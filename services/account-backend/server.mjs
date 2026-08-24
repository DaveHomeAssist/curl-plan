import { createServer } from "node:http";
import { createHash, randomUUID, randomBytes, scrypt, timingSafeEqual } from "node:crypto";
import { mkdir, readFile, readdir, rename, unlink, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const MAX_JSON_BYTES = 1_000_000;
const MAX_SEASON_BYTES = 512 * 1024;
const MAX_SEASON_DEPTH = 32;
const MAX_SEASON_KEYS = 25_000;
const MAX_SEASON_ITEMS = 25_000;
const CANONICAL_SEASON_SCHEMA = 4;
const RECORD_STORE_FORMAT = "curlplan-account-records-v1";
const OBJECT_RECORD_COLLECTIONS = [
  "accounts", "credentials", "sessions", "profiles", "seasons",
  "seasonReceipts", "sharedObjects", "interactions"
];
const ARRAY_RECORD_COLLECTIONS = ["relationships", "memberships", "reports"];
const DANGEROUS_KEYS = new Set(["__proto__", "constructor", "prototype"]);
const DEFAULT_STORAGE_PATH = resolve("/tmp/curlplan-account-backend-state.json");
const DEFAULT_REQUEST_TIMEOUT_MS = 15_000;
const DEFAULT_SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const scryptAsync = promisify(scrypt);
const DUMMY_CREDENTIAL = {
  algorithm: "scrypt-v1",
  normalization: "NFKC",
  salt: "c2f70854895a16e68e841710bcb85dcb",
  hash: "00".repeat(64)
};

class BackendError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

class AccountBackendStore {
  constructor(storagePath = DEFAULT_STORAGE_PATH, commitHook = null) {
    this.storagePath = storagePath;
    this.state = emptyState();
    this.loaded = false;
    this.queue = Promise.resolve();
    this.commitHook = commitHook;
  }

  async load() {
    if (this.loaded) {
      return;
    }
    try {
      this.state = await this.readSnapshot(this.storagePath);
    } catch (primaryError) {
      try {
        this.state = await this.readSnapshot(`${this.storagePath}.bak`);
        await this.save();
      } catch (backupError) {
        if (primaryError?.code !== "ENOENT" || backupError?.code !== "ENOENT") throw primaryError;
        this.state = emptyState();
      }
    }
    this.loaded = true;
  }

  async readSnapshot(path) {
    const raw = await readFile(path, "utf8");
    const decoded = JSON.parse(raw);
    if (decoded?.format !== RECORD_STORE_FORMAT) return normalizeState(decoded);
    const state = emptyState();
    const recordsDirectory = `${this.storagePath}.records`;
    for (const [logicalKey, blobName] of Object.entries(decoded.records || {})) {
      if (typeof blobName !== "string" || !/^[a-f0-9]{64}\.json$/.test(blobName)) {
        throw new Error("Invalid account record manifest.");
      }
      const payload = JSON.parse(await readFile(`${recordsDirectory}/${blobName}`, "utf8"));
      const separator = logicalKey.indexOf("/");
      const collection = separator < 0 ? logicalKey : logicalKey.slice(0, separator);
      const encodedID = separator < 0 ? "" : logicalKey.slice(separator + 1);
      if (OBJECT_RECORD_COLLECTIONS.includes(collection) && encodedID) {
        const id = decodeURIComponent(encodedID);
        if (DANGEROUS_KEYS.has(id)) throw new Error("Invalid account record key.");
        state[collection][id] = payload;
      } else if (ARRAY_RECORD_COLLECTIONS.includes(collection) && encodedID === "all" && Array.isArray(payload)) {
        state[collection] = payload;
      } else if (logicalKey === "counter" && Number.isInteger(payload)) {
        state.counter = payload;
      } else {
        throw new Error("Invalid account record collection.");
      }
    }
    return normalizeState(state);
  }

  async save() {
    await mkdir(dirname(this.storagePath), { recursive: true });
    const recordsDirectory = `${this.storagePath}.records`;
    await mkdir(recordsDirectory, { recursive: true });
    const payloads = new Map();
    for (const collection of OBJECT_RECORD_COLLECTIONS) {
      for (const [id, value] of Object.entries(this.state[collection])) {
        payloads.set(`${collection}/${encodeURIComponent(id)}`, value);
      }
    }
    for (const collection of ARRAY_RECORD_COLLECTIONS) {
      payloads.set(`${collection}/all`, this.state[collection]);
    }
    payloads.set("counter", this.state.counter);

    const records = {};
    for (const [logicalKey, value] of [...payloads.entries()].sort(([a], [b]) => a.localeCompare(b))) {
      const serializedRecord = `${JSON.stringify(value, null, 2)}\n`;
      const blobName = `${createHash("sha256").update(serializedRecord).digest("hex")}.json`;
      records[logicalKey] = blobName;
      try {
        await writeFile(`${recordsDirectory}/${blobName}`, serializedRecord, { flag: "wx" });
      } catch (error) {
        if (error?.code !== "EEXIST") throw error;
      }
    }

    const tempPath = `${this.storagePath}.${process.pid}.${Date.now()}.tmp`;
    const serialized = `${JSON.stringify({
      format: RECORD_STORE_FORMAT,
      schemaVersion: CANONICAL_SEASON_SCHEMA,
      records
    }, null, 2)}\n`;
    await writeFile(tempPath, serialized);
    if (this.commitHook) await this.commitHook();
    await rename(tempPath, this.storagePath);
    const backupTempPath = `${this.storagePath}.${process.pid}.${Date.now()}.bak.tmp`;
    try {
      await writeFile(backupTempPath, serialized);
      await rename(backupTempPath, `${this.storagePath}.bak`);
      await pruneUnreferencedRecords(recordsDirectory, new Set(Object.values(records)));
    } catch {
      // The atomically-renamed primary is the commit authority. A backup refresh
      // failure must not roll a successful commit back in memory.
    }
  }

  async runExclusive(operation) {
    const run = this.queue.then(async () => {
      const published = structuredClone(this.state);
      try {
        return await operation();
      } catch (error) {
        this.state = published;
        throw error;
      }
    });
    this.queue = run.catch(() => {});
    return run;
  }

  nextID(prefix) {
    this.state.counter += 1;
    return `${prefix}-${randomUUID()}`;
  }
}

export function accountBackendOptionsFromEnvironment(environment = process.env, argumentsList = process.argv) {
  return {
    storagePath: environment.CURLPLAN_ACCOUNT_BACKEND_STORE || argumentsList[2] || DEFAULT_STORAGE_PATH,
    port: boundedInteger(environment.PORT, 8787, 0, 65_535),
    hostname: environment.HOST || "127.0.0.1",
    mode: environment.CURLPLAN_ACCOUNT_BACKEND_MODE === "development" ? "development" : "quarantined",
    allowedOrigins: exactOrigins(environment.CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS),
    trustProxy: environment.CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY === "true",
    requestTimeoutMs: boundedInteger(
      environment.CURLPLAN_ACCOUNT_BACKEND_REQUEST_TIMEOUT_MS,
      DEFAULT_REQUEST_TIMEOUT_MS,
      1_000,
      120_000
    ),
    sessionTtlMs: boundedInteger(
      environment.CURLPLAN_ACCOUNT_BACKEND_SESSION_TTL_MS,
      DEFAULT_SESSION_TTL_MS,
      60_000,
      90 * 24 * 60 * 60 * 1000
    ),
    signInLimit: boundedInteger(environment.CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_LIMIT, 5, 1, 100),
    signInWindowMs: boundedInteger(
      environment.CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_WINDOW_MS,
      15 * 60 * 1000,
      1_000,
      24 * 60 * 60 * 1000
    ),
    maxRateBuckets: boundedInteger(
      environment.CURLPLAN_ACCOUNT_BACKEND_MAX_RATE_BUCKETS,
      10_000,
      100,
      1_000_000
    ),
    maxAccounts: boundedInteger(environment.CURLPLAN_ACCOUNT_BACKEND_MAX_ACCOUNTS, 10_000, 1, 1_000_000),
    maxSessionsPerAccount: boundedInteger(
      environment.CURLPLAN_ACCOUNT_BACKEND_MAX_SESSIONS_PER_ACCOUNT,
      5,
      1,
      100
    )
  };
}

export function createAccountBackendServer({
  storagePath = DEFAULT_STORAGE_PATH,
  mode = "quarantined",
  commitHook = null,
  allowedOrigins = [],
  trustProxy = false,
  signInLimit = 5,
  signInWindowMs = 15 * 60 * 1000,
  maxRateBuckets = 10_000,
  maxAccounts = 10_000,
  maxSessionsPerAccount = 5,
  sessionTtlMs = DEFAULT_SESSION_TTL_MS,
  requestTimeoutMs = DEFAULT_REQUEST_TIMEOUT_MS,
  logger = () => {}
} = {}) {
  const store = new AccountBackendStore(storagePath, commitHook);
  const limiter = new Map();
  const config = {
    allowedOrigins: new Set(allowedOrigins),
    trustProxy,
    signInLimit: Math.max(1, signInLimit),
    signInWindowMs: Math.max(1_000, signInWindowMs),
    maxRateBuckets: Math.max(100, maxRateBuckets),
    maxAccounts: Math.max(1, maxAccounts),
    maxSessionsPerAccount: Math.max(1, maxSessionsPerAccount),
    sessionTtlMs: Math.max(1, sessionTtlMs),
    logger,
    limiter
  };

  const server = createServer(async (request, response) => {
    const requestID = randomUUID();
    setBaseHeaders(response);

    try {
      applyCORS(request, response, config.allowedOrigins);
      if (request.method === "OPTIONS") {
        validatePreflight(request);
        response.removeHeader("Content-Type");
        response.writeHead(204);
        response.end();
        return;
      }
      await store.load();
      const url = new URL(request.url ?? "/", "http://localhost");
      if (request.method === "GET" && url.pathname === "/health") {
        sendJSON(response, 200, {
          ok: true,
          plane: "custom-account-development-verifier",
          mode,
          writable: mode === "development",
          schemaVersion: CANONICAL_SEASON_SCHEMA
        });
        return;
      }
      if (mode !== "development") {
        throw new BackendError(503, "PLANE_QUARANTINED", "The custom account service is not a production write authority.");
      }
      await store.runExclusive(() => routeRequest({ request, response, store, url, requestID, config }));
    } catch (error) {
      if (error instanceof BackendError) {
        sendError(response, error.status, error.code, error.message, requestID);
        return;
      }
      sendError(response, 500, "INTERNAL_ERROR", "Unexpected account backend failure.", requestID);
    }
  });
  server.requestTimeout = requestTimeoutMs;
  server.headersTimeout = Math.min(requestTimeoutMs, 10_000);
  return server;
}

export async function startAccountBackendServer(options = {}) {
  const {
    storagePath = DEFAULT_STORAGE_PATH,
    port = 0,
    hostname = "127.0.0.1"
  } = options;
  const server = createAccountBackendServer(options);
  await new Promise((resolveListen, rejectListen) => {
    server.once("error", rejectListen);
    server.listen(port, hostname, () => {
      server.off("error", rejectListen);
      resolveListen();
    });
  });
  const address = server.address();
  return {
    server,
    storagePath,
    baseURL: `http://${hostname}:${address.port}`,
    close: () => new Promise((resolveClose, rejectClose) => {
      server.close((error) => {
        if (error) {
          rejectClose(error);
          return;
        }
        resolveClose();
      });
    })
  };
}

async function routeRequest({ request, response, store, url, requestID, config }) {
  const method = request.method ?? "GET";
  const path = url.pathname;

  if (method === "POST" && path === "/v1/accounts") {
    const body = await readJSON(request);
    const handle = normalizeHandle(requiredText(body, "handle"));
    const displayName = requiredText(body, "displayName");
    const homeClub = requiredText(body, "homeClub");
    const password = requiredPassword(body, "password");
    const handleTaken = Object.values(store.state.profiles).some((profile) => normalizeHandle(profile.handle) === handle);
    if (handleTaken) {
      throw new BackendError(409, "HANDLE_TAKEN", "That handle is already reserved.");
    }
    if (Object.keys(store.state.accounts).length >= config.maxAccounts) {
      throw new BackendError(507, "ACCOUNT_QUOTA_EXCEEDED", "Development account storage quota is full.");
    }
    const account = {
      id: store.nextID("acct"),
      createdAt: now(),
      status: "active",
      deletedAt: null
    };
    store.state.accounts[account.id] = account;
    store.state.credentials[account.id] = await hashPassword(password.normalized);
    store.state.profiles[account.id] = {
      accountID: account.id,
      handle,
      displayName,
      homeClub,
      avatarURL: null,
      visibility: "private",
      searchable: false
    };
    await store.save();
    sendJSON(response, 201, account);
    return;
  }

  if (method === "POST" && path === "/v1/auth/sign-in") {
    const body = await readJSON(request);
    const handle = normalizeHandle(requiredText(body, "handle"));
    const password = passwordField(body, "password");
    const deviceID = requiredText(body, "deviceID");
    const limiterKey = signInLimiterKey(handle, request, config.trustProxy);
    const attempts = activeAttempts(config.limiter.get(limiterKey), config.signInWindowMs);
    if (!config.limiter.has(limiterKey) && config.limiter.size >= config.maxRateBuckets) {
      config.limiter.delete(config.limiter.keys().next().value);
    }
    config.limiter.set(limiterKey, attempts);
    if (attempts.length >= config.signInLimit) {
      logSecurityEvent(config.logger, "sign_in_rate_limited", handle, request, config.trustProxy);
      throw new BackendError(429, "SIGN_IN_RATE_LIMITED", "Too many sign in attempts. Try again later.");
    }
    const profile = Object.values(store.state.profiles).find((entry) => normalizeHandle(entry.handle) === handle);
    const accountID = profile?.accountID;
    const account = accountID ? store.state.accounts[accountID] : null;
    const credential = accountID ? store.state.credentials[accountID] : null;
    const verification = await verifyPassword(password, credential);
    // Generic credential failure: never reveal whether the handle exists.
    if (!account || account.status === "deleted" || !verification.matches) {
      attempts.push(Date.now());
      config.limiter.set(limiterKey, attempts);
      logSecurityEvent(config.logger, "sign_in_failed", handle, request, config.trustProxy);
      throw new BackendError(401, "INVALID_CREDENTIALS", "Handle or password is incorrect.");
    }
    config.limiter.delete(limiterKey);
    if (verification.migrate) {
      store.state.credentials[accountID] = await hashPassword(password.normalized);
    }
    const activeSessions = Object.values(store.state.sessions)
      .filter((session) => session.accountID === accountID && session.state === "active")
      .sort((a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt));
    while (activeSessions.length >= config.maxSessionsPerAccount) {
      const revoked = activeSessions.shift();
      store.state.sessions[revoked.id] = { ...revoked, state: "revoked" };
    }
    const session = {
      id: store.nextID("sess"),
      accountID,
      deviceID,
      createdAt: now(),
      expiresAt: expiresAt(config.sessionTtlMs),
      state: "active"
    };
    store.state.sessions[session.id] = session;
    const olderSessions = Object.values(store.state.sessions)
      .filter((entry) => entry.accountID === accountID && entry.id !== session.id)
      .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
    for (const stale of olderSessions.slice(config.maxSessionsPerAccount - 1)) {
      delete store.state.sessions[stale.id];
    }
    await store.save();
    sendJSON(response, 200, session);
    return;
  }

  if (method === "POST" && path === "/v1/auth/sign-out") {
    const { sessionID } = requireSession(store, request);
    store.state.sessions[sessionID] = { ...store.state.sessions[sessionID], state: "revoked" };
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/me/export") {
    const { accountID } = requireSession(store, request);
    const sections = ["account", "profile"];
    if (store.state.seasons[accountID]) {
      sections.push("season");
    }
    if (Object.values(store.state.sharedObjects).some((object) => object.ownerID === accountID)) {
      sections.push("owned_shared_objects");
    }
    sendJSON(response, 200, sections);
    return;
  }

  if (method === "DELETE" && path === "/v1/me") {
    const { accountID } = requireSession(store, request);
    const account = store.state.accounts[accountID];
    const ownedObjectIDs = new Set(Object.values(store.state.sharedObjects)
      .filter((object) => object.ownerID === accountID)
      .map((object) => object.id));
    const removedInteractionIDs = new Set(Object.values(store.state.interactions)
      .filter((interaction) => interaction.actorID === accountID || ownedObjectIDs.has(interaction.objectID))
      .map((interaction) => interaction.id));
    store.state.accounts[accountID] = { ...account, status: "deleted", deletedAt: now() };
    delete store.state.profiles[accountID];
    delete store.state.seasons[accountID];
    delete store.state.seasonReceipts[accountID];
    delete store.state.credentials[accountID];
    for (const objectID of ownedObjectIDs) {
      delete store.state.sharedObjects[objectID];
    }
    for (const [sessionID, session] of Object.entries(store.state.sessions)) {
      if (session.accountID === accountID) {
        store.state.sessions[sessionID] = { ...session, state: "revoked" };
      }
    }
    store.state.relationships = store.state.relationships.filter((edge) => edge.actorID !== accountID && edge.targetID !== accountID);
    store.state.memberships = store.state.memberships.filter((membership) => membership.accountID !== accountID && !ownedObjectIDs.has(membership.objectID));
    store.state.interactions = Object.fromEntries(
      Object.entries(store.state.interactions).filter(([, interaction]) => !removedInteractionIDs.has(interaction.id))
    );
    store.state.reports = store.state.reports.filter((report) => report.reporterID !== accountID && !removedInteractionIDs.has(report.targetID));
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/me/season/import-local") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const season = requiredSeason(body);
    if (store.state.seasons[accountID]) {
      throw new BackendError(409, "SEASON_ALREADY_EXISTS", "Account already has a season document.");
    }
    const document = {
      id: store.nextID("season"),
      accountID,
      schemaVersion: season.schemaVersion,
      version: 1,
      body: season,
      updatedAt: now()
    };
    store.state.seasons[accountID] = document;
    await store.save();
    sendJSON(response, 201, document);
    return;
  }

  if (method === "GET" && path === "/v1/me/season") {
    const { accountID } = requireSession(store, request);
    const document = store.state.seasons[accountID];
    if (!document) {
      throw new BackendError(404, "SEASON_MISSING", "Account does not have a season document.");
    }
    sendJSON(response, 200, document);
    return;
  }

  if (method === "POST" && path === "/v1/me/season/changes") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const document = store.state.seasons[accountID];
    if (!document) {
      throw new BackendError(404, "SEASON_MISSING", "Account does not have a season document.");
    }
    const baseVersion = requiredInteger(body, "baseVersion");
    const updatedBody = validateSeasonDocument(requiredObject(body, "updatedBody"));
    const clientMutationID = requiredText(body, "clientMutationID");
    const domains = requiredStringArray(body, "domains");
    const mutationFingerprint = stableStringify({ baseVersion, updatedBody, domains });
    const priorMutation = store.state.seasonReceipts[accountID]?.[clientMutationID];
    if (priorMutation) {
      if (priorMutation.fingerprint !== mutationFingerprint) {
        throw new BackendError(409, "IDEMPOTENCY_KEY_REUSED", "clientMutationID was already used for a different change.");
      }
      sendJSON(response, 200, priorMutation.receipt);
      return;
    }
    if (document.version !== baseVersion) {
      throw new BackendError(409, "VERSION_CONFLICT", `Current version is ${document.version}.`);
    }
    const nextVersion = document.version + 1;
    const updatedDocument = {
      ...document,
      schemaVersion: updatedBody.schemaVersion,
      version: nextVersion,
      body: updatedBody,
      updatedAt: now()
    };
    store.state.seasons[accountID] = updatedDocument;
    const receipt = {
      id: store.nextID("change"),
      seasonID: updatedDocument.id,
      actorID: accountID,
      baseVersion,
      serverVersion: nextVersion,
      clientMutationID,
      domains
    };
    store.state.seasonReceipts[accountID] ??= {};
    store.state.seasonReceipts[accountID][clientMutationID] = {
      fingerprint: mutationFingerprint,
      receipt
    };
    await store.save();
    sendJSON(response, 200, receipt);
    return;
  }

  if (method === "PATCH" && path === "/v1/me/privacy") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const visibility = requiredEnum(body, "visibility", ["private", "public"]);
    const searchable = requiredBoolean(body, "searchable");
    const profile = store.state.profiles[accountID];
    if (!profile) {
      throw new BackendError(404, "ACCOUNT_NOT_FOUND", "Account profile was not found.");
    }
    store.state.profiles[accountID] = { ...profile, visibility, searchable };
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "GET" && path === "/v1/profiles/search") {
    const { accountID } = requireSession(store, request);
    const query = (url.searchParams.get("q") ?? "").trim().toLowerCase();
    const profiles = Object.values(store.state.profiles)
      .filter((profile) => profile.visibility === "public")
      .filter((profile) => profile.searchable)
      .filter((profile) => !isBlockedBetween(store.state, accountID, profile.accountID))
      .filter((profile) => profile.handle.toLowerCase().includes(query) || profile.displayName.toLowerCase().includes(query))
      .sort((a, b) => a.handle.localeCompare(b.handle));
    sendJSON(response, 200, profiles);
    return;
  }

  if (method === "POST" && path === "/v1/relationships") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const targetID = requiredText(body, "targetID");
    requireActiveAccount(store.state, targetID);
    if (isBlockedBetween(store.state, accountID, targetID)) {
      throw new BackendError(403, "BLOCKED", "Blocked accounts cannot create relationships.");
    }
    const existing = store.state.relationships.find((edge) => edge.actorID === accountID && edge.targetID === targetID && edge.kind === "follow");
    if (existing) {
      sendJSON(response, 200, existing);
      return;
    }
    const edge = {
      id: store.nextID("rel"),
      actorID: accountID,
      targetID,
      kind: "follow",
      state: "accepted",
      createdAt: now()
    };
    store.state.relationships.push(edge);
    await store.save();
    sendJSON(response, 201, edge);
    return;
  }

  if (method === "DELETE" && path === "/v1/relationships/follow") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const targetID = requiredText(body, "targetID");
    store.state.relationships = store.state.relationships.filter((edge) => !(edge.actorID === accountID && edge.targetID === targetID && edge.kind === "follow"));
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/blocks") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const targetID = requiredText(body, "targetID");
    requireActiveAccount(store.state, targetID);
    store.state.relationships = store.state.relationships.filter((edge) => !samePair(edge, accountID, targetID));
    store.state.memberships = store.state.memberships.filter((membership) => {
      const object = store.state.sharedObjects[membership.objectID];
      if (!object) return true;
      return !((object.ownerID === accountID && membership.accountID === targetID) ||
        (object.ownerID === targetID && membership.accountID === accountID));
    });
    const edge = {
      id: store.nextID("rel"),
      actorID: accountID,
      targetID,
      kind: "block",
      state: "accepted",
      createdAt: now()
    };
    store.state.relationships.push(edge);
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/shared-objects") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const kind = requiredEnum(body, "kind", ["spiel", "bonspiel", "team", "roster", "lineup", "scorecard"]);
    const title = requiredText(body, "title");
    const visibility = requiredEnum(body, "visibility", ["private", "members_only", "public"]);
    const object = {
      id: store.nextID("shared"),
      kind,
      ownerID: accountID,
      visibility,
      version: 1,
      title
    };
    store.state.sharedObjects[object.id] = object;
    store.state.memberships.push({
      id: store.nextID("member"),
      objectID: object.id,
      accountID,
      role: "owner",
      state: "accepted"
    });
    await store.save();
    sendJSON(response, 201, object);
    return;
  }

  const memberRoute = path.match(/^\/v1\/shared-objects\/([^/]+)\/members$/);
  if (method === "POST" && memberRoute) {
    const { accountID } = requireSession(store, request);
    const objectID = decodeURIComponent(memberRoute[1]);
    const object = requireSharedObject(store.state, objectID);
    requireSharedObjectAdmin(store.state, object, accountID);
    const body = await readJSON(request);
    const memberAccountID = requiredText(body, "accountID");
    requireActiveAccount(store.state, memberAccountID);
    if (isBlockedBetween(store.state, accountID, memberAccountID) ||
        isBlockedBetween(store.state, object.ownerID, memberAccountID)) {
      throw new BackendError(403, "BLOCKED", "Blocked accounts cannot be added as members.");
    }
    const role = requiredEnum(body, "role", ["owner", "admin", "teammate", "viewer"]);
    const existingIndex = store.state.memberships.findIndex((membership) => membership.objectID === objectID && membership.accountID === memberAccountID);
    const membership = {
      id: existingIndex >= 0 ? store.state.memberships[existingIndex].id : store.nextID("member"),
      objectID,
      accountID: memberAccountID,
      role,
      state: "accepted"
    };
    if (existingIndex >= 0) {
      store.state.memberships[existingIndex] = membership;
    } else {
      store.state.memberships.push(membership);
    }
    await store.save();
    sendNoContent(response);
    return;
  }

  const sharedObjectRoute = path.match(/^\/v1\/shared-objects\/([^/]+)$/);
  if (method === "PATCH" && sharedObjectRoute) {
    const { accountID } = requireSession(store, request);
    const objectID = decodeURIComponent(sharedObjectRoute[1]);
    const object = requireSharedObject(store.state, objectID);
    requireSharedObjectAdmin(store.state, object, accountID);
    const body = await readJSON(request);
    const title = requiredText(body, "title");
    store.state.sharedObjects[objectID] = { ...object, title, version: object.version + 1 };
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/interactions") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const objectID = requiredText(body, "objectID");
    const object = requireSharedObject(store.state, objectID);
    if (isBlockedBetween(store.state, accountID, object.ownerID)) {
      throw new BackendError(403, "BLOCKED", "Blocked accounts cannot interact.");
    }
    if (object.visibility !== "public" && !isAcceptedMember(store.state, objectID, accountID)) {
      throw new BackendError(403, "NOT_MEMBER", "Only shared object members can interact.");
    }
    const kind = requiredEnum(body, "kind", ["rsvp", "invite", "reaction", "comment", "message"]);
    const interaction = {
      id: store.nextID("interaction"),
      objectID,
      actorID: accountID,
      kind,
      body: requiredText(body, "body"),
      state: "active",
      createdAt: now()
    };
    store.state.interactions[interaction.id] = interaction;
    await store.save();
    sendJSON(response, 201, interaction);
    return;
  }

  const interactionRoute = path.match(/^\/v1\/interactions\/([^/]+)$/);
  if (method === "DELETE" && interactionRoute) {
    const { accountID } = requireSession(store, request);
    const interactionID = decodeURIComponent(interactionRoute[1]);
    const interaction = requireInteraction(store.state, interactionID);
    const object = requireSharedObject(store.state, interaction.objectID);
    if (interaction.actorID !== accountID && isBlockedBetween(store.state, accountID, object.ownerID)) {
      throw new BackendError(403, "BLOCKED", "Blocked accounts cannot administer interactions.");
    }
    if (interaction.actorID !== accountID && !canAdminSharedObject(store.state, object, accountID)) {
      throw new BackendError(403, "INSUFFICIENT_ROLE", "Only the author or object admin can delete this interaction.");
    }
    store.state.interactions[interactionID] = { ...interaction, state: "deleted", deletedAt: now() };
    await store.save();
    sendNoContent(response);
    return;
  }

  if (method === "POST" && path === "/v1/reports") {
    const { accountID } = requireSession(store, request);
    const body = await readJSON(request);
    const interactionID = requiredText(body, "interactionID");
    const interaction = requireInteraction(store.state, interactionID);
    const object = requireSharedObject(store.state, interaction.objectID);
    if (isBlockedBetween(store.state, accountID, object.ownerID)) {
      throw new BackendError(403, "BLOCKED", "Blocked accounts cannot report through this shared object.");
    }
    const report = {
      id: store.nextID("report"),
      reporterID: accountID,
      targetID: interactionID,
      reason: requiredText(body, "reason"),
      state: "open",
      createdAt: now()
    };
    store.state.reports.push(report);
    await store.save();
    sendJSON(response, 201, report);
    return;
  }

  const moderationRoute = path.match(/^\/v1\/moderation\/reports\/([^/]+)\/hide$/);
  if (method === "POST" && moderationRoute) {
    const { accountID } = requireSession(store, request);
    const reportID = decodeURIComponent(moderationRoute[1]);
    const reportIndex = store.state.reports.findIndex((report) => report.id === reportID);
    if (reportIndex < 0) {
      throw new BackendError(404, "NOT_FOUND", "Report was not found.");
    }
    const report = store.state.reports[reportIndex];
    const interaction = requireInteraction(store.state, report.targetID);
    const object = requireSharedObject(store.state, interaction.objectID);
    requireSharedObjectAdmin(store.state, object, accountID);
    store.state.interactions[interaction.id] = { ...interaction, state: "hidden_by_moderation" };
    store.state.reports[reportIndex] = { ...report, state: "actioned" };
    await store.save();
    sendNoContent(response);
    return;
  }

  sendError(response, 404, "NOT_FOUND", "Route was not found.", requestID);
}

