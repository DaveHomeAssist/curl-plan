# Custom account backend verifier

This zero-dependency service is a quarantined development verifier. It is not a
production identity or data authority; the selected production boundary is the
Clerk + Cloudflare Worker/D1 plane documented in `api/README.md`.
The operational authority, TLS rules, recovery procedure, and incident response
live in `docs/SECURITY.md`.

Writes require `CURLPLAN_ACCOUNT_BACKEND_MODE=development`. Production-shaped
defaults stay quarantined. Development runs should also set:

- `CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS` to a comma-separated list of exact
  origins. Credentialed CORS never uses a wildcard.
- `CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY=true` only when a known reverse proxy
  overwrites `X-Forwarded-For`. Otherwise the socket address owns rate limits.
- a persistent `CURLPLAN_ACCOUNT_BACKEND_STORE` path with restricted access.
- bounded timeout, session, limiter, account, and session-cap variables exposed
  by the Dockerfile. Invalid or out-of-range values fall back to safe defaults.

The service caps JSON requests at 1 MB, season documents at 512 KiB, structural
depth and collection growth, account count, active sessions per account, and
sign-in limiter buckets. Sign-in uses asynchronous scrypt, NFKC-normalized
passwords, equivalent work for missing handles, generic failures, account and
source rate limits, and telemetry containing only hashes. Legacy raw-password
scrypt records are verified once and migrated to the versioned NFKC scheme.
Sessions expire after 30 days and are rechecked on every request.

If a controlled development deployment is needed, terminate TLS at a managed
reverse proxy, forward only to the private container port, impose a 15-second
upstream timeout and a 1 MB body limit, strip client-supplied forwarding
headers, and enable trusted-proxy mode only after that stripping rule is
verified. Back up the manifest plus its `.records` directory together. Restore
both into an offline instance and run `scripts/verify-account-remote.mjs`
before repointing a client.

The release/incident owner must revoke exposed sessions, preserve the affected
store for investigation, rotate proxy access where applicable, restore the
last verified pair of manifest and records, and keep the service quarantined
until the local abuse, lifecycle, persistence, and recovery suite passes. The
service must not be exposed publicly as a substitute for the selected Worker
boundary.
