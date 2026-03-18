# CurlPlan Update Report

Date: 2026-03-18

## Summary

CurlPlan moved from a monolithic inline `index.html` implementation to a static entrypoint with split CSS and JS assets. The live behavior baseline was preserved, smoke-tested in a real browser session, and protected with a lightweight split verification script.

## Completed Changes

- Split CSS into `assets/css/app.css`
- Split JS into:
  - `assets/js/app/utils.js`
  - `assets/js/app/core.js`
  - `assets/js/app/render.js`
  - `assets/js/app/actions.js`
  - `assets/js/app/bootstrap.js`
- Preserved all existing feature behavior:
  - dashboard stats and season cards
  - shot percentage tracking
  - planner checklist persistence
  - import/export/reset
  - printable game reports
- Added `scripts/verify-split.js`
- Added end-user guide at `docs/how-to-guide.html`
- Updated repo docs to reflect the split asset structure
- Removed the rollback-only monolith file from the active repo surface

## Smoke Test Results

The following flows passed against a local static server:

- asset loading
- dashboard render
- planner save and reload persistence
- export filename verification
- import application to live UI state
- print report composition and cleanup after `afterprint`

## Current Canonical Structure

- Entry: `index.html`
- Styles: `assets/css/app.css`
- Scripts:
  - `assets/js/app/utils.js`
  - `assets/js/app/core.js`
  - `assets/js/app/render.js`
  - `assets/js/app/actions.js`
  - `assets/js/app/bootstrap.js`

## Deferred / Not In Scope

- recurring events
- backend or sync features
- framework migration
- automated in-repo browser test harness beyond the static verification script

## Recommended Next Steps

1. Keep using `scripts/verify-split.js` after structural edits.
2. Add one committed smoke-test script if browser automation should become repeatable in-repo.
3. Split `core.js` one more time later into `state` and `storage` only if more complexity lands.
