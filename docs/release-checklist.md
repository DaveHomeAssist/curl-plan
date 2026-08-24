# Release checklist

Every production release or integration checkpoint has exactly one dated record under
[`docs/releases/`](releases/README.md). The record is the release authority; roadmap,
changelog, CI, deployment, and App Store claims must link back to it.

Use `Closed`, `Open`, `Blocked`, or `Not applicable` for every gate. An applicable `Open`
or `Blocked` gate prevents a release-ready or all-phases-complete claim.

- Product and version
- Release owner
- Source baseline and exact change commit SHA
- Environment: OS, runtime, toolchain, and dependency lockfiles
- User-facing artifacts and schema or migration version
- Exact test, lint, typecheck, build, browser, and negative-gate commands with exit codes
- Browser proof: journeys, engines, viewport, theme, and retained artifacts
- Accessibility proof: automated scan, keyboard, VoiceOver, 200 percent zoom, contrast,
  target size, Dynamic Type, orientation, and reduced motion as applicable
- Security proof: dependencies, secrets, configuration, authentication, authorization,
  rate limits, CORS, transport, hostile input, and recovery
- CI workflow URL, tested commit, and conclusion
- Xcode tests, simulator, device, signed archive, privacy manifest, and icon inspection
- Staging environment and deployment smoke result with timestamp
- Monitoring result, backup and restore drill, and incident owner
- Rollback commit or artifact, rollback command, exercise result, and owner
- Known risks and explicitly deferred proof
