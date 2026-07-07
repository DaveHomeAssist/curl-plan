// Pure, testable request handler for the CurlPlan sync API.
// Dependencies (D1 store, auth verifier, clock, CORS origin) are injected so the whole
// thing runs under Node in scripts/verify-api.js without Miniflare or a live Worker.
//
// Routes (all under /v1, JSON):
//   GET  /health      → { ok: true }
//   GET  /v1/state    → { state, rev }              (auth required)
//   POST /v1/state    → merge(stored, body.state)   (auth required) → { state, rev }
import merge from "../../src/merge.js";

const LWW = ["follows", "likes", "joins"];
const LISTS = ["posts", "addedCurlers", "addedSpiels"];
const MAPS = ["visits", "reviews", "iceReads", "threads"];
const MAX_BODY = 512 * 1024; // 512 KB per-user document cap

export function emptyState() {
  const s = {};
  LWW.forEach(k => s[k] = {});
  MAPS.forEach(k => s[k] = {});
  LISTS.forEach(k => s[k] = []);
  return s;
}

// Coerce a client-supplied doc to the expected top-level shape (defense-in-depth;
// merge itself is tolerant, but we never store a mis-shaped bucket).
export function sanitizeState(raw) {
  const s = emptyState();
  if (!raw || typeof raw !== "object") return s;
  LWW.concat(MAPS).forEach(k => { if (raw[k] && typeof raw[k] === "object" && !Array.isArray(raw[k])) s[k] = raw[k]; });
  LISTS.forEach(k => { if (Array.isArray(raw[k])) s[k] = raw[k]; });
  return s;
}

function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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

// deps: { db, verifyAuth, now, corsOrigin }
//   db.get(userId)         -> { doc, rev } | null
//   db.put(userId, doc, rev)
//   verifyAuth(request)    -> { userId } | null   (async)
export async function handleRequest(request, deps) {
  const { db, verifyAuth, now, corsOrigin } = deps;
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(corsOrigin) });
  if (request.method === "GET" && path === "/health") return json({ ok: true, ts: now() }, 200, corsOrigin);

  if (path === "/v1/state") {
    const auth = await verifyAuth(request);
    if (!auth || !auth.userId) return json({ error: "unauthorized" }, 401, corsOrigin);
    const userId = auth.userId;

    if (request.method === "GET") {
      const row = await db.get(userId);
      return json({ state: row ? row.doc : emptyState(), rev: row ? row.rev : 0 }, 200, corsOrigin);
    }

    if (request.method === "POST") {
      let body;
      try { body = await request.json(); } catch (e) { return json({ error: "invalid json" }, 400, corsOrigin); }
      const incomingRaw = body && body.state;
      if (JSON.stringify(incomingRaw || {}).length > MAX_BODY) return json({ error: "state too large" }, 413, corsOrigin);
      const incoming = sanitizeState(incomingRaw);
      const row = await db.get(userId);
      const merged = merge.mergeState(row ? row.doc : {}, incoming);
      const rev = (row ? row.rev : 0) + 1;
      await db.put(userId, merged, rev);
      return json({ state: merged, rev }, 200, corsOrigin);
    }

    return json({ error: "method not allowed" }, 405, corsOrigin);
  }

  return json({ error: "not found" }, 404, corsOrigin);
}
