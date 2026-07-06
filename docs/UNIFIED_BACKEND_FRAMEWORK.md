# CurlPlan — Unified Backend Framework (design draft)

**Date:** 2026-07-06
**Status:** proposed (design only — no code)
**Goal:** One real account that works on both the web and iOS apps, with per-account
state (follows, likes, joins, posts, visits, ice reads, reviews, threads, added
curlers/spiels) synced across devices and platforms — without giving up the offline-first
behavior both apps have today.

This builds directly on the parity work: both apps already share one domain model, one
seed, and a documented **backend-ready seam** (`signIn`/`signUp`/`currentUser` on web;
`Store.signIn/signUp/currentUser` on iOS). This framework fills that seam.

---

## 1. Goals & non-goals

**Goals**
- Shared identity: sign in once, same account on web + iOS.
- Convergent state sync across N devices, last-writer-sane, no lost data.
- Offline-first preserved: every action is local-first; the network is a background mirror.
- Minimal server: no bespoke merge engine to babysit; correctness comes from the data model.
- Reuse existing patterns: one shared JSON contract + parity tests (like `gen-seed.js` / `verify-parity.js`).

**Non-goals (v1)**
- Real-time collaboration inside a single record (no shared-cursor editing).
- Social graph *between* accounts (the "circle" stays seed/local for now — see §11).
- Server-side feed ranking, notifications, moderation.

---

## 2. Principles

1. **Local-first, seam-based.** The apps never block on the network. The store stays the
   source of truth on-device; the backend is a replica that converges.
2. **CRDT-shaped state.** Design the per-account state so that merging two versions is a
   pure, deterministic, commutative/idempotent function. Then "sync" is just merge —
   order-independent, retry-safe, offline-safe. No locks, no server merge logic required.
3. **One merge spec, three implementations, shared fixtures.** Write the merge algebra
   once as a spec + `data/merge-fixtures.json`; implement in JS (web + server) and Swift
   (iOS); cross-test both against the fixtures in CI. Same discipline as the shared seed.
4. **Identity is the provider's problem.** Drop the local password hashes (web djb2, iOS
   SHA-256); delegate auth to a real provider. The app only ever sees a stable `userId`.

---

## 3. Architecture

```
        ┌───────────────┐         ┌───────────────┐
        │  Web (Pages)  │         │  iOS (SwiftUI) │
        │  local store  │         │  local store   │
        └──────┬────────┘         └────────┬───────┘
               │  Clerk JWT + state sync    │
               ▼                            ▼
        ┌──────────────────────────────────────────┐
        │  Sync API (edge worker)                   │
        │  • verifies Clerk JWT → userId            │
        │  • GET /state  → merged doc + rev         │
        │  • POST /state → merge(stored, incoming)  │
        │  • realtime rev-bump (SSE/WS/Durable Obj) │
        └──────────────────┬───────────────────────┘
                           ▼
                 ┌───────────────────┐
                 │ per-user doc store │  (userId → {state, rev, updatedAt})
                 └───────────────────┘
```

- **Auth:** Clerk (already connected to this workspace). Issues a JWT whose `sub` is the
  canonical `userId`. Web uses `@clerk/clerk-js`; iOS uses the Clerk iOS SDK (or
  `ASWebAuthenticationSession` against Clerk's hosted flow).
- **Sync API:** a single edge function. It authenticates the JWT, derives `userId` **from
  the verified token** (never from the client body), and reads/writes that user's one
  state document. The merge function is the shared JS module.
- **Store:** one document per user (`userId → { state, rev, updatedAt }`). The state is the
  same `AppState` shape both apps already persist locally.

---

## 4. Auth (Clerk) — the seam swap

Both apps already isolate auth behind a seam, so this is a swap, not a rewrite.

| Seam call | Today (local) | Unified backend |
|---|---|---|
| `currentUser()` | reads local `auth.session` | reads Clerk session → `{ id: clerkUserId, … }` |
| `signIn` / `signUp` | local user table + hash | delegate to Clerk (hosted or embedded) |
| `signOut` | clears local session | `Clerk.signOut()` + drop local sync pointer |
| identity key | local `userId` / `"demo"` | Clerk `userId`; `"demo"` stays **local-only, never synced** |

Everything downstream of the seam (`render()` gating on web, `RootView` gating on iOS) is
unchanged. Demo mode keeps working with zero network. Passwords, reset, verification,
OAuth, and MFA become Clerk's responsibility — the local hashes are deleted.

---

## 5. The sync contract — state as a mergeable document

The crux. Classify every `AppState` bucket by CRDT type so merge is total and deterministic.

| Bucket | CRDT type | Merge rule |
|---|---|---|
| `follows{curlerId}` | LWW-Register per key | keep entry with max `at` (tie-break `deviceId`) |
| `likes{postId}` | LWW-Register per key | same |
| `joins{spielId}` | LWW-Register per key | same |
| `posts[]` | OR-Set by `id` | union by `id`; item immutable once created |
| `visits{stopId}[]` | OR-Set by `id` | union by `id` |
| `reviews{stopId}[]` | OR-Set by `id` | union by `id` |
| `iceReads{stopId}[]` | OR-Set by `id` | union by `id` |
| `threads{curlerId}[]` | OR-Set by `id` | union by `id`, order by `at` |
| `addedCurlers[]` / `addedSpiels[]` | OR-Set by `id` | union by `id` |

**Required schema tweak (v3):** the three map buckets become value-with-timestamp so LWW
has something to compare:

```
follows: { "sam": { v: true,  at: 1720000000.0 },
           "jo":  { v: false, at: 1720000042.0 } }
```

List items already carry a unique `id` + `at`, so OR-Sets need no change. Deletions (rare
in CurlPlan) are handled by tombstones in a later version; v1 is grow-only union, which is
safe for this app's actual behavior (you unfollow via LWW, you don't hard-delete posts).

