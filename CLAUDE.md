# CurlPlan

> Personal curling calendar, planner, game log, and ice notes.

## Project Overview

Two coexisting apps in one repo:

- **Root (`index.html`) — Hi-Fi app.** The promoted "Passport + Locker Room"
  concept: a mobile-first, self-contained single file. Screens: Passport (home),
  Locker Room (feed), Stop detail, Curler profile, Spiels, Roster. Tab + push/back
  navigation, follow/unfollow, Ice/Arena theming, deep links, offline shell.
- **Classic (`classic/`) — original planner.** Personal curling calendar, game
  logger, practice tracker, ice condition notes, and daily game planner. Six views,
  split CSS/JS assets, offline via its own service worker. Archived but still live.

## Stack

### Root Hi-Fi app
- Self-contained single-file HTML (`index.html`) — no build, no dependencies, web fonts only
- Appearance prefs persisted to localStorage under `curlplan-hifi-prefs-v1`
- Service worker (`sw.js`, cache `curlplan-hifi-v1`): network-first navigations, purges legacy caches
- Inline SVG favicon (house ring); seed data drives all screens
- XSS safety via `esc()` on all rendered content
- Verified by `scripts/verify-app.js`

### Classic app (`classic/`)
- Single HTML entry (`classic/index.html`) + split assets under `classic/assets/`
- No build step, no external dependencies
- localStorage persistence (single JSON blob under `curlplan-v1`)
- Service worker (`classic/sw.js`) for offline support
- Schema migration via `migrateRaw()` switch
- Verified by `scripts/verify-split.js`

## Key Decisions

- All six views (Today, Calendar, Games, Practice, Ice Notes, Daily Planner) coexist in one file.
- All state stored under a single localStorage key as one JSON blob.
- Modal-based CRUD for all entity types. Demo data seeds on first load.
- XSS safety enforced via `escapeHtml()` on all rendered content.
- Rink memory system links ice conditions, lineups, and planner entries across views.

## Product tag

`[CurlPlan]`

## Architecture

Root = self-contained Hi-Fi app. The sections below (Views, Key data collections)
describe the **classic** app under `classic/`.

- Single-file HTML app (`classic/index.html`)
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
| 005 | P1 | resolved | iOS SwiftUI port ships read-only: create actions unwired, no persistence | Native `ios/` port rendered seed data only; `Store.toggleFollow` was the sole mutation. RESOLVED across 3 passes (xcodebuild green each pass, runs on iPhone 17 / iOS 26.5): P1 wired New Spiel / New Result / New Curler sheets + `Store.addSpiel/addResult/addCurler` + reusable `CreateScaffold`/`CPField`/`CPChips`; P2 fixed the dead CTAs — Spiels "Details" → `SpielDetailSheet` with RSVP (`setSpielStatus`), Locker "I'm in" → working toggle, Curler "Message" → `ShareLink`, Roster + Locker search wired to live filters; P3 added `Codable` to the mutable models + `Persist`/UserDefaults round-trip so creates and follow-state survive relaunch. Deferred (feature stubs, not dead CTAs): Locker "Discover" tab, "All"/"+ All" see-all links, result social row. Tracked from status run RUN-20260621-1118. |

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
[2026-06-21] [CurlPlan] [feat] Implement Hi-Fi "Passport + Locker Room" concept as a navigable single-file app
[2026-06-21] [CurlPlan] [refactor] Promote Hi-Fi app to root; archive original planner to classic/ (history preserved)
[2026-06-21] [CurlPlan] [feat] Network-first sw.js (curlplan-hifi-v1) purges legacy v5 cache on activate
[2026-06-21] [CurlPlan] [test] Add verify-app.js for root app; retarget verify-split.js at classic/; CI runs both
[2026-06-21] [CurlPlan] [fix] SWs whitelist each other's cache (origin-wide CacheStorage); rename classic cache to curlplan-classic-v6
[2026-06-21] [CurlPlan] [fix] Repath tests/ stress harness to classic/assets; retarget how-to-guide and BRAND_BIBLE doc paths to classic/
[2026-06-21] [CurlPlan] [feat] Add native SwiftUI port under ios/ (Xcode project, 6 screens, house-ring system, Ice/Arena theming)
[2026-06-22] [CurlPlan] [feat] iOS port: wire create actions (New Spiel/Result/Curler) + Store add methods + CreateScaffold/CPField/CPChips
[2026-06-22] [CurlPlan] [fix] iOS port: fix dead CTAs — Spiels Details RSVP sheet, Locker "I'm in" toggle, Curler Message→Share, Roster+Locker search
[2026-06-22] [CurlPlan] [feat] iOS port: Codable models + UserDefaults persistence so creates and follow-state survive relaunch (resolves #005)
[2026-07-03] [CurlPlan] [feat] Add curling-clubs seed dataset (166 US clubs) from Notion for location choices
[2026-07-03] [CurlPlan] [feat] Root app: account flow (sign up / in / out via a local provider behind a Clerk-ready seam) gated in front of the app; onboarding home-club picker sourced from the clubs seed; account + change-club rows in settings
