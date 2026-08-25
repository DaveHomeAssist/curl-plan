# 2026-08-24 audit remediation evidence

Status: P0 through P3 are locally verified and the P4 controlled TLS staging exit is closed with isolated cloud D1 migration plus live Clerk JWT/JWKS, CORS, lifecycle, deployment, and cleanup proof. P5 is unlocked but not started; the remaining external release gates remain open.

## Authority

- Repository: `DaveHomeAssist/curl-plan`
- Audited baseline: `541695dce342ce44fab7d0f4c76e5ea7dfb21357`
- Local branch: `codex/curlplan-audit-remediation-20260824`
- P0 change commit: `73523784ed6bb0eb0350b6feea481fd9620d1c45`
- P1 change commit: `6749e1e46e77b4420c680eea56227eeaf3b6fffc`
- P2 change commit: `f659a2914291034e04b846818c088925f296eb16`
- P3 change commit: `af8ac0f33c8dd899573c373bc0f40599e9d0cb62`
- P4 local implementation commit: `77908ad4addba038b28b59df7208e502db45d92a`
- P4 local closure commit: `10eb4f8c0c2fc98337306d7134d9f7680fe312f6`
- Staging gate commit: `0e8e6d4d96d920936e02a1f1250fea65e7922169`
- Isolated cloud configuration commit: `313fce69e6cb006362e0fdfb83964ab35f14db92`
- Clerk issuer deployment commit: `2cdf3e2c7c2569bf01aa296bc424634bfb9b15b9`
- Disposable Clerk staging verifier commit: `e2ce7a928de16b300c1901f73d7672a8c2717e66`
- Release owner: Dave Robertson
- Evidence date: 2026-08-25 EDT

## Environment

- macOS 26.7 (`25G220`), Apple silicon
- Node `v25.8.1`; npm `11.11.0`
- Worker CI contract: Node 22 because Wrangler 4.123.0 declares `node >=22.0.0`
- Xcode 26.5 (`17F42`); unsigned generic iOS Simulator compile passed, while project tests and device evidence remain open for P5
- Root browser dependencies locked by `package-lock.json`
- Accessibility engine: `@axe-core/playwright` 4.10.2
- Worker dependencies locked by `api/package-lock.json`
- Account container base: `node:22-alpine@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32`

## P0 command evidence

| Command | Exit | Evidence |
|---|---:|---|
| `node scripts/gen-seed.js --check` | 0 | Swift SHA-256 remained `3a5d67f746b8b90c67e5d38c2d0809c23e0ad8cfb7af2537a8383aee834885f9` before and after |
| `node scripts/verify-app.js` | 0 | Root app and service worker verifier passed |
| `node scripts/verify-split.js` | 0 | Classic split verifier passed |
| `node scripts/verify-parity.js` | 0 | 12 cross-platform capability checks passed |
| `node scripts/verify-api.js` | 0 | Worker routes, auth isolation, merge, tombstones, body cap, and CORS passed |
| `node scripts/verify-merge.js` | 0 | 14 pair fixtures, associativity, and idempotency passed |
| `node scripts/verify-account-backend.mjs` | 0 | 20 account, session, sync, block, role, deletion, and restart checks passed |
| `node tests/run-stress.js` | 0 | 70 assertions passed; Planner Entries executed without a harness exception |
| `npm run test:browser` | 0 | Chromium stress harness passed; P0 Ice Notes regression retained as an expected failure with `existing is not defined` |
| `CURLPLAN_STRESS_NEGATIVE=1 npx playwright test tests/browser/stress-harness.spec.js` | 1 expected | Intentional fixture produced `75 passed, 1 failed`; the browser gate rejected it |
| `cd api && npm run typecheck` | 0 | Worker JavaScript typecheck passed |
| `cd api && npm run lint` | 0 | Three Worker modules passed syntax and source-policy checks |
| `cd api && npm test` | 0 | Behavioral API verifier passed |
| `cd api && npm run build` | 0 | Wrangler 4.123.0 dry-run bundle completed |
| `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-audit-p0-derived CODE_SIGNING_ALLOWED=NO build` | 0 | Xcode 26.5 unsigned simulator compile succeeded |

## P1 command evidence

