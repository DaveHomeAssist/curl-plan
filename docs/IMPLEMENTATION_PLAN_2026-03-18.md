# CurlPlan — UX Audit Implementation Plan

> **Source:** UX_AUDIT_2026-03-18.md (15 findings: 4 critical, 6 high, 5 medium)
> **Architecture:** Split-file vanilla JS (index.html + app.css + core.js + render.js + actions.js + bootstrap.js + utils.js)
> **Constraint:** No dependencies, no build step, localStorage persistence

---

## Batch Overview

| Batch | Type | Findings Covered | Files | Model |
|-------|------|-----------------|-------|-------|
| A | Data safety & guards | S1-1, S1-2, S2-6, S2-7, S2-8 | actions.js, core.js, bootstrap.js, utils.js | Claude |
| B | Feedback & status | S1-4, S2-5, S3-11, S3-12 | render.js, actions.js, utils.js, app.css | Codex |
| C | Flow bridges & linking | S1-3, S2-10 | render.js, actions.js, bootstrap.js, index.html | Claude |
| D | Accessibility & polish | S2-9, S3-13, S3-14, S3-15 | app.css, index.html, core.js | Codex |

---

## Batch A — Data Safety & Guards

**Findings addressed:**
- S1-1: No unsaved-changes guard on modal close
- S1-2: Calendar/search filter state lost on view switch
- S2-6: Import preview shows counts only, not validation errors
- S2-7: Game modal allows partial score entry
- S2-8: No export timestamp display

### A1. Unsaved-changes guard on modal close (S1-1)

**Problem:** Closing a modal with edits doesn't warn. Data lost silently.

**Implementation:**
1. In `actions.js`, add a `_modalDirty` flag set to `true` on any input `change`/`input` event inside an open modal
2. In `closeModal()` (actions.js:174-177), check `_modalDirty`. If true and modal has user input, show `confirm('Discard unsaved changes?')` before closing
3. Reset `_modalDirty = false` on modal open and after successful save
4. Wire input listeners in `openModal()` to set dirty flag

**Files:** actions.js (closeModal, openModal)

### A2. Persist filter state across view switches (S1-2)

**Problem:** Calendar filter resets to "All" on every view switch.

**Implementation:**
1. In `core.js`, extend `saveUiPrefs()` / `loadUiPrefs()` to include `calendarFilter`, `gameSort`, `practiceSort`, `iceSort`
2. In `bootstrap.js:32` where filter state is initialized, read from UI prefs instead of hardcoded defaults
3. In each filter/sort change handler, call `saveUiPrefs()` after updating state
4. On view switch in `switchView()`, restore filters from prefs instead of resetting

**Files:** core.js (saveUiPrefs, loadUiPrefs), bootstrap.js (init, switchView), actions.js (filter handlers)

### A3. Richer import preview with validation (S2-6)

**Problem:** Import preview shows "5 events, 3 games" but not whether fields are valid.

**Implementation:**
1. In `actions.js:458-482`, after counting records, run `normalizeState(parsed, {strict: true})` in a try/catch
2. Collect per-collection validation warnings: missing required fields, unrecognized keys, legacy format detected
3. Render warnings in the preview modal as a list below the counts: `⚠ 2 events missing date field` etc.
4. If strict mode throws, show error banner in preview: "This file may not be a valid CurlPlan export"
5. Keep the Confirm button but add a visual warning state

**Files:** actions.js (import preview rendering), core.js (normalizeState strict mode errors)

### A4. Score entry validation (S2-7)

**Problem:** Game modal allows "7" vs "" (empty) — inconsistent between number 0 and empty string.

**Implementation:**
1. In `actions.js:255-260` (game save), normalize scores: empty string → `null`, "0" → `0`, non-numeric → `null`
2. In `normalizeGame()` in `core.js:228-246`, ensure `us` and `them` are either `number` or `null`, never empty string
3. Auto-compute `result` only when both scores are non-null numbers
4. In render, show "—" for null scores instead of empty

**Files:** actions.js (game save), core.js (normalizeGame)

### A5. Export timestamp display (S2-8)

**Problem:** No indication of when last export was.

**Implementation:**
1. In `core.js`, add `lastExportAt` to UI prefs schema
2. In `actions.js:393-403` (export handler), after download triggers, write `lastExportAt: new Date().toISOString()` to UI prefs
3. In `render.js`, update the Export button label or add a subtitle: "Export (last: 2d ago)" using relative time formatting from `utils.js`
4. If never exported, show "Export (never)"

**Files:** core.js (UI prefs), actions.js (export handler), render.js (button label)

---

