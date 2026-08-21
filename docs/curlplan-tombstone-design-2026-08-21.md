# CurlPlan CRDT removal semantics — sync schema v4 (tombstones)

**Date:** 2026-08-21 · **Status:** Implemented (algebra layer) · **Phase:** 3 of the 2026-08-21 program

## Problem

Sync schema v3 merges OR-Set buckets by pure union: an item deleted locally
reappears ("resurrects") the next time any replica that still holds it merges.
LWW maps (`follows`, `likes`, `joins`) already handle overwrite/unset semantics;
the gap is the OR-Set buckets (`posts`, `addedCurlers`, `addedSpiels`) and the
map-of-OR-Set buckets (`visits`, `reviews`, `iceReads`, `threads`).

This must land **before** the Worker + D1 backend goes live: today it is a pure
code change; after real user data reaches D1 it becomes a server-side data
migration with loss risk.

## Chosen mechanism: LWW-element-set tombstones

Rejected: full OR-Set add/remove tag sets (heavier document shape, and item ids
here are already globally-unique uids, so per-tag granularity buys nothing).
Rejected: plain 2P-set (delete-wins-forever blocks any legitimate re-add and
makes tombstone compaction more dangerous).

**Adopted:** a top-level `tombstones` bucket keyed by OR-Set bucket name:

```json
{
  "posts": [ ... ],
  "tombstones": {
    "posts":  { "<itemId>": <deletedAt ms> },
    "visits": { "<itemId>": <deletedAt ms> }
  }
}
```

- Deleting an item writes `tombstones[bucket][id] = Date.now()` (and removes it
  from the local list).
- Map-of-OR-Set buckets tombstone by **item id, flat** (ids are unique uids
  across stop/thread keys — no nesting needed).
- **Merge rule (tombstones):** per id, `max(deletedAt)` across both documents.
  Empty per-bucket maps are omitted from the canonical form.
- **Merge rule (items):** after the normal OR-Set union, drop any item whose id
  has a tombstone with `deletedAt >= item.at`. **Ties favor the delete.**
- **Re-add:** an item whose `at` is *newer* than the tombstone survives. In
  practice re-adds mint a fresh uid anyway; this rule just makes the algebra
  total and lets a deliberate same-id restore work.
- A stop key whose visit list is emptied by tombstones remains present with
  `[]` — key presence derives from the key union and stays associative.

### Why the laws still hold

Both the item set and the tombstone set propagate through every merge, so the
final document is (union of all items) filtered by (per-id max of all
tombstones) — independent of merge order or repetition. Commutativity,
associativity, and idempotence are enforced by `scripts/verify-merge.js` and
`MergeTests.swift` over the shared fixtures, which now include delete-then-merge,
concurrent add/delete (tie), re-add-after-delete, map-of-OR-Set delete, and
max-deletedAt cases.

## Compaction

Merge is pure and clock-free; compaction is **not** part of merge. Clients call
`compactTombstones(state, now, maxAgeMs = 180 days)` at write time to drop
tombstones older than 180 days. Tombstones are `{id: at}` pairs — a few dozen
bytes each — so growth is slow; compaction bounds it.

**Accepted trade-off:** a replica offline for more than 180 days that still
holds a deleted item can resurrect it after its tombstone is compacted away.
At CurlPlan's scale (personal devices, one document per user) this is the right
cost for a bounded document.

## Migration (v3 → v4)

Purely additive: a v3 document simply has no `tombstones` bucket, which is
canonically equal to present-empty. No data rewrite is needed on load; clients
bump their store schema tag when they begin *writing* tombstones (delete
affordances). The Worker's `sanitizeState` whitelist now passes `tombstones`
through (`api/src/handler.js`), and `verify-api.js` gates delete propagation and
read-back (no resurrection) at the handler level.

## Delivered in this change

- `src/merge.js` — v4 reference: `mergeTombstones`, dead-item filtering in
  `mergeState`, `compactTombstones`, `TOMBSTONE_BUCKETS` export.
- `ios/CurlPlan/Merge.swift` — identical port; `MergeTests.swift` canonical fill
  updated. Same fixture file is the single test source for both platforms.
- `data/merge-fixtures.json` — 5 new tombstone cases (14 total).
- `api/src/handler.js` — sanitize passes `tombstones`; `scripts/verify-api.js`
  gains delete-propagation + no-resurrection checks.

## Deferred (Phase 3 remainder / Phase 6)

- UI delete affordances on web + iOS that write tombstones (Codex handoff).
- `compactTombstones` wiring into client save paths (lands with the sync loop,
  which is the first real consumer of merged documents).
