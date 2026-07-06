# CurlPlan — iOS ↔ Web Parity: Root Analysis & Implementation Plan

**Date:** 2026-07-06
**Author:** engineering pass
**Status:** proposed
**Goal:** Bring the native iOS app to full functional parity with the web Hi-Fi app,
fix the underlying reason the two drifted, and put guardrails in place so they can
never silently diverge again — patching where a patch suffices, rebuilding the parts
that structurally can't get there by patching.

Baseline: `origin/main` @ `fb385cd` (local in sync). Companion doc:
this supersedes the ad-hoc gap notes and is the source of truth for the parity effort.

---

## 0. TL;DR

- **Not a full rewrite.** The iOS view layer is a faithful, well-built port. The
  *state/data layer* is what's missing and structurally under-built — so we **rebuild
  the iOS `Store` + models + persistence + identity**, and **patch the views** to use them.
- **Root cause is duplicated hand-maintained seed data** with no shared contract and
  no cross-platform test. Fix that first (shared JSON seed → generated Swift + JS) or
  every parity fix we make will rot again.
- **Sequence:** foundation & guardrails → iOS state-layer rebuild → feature parity by
  screen → auth/personalization → backport iOS's own wins to web → hardening.
- **Hard constraint:** all Swift work must be compiled/run on a Mac (Xcode 15.4+). The
  repo's most recent iOS commit was authored on Windows and has **never been compiled**;
  Phase 0 establishes a green baseline before anything is layered on top.

---

## 1. Root-cause analysis

The symptom is a long feature gap (see §3 matrix). The *causes* are structural — fix
these, not just the symptoms.

### 1.1 No single source of truth for domain data — **primary root cause**
The season seed (curlers, stops, spiels, feed) exists as **two independent hand-typed
copies**:
- Web: JS object literals in [`index.html`](../index.html) lines ~506–585.
- iOS: Swift `enum Seed` literals in [`Models.swift`](../ios/CurlPlan/Models.swift) lines ~203–287.

They happen to match today only because someone transcribed them carefully once. There
is no contract, no generator, no diff check — so any edit to one is invisible to the
other. This is *the* mechanism of drift and must be removed, not managed.

Compounding it: [`data/curling-clubs.json`](../data/curling-clubs.json) — a versioned,
`$schema`-tagged, 166-club dataset built for exactly this purpose — is **imported by
neither app** (grep: zero references). The foundation for a shared seed already exists
and is sitting unused.

### 1.2 The web app took two passes the iOS port never received
iOS was branched at ~June 22. The web app then landed:
- **June 23:** persistent social layer (`curlplan-hifi-state-v1`), backed follow/like/
  join, compose sheet (note/result/review), stop-detail submissions, local message
  threads, **accounts/auth**, Club/Rink terminology canon.
- **July 3:** per-account state scoping, auth-flow UX, live `derivedStats()`, personalized
  Passport for real accounts.

None of this was ported. So the gap isn't random — it's "everything after the branch point."