| Command | Exit | Evidence |
|---|---:|---|
| `node scripts/verify-split.js` | 0 | Classic source, schema, script order, and parseability passed |
| `node tests/run-stress.js` | 0 | 70 assertions passed with no Classic normalization or persistence regression |
| `npm run test:browser` | 0 | 14 Chromium journeys passed: Ice Notes CRUD/failure/reload, corrupt and unavailable storage, durable reset restore, modal and scrim ownership, calendar filtering, scoped planner rendering, native controls, stress, and both-theme accessibility |
| `make feature-review CHANGED_FILES='<P1 allowlist>'` | 0 | The bounded review matrix accepted its in-scope support paths and the unsupported-authority claim scan passed |

## P2 command evidence

| Command | Exit | Evidence |
|---|---:|---|
| `node scripts/gen-seed.js --check` | 0 | Swift SHA-256 remained `3a5d67f746b8b90c67e5d38c2d0809c23e0ad8cfb7af2537a8383aee834885f9` before and after |
| `node scripts/verify-app.js` | 0 | Root semantics, persistence contract, CSP, manifest, service-worker ownership, and HTTPS club URL checks passed |
| `node scripts/verify-split.js` | 0 | Classic source, manifest, CSP, bounded import, cache ownership, schema, and parseability checks passed |
| `node scripts/verify-parity.js` | 0 | All 12 cross-platform capability checks passed after the root edit-flow update |
| `node tests/run-stress.js` | 0 | All 70 stress assertions passed |
| `npm run test:browser` | 0 | All 25 Chromium journeys passed, including root keyboard/name/CRUD/reload, failed-storage recovery, both-theme Axe coverage, 200 percent mobile-equivalent reflow, manifest assets, offline shell isolation, upgrade ownership, wrong-shell rejection, CSP, bounded imports, and HTTPS data |
| `make feature-review CHANGED_FILES='<P2 allowlist>'` | 0 | The bounded support-path review and unsupported-authority claim scan passed; this is not runtime product proof |
| `git diff --cached --check` | 0 | The exact P2 implementation allowlist contained no whitespace errors before commit |

## P3 command evidence

| Command | Exit | Evidence |
|---|---:|---|
| `node scripts/verify-merge.js` | 0 | All 14 shared pair fixtures, the three-replica associativity regression, commutativity, idempotency, tombstones, hostile-key filtering, and prototype-pollution checks passed |
| `node scripts/verify-api.js` | 0 | Schema migration wiring, atomic D1 batch tokens, concurrent same-revision convergence, stale conflict, idempotent retry and key-reuse rejection, schema 3 read migration, hostile keys, final merged size, export, restore, deletion, receipt purge, auth, and CORS checks passed |
| `node scripts/verify-account-backend.mjs` | 0 | Development service account flow, idempotency, serialized concurrency, failed-commit rollback, bounded import, deletion, restart, content-addressed record storage, corrupt-primary recovery, and production quarantine checks passed |
| `swift test --scratch-path /tmp/curlplan-p3-spm` | 0 | All 19 CurlPlanCore account, HTTP, runtime, social, sync, and persistence tests passed; the new failed-write fixture proved published memory remains unchanged |
| `cd api && npm run typecheck` | 0 | Worker JavaScript typecheck passed at the P3 revision |
| `cd api && npm run lint` | 0 | All three Worker modules passed syntax and source-policy checks |
| `cd api && ./node_modules/.bin/esbuild src/index.js --bundle --format=esm --platform=browser --target=es2022 --outfile=dist/index.js` | 0 | Direct Worker bundle completed at 21.0 kB |
| `node scripts/gen-seed.js --check` | 0 | Swift SHA-256 remained `3a5d67f746b8b90c67e5d38c2d0809c23e0ad8cfb7af2537a8383aee834885f9` before and after |
| `node scripts/verify-app.js` | 0 | Root verifier remained green |
| `node scripts/verify-split.js` | 0 | Classic verifier remained green |
| `node scripts/verify-parity.js` | 0 | All 12 web/native parity capabilities remained green |
| `make feature-review CHANGED_FILES='<P3 allowlist>'` | 0 | The bounded account/sync/trust-safety support-path review and unsupported-authority claim scan passed; this is not deployed-service proof |
| `git diff --cached --check` | 0 | The exact P3 implementation allowlist contained no whitespace errors before commit |

