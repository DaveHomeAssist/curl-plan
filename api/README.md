# CurlPlan sync API (Cloudflare Worker + D1)

The unified-backend sync endpoint. Verifies a Clerk JWT, then reads/writes one converged
state document per user in D1. Correctness comes from the shared CRDT merge
([`../src/merge.js`](../src/merge.js)) — the Worker just merges on write. See
[`../docs/UNIFIED_BACKEND_FRAMEWORK.md`](../docs/UNIFIED_BACKEND_FRAMEWORK.md).

## Endpoints
| Method | Path | Auth | Returns |
|---|---|---|---|
| GET | `/health` | — | `{ ok, ts }` |
| GET | `/v1/state` | Bearer JWT | `{ state, rev }` |
| POST | `/v1/state` | Bearer JWT | `merge(stored, body.state)` → `{ state, rev }` |

`user_id` is taken from the verified token's `sub` — never from the request body.

## Layout
- `src/index.js` — Worker entry; wires the D1 binding + Clerk verifier into the handler.
- `src/handler.js` — pure, dependency-injected request handler (routes, merge, sanitize, CORS).
- `src/auth.js` — Clerk JWT verification against the public JWKS (no Clerk secret needed).
- `schema.sql` — D1 table.
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

## What I still need from you to go live
1. **Clerk** (non-secret): publishable key + instance issuer URL.
2. **Cloudflare**: run the commands above; give me the **database_id** and the deployed
   **Worker URL**.
3. Confirm the **web origin** and **iOS bundle id** for CORS / allowed origins.

Then the client sync loop (web + iOS, behind a feature flag) points at the Worker URL and
sync is live. No client code needs your secrets.
