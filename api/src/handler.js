// Pure, testable request handler for CurlPlan's canonical Clerk + Worker/D1
// data plane. D1 operations are injected so atomic revision and idempotency
// behavior can be exercised under Node without cloud credentials.
import merge from "../../src/merge.js";

const LWW = ["follows", "likes", "joins"];
const LISTS = ["posts", "addedCurlers", "addedSpiels"];
const MAPS = ["visits", "reviews", "iceReads", "threads"];
const STATE_KEYS = new Set([...LWW, ...LISTS, ...MAPS, "tombstones"]);
const HOSTILE_KEYS = new Set(["__proto__", "constructor", "prototype"]);
const CANONICAL_SCHEMA_VERSION = 4;
const MAX_BODY_BYTES = 512 * 1024;
const MAX_STATE_BYTES = 512 * 1024;
const MAX_STRUCTURE_DEPTH = 32;
const MAX_STRUCTURE_KEYS = 25_000;
const MAX_STRUCTURE_ITEMS = 25_000;
const MAX_CAS_ATTEMPTS = 3;

export function emptyState() {
  const state = {};
  LWW.forEach(key => { state[key] = {}; });
  MAPS.forEach(key => { state[key] = {}; });
  LISTS.forEach(key => { state[key] = []; });
  state.tombstones = {};
  return state;
}

export function sanitizeState(raw) {
  const state = emptyState();
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return state;
  LWW.concat(MAPS).forEach(key => {
    if (raw[key] && typeof raw[key] === "object" && !Array.isArray(raw[key])) state[key] = raw[key];
  });
  LISTS.forEach(key => {
    if (Array.isArray(raw[key])) state[key] = raw[key];
  });
  if (raw.tombstones && typeof raw.tombstones === "object" && !Array.isArray(raw.tombstones)) {
    state.tombstones = raw.tombstones;
  }
  return state;
}

function canonicalState(raw) {
  return merge.mergeState(emptyState(), sanitizeState(raw));
}

function corsHeaders(origin) {
  if (!origin) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function json(body, status, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
  });
}

function errorBody(code, message, details = {}) {
  return { error: { code, message, ...details } };
}

function currentEnvelope(row) {
  return {
    schemaVersion: CANONICAL_SCHEMA_VERSION,
    state: canonicalState(row?.doc),
    rev: row?.rev || 0,
  };
}

function conflictEnvelope(row) {
  const current = currentEnvelope(row);
  return errorBody("REVISION_CONFLICT", "The account state changed. Merge the current state and retry with its revision.", {
    currentRev: current.rev,
    schemaVersion: current.schemaVersion,
    state: current.state,
  });
}

async function readJSON(request) {
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    return { error: errorBody("PAYLOAD_TOO_LARGE", "The JSON request body exceeds 512 KiB."), status: 413 };
  }
  try {
    return { value: raw ? JSON.parse(raw) : {} };
  } catch {
    return { error: errorBody("INVALID_JSON", "The request body must be valid JSON."), status: 400 };
  }
}

function validateStructure(value) {
  let keys = 0;
  let items = 0;
  const visit = (entry, depth) => {
    if (depth > MAX_STRUCTURE_DEPTH) return "maximum nesting depth exceeded";
    if (entry === null || typeof entry !== "object") return null;
    if (Array.isArray(entry)) {
      items += entry.length;
      if (items > MAX_STRUCTURE_ITEMS) return "maximum collection size exceeded";
      for (const item of entry) {
        const issue = visit(item, depth + 1);
        if (issue) return issue;
      }
      return null;
    }
    for (const key of Object.keys(entry)) {
      if (HOSTILE_KEYS.has(key)) return `dangerous key ${key} is not allowed`;
      keys += 1;
      if (keys > MAX_STRUCTURE_KEYS) return "maximum object key count exceeded";
      const issue = visit(entry[key], depth + 1);
      if (issue) return issue;
    }
    return null;
  };
  return visit(value, 0);
}

function validateState(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return "state must be an object";
  const unknown = Object.keys(raw).filter(key => !STATE_KEYS.has(key));
  if (unknown.length) return `unknown state bucket ${unknown[0]}`;
  return validateStructure(raw);
}

function validateWriteContract(body, requireState = true) {
  if (!body || typeof body !== "object" || Array.isArray(body) ||
      !Number.isInteger(body.baseRev) || body.baseRev < 0 ||
      typeof body.idempotencyKey !== "string" || body.idempotencyKey.trim().length < 1 ||
      body.idempotencyKey.length > 128 || !Number.isInteger(body.schemaVersion)) {
    return { status: 422, body: errorBody("INVALID_WRITE_CONTRACT", "schemaVersion, baseRev, and idempotencyKey are required.") };
  }
  if (body.schemaVersion !== CANONICAL_SCHEMA_VERSION) {
    return { status: 426, body: errorBody("SCHEMA_UPGRADE_REQUIRED", "Writes require CurlPlan sync schema 4.", {
      schemaVersion: CANONICAL_SCHEMA_VERSION,
    }) };
  }
  if (requireState) {
    const issue = validateState(body.state);
    if (issue) return { status: 422, body: errorBody("INVALID_STATE", issue) };
  }
  return null;
}

async function fingerprint(operation, body) {
  const bytes = new TextEncoder().encode(merge.stableStringify({ operation, body }));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
}