function emptyState() {
  return {
    accounts: {},
    credentials: {},
    sessions: {},
    profiles: {},
    seasons: {},
    seasonReceipts: {},
    relationships: [],
    sharedObjects: {},
    memberships: [],
    interactions: {},
    reports: [],
    counter: 0
  };
}

function normalizeState(raw) {
  return {
    ...emptyState(),
    ...raw,
    accounts: raw?.accounts ?? {},
    credentials: raw?.credentials ?? {},
    sessions: raw?.sessions ?? {},
    profiles: raw?.profiles ?? {},
    seasons: raw?.seasons ?? {},
    seasonReceipts: raw?.seasonReceipts ?? {},
    relationships: raw?.relationships ?? [],
    sharedObjects: raw?.sharedObjects ?? {},
    memberships: raw?.memberships ?? [],
    interactions: raw?.interactions ?? {},
    reports: raw?.reports ?? [],
    counter: Number.isInteger(raw?.counter) ? raw.counter : 0
  };
}

function requireSession(store, request) {
  const sessionID = bearerToken(request);
  if (!sessionID) {
    throw new BackendError(401, "SESSION_INVALID", "Active bearer session is required.");
  }
  const session = store.state.sessions[sessionID];
  if (!session || session.state !== "active") {
    throw new BackendError(401, "SESSION_INVALID", "Active bearer session is required.");
  }
  if (session.expiresAt && Date.parse(session.expiresAt) <= Date.now()) {
    throw new BackendError(401, "SESSION_EXPIRED", "Session has expired. Sign in again.");
  }
  const account = store.state.accounts[session.accountID];
  if (!account) {
    throw new BackendError(401, "SESSION_INVALID", "Active bearer session is required.");
  }
  if (account.status === "deleted") {
    throw new BackendError(403, "ACCOUNT_DELETED", "Account has been deleted.");
  }
  return { sessionID, session, accountID: session.accountID, account };
}

