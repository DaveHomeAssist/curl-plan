# CurlPlan Truthful System Loops Implementation Plan

Date: 2026-06-26

Target: `ios/CurlPlan.xcodeproj`

Primary surface: SwiftUI iOS app under `ios/CurlPlan/`

Related prior plan: `docs/curlplan-ios-gap-implementation-plan-2026-06-25.md`

## Operating Standard

Relabeling alone is not the fix. A label can be corrected only after the product loop behind it is honest.

Every visible claim in the app must have:

1. A named source of truth.
2. A mutation path that can create or change that truth.
3. A derived read path that every screen shares.
4. A recovery path for mistakes.
5. A persistence round trip.
6. A truth test that fails if the UI can drift from the model.

If a claim requires authority outside the local iOS app, such as public roster publication, official score approval, remote social discovery, or real location verification, the implementation must either build that authority or keep the claim out of the done scope. Copy changes are allowed only to describe implemented truth, not to hide missing mechanics.

## Product Boundary

This plan makes the local iOS app internally truthful. It does not require a backend unless the team chooses to keep network, public, or official claims.

Inside scope:

- Local season state.
- Local demo, blank, import, and export modes.
- Passport, Map, Locker Room, Spiels, Roster, Stop Detail, Curler Profile, Settings.
- Bonspiel records, rosters, lineups, games, and scorecards.
- Local persistence, migration, model tests, manual screenflow passes.

Outside scope unless explicitly added:

- Remote multiplayer identity.
- Real public roster publishing.
- Club or event official score systems.
- Push notifications.
- Cloud sync across devices.
- Verified GPS check in.

## System Overview

CurlPlan should behave like one local season system. The UI should never invent authority. Screens consume derived view models from a single app state. User actions go through explicit store mutations. Mutations return receipts so the UI can show useful completion feedback and so tests can prove which domains changed.

```text
[User action]
    -> [Input validation]
    -> [Store mutation]
    -> [Canonical AppData write]
    -> [Derived view models]
    -> [Screens update]
    -> [Persistence round trip]
    -> [Truth tests verify invariants]
```

## Core Components

| Component | Responsibility | Inputs | Outputs | Owner |
| --- | --- | --- | --- | --- |
| `AppData` | Canonical persisted season document | migrated seed, import JSON, user mutations | saved app state | `Store` |
| `Store` | Single mutation boundary and derived selectors | validated input structs | state updates, receipts, selectors | app core |
| `Input` models | Capture form intent before mutation | form fields | valid domain input or errors | feature loop |
| `Domain` models | Represent real concepts | validated inputs | profile, stop, visit, result, spiel, bonspiel, team, lineup | app core |
| `Derived` view models | Prepare screen safe read models | `AppData` | Passport, Map, Locker, Spiels, Roster, Profile models | app core |
| `Persistence` | Save, load, migrate, export, import | `AppData` | stable JSON and migration results | app core |
| `Truth tests` | Prove visible claims match state | fixtures and mutations | pass or explicit failure | tests |
| `Screenflow checklist` | Prove a user can finish loops | built app | green manual flow evidence | QA |

## Source of Truth Rules

1. `AppData` is the only persisted season document.
2. Seed data enters the app only through `Seed.appData(...)`, then becomes normal `AppData`.
3. UI reads from derived selectors, not from hardcoded demo constants.
4. UI writes only through store actions.
5. Counts, status labels, scores, win rate, attendance, people met, lineups, and current visit state are derived.
6. Every cross reference has an integrity rule and fallback.
7. Import replaces state only after full decode and validation succeeds.
8. Export contains every domain needed to reconstruct the visible app.

Recommended shape:

```swift
struct AppData: Codable, Equatable {
    var schemaVersion: Int
    var setupComplete: Bool
    var profile: PlayerProfile
    var curlers: [Curler]
    var stops: [Stop]
    var visits: [StopVisit]
    var spiels: [Spiel]
    var bonspiels: [BonspielRecord]
    var results: [GameResult]
    var feed: [FeedItem]
    var attendance: [SpielAttendance]
    var settingsSnapshot: DataSettings?
}
```

Recommended mutation receipt:

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

## Visible Claim Ledger

Create and maintain `docs/curlplan-visible-claim-ledger.md`. Each row is a contract.

