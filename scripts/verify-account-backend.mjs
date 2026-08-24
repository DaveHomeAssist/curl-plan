import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { scryptSync } from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  accountBackendOptionsFromEnvironment,
  startAccountBackendServer
} from "../services/account-backend/server.mjs";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));
const tempDir = await mkdtemp(join(tmpdir(), "curlplan-account-backend-"));
const storagePath = join(tempDir, "state.json");
let failNextCommit = false;
const telemetry = [];
const commitHook = async () => {
  if (!failNextCommit) return;
  failNextCommit = false;
  throw new Error("intentional commit failure");
};
const developmentOptions = {
  storagePath,
  port: 0,
  mode: "development",
  commitHook,
  allowedOrigins: ["https://app.example.test"],
  trustProxy: true,
  signInLimit: 4,
  signInWindowMs: 60_000,
  maxAccounts: 100,
  maxSessionsPerAccount: 3,
  logger: event => telemetry.push(event)
};
let service = await startAccountBackendServer(developmentOptions);

try {
  const configuredOptions = accountBackendOptionsFromEnvironment({
    PORT: "9443",
    HOST: "127.0.0.2",
    CURLPLAN_ACCOUNT_BACKEND_STORE: "/tmp/curlplan-configured.json",
    CURLPLAN_ACCOUNT_BACKEND_MODE: "development",
    CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS: "https://one.example, https://two.example",
    CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY: "true",
    CURLPLAN_ACCOUNT_BACKEND_REQUEST_TIMEOUT_MS: "12000",
    CURLPLAN_ACCOUNT_BACKEND_SESSION_TTL_MS: "60000",
    CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_LIMIT: "7",
    CURLPLAN_ACCOUNT_BACKEND_SIGN_IN_WINDOW_MS: "90000",
    CURLPLAN_ACCOUNT_BACKEND_MAX_RATE_BUCKETS: "500",
    CURLPLAN_ACCOUNT_BACKEND_MAX_ACCOUNTS: "250",
    CURLPLAN_ACCOUNT_BACKEND_MAX_SESSIONS_PER_ACCOUNT: "3"
  });
  assert(configuredOptions.port === 9443 && configuredOptions.hostname === "127.0.0.2",
    "environment parser should own the listener boundary");
  assert(configuredOptions.allowedOrigins.length === 2 && configuredOptions.trustProxy === true,
    "environment parser should own exact CORS and trusted-proxy boundaries");
  assert(configuredOptions.requestTimeoutMs === 12000 && configuredOptions.sessionTtlMs === 60000,
    "environment parser should own timeout and session-expiry boundaries");
  assert(configuredOptions.signInLimit === 7 && configuredOptions.signInWindowMs === 90000 &&
    configuredOptions.maxRateBuckets === 500 && configuredOptions.maxAccounts === 250 &&
    configuredOptions.maxSessionsPerAccount === 3,
  "environment parser should own abuse and storage caps");
  const boundedOptions = accountBackendOptionsFromEnvironment({
    PORT: "70000",
    CURLPLAN_ACCOUNT_BACKEND_MODE: "production",
    CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS: "*, https://valid.example/path, https://valid.example",
    CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY: "TRUE",
    CURLPLAN_ACCOUNT_BACKEND_REQUEST_TIMEOUT_MS: "999999",
    CURLPLAN_ACCOUNT_BACKEND_SESSION_TTL_MS: "0",
    CURLPLAN_ACCOUNT_BACKEND_MAX_ACCOUNTS: "NaN"
  });
  assert(boundedOptions.port === 8787 && boundedOptions.requestTimeoutMs === 15000 &&
    boundedOptions.sessionTtlMs === 30 * 24 * 60 * 60 * 1000 && boundedOptions.maxAccounts === 10000,
  "invalid numeric boundaries should fail closed to documented defaults");
  assert(boundedOptions.mode === "quarantined" && boundedOptions.trustProxy === false &&
    boundedOptions.allowedOrigins.length === 1 && boundedOptions.allowedOrigins[0] === "https://valid.example",
  "invalid modes, proxy flags, wildcards, and non-origin URLs should fail closed");
  pass("runtime environment controls parse into bounded server options");

  await request("GET", "/health", { expected: 200 });
  pass("health endpoint responds");

  const dockerfile = await readFile(join(repoRoot, "services/account-backend/Dockerfile"), "utf8");
  const securityAuthority = await readFile(join(repoRoot, "docs/SECURITY.md"), "utf8").catch(() => "");
  const authView = await readFile(join(repoRoot, "ios/CurlPlan/AuthView.swift"), "utf8");
  const appEntry = await readFile(join(repoRoot, "ios/CurlPlan/CurlPlanApp.swift"), "utf8");
  assert([
    "CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS",
    "CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY",
    "CURLPLAN_ACCOUNT_BACKEND_REQUEST_TIMEOUT_MS",
    "CURLPLAN_ACCOUNT_BACKEND_SESSION_TTL_MS"
  ].every(token => dockerfile.includes(token)),
  "container contract should expose CORS, trusted-proxy, timeout, and session boundaries");
  assert([
    "Production authority",
    "TLS termination",
    "Trusted proxy",
    "Session expiry",
    "Recovery",
    "Incident owner"
  ].every(token => securityAuthority.includes(token)),
  "docs/SECURITY.md should own every P4 transport and incident boundary");
  assert(authView.includes("@EnvironmentObject var accountRuntime") &&
    authView.includes("SecureField") &&
    authView.includes("Retry account setup") &&
    authView.includes("Roll back partial account"),
  "AuthView should expose password-gated retry and rollback only for partial account recovery");
  assert(appEntry.includes("resolveDevelopmentBackendURL") &&
    appEntry.includes(".environmentObject(accountRuntime)"),
  "app entry should inject an explicitly enabled development account runtime");
  pass("P4 native recovery and transport authority surfaces are wired explicitly");

  const allowedPreflight = await requestUnchecked("OPTIONS", "/v1/auth/sign-in", {
    headers: {
      Origin: "https://app.example.test",
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "content-type"
    }
  });
  assert(allowedPreflight.status === 204 &&
    allowedPreflight.headers["access-control-allow-origin"] === "https://app.example.test" &&
    allowedPreflight.headers["access-control-allow-credentials"] === "true" &&
    allowedPreflight.headers.vary.includes("Origin"),
  "allowed preflight should emit credentialed origin-specific CORS");
  const deniedPreflight = await requestUnchecked("OPTIONS", "/v1/auth/sign-in", {
    headers: {
      Origin: "https://evil.example.test",
      "Access-Control-Request-Method": "POST",
      "Access-Control-Request-Headers": "content-type"
    }
  });
  assert(deniedPreflight.status === 403 && !deniedPreflight.headers["access-control-allow-origin"],
    "disallowed preflight should fail without CORS authority");
  pass("CORS preflight is explicit, credentialed, origin-allowlisted, and fail-closed");

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

  const unicodePassword = "curling-\u212b-87";
  await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "h\u212bndle",
      displayName: "Unicode Password",
      homeClub: "Normalization CC",
      password: unicodePassword
    }
  });
  const unicodeSession = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: {
      handle: "hA\u030andle",
      password: "curling-A\u030a-87",
      deviceID: "unicode-phone"
    }
  });
  assert(unicodeSession.state === "active", "canonically equivalent password should sign in");
  pass("handle and password normalization are identical at creation and sign in");

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

  const timingPassword = "timing-hammer-87";
  await request("POST", "/v1/accounts", {
    expected: 201,
    body: {
      handle: "timing",
      displayName: "Timing Probe",
      homeClub: "Timing CC",
      password: timingPassword
    }
  });
  const measureSignIn = async (handle, password, source) => {
    const started = performance.now();
    const result = await requestUnchecked("POST", "/v1/auth/sign-in", {
      headers: { "X-Forwarded-For": source },
      body: { handle, password, deviceID: "timing-device" }
    });
    return { status: result.status, elapsed: performance.now() - started };
  };
  const wrongTiming = await Promise.all([
    measureSignIn("timing", "wrong-timing-1", "198.51.100.10"),
    measureSignIn("timing", "wrong-timing-2", "198.51.100.11")
  ]);
  const unknownTiming = await Promise.all([
    measureSignIn("missing-a", "wrong-timing-1", "198.51.100.12"),
    measureSignIn("missing-b", "wrong-timing-2", "198.51.100.13")
  ]);
  const mean = values => values.reduce((total, value) => total + value.elapsed, 0) / values.length;
  const timingRatio = Math.max(mean(wrongTiming), mean(unknownTiming)) / Math.max(1, Math.min(mean(wrongTiming), mean(unknownTiming)));
  assert(wrongTiming.every(result => result.status === 401) && unknownTiming.every(result => result.status === 401) && timingRatio < 3,
    `known/unknown handle timing ratio should remain bounded, got ${timingRatio.toFixed(2)}`);
  pass("handle enumeration timing performs equivalent asynchronous password work");

  const limitedAttempts = [];
  for (let index = 0; index < 5; index += 1) {
    limitedAttempts.push(await requestUnchecked("POST", "/v1/auth/sign-in", {
      headers: { "X-Forwarded-For": "203.0.113.20" },
      body: { handle: "timing", password: `rate-wrong-${index}`, deviceID: "rate-device" }
    }));
  }
  assert(limitedAttempts.slice(0, 4).every(result => result.status === 401) && limitedAttempts[4].status === 429,
    "fifth same-account/source attempt should be rate-limited");
  const alternateSource = await requestUnchecked("POST", "/v1/auth/sign-in", {
    headers: { "X-Forwarded-For": "203.0.113.21" },
    body: { handle: "timing", password: "rate-wrong-other", deviceID: "rate-device" }
  });
  assert(alternateSource.status === 401, "different source should retain an independent limiter bucket");
  assert(telemetry.length > 0 && !JSON.stringify(telemetry).includes("timing") && !JSON.stringify(telemetry).includes(timingPassword),
    "abuse telemetry should be present without raw handles or passwords");
  pass("sign in is rate-limited by account and trusted source with abuse-safe telemetry");

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

  await request("POST", `/v1/shared-objects/${scorecard.id}/members`, {
    expected: 204,
    token: sessionB.id,
    body: { accountID: jo.id, role: "admin" }
  });
  await request("PATCH", `/v1/shared-objects/${scorecard.id}`, {
    expected: 204,
    token: joSession.id,
    body: { title: "Authorized before block" }
  });
  await request("POST", "/v1/blocks", {
    expected: 204,
    token: sessionB.id,
    body: { targetID: jo.id }
  });
  const staleAdmin = await request("PATCH", `/v1/shared-objects/${scorecard.id}`, {
    expected: 403,
    token: joSession.id,
    body: { title: "Stale admin bypass" }
  });
  assert(staleAdmin.error.code === "BLOCKED" || staleAdmin.error.code === "INSUFFICIENT_ROLE",
    "blocked stale admin should lose direct mutation authority");
  const blockedMessage = await request("POST", "/v1/interactions", {
    expected: 403,
    token: joSession.id,
    body: { objectID: scorecard.id, kind: "message", body: "direct bypass" }
  });
  assert(blockedMessage.error.code === "BLOCKED", "blocked member should not message through direct API");
  const blockedReinvite = await request("POST", `/v1/shared-objects/${scorecard.id}/members`, {
    expected: 403,
    token: sessionB.id,
    body: { accountID: jo.id, role: "viewer" }
  });
  assert(blockedReinvite.error.code === "BLOCKED", "blocked account should not be re-invited");
  pass("block revokes membership and stale roles, messaging, direct mutations, and future invitations in both directions");

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
  service = await startAccountBackendServer(developmentOptions);
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
  assert(recordBlobs.length === new Set(Object.values(manifest.records)).size,
    "unreferenced content-addressed records should be pruned after primary and backup commit");
  pass("development storage commits per-record blobs behind an atomic manifest instead of rewriting one system document");

  await service.close();
  await writeFile(storagePath, "{corrupt-primary", "utf8");
  service = await startAccountBackendServer(developmentOptions);
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

  await service.close();
  const legacyStoragePath = join(tempDir, "legacy-state.json");
  const legacyPassword = "legacy-\u212b-87";
  const legacySalt = "00112233445566778899aabbccddeeff";
  await writeFile(legacyStoragePath, JSON.stringify({
    accounts: {
      "acct-legacy": { id: "acct-legacy", createdAt: new Date().toISOString(), status: "active", deletedAt: null }
    },
    credentials: {
      "acct-legacy": { salt: legacySalt, hash: scryptSync(legacyPassword, legacySalt, 64).toString("hex") }
    },
    profiles: {
      "acct-legacy": {
        accountID: "acct-legacy",
        handle: "legacy",
        displayName: "Legacy Credential",
        homeClub: "Migration CC",
        avatarURL: null,
        visibility: "private",
        searchable: false
      }
    }
  }), "utf8");
  service = await startAccountBackendServer({ ...developmentOptions, storagePath: legacyStoragePath });
  await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: { handle: "legacy", password: legacyPassword, deviceID: "legacy-device" }
  });
  await service.close();
  const legacyManifest = JSON.parse(await readFile(legacyStoragePath, "utf8"));
  const legacyCredentialBlob = legacyManifest.records[`credentials/${encodeURIComponent("acct-legacy")}`];
  const migratedCredential = JSON.parse(await readFile(`${legacyStoragePath}.records/${legacyCredentialBlob}`, "utf8"));
  assert(migratedCredential.algorithm === "scrypt-v1" && migratedCredential.normalization === "NFKC",
    "successful legacy sign in should migrate the credential scheme deliberately");
  service = await startAccountBackendServer({ ...developmentOptions, storagePath: legacyStoragePath });
  await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: { handle: "legacy", password: "legacy-A\u030a-87", deviceID: "migrated-device" }
  });
  pass("legacy raw-password scrypt records migrate once to versioned NFKC credentials");

  await service.close();
  service = await startAccountBackendServer({
    ...developmentOptions,
    storagePath: join(tempDir, "session-state.json"),
    maxSessionsPerAccount: 2,
    sessionTtlMs: 10
  });
  await request("POST", "/v1/accounts", {
    expected: 201,
    body: { handle: "session", displayName: "Session Bounds", homeClub: "Session CC", password: "session-pass-87" }
  });
  const boundedSessions = [];
  for (let index = 0; index < 3; index += 1) {
    boundedSessions.push(await request("POST", "/v1/auth/sign-in", {
      expected: 200,
      body: { handle: "session", password: "session-pass-87", deviceID: `session-device-${index}` }
    }));
  }
  const revokedByQuota = await request("POST", "/v1/me/export", {
    expected: 401,
    token: boundedSessions[0].id
  });
  assert(revokedByQuota.error.code === "SESSION_INVALID", "oldest active session should be revoked at the quota");
  await new Promise(resolve => setTimeout(resolve, 20));
  const expiredSession = await request("POST", "/v1/me/export", {
    expected: 401,
    token: boundedSessions[2].id
  });
  assert(expiredSession.error.code === "SESSION_EXPIRED", "session expiry should be enforced on every request");
  pass("active session count and server-side expiry are bounded and enforced");

  await service.close();
  service = await startAccountBackendServer({
    ...developmentOptions,
    storagePath: join(tempDir, "quota-state.json"),
    maxAccounts: 1
  });
  await request("POST", "/v1/accounts", {
    expected: 201,
    body: { handle: "quota-a", displayName: "Quota A", homeClub: "Quota CC", password: "quota-pass-87" }
  });
  const quota = await request("POST", "/v1/accounts", {
    expected: 507,
    body: { handle: "quota-b", displayName: "Quota B", homeClub: "Quota CC", password: "quota-pass-87" }
  });
  assert(quota.error.code === "ACCOUNT_QUOTA_EXCEEDED", "account quota should bound persistent growth");
  pass("account and session quotas bound rejected-plane storage growth");
} finally {
  await service.close().catch(() => {});
  await rm(tempDir, { recursive: true, force: true });
}

async function request(method, path, { expected, token, body, headers } = {}) {
  const result = await requestUnchecked(method, path, { token, body, headers });
  if (result.status !== expected) {
    throw new Error(`${method} ${path} returned ${result.status}, expected ${expected}: ${result.text}`);
  }
  return result.body;
}

async function requestUnchecked(method, path, { token, body, headers: suppliedHeaders = {} } = {}) {
  const headers = { ...suppliedHeaders };
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
    body: text ? JSON.parse(text) : null,
    headers: Object.fromEntries(response.headers.entries())
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
