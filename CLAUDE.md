# CurlPlan

> Personal curling calendar, planner, game log, and ice notes.

## Engineering policy

**Dependencies, build steps, backends, servers, databases, auth, and external
services are all allowed — and encouraged wherever they make the product better.**
Reach for npm packages, a bundler, an API, real-time sync, hosted services — whatever
fits the job.

There is **no "single-file / no-build / no-dependency / local-first / no-backend"
rule** here. That was an inherited root-repo artifact; it is dead and must not be
reintroduced. The app is a single static file *today* — a starting point, not a
constraint. Grow it however the roadmap needs.

## Project Overview

Two coexisting apps in one repo:

- **Root (`index.html`) — Hi-Fi app.** The promoted "Passport + Locker Room"
  concept: a mobile-first single-file app (today). Screens: Passport (home),
  Locker Room (feed), Stop detail, Curler profile, Spiels, Roster. Tab + push/back
  navigation, follow/unfollow, Ice/Arena theming, deep links, offline shell.
- **Classic (`classic/`) — original planner.** Personal curling calendar, game
  logger, practice tracker, ice condition notes, and daily game planner. Six views,
  split CSS/JS assets, offline via its own service worker. Archived but still live.

## Stack

### Root Hi-Fi app
- A single-file HTML app (`index.html`) today, web fonts only — a build step, dependencies, and a backend are all fair game
- Appearance prefs persisted to localStorage under `curlplan-hifi-prefs-v1`
- Social/log state persisted to localStorage under `curlplan-hifi-state-v1:<userId|demo>`
  (one blob per session — `storeKey()`; a legacy global `curlplan-hifi-state-v1` blob is
  migrated into the demo bucket once at boot): follows, likes, spiel registrations, user
  posts, club visits, reviews, ice reads, message threads. Seed data is the baseline; the
  store holds the user's overrides + additions (`isFollowing`/`likeCount`/`spielStatus`/
  `allPosts` derive seed + store). Posts stamp `author:"me"` + `at:Date.now()`; the store
  is rehydrated (`refreshStore()`) on every auth change. Real accounts derive Passport
  telemetry live from their own store (`derivedStats()`); demo stats stay with the demo.
- Accounts/auth under `curlplan-hifi-auth-v1` (`{users, session}`). `currentUser()` /
  `signUp` / `signIn` / `signOut` are the backend-ready seam — swap them for a real API or
  the connected Clerk instance without touching views. `render()` gates on `currentUser()`;
  `activeMe()` derives `me` (identity) from the signed-in user. A `"demo"` session maps to
  `defaultMe`. Demo passwords use a non-cryptographic hash (`hashPass`) — **not secure**,
  placeholder until real auth lands.
- Service worker (`sw.js`, cache `curlplan-hifi-v1`): network-first navigations, purges legacy caches
- Inline SVG favicon (house ring); seed data drives all screens
- XSS safety via `esc()` on all rendered content
- Verified by `scripts/verify-app.js`

### Classic app (`classic/`)
- Single HTML entry (`classic/index.html`) + split assets under `classic/assets/`
- A build step and external dependencies are welcome whenever they help
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

## Domain terminology (canonical)

Source of truth: Notion **"Curling terminology definitions"** (created 2026-06-23) —
https://app.notion.com/p/388255fc8f4480798117dbcaa1f31b0e. Use these terms exactly;
they exist to prevent naming collisions across clubs, teams, and events.

| Term | Definition (Curl-plan) | Notes |
|------|------------------------|-------|
| **Club** | The facility + the org that operates it, including members. | e.g. "Broomstones (Boston)". This is what the UI means by a venue. |
| **Team** | A competitive entry in a league/bonspiel. Always referable by **skip** name; may also carry an event nickname. | Multiple teams per club are normal. |
| **Rink** | The 4-person **lineup** (rostered unit of play). | First-class object, distinct from Team. **"Rink" is NOT the ice surface** — that's a Sheet. A team's rink can change without changing team identity. |
| **Sheet** | The physical playing surface (one "lane" of ice). | Use for facility scheduling and draw assignments. |
| **Bonspiel** | A tournament event, usually with a unique name. | Contains many team entries; multiple teams from one club allowed. |

- **Identity model:** Club ≠ Team. A team is referred to by its **skip**; its rink
  (lineup) is attached to the team and can change. A bonspiel holds many team entries.