| Claim | Screen | Backing state | Mutation path | Test | Done |
| --- | --- | --- | --- | --- | --- |
| Following feed | Locker Room | feed filtered by followed authors or self | follow toggle, result create, attendance update | following feed invariant | no unfollowed author appears |
| Discover | Locker Room | local suggestions from stops, spiels, mutual references | add to circle, ignore suggestion | discover loop test | suggestion can be acted on |
| Result post | Locker Room, Passport, Stop, Curler | `GameResult` plus derived feed | add/edit/delete result | result propagation test | stats and related screens update |
| Current visit | Map, Passport, Stop | `StopVisit` with active state | start/end visit | visit state test | no manual tap pretends GPS |
| Roster | Roster | circle membership | add/edit/delete curler | roster integrity test | no blank profile cards |
| Team roster | Spiels, Bonspiel detail | bonspiel team members | add/remove team member | team integrity test | team view survives deletion |
| Game lineup | Bonspiel game | lineup slots | submit/edit lineup | lineup lock test | lock blocks late edits |
| Scorecard | Bonspiel game, feed, Passport | end scores and result confirmation | score by end, confirm final | score total test | totals derive from ends |
| Attendance | Locker, Spiels | `SpielAttendance` | I'm in, not going | attendance persistence test | all screens agree |
| Export/import | Settings | full `AppData` | export, import | round trip test | exact state restores |

## Implementation Phases

### Phase 0: Claim Inventory and Baseline

Goal: know exactly what the app promises before changing behavior.

Work:

1. Add the visible claim ledger.
2. Inventory all user visible claims with `rg`.
3. Classify each claim as local, derived, manual, public, official, or location verified.
4. Mark every unsupported public, official, social, or location claim as blocked until there is backing authority.
5. Run the known iOS build command and capture baseline.
6. Add a manual screenflow checklist doc under `docs/`.

Truth tests:

- Static claim search for terms such as `live`, `here now`, `following`, `public roster`, `lineup lock`, `official`, `Going`, `met`, `record`, `win`, `share`, `discover`.
- Baseline build must pass before behavior work starts.

Screenflow pass:

- Launch demo.
- Visit each tab.
- Record every visible command.
- Record expected state change for each command.

Done:

- Claim ledger exists.
- Every visible command has an owner.
- Every unsupported claim is either assigned to a real implementation phase or explicitly blocked.
- Baseline build result is captured.

### Phase 1: Canonical State and Migration

Goal: make the app impossible to split into competing realities.

Work:

1. Promote `AppData` to the only persisted season document.
2. Add `visits`, `results`, and `attendance` as first class arrays.
3. Keep legacy decode for existing keys and current schema.
4. Add reference validation for curler IDs, stop IDs, spiel IDs, team IDs, member IDs.
5. Move derived summaries behind store selectors.
6. Make seed data deterministic and complete.
7. Add mutation receipts for every write action.

Truth tests:

- `AppDataMigrationTests`: old saves migrate to current schema once.
- `PersistenceRoundTripTests`: load after save exactly preserves user visible state.
- `ReferenceIntegrityTests`: deleted or missing references never render blank UI.
- `DerivedSummaryTests`: Passport, Map, Locker, Spiels, and Roster summaries derive from the same data.

Screenflow pass:

- Existing demo state still opens.
- Blank season still opens.
- Import of current export restores state.

Done:

- No screen owns a private copy of a shared domain.
- All persisted data needed by visible screens is inside export JSON.
- Relaunch preserves setup mode, profile, stops, visits, spiels, bonspiels, results, feed, attendance, curlers.
- Deleting referenced data produces a graceful fallback or cleanup.

### Phase 2: Result Loop

Goal: a recorded result becomes real season state, not just a feed decoration.

Work:

1. Replace score only feed posting with `GameResult`.
2. Result input requires score, opponent or team, date, and either stop, spiel, or note.
3. Support optional end by end scoring for bonspiel linked games.
4. Feed entries derive from result records.
5. Passport game count and win rate derive from result records plus imported baseline.
6. Stop Detail games derive from results attached to that stop.
7. Curler recent form derives from results when participants are linked.
8. Add edit and delete or undo for user created results.

Truth tests:

- Creating a result increments games exactly once.
- Win rate changes according to the result.
- Deleting a result reverses derived stats.
- Result cannot save with impossible score or no context.
- A result linked to a stop appears on that stop only.
- A result linked to a bonspiel game updates scorecard state or is rejected if incompatible.

Screenflow pass:

1. Open Locker Room.
2. Add a valid result.
3. See clear success feedback.
4. Open Passport and confirm games and win rate changed.
5. Open the linked stop and confirm game appears.
6. Edit or delete the result.
7. Confirm Passport and Stop Detail reverse cleanly.
8. Relaunch and verify final state.

Done:

