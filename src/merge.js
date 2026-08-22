"use strict";
/* ============================================================
 * merge.js — CurlPlan CRDT merge for the per-account state (sync schema v4).
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
 *   tombstones                     per-bucket { itemId: deletedAt } — v4 removal
 *
 * v4 removal semantics (LWW-element-set): deleting an item writes
 * tombstones[bucket][id] = deletedAt. Tombstones merge by max(deletedAt).
 * After the OR-Set union, an item is dropped iff a tombstone exists for its id
 * with deletedAt >= item.at (ties favor the delete). A re-add with a NEWER
 * item.at therefore survives an older tombstone. v3 docs simply have no
 * tombstones bucket (== empty), so v3 → v4 needs no data migration.
 * Compaction is a SEPARATE, clock-aware step (compactTombstones) applied by
 * clients at write time — never inside merge, which must stay deterministic.
 * See docs/curlplan-tombstone-design-2026-08-21.md.
 * ============================================================ */

var LWW_MAPS = ["follows", "likes", "joins"];
var ORSET_LISTS = ["posts", "addedCurlers", "addedSpiels"];
var ORSET_MAP_LISTS = ["visits", "reviews", "iceReads", "threads"];
var TOMBSTONE_BUCKETS = ORSET_LISTS.concat(ORSET_MAP_LISTS);

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

// OR-Set by item id: union; duplicate ids resolve to the newest item, with the
// lexicographically-smaller representation as a deterministic equal-time tie-break.
// Canonical order: at desc, id asc.
function mergeORSet(a, b) {
  a = Array.isArray(a) ? a : []; b = Array.isArray(b) ? b : [];
  var byId = {};
  a.concat(b).forEach(function (item) {
    if (!item || item.id == null) return;
    var key = String(item.id);
    if (!byId[key]) byId[key] = item;
    else {
      var itemAt = +item.at || 0, currentAt = +byId[key].at || 0;
      if (itemAt > currentAt ||
          (itemAt === currentAt && stableStringify(item) <= stableStringify(byId[key]))) {
        byId[key] = item;
      }
    }
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

// Tombstones: per-bucket { itemId: deletedAt }. Merge = per-id max(deletedAt).
// Empty per-bucket maps are omitted so the canonical form is stable.
function mergeTombstones(a, b) {
  a = a || {}; b = b || {};
  var out = {};
  TOMBSTONE_BUCKETS.forEach(function (n) {
    var ta = a[n] || {}, tb = b[n] || {}, m = {}, any = false;
    Object.keys(ta).concat(Object.keys(tb)).forEach(function (id) {
      m[id] = Math.max(+ta[id] || 0, +tb[id] || 0);
      any = true;
    });
    if (any) out[n] = m;
  });
  return out;
}

// An item is dead iff a tombstone exists for its id with deletedAt >= item.at.
function isDead(tomb, item) {
  if (!tomb || !item || item.id == null) return false;
  var t = tomb[String(item.id)];
  if (t == null) return false;
  return +t >= (+item.at || 0);
}

function dropDead(list, tomb) {
  if (!tomb) return list;
  return list.filter(function (item) { return !isDead(tomb, item); });
}

// Merge two AppState (v4) documents into one canonical converged document.
function mergeState(a, b) {
  a = a || {}; b = b || {};
  var out = {};
  var tombs = mergeTombstones(a.tombstones, b.tombstones);
  LWW_MAPS.forEach(function (n) { out[n] = mergeLWWMap(a[n], b[n]); });
  ORSET_LISTS.forEach(function (n) { out[n] = dropDead(mergeORSet(a[n], b[n]), tombs[n]); });
  ORSET_MAP_LISTS.forEach(function (n) {
    var m = mergeMapOfORSets(a[n], b[n]);
    Object.keys(m).forEach(function (k) { m[k] = dropDead(m[k], tombs[n]); });
    out[n] = m;
  });
  out.tombstones = tombs;
  return out;
}

// Clock-aware maintenance, applied by clients at write time — NEVER inside merge.
// Drops tombstones older than maxAgeMs (default 180 days). A replica offline
// longer than that could resurrect a deleted item; accepted trade-off (documented).
function compactTombstones(state, now, maxAgeMs) {
  if (!state || !state.tombstones) return state;
  var cutoff = (+now || 0) - (maxAgeMs == null ? 180 * 24 * 60 * 60 * 1000 : +maxAgeMs);
  var tombs = {};
  TOMBSTONE_BUCKETS.forEach(function (n) {
    var t = state.tombstones[n];
    if (!t) return;
    var m = {}, any = false;
    Object.keys(t).forEach(function (id) {
      if (+t[id] >= cutoff) { m[id] = t[id]; any = true; }
    });
    if (any) tombs[n] = m;
  });
  var out = {};
  Object.keys(state).forEach(function (k) { if (k !== "tombstones") out[k] = state[k]; });
  out.tombstones = tombs;
  return out;
}

var api = { mergeState: mergeState, mergeLWWMap: mergeLWWMap, mergeORSet: mergeORSet,
  mergeMapOfORSets: mergeMapOfORSets, mergeTombstones: mergeTombstones,
  compactTombstones: compactTombstones, stableStringify: stableStringify,
  LWW_MAPS: LWW_MAPS, ORSET_LISTS: ORSET_LISTS, ORSET_MAP_LISTS: ORSET_MAP_LISTS,
  TOMBSTONE_BUCKETS: TOMBSTONE_BUCKETS };

if (typeof module !== "undefined" && module.exports) module.exports = api;      // Node + Worker
if (typeof window !== "undefined") window.CurlPlanMerge = api;                   // browser
