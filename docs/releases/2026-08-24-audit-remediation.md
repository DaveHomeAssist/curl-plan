# 2026-08-24 audit remediation evidence

Status: P0 locally verified; P1 through P5 and all external release gates remain open.

## Authority

- Repository: `DaveHomeAssist/curl-plan`
- Audited baseline: `541695dce342ce44fab7d0f4c76e5ea7dfb21357`
- Local branch: `codex/curlplan-audit-remediation-20260824`
- P0 change commit: `Open` until the local checkpoint is committed
- Release owner: Dave Robertson
- Evidence date: 2026-08-24 EDT

## Environment

- macOS 26.7 (`25G220`), Apple silicon
- Node `v25.8.1`; npm `11.11.0`
- Worker CI contract: Node 22 because Wrangler 4.123.0 declares `node >=22.0.0`
- Xcode 26.5 (`17F42`); unsigned generic iOS Simulator compile passed, while project tests and device evidence remain open for P5
- Root browser dependencies locked by `package-lock.json`
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

## Browser and accessibility proof

- `Closed`: Chromium executes the repaired browser stress page without a literal closing-script parse break.
- `Closed`: the intentional failing fixture makes the Playwright gate return nonzero.
- `Open (P1)`: Classic Ice Notes create/edit/reload/storage-failure journeys.
- `Open (P1/P2)`: automated accessibility scans, full overlay keyboard inspection, light/dark contrast, and 200 percent web zoom.
- `Open (P5)`: VoiceOver, Dynamic Type accessibility sizes, orientation, keyboard, and reduced-motion device evidence.

## Operational and release gates

| Gate | Status | Evidence or blocker |
|---|---|---|
| Hosted CI on the P0 commit | Open | Push is explicitly outside the authorized program scope |
| Xcode project tests | Open | Unsigned compile passed; unit/UI tests remain deferred to P5 dependency order |
| Signed archive resource inspection | Open | Requires P5 and signing authority |
| Controlled TLS staging boundary | Open | No staging deployment or credential authority granted |
| Deployment smoke | Open | Deployment is explicitly unauthorized in this program run |
| Monitoring | Open | No deployed candidate exists |
| Backup and restore drill | Open | Production data authority is not selected until P3 |
| Rollback | Open | Candidate rollback is `git revert <P0 checkpoint>`; not exercised |

## Phase status

| Phase | Status | Remaining gate |
|---|---|---|
| P0 Honest release baseline | Closed locally | Commit this checkpoint; hosted CI remains an operational release gate, not a P0 code gate |
| P1 Classic workflows and recovery | Open | Depends on P0 checkpoint |
| P2 Root web and offline boundaries | Open | Depends on P0 checkpoint |
| P3 Atomic data ownership | Open | Depends on P0 checkpoint and architecture decision |
| P4 Identity and abuse boundaries | Open | Depends on P3 |
| P5 Native and release readiness | Open | Depends on P3 and P4 |

This record must not be used to claim the full remediation program or a production release is complete.
