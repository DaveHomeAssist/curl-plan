# CurlPlan

> Personal curling calendar, planner, game log, and ice notes.

## Project Overview

Personal curling calendar, game logger, practice tracker, ice condition notes, and daily game planner. Six view types in a single-file app with offline support via service worker.

## Stack

- Single-file HTML app (`index.html`)
- No build step, no external dependencies
- localStorage persistence (single JSON blob under `curlplan-v1`)
- Service worker (`sw.js`) for offline support
- Schema migration via `migrateRaw()` switch

## Key Decisions

- All six views (Today, Calendar, Games, Practice, Ice Notes, Daily Planner) coexist in one file.
- All state stored under a single localStorage key as one JSON blob.
- Modal-based CRUD for all entity types. Demo data seeds on first load.
- XSS safety enforced via `escapeHtml()` on all rendered content.
- Rink memory system links ice conditions, lineups, and planner entries across views.

## Product tag

`[CurlPlan]`

## Architecture

- Single-file HTML app (`index.html`)
- No build step, no dependencies
- localStorage for persistence
- Export/import via JSON

## Logging tier

**Medium app** — use inline `createLogger('[CurlPlan]')` helper when logging is needed.

## Key data collections

| Collection | Storage key      | Purpose                        |
| ---------- | ---------------- | ------------------------------ |
| events     | `curlplan-v1`    | Calendar events (all types)    |
| games      | `curlplan-v1`    | Game logs with shot % tracking |
| practice   | `curlplan-v1`    | Practice session logs          |
| notes      | `curlplan-v1`    | Ice condition notes per rink   |
| planner    | `curlplan-v1`    | Daily game planner state       |

All collections share one localStorage key as a single JSON blob.

## Views

1. **Today** — dashboard with stats, next event, planner snapshot, timeline, latest notes
2. **Calendar** — event queue, month snapshot (placeholder), event detail
3. **Games** — game log + performance stats
4. **Practice** — session log + drill focus summary
5. **Ice Notes** — rink condition log + rink memory
6. **Daily Planner** — pre-game planning and post-game reflection

## Conventions

- All HTML rendering uses `escapeHtml()` for XSS safety
- Modal-based CRUD for all entity types
- Demo data seeds on first load or reset
- Filter + search available on calendar view

## Documentation Maintenance

- **Issues**: Track in CLAUDE.md issue tracker table below. When project gets a `docs/UI_ISSUES_TABLE.html`, migrate there.
- **Session log**: Append to `/Users/daverobertson/Desktop/Code/95-docs-personal/today.csv` after each meaningful change

## Issue Tracker

| ID | Severity | Status | Title | Notes |
|----|----------|--------|-------|-------|
| 001 | P1 | resolved | Service worker cache not updating on edits | Created sw.js with CACHE_NAME curlplan-sw-v4; registered in bootstrap.js |
| 002 | P2 | deferred | is-working button class triggers but does not clear | Add setTimeout clear to markWorking() |
| 003 | P1 | resolved | importData fails on legacy schema versions | Added migrateRaw() switch in core.js; called in importData before normalizeState |
| 004 | P2 | resolved | Quick capture and next pass UX work remain | Planner prep, lineup, and bonspiel workflows are now live |

## Session Log

[2026-03-18] [CurlPlan] [docs] Add AGENTS baseline
[2026-03-18] [CurlPlan] [feat] Add dynamic issue tracker with full CRUD
[2026-03-18] [CurlPlan] [refactor] Align issue schema to ecosystem standard (P1/P2/P3, open/in-progress/resolved/deferred, 3-digit IDs)
[2026-03-18] [CurlPlan] [refactor] Elevate visual system with serif token, house ornament, and surface tiers
[2026-03-18] [CurlPlan] [feat] Replace emoji empty states with inline SVG icon set
[2026-03-18] [CurlPlan] [refactor] Reduce secondary hover lift and add local ownership brand line
[2026-03-18] [CurlPlan] [feat] Add schema v4 rink memory foundation with planner record migration
[2026-03-18] [CurlPlan] [feat] Surface compact rink profile cards across dashboard planner and event detail
[2026-03-18] [CurlPlan] [feat] Add structured planner goals and post game review ratings
[2026-03-18] [CurlPlan] [refactor] Link planner summaries and report output to review status
[2026-03-18] [CurlPlan] [feat] Add event linked lineup editor with preset save and load
[2026-03-18] [CurlPlan] [refactor] Carry lineup links into game saves and printed reports
[2026-03-19] [CurlPlan] [feat] Add bonspiel parent records with travel roster and budget fields
[2026-03-19] [CurlPlan] [feat] Render grouped bonspiel dashboards and linked draw context in calendar