**Merge is a pure function** `merge(a, b) -> c` that is:
- **commutative** — `merge(a,b) == merge(b,a)`
- **idempotent** — `merge(a,a) == a`, `merge(a, merge(a,b)) == merge(a,b)`
- **associative** — device order doesn't matter → guaranteed convergence.

Because of this, the server can be dumb: `stored = merge(stored, incoming)` on every push.
No optimistic-lock ping-pong required (though we still return a `rev` for change detection
and realtime).

---

## 6. API contract (minimal)

All calls carry `Authorization: Bearer <Clerk JWT>`; `userId` is taken from the verified token.

```
GET  /v1/state
     → 200 { state: AppState, rev: number, updatedAt: number }

POST /v1/state
     body: { state: AppState (local), baseRev: number }
     server: stored = merge(stored, body.state); rev++
     → 200 { state: merged, rev }            // always returns the merged truth

GET  /v1/state/stream        (optional realtime)
     → SSE/WS stream of { rev } bumps for this user's other devices
```

`GET /health`, size caps, and per-user rate limits round it out. Payloads are small
(one user's overrides), so full-document push is fine at this scale; a `since`/delta
variant is a later optimization, not a v1 need.

---

## 7. Client sync loop (identical shape on both platforms)

```
on local mutation:
  1. apply to local store immediately (optimistic)   ← already how both apps work
  2. persist locally (localStorage / UserDefaults)   ← unchanged
  3. mark dirty; schedule sync (debounced)

sync():
  4. pull   = GET /state
  5. local  = merge(local, pull.state)               ← converge inbound
  6. push   = POST /state { state: local }
  7. local  = merge(local, push.state)               ← converge server truth
  8. persist local; clear dirty; store rev

triggers: on mutation (debounced ~2s), on foreground, on reconnect,
          on realtime rev-bump. All idempotent — safe to run anytime.
```

Offline: steps 1–3 always succeed; 4–8 retry on reconnect. Because merge is convergent,
a device offline for a week rejoins cleanly. This is the same loop web and iOS run; only
the HTTP/persistence primitives differ.

---

## 8. Migration (local → cloud, once per first sign-in)

When a previously local-only user first authenticates with Clerk:

1. Detect a non-empty local `anon`/prior state bucket.
2. Offer "Bring your season to this account" (one tap).
3. `cloud = merge(cloud, localBucket)` via the same function — idempotent, so re-running
   is harmless.
4. Re-point the local store key to the Clerk `userId`; keep a backup of the old bucket for
   one release.

Demo state is never migrated or synced (it's shared sample data). Existing local schema
migrations (`migrateLegacyStore` on web, `migrateLegacyIfNeeded` on iOS) get one more step
for the v3 timestamped-map shape.

---

## 9. Security & privacy

- **Trust only the token.** `userId` is derived from the verified Clerk JWT server-side;
  the client can never write another user's document (no client-supplied user id).
- **Isolation.** One document per user, keyed by `userId`; enforce at the data layer (Row
  Level Security if Postgres, or key-scoping in the Worker).
- **Validation.** Reuse the existing `sanitizeStore` logic server-side (clamp stars, guard
  array shapes, size limits) so a malicious client can't poison a document.
- **Transport.** TLS only; short-lived JWTs; rotate signing keys via Clerk.
- **Deletion.** Account delete = drop the user's document + Clerk user (GDPR-style).
- Local passwords/hashes are **removed** — no secret material lives in the app anymore.

---

## 10. Tech stack — recommendation + alternatives

| Option | Auth | Sync store | Realtime | Trade-off |
|---|---|---|---|---|
| **A. Clerk + Cloudflare Workers + D1** *(recommended)* | Clerk (already connected) | D1 (SQLite) or Durable Object per user | Durable Object / SSE | Tiny server (one Worker runs the **shared JS merge**), edge, cheap, trivial CORS for a static Pages site, no infra to manage. Most reuse. |
| B. Supabase (all-in-one) | Supabase Auth *or* Clerk-via-JWT | Postgres + RLS | Supabase Realtime | Least code; first-class JS **and** Swift SDKs; but either migrate auth off Clerk or bridge Clerk→RLS. |
| C. Firebase | Firebase Auth | Firestore (offline SDK) | Firestore listeners | Offline + realtime nearly free, but Firestore's per-doc model reshapes the buckets and adds vendor lock-in. |

**Recommendation: Option A.** It reuses the already-connected Clerk, keeps the server to a
single edge function that imports the *same* JS merge module the web app uses, and fits the
existing static-hosting/estate style. Option B is the pick if you'd rather buy a platform
than write ~150 lines of Worker.

---

## 11. Phased rollout (each phase ships; local-first never breaks)

- **Phase A — Make the state sync-ready (no server).** Extract the merge algebra: spec +
  `data/merge-fixtures.json` + JS impl (web) + Swift impl (iOS) + cross-tests in CI.
  Convert the 3 map buckets to LWW `{v, at}` (schema v3 + migration on both). Ship — still
  fully local, but now provably mergeable.
- **Phase B — Real identity.** Swap the auth seam to Clerk on both apps; demo stays local.
  Ship — one shared account exists, state still device-local.
- **Phase C — Sync.** Stand up the Worker + store + the client sync loop behind a feature
  flag; local remains truth, cloud mirrors. Beta on both platforms.
- **Phase D — Realtime + migration UX + hardening.** Rev-bump stream, "bring your season"
  flow, telemetry, rate limits. GA.
- **Later — social graph.** Only after the above: move the "circle" (curlers you follow,
  their posts/spiels) from seed to a real multi-user graph. This is a bigger schema and is
  intentionally out of v1.

---

## 12. Verification

- **Merge fixtures:** `data/merge-fixtures.json` of `(a, b) → expected` cases; both the JS
  and Swift merges must reproduce them. Add to `verify-parity.js` (JS side) + an XCTest
  (Swift side). Same shared-contract pattern as the seed.
- **Property tests:** assert merge commutativity, idempotency, associativity on random
  inputs (convergence proof).
- **Multi-client integration:** two headless clients make offline edits, then sync — assert
  identical converged state (extend the existing Playwright smoke with a stubbed API).
- **Parity gate:** add sync-seam capability tokens to `verify-parity.js` so the sync layer
  can't land on one platform only.

---

## 13. Decision — LOCKED: Option A (Clerk + Cloudflare Workers + D1)

Chosen 2026-07-06. Concrete component map:

| Concern | Component | Notes |
|---|---|---|
| Auth | **Clerk** | `@clerk/clerk-js` (web), Clerk iOS SDK / `ASWebAuthenticationSession` (iOS). JWT `sub` = `userId`. |
| Sync API | **Cloudflare Worker** (`api/`) | One Worker: verifies Clerk JWT (JWKS), routes `GET/POST /v1/state`, imports the shared `merge.js`. |
| Store | **D1** (SQLite) | Table `state(user_id PK, doc JSON, rev INT, updated_at INT)`. One row per user. |
| Realtime | **Durable Object** (per user) or SSE | v1 can poll on foreground; add DO/SSE rev-bump in Phase D. |
| Shared merge | `src/merge.js` (JS) + `Merge.swift` | Same algebra; cross-tested against `data/merge-fixtures.json`. |
| Config | `wrangler.toml` | D1 binding, Clerk JWKS URL / issuer as vars; CORS allowlist = the Pages origin. |

New repo layout additions (proposed):
```
api/
├── wrangler.toml
├── src/index.js        # Worker: auth + routes
└── src/merge.js        # shared merge algebra (also imported by index.html build)
data/merge-fixtures.json # cross-platform merge test vectors
ios/CurlPlan/Sync/       # SyncClient.swift, Merge.swift, ClerkAuth.swift
```

### Phase A — DONE (2026-07-06), no cloud credentials needed
Proven the merge algebra cross-platform, standalone (not yet wired into the live Store):
1. ✅ `src/merge.js` + `data/merge-fixtures.json` (LWW + OR-Set algebra, 9 vectors).
2. ✅ `ios/CurlPlan/Merge.swift` — Swift port over a generic `JSONValue`, so it runs the
   *same* fixtures as JS.
3. ✅ `scripts/verify-merge.js` (JS) + `ios/CurlPlanTests/MergeTests.swift` (Swift) both
   run the fixtures + assert commutativity / idempotency / associativity; both wired into CI.
4. ✅ `generate-xcodeproj.js` now emits a **unit-test target**, so CI runs the Swift tests
   (StoreTests + MergeTests) via `xcodebuild test` — real Swift verification.

Deferred to Phase C (folds in with the sync loop, to avoid a risky schema churn on the
live apps for no user-facing benefit yet):
- Bump both live stores to schema **v3** (map buckets → `{v, at}`) + migrations
  (`migrateLegacyStore` / `migrateLegacyIfNeeded`), and route reads through merged data.

Phases B–D (Clerk swap, Worker+D1 sync loop, realtime+migration) require Cloudflare and
Clerk credentials/keys and a deploy target — they come after.
