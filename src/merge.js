"use strict";
/* ============================================================
 * merge.js — CurlPlan CRDT merge for the per-account state (sync schema v3).
 *
 * Pure, deterministic, commutative + idempotent + associative → convergent.
 * "Sync" is just merge, so it is order-independent, retry-safe and offline-safe.
 *
 * This is the ONE reference implementation, ported to ios/CurlPlan/Merge.swift.
 * Both are cross-tested against data/merge-fixtures.json (scripts/verify-merge.js
 * on the JS side, MergeTests.swift on the Swift side).
 *
 * Bucket CRDT types:
 *   follows/likes/joins            LWW-Register per key   entry = { v, at }
 *   posts/addedCurlers/addedSpiels OR-Set by item .id
 *   visits/reviews/iceReads/threads  map of OR-Sets by item .id
 * ============================================================ */

var LWW_MAPS = ["follows", "likes", "joins"];
var ORSET_LISTS = ["posts", "addedCurlers", "addedSpiels"];
var ORSET_MAP_LISTS = ["visits", "reviews", "iceReads", "threads"];

// Canonical, key-sorted serialization — used for deterministic tie-breaks only.
function stableStringify(v) {
  if (v === null || typeof v !== "object") return JSON.stringify(v);
  if (Array.isArray(v)) return "[" + v.map(stableStringify).join(",") + "]";
  return "{" + Object.keys(v).sort().map(function (k) {
    return JSON.stringify(k) + ":" + stableStringify(v[k]);
  }).join(",") + "}";
}

// LWW: later `at` wins; tie → larger stable-stringified value (symmetric).
function pickLWW(x, y) {
  if (!x) return y;
  if (!y) return x;
  var ax = +x.at || 0, ay = +y.at || 0;
  if (ax !== ay) return ax > ay ? x : y;
  return stableStringify(x.v) >= stableStringify(y.v) ? x : y;
}

function mergeLWWMap(a, b) {
  a = a || {}; b = b || {};
  var out = {}, seen = {};
  Object.keys(a).concat(Object.keys(b)).forEach(function (k) {
    if (seen[k]) return;
    seen[k] = 1;
    out[k] = pickLWW(a[k], b[k]);
  });
  return out;
}

// OR-Set by item id: union; duplicate ids resolve to the lexicographically-smaller
// item (deterministic — items are immutable in practice). Canonical order: at desc, id asc.
function mergeORSet(a, b) {
  a = Array.isArray(a) ? a : []; b = Array.isArray(b) ? b : [];
  var byId = {};
  a.concat(b).forEach(function (item) {
    if (!item || item.id == null) return;
    var key = String(item.id);
    if (!byId[key]) byId[key] = item;
    else byId[key] = stableStringify(item) <= stableStringify(byId[key]) ? item : byId[key];
  });
  return Object.keys(byId).map(function (k) { return byId[k]; }).sort(function (p, q) {
    var ap = +p.at || 0, aq = +q.at || 0;
    if (ap !== aq) return aq - ap;                 // at descending (newest first)
    var ip = String(p.id), iq = String(q.id);
    return ip < iq ? -1 : ip > iq ? 1 : 0;          // id ascending (tie-break)
  });
}

function mergeMapOfORSets(a, b) {
  a = a || {}; b = b || {};
  var out = {}, seen = {};
  Object.keys(a).concat(Object.keys(b)).forEach(function (k) {
    if (seen[k]) return;
    seen[k] = 1;
    out[k] = mergeORSet(a[k], b[k]);
  });
  return out;
}

// Merge two AppState (v3) documents into one canonical converged document.
function mergeState(a, b) {
  a = a || {}; b = b || {};
  var out = {};
  LWW_MAPS.forEach(function (n) { out[n] = mergeLWWMap(a[n], b[n]); });
  ORSET_LISTS.forEach(function (n) { out[n] = mergeORSet(a[n], b[n]); });
  ORSET_MAP_LISTS.forEach(function (n) { out[n] = mergeMapOfORSets(a[n], b[n]); });
  return out;
}

var api = { mergeState: mergeState, mergeLWWMap: mergeLWWMap, mergeORSet: mergeORSet,
  mergeMapOfORSets: mergeMapOfORSets, stableStringify: stableStringify,
  LWW_MAPS: LWW_MAPS, ORSET_LISTS: ORSET_LISTS, ORSET_MAP_LISTS: ORSET_MAP_LISTS };

if (typeof module !== "undefined" && module.exports) module.exports = api;      // Node + Worker
if (typeof window !== "undefined") window.CurlPlanMerge = api;                   // browser
