# CurlPlan Feature Review Packet

Date: 2026-06-27

Reviewer: Codex

Change: `2344504 Close CurlPlan truth loop audit`

## Changed Files

| Path | Source |
| --- | --- |
| `ios/CurlPlan/PassportView.swift` | Commit `2344504` |
| `ios/CurlPlan/SpielsView.swift` | Commit `2344504` |
| `docs/curlplan-rigorous-truth-implementation-plan-2026-06-26.md` | Commit `2344504` |
| `docs/curlplan-ui-screenflow-evidence-2026-06-26.md` | Commit `2344504` |
| `docs/curlplan-visible-claim-ledger-2026-06-26.md` | Commit `2344504` |

## Impacted Feature Rows

| Row ID | Feature area | Why impacted | Current rating |
| --- | --- | --- | --- |
| `FR-PASSPORT` | Passport summary | Passport route distance and recent stop surfaces changed | Green |
| `FR-STOPS` | Stop visits and map | Passport/Map stop summary surfaces changed | Green |
| `FR-RESULTS` | Results | Result-derived Passport facts and bonspiel confirmation paths are represented | Green |
| `FR-ATTENDANCE` | Spiel attendance | Spiels detail surface is in the changed file | Green |
| `FR-BONSPIEL-ROSTER` | Bonspiel roster | Spiels detail roster controls were added | Green |
| `FR-BONSPIEL-LINEUP` | Bonspiel lineup | Spiels detail lineup controls were added | Green |
| `FR-BONSPIEL-SCORE` | Bonspiel scorecard | End scoring, forfeit, validation, and confirmation controls were added | Green |
| `FR-A11Y` | Small screen and accessibility reachability | New UI identifiers and reachable controls were added | Green |
| `FR-CLAIMS` | Unsupported authority guardrails | User-facing claims changed and were scanned | Green |
| `docs-only` | Documentation | Truth plan, ledger, and UI evidence docs were added | Green |

## Truth Loop Review

| Dimension | Evidence | Result |
| --- | --- | --- |
| Source owner named | Matrix and claim ledger name `Store.seasonSummary`, `StopVisit`, `BonspielRecord`, `BonspielGame`, `BonspielScoreAgreement`, and `BonspielResultFlags` | Pass |
| Entry path reachable | UI evidence covers Passport, Spiels detail, Settings, Locker, Roster, Stop Detail, Profile, and setup paths | Pass |
| Completion path works | Screenflows cover result, stop visit, roster, attendance, lineup, scorecard, export/import, reset, and small screen loops | Pass |
| Correction or recovery exists | Result edit/delete/undo, visit end, roster delete cleanup, invalid import preservation, scorecard validation, and clear/reset confirmation are documented | Pass |
| Propagation uses same source | Claim ledger maps visible claims to selectors and mutation paths | Pass |
| Relaunch persistence proven | UI evidence names relaunch survival for every primary loop | Pass |
| Claim control clean | Static scans found no unsupported public, official, GPS, here now, likes, or comments claims | Pass |

## Commands Run

| Command | Result | Evidence |
| --- | --- | --- |
| `swift test --scratch-path /tmp/curlplan-spm-build` | Pass | 28 tests, 0 failures on 2026-06-27 |
| `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived-status CODE_SIGNING_ALLOWED=NO build` | Pass | Build succeeded on 2026-06-27 |
| `rg -in "likes\|comments\|public roster\|here now\|GPS verification\|official result" ios/CurlPlan ios/CurlPlanUITests tests/CurlPlanCoreTests -g '*.swift'` | Pass | No matches |
| `rg -in "\b(Text\|Label\|Button)\([^\n]*(official\|public roster\|likes\|comments\|gps\|here now\|live)" ios/CurlPlan -g '*.swift'` | Pass | No matches |
| `git diff --check` | Pass | Clean for committed files |

## Screenflow Evidence

| Screenflow | Required? | Result | Evidence |
| --- | --- | --- | --- |
| SF 01 setup | Yes | Pass | `docs/curlplan-ui-screenflow-evidence-2026-06-26.md` |
| SF 02 results | Yes | Pass | `testCleanInstallLockerLoopSurvivesRelaunch` |
| SF 03 stops | Yes | Pass | `testStopVisitLoopSurvivesRelaunchAndCanEnd` |
| SF 04 roster/profile | Yes | Pass | `testProfileShareAndDeleteCleanReferencesAcrossRelaunch`, route/circle proof |
| SF 05 attendance | Yes | Pass | Locker attendance toggle and Spiels cross-check |
| SF 06 bonspiel roster/lineup | Yes | Pass | `testBonspielRosterAndLineupManagementSurvivesRelaunch` |
| SF 07 bonspiel scorecard | Yes | Pass | `testBonspielScorecardLoopSurvivesRelaunch`, scorecard edge proof |
| SF 08 locker/discover | Yes | Pass | `testDiscoverFollowActionPersistsToCircleState`, feed search proof |
| SF 09 settings recovery | Yes | Pass | export, import, failed import, return to setup proofs |
| SF 10 accessibility/small screen | Yes | Pass | `/tmp/curlplan-sf10-mini-final.xcresult` |

## Residual Risk

| Risk | Owner | Disposition |
| --- | --- | --- |
| Aggregate full UI suite bundle was intentionally not used because it had stalled in an earlier run | CurlPlan maintainer | Follow targeted screenflow proof unless a future broad navigation change requires another aggregate run |

## Release Call

| Field | Value |
| --- | --- |
| Lowest row rating | Green |
| Ship decision | Ship local truth-loop contract |
| Required follow-up | Run impacted rows again after future feature changes |

## Definition Of Done Check

1. Changed files are mapped to feature review rows.
2. Every impacted row has a truth owner.
3. Every impacted row has an entry, completion, correction, propagation, and persistence path.
4. Unsupported authority scans return no unbacked matches.
5. Model proof is run or explicitly marked not applicable with a reason.
6. UI proof is run or explicitly marked not applicable with a reason.
7. Build proof is run when Swift source or Xcode project files change.
8. Commands, results, residual risks, and lowest feature rating are recorded.
9. Final release call uses the lowest impacted rating.
