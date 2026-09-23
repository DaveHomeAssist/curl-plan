# CurlPlan live journey audit — 2026-09-23

## Release call

**Web: Yellow. iOS: Red.** All scripted web journeys pass on the deployed current and Classic apps at phone and desktop sizes. Safari 26.6.1 now passes demo entry, Classic data-boundary discovery, Stop detail, in-app Back, and browser Back through keyboard activation at a requested phone-width window and desktop window. The Classic close control receives keyboard focus and closes with Enter, but SafariDriver did not dispatch pointer clicks and did not expose a visible `:focus-visible` state, so rendered tap and visible-focus proof remain open. The native demo journey passes on small and standard simulators at default text size and on the small simulator at Accessibility Medium. The latest broad audits still fail with 65 standard and 68 small findings, all partial Dynamic Type or contrast. Actual VoiceOver use, current-build physical-device proof, first-use comprehension with representative curlers, and account release flows remain unverified.

The native audit added stable accessibility identifiers and a simulator test harness. The web repair and Classic close-target fix shipped on `main` through `1e06cb7be2814912e53cb0116d1e33584feb9ba2`. Native repairs remain on draft [PR #18](https://github.com/DaveHomeAssist/curl-plan/pull/18) at `4bdab1c6da268b417b3c0a15c3fb4496c7026e21`.

## Scope and method

- Web baseline: `main` at `623bd18fb2da2c5ebdb5d6af5179c3039dda73b6`, clean before audit. The primary repair shipped at `e36a3dee9b18438a7e6a0613b393be70850681a6`; the Classic close-target fix shipped at `1e06cb7be2814912e53cb0116d1e33584feb9ba2`. Pages, Verify, Security, post-merge, and live asset readback passed.
- iOS source: draft [PR #18](https://github.com/DaveHomeAssist/curl-plan/pull/18) at `4bdab1c6da268b417b3c0a15c3fb4496c7026e21`, reconciled with `main` at `1e06cb7`. Its [Verify run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880566197) and [Security run](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880566196) passed. It is not merged or released.
- Live surfaces: [current web app](https://davehomeassist.github.io/curl-plan/) and [Classic planner](https://davehomeassist.github.io/curl-plan/classic/).
- Interaction: isolated Chrome browser contexts, mobile 390 × 844 and desktop 1440 × 900 for full scripted journeys, plus focused 320 × 700 navigation and layout retests. Initial layout checks also covered 768 × 1024 and 3840 × 1080. Safari 26.6.1 was driven through Apple's SafariDriver at requested 390 × 844 and 1440 × 900 windows; Safari exposed actual CSS viewports of 458 × 887 and 1694 × 952 on this host. A persistent Chrome profile seeded before the repair tested the Classic service worker upgrade. All journey writes stayed in browser local storage.
- Baseline evidence: [web results](evidence/curlplan-journey-2026-09-23/web-results.json), [Classic results](evidence/curlplan-journey-2026-09-23/classic-results.json), [layout and navigation results](evidence/curlplan-journey-2026-09-23/crosscut-results.json). Live retest evidence: [phone web](evidence/curlplan-journey-2026-09-23/retest-phone-web-results.json), [phone Classic](evidence/curlplan-journey-2026-09-23/retest-phone-classic-results.json), [desktop web](evidence/curlplan-journey-2026-09-23/retest-desktop-web-results.json), [desktop Classic](evidence/curlplan-journey-2026-09-23/retest-desktop-classic-results.json), [Safari results](evidence/curlplan-journey-2026-09-23/safari-results.json), and screenshots linked below. Chrome screenshots were visually inspected. SafariDriver returned only unusable 96 × 117 thumbnails and macOS rejected bounded screen capture, so no Safari screenshot is retained.
- Native accessibility method: [CI run 35852887967](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35852887967) ran Apple's `performAccessibilityAudit()` across the demo gate, Passport, Stop detail, four tabs, and Profile on iPhone 15 Pro and SE (3rd generation), iOS 17.0.1. Its screenflow tests passed and accessibility tests failed. [CI findings and screenshot index](evidence/curlplan-journey-2026-09-23/native-audit-ci-results.json) include build, device, starting data, expected versus actual, and per-screen counts. A separate [local SE audit](evidence/curlplan-journey-2026-09-23/native-audit-se3-results.json) on iOS 26.5 reproduced the classes of failure. Screenshots were inspected.
- [Current screenflow run 35880557947](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) at `4bdab1c` passed standard, small, and small Accessibility Medium journeys plus the focused Passport control audit. The broad audits intentionally failed on 65 standard findings (44 partial Dynamic Type, 21 contrast) and 68 small findings (39 partial Dynamic Type, 29 contrast). Zero clipping, unnamed-control, undersized-hit-target, or fully unsupported Dynamic Type findings remain. The [remote artifact](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947/artifacts/10762660707) retains screenshots and results through 2026-09-30 without using local disk.
- Limits: Safari pointer activation and visible focus treatment, actual VoiceOver operation, current-build physical-device use, recruited curler usability sessions, and the public account lifecycle remain unverified. The automated native audit flags issues; it is not an assistive-technology session.

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
| I1 | **Navigation and larger-text pass; broad accessibility fail** | [Screenflow run 35880557947](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) passed fresh demo entry, all four tabs, Stop/Profile detail and Back, follow state, relaunch persistence, the small Accessibility Medium journey, and the focused Passport-control audit. The broad audits still report 65 standard and 68 small partial Dynamic Type or contrast findings. Current-build physical iPad and actual VoiceOver proof remain open. |
| I2 | **Not enabled for release** | Current web and iOS auth gates offer a credential-free demo, not account creation or sign in. Local backend AS 01–12 checks pass, but they cannot substitute for an in-app account screenflow or public production service. |

## Findings, in priority order

### Resolved High — browser Back exited the app

Baseline: browser Back from current Stop detail returned to `about:blank`; Classic Calendar → Game Planner had the same failure. Both routers replaced rather than pushed user navigation history. Repair: user navigation now pushes history, while initial route setup and auth reset replace it. Live retest at 390 and 1440 px passed root detail, tab, in-app Back, Classic Calendar → Planner Back/Forward, and direct deep-link fallback. [Root Back](evidence/curlplan-journey-2026-09-23/W4-back-390.png); [Classic existing-profile Back](evidence/curlplan-journey-2026-09-23/old-profile-v9-pass.png).

### Resolved High — original planner was undiscoverable from the current site

Baseline: the current site's signed-out gate and demo offered no link to `/classic/` or explanation of its separate data. Repair: the signed-out gate and Passport now show a Classic link and data boundary. Scripted live activation passed at 320, 390, and 1440 px. An unprompted first-use test with a representative curler remains open.

### Resolved Medium — Classic's narrow-screen next action was clipped

Baseline: “Open Calendar” and “Quick Add Event” were clipped at 320 CSS px. The state strip now wraps its action; both labels were visually and dimensionally retested at 320 and 390 px. [Before](evidence/curlplan-journey-2026-09-23/classic-320.png); [after](evidence/curlplan-journey-2026-09-23/C1-planner-320.png).

### Medium — Classic modal close tap and visible-focus proof remains open

The [crosscut results](evidence/curlplan-journey-2026-09-23/crosscut-results.json) measured seven close buttons at 15–20 × 34 CSS px at a 320 px viewport, and four at 20–23 × 34 px at 390 px. Their declared width shrank in the flex modal header. [PR #19](https://github.com/DaveHomeAssist/curl-plan/pull/19) fixed their basis and dimensions at 44 × 44 px and advanced the stylesheet and service-worker cache versions. It merged to `main` as `1e06cb7`; Pages and post-merge checks passed, and the live HTML/CSS/cache assets show the new version. Safari loaded the new stylesheet, placed the close control first in the modal tab order, focused it from the first field with Shift+Tab, and closed it with Enter. Its computed size was 43.99 × 43.99 CSS px in Safari's scaled requested-phone window. SafariDriver pointer commands did not dispatch click events and its synthetic keys did not set `:focus-visible`, so an actual rendered tap and visible-focus observation remain required. [Structured Safari evidence](evidence/curlplan-journey-2026-09-23/safari-results.json).

### High — iOS does not scale with the system text setting

Apple's baseline audit reported unsupported Dynamic Type font sizes on every tested native screen on both devices. On an isolated iPhone SE with iOS 26.5, changing content size from Large to Accessibility Medium had produced [pixel-identical app content](evidence/curlplan-journey-2026-09-23/native-se3-content-size-compare.json). The branch now uses scaled system text styles, and the Accessibility Medium journey passes. The [current audit](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) reports zero fully unsupported findings but still records 44 partial Dynamic Type findings on the standard phone and 39 on the small phone. They are concentrated in compact labels, initials, and metadata. Actual VoiceOver use and further visible scaling review remain required.

### High — iOS contrast failures across the core journey

The baseline standard audit recorded 222 `Contrast failed` events and the small audit 219. The native `TabView` repair removed inactive-pane leakage from the current results. The [current audit](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) reports 21 standard and 29 small contrast findings, concentrated in compact visual labels, scores, initials, and secondary Stop/Profile metadata. These findings and an actual VoiceOver pass remain release blockers.

### High — iOS Passport controls were small or lacked names; repaired on the audit branch

Both baseline CI devices found five undersized hit regions and five elements without descriptions on Passport. The local SE audit identified four map pins and the “All” action among the hit-region failures. “All” opened Spiels instead of an all-stops view. The branch removes that action, expands map-pin and Settings-avatar targets to 44 × 44 points, and names the controls. The focused control test and both broad audits in [run 35880557947](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) report zero hit-region or unnamed-control failures. This native branch has not been merged into `main` or released.

### Resolved Medium — native text-clipping audit flags

The baseline and early repair audits reported clipped Stop metadata, Spiel dates and names, status text, and a read-only rating label. The branch now lets those labels wrap, isolates the rating as one noninteractive accessibility element, and uses native tabs so inactive panes are not audited as visible content. [Run 35880557947](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) reports zero clipping findings on both devices. The prior `Prairie Cashspiel` clipping and `4 out of 5 stars` hit-area regressions are absent.

### Resolved Medium — small “All” action on the web Passport

The web Recent Stops “All” action had a 14 × 16 px box and led to Spiels rather than an All Stops view. It was removed. Web map pins have an expanded effective hit area through their `::after` element; the native map pins had separate audit failures and were repaired on this branch.

## Supporting checks

- `node scripts/gen-seed.js --check`, `verify-app.js`, `verify-split.js`, and `verify-parity.js`: pass.
- `make account-backend-verify`: all local AS checks pass, including credential rejection, restore, deletion, authorization, persistence, and rate limits.
- Xcode 27.0 is available. The shell's default developer directory is Command Line Tools, so Xcode commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` explicitly. Two valid signing identities and a matching provisioning profile include David's iPad. A constrained one-job device build reached destination setup but stopped before creating DerivedData because the iPad had locked; the result bundle, log, and disposable build directory were deleted.
- [Verify run 35880566197](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880566197) and [Security run 35880566196](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880566196) passed at `4bdab1c`. [Screenflow run 35880557947](https://github.com/DaveHomeAssist/curl-plan/actions/runs/35880557947) passed all three journeys and the focused Passport controls; its expected failure is limited to the remaining broad partial Dynamic Type and contrast findings.
- `make feature-review`: passed after mapping the current auth view and native journey. Generated Xcode project parsed as a plist and its shared scheme parsed as XML. The PR's iOS, web, and security checks passed. CI's XCUITest reported one test and zero failures on each simulator; the result bundle was downloaded and the retained screenshots were inspected.
- Chrome keyboard activation reached Roster and Classic Planner; current-web Settings moved focus into its dialog and restored focus on Escape. Current-web Arena and Classic dark theme choices survived reload. Blank compose and blank event save showed validation messages. No page exceptions appeared during the scripted journeys.
- The repaired live Classic shell served versioned CSS and JavaScript. A pre-repair persistent Chrome profile upgraded from service worker cache v6 through v9; after activation, Calendar → Planner browser Back returned to Calendar. Fresh-context offline Planner and Dashboard passed at phone and desktop sizes. The currently loaded page may need one reload when a waiting service worker activates.
- The repaired live root's Classic link and Calendar tab activated with keyboard Enter at 320 px and exposed expected accessible names. Safari 26.6.1 also passed demo entry, Classic data-boundary discovery, Stop detail, in-app Back, and browser Back through keyboard activation at requested phone-width and desktop windows. This is keyboard and semantic evidence, not a VoiceOver test or pointer-tap pass.
- No document-level horizontal overflow was measured at the five tested widths. The root's phone-frame desktop layout is an intentional mobile-first presentation and was not marked as a defect here.

## Remaining proof and retest gate

1. Keep David's iPad unlocked and awake, preferably connected by USB, install `4bdab1c`, and run I1 with actual VoiceOver. Resolve the 44/39 partial Dynamic Type and 21/29 contrast findings that reproduce as visible problems. Simulator journeys, zero clipping, and zero core-control findings do not substitute for physical assistive-technology proof.
2. Complete the Safari pointer-tap and visible-focus observation for the Classic close control, then run a real web assistive-technology pass. Safari keyboard navigation passing does not prove pointer activation or spoken output.
3. Keep I2 outside the production release call until an account UI and public service are enabled. Then run create → sign out → sign in → restore → export → delete, plus invalid credentials, unavailable service, and revoked session, against the actual release configuration.
4. Have representative curlers attempt W1–C3 and X1 without route hints; record completion, wrong turns, and unclear next actions. This scripted audit cannot prove first-use comprehension by itself.

**Green requires:** all critical journeys complete, all High findings fixed and retested live, no data loss or misleading account claim, and native evidence for any iOS release under consideration.
