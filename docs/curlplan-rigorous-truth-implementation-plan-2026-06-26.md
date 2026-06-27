# CurlPlan Rigorous Truth Implementation Plan

Date: 2026-06-26

Target surface: `ios/CurlPlan.xcodeproj`

Primary code paths:

| Path | Role |
| --- | --- |
| `ios/CurlPlan/Models.swift` | Canonical data, store, selectors, persistence, seed |
| `ios/CurlPlan/PassportView.swift` | Season summary and recent stop loop |
| `ios/CurlPlan/LiveMapView.swift` | Stop map and visit loop |
| `ios/CurlPlan/LockerRoomView.swift` | Result, attendance, and feed loop |
| `ios/CurlPlan/SpielsView.swift` | Spiel schedule, attendance, roster, and detail loop |
| `ios/CurlPlan/RosterView.swift` | Circle and curler management loop |
| `ios/CurlPlan/StopDetailView.swift` | Stop, people met, and stop result loop |
| `ios/CurlPlan/CurlerProfileView.swift` | Curler derived history loop |
| `ios/CurlPlan/SettingsSheet.swift` | Import, export, reset, recovery |
| `tests/CurlPlanCoreTests/TruthLoopTests.swift` | Model, mutation, persistence, and invariant tests |

This plan supersedes `docs/curlplan-truthful-system-loops-plan-2026-06-26.md` for execution. The older plan is useful context. This file is the stricter acceptance contract.

## Non Negotiable Standard

Relabeling alone does not fix a lie.

A visible claim is allowed only when all five conditions are true:

| Requirement | Meaning |
| --- | --- |
| Source | There is one named state object or derived selector that owns the fact |
| Mutation | The user can create, change, undo, or delete the fact through the app |
| Propagation | Every screen that mentions the fact reads the same selector |
| Recovery | The user can correct a mistake without resetting the app |
| Proof | There is a model test and a screenflow pass that prove the loop |

If a claim requires authority that the local iOS app does not have, the app must either build that authority or remove the entire claim surface. Softer wording is not enough.

Examples:

| Claim type | Acceptable fix | Not acceptable |
| --- | --- | --- |
| Current stop | `StopVisit` records with start and end actions, shown consistently | Change "live" to "active" while no visit loop exists |
| Following feed | Real circle membership filter and add or remove flow | Rename to "circle" while feed contents ignore circle state |
| Scorecard | End scores, totals, validation, final confirmation | Show final score text without end data or correction path |
| Public roster | Build public publish authority or remove public roster claim | Say "shared roster" with no share or publish mechanism |
| Official result | Build official confirmation authority or avoid official language | Say "confirmed" when only local user input exists |

## Satisfying Loop Standard

A system loop is not done when a button writes a value. It is done when a normal user can finish the job, understand what happened, recover from a mistake, and see the same truth everywhere after relaunch.

Every loop must cover these states:

| State | Requirement |
| --- | --- |
| Entry | The user can find the loop from the natural screen without hidden gestures or debug setup |
| Empty | A blank season explains what can be done next without implying demo data exists |
| Input | Required fields, valid ranges, and unavailable choices are visible before save |
| Save | The save action writes through `Store` and returns a useful receipt |
| Feedback | The UI tells the user what changed and offers the next useful place to go |
| Propagation | All related screens update from the same selector without manual refresh |
| Correction | The user can edit, undo, remove, or otherwise correct the fact |
| Failure | Invalid input is blocked without losing typed work or existing state |
| Persistence | Relaunch shows the same final truth |
| Recovery | Export, import, clear, and reset paths can recover the season without data loss |

The UX bar for each retained loop:

1. The primary action is visible, labeled, and reachable at iPhone SE width and current simulator width.
2. The user is never left on a dead end after save, delete, import failure, blocked validation, or relaunch.
3. The receipt message names the outcome, not just that "something happened."
4. Destructive actions have confirmation and either undo or a clear explanation that they are permanent.
5. Demo, imported, and user created facts are distinguishable when the distinction matters.
6. No screen asks the user to trust a count, status, score, roster, or relationship that cannot be changed and rechecked in the app.

