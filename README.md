# CurlPlan

Personal curling calendar, planner, game log, and ice notes.

## Features

- **Calendar** — track games, practices, bonspiels, and league nights
- **Game Log** — record results, shot percentages, and key shots
- **Practice Tracker** — log sessions with focus areas and duration
- **Ice Notes** — remember rink conditions (speed, curl, quirks)
- **Daily Planner** — pre-game goals and post-game reflections
- **Import/Export** — back up and restore all data as JSON

## Usage

Open [index.html](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/index.html) in a browser, or serve the repo from any static host.

Data is stored in localStorage and persists across sessions.

## Structure

- Static entrypoint: [index.html](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/index.html)
- Styles: [assets/css/app.css](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/css/app.css)
- App scripts:
  - [utils.js](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/js/app/utils.js)
  - [core.js](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/js/app/core.js)
  - [render.js](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/js/app/render.js)
  - [actions.js](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/js/app/actions.js)
  - [bootstrap.js](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/assets/js/app/bootstrap.js)

## Verification

Run the split verification harness after structural changes:

```bash
node scripts/verify-split.js
```

This checks required IDs, script load order, `SCHEMA_VERSION`, and combined JS parseability.

## Guide

See [docs/how-to-guide.html](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/docs/how-to-guide.html) for the end-user walkthrough.

## Next Pass

See [NEXT_PASS_UX_FEATURES.md](/Users/daverobertson/Desktop/Code/10-active-projects/curl-plan/NEXT_PASS_UX_FEATURES.md) for the next planned UX/features pass.

## Tech

- Static HTML entrypoint with split CSS/JS assets
- No dependencies
- localStorage persistence
- Responsive layout (desktop + mobile)