async function writeState({ db, userId, body, operation, now }) {
  const contractError = validateWriteContract(body, operation !== "delete");
  if (contractError) return contractError;

  const requestFingerprint = await fingerprint(operation, body);
  const existingReceipt = await db.getReceipt(userId, body.idempotencyKey);
  if (existingReceipt) {
    if (existingReceipt.fingerprint !== requestFingerprint) {
      return {
        status: 409,
        body: errorBody("IDEMPOTENCY_KEY_REUSED", "The idempotency key was already used for a different request."),
      };
    }
    return { status: 200, body: existingReceipt.response };
  }

  let row = await db.get(userId);
  if ((row?.rev || 0) !== body.baseRev) {
    return { status: 409, body: conflictEnvelope(row) };
  }

  for (let attempt = 0; attempt < MAX_CAS_ATTEMPTS; attempt += 1) {
    const state = operation === "merge"
      ? merge.mergeState(canonicalState(row?.doc), sanitizeState(body.state))
      : operation === "restore"
        ? canonicalState(body.state)
        : emptyState();
    if (new TextEncoder().encode(JSON.stringify(state)).byteLength > MAX_STATE_BYTES) {
      return {
        status: 413,
        body: errorBody("MERGED_STATE_TOO_LARGE", "The final canonical account state exceeds 512 KiB."),
      };
    }

    const nextRev = (row?.rev || 0) + 1;
    const response = {
      schemaVersion: CANONICAL_SCHEMA_VERSION,
      rev: nextRev,
      operation,
      idempotencyKey: body.idempotencyKey,
    };
    const nextRow = {
      doc: state,
      rev: nextRev,
      schemaVersion: CANONICAL_SCHEMA_VERSION,
      updatedAt: now(),
    };
    const committed = await db.cas(userId, row?.rev || 0, nextRow, body.idempotencyKey, {
      fingerprint: requestFingerprint,
      operation,
      response,
    });
    if (committed) return { status: 200, body: response };

    const racedReceipt = await db.getReceipt(userId, body.idempotencyKey);
    if (racedReceipt) {
      if (racedReceipt.fingerprint !== requestFingerprint) {
        return { status: 409, body: errorBody("IDEMPOTENCY_KEY_REUSED", "The idempotency key was already used for a different request.") };
      }
      return { status: 200, body: racedReceipt.response };
    }

    row = await db.get(userId);
    if (operation !== "merge") return { status: 409, body: conflictEnvelope(row) };
  }

  return { status: 409, body: conflictEnvelope(await db.get(userId)) };
}

// deps: { db, verifyAuth, now, corsOrigin }
// db.get(userId) -> { doc, rev, schemaVersion, updatedAt } | null
// db.getReceipt(userId, key) -> { fingerprint, response } | null
// db.cas(userId, expectedRev, nextRow, key, receipt) -> boolean
export async function handleRequest(request, deps) {
  const { db, verifyAuth, now, corsOrigin } = deps;
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const requestOrigin = request.headers.get("Origin");
  const allowedOrigin = requestOrigin && corsOrigin && corsOrigin !== "*" && requestOrigin === corsOrigin
    ? requestOrigin
    : null;

  if (requestOrigin && !allowedOrigin) {
    return json(errorBody("ORIGIN_NOT_ALLOWED", "Request origin is not allowed."), 403, null);
  }
  if (request.method === "OPTIONS") {
    const requestedMethod = request.headers.get("Access-Control-Request-Method")?.toUpperCase();
    const requestedHeaders = (request.headers.get("Access-Control-Request-Headers") || "")
      .split(",")
      .map(value => value.trim().toLowerCase())
      .filter(Boolean);
    const methods = new Set(["GET", "POST", "DELETE"]);
    const headers = new Set(["authorization", "content-type"]);
    if (!allowedOrigin || !methods.has(requestedMethod) || requestedHeaders.some(value => !headers.has(value))) {
      return json(errorBody("PREFLIGHT_NOT_ALLOWED", "CORS preflight is not allowed."), 403, null);
    }
    return new Response(null, { status: 204, headers: corsHeaders(allowedOrigin) });
  }
  if (request.method === "GET" && path === "/health") {
    return json({ ok: true, schemaVersion: CANONICAL_SCHEMA_VERSION, ts: now() }, 200, allowedOrigin);
  }

  const protectedRoute = path === "/v1/state" || path === "/v1/export" || path === "/v1/restore";
  if (!protectedRoute) return json(errorBody("NOT_FOUND", "Route was not found."), 404, allowedOrigin);

  const auth = await verifyAuth(request);
  if (!auth?.userId) return json(errorBody("UNAUTHORIZED", "A valid bearer token is required."), 401, allowedOrigin);
  const userId = auth.userId;

  if (request.method === "GET" && (path === "/v1/state" || path === "/v1/export")) {
    return json(currentEnvelope(await db.get(userId)), 200, allowedOrigin);
  }

  if ((request.method === "POST" && (path === "/v1/state" || path === "/v1/restore")) ||
      (request.method === "DELETE" && path === "/v1/state")) {
    const parsed = await readJSON(request);
    if (parsed.error) return json(parsed.error, parsed.status, allowedOrigin);
    const operation = request.method === "DELETE" ? "delete" : path === "/v1/restore" ? "restore" : "merge";
    const result = await writeState({ db, userId, body: parsed.value, operation, now });
    return json(result.body, result.status, allowedOrigin);
  }

  return json(errorBody("METHOD_NOT_ALLOWED", "Method is not allowed for this route."), 405, allowedOrigin);
}
