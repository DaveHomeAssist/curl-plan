# Next UX / Features Pass

This pass should stay within the current product shape:

- static local-first app
- split asset structure already in place
- no libraries
- fast local-first behavior
- desktop and mobile first
- no schema reset unless migration is explicit

## Pass Goal

Improve daily usability, reduce friction in repeated logging, and make the app feel more trustworthy during real use.

## Priority 1

### 1. Quick Capture

Add lower-friction entry paths for the actions users do most often.

Scope:

- add persistent quick actions for `New Event`, `Log Game`, `Log Practice`, `Ice Note`
- add keyboard shortcut support for opening core modals
- support `Esc` to close modals
- support `Cmd/Ctrl + S` on planner view to save planner entry

Acceptance:

- every primary record type can be opened in one click from desktop and mobile
- keyboard shortcuts do not conflict with typing inside fields
- planner save shortcut only fires when planner inputs are active or planner view is visible

### 2. Stronger Event Detail Flow

The calendar/event area should be a decision surface, not just a list.

Scope:

- add richer selected-event detail
- show linked context when available:
  - related planner entry for same date
  - logged game on same date
  - latest rink note for same rink
- add a direct `Plan This Game` or `Open Planner` jump from event detail

Acceptance:

- selecting an event gives enough context to act without switching views blindly
- same-date and same-rink links are fast and non-destructive

### 3. Search, Sort, and Filter Quality

Current filtering works, but it can be sharper.

Scope:

- add visible search affordance in calendar/events
- add sort controls where useful:
  - upcoming vs newest
  - games newest first / oldest first
  - practice newest first
- persist current filter/search state in-memory while navigating views

Acceptance:

- user can narrow large event history quickly
- current filter state survives view switches until page reload

## Priority 2

### 4. Draft Safety and Undo

Reduce fear around destructive actions.

Scope:

- add soft undo for delete actions via toast action or short-lived restore buffer
- add unsaved-changes guard when closing a modal with edited fields
- add planner dirty-state indicator

Acceptance:

- accidental deletes are recoverable for a short window
- modal close warns only when values changed
- planner shows whether current form differs from saved state

### 5. Better Summaries

Make the dashboard and section summaries more useful.

Scope:

- add streaks or trends to game summary
- add upcoming count by type
- add most-used practice shot tags
- add rink frequency / recent speed pattern summary

Acceptance:

- dashboard surfaces one useful insight per section, not just raw counts
- summaries remain cheap to compute from current local state

### 6. Mobile Ergonomics

The app is responsive now; next pass should make it feel intentionally mobile.

Scope:

- tighten modal spacing and action placement on small screens
- keep primary actions visible without excessive scrolling
- improve tap target consistency for filter pills, nav buttons, speed dots
- review sticky or semi-sticky utility actions where helpful

Acceptance:

- common add/save flows feel comfortable on phone widths
- no cramped modal footer or hidden primary CTA

## Priority 3

### 7. Planner / Game Linkage

The planner should feel connected to actual outcomes.

Scope:

- offer `Create Game Log From Planner Date`
- prefill game modal from planner entry where possible
- after logging a game, surface a `Return to Planner Reflection` path

Acceptance:

- planner and game log reinforce each other instead of acting like separate tools

### 8. Export / Import Confidence

Import/export exists; next pass should improve confidence.

Scope:

- add last export timestamp in UI
- show import summary before applying when possible
- improve import error copy with field-level reason where feasible

Acceptance:

- users know what happened after import/export without reading raw JSON

## Deferred

Do not pull these into the next pass unless priorities above are done:

- multi-user sync
- backend/auth
- charts-heavy analytics
- drag-and-drop calendar
- framework migration

## Implementation Order

1. keyboard + modal behavior polish
2. event detail linkage
3. search/sort improvements
4. delete undo + unsaved changes guard
5. dashboard summaries
6. planner/game prefill linkage
7. import/export confidence polish
8. mobile tightening pass

## Suggested Branch

`ux/pass-02-flow-and-confidence`

## Suggested Commit Chunks

1. `Add keyboard shortcuts and modal close polish`
2. `Improve event detail and cross-view linking`
3. `Add search and sorting controls`
4. `Add undo and dirty-state feedback`
5. `Improve dashboard summaries and mobile ergonomics`

## QA Checklist

- open/close every modal with mouse, keyboard, and overlay click
- verify no save shortcut fires while typing in unrelated fields
- delete and undo each record type
- verify selected event links open correct planner/game context
- confirm mobile widths for 768px and 480px still hold
- export, import, and reset still work after UI changes
