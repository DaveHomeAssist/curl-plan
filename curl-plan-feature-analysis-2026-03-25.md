# CurlPlan — Feature Analysis

**Date:** 2026-03-25
**Project:** curl-plan
**Stack:** Multi-file static HTML app (index.html + JS modules + CSS), localStorage persistence, service worker, no build step, no dependencies

---

## Summary Table

| Feature | Status | Data Source / Persistence | Critical Gap |
|---|---|---|---|
| 6-view tabbed app shell (Dashboard, Calendar, Planner, Games, Practice, Ice Notes) | Complete | DOM state + ARIA tabs | None |
| localStorage data persistence (single JSON blob) | Complete | `curlplan-v1` localStorage key | No cloud sync — data lives only in one browser |
| Event CRUD with modal-based workflow | Complete | localStorage, modal forms | None |
| Game logging with scores and outcomes | Complete | localStorage, modal forms | None |
| Practice session logging | Complete | localStorage, modal forms | None |
| Ice condition notes per rink | Complete | localStorage | None |
| Daily game planner (pre-game + post-game) | Complete | localStorage, planner state per date | None |
| Season stats dashboard with range filters | Complete | Computed from game log | None |
| Calendar queue with filtering and search | Complete | localStorage events, filter chips + text search | None |
| Rink memory system (v4 schema) | Complete | localStorage, rink profile cards | None |
| Bonspiel parent records | Complete | localStorage, grouped dashboard rendering | None |
| Lineup editor with preset save/load | Complete | localStorage, event-linked lineups | None |
| Planner goals and execution ratings | Complete | localStorage, collapsible planner sections | None |
| Pre-game checklist with custom items | Complete | localStorage, add/reset UI | None |
| Dark/light theme ("Broadcast Classic" / "Arena Night") | Complete | CSS custom properties, localStorage prefs | None |
| Service worker caching | Complete | sw.js, cache-first for precached assets | None |
| Export/import JSON | Complete | File download / file input | None |
| Demo data seeding | Complete | Seeds on first load or reset | None |
| Keyboard shortcuts | Complete | Modal with shortcut help | None |
| Issue tracker (in-app) | Complete | localStorage, full CRUD | None |
| SVG icon system | Complete | Inline `<symbol>` definitions, `<use>` references | None |
| Design token system | Complete | theme.css shared tokens + app.css component styles | None |
| Accessibility (skip link, ARIA tabs/roles, focus-visible, live regions) | Complete | Native HTML/ARIA | None |
| Responsive layout | Complete | CSS grid/flex, media queries | None |

---

## Detailed Feature Analysis

### 1. Six-View Tabbed Application Shell

**Problem it solves:** Organizes a curler's entire season workflow — scheduling, game prep, logging, analysis, and rink knowledge — in one local-first tool.

**Implementation:** Navigation tabs (`#navTabs`, index.html line ~114-121) use `role="tablist"` with individual `role="tab"` buttons controlling `role="tabpanel"` view sections. Tab switching toggles `.is-active` class. Views include Dashboard (stats grid, upcoming sheet, planner snapshot, recent results, latest ice read), Calendar (filter bar, event feed, selected event detail), Game Planner (pre-game/post-game two-card layout), Game Log, Practice, and Ice Notes. A view context strip and suggested-next strip provide contextual guidance.

**Tradeoffs:** All views exist in the DOM simultaneously — only visibility is toggled. This simplifies state management but means the initial HTML payload is large. No URL-based routing, so refreshing always returns to the Dashboard.

---

### 2. Comprehensive Data Persistence

**Problem it solves:** Keeps all curling data locally without requiring an account, server, or internet connection.

**Implementation:** All data (events, games, practice sessions, ice notes, planner state, lineups, bonspiels, issues) shares a single localStorage key (`curlplan-v1`) as one JSON blob. The data layer includes schema migration (`migrateRaw()`) for upgrading between versions (currently at v4 with rink memory). Export downloads the blob as a JSON file. Import reads a JSON file and normalizes via `migrateRaw()` before loading. Demo data seeds on first load or manual reset.

**Tradeoffs:** Single-browser, single-device storage. No sync across devices. localStorage has a ~5-10MB limit depending on browser. A heavy season of data could approach this limit. No incremental backup — export is manual and all-or-nothing.

---

### 3. Daily Game Planner

**Problem it solves:** Provides a structured pre-game and post-game workflow so the curler captures preparation, goals, and reflection in one place.

**Implementation:** Two-card layout (index.html lines ~305-430): Pre-Game card has start time, rink, position select (Lead/Second/Third/Skip), opponent, collapsible shot goals (3 targets), collapsible pre-game checklist with custom items and reset-to-defaults, and ice notes textarea. Post-Game card has score inputs (ours/theirs), key shot input, collapsible execution ratings (draw weight, takeout, sweeping, line calling, strategy — each rated 1-5), and general notes. A save button persists planner state per date. Navigation arrows step through dates.

