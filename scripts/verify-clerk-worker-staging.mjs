#!/usr/bin/env node

import { spawn } from "node:child_process";
import { randomBytes, randomUUID } from "node:crypto";

const clerkAPI = "https://api.clerk.com/v1";
const clerkAPIVersion = "2026-05-12";
const templateName = process.env.CURLPLAN_STAGING_AUDIENCE || "curlplan-api";
const secretKey = required("CLERK_SECRET_KEY");
const expectedIssuer = requiredURL("CLERK_STAGING_EXPECTED_ISSUER").href.replace(/\/+$/, "");
const workerURL = requiredURL("CURLPLAN_STAGING_URL").href;
const stagingOrigin = requiredURL("CURLPLAN_STAGING_ORIGIN").origin;

if (!secretKey.startsWith("sk_test_")) {
  fail("CLERK_SECRET_KEY must be a Clerk development-instance sk_test_ key");
}

let session = null;
let user = null;
let verificationPassed = false;
const cleanupErrors = [];

try {
  const instance = await clerkRequest("GET", "/instance");
  assert(instance?.environment_type === "development" || instance?.instance_type === "development",
    "Clerk instance is a development environment");

  const domains = listData(await clerkRequest("GET", "/domains"));
  const primaryDomain = domains.find(domain => domain && domain.is_satellite === false);
  const actualIssuer = primaryDomain?.frontend_api_url?.replace(/\/+$/, "");
  assert(actualIssuer === expectedIssuer, "Clerk primary issuer matches the isolated staging configuration");

  const templates = listData(await clerkRequest("GET", "/jwt_templates?limit=100"));
  let template = templates.find(candidate => candidate?.name === templateName);
  if (!template) {
    template = await clerkRequest("POST", "/jwt_templates", {
      name: templateName,
      claims: { aud: templateName },
      lifetime: 900,
      allowed_clock_skew: 5,
    });
    pass(`created Clerk JWT template ${templateName}`);
  } else {
    pass(`reused Clerk JWT template ${templateName}`);
  }
  assert(audiences(template?.claims?.aud).includes(templateName),
    `Clerk JWT template carries audience ${templateName}`);
  assert(template?.signing_algorithm === "RS256", "Clerk JWT template uses RS256");
  assert(Number.isInteger(template?.lifetime) && template.lifetime > 0 && template.lifetime <= 3600,
    "Clerk JWT template lifetime is at most one hour");

  const nonce = randomUUID();
  user = await clerkRequest("POST", "/users", {
    email_address: [`curlplan-staging+${nonce}@example.com`],
    password: `${randomBytes(24).toString("base64url")}Aa1!`,
    first_name: "CurlPlan",
    last_name: "Staging Probe",
    external_id: `curlplan-staging-${nonce}`,
  });
  assert(typeof user?.id === "string" && user.id.startsWith("user_"),
    "created a disposable Clerk staging user");
  console.log(`  · disposable Clerk subject: ${user.id}`);

  session = await clerkRequest("POST", "/sessions", { user_id: user.id });
  assert(typeof session?.id === "string" && session.id.startsWith("sess_"),
    "created a disposable Clerk staging session");

  const tokenResponse = await clerkRequest(
    "POST",
    `/sessions/${encodeURIComponent(session.id)}/tokens/${encodeURIComponent(templateName)}`,
    { expires_in_seconds: 900 },
  );
  assert(typeof tokenResponse?.jwt === "string" && tokenResponse.jwt.split(".").length === 3,
    "minted a short-lived audience-bound staging JWT");

  const verifierExit = await runVerifier(tokenResponse.jwt);
  if (verifierExit !== 0) fail(`Worker staging verifier exited ${verifierExit}`);
  verificationPassed = true;
} finally {
  if (session?.id) {
    try {
      await clerkRequest("POST", `/sessions/${encodeURIComponent(session.id)}/revoke`);
      pass("revoked the disposable Clerk session");
    } catch (error) {
      cleanupErrors.push(`session revoke: ${error.message}`);
    }
  }
  if (user?.id) {
    try {
      await clerkRequest("DELETE", `/users/${encodeURIComponent(user.id)}`);
      pass("deleted the disposable Clerk user");
    } catch (error) {
      cleanupErrors.push(`user delete: ${error.message}`);
    }
  }
}

if (cleanupErrors.length > 0) {
  fail(`Clerk cleanup failed (${cleanupErrors.join("; ")})`);
}
if (!verificationPassed) fail("Worker staging verification did not complete");

console.log("\nverify-clerk-worker-staging: disposable Clerk lifecycle and Worker proof pass ✓");

async function clerkRequest(method, pathname, body) {
  const headers = {
    Authorization: `Bearer ${secretKey}`,
    "Clerk-API-Version": clerkAPIVersion,
  };
  let payload;
  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const response = await fetch(`${clerkAPI}${pathname}`, {
    method,
    headers,
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
      fail(`Clerk ${method} ${pathname.split("?")[0]} returned non-JSON content`);
    }
  }
  if (!response.ok) {
    const code = parsed?.errors?.[0]?.code || parsed?.code || "unexpected_response";
    fail(`Clerk ${method} ${pathname.split("?")[0]} returned ${response.status} (${code})`);
  }
  return parsed;
}

function runVerifier(token) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [new URL("./verify-worker-staging.mjs", import.meta.url).pathname], {
      env: {
        ...process.env,
        CURLPLAN_STAGING_URL: workerURL,
        CURLPLAN_STAGING_ORIGIN: stagingOrigin,
        CURLPLAN_STAGING_AUDIENCE: templateName,
        CURLPLAN_STAGING_TOKEN: token,
      },
      stdio: "inherit",
    });
    child.once("error", reject);
    child.once("exit", code => resolve(code ?? 1));
  });
}

function listData(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.data)) return value.data;
  fail("Clerk list response did not contain an array");
}

function audiences(value) {
  if (Array.isArray(value)) return value;
  return typeof value === "string" ? [value] : [];
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) fail(`set ${name}`);
  return value;
}

function requiredURL(name) {
  try {
    const value = new URL(required(name));
    if (value.protocol !== "https:") fail(`${name} must use HTTPS`);
    return value;
  } catch (error) {
    if (error.message?.includes("must use HTTPS")) throw error;
    fail(`${name} must be an absolute HTTPS URL`);
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