### 1.3 iOS data model is structurally too thin to reach parity by patching
- `Store` persists only `curlers/spiels/feed` ([Models.swift:118-129](../ios/CurlPlan/Models.swift#L118)).
  There are **no buckets** for likes, visits, reviews, ice reads, or threads — the web
  store has all of them ([index.html:615-627](../index.html#L615)).
- `SpielPost` has **no `spielId`** linking a feed card back to a `Spiel`
  ([Models.swift:57-61](../ios/CurlPlan/Models.swift#L57)); web does the linkage via
  `spielById(p.spielId)` ([index.html:1038](../index.html#L1038)). This is why the iOS
  feed "I'm in" button is a throwaway `@State` toggle disconnected from the Spiels tab.
- `Me` is a constant struct ([Models.swift:131-139](../ios/CurlPlan/Models.swift#L131));
  there is no identity/account concept at all, so a "real personalized account" cannot be
  expressed. → This is why §4 treats the model/store as a **rebuild**, not a patch.

### 1.4 No cross-platform parity gate
Verification is web-only (`scripts/verify-app.js`, `verify-split.js`) and iOS has **no
tests, no CI, no compile check**. Nothing anywhere asserts "iOS covers the same feature
set as web." Divergence had no tripwire.

### 1.5 Build & authoring friction
- The last iOS commit (`0c86150`, PebbleOverlay + always-alive tab stacks) was authored
  on Windows and, per CLAUDE.md, **needs an Xcode compile pass** — i.e. `main` may not
  even build clean on iOS today.
- `project.pbxproj` is codegen'd by `generate-xcodeproj.js`; every new Swift file must be
  followed by `node generate-xcodeproj.js`. Easy to forget → "file not in target" errors.

### 1.6 Summary
The fixable root is: **one hand-copied seed, no shared contract, a too-thin iOS store,
and no parity gate.** Everything in §4 Phase 0–1 targets those directly; the later phases
are then straightforward feature ports on a sound base.

---

## 2. Strategic decision — patch vs. rebuild

**Decision: hybrid — rebuild the iOS state/data foundation, patch the iOS views, and
introduce a shared seed contract. Do NOT rewrite either app wholesale.**

| Option | Verdict | Why |
|---|---|---|
| **Full rewrite of iOS** | ✗ Rejected | The 12 SwiftUI views are faithful, idiomatic, and already ahead of web on search + create sheets. Throwing them away destroys real value and re-introduces risk for zero design gain. |
| **Pure patching (no model changes)** | ✗ Rejected | Impossible: no store buckets for visits/reviews/threads/likes, no identity model, no spiel linkage. You cannot patch features onto a model that can't represent them. |
| **Rebuild state layer + patch views + shared seed** | ✓ **Chosen** | Keeps the good (views/design), replaces the weak (store/models/persistence), and removes the drift mechanism (dual seed). Incremental, testable, reversible per phase. |
| **Unify to one codebase (e.g. drop native, wrap web)** | ✗ Out of scope now | A product/strategy call, not an engineering one. Note it as a future option in §6; this plan assumes both apps stay. |

---

## 3. Target state (what "done" means)

Full parity matrix — every 🔴/🟠 becomes ✅, iOS's 🔵 wins get backported to web,
and both apps read one seed.

| Capability | Web today | iOS today | Target |
|---|---|---|---|
| 6 screens, tab nav, theming | ✅ | ✅ | ✅ (unchanged) |
| Shared seed contract | ✗ (JS literals) | ✗ (Swift literals) | ✅ one JSON → generated both sides |
| Accounts & auth, sign out | ✅ | ✗ | ✅ iOS gains local-first auth + seam |
| Per-account persisted state | ✅ | ✗ | ✅ iOS store keyed per identity |
| Personalized Passport + derived stats | ✅ | ✗ | ✅ |
| Stop contributions (visit/ice read/review) + lists | ✅ | ✗ | ✅ |
| Messaging threads | ✅ | ✗ (ShareLink) | ✅ threads; keep Share as secondary |
| Compose note/result/review | ✅ | ⚠️ result only | ✅ all three |
| Interactive likes, persisted | ✅ | ✗ static | ✅ |
| Spiel register/withdraw unified feed↔list | ✅ | ⚠️ split-brain | ✅ via `spielId` |
| Relative timestamps | ✅ | ✗ static | ✅ shared idiom |
| Functional search (Locker + Roster) | ✗ decorative | ✅ | ✅ **backport to web** |
| Create spiel / curler | ✗ inert "+" | ✅ | ✅ **backport to web** |
| Discover tab, "+All" see-all | stub | stub | ✅ implement or remove on both |
| Cross-platform parity gate | ✗ | ✗ | ✅ CI: web verify + iOS build + parity checklist |

---

## 4. Phased implementation plan

Each phase is independently shippable and leaves both apps in a working state. Phases
1–5 are iOS-focused (require Mac compile); Phase 6 is web; Phase 0 and 7 are cross-cutting.

> **Every phase that adds/removes a Swift file ends with `node ios/generate-xcodeproj.js`
> + an Xcode compile + a simulator smoke run.** This is a standing exit criterion, not
> repeated per task.

### Phase 0 — Foundation & guardrails (do first, no features)
Goal: a known-green baseline + the shared-seed mechanism + a parity tripwire.

Tasks:
1. **Compile baseline.** On a Mac, open `ios/CurlPlan.xcodeproj`, build the CurlPlan
   scheme, run on iPhone 17 / iOS 26.x sim. Fix whatever the Windows-authored commit
   broke. Commit `fix(ios): restore green build baseline`. *(Nothing below starts until this passes.)*
2. **Shared seed contract.** Promote the season seed to a versioned JSON file
   `data/season-seed.json` (curlers, stops, spiels, feed) with a `$schema` tag, mirroring
   the `curling-clubs.json` convention.
3. **Codegen both sides from the seed.**
   - `scripts/gen-seed.js` reads `data/season-seed.json` and emits:
     - `ios/CurlPlan/Seed.generated.swift` (replaces the literals in `Models.swift`).
     - a JS module / inline block the web build consumes (replace literals in `index.html`,
       or emit `assets/season-seed.generated.js`).
   - Add `// GENERATED — do not edit` headers.
4. **Parity gate in CI.** Extend `.github/workflows/`:
   - keep web `verify-app.js` / `verify-split.js`;
   - add a macOS job: `xcodebuild -scheme CurlPlan build` (and `test` once Phase 7 lands);
   - add `scripts/verify-parity.js` — a checklist asserting matching capability tokens
     exist in both `index.html` and the Swift sources (e.g. both define a review-compose
     path, a visits store, etc.). Start as a maintained checklist; tighten over time.
5. **Wire `curling-clubs.json`** into at least one real picker (club selection in the
   iOS `NewCurlerSheet` / web signup) so the orphaned asset earns its place and both
   apps share the club vocabulary.

Acceptance: iOS builds green on `main`; editing `data/season-seed.json` + running
`gen-seed.js` changes both apps identically; CI runs web verify + iOS build.

### Phase 1 — iOS state/data-layer rebuild (the core)
Goal: an iOS `Store` that can *represent* everything web can, persisted, per-identity.
No new UI yet — existing views keep working against the richer store.

Tasks:
1. **Expand the persisted store** to mirror the web buckets. New `Codable` state:
   `follows`, `likes`, `joins`, `posts`, `visits`, `reviews`, `iceReads`, `threads`
   (parallel to [index.html:615-627](../index.html#L615)). Keep seed as baseline; store
   holds overrides + additions (same derivation model as web:
   `isFollowing`/`likeCount`/`spielStatus`/`allPosts`).
2. **Identity model.** Introduce `Account`/`Session` and an `Identity` store (local-first,
   Codable), mirroring `curlplan-hifi-auth-v1`. Add a `demo` session. Persistence key is
   **scoped by identity** (`cp.state.v2:<userId|demo>`), matching web's per-session blob.
3. **Model fixes:**
   - Add `spielId: String?` to `SpielPost`; feed spiel cards resolve to a real `Spiel`.
   - Give posts a real timestamp (`at: Date`) + a `fmtAgo`-equivalent formatter.
   - Make `Me`/telemetry **derivable** (`derivedStats()` from visits/result-posts) instead
     of constants, gated on real-vs-demo account.
4. **Migration.** One-time migrate the existing global `cp.curlers/spiels/feed.v1` blobs
   into the `demo` bucket (mirror `migrateLegacyStore()`), then read v2 going forward.
5. **Sanitization** on load (clamp stars, array guards) mirroring `sanitizeStore()`.

Acceptance: existing screens render unchanged; unit tests (Phase 7 harness, stubbed here)
prove derivations match web semantics; relaunch preserves state per identity.

### Phase 2 — Stop contributions (biggest single-screen gap)
Port web's stop-detail submission system to `StopDetailView`.

Tasks:
1. Add the **add-row** ("Log visit" / "Ice read" / "Write review") to
   [`StopDetailView`](../ios/CurlPlan/StopDetailView.swift).
2. Three create sheets reusing `CreateScaffold`/`CPField`/`CPChips`, writing to
   `store.visits/iceReads/reviews[stopID]`.
3. Render **community lists** back on the stop ("Community ice reads", "Your visits",
   "Reviews"), mirroring `submissionCard()` ([index.html:855](../index.html#L855)) with
   empty states.
4. Star picker component for reviews (parity with web `starPicker`).

Acceptance: log each type on a stop, background the app, relaunch → entries persist and
render; matches web copy/behavior.

### Phase 3 — Interactive social + consistency fixes (small, high-value)
Tasks:
1. **Interactive likes.** Make `ResultCard`'s heart a `Button` toggling `store.likes`,
   showing `likeCount` — replace the static `Label` at
   [LockerRoomView.swift:189](../ios/CurlPlan/LockerRoomView.swift#L189).
2. **Unify spiel registration.** Feed `SpielCard` reads/writes `store.setSpielStatus` via
   the new `spielId` (delete the local `@State joined` at
   [LockerRoomView.swift:206](../ios/CurlPlan/LockerRoomView.swift#L206)); Spiels tab and
   feed now reflect one another. Add withdraw semantics (`withdrawSpiel` parity).
3. **Timestamps.** Swap static `time` strings for `at`-based relative labels.

Acceptance: like/unlike persists and survives relaunch; registering in the feed updates
the Spiels tab and vice-versa; new posts show "NOW" then age.

### Phase 4 — Full compose + messaging
Tasks:
1. **Compose note/result/review.** Generalize `NewResultSheet` into a segmented composer
   (Note / Result / Review) matching `openCompose` ([index.html:1375](../index.html#L1375)),
   writing typed posts to `store.posts`. New file `ComposeSheet.swift` (→ regen pbxproj).
2. **Messaging threads.** New `MessageThreadView.swift`: per-curler local thread
   (bubbles, composer, persistence to `store.threads`), mirroring `openThread`/`sendMessage`
   ([index.html:1475](../index.html#L1475)). Keep the existing `ShareLink` as a secondary
   action, not the primary — restore "Message" as primary on
   [CurlerProfileView.swift:80](../ios/CurlPlan/CurlerProfileView.swift#L80).

Acceptance: post all three types from the phone; message a curler, relaunch → thread
persists.

### Phase 5 — Auth & personalized Passport (largest, do once base is proven)
Tasks:
1. **Auth UI** (`AuthView.swift`): sign in / sign up / "explore demo", validation, and a
   sign-out row in `SettingsSheet`. Local-first with the **same backend-ready seam** the
   web documents (swappable for a real API / the connected Clerk instance) — do not ship
   the djb2 pseudo-hash to production; use Keychain + a proper local hash or defer real
   auth to the backend seam.
2. **Gate the app** on session (mirror web `render()` gating on `currentUser()`); route to
   `AuthView` when signed out.
3. **Personalized Passport:** real accounts get `visitedStops`, derived telemetry, empty
   states, "N STOPS LOGGED" tally, and drop the demo "here now" chip / "2,400 KM" literal
   in `SeasonMap` ([PassportView.swift:166](../ios/CurlPlan/PassportView.swift#L166)).
   Demo session keeps the seed chrome (parity with web `isRealAccount()` branching).

Acceptance: sign up → empty personalized season; log visits/results → telemetry and map
tally update live; sign out returns to demo/seed; two accounts don't leak state.

### Phase 6 — Backport iOS's wins to web + finish stubs (convergence)
So parity is symmetric and the apps *converge*, not just iOS catching up.

Tasks:
1. **Web functional search** in Locker Room and Roster (the `⌕` icons at
   [index.html:1065](../index.html#L1065)/[1120](../index.html#L1120) are currently inert)
   — port the filter logic iOS already has.
2. **Web create sheets** for spiel and curler (the "+" headers are inert) — reuse the
   compose/sheet infra.
3. **Resolve the shared stubs on both:** either implement the Locker **Discover** tab and
   "+All"/"All" see-all links, or remove them so neither app ships dead affordances.

Acceptance: `verify-parity.js` checklist is fully green; the §3 matrix has no ✗/⚠️.

### Phase 7 — Hardening, tests, docs
Tasks:
1. **iOS unit tests** (XCTest): store derivations, persistence round-trip, migration,
   per-identity isolation, spiel-status unification. Wire `xcodebuild test` into CI.
2. **Extend web verify** to assert the new capability tokens (search handlers, create
   flows, discover resolution).
3. **Docs:** update `ios/README.md`, `README.md`, and `CLAUDE.md` (retire the "deferred
   iOS items", record the shared-seed workflow); add a session-log block per pass.
4. **Terminology sweep:** ensure Club/Team/Rink(=lineup)/Sheet/Bonspiel canon holds across
   the new iOS surfaces (it already partially does — RINK→CLUB review was aligned July 3).

Acceptance: CI green (web verify + iOS build + iOS test + parity); docs current;
CLAUDE.md issue tracker reflects reality.

---

## 5. Cross-cutting: testing & verification

- **Every Swift change:** `node ios/generate-xcodeproj.js` → Xcode build → simulator smoke.
- **Behavioral parity:** for each ported feature, drive the real flow on device
  (per the repo's `verify` discipline) — persist, background, relaunch, assert.
- **Regression tripwire:** `scripts/verify-parity.js` in CI fails the build if a capability
  exists on one platform and not the other.
- **Data integrity:** `gen-seed.js` is the only way to edit seed; a CI check fails if the
  generated files are stale vs `data/season-seed.json` (`git diff --exit-code` after regen).

---

## 6. Risks, constraints, sequencing

- **Mac dependency (hard):** Phases 0–5, 7 require Xcode. This machine is Windows — Swift
  changes can be *authored* here but MUST be compiled/run on a Mac before merge. Do not
  merge un-compiled Swift (that's how the current baseline got into doubt).
- **pbxproj codegen:** forget `generate-xcodeproj.js` → "file not in target." Standing
  checklist item.
- **Auth security:** local-first is fine for the demo, but don't promote djb2 hashing to a
  real product; the plan routes real auth through the documented backend seam.
- **Scope creep toward a backend:** the engineering policy *allows* a backend, but this
  plan stays local-first with a seam. Adding real sync is a follow-on, not in this plan.
- **Effort (rough, Mac-time):** P0 ≈ 1–2 days · P1 ≈ 2–3 · P2 ≈ 1–2 · P3 ≈ 1 · P4 ≈ 2 ·
  P5 ≈ 2–3 · P6 ≈ 1–2 · P7 ≈ 1–2. Total ≈ 2–3 focused weeks. Ship phase-by-phase.
- **Future option (noted, not chosen):** if maintaining two hand-written UIs proves costly,
  revisit consolidating to one codebase. Out of scope here.

---

## 7. Immediate next actions

1. **On a Mac:** compile `main`, fix the Windows-authored breakage, land the green baseline
   (Phase 0.1). Nothing else starts first.
2. Author `data/season-seed.json` + `scripts/gen-seed.js`; regenerate both apps from it and
   confirm byte-for-byte no behavior change (Phase 0.2–0.3).
3. Stand up the CI parity gate (Phase 0.4).
4. Begin the iOS store/identity rebuild (Phase 1).

Progress is tracked by checking each phase's acceptance criteria; update the CLAUDE.md
issue tracker + session log as phases land.
