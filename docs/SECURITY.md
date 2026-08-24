# CurlPlan security authority and incident runbook

## Production authority

Clerk is the production identity authority. The Cloudflare Worker and D1 schema
under `api/` are the production API and account-data authority. The custom
handle/password service under `services/account-backend/` is a quarantined
development verifier; it must not be promoted, published, or treated as a
production credential store.

Worker requests fail closed unless the token issuer and audience match the
configured Clerk values and the token carries valid `sub`, `exp`, `nbf`, and
`iat` claims. Only RS256 signing keys with compatible JWK metadata are accepted.
The Worker caches its JWKS set and performs one uncached refresh for an unknown
key ID before rejecting the request.

## Transport boundary

- **TLS termination:** Cloudflare owns TLS for the production Worker. A controlled
  development instance of the custom service must terminate TLS at a managed
  reverse proxy and forward only to a private container port.
- **Trusted proxy:** leave
  `CURLPLAN_ACCOUNT_BACKEND_TRUST_PROXY=false` unless a known proxy strips every
  client-supplied forwarding header and writes the authoritative source address.
- **CORS:** configure exact origins with
  `CURLPLAN_ACCOUNT_BACKEND_ALLOWED_ORIGINS`. Credentialed responses never use a
  wildcard. The production Worker also fails closed when its exact origin is
  absent.
- **Request bounds:** the service defaults to a 15-second request timeout, a
  1 MB JSON body limit, a 512 KiB season limit, and bounded object depth, keys,
  and collection growth. The reverse proxy must enforce an equal or smaller
  timeout and body limit.
- **Container state:** persist `/data`, run as the image's non-root `node` user,
  and keep the default mode `quarantined`. Setting mode to `development` enables
  writes and is allowed only in a controlled development environment.

## Identity and abuse boundary

The development verifier uses asynchronous scrypt with NFKC-normalized
passwords, equivalent hashing work for an unknown handle, generic sign-in
failures, and account-plus-source throttling. Security telemetry contains only
truncated hashes. Configuration values are parsed through bounded server
options; malformed or out-of-range values fall back to conservative defaults.

Session expiry defaults to 30 days. Every request rechecks expiry, and each
account is capped at five active sessions by default. Rate-limiter buckets,
account count, and session count are bounded. These development controls do not
replace Clerk's production session and abuse controls.

Authorization is object-scoped. Shared-object membership and role determine
read or mutation access. Blocking is enforced in both directions for social
relationships, messaging, and direct interaction. Account deletion revokes
sessions and removes account-owned records.

## Recovery and rollback

Recovery of the custom service requires the manifest and its sibling `.records`
directory from the same backup point. Restore both to an offline instance, keep
it quarantined, and run `node scripts/verify-account-remote.mjs <private-url>`
before any development client is repointed. Do not overwrite the only known-good
backup during a restore attempt.

The native partial-account lifecycle stores only the handle, account ID, and
last completed stage. Its password is never persisted. Retry and rollback are
visible only when the development feature flag and backend URL were explicitly
provided and an interrupted lifecycle exists. Retry is idempotent; rollback
deletes the partial backend account and leaves the device's local season intact.

## Incident response

Incident owner: Dave Robertson, acting as CurlPlan release owner. If ownership
changes, update this runbook before the next controlled staging exercise.

1. Quarantine the affected plane and stop new writes. Do not delete evidence.
2. Revoke exposed sessions and rotate affected proxy or provider credentials
   through their owning secret store; never write secrets into the repository.
3. Preserve the affected D1 export or custom-service manifest-plus-records pair
   with timestamps and hashes.
4. Determine whether the production Clerk/Worker plane or the development
   verifier was involved; do not infer one plane's state from the other.
5. Restore into an isolated target and run the API, abuse, persistence, and
   recovery suites before reconnecting any client.
6. Record the incident, affected interval, owner, credential rotations, restore
   evidence, and explicit release decision.

No public deployment, live migration, or credential rotation is performed by
the local P4 verification workflow. Those actions require separately recorded
authority and a controlled TLS staging target.