## P4 command evidence

Red-first proof preceded implementation: the new Worker checks reported three
JWT/JWKS failures; the custom verifier stopped at the credentialed CORS
contract; and Swift failed because recovery state did not exist. Additional
red checks rejected Worker origin handling, session expiry/quota enforcement,
record pruning, and the native post-create crash window before each production
change was made. A final exact-surface audit then failed first on the absent
development feature gate, container runtime contract, environment parser,
security authority document, and recovery UI before the local closure patch.

| Command | Exit | Evidence |
|---|---:|---|
| `node scripts/verify-api.js` | 0 | Complete issuer/audience/subject/time claims, RS256 and signing-use constraints, expired/premature/wrong-claim negatives, unknown-key refresh, legitimate rotation, stale JWKS rejection, atomic sync, hostile keys, bounded documents, lifecycle, and explicit credentialed allowlisted CORS passed |
| `node scripts/verify-account-backend.mjs` | 0 | NFKC handle/password parity, asynchronous equalized scrypt, legacy credential migration, account-plus-trusted-source rate limits, redacted telemetry, CORS, hostile input, quotas, session cap/expiry, direct block bypass, stale-role revocation, future-invitation denial, failed-commit rollback, record pruning, corrupt-primary recovery, and production quarantine passed |
| `swift test --scratch-path /tmp/curlplan-p4-final-spm` | 0 | All 24 account, HTTP, runtime, sync, persistence, social, authorization, resumable setup, crash-window, retry, and rollback tests passed |
| `cd api && npm run typecheck` | 0 | Worker JavaScript typecheck passed with required Clerk audience wiring |
| `cd api && npm run lint` | 0 | All three Worker modules passed syntax and source-policy checks |
| `cd api && ./node_modules/.bin/esbuild src/index.js --bundle --format=esm --platform=browser --target=es2022 --outfile=dist/index.js` | 0 | Direct Worker bundle completed at 23.5 kB |
| `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-p4-derived CODE_SIGNING_ALLOWED=NO build` | 0 | The full native app, including resumable account runtime and block enforcement, compiled for arm64 and x86_64 Simulator architectures |
| `node scripts/verify-merge.js` | 0 | All 14 pair fixtures, associativity, idempotency, tombstones, and hostile-key cases remained green |
| `node scripts/gen-seed.js --check` | 0 | Generated Swift seed SHA-256 remained unchanged before and after check mode |
| `node scripts/verify-app.js && node scripts/verify-split.js && node scripts/verify-parity.js` | 0 | Root, Classic, and all 12 cross-platform capability checks remained green |
| `make feature-review CHANGED_FILES='<P4 allowlist>'` | 0 | Account, sync, settings recovery, identity, relationship, shared-object, social, trust-safety, and unsupported-authority claim gates passed |
| `git diff --cached --check` | 0 | The exact P4 implementation allowlist contained no whitespace errors before commit |
| `node scripts/verify-account-backend.mjs` at `10eb4f8` | 0 | All 37 checks passed, including bounded environment parsing, invalid-value fail-closed behavior, Docker/security surface ownership, recovery UI wiring, CORS, credential abuse boundaries, authorization, persistence, and quarantine |
| `swift test --scratch-path /tmp/curlplan-p4-gap-spm` | 0 | All 25 CurlPlanCore tests passed, including the explicit development-feature gate and all lifecycle, API, persistence, sync, graph, shared-object, and safety contracts |
| `xcodebuild -quiet -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-p4-gap-derived CODE_SIGNING_ALLOWED=NO build` | 0 | The development-gated recovery view and injected runtime compiled for arm64 and x86_64 after the compiler rejected and prompted removal of an unavailable accessibility modifier |
| `make feature-review` | 0 | `AuthView.swift` is now mapped to account, settings-recovery, accessibility, and claim-control rows; all changed paths mapped and the literal unsupported-authority scan passed |
| `node --check services/account-backend/server.mjs && node --check scripts/verify-account-backend.mjs && sh -n scripts/feature_review_matrix_check.sh && git diff --check` | 0 | JavaScript, shell, and diff hygiene checks passed before the closure checkpoint |
| `node scripts/verify-d1-migration.mjs` at `0e8e6d4` | 0 | Wrangler/D1 preserved the seeded pre-v4 user, JSON document, revision, and timestamp; added only the planned state columns, receipt table, and index; accepted a receipt; and left the pre-migration backup independently readable |
| `node scripts/verify-worker-staging.mjs` against a temporary trusted-TLS fixture | 0 | The verifier itself checked TLS 1.3, RS256 token claims and JWKS signature, positive and negative auth, exact credentialed CORS, merge/idempotent retry/export/restore/delete, and final empty state against the actual Worker handler; this is harness proof, not external staging proof |
| `cd api && wrangler deploy --dry-run --outdir=dist` under Node 22 | 0 | Wrangler 4.123.0 bundled the current revision at 24.91 KiB and reported the expected D1 and Clerk/CORS bindings |
| Remote `curlplan-staging-20260825` pre-v4 export and `0002_atomic_sync_v4.sql` execution | 0 | The isolated ENAM D1 preserved the disposable document, revision 17, and timestamp; added schema version 3 and the empty idempotency default; created the receipt table/index; accepted a receipt; and produced independently readable rollback export SHA-256 `a26e99c449d3cc6091585f517679b2161ac897e5330090a0fb21c0f178b917db` before returning to zero rows |
| `wrangler deploy --env staging --strict` from pushed `313fce6` | 0 | Worker version `544eb06b-c5ce-422d-923a-9cd3b8e0fb75` deployed with the isolated D1, fail-closed empty Clerk issuer, `curlplan-api` audience, exact Pages origin, and 6 ms startup |
| Live staging OpenSSL and HTTP smoke | 0 | TLS 1.2 negotiated with certificate verification; health returned 200/schema 4; missing and malformed bearer tokens returned 401; the exact credentialed origin returned 204 with the required headers; and a disallowed origin returned 403 |
| `wrangler deploy --env staging` from pushed `2cdf3e2` | 0 | Worker version `6309a4f7-a8ee-4177-93ed-d5afe65b1570` deployed at 100 percent with the dedicated Clerk development issuer, isolated D1, `curlplan-api` audience, exact Pages origin, and 5 ms startup |
| `node scripts/verify-clerk-worker-staging.mjs` from pushed `e2ce7a9` | 0 | The dedicated Clerk development instance created the audience template plus a disposable user/session and short-lived RS256 token; TLS 1.3, token claims, live JWKS key/signature, schema 4 health, negative auth, exact CORS, merge/idempotent retry/export/restore/delete, and final empty state all passed; the session was revoked and user deleted |
| Exact post-run D1 and credential cleanup readback | 0 | The disposable subject was removed from `state` and `sync_receipts`; both exact and total counts returned zero. The temporary Clerk key was absent from Keychain and the clipboard returned zero bytes |
| `xcodebuild -quiet -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-staging-tools-derived CODE_SIGNING_ALLOWED=NO build` | 0 | The workflow-gate change retained a clean unsigned simulator compile |
| `make feature-review CHANGED_FILES='<staging gate allowlist>'` | 0 | The workflow, API docs/package, and two verification scripts mapped to build/gate support and passed the unsupported-authority claim scan |

