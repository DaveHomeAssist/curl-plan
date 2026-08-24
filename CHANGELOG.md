# Changelog

All material CurlPlan product and engineering changes are recorded here. Dates are release or integration dates; unreleased account work is labeled explicitly.

## Unreleased - 2026-08-24 audit remediation

### Added

- Added reproducible Node 22 Worker typecheck, lint, behavioral test, and Wrangler dry-run build gates with an API lockfile.
- Added a real-browser Playwright harness, a Classic Ice Notes regression fixture, and a demonstrated intentional-failure gate.
- Added the authoritative dated release-evidence ledger and dependency-ordered remediation roadmap.
- Added durable Classic storage-recovery and pre-reset restore notices plus automated light/dark accessibility coverage for every overlay.
- Added root create/edit/delete/reload coverage, structured storage-failure recovery, correction-state accessibility checks, and stable user-created record identifiers.
- Added product-scoped manifests and isolated root/Classic service-worker upgrade and offline-shell browser tests.
- Added the canonical Clerk + Worker/D1 identity and season-ownership decision, schema 4 D1 migration, versioned export/restore/deletion endpoints, and persisted idempotency receipts.
- Added concurrent CAS, hostile-key, merged-size, migration, lifecycle, rejected-plane, per-record recovery, and failed-Swift-persistence regression coverage.

### Changed

- Made seed check mode read-only and self-verify the generated Swift SHA-256 before and after checking.
- Repaired Planner Entries stress fixtures and the browser harness's literal closing-script injection.
- Pinned the account backend container base to a multi-architecture Node 22 Alpine digest.
- Stabilized Classic Ice Notes create/edit/reload and failed-write behavior, made overlays single-owner hidden/inert dialogs with focus restoration, aligned calendar detail with active filters, and scoped planner saves to affected views.
- Defined Classic as a retained, supported local-first planner whose canonical route and storage boundary remain distinct from the root product preview.
- Replaced non-semantic root controls with named keyboard-operable controls, added tab and rating state semantics, repaired form naming and validation focus, and established contrast-safe accents in both themes.
- Isolated root and Classic cache ownership, constrained navigation fallbacks to each product scope, tightened both web CSPs, and bounded Classic imports by bytes, records, depth, and keys before merge.
- Replaced all six cleartext club website records with verified HTTPS destinations and made the verifier reject new cleartext records.
- Made Worker/D1 writes revision-conditional, bounded-retry, final-size checked, and atomic with small bounded idempotency receipts; stale writes now return a deterministic current-state conflict envelope.
- Replaced inherited-key-sensitive merge accumulators with null-prototype dictionaries and filtered dangerous keys before they can enter merge state.
- Quarantined the custom credential service by default, retained explicit development mode only, serialized its mutations, validated schema 4 imports, and replaced whole-system snapshots with content-addressed records behind an atomic recoverable manifest.
- Staged Swift account mutations in an isolated store and publish them only after durable persistence succeeds.

### Verified locally

- All P0 local application, parity, merge, API, account-backend, stress, Worker lifecycle, and browser gates passed.
- All P1 Classic CRUD, recovery, modal, calendar, control-semantics, focus, contrast, and automated accessibility gates passed locally in Chromium.
- All P2 root semantics, keyboard, CRUD/reload, storage recovery, theme/contrast, correction-state, install asset, service-worker isolation, wrong-shell, import-bound, CSP, and HTTPS gates passed locally; the browser suite is 25 of 25 green.
- All P3 merge, atomic Worker/D1, migration, lifecycle, custom development-service, hostile-input, bounded-growth, and 19 Swift contract tests passed locally.
- P3 Worker typecheck, lint, and direct esbuild passed; the current-revision Wrangler dry-run remains open because startup blocked on synchronous dependency reads under critical APFS capacity pressure.
- Hosted CI, staging, deployment, monitoring, rollback, Xcode project tests, archive, device, and manual accessibility evidence remain explicitly open.

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