## Current Open Loop Gaps

No open truth-loop gaps remain for the local season contract as of the 2026-06-27 status check.

| Gap | Why it matters | Closure |
| --- | --- | --- |
| Final release audit rerun | A truth pass is only green after current code, tests, build, static scans, and retained screenflow evidence agree | Closed on 2026-06-27: model tests passed, `CODE_SIGNING_ALLOWED=NO` simulator build passed, unsupported claim scans returned no matches, retained SF10 and edge UI result bundles were readable and passed, and diff hygiene was clean |

## Current Evidence Checkpoint

This is the verified implementation state for the local truth-loop contract.

| Gate | Current proof | Status |
| --- | --- | --- |
| Model tests | `swift test --scratch-path /tmp/curlplan-spm-build` passed 28 tests with 0 failures on 2026-06-27 | Green |
| iOS build | `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived-status CODE_SIGNING_ALLOWED=NO build` succeeded on 2026-06-27 | Green |
| Static unsupported claim scan | active Swift claim scans for unsupported social, public, official, GPS, and here now language returned no matches on 2026-06-27 | Green |
| UI screenflows | seven `CurlPlanPrimaryScreenflowUITests` passed on `CurlPlan Audit iPhone 17`, iOS 26.5; targeted SF01, SF02, SF03, SF04, SF06, SF08, SF09, SF10, route/circle, and scorecard edge reruns passed after cleanup; SF10 passed on `CurlPlan Audit iPhone 13 mini`, iOS 26.5, at accessibility-medium content size; retained SF10 and edge UI bundles were readable on 2026-06-27 | Green |
| Overall truth state | Current evidence supports the local truth-loop contract; keep this green only while the listed gates continue to pass after future changes | Green |

This status stays green only while SF 01 through SF 10 retain model proof, UI proof, relaunch proof, and ledger rows that name the source object.

## System Boundary

Inside this pass:

| Area | Included work |
| --- | --- |
| App state | One persisted `AppData` season document |
| Store | One mutation boundary with receipts and selectors |
| Local user loops | Setup, profile, roster, stop visit, result, spiel attendance, bonspiel lineup, scorecard, import, export, reset |
| Persistence | UserDefaults persistence plus export and import JSON |
| Tests | Swift model tests, invariant tests, static claim scan, iOS build |
| Screenflow | Manual simulator passes with screenshot or screen recording evidence |

Outside this pass:

| Area | Rule |
| --- | --- |
| Public publishing | Do not claim it unless a public artifact exists |
| Remote social graph | Do not claim it unless a network backed identity graph exists |
| Official scoring | Do not claim official status unless an official approval model exists |
| Verified GPS | Do not claim physical presence unless location permission and verification exist |
| Cross device sync | Do not claim sync unless a sync path exists |

Current behavior may be local. Do not frame that as a permanent product commitment.

## Target Architecture

CurlPlan should work as one local season system.

```text
User action
  -> input validation
  -> Store mutation
  -> MutationReceipt
  -> AppData update
  -> derived selectors
  -> SwiftUI screens
  -> persistence save
  -> reload or export proof
```

Core rules:

1. `AppData` is the only persisted season document.
2. Seed data enters only through `Seed.appData(...)`.
3. Screens read derived selectors, not their own copied data.
4. Screens write only through `Store` mutations.
5. Every write returns a `MutationReceipt`.
6. Derived values are recomputed from source state.
7. Import validates all references before replacing state.
8. Export contains every domain needed to rebuild the visible app.

Recommended receipt contract:

```swift
struct MutationReceipt: Equatable {
    var id: UUID
    var action: String
    var changedDomains: Set<SeasonDomain>
    var userMessage: String
    var focusRoute: Route?
    var undoToken: UndoToken?
}
```

## Claim Ledger To Build

Create `docs/curlplan-visible-claim-ledger-2026-06-26.md` during Phase 0. It is the truth contract for all visible claims.

