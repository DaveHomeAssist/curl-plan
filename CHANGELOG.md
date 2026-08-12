# Changelog

All material CurlPlan product and engineering changes are recorded here. Dates are release or integration dates; unreleased account work is labeled explicitly.

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
