# CurlPlan live journey audit — 2026-09-23

## Release call

**Web: Yellow. iOS: Red.** All scripted web journeys now pass on the deployed current and Classic apps at phone and desktop sizes. The four web findings from the initial audit were repaired and retested live. The native demo journey passes on small and standard simulators, but automated accessibility audits fail on both. An iPhone SE content-size comparison confirms that the app does not scale its content with the system text setting. Actual VoiceOver use, Safari, first-use comprehension with representative curlers, and account release flows remain unverified.

The native audit added stable accessibility identifiers and a simulator test harness. The web repair shipped on `main` through `e36a3dee9b18438a7e6a0613b393be70850681a6`.

## Scope and method

- Web baseline: `main` at `623bd18fb2da2c5ebdb5d6af5179c3039dda73b6`, clean before audit. Repair and live retest: `e36a3dee9b18438a7e6a0613b393be70850681a6`. Its [Verify run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35849309359), [security run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35849309343), and [Pages deployment](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35849309471) succeeded.
- iOS source: `49d90e5b2ba54576b1173060def5f4031c458e64`, merged to `main` as `6a41f338f0af918987cfdfe8de89fde681652508` in [PR #17](https://github.com/DaveHomeAssist/curl-plan/pull/17). Its [simulator run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35845736958), PR iOS and web checks, and security scan passed.
- Live surfaces: [current web app](https://davehomeassist.github.io/curl-plan/) and [Classic planner](https://davehomeassist.github.io/curl-plan/classic/).
- Interaction: isolated Chrome browser contexts, mobile 390 × 844 and desktop 1440 × 900 for full scripted journeys, plus focused 320 × 700 navigation and layout retests. Initial layout checks also covered 768 × 1024 and 3840 × 1080. A persistent Chrome profile seeded before the repair tested the Classic service worker upgrade. All journey writes stayed in browser local storage.
- Baseline evidence: [web results](evidence/curlplan-journey-2026-09-23/web-results.json), [Classic results](evidence/curlplan-journey-2026-09-23/classic-results.json), [layout and navigation results](evidence/curlplan-journey-2026-09-23/crosscut-results.json). Live retest evidence: [phone web](evidence/curlplan-journey-2026-09-23/retest-phone-web-results.json), [phone Classic](evidence/curlplan-journey-2026-09-23/retest-phone-classic-results.json), [desktop web](evidence/curlplan-journey-2026-09-23/retest-desktop-web-results.json), [desktop Classic](evidence/curlplan-journey-2026-09-23/retest-desktop-classic-results.json), and screenshots linked below. Rendered screenshots were visually inspected.
- Native accessibility method: [CI run 35852887967](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35852887967) ran Apple's `performAccessibilityAudit()` across the demo gate, Passport, Stop detail, four tabs, and Profile on iPhone 15 Pro and SE (3rd generation), iOS 17.0.1. Its screenflow tests passed and accessibility tests failed. [CI findings and screenshot index](evidence/curlplan-journey-2026-09-23/native-audit-ci-results.json) include build, device, starting data, expected versus actual, and per-screen counts. A separate [local SE audit](evidence/curlplan-journey-2026-09-23/native-audit-se3-results.json) on iOS 26.5 reproduced the classes of failure. Screenshots were inspected.
- Limits: Chrome was the only browser driven interactively. Safari, actual VoiceOver operation, recruited curler usability sessions, and broader native/account flows remain unverified. The automated audit flags issues; it is not an assistive-technology session.

## Journey results

| ID | Result | Current evidence |
| --- | --- | --- |
| W1 | Pass | Entered demo, opened Kelowna Stop from Passport, and returned with the in-app Back button. [Stop detail screenshot](evidence/curlplan-journey-2026-09-23/W1-stop.png). |
| W2 | Pass | Locker empty search showed a clear message; Following/Discover switched; a new note appeared and survived reload. [Locker screenshot](evidence/curlplan-journey-2026-09-23/W2-locker.png). |
| W3 | Pass | Registered for a spiel, followed a curler, opened and left the profile, switched tabs, and confirmed registration after reload. |
| W4 | **Pass after repair** | Direct `#locker`, `#spiels`, `#roster`, `#stop/kelowna`, and `#curler/sam` links and reload worked. Browser Back from Stop detail returned to Passport at phone and desktop sizes; tab Back and Forward, in-app Back, direct-link fallback, and sign-out persistence also passed. [Phone Back screenshot](evidence/curlplan-journey-2026-09-23/W4-back-390.png). |
| C1 | Pass | Created an event, found its detail in Calendar, saved Planner notes with visible “Saved” feedback, used “Log This Game” with opponent prefill, saw the new Game Log entry and dashboard count, and confirmed the result after reload. [Game Log screenshot](evidence/curlplan-journey-2026-09-23/C1-games.png). |
| C2 | Pass | Practice and Ice Notes entries remained findable after reload. |
| C3 | Pass for tested cases | Export included a new event; reset removed it; import restored it; malformed JSON left it intact; Classic's service worker loaded Dashboard and Planner offline. An unsaved Event draft prompted before discard. |
| X1 | **Pass after repair** | A visible Classic link appears before demo entry and in Passport. It explains that Classic data is separate in this browser. Link activation was verified by click at 320, 390, and 1440 px and by keyboard Enter at 320 px. [Before repair](evidence/curlplan-journey-2026-09-23/root-320.png); [after repair](evidence/curlplan-journey-2026-09-23/X1-before-320.png). |
| I1 | **Navigation pass; accessibility fail** | The [XCUITest journey](../../ios/CurlPlanUITests/CurlPlanJourneyUITests.swift) passed with zero failures on iPhone 15 Pro and iPhone SE (3rd generation), both iOS 17.0.1: fresh demo entry, four tabs, Stop/Profile detail and Back, follow state, and relaunch persistence. See the [CI run and result bundles](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35852887967). [Small demo](evidence/curlplan-journey-2026-09-23/ios-small-demo.png), [Passport](evidence/curlplan-journey-2026-09-23/ios-small-passport.png), [Stop](evidence/curlplan-journey-2026-09-23/ios-small-stop.png), and [Profile](evidence/curlplan-journey-2026-09-23/ios-small-profile.png); [standard Passport](evidence/curlplan-journey-2026-09-23/ios-standard-passport.png), [Stop](evidence/curlplan-journey-2026-09-23/ios-standard-stop.png), and [Profile](evidence/curlplan-journey-2026-09-23/ios-standard-profile.png). The accessibility audit failed across the tested screens, detailed below. |
| I2 | **Not enabled for release** | Current web and iOS auth gates offer a credential-free demo, not account creation or sign in. Local backend AS 01–12 checks pass, but they cannot substitute for an in-app account screenflow or public production service. |

## Findings, in priority order

### Resolved High — browser Back exited the app

Baseline: browser Back from current Stop detail returned to `about:blank`; Classic Calendar → Game Planner had the same failure. Both routers replaced rather than pushed user navigation history. Repair: user navigation now pushes history, while initial route setup and auth reset replace it. Live retest at 390 and 1440 px passed root detail, tab, in-app Back, Classic Calendar → Planner Back/Forward, and direct deep-link fallback. [Root Back](evidence/curlplan-journey-2026-09-23/W4-back-390.png); [Classic existing-profile Back](evidence/curlplan-journey-2026-09-23/old-profile-v9-pass.png).

### Resolved High — original planner was undiscoverable from the current site

Baseline: the current site's signed-out gate and demo offered no link to `/classic/` or explanation of its separate data. Repair: the signed-out gate and Passport now show a Classic link and data boundary. Scripted live activation passed at 320, 390, and 1440 px. An unprompted first-use test with a representative curler remains open.

### Resolved Medium — Classic's narrow-screen next action was clipped

Baseline: “Open Calendar” and “Quick Add Event” were clipped at 320 CSS px. The state strip now wraps its action; both labels were visually and dimensionally retested at 320 and 390 px. [Before](evidence/curlplan-journey-2026-09-23/classic-320.png); [after](evidence/curlplan-journey-2026-09-23/C1-planner-320.png).

### High — iOS does not scale with the system text setting

Apple's audit reported unsupported Dynamic Type font sizes on every tested native screen on both devices. On an isolated iPhone SE (3rd generation) with iOS 26.5, changing system content size from Large to Accessibility Medium and relaunching the app produced [pixel-identical app content](evidence/curlplan-journey-2026-09-23/native-se3-content-size-compare.json) below the status bar. [Large](evidence/curlplan-journey-2026-09-23/native-se3-content-size-large.png); [Accessibility Medium](evidence/curlplan-journey-2026-09-23/native-se3-content-size-accessibility-medium.png). This is a systemic release blocker; no successful retest yet.

### High — iOS contrast failures across the core journey

The standard simulator audit recorded 222 `Contrast failed` events and the small simulator 219, spanning the gate, Passport, Stop detail, tabs, and Profile. Repeated appearances of the same underlying view make these event counts larger than the number of distinct controls. [Standard Passport](evidence/curlplan-journey-2026-09-23/native-audit-ci-standard-passport.png); [small Passport](evidence/curlplan-journey-2026-09-23/native-audit-ci-small-passport.png). Contrast needs a design-token and component-level repair followed by a new audit; no successful retest yet.

### High — iOS Passport controls were small or lacked names; repaired on the audit branch

Both CI devices found five undersized hit regions and five elements without descriptions on Passport. The local SE audit identified four map pins and the “All” action among the hit-region failures. “All” opened Spiels instead of an all-stops view. The branch removes that action, expands map-pin and Settings-avatar targets to 44 × 44 points, and names the controls. A [focused local retest](evidence/curlplan-journey-2026-09-23/native-retest-se3-passport-controls.json) on the SE passed: one test, zero hit-region or description failures. [Retest screenshot](evidence/curlplan-journey-2026-09-23/native-retest-se3-passport-controls.png). This branch has not been merged into `main` or released.

### Medium — Stop detail text-clipping audit flags

The CI audit flagged one label on the standard simulator and two on the SE. The local SE audit named “📍 KELOWNA, BC · JAN 9–11” and “SPEED · 24.1s.” A spacing/wrapping experiment still produced both failures in the focused retest, so it was not retained. The screenshot appears legible at the captured size, but that does not clear the automated finding or larger-text behavior. [Initial SE Stop](evidence/curlplan-journey-2026-09-23/native-audit-se3-stop-detail.png); [focused retest](evidence/curlplan-journey-2026-09-23/native-retest-se3-stop-labels.png).

### Resolved Medium — small “All” action on the web Passport

The web Recent Stops “All” action had a 14 × 16 px box and led to Spiels rather than an All Stops view. It was removed. Web map pins have an expanded effective hit area through their `::after` element; the native map pins had separate audit failures and were repaired on this branch.

## Supporting checks

- `node scripts/gen-seed.js --check`, `verify-app.js`, `verify-split.js`, and `verify-parity.js`: pass.
- `make account-backend-verify`: all local AS checks pass, including credential rejection, restore, deletion, authorization, persistence, and rate limits.
- Xcode 27.0 is available. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/curlplan-spm-audit-20260923-final` passed 18 tests. The focused iPhone SE XCUITest passed one Passport-control audit with zero failures. An earlier `no such module 'XCTest'` error came from running under Command Line Tools and is superseded.
- `make feature-review`: passed after mapping the current auth view and native journey. Generated Xcode project parsed as a plist and its shared scheme parsed as XML. The PR's iOS, web, and security checks passed. CI's XCUITest reported one test and zero failures on each simulator; the result bundle was downloaded and the retained screenshots were inspected.
- Chrome keyboard activation reached Roster and Classic Planner; current-web Settings moved focus into its dialog and restored focus on Escape. Current-web Arena and Classic dark theme choices survived reload. Blank compose and blank event save showed validation messages. No page exceptions appeared during the scripted journeys.
- The repaired live Classic shell served versioned CSS and JavaScript. A pre-repair persistent Chrome profile upgraded from service worker cache v6 through v9; after activation, Calendar → Planner browser Back returned to Calendar. Fresh-context offline Planner and Dashboard passed at phone and desktop sizes. The currently loaded page may need one reload when a waiting service worker activates.
- The repaired live root's Classic link and Calendar tab activated with keyboard Enter at 320 px and exposed expected accessible names. This is keyboard and semantic evidence, not a VoiceOver test.
- No document-level horizontal overflow was measured at the five tested widths. The root's phone-frame desktop layout is an intentional mobile-first presentation and was not marked as a defect here.

## Remaining proof and retest gate

1. Repair native Dynamic Type and contrast across shared typography and color components; rerun the full accessibility audit on small and standard simulators. Resolve the Stop label clipping flags and retest. The tested navigation path passing does not clear these failures.
2. Run a real assistive-technology pass on web and iOS, and interactive Safari checks for the web release. Keyboard and Chrome automation alone do not cover those environments.
3. Keep I2 outside the production release call until an account UI and public service are enabled. Then run create → sign out → sign in → restore → export → delete, plus invalid credentials, unavailable service, and revoked session, against the actual release configuration.
4. Have representative curlers attempt W1–C3 and X1 without route hints; record completion, wrong turns, and unclear next actions. This scripted audit cannot prove first-use comprehension by itself.

**Green requires:** all critical journeys complete, all High findings fixed and retested live, no data loss or misleading account claim, and native evidence for any iOS release under consideration.