| Claim | Surface | Source | Mutation | Required proof |
| --- | --- | --- | --- | --- |
| Season games | Passport | `GameResult` plus imported history | add, edit, delete result | count changes once and reverses |
| Win rate | Passport, profile | results and imported history | result mutation | score outcomes drive rate |
| Current visit | Map, Passport, Stop | `StopVisit` | start, end, edit visit | only one active visit |
| People met | Stop, profile | `StopVisit.curlerIDs` | visit edit, curler link | deleted curler does not blank UI |
| Circle membership | Locker, Roster, Profile, Stop | `Curler.following` or membership record | add, remove, toggle | all screens agree |
| Feed visibility | Locker | feed selector | result, review, attendance, circle | filtered feed has no invalid author |
| Attendance | Locker, Spiels | `SpielAttendance` | attend, cancel | count and row state agree |
| Spiel roster | Spiels | bonspiel or spiel roster | add, remove member | member delete cleanup |
| Game lineup | Bonspiel game | lineup snapshot | submit, edit until lock | lock blocks late edit |
| Scorecard total | Bonspiel game | end scores | score end, correct end | totals equal end sums |
| Final result | Bonspiel game, feed | scorecard confirmation | confirm, unconfirm if allowed | cannot finalize invalid score |
| Export | Settings | full `AppData` | export | export can restore state |
| Import | Settings | validated JSON | import | bad refs rejected |
| Reset | Settings | seed or blank state | reset | destructive confirm required |

## Implementation Phases

### Phase 0: Baseline Truth Inventory

Goal: know exactly what the app says before changing behavior.

Work:

1. Free enough local disk for source hydration, build artifacts, and simulator logs.
2. Hydrate dataless Swift and test files if iCloud has evicted them.
3. Capture baseline build result.
4. Create the visible claim ledger.
5. Run static claim inventory across iOS source and docs.
6. Classify claims as local, derived, manual, public, official, remote, or location verified.
7. Assign every unsupported claim to a real loop phase or mark it as removed.

Truth tests:

| Test | Command or method | Required result |
| --- | --- | --- |
| Build baseline | `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO build` | build succeeds or failure is logged before edits |
| Static claim scan | `rg -n "live|here now|following|public|official|lock|discover|share|going|met|record|win rate|likes|comments|message|nearby|GPS|current|attending|roster|scorecard|lineup" ios/CurlPlan tests docs` | every match has a ledger row or removal task |
| Existing test baseline | `swift test --scratch-path /tmp/curlplan-spm-build` | current model tests pass or preexisting failures are documented |

Screenflow pass:

| Step | Expected evidence |
| --- | --- |
| Launch demo season | screenshot of first screen and setup state |
| Visit each tab | screenshot or notes for each visible claim |
| Tap every command | command list with current outcome |
| Relaunch | persisted state check |

Definition of done:

1. Claim ledger exists.
2. Baseline build and test status are recorded.
3. Every visible command has an owner.
4. Every unsupported claim has an implementation task or removal task.
5. No code behavior work starts until the ledger is complete.

### Phase 1: Canonical State And Mutation Boundary

Goal: eliminate competing realities in the app.

Work:

1. Make `AppData` the only saved season document.
2. Include profile, curlers, stops, visits, spiels, attendance, results, feed, bonspiels, and setup state in `AppData`.
3. Keep decode compatibility for older saved keys.
4. Add reference validation for stop IDs, curler IDs, spiel IDs, bonspiel IDs, team IDs, and game IDs.
5. Route all writes through `Store` methods.
6. Return `MutationReceipt` from every write.
7. Add undo snapshots for user created or user edited objects.
8. Move screen summaries behind selectors.

Truth tests:

| Test class | Assertions |
| --- | --- |
| `StoreMutationTests` | every mutation changes only intended domains and returns receipt |
| `PersistenceRoundTripTests` | save and reload preserves visible state |
| `ReferenceIntegrityTests` | invalid refs are rejected or cleaned during migration |
| `SeedIsolationTests` | seed data is deterministic and does not bypass `AppData` |

Screenflow pass:

1. Start demo season.
2. Start blank season.
3. Import a known valid season.
4. Export, clear, import, relaunch.
5. Confirm each mode lands on the expected screen with no mixed state.