- User can complete create, inspect, correct, delete, relaunch.
- No result appears in one screen without matching source state.
- No feed stat can drift from the result record.

### Phase 3: Stop Visit and Map Loop

Goal: Map, Passport, and Stop Detail agree about stops and visits.

Work:

1. Replace `here` as a loose boolean with `StopVisit` records.
2. Add start visit and end visit actions.
3. Visit input can include date, people met, note, and optional game or spiel link.
4. Map pins derive current, visited, home, upcoming, and saved state from selectors.
5. Passport recent stops derive from visit and result activity.
6. Kilometers derive from coordinate route distance when coordinates are known.
7. If coordinates are missing, distance is unavailable rather than guessed.

Truth tests:

- Starting a visit creates one active visit.
- Ending a visit clears current state but preserves history.
- Passport recent stops updates from visit records.
- Map current pin and Passport current badge agree.
- Distance total equals deterministic coordinate calculation.
- Missing coordinate does not fabricate distance.

Screenflow pass:

1. Open Map.
2. Select a stop.
3. Start a visit.
4. Add a person met.
5. Open Passport and confirm recent stop.
6. Open Stop Detail and confirm visit context.
7. End visit.
8. Relaunch and confirm history remains but current state is gone.

Done:

- Manual visit state is honest and reversible.
- Map and Passport never disagree about current or visited status.
- No location verified language appears unless location verification exists.

### Phase 4: Roster, Team, and Lineup Loop

Goal: separate circle, team roster, and game lineup, then connect them deliberately.

Work:

1. Define `CircleMember`, `BonspielTeamMember`, and `GameLineup` semantics in code comments or docs.
2. Roster tab manages local circle members.
3. Bonspiel detail manages team rosters.
4. Game detail manages delivery order and skip or vice roles.
5. Add conversion actions:
   - Add circle member to team.
   - Add team member from free text.
   - Submit lineup from team roster.
6. Add edit and delete handling with stale reference cleanup.
7. Add lineup validation per discipline.

Truth tests:

- Adding a curler to circle does not imply team membership.
- Adding a curler to team does not imply game lineup.
- Lineup must satisfy discipline player count.
- Deleted circle member leaves team member display name intact or asks for cleanup.
- Locked lineup cannot be edited without explicit unlock or admin action.

Screenflow pass:

1. Add a new curler.
2. Open profile and confirm useful empty states.
3. Add curler to a bonspiel team.
4. Submit lineup for a game.
5. Try invalid lineup and see inline reason.
6. Lock lineup.
7. Confirm late edit is blocked or requires explicit override.
8. Relaunch and confirm circle, team, lineup remain distinct.

Done:

- User can complete circle to team to lineup without mental translation.
- No screen uses `Roster` for three different concepts without a real action boundary.
- All discipline constraints are enforced.

### Phase 5: Bonspiel Game and Scorecard Loop

Goal: bonspiel game snapshots become editable game records with complete score flow.

Work:

1. Add bonspiel game create and edit flow.
2. Add draw, sheet, teams, start time, stage, status.
3. Add end by end scoring.
4. Derive totals from ends only.
5. Support blank ends, conceded, forfeited, extra end, and final confirmation.
6. Add score agreement appropriate to local scope: user confirmed, organizer confirmed, or not confirmed.
7. Feed and Passport derive from finalized local results.

Truth tests:

- End scores sum to displayed total.
- Blank end contributes zero and counts as completed.
- Final cannot be confirmed before minimum required fields.
- Conceded and forfeited games follow explicit result rules.
- Score agreement label matches confirmation state.
- Editing an end updates all dependent totals.

Screenflow pass:

1. Create bonspiel.
2. Add two teams.
3. Add a draw game.
4. Submit both lineups.
5. Enter four ends.
6. Confirm final or leave in progress.
7. Open Spiels detail and see same score.
8. Open Locker and Passport only if result is eligible.
9. Relaunch and verify full scorecard.

Done:

- A user can complete a bonspiel game from schedule through score confirmation.
- The app never shows an official result unless the selected authority exists.
- Game snapshots are not dead displays.

### Phase 6: Locker Room Feed, Discover, and Attendance Loop

Goal: social looking surfaces become consistent local activity surfaces.

Work:

1. Make Following feed filter real.
2. Define feed eligibility: self activity, followed curler activity, attended spiel updates, linked local results.
3. Make Discover derive suggestions from shared stops, spiels, teams, and imported records.
4. Add actions to follow, dismiss, or open suggested curler.
5. Make `I'm in` write `SpielAttendance`.
6. Spiels detail and feed cards read the same attendance state.
7. Likes and comments are either implemented locally or removed from active controls until backed.

