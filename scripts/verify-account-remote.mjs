// Runs AS 01, AS 02, and AS 03 against a deployed account backend over real HTTP.
// Unlike verify-account-backend.mjs (which boots a local server), this targets an
// already-running remote URL and is self-cleaning: it creates a uniquely handled
// throwaway account and deletes it at the end (AS 03), leaving the store untouched.
//
// Usage: CURLPLAN_ACCOUNT_BACKEND_URL=http://dominic:8787 node scripts/verify-account-remote.mjs
//    or: node scripts/verify-account-remote.mjs http://dominic:8787

const baseURL = (process.env.CURLPLAN_ACCOUNT_BACKEND_URL || process.argv[2] || "").replace(/\/$/, "");
if (!baseURL) {
  console.error("Set CURLPLAN_ACCOUNT_BACKEND_URL or pass the base URL as an argument.");
  process.exit(2);
}

const stamp = Date.now();
const handle = `verify-${stamp}`;
const password = `verify-pass-${stamp}`;

try {
  await request("GET", "/health", { expected: 200 });
  pass(`health endpoint responds at ${baseURL}`);

  const account = await request("POST", "/v1/accounts", {
    expected: 201,
    body: { handle, displayName: "Remote Verifier", homeClub: "Tailnet CC", password }
  });
  assert(account.status === "active", "new account should be active");
  pass("AS 01 creates an active account");

  const wrong = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: { handle, password: `${password}-nope`, deviceID: "device-a" }
  });
  assert(wrong.error.code === "INVALID_CREDENTIALS", "wrong password should be rejected");
  pass("AS 01 rejects sign in with the wrong password");

  const sessionA = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: { handle, password, deviceID: "device-a" }
  });
  assert(sessionA.state === "active", "device A session should be active");
  pass("AS 01 signs in on device A with server session");

  const season = seasonFixture("Remote Verifier", "Tailnet CC");
  const imported = await request("POST", "/v1/me/season/import-local", {
    expected: 201,
    token: sessionA.id,
    body: { season }
  });
  assert(imported.version === 1, "imported season should start at version 1");
  pass("AS 01 imports local season into account scope");

  await request("POST", "/v1/auth/sign-out", { expected: 204, token: sessionA.id });
  const afterSignOut = await request("GET", "/v1/me/season", { expected: 401, token: sessionA.id });
  assert(afterSignOut.error.code === "SESSION_INVALID", "signed out session should be rejected");
  pass("AS 01 revokes device A session on sign out");

  const sessionB = await request("POST", "/v1/auth/sign-in", {
    expected: 200,
    body: { handle, password, deviceID: "device-b" }
  });
  const restored = await request("GET", "/v1/me/season", { expected: 200, token: sessionB.id });
  assert(restored.body.profile.name === "Remote Verifier", "device B should restore account season");
  pass("AS 02 restores the same season on device B with handle and password");

  await request("DELETE", "/v1/me", { expected: 204, token: sessionB.id });
  const deletedSignIn = await request("POST", "/v1/auth/sign-in", {
    expected: 401,
    body: { handle, password, deviceID: "device-c" }
  });
  assert(deletedSignIn.error.code === "INVALID_CREDENTIALS", "deleted account should not sign in");
  const deletedSession = await request("GET", "/v1/me/season", { expected: 401, token: sessionB.id });
  assert(deletedSession.error.code === "SESSION_INVALID", "deleted account session should be revoked");
  pass("AS 03 delete account revokes sessions and blocks future sign in");

  console.log("\nAll deployed AS 01-03 checks passed.");
} catch (error) {
  console.error(`\nFAIL: ${error.message}`);
  process.exit(1);
}

async function request(method, path, { expected, token, body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(`${baseURL}${path}`, { method, headers, body: payload });
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
      initials: "RV",
      homeClub,
      homeProvince: "AB",
      season: "Season 2025-26 - remote verifier",
      demoMode: false,
      baseGames: 0,
      baseWins: 0
    },
    curlers: [], stops: [], visits: [], spiels: [],
    attendance: [], results: [], feed: [], bonspiels: []
  };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function pass(message) {
  console.log(`PASS ${message}`);
}
