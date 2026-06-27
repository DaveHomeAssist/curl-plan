# CurlPlan UI Screenflow Evidence

Date: 2026-06-26

Target: `ios/CurlPlan.xcodeproj`

Device:

| Field | Value |
| --- | --- |
| Simulator | CurlPlan Audit iPhone 17 |
| UDID | `43CF768A-3A31-4541-9D67-0595F6BBCF67` |
| Runtime | iOS 26.5 |

Command:

```sh
xcodebuild test -quiet -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'id=43CF768A-3A31-4541-9D67-0595F6BBCF67' -derivedDataPath /tmp/curlplan-ui-derived CODE_SIGNING_ALLOWED=NO -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests
```

Full suite result summary from `.xcresult` tests view:

| Metric | Value |
| --- | --- |
| Result | Passed |
| Passed tests | 7 |
| Failed tests | 0 |
| Skipped tests | 0 |
| Started | 2026-06-26 03:51:47 -0400 |
| Finished | 2026-06-26 03:59:11 -0400 |
| Result bundle | `/tmp/curlplan-ui-derived/Logs/Test/Test-CurlPlan-2026.06.26_03-51-47--0400.xcresult` |

Note: the `xcresulttool get test-results tests` view returned the seven passed tests below. The summary view for this result bundle returned an `XCResultDataViews.Database.DBError`, so this file relies on the tests view and the successful `xcodebuild test` exit code.

Disk note: several earlier `/tmp` result bundles listed below were removed during local disk recovery after their pass/fail outcome was recorded. The retained CurlPlan result bundles at closeout include `/tmp/curlplan-truth-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-58-53--0400.xcresult`, `/tmp/curlplan-sf10-iphone17.xcresult`, `/tmp/curlplan-sf10-mini-final.xcresult`, and `/tmp/curlplan-edge-ui.xcresult`.

Post cleanup targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testExportClearImportRecoveryLoopSurvivesRelaunch` |
| Result | Passed |
| Duration | 2m 8s |
| Result bundle | `/tmp/curlplan-ui-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-04-10--0400.xcresult` |

Result propagation targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testCleanInstallLockerLoopSurvivesRelaunch` |
| Result | Passed |
| Duration | 2m 48s |
| Result bundle | `/tmp/curlplan-ui-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-15-51--0400.xcresult` |

Stop visit people met targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testStopVisitLoopSurvivesRelaunchAndCanEnd` |
| Result | Passed |
| Duration | 1m 3s |
| Result bundle | `/tmp/curlplan-ui-derived-sf03/Logs/Test/Test-CurlPlan-2026.06.26_04-26-05--0400.xcresult` |

Profile share and delete targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testProfileShareAndDeleteCleanReferencesAcrossRelaunch` |
| Result | Passed |
| Duration | 1m 34s |
| Result bundle | `/tmp/curlplan-truth-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-34-58--0400.xcresult` |

Feed search and filter targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testLockerFeedSearchFilterAndBackingSourceDeletionSurvivesRelaunch` |
| Result | Passed |
| Duration | 1m 13s |
| Result bundle | `/tmp/curlplan-truth-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-40-37--0400.xcresult` |

Recovery import targeted rerun:

| Field | Value |
| --- | --- |
| Tests | `testExportClearImportRecoveryLoopSurvivesRelaunch`, `testFailedImportPreservesCurrentSeasonInSettingsAcrossRelaunch`, `testSetupImportAndReturnToSetupRecoveryLoopSurvivesRelaunch` |
| Result | Passed |
| Durations | 2m 12s, 1m 13s, 1m 16s |
| Result bundle | `/tmp/curlplan-truth-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-46-10--0400.xcresult` |

Bonspiel roster and lineup targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testBonspielRosterAndLineupManagementSurvivesRelaunch` |
| Result | Passed |
| Duration | 1m 20s |
| Result bundle | `/tmp/curlplan-truth-derived/Logs/Test/Test-CurlPlan-2026.06.26_04-58-53--0400.xcresult` |

Small-device accessibility targeted rerun:

| Field | Value |
| --- | --- |
| Test | `testSmallScreenAccessibilityPrimaryControlsRemainReachable` |
| Result | Passed |
| Duration | 1m 58s |
| Device | `CurlPlan Audit iPhone 13 mini`, UDID `5AEE5FA4-2054-4B52-B95B-1ADCF5CA1A14`, iOS 26.5 |
| Content size | `accessibility-medium` |
| Result bundle | `/tmp/curlplan-sf10-mini-final.xcresult` |
| Evidence screenshot | `/tmp/curlplan-sf10-mini-final.png` |
| Notes | Xcode emitted `IDELaunchParametersSnapshot` / `no debugger version` before the test body, but the result bundle reports the test case as passed on the mini destination. |

Route, circle, and scorecard edge targeted rerun:

| Field | Value |
| --- | --- |
| Tests | `testRouteDistanceAndCircleMembershipSurfacesStayTruthfulAcrossRelaunch`, `testBonspielScorecardEndScoringEdgesSurviveRelaunch`, `testBonspielForfeitResultSurvivesRelaunch` |
| Result | Passed |
| Durations | 1m 24s, 2m 23s, 1m 13s |
| Device | `CurlPlan Audit iPhone 17`, UDID `43CF768A-3A31-4541-9D67-0595F6BBCF67`, iOS 26.5 |
| Result bundle | `/tmp/curlplan-edge-ui.xcresult` |