## Browser and accessibility proof

- `Closed`: Chromium executes the repaired browser stress page without a literal closing-script parse break.
- `Closed`: the intentional failing fixture makes the Playwright gate return nonzero.
- `Closed (P1)`: Classic Ice Notes create/edit/invalid/storage-failure/reload and reset/restore journeys pass in Chromium.
- `Closed (P1)`: automated Axe scans report no violations on the base page or any of seven overlays in light and dark themes; keyboard tests cover modal ownership, focus containment and restoration, Escape, scrim close, tabs, and the Ice speed radio group.
- `Closed (P2)`: root tab, radio, native-control, naming, validation, correction, create/edit/delete/reload, and failed-storage recovery journeys pass in Chromium.
- `Closed (P2)`: automated Axe scans report no violations in both themes with every accent across Passport, Locker, contribution, correction-list, and edit-sheet states.
- `Closed with automated equivalent (P2)`: the root layout reflows without horizontal overflow or clipped controls at a 195 by 406 CSS-pixel viewport, equivalent to a 390-pixel mobile viewport at 200 percent browser zoom.
- `Open (P5)`: manual VoiceOver web proof plus VoiceOver, Dynamic Type accessibility sizes, orientation, keyboard, and reduced-motion native-device evidence.

## Operational and release gates

