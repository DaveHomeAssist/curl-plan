# Identity and data ownership decision

Status: Accepted locally on 2026-08-24. Not deployed.

## Decision

CurlPlan has one production account plane: Clerk owns identity and session
issuance, and the CurlPlan Cloudflare Worker with D1 owns the canonical season
document. Together they are one boundary; neither component may be replaced by
the custom credential service or a client-local store in a production claim.

| Responsibility | Sole production authority |
|---|---|
| Identity, authentication, session issuance, identity recovery, identity deletion | Clerk |
| Season state, revision, merge, idempotency, export, season deletion, and restore | Worker/D1 |
| Migration execution and compatibility enforcement | Worker/D1 deployment owner |

The root preview and Classic remain separate local products. Their browser
stores are not production account state. The native custom-account transport is
a development contract seam until a Clerk-authenticated Worker client replaces
it.

## Canonical contract

- Schema version: sync schema 4, including top-level tombstones.
- Document limit: 512 KiB after canonical merge or restore, measured as UTF-8.
- Write identity: a non-empty client idempotency key, at most 128 characters,
  scoped to the Clerk subject.
- Idempotency: D1 stores a SHA-256 request fingerprint and the successful
  response in the same atomic batch as the state revision. Reusing a key for a
  different request fails closed.
- Revision: clients send the last observed non-negative revision. A stale
  initial revision returns `REVISION_CONFLICT` with canonical current state. Two
  writes that both began on the same revision are merged through at most three
  conditional compare-and-swap attempts, so both CRDT changes converge without
  a lost update.
- Conflict response: code, current revision, schema version, and canonical
  current state are deterministic.
- Boundary validation: unknown state buckets, dangerous object keys, excessive
  depth, excessive key or collection growth, oversized requests, and oversized
  final documents are rejected before publication.

## Lifecycle contract

- `GET /v1/export` returns the canonical schema, revision, and season state.
- `POST /v1/restore` atomically replaces state at an expected revision and is
  idempotent.
- `DELETE /v1/state` atomically commits an empty schema 4 state while advancing
  revision history; it does not reset the revision to zero.
- Production account deletion is not complete until Clerk identity deletion and
  Worker season deletion both succeed. That orchestration remains a release
  blocker; the public product must not expose account creation before it exists.

## Migration and compatibility

D1 is the migration owner. Fresh databases use `api/schema.sql`. A database
created with the original schema runs
`api/migrations/0002_atomic_sync_v4.sql` exactly once before the schema 4 Worker
is promoted. Existing schema 3 rows are readable through the additive
tombstone migration and become schema 4 on their first successful schema 4
write.

Schema 3 clients are read-compatible but cannot write. The compatibility window
ends 90 days after the first production migration activation; because no
production migration has been authorized or run, that clock has not started.
Before any migration, the release owner must capture a D1 backup/export and a
row count. Rollback may revert Worker code only while it still understands the
schema 4 columns and receipts; destructive down-migration is prohibited.

## Rejected plane

`services/account-backend` is rejected as a production identity or season
authority. It defaults to `quarantined`, reports `writable: false`, and returns
`PLANE_QUARANTINED` for account routes. Explicit `development` mode exists only
for local and private contract verification.

Its retained development storage serializes mutations, stages memory until an
atomic commit succeeds, stores content-addressed per-record blobs behind an
atomically replaced manifest, recovers from a backup manifest, validates schema
4 season imports, and keeps idempotency receipts. Those safeguards do not grant
it production authority. The Dominic script explicitly opts into development
mode and is not a production deployment path.

## Activation gates

No live Clerk, D1 migration, Worker deployment, credential rotation, or client
cutover occurred in this decision. Production activation still requires the P4
identity/abuse gates, P5 native/client proof, a backup and restore drill, hosted
CI, controlled staging, rollback rehearsal, and explicit release authority.
