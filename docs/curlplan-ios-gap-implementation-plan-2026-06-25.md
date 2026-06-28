# CurlPlan iOS Gap Implementation Plan

Date: 2026-06-25

Target: `ios/CurlPlan.xcodeproj`

Build under test: `686fe43` with dirty iOS working tree changes present

Primary app surface: SwiftUI iOS app, scheme `CurlPlan`

Last verified build command:

```sh
xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-audit-derived CODE_SIGNING_ALLOWED=NO build
```

Last verified result: `BUILD SUCCEEDED`

## Product Goal

Make CurlPlan feel like one connected curling season companion instead of a set of polished but partly disconnected screens. A player should be able to start or resume a season, record results, manage curlers and spiels, explore nearby stops, recover from mistakes, and see every major screen reflect the same underlying season state.

The highest leverage product move is to establish one source of truth for season state, then connect Passport, Map, Locker Room, Spiels, Roster, Stop Detail, Curler Profile, and Settings to that state.

## Scope

Included:

* iOS app runtime behavior.
* SwiftUI navigation, forms, empty states, settings, and persistence.
* Existing local data model and UserDefaults persistence.
* Manual smoke coverage and focused model tests where practical.

Not included:

* Backend sync.
* App Store release work.
* Web root or classic web runtime parity unless needed for docs.
* New third party dependencies.
* Large visual redesign outside the existing brand system.

## Implementation Principles

1. Use one app owned season state model.
2. Keep visual style aligned with the existing components and brand bible.
3. Make every visible action either work or disappear.
4. Prefer derived values over duplicated constants.
5. Preserve user data during migration.
6. Add recovery paths before adding more mutation paths.
7. Verify every fixed gap with a user journey, not only a compile pass.

## Target Architecture

### Current State

The app has strong visual surfaces, but several screens own their own reality:

* `Store` owns curlers, stops, spiels, and feed.
* `PassportView` shows profile and stats that are mostly seeded constants.
* `LiveMapView` owns a separate `LiveMapStop.seed` model and detail readout.
* `LockerRoomView` can create result feed entries, but Passport stats and stops do not update from them.
* Settings controls appearance, but not app data recovery.

### Target State

Create a single local app state contract, either by expanding `Store` or by adding a `SeasonState` value inside `Store`.

Recommended shape:

```swift
struct AppData: Codable, Equatable {
    var schemaVersion: Int
    var profile: PlayerProfile
    var curlers: [Curler]
    var stops: [Stop]
    var spiels: [Spiel]
    var games: [GameResult]
    var feed: [ActivityItem]
    var settings: DataSettings
}
```

`Store` should expose:

```swift
@Published private(set) var appData: AppData

var passportSummary: PassportSummary { get }
var recentStops: [Stop] { get }
var mapStops: [MapStopViewModel] { get }
var lockerSummary: LockerSummary { get }
var rosterSummary: RosterSummary { get }
var progressionSummary: ProgressionSummary { get }
```

Mutation methods should be explicit:

```swift
func startSeason(profile: PlayerProfile, mode: SeasonMode)
func resetToDemoData()
func clearSeason()
func importData(_ data: AppData) throws
func exportData() throws -> Data
func addResult(_ input: ResultInput) throws
func deleteResult(id: String)
func addCurler(_ input: CurlerInput) throws
func updateCurler(id: String, input: CurlerInput) throws
func deleteCurler(id: String)
func addSpiel(_ input: SpielInput) throws
func setSpielStatus(id: String, status: SpielStatus)
func markStopVisited(id: String, context: StopVisitInput)
```

Persistence target:

* Add `cp.appdata.v2` as the canonical key.
* Keep reading existing v1 keys: `cp.curlers.v1`, `cp.spiels.v1`, `cp.feed.v1`.
* Migrate v1 data into v2 on first launch.
* Do not delete v1 keys until v2 has been written successfully.
* Add a visible reset path before shipping migration.

## Phase Plan

### Phase 0: Safety Baseline

Goal: make the implementation safe to start and easy to verify.

Work:

1. Record current dirty files before editing.
2. Rebuild with the known working `xcodebuild` command.
3. Add a focused verification checklist under docs for the iOS journeys.
4. Add or prepare lightweight model tests for `Store` derived state and persistence migration if the project test setup supports it without broad Xcode churn.

Done when:

* Current dirty tree is documented.
* Baseline build still succeeds.
* Manual smoke checklist exists and maps to all gaps below.
* Test strategy is chosen and documented.

### Phase 1: Single Source of Truth

Goal: make every major screen read from the same season state.

Work:

1. Introduce `AppData` or equivalent season state inside `Store`.
2. Move profile, stops, spiels, curlers, games, and feed under the same persisted model.
3. Add derived summaries for Passport, Map, Locker Room, Roster, and Progression.
4. Replace screen level constants with derived Store data where possible.
5. Add v1 to v2 migration.

