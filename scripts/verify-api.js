#!/usr/bin/env node
/* ============================================================
 * verify-api.js — exercises the sync Worker's pure handler under Node.
 * The in-memory adapter implements the same revision CAS and idempotency
 * contract as D1 so concurrency, migration, export, restore, and deletion can
 * be proved without cloud credentials or a deployment.
 * ============================================================ */
"use strict";
const path = require("path");
const fs = require("fs");
const { pathToFileURL } = require("url");

(async () => {
  const { handleRequest } = await import(pathToFileURL(path.join(__dirname, "../api/src/handler.js")).href);
  const rows = new Map();
  const receipts = new Map();
  let readBarrier = null;
  const clone = value => value == null ? value : structuredClone(value);
  const receiptKey = (userId, idempotencyKey) => `${userId}:${idempotencyKey}`;
  const db = {
    async get(userId) {
      const row = clone(rows.get(userId) || null);
      if (readBarrier?.userId === userId && !readBarrier.released) {
        readBarrier.arrivals += 1;
        if (readBarrier.arrivals === readBarrier.parties) {
          readBarrier.released = true;
          readBarrier.resolve();
        }
        await readBarrier.promise;
      }
      return row;
    },
    async getReceipt(userId, idempotencyKey) {
      return clone(receipts.get(receiptKey(userId, idempotencyKey)) || null);
    },
    async cas(userId, expectedRev, row, idempotencyKey, response) {
      const current = rows.get(userId);
      if ((current?.rev || 0) !== expectedRev) return false;
      rows.set(userId, clone(row));
      if (response.operation === "delete") {
        for (const key of receipts.keys()) {
          if (key.startsWith(`${userId}:`)) receipts.delete(key);
        }
      } else {
        const userReceiptKeys = [...receipts.keys()].filter(key => key.startsWith(`${userId}:`));
        while (userReceiptKeys.length >= 100) receipts.delete(userReceiptKeys.shift());
      }
      receipts.set(receiptKey(userId, idempotencyKey), clone(response));
      return true;
    },
  };
  const verifyAuth = async request => {
    const userId = request.headers.get("x-test-user");
    return userId ? { userId } : null;
  };
  const deps = { db, verifyAuth, now: () => 1720000000000, corsOrigin: "https://example.test" };

  const call = (method, pathname, opts = {}) => {
    const headers = {};
    if (opts.user) headers["x-test-user"] = opts.user;
    if (opts.body !== undefined || opts.rawBody !== undefined) headers["Content-Type"] = "application/json";
    return handleRequest(new Request("https://api.test" + pathname, {
      method,
      headers,
      body: opts.rawBody !== undefined ? opts.rawBody : opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    }), deps);
  };
  const stateWrite = (baseRev, idempotencyKey, state, schemaVersion = 4) => ({
    schemaVersion, baseRev, idempotencyKey, state,
  });

  let failed = 0;
  const ok = (condition, message) => {
    if (!condition) {
      failed++;
      console.error("  ✗ " + message);
    } else {
      console.log("  ✓ " + message);
    }
  };

  let response = await call("GET", "/health");
  ok(response.status === 200, "GET /health → 200");

  const schemaSQL = fs.readFileSync(path.join(__dirname, "../api/schema.sql"), "utf8");
  const migrationSQL = fs.readFileSync(path.join(__dirname, "../api/migrations/0002_atomic_sync_v4.sql"), "utf8");
  const workerAdapter = fs.readFileSync(path.join(__dirname, "../api/src/index.js"), "utf8");
  ok(/schema_version[\s\S]+last_idempotency_key/.test(schemaSQL) &&
      /CREATE TABLE IF NOT EXISTS sync_receipts/.test(schemaSQL) &&
      /ALTER TABLE state ADD COLUMN schema_version/.test(migrationSQL) &&
      /env\.DB\.batch/.test(workerAdapter),
  "fresh schema, additive v3 migration, receipt table, and atomic D1 batch are wired");

  response = await call("GET", "/v1/state");
  ok(response.status === 401, "GET /v1/state without auth → 401");

  response = await call("GET", "/v1/state", { user: "u1" });
  let body = await response.json();
  ok(response.status === 200 && body.schemaVersion === 4 && body.rev === 0 && body.state.posts.length === 0,
    "GET empty state → canonical schema 4, rev 0, empty buckets");

  response = await call("POST", "/v1/state", { user: "u1", body: { state: {} } });
  body = await response.json();
  ok(response.status === 422 && body.error.code === "INVALID_WRITE_CONTRACT",
    "write requires schema, base revision, and idempotency key");

  const firstWrite = stateWrite(0, "sync-1", {
    follows: { sam: { v: true, at: 100 } },
    posts: [{ id: "p1", at: 100, body: "hi" }],
  });
  response = await call("POST", "/v1/state", { user: "u1", body: firstWrite });
  body = await response.json();
  ok(response.status === 200 && body.rev === 1 && body.operation === "merge",
    "first CAS merge commits revision 1");

  response = await call("POST", "/v1/state", { user: "u1", body: firstWrite });
  body = await response.json();
  ok(response.status === 200 && body.rev === 1 && rows.get("u1").rev === 1,
    "idempotent retry returns the original receipt without a second write");

  response = await call("POST", "/v1/state", {
    user: "u1",
    body: stateWrite(0, "sync-1", { posts: [{ id: "different", at: 1 }] }),
  });
  body = await response.json();
  ok(response.status === 409 && body.error.code === "IDEMPOTENCY_KEY_REUSED" && rows.get("u1").rev === 1,
    "idempotency key reuse with different content fails closed");

  let releaseBarrier;
  readBarrier = {
    userId: "u1",
    parties: 2,
    arrivals: 0,
    released: false,
    promise: new Promise(resolve => { releaseBarrier = resolve; }),
    resolve: () => releaseBarrier(),
  };
  const [concurrentA, concurrentB] = await Promise.all([
    call("POST", "/v1/state", {
      user: "u1",
      body: stateWrite(1, "sync-concurrent-a", { posts: [{ id: "p2", at: 200, body: "two" }] }),
    }),
    call("POST", "/v1/state", {
      user: "u1",
      body: stateWrite(1, "sync-concurrent-b", { posts: [{ id: "p3", at: 300, body: "three" }] }),
    }),
  ]);
  readBarrier = null;
  response = await call("GET", "/v1/state", { user: "u1" });
  body = await response.json();
  ok(concurrentA.status === 200 && concurrentB.status === 200 && body.rev === 3 &&
      body.state.posts.map(post => post.id).join(",") === "p3,p2,p1",
  "interleaved same-user writes converge through bounded CAS retry without lost updates");

  response = await call("POST", "/v1/state", {
    user: "u1",
    body: stateWrite(1, "sync-stale", { posts: [{ id: "stale", at: 50 }] }),
  });
  body = await response.json();
  ok(response.status === 409 && body.error.code === "REVISION_CONFLICT" && body.error.currentRev === 3 &&
      body.error.schemaVersion === 4,
  "stale initial revision returns a deterministic conflict envelope");

  response = await call("POST", "/v1/state", {
    user: "u1",
    body: stateWrite(3, "sync-lww", { follows: { sam: { v: false, at: 50 } } }),
  });
  body = await response.json();
  const lwwRead = await (await call("GET", "/v1/state", { user: "u1" })).json();
  ok(response.status === 200 && body.rev === 4 && lwwRead.state.follows.sam.v === true,
    "LWW rejects an older value while advancing the committed revision");

  response = await call("POST", "/v1/state", {
    user: "u1",
    body: stateWrite(4, "sync-delete", { tombstones: { posts: { p1: 400 } } }),
  });
  body = await response.json();
  const tombstoneRead = await (await call("GET", "/v1/state", { user: "u1" })).json();
  ok(response.status === 200 && body.rev === 5 && tombstoneRead.state.posts.every(post => post.id !== "p1") &&
      tombstoneRead.state.tombstones.posts.p1 === 400,
  "schema 4 tombstone survives sanitize and prevents resurrection");

  rows.set("migration-user", {
    doc: { posts: [{ id: "legacy", at: 10, body: "v3" }] },
    rev: 7,
    schemaVersion: 3,
    updatedAt: 1,
  });
  response = await call("GET", "/v1/state", { user: "migration-user" });
  body = await response.json();
  ok(response.status === 200 && body.schemaVersion === 4 && body.rev === 7 && body.state.tombstones,
    "stored schema 3 reads through the additive schema 4 migration");
  response = await call("POST", "/v1/state", {
    user: "migration-user",
    body: stateWrite(7, "migrate-write", { posts: [{ id: "current", at: 20 }] }),
  });
  body = await response.json();
  ok(response.status === 200 && body.rev === 8 && rows.get("migration-user").schemaVersion === 4,
    "first successful schema 4 write owns migration of a stored schema 3 row");

  response = await call("POST", "/v1/state", {
    user: "legacy-client",
    body: stateWrite(0, "legacy-write", {}, 3),
  });
  body = await response.json();
  ok(response.status === 426 && body.error.code === "SCHEMA_UPGRADE_REQUIRED",
    "schema 3 clients are read-compatible but cannot create new writes");

  const hostileState = JSON.parse(`{
    "follows": { "__proto__": { "v": true, "at": 1 } },
    "posts": []
  }`);
  response = await call("POST", "/v1/state", {
    user: "hostile-user",
    body: stateWrite(0, "hostile-write", hostileState),
  });
  body = await response.json();
  ok(response.status === 422 && body.error.code === "INVALID_STATE" && Object.prototype.polluted === undefined,
    "hostile object keys are rejected at the API boundary");

  const storedLarge = { posts: Array.from({ length: 3000 }, (_, index) => ({
    id: `stored-${index}`, at: index, body: "s".repeat(80),
  })) };
  const incomingLarge = { posts: Array.from({ length: 3000 }, (_, index) => ({
    id: `incoming-${index}`, at: index + 5000, body: "i".repeat(80),
  })) };
  rows.set("large-user", { doc: storedLarge, rev: 1, schemaVersion: 4, updatedAt: 1 });
  response = await call("POST", "/v1/state", {
    user: "large-user",
    body: stateWrite(1, "large-merge", incomingLarge),
  });
  body = await response.json();
  ok(JSON.stringify(incomingLarge).length < 512 * 1024 && response.status === 413 &&
      body.error.code === "MERGED_STATE_TOO_LARGE" && rows.get("large-user").rev === 1,
  "final merged document cap rejects growth without publishing a new revision");

  response = await call("POST", "/v1/restore", {
    user: "lifecycle-user",
    body: stateWrite(0, "restore-1", { posts: [{ id: "restored", at: 50 }] }),
  });
  body = await response.json();
  ok(response.status === 200 && body.rev === 1 && body.operation === "restore",
    "restore replaces an empty account state through the same CAS contract");
  response = await call("GET", "/v1/export", { user: "lifecycle-user" });
  body = await response.json();
  ok(response.status === 200 && body.schemaVersion === 4 && body.rev === 1 && body.state.posts[0].id === "restored",
    "export returns the canonical versioned season document");
  const deleteWrite = { schemaVersion: 4, baseRev: 1, idempotencyKey: "delete-1" };
  response = await call("DELETE", "/v1/state", { user: "lifecycle-user", body: deleteWrite });
  body = await response.json();
  const deletedRead = await (await call("GET", "/v1/state", { user: "lifecycle-user" })).json();
  ok(response.status === 200 && body.rev === 2 && body.operation === "delete" && deletedRead.state.posts.length === 0 &&
      [...receipts.keys()].filter(key => key.startsWith("lifecycle-user:")).join(",") === "lifecycle-user:delete-1",
    "deletion commits an empty canonical state without resetting revision history");
  response = await call("DELETE", "/v1/state", { user: "lifecycle-user", body: deleteWrite });
  body = await response.json();
  ok(response.status === 200 && body.rev === 2 && rows.get("lifecycle-user").rev === 2,
    "deletion retry is idempotent");

  response = await call("OPTIONS", "/v1/state");
  ok(response.status === 204 && response.headers.get("Access-Control-Allow-Origin") === "https://example.test",
    "OPTIONS preflight → 204 with configured CORS origin");

  response = await call("GET", "/v1/nope", { user: "u1" });
  ok(response.status === 404, "unknown route → 404");

  if (failed) {
    console.error(`\nverify-api: ${failed} check(s) failed.`);
    process.exit(1);
  }
  console.log("\nverify-api: atomic sync, migration, lifecycle, size, hostile-key, auth, and CORS contracts pass ✓");
})().catch(error => {
  console.error(error);
  process.exit(1);
});