Automated passes:

| Test | User loop evidence |
| --- | --- |
| `testBlankSeasonRosterLoopSurvivesRelaunch` | Starts from cleared local season data, creates a blank season profile, opens Roster, adds a curler through the sheet, terminates and relaunches, verifies the curler persists. |
| `testBonspielRosterAndLineupManagementSurvivesRelaunch` | Starts from cleared local season data, chooses demo setup, opens Brier Patch, adds and removes an eligible team member, verifies a locked roster member cannot be removed, submits an invalid lineup and sees validation, submits both team lineups for an unlocked game, locks the lineup, verifies later edit is blocked, relaunches, and verifies the locked lineup persists. |
| `testBonspielScorecardLoopSurvivesRelaunch` | Starts from cleared local season data, chooses demo setup, opens the Brier Patch bonspiel detail, proves early confirmation is blocked, records concession, confirms the local scorecard, relaunches, verifies confirmation persists, and verifies the linked Locker result appears. |
| `testCleanInstallLockerLoopSurvivesRelaunch` | Starts from cleared local season data, chooses demo setup, opens Locker, toggles attendance from Going to not going and back, verifies the same attendance count in Spiels, logs a local result linked to Kelowna and Sam Reid, verifies the receipt, edits the result from win to loss, deletes it, undoes the delete, verifies Locker, Passport games and win rate, Stop Detail games, and Sam Reid profile recent form, terminates and relaunches, and verifies those same result surfaces again. |
| `testDiscoverFollowActionPersistsToCircleState` | Starts from cleared local season data, chooses demo setup, opens Discover, follows Sam Reid, verifies the suggestion leaves Discover, relaunches, and verifies the followed suggestion stays out of Discover. |
| `testExportClearImportRecoveryLoopSurvivesRelaunch` | Starts from cleared local season data, creates a blank season, adds a roster curler, logs a local result, exports from Settings, clears the season through confirmation, imports the saved export through the import sheet, verifies the roster and Locker result are restored, terminates and relaunches, and verifies both restored facts again. |
| `testFailedImportPreservesCurrentSeasonInSettingsAcrossRelaunch` | Starts from cleared local season data, creates a blank season, adds a roster curler, opens Settings import, enters invalid JSON, verifies the import error, cancels, verifies the existing roster is still present, relaunches, and verifies the same roster remains. |
| `testLockerFeedSearchFilterAndBackingSourceDeletionSurvivesRelaunch` | Starts from cleared local season data, chooses demo setup, logs a local result, searches the Locker feed for that result, deletes the backing result, verifies the filtered feed becomes empty, switches to Discover, follows Sam Reid, relaunches, and verifies Sam stays out of Discover. |
| `testProfileShareAndDeleteCleanReferencesAcrossRelaunch` | Starts from cleared local season data, chooses demo setup, opens Kelowna stop detail, opens Sam Reid profile, copies the derived profile card, verifies the copied text contains Sam's identity, club, record, and win fields, confirms destructive deletion, verifies the stop no longer shows Sam, verifies roster search cannot find Sam, relaunches, and verifies both cleanup facts again. |
| `testSettingsClearAndResetRecoveryLoop` | Starts from cleared local season data, chooses demo setup, opens Settings, clears the season through confirmation, verifies the empty Passport state, resets demo through confirmation, and verifies demo stops return. |
| `testSetupImportAndReturnToSetupRecoveryLoopSurvivesRelaunch` | Starts from cleared local season data, creates a blank season, adds a roster curler, exports the season, returns to setup through confirmation, imports the saved JSON from first launch, verifies the roster returns, relaunches, and verifies the imported roster persists. |
| `testStopVisitLoopSurvivesRelaunchAndCanEnd` | Starts from cleared local season data, chooses demo setup, opens Kelowna stop detail, starts a visit through the capture sheet, selects Bryn Carter as a person met, writes a visit note, verifies Stop Detail shows Carter, opens Carter's profile and verifies Kelowna Curling Club is derived as a shared rink, relaunches, verifies Carter remains on the stop visit, ends the visit, and verifies the start action returns. |

Coverage notes:

These are still targeted screenflow gates, not a substitute for exploratory use. They now prove clean install setup, setup import, linked result creation, result edit from win to loss, result delete, result undo, Passport result summary propagation, route distance unavailable display, Stop Detail result propagation, Profile recent form propagation, profile copy from derived summary, profile delete confirmation, profile reference cleanup from Stop and Roster, Roster and Profile circle toggles, attendance cross-check, roster creation, stop visit start/end, visit people capture, visit derived profile shared rink, Locker search, feed update after backing result deletion, bonspiel roster member editing, locked roster protection, manual lineup validation, manual lineup submission, lineup lock, blocked lineup edit, bonspiel end scoring, blank ends, tied-game extra-end requirement, extra-end scoring, conceded confirmation, forfeited confirmation, bonspiel scorecard confirmation, discover follow, Settings export, clear, import, failed import preservation, return to setup, reset demo, small-screen reachability, accessibility-medium content size, and relaunch persistence through the SwiftUI surface.
