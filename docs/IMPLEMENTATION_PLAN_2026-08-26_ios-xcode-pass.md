# CurlPlan — iOS Xcode pass

**Date:** 2026-08-26 · **Status:** Phase 0 landed; Phases 1–3 need a Mac
**Scope:** close out the long-standing "needs a Mac Xcode pass" item on the native port.

## Correction to the standing note

`CLAUDE.md` and `ios/README.md` said the Swift "needs a Mac Xcode compile/run pass" and
that `StoreTests.swift` "needs a test target wired". **Both were stale.** The `ios` CI
job (macos-14) has been regenerating the project and running `xcodebuild build` +
`xcodebuild test` on every push, green on the current head (`541695d`: build 38s, tests
2m31s). The test target is emitted by `ios/generate-xcodeproj.js` automatically.

What has genuinely never happened is an **interactive run**. Nobody has launched the app
and driven a screen. Compile-green says the types check; it says nothing about layout,
navigation, persistence across relaunch, or whether a view renders at all.

## Two blocking findings (found while preparing this pass)

### 1. The feature-review matrix describes a codebase that no longer exists

`docs/curlplan-feature-review-matrix-2026-06-27.md` rates 14 rows Green and names a
truth owner for each. Those truth owners are **not in the shipped `Models.swift`**:

| Matrix truth owner | In `ios/CurlPlan/Models.swift`? |
| --- | --- |
| `AppData.setupComplete` (FR-SETUP) | **No** |
| `Store.seasonSummary` (FR-PASSPORT) | **No** |
| `StopVisit`, `isCurrentStop`, `peopleMetIDs(for:)` (FR-STOPS) | **No** |
| `GameResult` (FR-RESULTS) | **No** |
| `SpielAttendance` (FR-ATTENDANCE) | **No** |
| `BonspielRecord`, `BonspielGame`, `BonspielRosterPolicy`, `BonspielResultFlags` (FR-BONSPIEL-*) | **No** |

The shipped model graph is `Curler / Stop / Spiel / Post / VisitEntry / IceReadEntry /
ReviewEntry / Message / Account / AuthState / AppState / Store`. This is the expected
consequence of `docs/curlplan-branch-integration-2026-08-12.md`, which deliberately
discarded the replacement `AppData` graph and kept `main` authoritative — but the matrix
was never re-based onto the surviving code.

**Impact:** the matrix's Green ratings are not evidence about the app that ships, and
several Phase 2 walkthroughs below (bonspiel scorecard, lineup lock, stop visits) cannot
be performed because the features are not in the build. Re-basing the matrix onto the
current `Store` is a prerequisite for treating it as a release gate again.

### 2. The app has zero accessibility identifiers

`grep -c accessibilityIdentifier ios/CurlPlan/*.swift` → **0**.

The matrix names `CurlPlanUITests/CurlPlanPrimaryScreenflowUITests` as the proof for
FR-A11Y, FR-CIRCLE, and FR-BONSPIEL-SCORE, and `scripts/feature_review_matrix_check.sh`
prints those `-only-testing:` commands as required proof. **`ios/CurlPlanUITests/` does
not exist**, and it cannot be written usefully until elements are addressable: with no
identifiers, every query would bind to display copy and break on any wording change.

**Deliberately not done in Phase 0:** scaffolding that UI-test target. Adding a test
that asserts against nonexistent features, or that binds to raw strings, would encode a
false proof and redden CI. It needs identifiers first — see Phase 1.5.

## Phase 0 — repo-side prep (done)

- `swift test --scratch-path /tmp/curlplan-spm-build` added to the `ios` CI job.
  `tests/CurlPlanCoreTests/` is 695 lines of account-contract tests (backend API, HTTP
  backend, runtime, social contracts, persistence) that **ran nowhere** until now, while
  being the matrix's named proof command for every Green row.
- CI simulator selection hardened: `iPhone 1[567]` → `iPhone [0-9]+`, so the job keeps
  working as runner images roll forward.
- Stale compile-status notes corrected in `ios/README.md` and `CLAUDE.md`.

## Phase 1 — first launch

```bash
git pull && node scripts/gen-seed.js --check
node ios/generate-xcodeproj.js
open ios/CurlPlan.xcodeproj      # scheme CurlPlan, iPhone simulator, ⌘R
```

Expect a clean build. Watch for what CI cannot see:

- SwiftUI runtime warnings in the console.
- **ATS / dev backend.** `ios/CurlPlan/Info.plist` carries a cleartext exception for
  `dominic.tailae148c.ts.net` (the dev account backend on the private tailnet). Off the
  tailnet that host is unreachable. `AccountRuntime.resolveBackendURL` reads an env var
  and a launch argument, so the default path should stay fully local — confirm the auth
  gate does not stall waiting on it.

## Phase 1.5 — accessibility identifiers (prerequisite for any UI test)

Add `.accessibilityIdentifier(...)` to the primary controls, starting with `CPTabBar`'s
four tab buttons in `RootView.swift` (`passport`, `locker`, `spiels`, `roster`), then the
compose/save controls on each screen. Only then is
`CurlPlanUITests/CurlPlanPrimaryScreenflowUITests` writable against stable anchors, and
only then is a UI-test target worth adding to `generate-xcodeproj.js`
(`com.apple.product-type.bundle.ui-testing`, `TEST_TARGET_NAME = CurlPlan`).

## Phase 2 — drive the screenflows

Walk the surfaces that were authored blind and never seen running. These compile but can
render or behave wrong:

- **Passport** — derived stats, season-map tallies, recent-stop avatars (rewritten in
  PR #12, never seen rendering).
- **RootView** — four `NavigationStack`s kept alive and opacity-switched. Verify pushed
  routes and scroll position survive tab changes and no pane renders over another.
- **PebbleOverlay** — the accumulated-`Path` perf rewrite: check it draws and does not
  cost scrolling.
- **Compose / stop contributions / message threads** — enter each loop, save, confirm the
  result appears on every related screen.
- **Relaunch** — kill and reopen; confirm follows, likes, posts, visits persisted.
- **Theming + Dynamic Type** — Ice/Arena, accent, accessibility-medium content size.
  Fonts fall back to system faces (Instrument Serif et al. are not bundled).

Skip the bonspiel and stop-visit rows: per Finding 1 those features are not in this build.

## Phase 3 — capture and close

Record findings in a packet from `docs/curlplan-feature-review-packet-template.md`. File
runtime defects as issues rather than fixing inline — a first-run pass usually surfaces
several small layout items that are better triaged than bundled.

**Definition of done:** app launched and driven on a simulator; each Phase 2 surface
either confirmed or ticketed; the matrix re-based onto the shipped `Store` (Finding 1);
identifiers landed and a real `CurlPlanPrimaryScreenflowUITests` running in CI
(Finding 2).