function bearerToken(request) {
  const header = request.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return null;
  }
  return header.slice("Bearer ".length).trim();
}

async function readJSON(request) {
  const chunks = [];
  let total = 0;
  for await (const chunk of request) {
    total += chunk.length;
    if (total > MAX_JSON_BYTES) {
      throw new BackendError(413, "PAYLOAD_TOO_LARGE", "JSON request body is too large.");
    }
    chunks.push(chunk);
  }
  if (chunks.length === 0) {
    return {};
  }
  const raw = Buffer.concat(chunks).toString("utf8");
  try {
    return JSON.parse(raw);
  } catch {
    throw new BackendError(400, "INVALID_JSON", "Request body must be valid JSON.");
  }
}

function requiredText(body, key) {
  if (typeof body?.[key] !== "string" || body[key].trim() === "") {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} is required.`);
  }
  return body[key].trim();
}

function normalizeHandle(value) {
  return value.normalize("NFKC").toLocaleLowerCase("en-US");
}

function requiredInteger(body, key) {
  if (!Number.isInteger(body?.[key])) {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} must be an integer.`);
  }
  return body[key];
}

const MIN_PASSWORD_LENGTH = 8;

function requiredPassword(body, key) {
  const password = passwordField(body, key);
  if (password.normalized.length < MIN_PASSWORD_LENGTH) {
    throw new BackendError(422, "WEAK_PASSWORD", `${key} must be at least ${MIN_PASSWORD_LENGTH} characters.`);
  }
  return password;
}