Truth tests:

- Following feed excludes unfollowed third party activity.
- Following a curler changes feed membership.
- Unfollowing removes unrelated activity.
- Discover suggestions disappear after follow or dismiss.
- Attendance toggle persists and updates Spiels list count.
- Double tapping attendance does not create duplicate records.

Screenflow pass:

1. Open Locker Following.
2. Follow and unfollow a curler.
3. Confirm feed changes.
4. Open Discover.
5. Follow a suggestion.
6. Toggle `I'm in` on a spiel card.
7. Open Spiels and confirm attendance.
8. Relaunch and confirm state.

Done:

- Locker Room reads like a local activity system because it behaves like one.
- No social counter or action appears unless it can be completed.

### Phase 7: Profile Stats and History Loop

Goal: curler profiles show derived truth, not frozen seed biography.

Work:

1. Derive shared rinks from visits, stops, and linked results.
2. Derive recent form from results involving that curler.
3. Derive mutual count from shared team, visit, and attendance references.
4. For imported or seed history, store it as `ImportedCurlerHistory`.
5. New curlers show complete empty states and next actions.
6. Share content uses derived or explicitly imported values.

Truth tests:

- New curler has no fake record.
- Adding a shared visit updates shared rink.
- Adding linked result updates recent form.
- Deleting linked result removes form line.
- Share text matches visible profile values.

Screenflow pass:

1. Create curler.
2. Open profile.
3. Add shared visit.
4. Add result involving curler.
5. Return to profile and confirm shared rink and form.
6. Delete result and confirm form updates.
7. Share profile and inspect generated text.

Done:

- Profile values are derived, imported, or empty with clear next action.
- No person profile looks more authoritative than its backing data.

### Phase 8: Recovery, Import, Export, and Reset Loop

Goal: users can trust the app because mistakes and bad data are recoverable.

Work:

1. Export full `AppData`, including schema, generated date, and app version if available.
2. Import validates schema, references, and required fields before replacing state.
3. Add clear season, reset demo, and return to setup with confirmations.
4. Failed import preserves current state.
5. Add optional diagnostics view with schema version and counts.
6. Add undo where small mutations can be reversed.

Truth tests:

- Export then import produces equivalent visible state.
- Invalid JSON cannot mutate current state.
- Unsupported future schema shows useful error.
- Clear season removes all season data and preserves intended profile fields.
- Reset demo restores deterministic demo.

Screenflow pass:

1. Create data in every domain.
2. Export.
3. Clear season.
4. Import export.
5. Verify all domains restored.
6. Try invalid import.
7. Confirm current state remains.
8. Reset demo.
9. Confirm demo state is deterministic.

Done:

- A user can recover from a bad edit without reinstalling.
- Support can diagnose schema and counts from the app or export.

### Phase 9: Screenflow and Detail Pass

Goal: every loop feels complete, not merely technically wired.

Work:

1. Run every screen at compact phone size, large phone size, and iPad size.
2. Check keyboard behavior in every form.
3. Check save, cancel, dismiss, and back behavior.
4. Check empty, loading if any, error, success, undo, and deleted reference states.
5. Check Dynamic Type at one larger size.
6. Check VoiceOver labels for icon only controls.
7. Check no clipped text in chips, buttons, cards, and sheets.
8. Check one clear next action in every empty state.

Screenflow pass set:

| Pass | Device | Goal |
| --- | --- | --- |
| Compact phone | iPhone simulator | normal one hand completion |
| Large phone | iPhone simulator | spacing and sheet behavior |
| iPad | Ignacio when available | split sizing, popover, keyboard, landscape if supported |
| Clean install | simulator | setup and blank mode |
| Dirty state | simulator | migrate existing local data |
| Recovery | simulator | export, clear, import |

Done:

- Every primary loop has a satisfying end state.
- Completion feedback points to the changed object or screen.
- User can recover from mistakes.
- No visible command silently fails.
- No text overlap or unusable control at target sizes.

### Phase 10: Release Gate

Goal: prove truthfulness with automated and manual evidence.

Required commands:

```sh
xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO build
```

Recommended after tests are added:

```sh
xcodebuild test -project ios/CurlPlan.xcodeproj -scheme CurlPlan -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/curlplan-truth-test-derived CODE_SIGNING_ALLOWED=NO
```

Static review gates:

```sh
rg -n "live|here now|You're here|following|public roster|lineup lock|official|Going|I'm in|met at|record|win|discover|share" ios/CurlPlan
```