Definition of done:

1. No screen owns a private duplicate of shared season facts.
2. Relaunch restores the same visible state.
3. Import cannot create dangling references.
4. Undo or delete exists for each user created object added in this pass.
5. Tests prove migration and persistence.

### Phase 2: First Launch, Setup, And Recovery Loop

Goal: the user can start, recover, and reset without guessing what state they are in.

Work:

1. Add setup mode selector if not already complete: demo, blank, import.
2. Add profile setup fields for name, home rink, and preferred role.
3. Add state badges for demo data and blank season.
4. Add settings tools: export, import, reset to demo, clear season.
5. Add confirmation sheets for destructive actions.
6. Add success receipts that say what changed and where to go next.

Truth tests:

| Test | Assertions |
| --- | --- |
| setup starts blank | no demo claims appear in blank season |
| demo starts complete | demo has coherent refs and useful examples |
| import restore | exported state imports exactly |
| clear season | clears user objects after confirmation |

Screenflow pass:

1. Clean install.
2. Choose blank season.
3. Enter profile.
4. Add one curler and one result.
5. Export.
6. Clear.
7. Import.
8. Relaunch.
9. Confirm state is restored.

Definition of done:

1. Clean install does not drop the user into unexplained demo data.
2. User always knows if they are seeing demo or real local data.
3. Destructive actions require confirmation.
4. Import and export complete a full recovery loop.

### Phase 3: Result Loop

Goal: a result is a season fact, not feed decoration.

Work:

1. Create or finish `GameResult` as source of truth.
2. Require date, opponent or team, score, and context.
3. Context must be stop, spiel, bonspiel game, or explicit note.
4. Validate score values, ties, impossible states, and missing context.
5. Feed result cards derive from `GameResult`.
6. Passport games, record, and win rate derive from `GameResult` plus imported baseline.
7. Stop Detail games derive from results attached to that stop.
8. Curler profile recent form derives from linked results.
9. Support edit, delete, and undo.

Truth tests:

| Test | Assertions |
| --- | --- |
| create result | result appears in feed, Passport, and linked stop |
| edit result | derived score, record, and win rate update |
| delete result | all derived screens reverse |
| invalid result | impossible or contextless result is rejected |
| linked participants | profile form changes only when participant refs match |

Screenflow pass:

1. Open Locker Room.
2. Add a valid win linked to a stop.
3. Confirm receipt.
4. Open Passport and verify game count and win rate.
5. Open Stop Detail and verify the game appears.
6. Open Curler Profile for linked player and verify form if applicable.
7. Edit the result to a loss.
8. Verify all summaries change.
9. Delete or undo.
10. Relaunch and verify final state.

Definition of done:

1. User can create, inspect, edit, delete, relaunch.
2. No screen shows a result without a `GameResult`.
3. Counts and win rate cannot drift from result records.
4. Invalid score states cannot be saved.

### Phase 4: Stop Visit And Map Loop

Goal: Passport, Map, and Stop Detail agree about where the user has been and what happened there.

Work:

1. Use `StopVisit` as the source of truth for active and historical visits.
2. Add start visit, end visit, and edit visit actions.
3. Visit can include date, stop, people met, note, and optional result or spiel link.
4. Map pin state derives from visit, saved, upcoming, and result selectors.
5. Passport recent stops derive from visits and result activity.
6. Stop Detail people met derives from visit curler IDs.
7. Distance is derived only when coordinates exist.
8. No GPS or presence language unless location verification exists.

Truth tests:

| Test | Assertions |
| --- | --- |
| start visit | creates one active visit |
| switch visit | ending or starting another stop cannot leave two active stops |
| people met | Stop Detail and profile connections use the same visit refs |
| missing coordinate | distance claim is unavailable, not guessed |
| relaunch | active and historical visits persist |

Screenflow pass:

1. Open Map.
2. Start a visit at one stop.
3. Open Passport and confirm current or recent state.
4. Add people met.
5. Open Stop Detail and confirm the same people.
6. Open a curler profile and confirm shared rink context.
7. End the visit.
8. Relaunch and confirm it is historical, not active.