| Gate | Status | Evidence or blocker |
|---|---|---|
| Hosted CI on the remediation branch | Open | Branch `codex/curlplan-audit-remediation-20260824` contains pushed verifier commit `e2ce7a9`; the workflow triggers only on `main` or pull requests, and no PR was created |
| Current-revision Wrangler dry-run | Closed locally | Node 22 and Wrangler 4.123.0 bundled the current revision at 24.91 KiB with the expected D1 and Clerk/CORS bindings |
| Xcode project tests | Open | The unsigned P4 simulator app build passed for arm64 and x86_64; Xcode unit/UI scheme execution remains deferred to P5 dependency order |
| Native recovery UI runtime proof | Open | The generated project currently has only `CurlPlan` and `CurlPlanTests`, no UI-test target, and `xcrun simctl list devices available` returned no devices. Compile and source-contract proof passed; interactive recovery proof did not run |
| Account container image build | Open | The Dockerfile and runtime parser are source- and behavior-checked, but `docker` is not installed on this Mac, so the pinned image was not built or health-checked as a container |
| Signed archive resource inspection | Open | Requires P5 and signing authority |
| Isolated D1 migration rehearsal | Closed locally and in controlled cloud staging | Real Wrangler/D1 execution preserved pre-v4 data locally and on isolated ENAM D1, created schema 4 support objects, accepted a receipt, and retained independently readable pre-migration backups |
| Controlled TLS staging boundary | Closed | The isolated Worker/D1 candidate passed TLS 1.3, schema 4 health, positive RS256 JWT/JWKS verification, missing/malformed-token rejection, exact credentialed CORS, rejected-origin handling, and the full authenticated lifecycle with a disposable Clerk identity |
| Deployment smoke | Closed for controlled staging | Cloudflare readback reports Worker version `6309a4f7-a8ee-4177-93ed-d5afe65b1570` at 100 percent from pushed source `2cdf3e2`; all live health, auth, CORS, and D1 lifecycle paths passed |
| Monitoring | Open | A deployed candidate now exists, but live log and alert evidence has not been captured |
| Backup and restore drill | Closed for controlled staging | The remote D1 pre-migration export is hash-recorded and independently readable, and the authenticated API export/restore cycle recovered the original empty state before deletion |
| Rollback | Partially closed | The Worker version and source commit are identified and the pre-migration D1 export is readable; no D1 down-migration exists and an actual Worker rollback has not been exercised |

## Phase status

| Phase | Status | Remaining gate |
|---|---|---|
| P0 Honest release baseline | Closed locally | Hosted CI remains an operational release gate, not a P0 code gate |
| P1 Classic workflows and recovery | Closed locally | Hosted CI remains an operational release gate; no push or deployment was authorized |
| P2 Root web and offline boundaries | Closed locally | Root semantics, durable recovery, bounded import, install assets, and cross-app offline/cache isolation pass locally; manual VoiceOver remains a final release gate |
| P3 Atomic data ownership | Closed locally with isolated cloud migration proof | Clerk + Worker/D1 is the sole production plane; schema 4 CAS/idempotency/lifecycle, hostile-key, bounded-growth, rejected-plane quarantine, per-record development commits, Swift rollback, and local plus isolated-cloud D1 migration checks pass. No production D1 cutover has run |
| P4 Identity and abuse boundaries | Closed through controlled TLS staging | Isolated D1 migration plus Worker TLS/health, positive and negative Clerk auth/JWKS, exact CORS, authenticated merge/idempotency/export/restore/delete, deployment readback, and exact test-data cleanup all pass. Container execution and interactive recovery UI remain separate operational/P5 evidence gaps |
| P5 Native and release readiness | Unlocked; not started | P3 and P4 dependencies are satisfied. Native state ownership, archive resources, device accessibility/performance, and the final release record remain P5 work |

This record must not be used to claim the full remediation program or a production release is complete.
