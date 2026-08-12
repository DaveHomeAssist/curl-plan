import { createServer } from "node:http";
import { randomUUID, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const MAX_JSON_BYTES = 1_000_000;
const DEFAULT_STORAGE_PATH = resolve("/tmp/curlplan-account-backend-state.json");

class BackendError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

class AccountBackendStore {
  constructor(storagePath = DEFAULT_STORAGE_PATH) {
    this.storagePath = storagePath;
    this.state = emptyState();
    this.loaded = false;
  }

  async load() {
    if (this.loaded) {
      return;
    }
    try {
      const raw = await readFile(this.storagePath, "utf8");
      this.state = normalizeState(JSON.parse(raw));
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
      this.state = emptyState();
    }
    this.loaded = true;
  }

  async save() {
    await mkdir(dirname(this.storagePath), { recursive: true });
    const tempPath = `${this.storagePath}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(tempPath, `${JSON.stringify(this.state, null, 2)}\n`);
    await rename(tempPath, this.storagePath);
  }

  nextID(prefix) {
    this.state.counter += 1;
    return `${prefix}-${randomUUID()}`;
  }
}

export function createAccountBackendServer({ storagePath = DEFAULT_STORAGE_PATH } = {}) {
  const store = new AccountBackendStore(storagePath);

  return createServer(async (request, response) => {
    const requestID = randomUUID();
    setBaseHeaders(response);

    if (request.method === "OPTIONS") {
      response.writeHead(204);
      response.end();
      return;
    }

    try {
      await store.load();
      const url = new URL(request.url ?? "/", "http://localhost");
      await routeRequest({ request, response, store, url, requestID });
    } catch (error) {
      if (error instanceof BackendError) {
        sendError(response, error.status, error.code, error.message, requestID);
        return;
      }
      sendError(response, 500, "INTERNAL_ERROR", "Unexpected account backend failure.", requestID);
    }
  });
}

export async function startAccountBackendServer({ storagePath = DEFAULT_STORAGE_PATH, port = 0, hostname = "127.0.0.1" } = {}) {
  const server = createAccountBackendServer({ storagePath });
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

async function routeRequest({ request, response, store, url, requestID }) {
  const method = request.method ?? "GET";
  const path = url.pathname;

  if (method === "GET" && path === "/health") {
    sendJSON(response, 200, { ok: true });
    return;
  }

  if (method === "POST" && path === "/v1/accounts") {
    const body = await readJSON(request);
    const handle = requiredText(body, "handle").toLowerCase();
    const displayName = requiredText(body, "displayName");
    const homeClub = requiredText(body, "homeClub");
    const password = requiredPassword(body, "password");
    const handleTaken = Object.values(store.state.profiles).some((profile) => profile.handle.toLowerCase() === handle);
    if (handleTaken) {
      throw new BackendError(409, "HANDLE_TAKEN", "That handle is already reserved.");
    }
    const account = {
      id: store.nextID("acct"),
      createdAt: now(),
      status: "active",
      deletedAt: null
    };
    store.state.accounts[account.id] = account;
    store.state.credentials[account.id] = hashPassword(password);
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
    const handle = requiredText(body, "handle").toLowerCase();
    const password = requiredText(body, "password");
    const deviceID = requiredText(body, "deviceID");
    const profile = Object.values(store.state.profiles).find((entry) => entry.handle.toLowerCase() === handle);
    const accountID = profile?.accountID;
    const account = accountID ? store.state.accounts[accountID] : null;
    // Generic credential failure: never reveal whether the handle exists.
    if (!account || account.status === "deleted" || !verifyPassword(password, store.state.credentials[accountID])) {
      throw new BackendError(401, "INVALID_CREDENTIALS", "Handle or password is incorrect.");
    }
    const session = {
      id: store.nextID("sess"),
      accountID,
      deviceID,
      createdAt: now(),
      expiresAt: expiresAt(),
      state: "active"
    };
    store.state.sessions[session.id] = session;
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
    const updatedBody = requiredObject(body, "updatedBody");
    const clientMutationID = requiredText(body, "clientMutationID");
    const domains = requiredStringArray(body, "domains");
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
    if (isBlockedBetween(store.state, accountID, memberAccountID)) {
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
    requireInteraction(store.state, interactionID);
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

function requiredInteger(body, key) {
  if (!Number.isInteger(body?.[key])) {
    throw new BackendError(422, "VALIDATION_FAILED", `${key} must be an integer.`);
  }
  return body[key];
}

const MIN_PASSWORD_LENGTH = 8;

function requiredPassword(body, key) {
  const value = body?.[key];
  if (typeof value !== "string" || value.length < MIN_PASSWORD_LENGTH) {
    throw new BackendError(422, "WEAK_PASSWORD", `${key} must be at least ${MIN_PASSWORD_LENGTH} characters.`);
  }
  return value;
}

function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return { salt, hash };
}

function verifyPassword(password, credential) {
  if (!credential || typeof credential.salt !== "string" || typeof credential.hash !== "string") {
    return false;
  }
  const expected = Buffer.from(credential.hash, "hex");
  const actual = scryptSync(password, credential.salt, expected.length);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
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
  const season = requiredObject(body, "season");
  if (!Number.isInteger(season.schemaVersion)) {
    throw new BackendError(422, "VALIDATION_FAILED", "season.schemaVersion must be an integer.");
  }
  if (season.schemaVersion > 4) {
    throw new BackendError(422, "SCHEMA_UNSUPPORTED", "CurlPlan account backend accepts account season payload schema 4 or earlier.");
  }
  return season;
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

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

function expiresAt() {
  return new Date(Date.now() + SESSION_TTL_MS).toISOString();
}

async function main() {
  const storagePath = process.env.CURLPLAN_ACCOUNT_BACKEND_STORE || process.argv[2] || DEFAULT_STORAGE_PATH;
  const port = Number.parseInt(process.env.PORT || "8787", 10);
  const hostname = process.env.HOST || "127.0.0.1";
  const started = await startAccountBackendServer({ storagePath, port, hostname });
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
