# CurlPlan

> Your season, your circle. A curling-native app — map your season, stay close to your circle.

The root app (`index.html`) is the **Hi-Fi concept**: a mobile-first, single-file
build of the "Passport + Locker Room" direction. The original multi-view planner
is preserved, fully working, under [`classic/`](classic/).

## Hi-Fi app (root)

A single HTML file today, web fonts only — with a build step, dependencies, and a backend all on the table as it grows.

### Screens

- **Passport** (home) — season telemetry, the house-ring season map, recent stops
- **Locker Room** — result posts, shared spiels, rink reviews, compose FAB
- **Stop detail** — ice read, your games here, people you met
- **Curler profile** — identity, stats, shared rinks, recent form
- **Spiels** — your season schedule and who from your circle is going
- **Roster** — your circle, with follow/unfollow

### Interactions

- Bottom **tab bar** navigation + push/back into stop & curler detail screens
- **Follow/unfollow** across Roster, profiles, and stop detail
- **Appearance** settings (tap the avatar): Ice/Arena theme, accent
  (House red / blue / Granite), pebble texture — persisted to localStorage
- **Deep links**: `#locker`, `#spiels`, `#roster`, `#stop/<id>`, `#curler/<id>`
- **Shareable themed links**: `?theme=arena&accent=House%20blue&pebble=0`

### Quick start

Open `index.html` in a browser, or serve the repo from any static host.

## Classic app (`classic/`)

The original planner — Calendar, Game Log, Practice Tracker, Ice Notes, Daily
Planner — with split CSS/JS assets, localStorage persistence, and offline support.
Still live at `classic/index.html`. See [`classic/`](classic/) for its assets.

## Native iOS app (`ios/`)

A SwiftUI port of the Hi-Fi concept — same six screens, house-ring system, Ice/Arena
theming, tab navigation, and push-to-detail flows. Open `ios/CurlPlan.xcodeproj` in
Xcode 15.4+ (iOS 17+) — nothing extra to install. See [`ios/README.md`](ios/README.md).

## Structure

```
curl-plan/
├── index.html              # Hi-Fi web app (single file today)
├── sw.js                   # Service worker (network-first; purges legacy cache)
├── ios/                    # Native SwiftUI port (Xcode project)
│   ├── CurlPlan.xcodeproj
│   └── CurlPlan/*.swift
├── classic/                # Original multi-view planner (archived, still working)
│   ├── index.html
│   ├── sw.js
│   └── assets/css|js|icons
├── docs/                   # Brand bible, UX audits, how-to guide
├── scripts/
│   ├── verify-app.js       # Verifies the root Hi-Fi app + service worker
│   └── verify-split.js     # Verifies the classic split app
├── CLAUDE.md               # Architecture + engineering policy
└── README.md               # This file
```

## Shared season seed (single source of truth)

The demo season (curlers, stops, spiels, feed) lives in **`data/season-seed.json`** and
is the only place to edit it. `node scripts/gen-seed.js` regenerates the web seed block
in `index.html` **and** the iOS `Seed.generated.swift` from it — so the two apps can't
drift. It also emits a shared club vocabulary from `data/curling-clubs.json`. CI fails if
the generated output is stale.

## Verification

```bash
node scripts/gen-seed.js          # regenerate web + iOS seed from data/season-seed.json
node scripts/gen-seed.js --check  # CI: fail if generated seed is stale
node scripts/verify-app.js        # root Hi-Fi app: JS parses, views/router/SW/favicon present
node scripts/verify-split.js      # classic app: required IDs, script order, schema, parseability
node scripts/verify-parity.js     # CI: each capability present on BOTH web and iOS
```

All run in CI via `.github/workflows/verify.yml` (a `web` job on Linux + an `ios` job on
macOS that regenerates the Xcode project and runs `xcodebuild build`).

## Deployment

- **Host:** GitHub Pages
- **Build step:** None (static)

## Tech

- Single-file root app today (dependencies + backend welcome as it grows)
- localStorage for appearance prefs; service worker for offline shell
- Responsive: device frame on desktop, full-bleed on phones