function passwordField(body, key) {
  const raw = body?.[key];
  if (typeof raw !== "string") {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} is required.`);
  }
  return { raw, normalized: raw.normalize("NFKC") };
}

async function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = (await scryptAsync(password, salt, 64)).toString("hex");
  return { algorithm: "scrypt-v1", normalization: "NFKC", salt, hash };
}

async function verifyPassword(password, credential) {
  const validCredential = credential &&
    typeof credential.salt === "string" &&
    typeof credential.hash === "string" &&
    /^[a-f0-9]{128}$/i.test(credential.hash)
    ? credential
    : DUMMY_CREDENTIAL;
  const legacy = !validCredential.algorithm;
  const candidate = legacy ? password.raw : password.normalized;
  const expected = Buffer.from(validCredential.hash, "hex");
  const actual = await scryptAsync(candidate, validCredential.salt, expected.length);
  const matches = expected.length === actual.length && timingSafeEqual(expected, actual);
  return {
    matches: credential != null && validCredential === credential && matches,
    migrate: legacy && matches
  };
}

function requiredObject(body, key) {
  if (!body?.[key] || typeof body[key] !== "object" || Array.isArray(body[key])) {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} must be an object.`);
  }
  return body[key];
}

function requiredStringArray(body, key) {
  if (!Array.isArray(body?.[key]) || body[key].some((value) => typeof value !== "string")) {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} must be a string array.`);
  }
  return [...new Set(body[key])].sort();
}

function requiredBoolean(body, key) {
  if (typeof body?.[key] !== "boolean") {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} must be a boolean.`);
  }
  return body[key];
}