```sh
rg -n "Text\\(\"All\"\\)|Text\\(\"\\+ All\"\\)|Text\\(\"Discover\"\\)|Text\\(\"Following\"\\)|Text\\(\"Lineup locked\"\\)" ios/CurlPlan
```

Done:

- Build succeeds.
- Model tests pass.
- Static claim review has no unsupported claims.
- Screenflow checklist is green.
- Export/import round trip is green.
- Device smoke on Ignacio is green if the device is available.

## Rigorous Truth Test Suite

Create focused tests before or alongside implementation. Prefer model and store tests over fragile UI tests until the UI test harness is stable.

| Test suite | What it proves |
| --- | --- |
| `StoreMutationTests` | every store action changes the expected domains only |
| `DerivedSummaryTests` | counts and labels match canonical state |
| `ResultLoopTests` | result creation, edit, delete, score, and stats propagation |
| `VisitLoopTests` | stop visit lifecycle and map/passport agreement |
| `RosterLineupTests` | circle, team roster, and game lineup remain distinct |
| `BonspielScoreTests` | end scores, totals, status, and confirmation rules |
| `LockerFeedTests` | following, discover, and attendance filters |
| `ProfileHistoryTests` | shared rinks, form, and share text derive correctly |
| `PersistenceRoundTripTests` | save, load, export, import, migration |
| `ReferenceIntegrityTests` | stale IDs, deletes, and missing links are handled |
| `SeedIsolationTests` | demo data is deterministic and does not leak into blank season |

Minimum invariant examples:

```swift
XCTAssertEqual(store.passportSummary.games, store.results.count + store.profile.importedGameCount)
XCTAssertEqual(game.scoreLabel, "\(game.ends.map(\.teamA).reduce(0, +))-\(game.ends.map(\.teamB).reduce(0, +))")
XCTAssertTrue(store.lockerFollowingFeed.allSatisfy { item in store.feedItemIsVisibleToFollowing(item) })
XCTAssertEqual(store.spielAttendance(spielID).count, Set(store.attendance.filter { $0.spielID == spielID }.map(\.curlerID)).count)
```

## Definitions of Done by Loop

| Loop | Definition of Done |
| --- | --- |
| First launch | User can choose demo, blank, or import. Choice persists. Returning to setup does not lose data unless user confirms. |
| Result | User can create, inspect, edit or delete, see stats update, link to stop or bonspiel, relaunch with state intact. |
| Stop visit | User can start visit, add context, see Map and Passport update, end visit, and keep history. |
| Roster | User can create, edit, follow, unfollow, delete, and open a useful profile without fake stats. |
| Team roster | User can build a bonspiel team from circle or free text and survive circle member deletion. |
| Game lineup | User can submit valid lineup, see invalid reasons, lock lineup, and understand override path if any. |
| Bonspiel game | User can schedule game, attach teams, score by end, confirm status, and see derived totals. |
| Attendance | User can mark going or not going from any offered surface, and every count updates. |
| Locker feed | Following and Discover behave from actual local state. No inactive social controls remain. |
| Profile history | Shared rinks, recent form, record, and share text derive from results, visits, teams, or imported history. |
| Recovery | Export, import, clear, reset, invalid import, and relaunch all preserve or change state exactly as promised. |
| Screen quality | No clipped text, no dead controls, no orphan success states, no missing back path, no unexplained empty cards. |

## Attention to Detail Rules

1. Save buttons show disabled reasons before submission.
2. Successful saves land the user where the changed object is visible.
3. Destructive actions have confirmation and clear object names.
4. Undo is preferred for small local mutations.
5. Duplicate taps cannot create duplicate records.
6. Back and Done always preserve or discard intentionally.
7. Empty states include one real next action.
8. Search, filters, and counts update together.
9. Sheets handle keyboard, Dynamic Type, and scrolling.
10. Icon buttons have accessibility labels.
11. Imported or stale references never render blank names or blank avatars.
12. The app does not use external authority words without authority.

## Global Completion Standard

This project is green only when:

1. Every visible claim in the ledger has backing state, mutation path, selector, test, screenflow proof, and recovery path.
2. The app can complete all primary loops from a clean install.
3. The app can recover from invalid input and destructive actions.
4. Demo, blank, and imported states remain separate and predictable.
5. All screens agree after every mutation.
6. Relaunch preserves all completed loops.
7. Build passes.
8. Truth tests pass.
9. Screenflow passes are green on simulator and, when available, Ignacio.
10. Any remaining unsupported public, official, remote, or location claims are removed from the product surface or assigned to a backend integration plan before release.
