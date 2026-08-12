import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { startAccountBackendServer } from "../services/account-backend/server.mjs";

const tempDir = await mkdtemp(join(tmpdir(), "curlplan-account-backend-"));
const storagePath = join(tempDir, "state.json");
let service = await startAccountBackendServer({ storagePath, port: 0 });

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
  service = await startAccountBackendServer({ storagePath, port: 0 });
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
} finally {
  await service.close().catch(() => {});
  await rm(tempDir, { recursive: true, force: true });
}

async function request(method, path, { expected, token, body } = {}) {
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
  const parsed = text ? JSON.parse(text) : null;
  if (response.status !== expected) {
    throw new Error(`${method} ${path} returned ${response.status}, expected ${expected}: ${text}`);
  }
  return parsed;
}

function seasonFixture(name, homeClub) {
  return {
    schemaVersion: 4,
    setupComplete: true,
    profile: {
      name,
      initials: "DM",
      homeClub,
      homeProvince: "AB",
      season: "Season 2025-26 - backend verifier",
      demoMode: false,
      baseGames: 0,
      baseWins: 0
    },
    curlers: [],
    stops: [],
    visits: [],
    spiels: [],
    attendance: [],
    results: [],
    feed: [],
    bonspiels: []
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