Done when:

* Passport stats are derived from the same state used by Locker Room and Spiels.
* Map stops are derived from `Store.stops`.
* No screen owns a separate seed list for the same concept.
* Relaunch preserves the same data.
* Existing seeded demo state still appears on first demo launch.

### Phase 2: First Launch, Onboarding, and Recovery

Goal: make the app understandable and reversible from first launch.

Work:

1. Add first launch state detection.
2. Add setup choices:
   * Start blank season.
   * Use demo season.
   * Import saved season.
3. Add simple profile setup for name, home rink, and preferred role.
4. Add Settings data tools:
   * Export season.
   * Import season.
   * Reset to demo.
   * Clear season.
5. Add confirmations for destructive actions.

Done when:

* Clean install no longer drops the user directly into unexplained seeded state.
* Demo mode is clearly labeled as demo data.
* Blank season shows useful empty states.
* Reset and import paths can recover from a bad state.
* Closing and reopening the app resumes the chosen state.

### Phase 3: Connected Map and Stop Detail

Goal: make Map part of the same loop as Passport and Stops.

Work:

1. Replace `LiveMapStop.seed` with Store backed map view models.
2. Route map stop selection to the existing stop detail experience, or wrap the existing detail content in the map sheet.
3. Derive map summary stats from visited stops, upcoming spiels, nearby stops, and saved stops.
4. Connect stop actions:
   * Mark visited.
   * Save or unsave stop.
   * Open stop detail.
   * Add planned visit or spiel if appropriate.
5. Add empty state for no stops.

Done when:

* A stop shown on Map is the same stop shown in Passport recent stops and Stop Detail.
* Visiting a stop updates Passport progress.
* Search and filter states do not create mismatches between map pins and sheet details.
* Relaunch keeps visited and saved stop state.
* The old private map seed list is removed or used only as migration seed data.

### Phase 4: Complete Offered Navigation and Actions

Goal: remove misleading UI affordances and complete underbuilt routes.

Work:

1. Convert `SectionHeader` action text into a real optional `Button`.
2. Wire Passport `All` to a complete stops or activity list.
3. Wire Stop Detail `+ All` to a real action, likely add all listed curlers to a saved group or shared rink context. If product meaning is unclear, rename it to a precise action or remove it.
4. Wire Locker Room `Discover` to roster discovery, suggested curlers, or remove it until built.
5. Add disabled and empty states where a route has no items.
6. Add VoiceOver labels for icon only actions.

Done when:

* Every visible command in the audited paths either performs a state change, navigates, opens a sheet, or is intentionally hidden.
* Tapping each command has a deterministic result.
* Empty lists explain what to do next.
* No visible action silently does nothing.

### Phase 5: Creation UX and Validation

Goal: make user created data complete, editable, and recoverable.

Work:

1. Replace score only validation in new result with a structured `ResultInput`.
2. Require opponent, rink, or meaningful note, or provide an automatic fallback label.
3. Validate score ranges and tie handling.
4. Show inline validation reasons near Save.
5. Add delete or undo for created feed entries.
6. Ensure added results update derived stats immediately.
7. Add curler creation validation and useful defaults.

Done when:

* A blank result post cannot be created.
* Invalid scores cannot be saved.
* Created results can be removed or undone.
* New results update Passport and Locker Room summaries in the same session.
* Relaunch preserves valid created results.
* Validation failures are visible and do not rely on console output.

### Phase 6: Profile, Roster, and Empty States

Goal: make newly created people and blank seasons feel intentional.

Work:

1. Add empty states to Curler Profile shared rinks and recent form sections.
2. Add defaults for a newly created curler that avoid blank profile panels.
3. Add edit and delete actions for curlers if not already present in reachable UI.
4. Fix recent stop avatar initials to derive from real met curlers.
5. Add fallbacks for missing or deleted referenced curlers.
6. Add empty state components for:
   * No curlers.
   * No spiels.
   * No stops.
   * No results.
   * No activity.

Done when:

* Creating a curler and opening their profile never shows unexplained blank sections.
* Recent stop avatars display initials or a clear fallback.
* Deleting or missing referenced curlers does not break recent stop UI.
* Blank season mode is coherent across Passport, Locker Room, Spiels, Roster, and Map.

### Phase 7: Verification and Release Readiness

Goal: prove the product loop is connected and resilient.

Work:

1. Run build.
2. Run tests if added.
3. Run clean install simulator smoke.
4. Run persistence round trip:
   * Start season.
   * Create result.
   * Add curler.
   * Visit stop.
   * Relaunch.
   * Verify same state.
5. Run recovery checks:
   * Export.
   * Clear.
   * Import.
   * Reset demo.
6. Capture screenshots for first launch, main tabs, map stop detail, settings recovery, and blank season empty states.