Definition of done:

1. Active stop is a real `StopVisit`.
2. User can end or correct a visit.
3. Map and Passport never disagree about current stop.
4. Presence language does not imply GPS verification.

### Phase 5: Roster, Circle, And Curler Profile Loop

Goal: people in the app have coherent history and can be managed without dead ends.

Work:

1. Use one curler identity model for Roster, Locker, Stop Detail, and Profile.
2. Add add, edit, delete, and circle membership actions.
3. Derive profile stats from imported history, visits, and linked results.
4. Derive shared rinks from visits and result context.
5. Derive mutual count only from real relationship state.
6. Add graceful fallbacks for deleted or missing people.
7. Make Share or Message actions perform a local share sheet or remove them.

Truth tests:

| Test | Assertions |
| --- | --- |
| add curler | appears in Roster and can open profile |
| circle toggle | all surfaces agree on membership |
| delete curler | references clean up without blank UI |
| profile stats | record and recent form derive from actual refs |
| share action | share text is derived from current profile |

Screenflow pass:

1. Add a curler.
2. Add to circle.
3. Link the curler to a visit.
4. Link the curler to a result.
5. Open Roster, Stop Detail, Locker, and Profile.
6. Remove from circle.
7. Delete curler.
8. Confirm no blank names or stale profile routes.

Definition of done:

1. A curler can complete add, inspect, link, unlink, delete.
2. Circle membership filters feed and suggestions if those claims remain.
3. Profile history is derived or marked imported.
4. No profile stat is a standalone constant unless it is imported data labeled as imported.

### Phase 6: Spiel Attendance And Schedule Loop

Goal: attendance is a real user choice that updates every relevant schedule surface.

Work:

1. Use `SpielAttendance` as source of truth.
2. Add attend, cancel, and maybe interested states if the UI needs more than binary.
3. Update Locker shared spiel cards through the same attendance mutation.
4. Update Spiels row count and detail list through one selector.
5. Add empty states for no attending spiels.
6. Do not imply remote attendee counts unless counts are seeded or imported with source labeling.

Truth tests:

| Test | Assertions |
| --- | --- |
| attend spiel | Locker and Spiels agree |
| cancel attendance | count and detail list reverse |
| duplicate tap | attendance is not duplicated |
| invalid spiel | mutation is rejected |
| relaunch | attendance persists |

Screenflow pass:

1. Open Locker Room.
2. Attend a spiel from a card.
3. Open Spiels list.
4. Confirm count and detail list include the user.
5. Cancel from Spiels.
6. Return to Locker and confirm card state.
7. Relaunch and verify final state.

Definition of done:

1. Attendance can be changed from every visible entry point.
2. Attendance counts are derived.
3. Duplicate records cannot occur.
4. Remote social attendance is not implied.

### Phase 7: Bonspiel Roster And Lineup Loop

Goal: bonspiel roster and per game lineup reflect real curling structure, not a static display.

Work:

1. Keep bonspiel, team, team member, game, and lineup as distinct concepts.
2. Add team member add, edit, remove actions.
3. Add game lineup submit and edit action.
4. Enforce discipline specific player count.
5. Enforce roster policy for spares and alternates.
6. Add lineup lock based on game status or configured lock time.
7. Store lineup snapshots per game.
8. Record lineup changes as deltas after lock, not silent overwrites.
9. Remove public roster language unless publish authority exists.

Truth tests:

| Test | Assertions |
| --- | --- |
| add team member | roster view updates and refs remain valid |
| submit lineup | lineup snapshot contains valid team members |
| invalid count | lineup is rejected |
| locked lineup | edit is blocked after lock |
| lineup delta | post lock change is stored as change event |
| deleted member | lineup handles removed member according to policy |

Screenflow pass:

1. Open a bonspiel.
2. Add or edit team roster.
3. Open a scheduled game.
4. Submit a valid lineup.
5. Try an invalid lineup and confirm inline error.
6. Lock the lineup.
7. Try to edit after lock and confirm blocked path.
8. Add approved lineup change if supported.
9. Relaunch and verify snapshot is intact.

