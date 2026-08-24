# 2026-08-24 audit remediation evidence

Status: P0 through P3 locally verified; the P4 implementation is locally verified but its controlled TLS staging exit remains open. P5, the current-revision Wrangler lifecycle rerun, and all external release gates remain open.

## Authority

- Repository: `DaveHomeAssist/curl-plan`
- Audited baseline: `541695dce342ce44fab7d0f4c76e5ea7dfb21357`
- Local branch: `codex/curlplan-audit-remediation-20260824`
- P0 change commit: `73523784ed6bb0eb0350b6feea481fd9620d1c45`
- P1 change commit: `6749e1e46e77b4420c680eea56227eeaf3b6fffc`
- P2 change commit: `f659a2914291034e04b846818c088925f296eb16`
- P3 change commit: `af8ac0f33c8dd899573c373bc0f40599e9d0cb62`
- P4 local implementation commit: `77908ad4addba038b28b59df7208e502db45d92a`
- Release owner: Dave Robertson
- Evidence date: 2026-08-24 EDT

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
change was made.

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
| Hosted CI on the local phase commits | Open | Push is explicitly outside the authorized program scope |
| Current-revision Wrangler dry-run | Open | Typecheck, lint, API behavior, and direct esbuild passed; the P4 Wrangler 4.123.0 attempt produced no output after 45 seconds beyond startup and was interrupted. APFS remained 99-percent full |
| Xcode project tests | Open | The unsigned P4 simulator app build passed for arm64 and x86_64; Xcode unit/UI scheme execution remains deferred to P5 dependency order |
| Signed archive resource inspection | Open | Requires P5 and signing authority |
| Controlled TLS staging boundary | Open | No staging deployment or credential authority granted |
| Deployment smoke | Open | Deployment is explicitly unauthorized in this program run |
| Monitoring | Open | No deployed candidate exists |
| Backup and restore drill | Open | The authority is selected, but no live D1 database or migration/deployment authority exists for a production drill |
| Rollback | Open | Candidate rollback is a revert of the local P4-to-P0 phase commits; no D1 down-migration exists and no live migration was run |

## Phase status

| Phase | Status | Remaining gate |
|---|---|---|
| P0 Honest release baseline | Closed locally | Hosted CI remains an operational release gate, not a P0 code gate |
| P1 Classic workflows and recovery | Closed locally | Hosted CI remains an operational release gate; no push or deployment was authorized |
| P2 Root web and offline boundaries | Closed locally | Root semantics, durable recovery, bounded import, install assets, and cross-app offline/cache isolation pass locally; manual VoiceOver remains a final release gate |
| P3 Atomic data ownership | Closed locally | Clerk + Worker/D1 is the sole production plane; schema 4 CAS/idempotency/lifecycle, hostile-key, bounded-growth, rejected-plane quarantine, per-record development commits, and Swift rollback pass locally. No D1 migration or live cutover was authorized |
| P4 Identity and abuse boundaries | Local implementation verified; exit open | Token/JWKS, password, authorization, blocking, CORS, session, quota, telemetry, and resumable recovery pass locally. The required controlled TLS staging boundary was not created because deployment and credential authority were explicitly withheld |
| P5 Native and release readiness | Not started | P4 has not met its controlled TLS staging exit, so strict dependency order blocks P5 |

This record must not be used to claim the full remediation program or a production release is complete.
