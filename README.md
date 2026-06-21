# CurlPlan

> Your season, your circle. A curling-native app — map your season, stay close to your circle.

The root app (`index.html`) is the **Hi-Fi concept**: a mobile-first, single-file
build of the "Passport + Locker Room" direction. The original multi-view planner
is preserved, fully working, under [`classic/`](classic/).

## Hi-Fi app (root)

A single, self-contained HTML file — no build, no dependencies, web fonts only.

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

## Structure

```
curl-plan/
├── index.html              # Hi-Fi app (self-contained single file)
├── sw.js                   # Service worker (network-first; purges legacy cache)
├── classic/                # Original multi-view planner (archived, still working)
│   ├── index.html
│   ├── sw.js
│   └── assets/css|js|icons
├── docs/                   # Brand bible, UX audits, how-to guide
├── scripts/
│   ├── verify-app.js       # Verifies the root Hi-Fi app + service worker
│   └── verify-split.js     # Verifies the classic split app
├── CLAUDE.md               # Architecture constraints
└── README.md               # This file
```

## Verification

```bash
node scripts/verify-app.js     # root Hi-Fi app: JS parses, views/router/SW/favicon present
node scripts/verify-split.js   # classic app: required IDs, script order, schema, parseability
```

Both run in CI on push/PR via `.github/workflows/verify.yml`.

## Deployment

- **Host:** GitHub Pages
- **Build step:** None (static)

## Tech

- Self-contained single-file root app (no dependencies)
- localStorage for appearance prefs; service worker for offline shell
- Responsive: device frame on desktop, full-bleed on phones