Definition of done:

1. The user can manage roster and lineup separately.
2. Lineup locks are enforced by state, not display only.
3. Per game lineups are snapshots.
4. Public roster claims are absent unless there is a public artifact.

### Phase 8: Bonspiel Scorecard And Result Confirmation Loop

Goal: scorecards are internally valid, correctable, and tied to result records.

Work:

1. Store end scores as source of truth.
2. Derive totals from ends.
3. Validate that only one team scores in a normal end.
4. Support blank ends.
5. Support extra end when tied if the rules profile allows it.
6. Record result flags such as complete, conceded, forfeit, or cancelled.
7. Confirm final score only after validation.
8. Create or update linked `GameResult` from confirmed scorecard.
9. Support correction before final, and controlled correction after final if allowed.

Truth tests:

| Test | Assertions |
| --- | --- |
| end total | totals equal end sums |
| blank end | `0/0` is allowed and does not pick winner |
| invalid end | both teams scoring in same end is rejected |
| extra end | only allowed after tied regulation |
| final confirmation | invalid scorecard cannot finalize |
| result link | confirmed scorecard updates result loop once |

Screenflow pass:

1. Open bonspiel game.
2. Enter end scores.
3. Confirm totals change after each end.
4. Try invalid end and confirm inline error.
5. Finish regulation tied if test data supports it.
6. Add extra end.
7. Confirm final.
8. Open Passport, Locker, and Stop Detail.
9. Confirm linked result appears exactly once.
10. Correct before final or use approved correction path.

Definition of done:

1. Totals are derived, not typed twice.
2. Scorecard cannot finalize invalid data.
3. Final score creates one linked result.
4. User can complete the full scorecard without losing work.

### Phase 9: Feed, Discovery, And Local Social Claims

Goal: Locker Room shows connected season activity without pretending to have a remote social network.

Work:

1. Decide which feed items are local activity, imported demo activity, and user created activity.
2. Add `authorityLevel` or equivalent on feed source if mixed.
3. Make feed cards derive from result, attendance, visit, review, and bonspiel events.
4. Make following or circle feed filter by real circle membership.
5. Make Discover use actionable suggestions from local state.
6. Suggestions must be dismissible or convertible into a real curler or stop action.
7. Remove likes and comments unless they have local mutation paths.

Truth tests:

| Test | Assertions |
| --- | --- |
| derived feed | feed item has backing source object |
| circle filter | filter excludes non circle authors unless self |
| discover action | suggestion can be accepted or dismissed |
| source deletion | deleting result or curler removes dependent feed item |
| no fake social | static scan has no likes or comments without actions |

Screenflow pass:

1. Open Locker Room.
2. Switch feed modes.
3. Confirm feed contents match circle state.
4. Create a result.
5. Confirm feed item appears.
6. Delete the result.
7. Confirm feed item disappears.
8. Accept or dismiss one suggestion.
9. Relaunch and confirm final state.

Definition of done:

1. Every feed card has a backing source object.
2. Feed filters are testable selectors.
3. Suggestions can be completed or dismissed.
4. No social metric appears without a mutation path.

### Phase 10: Static Claim Audit And Copy Gate

Goal: copy changes are the final validation layer, not the solution.

Work:

1. Run the static claim scan again.
2. For every match, link to a ledger row and test.
3. Remove claims that cannot be backed.
4. Keep language precise about local state, imported data, demo data, and official data.
5. Update README or iOS README only after runtime behavior is proven.

Truth tests:

| Test | Assertions |
| --- | --- |
| static scan | no unsupported claim remains |
| ledger coverage | every claim row has test and screenflow evidence |
| docs parity | README claims match runtime state |

Screenflow pass:

1. Read every visible label on each screen.
2. For each claim, perform the action that changes it.
3. Confirm the screen updates.
4. Relaunch.
5. Confirm the claim still holds.

Definition of done:

1. Claim scan has zero unsupported matches.
2. Every retained claim has a source, mutation, selector, test, and screenflow pass.
3. Documentation does not advertise behavior missing from the iOS app.

