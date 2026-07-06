#!/usr/bin/env node
/* ============================================================
 * verify-merge.js — proves the CRDT merge (src/merge.js) is correct against the
 * shared fixtures AND satisfies the algebraic laws that guarantee convergence.
 * The Swift port (MergeTests.swift) runs the SAME data/merge-fixtures.json.
 * ============================================================ */
"use strict";
const fs = require("fs");
const path = require("path");
const { mergeState, stableStringify } = require("../src/merge.js");

const root = path.resolve(__dirname, "..");
const fixtures = JSON.parse(fs.readFileSync(path.join(root, "data", "merge-fixtures.json"), "utf8"));

const LWW = ["follows", "likes", "joins"];
const LISTS = ["posts", "addedCurlers", "addedSpiels"];
const MAPS = ["visits", "reviews", "iceReads", "threads"];

// Fill missing buckets so "absent" == "present-empty" when comparing.
function fill(s) {
  s = s || {};
  const o = {};
  LWW.forEach(k => o[k] = s[k] || {});
  LISTS.forEach(k => o[k] = s[k] || []);
  MAPS.forEach(k => o[k] = s[k] || {});
  return o;
}
const canon = (s) => stableStringify(fill(s));
const eq = (x, y) => canon(x) === canon(y);

let failed = 0;
function check(cond, msg) { if (!cond) { failed++; console.error("  ✗ " + msg); } }

// 1. Fixture vectors + per-case laws
for (const c of fixtures.cases) {
  const ab = mergeState(c.a, c.b);
  check(eq(ab, c.expected), `${c.name}: merge(a,b) != expected\n      got:      ${canon(ab)}\n      expected: ${canon(c.expected)}`);
  check(eq(mergeState(c.b, c.a), ab), `${c.name}: not commutative`);
  check(eq(mergeState(ab, ab), ab), `${c.name}: not idempotent`);
  if (failed === 0 || eq(ab, c.expected)) console.log(`  ✓ ${c.name}`);
}

// 2. Associativity across a spread of the fixture states: merge(merge(a,b),c) == merge(a,merge(b,c))
const states = fixtures.cases.flatMap(c => [c.a, c.b]).filter(s => s && Object.keys(s).length);
for (let i = 0; i + 2 < states.length; i += 3) {
  const [a, b, c] = [states[i], states[i + 1], states[i + 2]];
  check(eq(mergeState(mergeState(a, b), c), mergeState(a, mergeState(b, c))),
    `associativity failed for states ${i}..${i + 2}`);
}
console.log("  ✓ associativity across fixture states");

// 3. Idempotency of the full seed of states
for (const s of states) check(eq(mergeState(s, {}), mergeState(mergeState(s, {}), mergeState(s, {}))), "idempotency (canonicalized) failed");
console.log("  ✓ idempotency (canonicalized) across fixture states");

if (failed) {
  console.error(`\nverify-merge: ${failed} check(s) failed.`);
  process.exit(1);
}
console.log(`\nverify-merge: ${fixtures.cases.length} fixtures + commutativity/idempotency/associativity all pass ✓`);