function requiredEnum(body, key, allowed) {
  const value = requiredText(body, key);
  if (!allowed.includes(value)) {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} is not supported.`);
  }
  return value;
}

function requiredSeason(body) {
  return validateSeasonDocument(requiredObject(body, "season"));
}

function validateSeasonDocument(season) {
  const issue = validateBoundedStructure(season);
  if (issue) throw new BackendError(422, "INVALID_SEASON_DOCUMENT", issue);
  if (Buffer.byteLength(JSON.stringify(season), "utf8") > MAX_SEASON_BYTES) {
    throw new BackendError(413, "SEASON_TOO_LARGE", "Season document exceeds 512 KiB.");
  }
  const allowedSeasonKeys = new Set(["schemaVersion", "profile", "state"]);
  const allowedProfileKeys = new Set(["name", "homeClub", "province"]);
  const stateShape = {
    addedCurlers: "array",
    addedSpiels: "array",
    follows: "object",
    likes: "object",
    joins: "object",
    posts: "array",
    visits: "object",
    reviews: "object",
    iceReads: "object",
    threads: "object"
  };
  const unknownSeasonKey = Object.keys(season).find(key => !allowedSeasonKeys.has(key));
  if (unknownSeasonKey) throw new BackendError(422, "INVALID_SEASON_DOCUMENT", `Unknown season field ${unknownSeasonKey}.`);
  if (season.schemaVersion !== CANONICAL_SEASON_SCHEMA) {
    throw new BackendError(422, "SCHEMA_UNSUPPORTED", "Development imports require canonical season schema 4.");
  }
  if (!season.profile || typeof season.profile !== "object" || Array.isArray(season.profile) ||
      Object.keys(season.profile).some(key => !allowedProfileKeys.has(key)) ||
      ["name", "homeClub", "province"].some(key => typeof season.profile[key] !== "string")) {
    throw new BackendError(422, "INVALID_SEASON_DOCUMENT", "Season profile must contain only name, homeClub, and province strings.");
  }
  if (!season.state || typeof season.state !== "object" || Array.isArray(season.state) ||
      Object.keys(season.state).some(key => !Object.hasOwn(stateShape, key))) {
    throw new BackendError(422, "INVALID_SEASON_DOCUMENT", "Season state contains unknown or missing structure.");
  }
  for (const [key, kind] of Object.entries(stateShape)) {
    const value = season.state[key];
    const valid = kind === "array" ? Array.isArray(value) : value && typeof value === "object" && !Array.isArray(value);
    if (!valid) throw new BackendError(422, "INVALID_SEASON_DOCUMENT", `Season state field ${key} must be an ${kind}.`);
  }
  return season;
}

function validateBoundedStructure(value) {
  let keys = 0;
  let items = 0;
  const visit = (entry, depth) => {
    if (depth > MAX_SEASON_DEPTH) return "Season document nesting is too deep.";
    if (!entry || typeof entry !== "object") return null;
    if (Array.isArray(entry)) {
      items += entry.length;
      if (items > MAX_SEASON_ITEMS) return "Season document contains too many collection items.";
      for (const item of entry) {
        const issue = visit(item, depth + 1);
        if (issue) return issue;
      }
      return null;
    }
    for (const key of Object.keys(entry)) {
      if (DANGEROUS_KEYS.has(key)) return `Dangerous season key ${key} is not allowed.`;
      keys += 1;
      if (keys > MAX_SEASON_KEYS) return "Season document contains too many object keys.";
      const issue = visit(entry[key], depth + 1);
      if (issue) return issue;
    }
    return null;
  };
  return visit(value, 0);
}

function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
}

async function pruneUnreferencedRecords(recordsDirectory, retained) {
  const entries = await readdir(recordsDirectory);
  await Promise.all(entries
    .filter(entry => /^[a-f0-9]{64}\.json$/.test(entry) && !retained.has(entry))
    .map(entry => unlink(`${recordsDirectory}/${entry}`)));
}

function requireActiveAccount(state, accountID) {
  const account = state.accounts[accountID];
  if (!account || account.status !== "active") {
    throw new BackendError(404, "ACCOUNT_NOT_FOUND", "Account was not found.");
  }
  return account;
}

function requireSharedObject(state, objectID) {
  const object = state.sharedObjects[objectID];
  if (!object) {
    throw new BackendError(404, "NOT_FOUND", "Shared object was not found.");
  }
  return object;
}

function requireInteraction(state, interactionID) {
  const interaction = state.interactions[interactionID];
  if (!interaction) {
    throw new BackendError(404, "NOT_FOUND", "Interaction was not found.");
  }
  return interaction;
}

function requireSharedObjectAdmin(state, object, accountID) {
  if (isBlockedBetween(state, accountID, object.ownerID)) {
    throw new BackendError(403, "BLOCKED", "Blocked accounts cannot administer this shared object.");
  }
  if (!canAdminSharedObject(state, object, accountID)) {
    throw new BackendError(403, "INSUFFICIENT_ROLE", "Admin or owner role is required.");
  }
}

function canAdminSharedObject(state, object, accountID) {
  if (object.ownerID === accountID) {
    return true;
  }
  return state.memberships.some((membership) => membership.objectID === object.id &&
    membership.accountID === accountID &&
    membership.state === "accepted" &&
    ["owner", "admin"].includes(membership.role));
}

function isAcceptedMember(state, objectID, accountID) {
  return state.memberships.some((membership) => membership.objectID === objectID &&
    membership.accountID === accountID &&
    membership.state === "accepted");
}

function isBlockedBetween(state, accountID, targetID) {
  return state.relationships.some((edge) => samePair(edge, accountID, targetID) &&
    edge.kind === "block" &&
    edge.state === "accepted");
}

function samePair(edge, accountID, targetID) {
  return (edge.actorID === accountID && edge.targetID === targetID) ||
    (edge.actorID === targetID && edge.targetID === accountID);
}

const CORS_METHODS = new Set(["GET", "POST", "PATCH", "DELETE", "OPTIONS"]);
const CORS_HEADERS = new Set(["authorization", "content-type"]);

function applyCORS(request, response, allowedOrigins) {
  const origin = request.headers.origin;
  if (!origin) return;
  if (!allowedOrigins.has(origin)) {
    throw new BackendError(403, "ORIGIN_NOT_ALLOWED", "Request origin is not allowed.");
  }
  response.setHeader("Access-Control-Allow-Origin", origin);
  response.setHeader("Access-Control-Allow-Credentials", "true");
  response.setHeader("Access-Control-Allow-Methods", [...CORS_METHODS].join(", "));
  response.setHeader("Access-Control-Allow-Headers", [...CORS_HEADERS].map(value => value.replace(/^./, char => char.toUpperCase())).join(", "));
  response.setHeader("Access-Control-Max-Age", "600");
  response.setHeader("Vary", "Origin");
}

function validatePreflight(request) {
  const method = request.headers["access-control-request-method"]?.toUpperCase();
  const headers = (request.headers["access-control-request-headers"] ?? "")
    .split(",")
    .map(value => value.trim().toLowerCase())
    .filter(Boolean);
  if (!request.headers.origin || !method || !CORS_METHODS.has(method) || headers.some(header => !CORS_HEADERS.has(header))) {
    throw new BackendError(403, "PREFLIGHT_NOT_ALLOWED", "CORS preflight is not allowed.");
  }
}

function activeAttempts(attempts = [], windowMs) {
  const cutoff = Date.now() - windowMs;
  return attempts.filter(timestamp => timestamp > cutoff);
}

function boundedInteger(rawValue, fallback, minimum, maximum) {
  if (rawValue === undefined || rawValue === "") return fallback;
  const value = Number(rawValue);
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum ? value : fallback;
}

function exactOrigins(rawValue = "") {
  const origins = rawValue.split(",").map(value => value.trim()).filter(Boolean);
  return [...new Set(origins.filter(value => {
    try {
      const url = new URL(value);
      return (url.protocol === "https:" || url.protocol === "http:") &&
        url.origin === value && !url.username && !url.password;
    } catch {
      return false;
    }
  }))];
}

function sourceAddress(request, trustProxy) {
  if (trustProxy && typeof request.headers["x-forwarded-for"] === "string") {
    return request.headers["x-forwarded-for"].split(",", 1)[0].trim().slice(0, 128);
  }
  return String(request.socket?.remoteAddress || "unknown").slice(0, 128);
}

function securityHash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 24);
}

function signInLimiterKey(handle, request, trustProxy) {
  return `${securityHash(handle)}:${securityHash(sourceAddress(request, trustProxy))}`;
}

function logSecurityEvent(logger, event, handle, request, trustProxy) {
  try {
    logger({
      event,
      accountHash: securityHash(handle),
      sourceHash: securityHash(sourceAddress(request, trustProxy)),
      at: now()
    });
  } catch {
    // Security telemetry must never change the authentication result.
  }
}

function setBaseHeaders(response) {
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.setHeader("X-Content-Type-Options", "nosniff");
}

function sendJSON(response, status, body) {
  response.writeHead(status);
  response.end(JSON.stringify(body));
}

function sendNoContent(response) {
  response.removeHeader("Content-Type");
  response.writeHead(204);
  response.end();
}

function sendError(response, status, code, message, requestID) {
  sendJSON(response, status, {
    error: {
      status,
      code,
      message,
      requestID
    }
  });
}

function now() {
  return new Date().toISOString();
}

function expiresAt(sessionTtlMs) {
  return new Date(Date.now() + sessionTtlMs).toISOString();
}

async function main() {
  const started = await startAccountBackendServer(accountBackendOptionsFromEnvironment());
  console.log(`CurlPlan account backend listening on ${started.baseURL}`);
  console.log(`Storage: ${started.storagePath}`);

  let shuttingDown = false;
  const shutdown = async (signal) => {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Received ${signal}, closing account backend.`);
    try {
      await started.close();
    } finally {
      process.exit(0);
    }
  };
  process.on("SIGTERM", () => { shutdown("SIGTERM"); });
  process.on("SIGINT", () => { shutdown("SIGINT"); });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  });
}
