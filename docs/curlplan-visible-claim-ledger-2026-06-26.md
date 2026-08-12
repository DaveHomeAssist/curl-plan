# CurlPlan Visible Claim Ledger

Date: 2026-06-26

Target: `ios/CurlPlan.xcodeproj`

Status key:

| Status | Meaning |
| --- | --- |
| Green | Backed by state, mutation, selector, model test proof, and completed simulator screenflow proof |
| Yellow | Backed in code, but complete simulator screenflow evidence is still needed |
| Red | Unsupported and must not ship |

## Claims

| Claim | UI surface | Source of truth | Mutation path | Proof | Status |
| --- | --- | --- | --- | --- | --- |
| Season game count | Passport | `Store.seasonSummary.games` from `GameResult` plus imported profile count | `addResult`, `deleteResult`, `confirmBonspielGameResult` | `DerivedSummaryTests`, `ResultLoopTests`, `PersistenceRoundTripTests`, SF 02 simulator proof | Green |
| Win percent | Passport | `Store.seasonSummary.winPercent` from result outcomes plus imported wins | `addResult`, `updateResult`, `deleteResult`, `confirmBonspielGameResult` | `DerivedSummaryTests`, `ResultLoopTests`, SF 02 simulator proof | Green |
| Active visit | Passport, Map, Stop | `StopVisit.departedAt == nil` through `isCurrentStop` | `startVisit`, `endVisit` | `VisitLoopTests`, `PersistenceRoundTripTests`, SF 03 simulator proof | Green |
| Route distance | Passport, Map | `SeasonSummary.distanceLabel` | no mutation until measured route distance exists | `DerivedSummaryTests`, route distance simulator proof | Green |
| People met here | Map, Stop, Profile | `peopleMetIDs(for:)` from visits and migrated stop refs | `startVisit`, `deleteCurler`, import normalization | `VisitLoopTests`, `ReferenceIntegrityTests`, SF 03 and SF 04 simulator proof | Green |
| Circle membership | Locker, Roster, Stop, Profile | `Curler.following` through store selectors | `toggleFollow`, `followAll`, `deleteCurler` | `LockerFeedTests`, `ReferenceIntegrityTests`, SF 08 simulator proof for Discover follow, route/circle simulator proof for Roster and Profile toggles | Green |
| Following feed | Locker | `lockerFollowingFeed` and `feedVisibleToFollowing` | follow actions, attendance actions, result actions | `LockerFeedTests`, SF 08 simulator proof | Green |
| Discover suggestions | Locker | `discoverSuggestions` from shared stops, spiels, visits, results, teams | `toggleFollow`, `followAll`, `deleteCurler` | `LockerFeedTests`, discover simulator proof | Green |
| Attendance count | Locker, Spiels | `SpielAttendance` deduped by `attendeeIDs` | `setAttendance`, `toggleAttendance` | `LockerFeedTests`, `RosterLineupTests`, `PersistenceRoundTripTests`, SF 05 simulator proof | Green |
| Roster rows | Roster, Profile | `AppData.curlers` | `addCurler`, `deleteCurler`, `toggleFollow` | `ProfileHistoryTests`, `ReferenceIntegrityTests`, SF 04 simulator proof | Green |
| Curler shared rinks | Profile | visits, results, team membership, imported history fallback | result, visit, team roster mutations, import normalization | `ProfileHistoryTests`, SF 03 simulator proof | Green |
| Curler recent form | Profile | linked `GameResult` rows or `ImportedCurlerHistory` | `addResult`, `updateResult`, `deleteResult`, scorecard confirmation | `ProfileHistoryTests`, `ResultLoopTests`, SF 02 simulator proof | Green |
| Bonspiel roster policy | Spiels detail | `BonspielRecord.rosterPolicy` | `addBonspielTeamMember`, `removeBonspielTeamMember` | `RosterLineupTests`, SF 06 simulator proof | Green |
| Lineup lock | Spiels detail | `BonspielGame.status` through `lineupIsLocked` | `submitBonspielLineup`, `lockBonspielLineup`, `addBonspielLineupChange` | `RosterLineupTests`, SF 06 simulator proof | Green |
| Game score label | Spiels detail | `BonspielGame.ends` totals only | `recordBonspielEndScore`, `confirmBonspielGameResult` | `BonspielScoreTests`, scorecard edge simulator proof | Green |
| Blank end | Spiels detail | `BonspielEndScore.isBlank` and `0-0` validation | `recordBonspielEndScore` | `BonspielScoreTests`, scorecard edge simulator proof | Green |
| Extra end | Spiels detail | end number greater than scheduled ends, tied regulation validation | `recordBonspielEndScore` | `BonspielScoreTests`, scorecard edge simulator proof | Green |
| Conceded result | Spiels detail | `BonspielResultFlags.conceded` | `setBonspielResultFlags`, `confirmBonspielGameResult` | `BonspielScoreTests`, SF 07 simulator proof | Green |
| Forfeited result | Spiels detail | `BonspielResultFlags.forfeited` | `setBonspielResultFlags`, `confirmBonspielGameResult` | `BonspielScoreTests`, forfeit simulator proof | Green |
| Local scorecard confirmation | Spiels detail, Locker result | `BonspielScoreAgreement` plus linked `GameResult` | `confirmBonspielGameResult` | `BonspielScoreTests`, `PersistenceRoundTripTests`, SF 07 and scorecard edge simulator proof | Green |
| Export season | Settings | encoded `AppData` schema 4 | `exportJSON` read path | `PersistenceRoundTripTests`, SF 09 simulator proof | Green |
| Import season | Settings, setup | validated `AppData` replacement | `importJSON`, `importData` | `PersistenceRoundTripTests`, `ReferenceIntegrityTests`, SF 01 and SF 09 simulator proof | Green |
| Failed import preserves state | Settings | current `AppData` until decode and validation pass | `importJSON`, `importData` | `PersistenceRoundTripTests`, SF 09 simulator proof | Green |
| Reset demo | Settings, setup | `Seed.appData(setupComplete: true)` | `startDemoSeason` | `SeedIsolationTests`, `PersistenceRoundTripTests`, SF 09 simulator proof | Green |
| Clear season | Settings | blank `AppData` with preserved profile identity | `clearSeason` | `SeedIsolationTests`, SF 09 simulator proof | Green |
| Return to setup | Settings | `AppData.setupComplete` | `resetToSetup` | SF 01 and SF 09 simulator proof | Green |

