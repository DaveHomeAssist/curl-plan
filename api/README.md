# CurlPlan sync API (Cloudflare Worker + D1)

The sole production season-state endpoint. It verifies a Clerk JWT, then reads
or atomically writes one converged schema 4 document per user in D1. Correctness comes from the shared CRDT merge
([`../src/merge.js`](../src/merge.js)) — the Worker just merges on write. See
[`../docs/UNIFIED_BACKEND_FRAMEWORK.md`](../docs/UNIFIED_BACKEND_FRAMEWORK.md).

## Endpoints
| Method | Path | Auth | Returns |
|---|---|---|---|
| GET | `/health` | — | `{ ok, ts }` |
| GET | `/v1/state` | Bearer JWT | `{ schemaVersion, state, rev }` |
| POST | `/v1/state` | Bearer JWT | Atomic CRDT merge with revision and idempotency checks |
| GET | `/v1/export` | Bearer JWT | Canonical versioned state export |
| POST | `/v1/restore` | Bearer JWT | Atomic state replacement at an expected revision |
| DELETE | `/v1/state` | Bearer JWT | Atomic empty-state commit that advances revision |

Writes provide `schemaVersion: 4`, `baseRev`, `idempotencyKey`, and `state`
(except delete, which has no state). D1 commits the state and idempotency receipt
in one batch guarded by a revision predicate. A stale initial revision returns a
deterministic current-state envelope. The final canonical document, not only the
incoming fragment, is capped at 512 KiB.

`user_id` is taken from the verified token's `sub` — never from the request body.

## Layout
- `src/index.js` — Worker entry; wires the D1 binding + Clerk verifier into the handler.
- `src/handler.js` — pure, dependency-injected request handler (routes, merge, sanitize, CORS).
- `src/auth.js` — Clerk JWT verification against the public JWKS (no Clerk secret needed).
- `schema.sql` — fresh D1 schema 4 tables.
- `migrations/0002_atomic_sync_v4.sql` — one-time additive migration for a database created with the original schema.
- The handler is unit-tested under Node by [`../scripts/verify-api.js`](../scripts/verify-api.js) (in CI).

## Deploy (what you run once accounts exist)
```bash
cd api
npm install                      # wrangler
npx wrangler login               # Cloudflare account

npx wrangler d1 create curlplan  # → copy the printed database_id into wrangler.toml
npm run db:init:remote           # apply schema.sql to the remote D1

# set config in wrangler.toml [vars]:
#   CLERK_ISSUER = "https://<your-app>.clerk.accounts.dev"
#   CORS_ORIGIN  = "https://davehomeassist.github.io"
npm run deploy                   # → note the *.workers.dev URL (becomes the clients' API base)
```

For an existing original-schema database, take a backup/export and row count,
then run `npm run db:migrate:v4:remote` exactly once instead of reapplying the
fresh schema. No migration or deployment is performed by repository verification.

## What I still need from you to go live
1. **Clerk** (non-secret): publishable key + instance issuer URL.
2. **Cloudflare**: run the commands above; give me the **database_id** and the deployed
   **Worker URL**.
3. Confirm the **web origin** and **iOS bundle id** for CORS / allowed origins.

Then the client sync loop (web + iOS, behind a feature flag) points at the Worker URL and
sync is live. No client code needs your secrets.
