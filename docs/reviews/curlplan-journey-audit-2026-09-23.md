# CurlPlan live journey audit — 2026-09-23

## Release call

**Web: Red. iOS: Yellow for the tested demo journey.** The live web journeys mostly work, but browser Back leaves both apps and the current homepage gives users no route to the original Classic planner. The native demo journey passed on standard and small iPhone simulators; assistive technology, Dynamic Type, and account release flows still need separate proof.

The native audit added stable accessibility identifiers and a simulator test harness. The web findings have not been repaired or successfully retested.

## Scope and method

- Web source: `main` at `623bd18fb2da2c5ebdb5d6af5179c3039dda73b6`, clean before audit. Its [Verify run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35842151117), [security run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35842151080), and [Pages deployment](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35842149973) succeeded.
- iOS source: `49d90e5b2ba54576b1173060def5f4031c458e64`, merged to `main` as `6a41f338f0af918987cfdfe8de89fde681652508` in [PR #17](https://github.com/DaveHomeAssist/curl-plan/pull/17). Its [simulator run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35845736958), PR iOS and web checks, and security scan passed.
- Live surfaces: [current web app](https://davehomeassist.github.io/curl-plan/) and [Classic planner](https://davehomeassist.github.io/curl-plan/classic/).
- Interaction: isolated Chrome browser contexts, mobile 390 × 844 for scripted journeys, plus 320 × 700, 768 × 1024, 1440 × 900, and 3840 × 1080 layout checks. All writes in these journeys stayed in each isolated browser's local storage.
- Evidence: [web results](evidence/curlplan-journey-2026-09-23/web-results.json), [Classic results](evidence/curlplan-journey-2026-09-23/classic-results.json), [layout and navigation results](evidence/curlplan-journey-2026-09-23/crosscut-results.json), and screenshots linked below. Automated interactions were followed by visual inspection of rendered screenshots.
- Limits: Chrome was the only browser driven interactively. Safari, VoiceOver, Dynamic Type, recruited curler usability sessions, and broader native flows remain unverified.

## Journey results

| ID | Result | Current evidence |
| --- | --- | --- |
| W1 | Pass | Entered demo, opened Kelowna Stop from Passport, and returned with the in-app Back button. [Stop detail screenshot](evidence/curlplan-journey-2026-09-23/W1-stop.png). |
| W2 | Pass | Locker empty search showed a clear message; Following/Discover switched; a new note appeared and survived reload. [Locker screenshot](evidence/curlplan-journey-2026-09-23/W2-locker.png). |
| W3 | Pass | Registered for a spiel, followed a curler, opened and left the profile, switched tabs, and confirmed registration after reload. |
| W4 | **Fail** | Direct `#locker`, `#spiels`, `#roster`, `#stop/kelowna`, and `#curler/sam` links and curler reload worked. Browser Back from Stop detail went to `about:blank` instead of Passport. Sign out returned to the demo gate and persisted after reload. |
| C1 | Pass | Created an event, found its detail in Calendar, saved Planner notes with visible “Saved” feedback, used “Log This Game” with opponent prefill, saw the new Game Log entry and dashboard count, and confirmed the result after reload. [Game Log screenshot](evidence/curlplan-journey-2026-09-23/C1-games.png). |
| C2 | Pass | Practice and Ice Notes entries remained findable after reload. |
| C3 | Pass for tested cases | Export included a new event; reset removed it; import restored it; malformed JSON left it intact; Classic's service worker loaded Dashboard and Planner offline. An unsaved Event draft prompted before discard. |
| X1 | **Fail** | No visible route to Classic existed before or after entering the current demo. The homepage did not explain that Classic data uses a separate local storage key. [Current homepage at 320 px](evidence/curlplan-journey-2026-09-23/root-320.png). |
| I1 | Pass for tested demo flow; broader review open | The [XCUITest journey](../../ios/CurlPlanUITests/CurlPlanJourneyUITests.swift) passed with zero failures on iPhone 15 Pro and iPhone SE (3rd generation), both iOS 17.0.1: fresh demo entry, four tabs, Stop/Profile detail and Back, follow state, and relaunch persistence. See the [CI run and downloadable result bundles](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35845736958). [Small demo](evidence/curlplan-journey-2026-09-23/ios-small-demo.png), [Passport](evidence/curlplan-journey-2026-09-23/ios-small-passport.png), [Stop](evidence/curlplan-journey-2026-09-23/ios-small-stop.png), and [Profile](evidence/curlplan-journey-2026-09-23/ios-small-profile.png); [standard Passport](evidence/curlplan-journey-2026-09-23/ios-standard-passport.png), [Stop](evidence/curlplan-journey-2026-09-23/ios-standard-stop.png), and [Profile](evidence/curlplan-journey-2026-09-23/ios-standard-profile.png). Screenshots were visually inspected; no obvious overlap or clipping appeared on these captured states. |
| I2 | **Not enabled for release** | Current web and iOS auth gates offer a credential-free demo, not account creation or sign in. Local backend AS 01–12 checks pass, but they cannot substitute for an in-app account screenflow or public production service. |

## Findings, in priority order

### High — browser Back exits the app

Repro: enter the current demo, open a Stop detail, press the browser Back control. Chrome returns to `about:blank` rather than Passport. Classic behaves the same after Calendar → Game Planner. Both routers write view changes with `history.replaceState` (`index.html:1854`; `classic/assets/js/app/actions.js:163`), so they create no history entry for the previous screen. In-app Back works for current Stop detail, but browser history disagrees with the visible navigation. Retest both tab and detail transitions after a fix.

### High — original planner is undiscoverable from the current site

The Classic planner is live at `/classic/`, but the current site's signed-out gate and four-tab demo have no link to it. A user starting from the homepage cannot reach the Calendar/Game Planner workflow or learn whether Classic and the new demo share data. Source keys differ: root uses `curlplan-hifi-state-v1`; Classic uses `curlplan-v1`. Provide an explicit route and a plain-language data boundary, then run X1 with a new user who has not been given the Classic URL.

### Medium — Classic's narrow-screen next action is clipped

At 320 CSS px, the suggested-next button's “Open Calendar” text needs 91 px but its content box is 65 px with hidden overflow. The rendered [320 px screenshot](evidence/curlplan-journey-2026-09-23/classic-320.png) shows the dashboard action label cut off. The same component also showed a clipped “Quick Add Event” label. Recheck all state-strip actions at 320 and 390 px after adjusting the layout.

### Medium — small “All” action on Passport

The Recent Stops “All” action has a 14 × 16 px box at 320 and 390 px. It is keyboard-focusable and does open Spiels, but its touch area is difficult to target. The map pins look smaller, although their `::after` pseudo-element expands their effective hit area; they were not classified as a defect from visual size alone.

## Supporting checks

- `node scripts/gen-seed.js --check`, `verify-app.js`, `verify-split.js`, and `verify-parity.js`: pass.
- `make account-backend-verify`: all local AS checks pass, including credential rejection, restore, deletion, authorization, persistence, and rate limits.
- `swift test --scratch-path /tmp/curlplan-audit-spm-20260923`: Swift core compilation proceeded, then tests stopped at `no such module 'XCTest'` under Command Line Tools. This is host tooling, not an observed source failure.
- `make feature-review`: passed after mapping the current auth view and native journey. Generated Xcode project parsed as a plist and its shared scheme parsed as XML. The PR's iOS, web, and security checks passed. CI's XCUITest reported one test and zero failures on each simulator; the result bundle was downloaded and the retained screenshots were inspected.
- Chrome keyboard activation reached Roster and Classic Planner; current-web Settings moved focus into its dialog and restored focus on Escape. Current-web Arena and Classic dark theme choices survived reload. Blank compose and blank event save showed validation messages. No page exceptions appeared during the scripted journeys.
- No document-level horizontal overflow was measured at the five tested widths. The root's phone-frame desktop layout is an intentional mobile-first presentation and was not marked as a defect here.

## Remaining proof and retest gate

1. Fix and retest the four web findings on the deployed user surface; retain before/after screenshots and browser-history results. No failed finding is considered closed by a code change or CI result alone.
2. Extend native review beyond the now-passing demo journey: Dynamic Type, VoiceOver focus/labels, target reachability, layout at larger text sizes, and additional mutation/recovery flows. Inspect console warnings and repeat on the actual release configuration before an iOS release.
3. Keep I2 outside the production release call until an account UI and public service are enabled. Then run create → sign out → sign in → restore → export → delete, plus invalid credentials, unavailable service, and revoked session, against the actual release configuration.
4. Have representative curlers attempt W1–C3 and X1 without route hints; record completion, wrong turns, and unclear next actions. This scripted audit cannot prove first-use comprehension by itself.

**Green requires:** all critical journeys complete, all High findings fixed and retested live, no data loss or misleading account claim, and native evidence for any iOS release under consideration.