- **Display naming** (when collisions matter): `{Club short} · {Skip}` — e.g.
  `Broomstones · Hsllo`. Disambiguate by appending `· {Season}` / `· {Event}` / `· {Team ID}`.
  Helper: `teamLabel(club, skip)` in `index.html`.
- **Migration note:** older copy used "rink" to mean the venue. The root app now uses
  **Club** for venue and reserves **Rink** for the lineup. The classic app's legacy
  "rink memory" (per-venue ice notes) predates this canon — rename when next touched.

## Single source of truth (season seed)

The demo season (curlers, stops, spiels, feed, `me`) lives in **`data/season-seed.json`**
and is the ONLY place to edit it. `scripts/gen-seed.js` regenerates both apps from it:

- `ios/CurlPlan/Seed.generated.swift` — native seed baseline (`enum Seed`)
- the marker-delimited `SEED` block inside `index.html` — web seed baseline
- `ios/CurlPlan/Clubs.generated.swift` + the `CLUBS` block in `index.html` — a shared
  club vocabulary generated from `data/curling-clubs.json` (used by the create pickers)

Workflow: edit `data/season-seed.json` (or `data/curling-clubs.json`) → run
`node scripts/gen-seed.js` → commit. **Never hand-edit the generated blocks/files.**
CI runs `node scripts/gen-seed.js --check` and fails if they're stale. This is the
mechanism that keeps the web and iOS apps from drifting — the root cause of the old gap.

`scripts/verify-parity.js` (also in CI) asserts each parity capability exists on BOTH
platforms; add a capability to one side without the other and CI fails.

## Web ⟷ iOS parity

As of 2026-07-06 the native iOS port is at **functional parity** with the web Hi-Fi app:
accounts/auth, per-account persisted state (likes, follows, joins, posts, visits, ice
reads, reviews, threads), stop contributions, messaging threads, note/result/review
compose, interactive likes, spielId-unified registration, personalized Passport with
derived stats, functional search, and create-spiel/curler — plus Following/Discover on
both. The full plan is in [docs/IMPLEMENTATION_PLAN_2026-07-06_ios-web-parity.md](docs/IMPLEMENTATION_PLAN_2026-07-06_ios-web-parity.md).
All Swift was authored on Windows and **needs a Mac Xcode compile/run pass** (the iOS CI
job does this); iOS store logic is covered by `ios/CurlPlanTests/StoreTests.swift`, which
needs a test target wired before it runs.

## Product tag

`[CurlPlan]`

## Architecture

Root = the Hi-Fi app. The sections below (Views, Key data collections)
describe the **classic** app under `classic/`.

