#!/usr/bin/env node

import { connect } from "node:tls";

const baseURL = requiredURL("CURLPLAN_STAGING_URL");
const allowedOrigin = requiredURL("CURLPLAN_STAGING_ORIGIN").origin;
const token = required("CURLPLAN_STAGING_TOKEN");
const expectedAudience = process.env.CURLPLAN_STAGING_AUDIENCE || "curlplan-api";
const disallowedOrigin = process.env.CURLPLAN_STAGING_DISALLOWED_ORIGIN || "https://untrusted.invalid";

if (baseURL.protocol !== "https:") fail("CURLPLAN_STAGING_URL must use HTTPS");
if (new URL(allowedOrigin).protocol !== "https:") fail("CURLPLAN_STAGING_ORIGIN must use HTTPS");
if (new URL(disallowedOrigin).origin === allowedOrigin) fail("the disallowed origin must differ from staging origin");

const [encodedHeader, encodedPayload, encodedSignature] = token.split(".");
if (!encodedHeader || !encodedPayload || !encodedSignature) fail("CURLPLAN_STAGING_TOKEN is not a JWT");
const header = decodeJSON(encodedHeader, "JWT header");
const claims = decodeJSON(encodedPayload, "JWT claims");
const issuer = requiredClaim(claims, "iss").replace(/\/+$/, "");
const issuerURL = new URL(issuer);
const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
const now = Math.floor(Date.now() / 1000);

assert(header.alg === "RS256" && typeof header.kid === "string" && header.kid,
  "staging token declares an RS256 signing key");
assert(issuerURL.protocol === "https:", "Clerk issuer uses HTTPS");
assert(audiences.includes(expectedAudience), `staging token carries audience ${expectedAudience}`);
assert(typeof claims.sub === "string" && claims.sub.length > 0, "staging token carries a subject");
assert([claims.exp, claims.nbf, claims.iat].every(Number.isFinite),
  "staging token carries exp, nbf, and iat claims");
assert(now < claims.exp && now >= claims.nbf && now - claims.iat <= 3600,
  "staging token is current and no older than one hour");

const workerTLS = await probeTLS(baseURL);
assert(workerTLS === "TLSv1.2" || workerTLS === "TLSv1.3", `Worker negotiates ${workerTLS}`);
const issuerTLS = await probeTLS(issuerURL);
assert(issuerTLS === "TLSv1.2" || issuerTLS === "TLSv1.3", `Clerk issuer negotiates ${issuerTLS}`);

