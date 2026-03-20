# CurlPlan

> Personal curling calendar, planner, game log, and ice notes.

## Features

- **Calendar** — track games, practices, bonspiels, and league nights
- **Game Log** — record results, shot percentages, and key shots
- **Practice Tracker** — log sessions with focus areas and duration
- **Ice Notes** — remember rink conditions (speed, curl, quirks)
- **Daily Planner** — pre-game goals and post-game reflections
- **Import/Export** — back up and restore all data as JSON

## Quick Start

Open `index.html` in a browser, or serve the repo from any static host.

Data is stored in localStorage and persists across sessions.

## Structure

```
curl-plan/
├── index.html                  # Static entrypoint
├── assets/
│   ├── css/app.css             # Styles
│   └── js/app/
│       ├── utils.js            # Shared utilities
│       ├── core.js             # State management and data model
│       ├── render.js           # UI rendering
│       ├── actions.js          # Event handlers and CRUD
│       └── bootstrap.js        # App initialization
├── docs/
│   ├── how-to-guide.html       # End-user walkthrough
│   ├── BRAND_BIBLE.md          # Brand positioning and tokens
│   └── IMPLEMENTATION_PLAN_*.md # UX task batches
├── scripts/
│   └── verify-split.js         # Split verification harness
├── AGENTS.md                   # Agent instructions and issue tracker
├── CLAUDE.md                   # Architecture constraints
└── README.md                   # This file
```

## Verification

Run the split verification harness after structural changes:

```bash
node scripts/verify-split.js
```

This checks required IDs, script load order, `SCHEMA_VERSION`, and combined JS parseability.

## Deployment

- **Host:** GitHub Pages
- **Build step:** None (static)

## Tech

- Static HTML entrypoint with split CSS/JS assets
- No dependencies
- localStorage persistence
- Responsive layout (desktop + mobile)

## Links

- Guide: `docs/how-to-guide.html`
- Next pass: `NEXT_PASS_UX_FEATURES.md`

## Conventions

This project follows the shared naming conventions in `30-shared-resources/shared-standards/NAMING_CONVENTIONS.md`.
