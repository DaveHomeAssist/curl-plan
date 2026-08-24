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
The verifier requires an RS256 signing key and complete `iss`, `aud`, `sub`,
`exp`, `nbf`, and `iat` claims. It allows 30 seconds of clock skew, caps token
age at one hour, honors the configured JWKS cache, and performs exactly one
no-cache refresh for an unknown key id before failing closed.

Browser access is credentialed and origin-specific. `CORS_ORIGIN` must be one
exact HTTPS origin; wildcard and unlisted origins fail closed. Preflights allow
only the documented methods plus `Authorization` and `Content-Type`, and all
origin-dependent responses carry `Vary: Origin`.

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
#   CLERK_AUDIENCE = "curlplan-api"
#   CORS_ORIGIN    = "https://davehomeassist.github.io"
npm run deploy                   # → note the *.workers.dev URL (becomes the clients' API base)
```

For an existing original-schema database, take a backup/export and row count,
then run `npm run db:migrate:v4:remote` exactly once instead of reapplying the
fresh schema. No migration or deployment is performed by repository verification.

Before exposure, deploy to a controlled TLS staging hostname, configure the
same issuer, audience, and origin as the staging client, and run the negative
token, key-rotation, CORS, size, concurrency, export, restore, and deletion
suite against that boundary. Cloudflare owns TLS termination and request
timeouts for the Worker; the handler independently caps request and final
document size. The release owner is responsible for Clerk key or audience
incidents, Cloudflare Worker/D1 rollback, and restoring D1 from the
pre-migration export. Do not run a live migration without a row-counted backup,
a rollback decision, and explicit deployment authority.

The repository keeps the migration and live-boundary checks executable:

```bash
# Runs the real Wrangler/D1 migration against a disposable pre-v4 local DB,
# proves row preservation and the receipt schema, and verifies its backup.
npm run test:migration

# Requires a fresh disposable Clerk staging user whose JWT uses the configured
# curlplan-api audience. Keep the token in the environment; never paste it into
# a command, report, issue, or tracked file.
CURLPLAN_STAGING_URL=https://<worker>.workers.dev \
CURLPLAN_STAGING_ORIGIN=https://<staging-client> \
CURLPLAN_STAGING_TOKEN="$CURLPLAN_STAGING_TOKEN" \
npm run test:staging
```

The live verifier requires HTTPS, independently verifies the supplied JWT
against the issuer's JWKS, checks exact credentialed CORS and negative auth,
then exercises merge, idempotent retry, export, restore, deletion, and final
empty-state readback. It refuses to mutate a non-empty account state.

## What I still need from you to go live
1. **Clerk** (non-secret): publishable key + instance issuer URL.
2. **Cloudflare**: run the commands above; give me the **database_id** and the deployed
   **Worker URL**.
3. Confirm the **token audience**, exact **web origin**, and **iOS bundle id**.

Then the client sync loop (web + iOS, behind a feature flag) points at the Worker URL and
sync is live. No client code needs your secrets.