const jwksResponse = await fetch(`${issuer}/.well-known/jwks.json`, {
  headers: { "Cache-Control": "no-cache" },
  signal: AbortSignal.timeout(15_000),
});
assert(jwksResponse.ok, `Clerk JWKS responds ${jwksResponse.status}`);
const jwks = await jwksResponse.json();
const jwk = Array.isArray(jwks.keys) ? jwks.keys.find(candidate => candidate.kid === header.kid) : null;
assert(jwk?.kty === "RSA" && jwk.use === "sig" && (jwk.alg === undefined || jwk.alg === "RS256") &&
    (!Array.isArray(jwk.key_ops) || jwk.key_ops.includes("verify")),
"Clerk JWKS exposes the token's constrained signing key");
const key = await crypto.subtle.importKey(
  "jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]
);
assert(await crypto.subtle.verify(
  "RSASSA-PKCS1-v1_5",
  key,
  Buffer.from(encodedSignature, "base64url"),
  new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`)
), "Clerk JWKS verifies the supplied staging token signature");

const health = await request("GET", "/health", { expected: 200 });
assert(health.body?.ok === true && health.body?.schemaVersion === 4,
  "deployment health reports canonical schema 4");

await request("GET", "/v1/state", { expected: 401 });
pass("protected state rejects a missing bearer token");
await request("GET", "/v1/state", { expected: 401, token: "not-a-jwt" });
pass("protected state rejects a malformed bearer token");

const preflight = await request("OPTIONS", "/v1/state", {
  expected: 204,
  origin: allowedOrigin,
  headers: {
    "Access-Control-Request-Method": "POST",
    "Access-Control-Request-Headers": "authorization, content-type",
  },
});
assert(preflight.response.headers.get("access-control-allow-origin") === allowedOrigin &&
    preflight.response.headers.get("access-control-allow-credentials") === "true" &&
    preflight.response.headers.get("vary")?.toLowerCase().includes("origin"),
"credentialed CORS preflight returns the exact staging origin and Vary boundary");

const rejectedOrigin = await request("OPTIONS", "/v1/state", {
  expected: 403,
  origin: disallowedOrigin,
  headers: {
    "Access-Control-Request-Method": "GET",
    "Access-Control-Request-Headers": "authorization",
  },
});
assert(!rejectedOrigin.response.headers.has("access-control-allow-origin"),
  "unlisted origin fails closed without CORS authority");

const initial = await request("GET", "/v1/state", {
  expected: 200, token, origin: allowedOrigin,
});
assert(initial.body?.schemaVersion === 4 && Number.isInteger(initial.body?.rev),
  "authenticated state read returns a schema 4 revision");
assert(initial.body.rev === 0 && empty(initial.body.state),
  "staging token belongs to a fresh disposable account state");

try {
  const marker = `staging-${crypto.randomUUID()}`;
  const mergeKey = `merge-${crypto.randomUUID()}`;
  const mergeBody = {
    schemaVersion: 4,
    baseRev: initial.body.rev,
    idempotencyKey: mergeKey,
    state: { posts: [{ id: marker, at: Date.now(), body: "CurlPlan controlled staging verification" }] },
  };
  const merged = await request("POST", "/v1/state", {
    expected: 200, token, origin: allowedOrigin, body: mergeBody,
  });
  assert(merged.body?.operation === "merge" && merged.body?.rev === 1,
    "state merge commits the first D1 revision");
  const mergeRetry = await request("POST", "/v1/state", {
    expected: 200, token, origin: allowedOrigin, body: mergeBody,
  });
  assert(mergeRetry.body?.rev === 1 && mergeRetry.body?.idempotencyKey === mergeKey,
    "identical merge retry returns the stored idempotent response");

  const exported = await request("GET", "/v1/export", {
    expected: 200, token, origin: allowedOrigin,
  });
  assert(exported.body?.rev === 1 && exported.body?.state?.posts?.some(post => post.id === marker),
    "export reads the committed staging marker from D1");

  const restoreKey = `restore-${crypto.randomUUID()}`;
  const restored = await request("POST", "/v1/restore", {
    expected: 200,
    token,
    origin: allowedOrigin,
    body: {
      schemaVersion: 4,
      baseRev: exported.body.rev,
      idempotencyKey: restoreKey,
      state: initial.body.state,
    },
  });
  assert(restored.body?.operation === "restore" && restored.body?.rev === 2,
    "restore replaces the marker with the original empty state");

  const deleteKey = `delete-${crypto.randomUUID()}`;
  const deleteBody = { schemaVersion: 4, baseRev: restored.body.rev, idempotencyKey: deleteKey };
  const deleted = await request("DELETE", "/v1/state", {
    expected: 200, token, origin: allowedOrigin, body: deleteBody,
  });
  assert(deleted.body?.operation === "delete" && deleted.body?.rev === 3,
    "state deletion commits an empty canonical revision");
  const deleteRetry = await request("DELETE", "/v1/state", {
    expected: 200, token, origin: allowedOrigin, body: deleteBody,
  });
  assert(deleteRetry.body?.rev === 3 && deleteRetry.body?.idempotencyKey === deleteKey,
    "state deletion retry is idempotent");

  const finalState = await request("GET", "/v1/state", {
    expected: 200, token, origin: allowedOrigin,
  });
  assert(finalState.body?.rev === 3 && empty(finalState.body?.state),
    "lifecycle smoke leaves the disposable account state empty");
} catch (error) {
  try {
    await cleanupState();
  } catch (cleanupError) {
    console.error(`  ! cleanup failed: ${cleanupError.message}`);
  }
  throw error;
}

console.log("\nverify-worker-staging: TLS, JWT/JWKS, CORS, D1 lifecycle, and deployment smoke pass ✓");

async function request(method, pathname, { expected, token: bearer, origin, headers = {}, body } = {}) {
  const requestHeaders = { ...headers };
  if (bearer) requestHeaders.Authorization = `Bearer ${bearer}`;
  if (origin) requestHeaders.Origin = origin;
  let payload;
  if (body !== undefined) {
    requestHeaders["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(new URL(pathname, baseURL), {
    method,
    headers: requestHeaders,
    body: payload,
    redirect: "error",
    signal: AbortSignal.timeout(15_000),
  });
  const text = await response.text();
  let parsed = null;
  if (text) {
    try {
      parsed = JSON.parse(text);
    } catch {
      fail(`${method} ${pathname} returned non-JSON content`);
    }
  }
  if (response.status !== expected) {
    const code = parsed?.error?.code || "unexpected_response";
    fail(`${method} ${pathname} returned ${response.status}, expected ${expected} (${code})`);
  }
  return { response, body: parsed };
}

async function cleanupState() {
  const current = await request("GET", "/v1/state", {
    expected: 200, token, origin: allowedOrigin,
  });
  if (!Number.isInteger(current.body?.rev)) return;
  await request("DELETE", "/v1/state", {
    expected: 200,
    token,
    origin: allowedOrigin,
    body: {
      schemaVersion: 4,
      baseRev: current.body.rev,
      idempotencyKey: `cleanup-${crypto.randomUUID()}`,
    },
  });
  console.error("  ! lifecycle failure cleanup committed an empty state");
}

function probeTLS(url) {
  return new Promise((resolve, reject) => {
    const socket = connect({
      host: url.hostname,
      port: Number(url.port || 443),
      servername: url.hostname,
      rejectUnauthorized: true,
      minVersion: "TLSv1.2",
    }, () => {
      const protocol = socket.getProtocol();
      socket.end();
      resolve(protocol);
    });
    socket.setTimeout(10_000, () => socket.destroy(new Error(`TLS timeout for ${url.hostname}`)));
    socket.once("error", reject);
  });
}

function empty(state) {
  if (!state || typeof state !== "object" || Array.isArray(state)) return false;
  return Object.values(state).every(value => Array.isArray(value)
    ? value.length === 0
    : value && typeof value === "object" && Object.keys(value).length === 0);
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) fail(`set ${name}`);
  return value;
}

function requiredURL(name) {
  try {
    return new URL(required(name));
  } catch {
    fail(`${name} must be an absolute URL`);
  }
}

function requiredClaim(claims, name) {
  const value = claims?.[name];
  if (typeof value !== "string" || !value) fail(`staging token is missing ${name}`);
  return value;
}

function decodeJSON(value, label) {
  try {
    return JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
  } catch {
    fail(`could not decode ${label}`);
  }
}

function assert(condition, message) {
  if (!condition) fail(message);
  pass(message);
}

function pass(message) {
  console.log(`  ✓ ${message}`);
}

function fail(message) {
  throw new Error(message);
}
