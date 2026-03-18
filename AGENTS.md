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
| 001 | P1 | open | Service worker cache not updating on edits | Version-string the cache name in sw.js |
| 002 | P2 | deferred | is-working button class triggers but does not clear | Add setTimeout clear to markWorking() |
| 003 | P1 | open | importData fails on legacy schema versions | Implement data migration switch case in DataManager |
| 004 | P2 | in-progress | Quick capture and next pass UX work remain | Planned in next pass brief, not yet implemented |

## Session Log

[2026-03-18] [CurlPlan] [docs] Add AGENTS baseline
[2026-03-18] [CurlPlan] [feat] Add dynamic issue tracker with full CRUD
[2026-03-18] [CurlPlan] [refactor] Align issue schema to ecosystem standard (P1/P2/P3, open/in-progress/resolved/deferred, 3-digit IDs)

