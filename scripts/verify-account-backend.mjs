import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { startAccountBackendServer } from "../services/account-backend/server.mjs";

const tempDir = await mkdtemp(join(tmpdir(), "curlplan-account-backend-"));
const storagePath = join(tempDir, "state.json");
let failNextCommit = false;
const commitHook = async () => {
  if (!failNextCommit) return;
  failNextCommit = false;
  throw new Error("intentional commit failure");
};
let service = await startAccountBackendServer({ storagePath, port: 0, mode: "development", commitHook });

try {
  await request("GET", "/health", { expected: 200 });
  pass("health endpoint responds");

  const danaPassword = "granite-rocks-87";
  const account = await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "dana",
      displayName: "Dana Mercer",
      homeClub: "Calgary Granite CC",
      password: danaPassword
    }
  });
  assert(account.status === "active", "new account should be active");
  pass("AS 01 creates an active account");

  const weakPassword = await request("POST", "/v1/accounts", {
    expected: 422,
    body: {
      handle: "weak",
      displayName: "Weak Pass",
      homeClub: "Nowhere CC",
      password: "short"
    }
  });
  assert(weakPassword.error.code === "WEAK_PASSWORD", "short password should be rejected");
  pass("AS 01 rejects a password under the minimum length");

  const wrongPassword = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: {
      handle: "dana",
      password: "wrong-password-99",
      deviceID: "device-a"
    }
  });
  assert(wrongPassword.error.code === "INVALID_CREDENTIALS", "wrong password should be rejected");
  pass("AS 01 rejects sign in with the wrong password");

  const sessionA = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "dana",
      password: danaPassword,
      deviceID: "device-a"
    }
  });
  assert(sessionA.state === "active", "device A session should be active");
  pass("AS 01 signs in on device A with server session");

  const season = seasonFixture("Dana Mercer", "Calgary Granite CC");
  const imported = await request("POST", "/v1/me/season/import-local", {
    expected: 201,
    token: sessionA.id,
    body: { season }
  });
  assert(imported.version === 1, "imported season should start at version 1");
  assert(imported.body.profile.name === "Dana Mercer", "imported season should retain profile");
  pass("AS 01 imports local season into account scope");

  const exported = await request("POST", "/v1/me/export", {
    expected: 200,
    token: sessionA.id
  });
  assert(exported.join(",") === "account,profile,season", "export should include account, profile, and season");
  pass("AS 01 exports account sections after season import");

  await request("POST", "/v1/auth/sign-out", {
    expected: 204,
    token: sessionA.id
  });
  const signedOut = await request("GET", "/v1/me/season", {
    expected: 401,
    token: sessionA.id
  });
  assert(signedOut.error.code === "SESSION_INVALID", "signed out session should be rejected");
  pass("AS 01 revokes device A session on sign out");

  const sessionB = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "dana",
      password: danaPassword,
      deviceID: "device-b"
    }
  });
  const restored = await request("GET", "/v1/me/season", {
    expected: 200,
    token: sessionB.id
  });
  assert(restored.body.profile.name === "Dana Mercer", "device B should restore account season");
  pass("AS 02 restores the same season on device B");

  const changedSeason = {
    ...restored.body,
    profile: {
      ...restored.body.profile,
      homeClub: "Vernon Curling Club"
    }
  };
  const receipt = await request("POST", "/v1/me/season/changes", {
    expected: 200,
    token: sessionB.id,
    body: {
      baseVersion: restored.version,
      updatedBody: changedSeason,
      domains: ["profile"],
      clientMutationID: "client-1"
    }
  });
  assert(receipt.serverVersion === 2, "fresh change should advance server version");
  pass("AS 04 sync receipt advances server version");

  const retriedReceipt = await request("POST", "/v1/me/season/changes", {
    expected: 200,
    token: sessionB.id,
    body: {
      baseVersion: restored.version,
      updatedBody: changedSeason,
      domains: ["profile"],
      clientMutationID: "client-1"
    }
  });
  assert(retriedReceipt.id === receipt.id && retriedReceipt.serverVersion === 2,
    "same client mutation should return its original receipt");
  pass("AS 04 idempotent retry does not apply the season change twice");

  const stale = await request("POST", "/v1/me/season/changes", {
    expected: 409,
    token: sessionB.id,
    body: {
      baseVersion: restored.version,
      updatedBody: changedSeason,
      domains: ["profile"],
      clientMutationID: "client-stale"
    }
  });
  assert(stale.error.code === "VERSION_CONFLICT", "stale base version should conflict");
  pass("AS 05 stale sync receives conflict envelope");

  const concurrentBodyA = {
    ...changedSeason,
    profile: { ...changedSeason.profile, homeClub: "Concurrent A CC" }
  };
  const concurrentBodyB = {
    ...changedSeason,
    profile: { ...changedSeason.profile, homeClub: "Concurrent B CC" }
  };
  const concurrentResults = await Promise.all([
    requestUnchecked("POST", "/v1/me/season/changes", {
      token: sessionB.id,
      body: {
        baseVersion: 2,
        updatedBody: concurrentBodyA,
        domains: ["profile"],
        clientMutationID: "concurrent-a"
      }
    }),
    requestUnchecked("POST", "/v1/me/season/changes", {
      token: sessionB.id,
      body: {
        baseVersion: 2,
        updatedBody: concurrentBodyB,
        domains: ["profile"],
        clientMutationID: "concurrent-b"
      }
    })
  ]);
  assert(concurrentResults.map(result => result.status).sort().join(",") === "200,409",
    "serialized same-user changes should commit exactly one version");
  const concurrentSeason = await request("GET", "/v1/me/season", {
    expected: 200,
    token: sessionB.id
  });
  assert(concurrentSeason.version === 3 && ["Concurrent A CC", "Concurrent B CC"].includes(concurrentSeason.body.profile.homeClub),
    "concurrent change winner should be durable at version 3");
  pass("AS 05 serializes concurrent same-user season changes without a lost committed update");

  failNextCommit = true;
  const failedCommit = await request("POST", "/v1/me/season/changes", {
    expected: 500,
    token: sessionB.id,
    body: {
      baseVersion: 3,
      updatedBody: {
        ...concurrentSeason.body,
        profile: { ...concurrentSeason.body.profile, homeClub: "Must Not Publish CC" }
      },
      domains: ["profile"],
      clientMutationID: "failed-commit"
    }
  });
  assert(failedCommit.error.code === "INTERNAL_ERROR", "intentional commit failure should return a closed error");
  const afterFailedCommit = await request("GET", "/v1/me/season", {
    expected: 200,
    token: sessionB.id
  });
  assert(afterFailedCommit.version === 3 && afterFailedCommit.body.profile.homeClub !== "Must Not Publish CC",
    "failed durable write must leave published state unchanged");
  pass("failed development-service commit rolls memory back to its durable snapshot");

  const malformedPassword = "malformed-season-87";
  await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "malformed",
      displayName: "Malformed Import",
      homeClub: "Nowhere CC",
      password: malformedPassword
    }
  });
  const malformedSession = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "malformed",
      password: malformedPassword,
      deviceID: "malformed-phone"
    }
  });
  const hostileSeason = JSON.parse(JSON.stringify({ season: seasonFixture("Malformed Import", "Nowhere CC") }));
  hostileSeason.season.state = JSON.parse(`{"__proto__":{"polluted":true}}`);
  const hostileImport = await request("POST", "/v1/me/season/import-local", {
    expected: 422,
    token: malformedSession.id,
    body: hostileSeason
  });
  assert(hostileImport.error.code === "INVALID_SEASON_DOCUMENT" && Object.prototype.polluted === undefined,
    "dangerous season keys should be rejected");
  const unknownImport = await request("POST", "/v1/me/season/import-local", {
    expected: 422,
    token: malformedSession.id,
    body: { season: { ...seasonFixture("Malformed Import", "Nowhere CC"), unexpected: true } }
  });
  assert(unknownImport.error.code === "INVALID_SEASON_DOCUMENT", "unknown season fields should be rejected");
  const deeplyNestedSeason = seasonFixture("Malformed Import", "Nowhere CC");
  let nested = {};
  deeplyNestedSeason.state.posts = [nested];
  for (let index = 0; index < 40; index += 1) {
    nested.child = {};
    nested = nested.child;
  }
  const deepImport = await request("POST", "/v1/me/season/import-local", {
    expected: 422,
    token: malformedSession.id,
    body: { season: deeplyNestedSeason }
  });
  assert(deepImport.error.code === "INVALID_SEASON_DOCUMENT", "deep season structure should be rejected");
  const keyHeavySeason = seasonFixture("Malformed Import", "Nowhere CC");
  keyHeavySeason.state.follows = Object.fromEntries(Array.from({ length: 25_001 }, (_, index) => [`curler-${index}`, false]));
  const keyHeavyImport = await request("POST", "/v1/me/season/import-local", {
    expected: 422,
    token: malformedSession.id,
    body: { season: keyHeavySeason }
  });
  assert(keyHeavyImport.error.code === "INVALID_SEASON_DOCUMENT", "key-heavy season should be rejected");
  const oversizedSeason = seasonFixture("Malformed Import", "Nowhere CC");
  oversizedSeason.state.posts = [{ id: "large", body: "x".repeat(600_000) }];
  const oversizedImport = await request("POST", "/v1/me/season/import-local", {
    expected: 413,
    token: malformedSession.id,
    body: { season: oversizedSeason }
  });
  assert(oversizedImport.error.code === "SEASON_TOO_LARGE", "oversized season should be rejected");
  pass("account season import rejects hostile, unknown, deep, key-heavy, and oversized documents before storage");

  const samPassword = "vernon-hammer-12";
  const joPassword = "kelowna-skip-34";
  const sam = await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "sam",
      displayName: "Sam Reid",
      homeClub: "Vernon CC",
      password: samPassword
    }
  });
  const jo = await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "jo",
      displayName: "Jo Mara",
      homeClub: "Kelowna CC",
      password: joPassword
    }
  });
  const samSession = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "sam",
      password: samPassword,
      deviceID: "sam-phone"
    }
  });
  const joSession = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "jo",
      password: joPassword,
      deviceID: "jo-phone"
    }
  });

  const privateSearch = await request("GET", "/v1/profiles/search?q=sam", {
    expected: 200,
    token: sessionB.id
  });
  assert(privateSearch.length === 0, "private profile should not be searchable");
  await request("PATCH", "/v1/me/privacy", {
    expected: 204,
    token: samSession.id,
    body: {
      visibility: "public",
      searchable: true
    }
  });
  const publicSearch = await request("GET", "/v1/profiles/search?q=sam", {
    expected: 200,
    token: sessionB.id
  });
  assert(publicSearch.map((profile) => profile.handle).join(",") === "sam", "public searchable profile should be discoverable");
  pass("AS 06 profile search respects private default and public opt-in");

  const follow = await request("POST", "/v1/relationships", {
    expected: 201,
    token: sessionB.id,
    body: {
      targetID: sam.id
    }
  });
  assert(follow.kind === "follow" && follow.state === "accepted", "follow should create an accepted edge");
  await request("DELETE", "/v1/relationships/follow", {
    expected: 204,
    token: sessionB.id,
    body: {
      targetID: sam.id
    }
  });
  pass("AS 07 follow and unfollow update server graph state");

  await request("POST", "/v1/blocks", {
    expected: 204,
    token: sessionB.id,
    body: {
      targetID: sam.id
    }
  });
  const blockedSearch = await request("GET", "/v1/profiles/search?q=sam", {
    expected: 200,
    token: sessionB.id
  });
  assert(blockedSearch.length === 0, "blocked profile should disappear from search");
  const blockedFollow = await request("POST", "/v1/relationships", {
    expected: 403,
    token: samSession.id,
    body: {
      targetID: account.id
    }
  });
  assert(blockedFollow.error.code === "BLOCKED", "blocked account should not create follow edge");
  pass("AS 08 block state is enforced by search and relationship APIs");

  const scorecard = await request("POST", "/v1/shared-objects", {
    expected: 201,
    token: sessionB.id,
    body: {
      kind: "scorecard",
      title: "Sheet 4",
      visibility: "members_only"
    }
  });
  const nonMemberInteraction = await request("POST", "/v1/interactions", {
    expected: 403,
    token: joSession.id,
    body: {
      objectID: scorecard.id,
      kind: "rsvp",
      body: "going"
    }
  });
  assert(nonMemberInteraction.error.code === "NOT_MEMBER", "non-members should not interact with member-only objects");
  await request("POST", `/v1/shared-objects/${scorecard.id}/members`, {
    expected: 204,
    token: sessionB.id,
    body: {
      accountID: jo.id,
      role: "viewer"
    }
  });
  pass("AS 09 shared object membership controls RSVP access");

  const unauthorizedTitle = await request("PATCH", `/v1/shared-objects/${scorecard.id}`, {
    expected: 403,
    token: joSession.id,
    body: {
      title: "Unauthorized edit"
    }
  });
  assert(unauthorizedTitle.error.code === "INSUFFICIENT_ROLE", "viewer should not edit shared object title");
  pass("AS 10 shared object role boundary rejects unauthorized edit");

  const reaction = await request("POST", "/v1/interactions", {
    expected: 201,
    token: joSession.id,
    body: {
      objectID: scorecard.id,
      kind: "reaction",
      body: "stone"
    }
  });
  await request("DELETE", `/v1/interactions/${reaction.id}`, {
    expected: 204,
    token: joSession.id
  });
  const comment = await request("POST", "/v1/interactions", {
    expected: 201,
    token: joSession.id,
    body: {
      objectID: scorecard.id,
      kind: "comment",
      body: "needs review"
    }
  });
  const report = await request("POST", "/v1/reports", {
    expected: 201,
    token: sessionB.id,
    body: {
      interactionID: comment.id,
      reason: "unsafe"
    }
  });
  await request("POST", `/v1/moderation/reports/${report.id}/hide`, {
    expected: 204,
    token: sessionB.id
  });
  pass("AS 11 and AS 12 interactions support create, delete, report, and moderation hide");

  await request("DELETE", "/v1/me", {
    expected: 204,
    token: sessionB.id
  });
  const deletedSignIn = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: {
      handle: "dana",
      password: danaPassword,
      deviceID: "device-c"
    }
  });
  assert(deletedSignIn.error.code === "INVALID_CREDENTIALS", "deleted account should not sign in");
  pass("AS 03 delete account blocks future sign in");

  const deletedObjectInteraction = await request("POST", "/v1/interactions", {
    expected: 404,
    token: joSession.id,
    body: {
      objectID: scorecard.id,
      kind: "reaction",
      body: "after delete"
    }
  });
  assert(deletedObjectInteraction.error.code === "NOT_FOUND", "deleted account owned shared object should be removed");
  pass("AS 03 delete account removes owned shared object access");

  await service.close();
  service = await startAccountBackendServer({ storagePath, port: 0, mode: "development", commitHook });
  const persistedDelete = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: {
      handle: "dana",
      password: danaPassword,
      deviceID: "device-d"
    }
  });
  assert(persistedDelete.error.code === "INVALID_CREDENTIALS", "deleted state should survive backend restart");
  pass("AS 03 deletion survives backend restart");

  const manifest = JSON.parse(await readFile(storagePath, "utf8"));
  const recordBlobs = await readdir(`${storagePath}.records`);
  assert(manifest.format === "curlplan-account-records-v1" && Object.keys(manifest.records).length > 3 && recordBlobs.length > 3,
    "development persistence should use a manifest and content-addressed record blobs");
  pass("development storage commits per-record blobs behind an atomic manifest instead of rewriting one system document");

  await service.close();
  await writeFile(storagePath, "{corrupt-primary", "utf8");
  service = await startAccountBackendServer({ storagePath, port: 0, mode: "development", commitHook });
  const recoveredDelete = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: {
      handle: "dana",
      password: danaPassword,
      deviceID: "device-recovery"
    }
  });
  assert(recoveredDelete.error.code === "INVALID_CREDENTIALS", "backup recovery should retain deleted account state");
  pass("atomic snapshot backup recovers from a malformed primary file");

  await service.close();
  service = await startAccountBackendServer({ storagePath, port: 0, mode: "quarantined" });
  const quarantinedHealth = await request("GET", "/health", { expected: 200 });
  assert(quarantinedHealth.writable === false, "quarantined health should disclose a read-only rejected plane");
  const quarantinedWrite = await request("POST", "/v1/accounts", {
    expected: 503,
    body: {
      handle: "production",
      displayName: "Production Attempt",
      homeClub: "Nowhere CC",
      password: "not-accepted-87"
    }
  });
  assert(quarantinedWrite.error.code === "PLANE_QUARANTINED", "rejected plane must fail closed for writes");
  pass("rejected custom plane cannot accept production writes");
} finally {
  await service.close().catch(() => {});
  await rm(tempDir, { recursive: true, force: true });
}

async function request(method, path, { expected, token, body } = {}) {
  const result = await requestUnchecked(method, path, { token, body });
  if (result.status !== expected) {
    throw new Error(`${method} ${path} returned ${result.status}, expected ${expected}: ${result.text}`);
  }
  return result.body;
}

async function requestUnchecked(method, path, { token, body } = {}) {
  const headers = {};
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  let payload;
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(`${service.baseURL}${path}`, {
    method,
    headers,
    body: payload
  });
  const text = await response.text();
  return {
    status: response.status,
    text,
    body: text ? JSON.parse(text) : null
  };
}

function seasonFixture(name, homeClub) {
  return {
    schemaVersion: 4,
    profile: {
      name,
      homeClub,
      province: "AB"
    },
    state: {
      addedCurlers: [],
      addedSpiels: [],
      follows: {},
      likes: {},
      joins: {},
      posts: [],
      visits: {},
      reviews: {},
      iceReads: {},
      threads: {}
    }
  };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function pass(message) {
  console.log(`PASS ${message}`);
}