## Removed Or Blocked Claims

| Claim | Decision | Evidence |
| --- | --- | --- |
| Likes | Removed from active controls | static scan has no `likes` matches in active Swift source |
| Comments | Removed from active controls | static scan has no `comments` matches in active Swift source |
| Official result | Not claimed | visible text scan has no `official` match |
| Public roster | Not claimed | visible text scan has no `public roster` match |
| GPS verified location | Not claimed | visible text scan has no `gps` match |
| Here now | Not claimed | visible text scan has no `here now` match |

## Future Account And Social Claims

These claims remain blocked until `docs/curlplan-accounts-social-roadmap-2026-06-28.md` is implemented with backend-backed proof. They are not current app capabilities.

| Claim | Required authority before claim can ship | Gate row |
| --- | --- | --- |
| Sign in, sign out, account restore | Auth service, revocable session, account-scoped season document, account deletion/export paths | `FR-ACCOUNT` |
| Cloud sync or cross-device restore | Sync API, versioned season document, offline queue, conflict receipts, second-device proof | `FR-SYNC` |
| Public profile or discoverable curler identity | Public identity API, visibility settings, search index, block-aware profile fetch | `FR-PUBLIC-ID` |
| Remote follow, friend, teammate, invite, or block | Relationship graph API, second-device agreement, block enforcement at API and UI | `FR-RELATIONSHIP` |
| Shared spiel, bonspiel, roster, lineup, RSVP, or scorecard | Shared object API, membership roles, visibility, versioning, permission checks | `FR-SHARED-OBJECTS` |
| Reaction, comment, message, notification, or public conversation | Interaction API, edit/delete/report/block flows, notification suppression, rate limits | `FR-SOCIAL` |
| Report, moderation, account deletion, privacy export, community safety | Report queue, moderation state, audit logs, rate limits, privacy policy, App Store privacy labels | `FR-TRUST-SAFETY` |

## Automated Screenflow Evidence

These simulator UI tests now exist in `ios/CurlPlanUITests/CurlPlanPrimaryScreenflowUITests.swift` and run through the actual SwiftUI app on `CurlPlan Audit iPhone 17`, iOS 26.5.

