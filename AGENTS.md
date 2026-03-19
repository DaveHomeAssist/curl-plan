# AGENTS.md

Inherits root rules from `/Users/daverobertson/Desktop/Code/AGENTS.md`.

## Project Overview

CurlPlan is a local first curling operations tracker for planning games, logging results, tracking practice sessions, and recording ice reads in one static browser app.

## Stack

- Single file HTML, CSS, and JavaScript app
- Local storage persistence
- JSON import and export
- GitHub Pages style static hosting

## Key Decisions

- Keep the app self contained and static for easy deploy and portability
- Use one canonical local storage schema with migration rather than scattered keys
- Favor safe rendering and delegated event wiring over inline handlers

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