Done when:

* Build succeeds.
* Tests pass or any preexisting failures are clearly identified.
* Manual journey checklist is green.
* No audited P0 or P1 gaps remain.
* Remaining P2 items are documented with exact file locations.

## Gap Goals and Definitions of Done

| ID | Gap | Goal | Definition of Done |
| --- | --- | --- | --- |
| G01 | First launch drops directly into seeded Passport | Give new users a clear setup, demo, restore, or blank season choice. | Clean install shows setup before main app. Demo data is labeled. Blank season has useful empty states. User choice persists across relaunch. Reset to setup is available through Settings. |
| G02 | Core loop mutations do not drive progression | Make result, spiel, curler, stop, and feed changes update the whole season model. | Adding a result updates games played, win rate, activity, and relevant Passport summary. Adding or changing a spiel updates Spiels and progression surfaces. Adding a curler updates Roster and any count based summaries. All changes survive relaunch. |
| G03 | Map is visually strong but disconnected from Store and Stop Detail | Make Map a first class view over Store stops and progression. | Map pins derive from Store stops. Selecting a stop opens the same stop detail concept as the rest of the app. Marking visited or saved updates Passport and persists. Map summary numbers match Store derived numbers. |
| G04 | Visible controls render as inert text | Make every visible command actionable or remove it. | Passport `All`, Stop Detail `+ All`, and Locker Room `Discover` are buttons with real destinations or actions. If a command has no valid product meaning, it is removed or renamed. VoiceOver labels describe the action. |
| G05 | Result creation allows incomplete posts | Prevent invalid or meaningless activity entries. | Save stays disabled until required fields are valid. Inline validation explains what is missing. Scores have bounded validation. Blank opponent plus blank note cannot save unless a fallback label is generated. Saved result can be deleted or undone. |
| G06 | New curler profiles show blank sections | Make new curler profiles feel complete even before history exists. | Shared rinks and recent form sections show clear empty states. New curler default data does not create blank cards. Edit and delete paths are available or explicitly deferred in UI copy. |
| G07 | Recent stop avatar stack renders blank initials | Show meaningful avatars for people met at stops. | Avatar initials derive from real curler names or a documented fallback. Plus counts are accurate. Missing references do not render blank circles. |
| G08 | No in app data recovery tools | Give users safe ways to recover, reset, export, and import local state. | Settings includes export, import, clear season, and reset demo controls. Destructive actions require confirmation. Import validates schema before replacing data. A failed import leaves current data unchanged. |

## Expanded Feature Backlog

These items are not separate audit gaps, but they improve the same user experience goals.

| Feature | User Value | Implementation Notes | Done |
| --- | --- | --- | --- |
| Blank season mode | Lets real users start without demo clutter. | Reuse the same AppData shape with empty arrays and profile fields. | Every tab has a helpful zero state and a primary next action. |
| Activity detail list | Makes Passport `All` meaningful. | Add a route to full feed or visited stops. | User can inspect all activity and return without state loss. |
| Suggested curlers | Gives Locker Room `Discover` a real purpose. | Start with Store derived suggestions from stops and spiels before adding remote discovery. | Discovery can add a curler or open a profile. |
| Stop visit workflow | Connects map exploration to season progress. | Add a simple sheet for visit note, date, and people met. | Visit appears in Passport recent stops and feed. |
| Result edit/delete | Makes mistakes recoverable. | Add context menu or detail sheet actions. | Created result can be corrected without clearing app data. |
| Data diagnostics | Helps QA and users understand state. | Add app data version and export date in Settings. | Support can identify schema version without inspecting storage. |
| Accessibility pass | Improves real device usability. | Label icon buttons, avoid text truncation, verify Dynamic Type basics. | Main commands are reachable and named through VoiceOver. |

## Journey Based Acceptance Tests

### First Launch Journey

Goal: start with no local app data and reach a meaningful home state.

Acceptance:

1. Delete app from simulator.
2. Launch app.
3. See setup choices.
4. Choose demo season.
5. Land in Passport with demo label visible or reachable.
6. Relaunch app.
7. Return to same Passport state without setup repeating.

### Core Loop Journey

Goal: record a result and see season progress update.

Acceptance:

1. Open Locker Room.
2. Create a valid result.
3. See result in activity feed.
4. Open Passport.
5. Confirm games played and recent activity changed.
6. Relaunch.
7. Confirm result and stats persist.

### Progression Journey

Goal: add or update a spiel and see season planning reflect it.

Acceptance:

1. Open Spiels.
2. Add or change a spiel status.
3. Confirm progression summary updates.
4. Confirm related screens show the same upcoming state.
5. Relaunch and verify persistence.

### Map Journey

Goal: use Map to explore and affect season state.

Acceptance:

1. Open Map.
2. Select a stop.
3. Open stop details.
4. Mark visited or saved.
5. Return to Passport.
6. Confirm recent stops or saved state updated.
7. Relaunch and verify state.

### Failure and Recovery Journey

Goal: recover from invalid input and destructive choices.

Acceptance:

1. Attempt to save an invalid result.
2. See inline validation and no state mutation.
3. Export current season.
4. Clear season after confirmation.
5. Import exported season.
6. Confirm restored data exactly matches exported state.

### Exit and Return Journey

Goal: persistence round trip across all mutable areas.

Acceptance:

1. Add result.
2. Add curler.
3. Change spiel status.
4. Mark stop visited.
5. Kill app or close simulator session.
6. Relaunch.
7. Verify all four changes are present.

### Settings Journey

Goal: make preferences and data tools predictable.

Acceptance:

1. Change appearance setting.
2. Relaunch and confirm appearance persisted.
3. Export season.
4. Try invalid import and confirm existing state remains.
5. Reset demo and confirm seeded demo restored.

## Edge Case Probes

| Probe | Expected Behavior |
| --- | --- |
| No curlers | Roster shows empty state and add action. |
| No stops | Map and Passport stop sections show empty state without crash. |
| No spiels | Spiels shows empty state and create action. |
| No activity | Feed shows empty state and next action. |
| Double tap Save | One result is created, not duplicates. |
| Rapid tab switching during save | State remains consistent. |
| Relaunch during onboarding | User returns to the same incomplete setup step or starts cleanly. |
| Import invalid JSON | Error shown, current data preserved. |
| Import older v1 data | Data migrates once and persists as v2. |
| Maximum score boundary | Validation prevents unreasonable or overflowing values. |
| Deleted referenced curler | UI renders fallback name or removes stale reference cleanly. |

## Verification Commands

Baseline build:

```sh
xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-derived CODE_SIGNING_ALLOWED=NO build
```

Project listing:

```sh
xcodebuild -list -project ios/CurlPlan.xcodeproj
```

Recommended test command after adding tests:

```sh
xcodebuild test -project ios/CurlPlan.xcodeproj -scheme CurlPlan -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/curlplan-test-derived CODE_SIGNING_ALLOWED=NO
```

Static searches before release:

```sh
rg -n "LiveMapStop\\.seed|cp\\.curlers\\.v1|cp\\.spiels\\.v1|cp\\.feed\\.v1|Text\\(\"All\"\\)|Text\\(\"Discover\"\\)|Text\\(\"\\+ All\"\\)" ios/CurlPlan
```

```sh
rg -n "Date\\(|UUID\\(|random|arc4random|shuffled" ios/CurlPlan
```

The second search is not automatically a failure. It is a review gate. UUIDs and dates are acceptable for user created records, but seeded demo data and deterministic tests should not depend on nondeterministic values.

## Suggested Implementation Order

1. G02 and G03: single source of truth and Map integration.
2. G01 and G08: first launch plus recovery tools.
3. G04: make offered controls real.
4. G05 and G06: validation and profile empty states.
5. G07: avatar correctness.
6. Expanded backlog items that now have a stable state model.

This order avoids adding more surface area on top of duplicated state. It also gives QA a recovery path before deeper mutation testing.

## Rollback Plan

1. Keep v1 keys readable until v2 migration is proven.
2. Add export before destructive clear and reset tools.
3. Gate new onboarding with a simple persisted flag so it can be bypassed for existing users with valid data.
4. Keep demo seed data available as a reset target.
5. If Map integration regresses, temporarily route Map selection to a Store backed read only detail sheet while preserving Store sourced pins.
6. Avoid deleting old code until the replacement path has passed build and manual smoke checks.

## Risks

| Risk | Mitigation |
| --- | --- |
| Dirty iOS working tree may include unreviewed user work. | Inspect relevant diffs before implementation and avoid unrelated reversions. |
| Xcode UI test harness was unstable in prior simulator attempts. | Prefer model tests plus manual simulator smoke unless UI test infrastructure is stabilized first. |
| Persistence migration can lose data if written too early. | Write v2 only after successful decode and migration. Keep v1 keys. Add export before clear. |
| MapKit behavior may differ on simulator and device. | Verify core state changes independent of map rendering, then add device smoke when available. |
| Product meaning of `+ All` is unclear. | Either define the action precisely during implementation or remove the affordance. |

## Completion Standard

This plan is complete when the app passes the following:

1. Clean launch setup works.
2. Demo and blank season modes both work.
3. Result, curler, spiel, and stop mutations update shared state.
4. Map, Passport, Locker Room, Roster, Spiels, and Settings agree on the same state.
5. Export, import, clear, and reset recovery paths work.
6. Relaunch preserves state.
7. Build succeeds.
8. Tests or documented manual smoke checks cover every fixed gap.