| Test | Covered loops | Result |
| --- | --- | --- |
| `testBlankSeasonRosterLoopSurvivesRelaunch` | clean install blank setup, roster add, relaunch persistence | Pass |
| `testBonspielRosterAndLineupManagementSurvivesRelaunch` | bonspiel team member add, eligible remove, locked remove block, invalid lineup validation, valid lineup submission, lock, blocked late edit, relaunch persistence | Pass |
| `testBonspielScorecardLoopSurvivesRelaunch` | blocked premature scorecard confirmation, concession flag, local scorecard confirmation, linked Locker result, relaunch persistence | Pass |
| `testCleanInstallLockerLoopSurvivesRelaunch` | clean install demo setup, Locker attendance toggle, Spiels attendance cross-check, linked local result create, receipt, win to loss edit, delete, undo, Locker, Passport, Stop Detail, Profile, relaunch persistence | Pass |
| `testDiscoverFollowActionPersistsToCircleState` | Discover suggestion action writes circle state and persists across relaunch | Pass |
| `testExportClearImportRecoveryLoopSurvivesRelaunch` | Settings export, clear through confirmation, import saved export, roster restore, Locker result restore, relaunch persistence | Pass |
| `testFailedImportPreservesCurrentSeasonInSettingsAcrossRelaunch` | Settings import rejects invalid JSON in the import sheet, preserves the current roster, and preserves it across relaunch | Pass |
| `testLockerFeedSearchFilterAndBackingSourceDeletionSurvivesRelaunch` | Locker search finds a real logged result, result deletion empties that filtered feed, Discover follow changes suggestion state, relaunch persistence | Pass |
| `testProfileShareAndDeleteCleanReferencesAcrossRelaunch` | profile copy from derived summary, delete confirmation, stop reference cleanup, roster search cleanup, relaunch persistence | Pass |
| `testSettingsClearAndResetRecoveryLoop` | Settings close, clear season confirmation, reset demo confirmation, Passport state update | Pass |
| `testSetupImportAndReturnToSetupRecoveryLoopSurvivesRelaunch` | Settings return to setup, first launch import from exported JSON, restored roster, relaunch persistence | Pass |
| `testStopVisitLoopSurvivesRelaunchAndCanEnd` | stop visit capture sheet, user selected people met, derived Stop Detail people list, derived Profile shared rink, active visit relaunch persistence, end visit | Pass |

## Remaining Manual Or Automated Evidence

The model, build, static scan, seven full suite simulator screenflows, targeted SF 01, SF 04, SF 06, SF 08, and SF 09 simulator reruns, and the SF 10 small-device accessibility rerun are green. Keep the ledger green only while the final release audit commands continue to pass:

| Pass | Loop | Current evidence |
| --- | --- | --- |
| SF 01 | Clean install and setup | Demo, blank, setup import, return to setup, and relaunch pass through automated UI tests |
| SF 02 | Result create, edit, delete, relaunch | Linked result create, receipt, edit from win to loss, delete, undo, Locker, Passport, Stop Detail, Profile, and relaunch pass through automated UI test |
| SF 03 | Stop visit start, people met, end, relaunch | Start through capture sheet, selected people met, Stop Detail people list, Profile shared rink, active relaunch, and end pass through automated UI test |
| SF 04 | Roster add, circle, profile, share, delete | Add and relaunch pass through automated UI test; circle from Discover has UI proof; profile copy, delete confirmation, Stop cleanup, Roster cleanup, and relaunch pass through targeted automated UI test |
| SF 05 | Spiel attendance from Locker and Spiels | Locker toggle, Spiels cross-check, and relaunch pass through automated UI test |
| SF 06 | Bonspiel roster and lineup lock | Team member add, eligible remove, locked remove block, invalid lineup validation, valid lineup submission, lock, blocked late edit, and relaunch pass through automated UI test |
| SF 07 | Bonspiel scorecard, concession, local confirmation | Blocked confirmation, concession, local confirmation, linked Locker result, and relaunch pass through automated UI test |
| SF 08 | Feed filtering and discover action | Locker search, result backed feed update after delete, Discover action, and relaunch pass through targeted automated UI test |
| SF 09 | Export, clear, import, relaunch | Settings export, clear, import sheet, restored roster, restored Locker result, failed import preservation, setup import, return to setup, and relaunch pass through automated UI tests |
| SF 10 | Accessibility and small screen | `testSmallScreenAccessibilityPrimaryControlsRemainReachable` passed on `CurlPlan Audit iPhone 13 mini`, iOS 26.5, at `accessibility-medium` content size; result bundle `/tmp/curlplan-sf10-mini-final.xcresult` |