## Batch B — Feedback & Status

**Findings addressed:**
- S1-4: Planner auto-save is completely silent
- S2-5: Season stats grid renders empty containers when no data
- S3-11: Checklist has no completion progress indicator
- S3-12: Modal title doesn't always match action

### B1. Planner save indicator (S1-4)

**Problem:** 500ms debounced auto-save gives zero visual confirmation.

**Implementation:**
1. In `app.css`, add `.planner-save-status` styles: small text below planner header, transitions opacity
2. In `render.js` (planner view), add a `<span id="plannerSaveStatus">` element
3. In `actions.js:696-698` (planner save), after `saveState()`, set text to "Saved" with green tone, fade after 1.5s
4. Use existing `setStatus()` or a lighter inline approach

**Files:** app.css (new class), render.js (planner render), actions.js (save callback)

### B2. Hide empty stat cards (S2-5)

**Problem:** Four empty insight cards with "No games in this range" take visual space.

**Implementation:**
1. In `render.js:11-14` (season stats grid render), check if games array for selected range is empty
2. If empty, render a single empty-state card instead of the full grid: "Log your first game to unlock season insights"
3. If partial (e.g., no position data but some games), show available cards only, skip empty ones
4. Use existing `renderEmpty()` helper

**Files:** render.js (renderDashboard, season stats section)

### B3. Checklist progress bar (S3-11)

**Problem:** No visual indicator of "4/6 items checked".

**Implementation:**
1. In `app.css`, add `.checklist-progress` bar styles (height 4px, green fill, rounded)
2. In `render.js:67-83` (checklist render), compute `checked / total` ratio
3. Render progress bar above or below checklist: `<div class="checklist-progress"><div style="width:${pct}%"></div></div>`
4. Add text label: "4 / 6 ready"

**Files:** app.css (progress bar), render.js (checklist render)

### B4. Modal title accuracy (S3-12)

**Problem:** "Add Event" title persists even after form errored and user re-opens.

**Implementation:**
1. In `actions.js:45` (openModal), always set title based on current action: "Add Event" vs "Edit Event" based on whether `editingId` is set
2. Ensure title is reset on every `openModal()` call, not just on first open
3. Check all 5 modal types for consistent title behavior

**Files:** actions.js (openModal for each type)

---

## Batch C — Flow Bridges & Linking

**Findings addressed:**
- S1-3: No "Create game from planner" CTA
- S2-10: Game log rows may be hard to expand on mobile

### C1. Planner → Game bridge CTA (S1-3)

**Problem:** After planning a game day, user must separately navigate to Games and log it manually.

**Implementation:**
1. In `render.js` (planner post-game section), add a "Log this game" button that appears when the planner has a date with an opponent or event linked
2. Button click pre-fills the game modal with planner data: date, opponent, rink, position from planner fields
3. In `actions.js`, add `openGameModalFromPlanner(date)` that reads planner entry for that date and calls `openGameModal()` with pre-filled values
4. After game save, show toast linking back to planner: "Game logged — view in Game Log"
5. In `bootstrap.js`, wire the new button click

**Files:** render.js (planner view), actions.js (new prefill function), bootstrap.js (event wiring)

### C2. Mobile game row expansion (S2-10)

**Problem:** Expandable detail row has small tap target for expand/collapse toggle on mobile.

**Implementation:**
1. In `app.css`, at the 480px breakpoint, increase the expand/collapse hit area to full row width (make entire row clickable, not just the chevron)
2. Add `cursor: pointer` to the game row on mobile
3. In `render.js:134-136`, ensure the `aria-expanded` toggle works on the full row click, not just the icon
4. Add a visual affordance: "Tap to expand" text or a subtle chevron animation

**Files:** app.css (mobile breakpoint), render.js (game row render)

---

## Batch D — Accessibility & Polish

**Findings addressed:**
- S2-9: Speed dots in Ice modal lack visible focus indicator
- S3-13: Danger button color may be borderline WCAG AA
- S3-14: No breadcrumb or "you are here" beyond tab highlight
- S3-15: Demo data tracked issues may confuse real users

### D1. Speed dots focus indicator (S2-9)

**Problem:** Keyboard users can't tell which speed level is focused.

**Implementation:**
1. In `app.css`, add `:focus-visible` style for speed dot buttons in the Ice modal: `outline: 2px solid var(--sky); outline-offset: 2px;`
2. Ensure the dots have `tabindex="0"` and `role="radio"` with `aria-checked` for the selected value
3. Add `aria-label="Speed N of 5"` to each dot

**Files:** app.css (focus styles), index.html (dot ARIA attributes)

