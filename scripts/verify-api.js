#!/usr/bin/env node
/* ============================================================
 * verify-api.js — exercises the sync Worker's pure handler under Node (no Miniflare).
 * Injects an in-memory D1 + a stub auth verifier, so routing, CRDT merge-on-write,
 * per-user isolation, LWW, size caps and CORS are all tested in CI without deploying.
 * The real Clerk crypto path (api/src/auth.js) is exercised only against a live instance.
 * ============================================================ */
"use strict";
const path = require("path");
const { pathToFileURL } = require("url");

(async () => {
  const { handleRequest } = await import(pathToFileURL(path.join(__dirname, "../api/src/handler.js")).href);

  const mem = new Map();
  const db = {
    async get(u) { return mem.has(u) ? mem.get(u) : null; },
    async put(u, doc, rev) { mem.set(u, { doc, rev }); },
  };
  const verifyAuth = async (req) => { const u = req.headers.get("x-test-user"); return u ? { userId: u } : null; };
  const deps = { db, verifyAuth, now: () => 1720000000000, corsOrigin: "https://example.test" };

  const call = (method, pathname, opts = {}) => {
    const headers = {};
    if (opts.user) headers["x-test-user"] = opts.user;
    if (opts.body) headers["Content-Type"] = "application/json";
    return handleRequest(new Request("https://api.test" + pathname, {
      method, headers, body: opts.body ? JSON.stringify(opts.body) : undefined,
    }), deps);
  };

  let failed = 0;
  const ok = (c, m) => { if (!c) { failed++; console.error("  ✗ " + m); } else console.log("  ✓ " + m); };

  let r = await call("GET", "/health");
  ok(r.status === 200, "GET /health → 200");

  r = await call("GET", "/v1/state");
  ok(r.status === 401, "GET /v1/state without auth → 401");

  r = await call("GET", "/v1/state", { user: "u1" });
  let j = await r.json();
  ok(r.status === 200 && j.rev === 0 && Array.isArray(j.state.posts) && j.state.posts.length === 0, "GET empty state → rev 0, empty buckets");

  r = await call("POST", "/v1/state", { user: "u1", body: { state: { follows: { sam: { v: true, at: 100 } }, posts: [{ id: "p1", at: 100, body: "hi" }] } } });
  j = await r.json();
  ok(r.status === 200 && j.rev === 1 && j.state.follows.sam.v === true && j.state.posts.length === 1, "POST merges + rev → 1");

  r = await call("POST", "/v1/state", { user: "u1", body: { state: { posts: [{ id: "p2", at: 200, body: "yo" }] } } });
  j = await r.json();
  ok(j.rev === 2 && j.state.posts.length === 2 && j.state.posts[0].id === "p2", "second push converges (OR-Set union, at desc)");

  r = await call("GET", "/v1/state", { user: "u2" });
  j = await r.json();
  ok(j.state.posts.length === 0, "per-user isolation (u2 sees nothing of u1)");

  r = await call("POST", "/v1/state", { user: "u1", body: { state: { follows: { sam: { v: false, at: 50 } } } } });
  j = await r.json();
  ok(j.state.follows.sam.v === true, "LWW: stale (older) write does not override newer");

  const big = { state: { posts: Array.from({ length: 20000 }, (_, i) => ({ id: "x" + i, at: i, body: "padpadpadpadpadpad" })) } };
  r = await call("POST", "/v1/state", { user: "u1", body: big });
  ok(r.status === 413, "oversized document → 413");

  r = await call("OPTIONS", "/v1/state");
  ok(r.status === 204 && r.headers.get("Access-Control-Allow-Origin") === "https://example.test", "OPTIONS preflight → 204 + CORS");

  r = await call("GET", "/v1/nope", { user: "u1" });
  ok(r.status === 404, "unknown route → 404");

  if (failed) { console.error(`\nverify-api: ${failed} check(s) failed.`); process.exit(1); }
  console.log("\nverify-api: sync handler OK — routes, merge convergence, auth, isolation, LWW, size cap, CORS ✓");
})().catch(e => { console.error(e); process.exit(1); });
