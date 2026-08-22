# Changelog

All material CurlPlan product and engineering changes are recorded here. Dates are release or integration dates; unreleased account work is labeled explicitly.

## 2026-08-21

### Fixed

- Passport recent-stop avatars now resolve met curlers through the store and render real initials instead of blank circles (iOS); the demo season-map tally and sample-stop label derive from seed data instead of hardcoded copy.

### Changed

- Open-PR triage: merged the dependabot bumps (actions/checkout v7.0.1, actions/setup-node v7.0.0, wrangler 4.x in /api); closed the conflicting draft Passport fix in favor of a re-land on current main.

### Verified

- Confirmed the iOS CI test gate is live end to end: `generate-xcodeproj.js` emits the CurlPlanTests target and the macOS job executes MergeTests and StoreTests on an iOS Simulator on every push and pull request.

## 2026-08-13

### Fixed

- Raised all four primary web tab targets to a 44 by 44 CSS-pixel minimum at mobile and reflow viewports, while preserving tab order, selected styling, visible keyboard focus, and overflow behavior.
- Removed closed Appearance and action sheets from the keyboard focus order, added initial hidden/inert dialog state, meaningful opening focus, Escape and scrim dismissal, modal Tab containment, and focus restoration to the invoking control.

## 2026-08-12

### Added

- Reconciled the account-foundation branch into a current-main integration head without replacing the newer store, parity, synchronization, or accessibility architecture.
- Added versioned account-season transport contracts, backend and runtime clients, persistence and social safety contracts, review gates, and 18 Swift contract tests.
- Added self-hosted Hanken Grotesk, Instrument Serif, and DM Mono fonts with their OFL licenses.
- Added pinned repository security scanning and weekly dependency update configuration.

### Changed

- Reworked the public preview landing with one clear H1, an explicit demo CTA relationship, 44px interaction targets, visible keyboard focus, and reduced-motion handling.
- Removed Google Fonts from the critical path and tightened the content-security policy to local fonts and scripts.
- Removed unbacked like/comment affordances and replaced the demo-only “here now” location cue with explicit sample language on web and native surfaces.

### Security boundary

- The integrated credential service remains a development contract, not production authentication. Public account collection remains disabled until managed identity, abuse controls, deletion/recovery, migration, and signed-in device proof pass the release gate.