### D2. Danger button contrast (S3-13)

**Problem:** Granite red (#b44a2c) on light red bg ≈ 3.5:1 at small text sizes.

**Implementation:**
1. In `app.css:247-256`, darken `.btn-danger` text to `#8a2e15` (darker granite) or increase font-weight to 600
2. Alternatively, darken the background and use white text: `background: var(--granite); color: #fff;`
3. Test with axe-core or WAVE to confirm ≥ 4.5:1 at `text-xs` size

**Files:** app.css (btn-danger styles)

### D3. View context indicator (S3-14)

**Problem:** Deep views (event detail, game report) lack navigation context.

**Implementation:**
1. In `app.css`, add `.view-context` styles: small text bar below nav tabs showing current context
2. In `render.js`, when rendering event detail or game report, show breadcrumb: "Calendar → Event: League Night" or "Games → Report: vs Granite CC"
3. Make the parent link clickable to return to the list view
4. Hide on dashboard (no context needed)

**Files:** app.css (breadcrumb styles), render.js (event detail, game report renders)

### D4. Demo data issues cleanup (S3-15)

**Problem:** Issues like "Offline cache not updating" appear to be real bugs, not demo content.

**Implementation:**
1. In `core.js`, update demo data issues to clearly be sample data: prefix titles with "[Demo]" or use obviously fictional content
2. Add a dismissible banner on first load: "CurlPlan loaded with sample data. Reset from the top bar to start fresh."
3. Alternatively, don't seed issues in demo data — let the issues tracker start empty

**Files:** core.js (demo data seeding)

---

## Batch Execution Prompts

### Batch A — Claude (reasoning-heavy: dirty checks, validation logic, state persistence design)

```text
CurlPlan Batch A: Data Safety & Guards
Architecture: Split-file vanilla JS (index.html + assets/css/app.css + assets/js/app/*.js)
Constraint: No dependencies, no build step, localStorage only, all HTML uses escapeHtml()

You are making 5 changes to improve data safety. Read each target file before editing.

1. UNSAVED-CHANGES GUARD (actions.js)
Add a _modalDirty flag. Set true on any input/change event inside an open modal.
In closeModal(), if _modalDirty is true, show confirm('Discard unsaved changes?').
Reset flag on modal open and after successful save. Wire input listeners in openModal().

2. PERSIST FILTER STATE (core.js, bootstrap.js)
Extend saveUiPrefs()/loadUiPrefs() to include calendarFilter, gameSort, practiceSort, iceSort.
On view switch, restore filters from prefs instead of resetting to defaults.
On each filter change, call saveUiPrefs().

3. IMPORT VALIDATION (actions.js, core.js)
In the import preview handler, run normalizeState(parsed, {strict:true}) in try/catch.
Collect per-collection warnings (missing required fields, unrecognized keys).
Render warnings in the preview modal below the counts.
If strict throws, show error banner. Keep Confirm button but add visual warning.

4. SCORE NORMALIZATION (actions.js, core.js)
In game save, normalize: empty string → null, "0" → 0, non-numeric → null.
In normalizeGame(), ensure us/them are number|null, never empty string.
Auto-compute result only when both scores are non-null.

5. EXPORT TIMESTAMP (core.js, actions.js, render.js)
Add lastExportAt to UI prefs. Write timestamp on export.
Update Export button label: "Export (last: 2d ago)" or "Export (never)".
Use relative time formatting.

Do not change HTML structure unless adding aria attributes. Match existing code style.
```

### Batch B — Codex (mechanical: CSS additions, render template changes, flag checks)

```text
CurlPlan Batch B: Feedback & Status
Architecture: Split-file vanilla JS. Files: app.css, render.js, actions.js

4 changes. All are visual/template changes with clear before→after.

1. PLANNER SAVE INDICATOR
Add .planner-save-status CSS: font-size .72rem, color var(--leaf), opacity transition 1s.
In render.js planner view, add <span id="plannerSaveStatus"></span> after the date nav.
In actions.js planner save callback, set text "Saved ✓", fade to opacity 0 after 1.5s.

2. HIDE EMPTY STAT CARDS
In render.js season stats grid render, if games array for range is empty:
  render single card: "Log your first game to unlock season insights" with renderEmpty().
If partial data (some games but no position tags): show available cards only, skip empties.

3. CHECKLIST PROGRESS BAR
Add .checklist-progress CSS: height 4px, background var(--sky-soft), border-radius 2px, overflow hidden.
Add .checklist-progress-fill: height 100%, background var(--sky), transition width 220ms.
In render.js checklist render, compute checked/total, render bar + "4 / 6 ready" label.

4. MODAL TITLE ACCURACY
In actions.js openModal(), always set title based on editingId:
  editingId ? "Edit [Type]" : "Add [Type]"
Check all 5 modal types. Title must reset on every openModal() call.

Use existing CSS variables. No new dependencies.
```

### Batch C — Claude (design decisions: prefill logic, mobile interaction patterns)

```text
CurlPlan Batch C: Flow Bridges & Linking
Architecture: Split-file vanilla JS. Files: render.js, actions.js, bootstrap.js, index.html

2 changes requiring design judgment.

1. PLANNER → GAME BRIDGE CTA
In render.js planner post-game section, add "Log this game" button.
Show when planner has date + (opponent OR linked event).
On click, call new openGameModalFromPlanner(date) in actions.js:
  - Read planner entry for that date
  - Pre-fill game modal: date, opponent, rink, position from planner fields
  - Open game modal in "add" mode (not edit)
After game save, show toast: "Game logged"
Wire button click in bootstrap.js.

Edge cases:
- Planner has no opponent but has linked event with opponent → use event opponent
- Game already logged for this date → show "Game already logged" instead of CTA
- Multiple events on same date → use the one matching planner rink/opponent

2. MOBILE GAME ROW EXPANSION
At 480px breakpoint in app.css, make entire game row clickable (not just chevron).
In render.js game row render, on mobile: row click toggles expand.
Add cursor:pointer to .game-row at mobile breakpoint.
Ensure aria-expanded updates on full-row click.

Do not change desktop behavior. Match existing code patterns.
```

### Batch D — Codex (mechanical: CSS fixes, ARIA attributes, static content changes)

```text
CurlPlan Batch D: Accessibility & Polish
Architecture: Split-file vanilla JS. Files: app.css, index.html, core.js

4 changes. All are targeted CSS/HTML/static-content fixes.

1. SPEED DOTS FOCUS
In app.css, add: .speed-dot:focus-visible { outline: 2px solid var(--sky); outline-offset: 2px; }
In index.html speed dots (line 717-723), add role="radio" and aria-checked on selected.
Add aria-label="Speed N of 5" to each dot.

2. DANGER BUTTON CONTRAST
In app.css btn-danger (line 247-256), change to:
  background: var(--granite); color: #fff; border-color: var(--granite);
Hover: background: #9a3a1e; (darker granite)
This gives white-on-red ≈ 7:1 contrast ratio.

3. VIEW CONTEXT BREADCRUMB
Add .view-context CSS: font-size .7rem, color var(--pebble), padding 6px 16px,
  border-bottom 1px solid rgba(44,62,74,.08).
In render.js, when rendering event detail: show "Calendar → [Event Title]"
When rendering game report: show "Games → Report: vs [Opponent]"
Make parent text a clickable link that calls switchView().

4. DEMO DATA CLEANUP
In core.js demo data, change issue titles to clearly demo content:
  "[Sample] Offline cache versioning" instead of "Offline cache not updating"
  "[Sample] Legacy schema import" instead of "importData fails on legacy schema versions"
Or: remove issues from demo data entirely. Let tracker start empty.

Match existing CSS variables and code conventions.
```

---

## Finding → Batch Traceability

| Finding | Severity | Batch | Task |
|---------|----------|-------|------|
| S1-1 No unsaved-changes guard | Critical | A | A1 |
| S1-2 Filter state lost on view switch | Critical | A | A2 |
| S1-3 No planner→game bridge CTA | Critical | C | C1 |
| S1-4 Planner auto-save silent | Critical | B | B1 |
| S2-5 Empty stat cards render | High | B | B2 |
| S2-6 Import preview lacks validation | High | A | A3 |
| S2-7 Partial score entry | High | A | A4 |
| S2-8 No export timestamp | High | A | A5 |
| S2-9 Speed dots lack focus | High | D | D1 |
| S2-10 Mobile game row expansion | High | C | C2 |
| S3-11 No checklist progress | Medium | B | B3 |
| S3-12 Modal title mismatch | Medium | B | B4 |
| S3-13 Danger button contrast | Medium | D | D2 |
| S3-14 No breadcrumb | Medium | D | D3 |
| S3-15 Demo data confusion | Medium | D | D4 |

**All 15 findings addressed. Zero skipped.**

---

## Execution Order

1. **Batch A** (Claude) — data safety first, prevents data loss
2. **Batch B** (Codex) — feedback, can run in parallel with A on separate files
3. **Batch C** (Claude) — flow bridges, depends on A2 (filter persistence) being done
4. **Batch D** (Codex) — polish, no dependencies, can run last or in parallel with C