- Single-file HTML app (`classic/index.html`)
- Build step and dependencies optional — add them when useful
- localStorage for persistence (a backend/db can replace or back it)
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
| 006 | P1 | resolved | iOS port lagged the web app by two feature passes | Closed via the 2026-07-06 parity effort (Phases 0–7). iOS rebuilt on a per-account Store with the full social/contribution layer, auth, personalized Passport; web + iOS now generated from one seed (data/season-seed.json) with a CI parity gate. Locker "Discover" is now a working Following/Discover filter on both. Remaining: Mac Xcode compile/run pass (authored on Windows); wire a test target for CurlPlanTests. |

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
[2026-06-23] [CurlPlan] [feat] Add curlplan-hifi-state-v1 persistence layer for the Hi-Fi app (follows, likes, joins, posts, visits, reviews, ice reads, threads) with seed+store derivations
[2026-06-23] [CurlPlan] [feat] Back the prototyped social actions: persistent follow graph, likes (toggle+count), bonspiel register/withdraw across Spiels + feed
[2026-06-23] [CurlPlan] [feat] Add compose flow (result/review/note) posting to the Locker Room feed via a reusable action sheet
[2026-06-23] [CurlPlan] [feat] Add stop-detail submissions — log visit, add community ice read, write review — rendered back on the stop
[2026-06-23] [CurlPlan] [feat] Add local message threads per curler (saved on device; server-backed delivery to follow)
[2026-06-23] [CurlPlan] [docs] Purge the inherited no-backend/no-dependency rule repo-wide; reverse it to an explicit pro-dependency/backend engineering policy
[2026-06-23] [CurlPlan] [docs] Add canonical Domain terminology section (Club/Team/Rink=lineup/Sheet/Bonspiel) from the Notion terminology page
[2026-06-23] [CurlPlan] [refactor] Align Hi-Fi app terms to canon: venue "rink" → Club (telemetry, profile, reviews, compose); reserve "Rink" for lineup; add teamLabel/clubShort/initialsOf
[2026-06-23] [CurlPlan] [feat] Add accounts/auth (curlplan-hifi-auth-v1): sign-up/sign-in/sign-out, demo session, auth-gated render, identity-derived me; backend-ready seam (Clerk-ready)
[2026-07-03] [CurlPlan] [fix] Scope the social store per session (curlplan-hifi-state-v1:<userId|demo>, legacy blob migrated to demo) — ends cross-account post/thread/review leaks and author:"me" re-attribution
[2026-07-03] [CurlPlan] [fix] Auth flow UX: honor boot deep links after sign-in (enterApp), preserve typed form fields across error re-renders (authDraft), carry compose body across type switches, clear stale hash on sign-out
[2026-07-03] [CurlPlan] [fix] Posts persist at:Date.now() rendered via fmtAgo (legacy time labels still honored); withdraw reverts to seed spiel status (delete override) instead of hardcoding "Watching"; feed spiel card uses a real spielById lookup
[2026-07-03] [CurlPlan] [fix] Real accounts get live derivedStats() (clubs/prov from visits, games/win from result posts) instead of Dana Mercer's demo telemetry; season eyebrow demo-gated
[2026-07-03] [CurlPlan] [fix] iOS: spiel avatars resolve curler initials via store.curler(_:) (were blank circles); align terms to canon (RINK REVIEW→CLUB REVIEW, rinks/sharedRinks→clubs/sharedClubs); extract shared StatCell into Components.swift
[2026-07-03] [CurlPlan] [refactor] Web polish pass: scroll-preserving render({keepScroll}) + in-place like toggle, sendMessage appends a bubble (no sheet rebuild), loadStore sanitization (clamped stars, array guards), postHead/postActions/starsRow/submissionCard/addStopEntry/readJSON dedup, viewAuth added to verify-app required tokens
[2026-07-03] [CurlPlan] [perf] iOS: PebbleOverlay draws one accumulated Path (was ~1k fills per redraw); RootView keeps all four tab NavigationStacks alive (opacity-switched) so pushed routes + scroll survive tab changes — needs an Xcode compile pass (authored on Windows)
[2026-07-03] [CurlPlan] [fix] Passport personalized for real accounts (isRealAccount): recent stops derive from own visits (visitedStops) with an empty state; "here now" chip + here-pin dropped; map tally reads "N STOP(S) LOGGED"/"NEW SEASON" — demo session keeps the seed map
[2026-07-06] [CurlPlan] [build] Phase 0 — single source of truth: data/season-seed.json + scripts/gen-seed.js generate both apps (Seed.generated.swift + web SEED block) and a shared club vocab (Clubs.generated.swift + CLUBS block) from data/curling-clubs.json; CI gains seed --check staleness gate, verify-parity.js, and a macOS iOS build job
[2026-07-06] [CurlPlan] [feat] Phase 1 — iOS state/data-layer rebuild: unified Post model, per-account AppState (follows/likes/joins/posts/visits/reviews/iceReads/threads) with tolerant Codable, identity/auth (SHA-256, backend-ready seam), derived stats, timestamps, spielId, legacy-blob migration, UserDefaults.defaults test seam
[2026-07-06] [CurlPlan] [feat] Phase 2 — iOS StopDetailView contributions: log visit / ice read / write review sheets + community lists, follow state routed through the store
[2026-07-06] [CurlPlan] [feat] Phase 3 — iOS interactive likes (persisted), feed spiel registration unified with the Spiels tab via spielId, relative timestamps (RelativeTime.ago)
[2026-07-06] [CurlPlan] [feat] Phase 4 — iOS compose sheet (note/result/review) replaces result-only; per-curler MessageThreadView restores Message as primary (Share kept secondary)
[2026-07-06] [CurlPlan] [feat] Phase 5 — iOS AuthView (sign in/up/demo, pw meter), auth-gated RootView, Settings account row + sign out, personalized Passport (derived stats, visited stops, empty state, demo-only map chrome)
[2026-07-06] [CurlPlan] [feat] Phase 6 — web backports: functional Locker + Roster search (focus-preserving list re-render), create-spiel/curler sheets with club datalist, Following/Discover made functional on BOTH platforms
[2026-07-06] [CurlPlan] [test] Phase 7 — scripts/verify-parity.js (12 capabilities, CI-gated), ios/CurlPlanTests/StoreTests.swift; docs refreshed (READMEs, CLAUDE.md)