## Rigorous Truth Testing Strategy

Run tests in layers. Do not let a passing build replace behavioral proof.

| Layer | Purpose | Required command or method | Pass condition |
| --- | --- | --- | --- |
| Model tests | Prove mutations and derived state | `swift test --scratch-path /tmp/curlplan-spm-build` | all truth tests pass |
| iOS build | Prove app compiles in target | `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO build` | build succeeds |
| Static claim audit | Catch unsupported copy and affordances | `rg -n "<claim terms>" ios/CurlPlan tests docs` | every match backed or removed |
| Persistence proof | Prove relaunch state | simulator manual pass plus tests | state survives relaunch |
| Screenflow proof | Prove user can finish loops | simulator recording or screenshot set | every loop completes without dead end |
| Accessibility spot check | Prove controls are operable | simulator VoiceOver labels plus source check | icon buttons and rows have labels |

Required test suites:

| Suite | Required coverage |
| --- | --- |
| `StoreMutationTests` | receipts, changed domains, undo tokens |
| `DerivedSummaryTests` | Passport, Locker, Spiels, Map, Profile derived values |
| `ResultLoopTests` | create, edit, delete, validation, linked screens |
| `VisitLoopTests` | active visit, people met, stop summaries |
| `RosterLineupTests` | roster member integrity, lineup validation, lineup lock |
| `BonspielScoreTests` | end score validation, total derivation, final confirmation |
| `LockerFeedTests` | feed source objects, circle filter, suggestion action |
| `ProfileHistoryTests` | imported stats versus derived stats |
| `PersistenceRoundTripTests` | save, reload, export, import |
| `ReferenceIntegrityTests` | deletion and missing ref recovery |
| `SeedIsolationTests` | deterministic seed and no bypass state |

Invariant tests:

1. A result can appear in feed only if its `GameResult` exists.
2. A score total must equal the sum of end scores.
3. A normal end cannot award points to both teams.
4. One active visit maximum.
5. Attendance has one row per user and spiel.
6. A lineup cannot contain players outside the team roster unless policy allows spares.
7. A locked lineup cannot be overwritten.
8. A deleted curler cannot render as a blank profile.
9. Exported data can restore every visible loop.
10. Static demo data cannot be mistaken for user created data.

## Screenflow Pass Matrix

Each pass must be run on the simulator after model tests and build pass.

Evidence format:

| Field | Required value |
| --- | --- |
| Device | simulator name and iOS version |
| Build | local build timestamp and command |
| Starting state | demo, blank, imported, or migrated |
| Steps | numbered user actions |
| Expected state | source object and selector |
| Evidence | screenshot or screen recording path |
| Result | pass, fail, blocked |
| Fix link | commit or file path after repair |

Run protocol:

1. Start from a known state: clean install, blank season, demo season, imported season, or migrated saved state.
2. State the source object that should change before tapping the first control.
3. Complete the loop through the normal UI only. Do not use debug mutation helpers.
4. Verify the immediate receipt, the original screen, and every related screen that displays the same fact.
5. Relaunch the app and verify the final state.
6. Record a screenshot or screen recording for the start state, successful save, cross screen propagation, and relaunch proof.
7. Mark the pass failed if the user must infer state from copy alone, if any control is unreachable, if any stale value remains visible, or if correction requires clearing the app.

Required passes:

| Pass | User loop | Source objects | Done when |
| --- | --- | --- | --- |
| SF 01 | Clean install and setup | `AppData.setupComplete`, `PlayerProfile`, seed or import JSON | user can choose blank, demo, or import, then relaunch into the chosen state without mixed demo data |
| SF 02 | Result creation and correction | `GameResult`, derived feed, season summary | result can be created, edited, deleted, undone, and relaunch verified; Passport, Locker, Stop, and Profile update from the same result |
| SF 03 | Stop visit | `StopVisit`, stop selectors, people met selectors | visit can start, add people met, end, relaunch, and no screen claims GPS verification |
| SF 04 | Roster and profile | `Curler`, membership refs, imported history | curler can be added, opened, shared, linked, removed from circle, deleted, and no stale blank references remain |
| SF 05 | Spiel attendance | `SpielAttendance`, spiel attendance selector | attend and cancel work from Locker and Spiels, counts dedupe, and relaunch preserves final state |
| SF 06 | Bonspiel roster and lineup | `BonspielRecord`, team members, lineup snapshot | user can manage roster, submit valid lineup, see invalid lineup blocked, lock lineup, see post lock edit blocked, and relaunch keeps snapshot |
| SF 07 | Bonspiel scorecard | `BonspielEndScore`, result flags, linked `GameResult` | user can enter ends, see totals derive live, see invalid ends blocked, confirm final, and see exactly one linked result |
| SF 08 | Feed and discovery | feed selectors, circle membership, discover suggestions | feed filters match circle state, search works, a backing item can be created and removed, and a suggestion can be accepted or dismissed |
| SF 09 | Import and export recovery | encoded `AppData`, import validator, persistence | export captures full state, clear removes it, import restores exact state, invalid import leaves current state unchanged, relaunch proves recovery |
| SF 10 | Accessibility and small screen | visible layout and accessibility tree | no clipped text, no overlapping controls, tap targets are reachable, VoiceOver labels identify icon buttons, and Dynamic Type does not block loops |

For automated UI tests, each pass must assert at least one visible label and one accessibility identifier after every mutation. For manual screen recordings, the evidence note must name the selector or source object that proves the visible state.

## Overall Definition Of Done

The work is done only when all rows below are green.

| Gate | Done condition |
| --- | --- |
| State | `AppData` is the only persisted season document |
| Mutation | all writes go through `Store` and return receipts |
| Derived state | visible counts, statuses, scores, records, and membership labels come from selectors |
| User loops | every retained visible action completes, corrects, and persists |
| Bonspiel rigor | roster, lineup, scorecard, and result confirmation are separate and validated |
| User satisfaction | every loop has useful empty, success, error, correction, and relaunch states |
| Truth tests | required Swift test suites pass |
| Build | iOS build passes with the repo command |
| Screenflows | all required simulator passes are recorded as pass |
| Static audit | unsupported claim scan returns no unresolved matches |
| Docs | README and iOS README describe only proven behavior |
| Cleanup | generated build artifacts are removed after verification |

## Stop Conditions

Stop and report red if any of these happens:

1. The app cannot build after a phase and the failure is caused by that phase.
2. A migration can lose existing user data.
3. A retained visible claim cannot be backed by local state or tested.
4. The source files remain dataless and cannot be hydrated enough to edit or test.
5. Disk space is too low to run build and test safely.

Report yellow if behavior is implemented but any screenflow or static audit remains incomplete.

Report green only after tests, build, static claim audit, and screenflow evidence all pass.

## Execution Order

1. Phase 0 claim ledger and baseline.
2. Phase 1 canonical state.
3. Phase 2 setup and recovery.
4. Phase 3 result loop.
5. Phase 4 stop visit loop.
6. Phase 5 roster and profile loop.
7. Phase 6 spiel attendance loop.
8. Phase 7 bonspiel roster and lineup loop.
9. Phase 8 bonspiel scorecard loop.
10. Phase 9 feed and discovery loop.
11. Phase 10 static claim audit and docs parity.

Do not reorder Phase 7 and Phase 8. A scorecard needs valid teams and lineups before final result confirmation can be honest.

## Final Verification Commands

Run from `/Users/daverobertson/Desktop/Code/10-projects/active/curl-plan`.

```sh
swift test --scratch-path /tmp/curlplan-spm-build
```

```sh
xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO build
```

```sh
rg -n "live|here now|following|public|official|lock|discover|share|going|met|record|win rate|likes|comments|message|nearby|GPS|current|attending|roster|scorecard|lineup" ios/CurlPlan tests docs
```

```sh
rm -rf /tmp/curlplan-truth-derived /tmp/curlplan-spm-build
```

The final static scan is not expected to have zero text matches. It is expected to have zero unsupported matches. Every retained match must point to a ledger row, a test, and a completed screenflow pass.