**Tradeoffs:** The planner is date-indexed, meaning only one planner entry per day. If a curler has two games in one day (common in bonspiels), the second game overwrites the first planner entry. The execution ratings are 1-5 scales with no guidance on what each number means.

---

### 4. Rink Memory System

**Problem it solves:** Builds a persistent knowledge base about specific rinks — ice speed, curl patterns, and quirks — that surfaces when the curler returns to that venue.

**Implementation:** Schema v4 introduced rink memory (per CLAUDE.md session log). Rink profile cards surface across the dashboard, planner, and event detail views. When a rink is entered in the planner or event form, matching rink memory data is retrieved and displayed as a compact profile card. Ice notes accumulate per rink over time.

**Tradeoffs:** Rink matching appears to be by name string, meaning "Curl Burlington" and "Burlington Curling Club" would be treated as different rinks. No fuzzy matching or alias system.

---

### 5. Season Stats Dashboard

**Problem it solves:** Gives the curler performance analytics computed automatically from their game log, without manual data entry.

**Implementation:** The dashboard (index.html lines ~129-173) shows a stat grid (games logged, wins logged, upcoming events) with clickable cards that route to relevant views. A season stats section computes aggregated metrics with range filters — "This Season" (calendar year), "All Time", and "Last 10" games. Stats are rendered into `#seasonStatsGrid` as insight cards.

**Tradeoffs:** Stats depend entirely on what the user logs. If games are logged inconsistently (missing scores, missing opponents), the stats will be incomplete. There is no validation enforcing complete game records.

---

### 6. Design Token System

**Problem it solves:** Maintains visual consistency across two themes and positions the design system for reuse (shared with a planned "Curling Simulator" per the theme.css header).

**Implementation:** `theme.css` (363 lines) defines shared tokens — colors (bg, surface, text, primary, secondary, accent, highlight, granite tones, semantic states), radii, shadows, type scale, timing, and font stacks (Syne display, Instrument Serif, DM Mono). Dark theme (`[data-theme="dark"]`) overrides all color tokens. Base reset, buttons, cards, section labels, form inputs, badges, and utility classes are defined here. `app.css` (2234 lines) builds on these tokens for app-specific components. An ice grain texture overlay (`body::before`) adds subtle texture.

**Tradeoffs:** The token system references fonts (Syne, Instrument Serif, DM Mono) but no `@import` or `<link>` for these fonts appears in index.html — they may be loaded elsewhere or missing. The theme toggle is labeled "Arena Night" which is domain-specific and charming but could confuse users expecting "Dark Mode."

---

### 7. Bonspiel Management

**Problem it solves:** Handles multi-day curling tournaments (bonspiels) as parent records that group related events, with travel roster and budget fields.

**Implementation:** Bonspiel records are created as a parent entity type with linked child events (draws/games). The dashboard renders grouped bonspiel sections showing the tournament schedule. Calendar view provides draw context for bonspiel-linked events. Travel roster and budget fields support tournament logistics planning.

**Tradeoffs:** Bonspiel workflow was recently added (per session log 2026-03-19) and may not be fully battle-tested. The relationship between bonspiel parent records and child events depends on correct linking at creation time.

---

### 8. In-App Issue Tracker

**Problem it solves:** Tracks UI bugs and feature requests inside the app itself, following the ecosystem-standard schema (P1/P2/P3, open/in-progress/resolved/deferred).

**Implementation:** A full CRUD issue tracker accessible from the settings menu ("UI Issues" item). Issues have severity (P1/P2/P3), status (open/in-progress/resolved/deferred), 3-digit IDs, title, and notes. Data persists in the same localStorage blob.

**Tradeoffs:** The issue tracker is user-facing but uses developer-oriented terminology (P1/P2/P3 severity). It's primarily useful for the developer (Dave) rather than end users. Issues stored in localStorage are lost if the user clears browser data.

---

## Top 3 Priorities

1. **Add URL hash routing so views survive page refresh.** Currently, refreshing always returns to the Dashboard. Adding `#/calendar`, `#/planner`, etc. to the URL would preserve the user's current view and enable direct linking.

2. **Implement rink name normalization or an alias system.** The rink memory feature's value depends on matching rink names consistently. A simple normalization (lowercase, trim, strip common suffixes like "Curling Club") or an alias table would prevent duplicate rink profiles.

3. **Add a cloud sync or file-based sync option.** The app is local-first by design ("Yours. Local. No cloud."), but data loss from browser clearing or device switching is the biggest risk. Even a manual "sync to file" on a cloud drive (Dropbox, iCloud) would mitigate this without compromising the local-first philosophy.
