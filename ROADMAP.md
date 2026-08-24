# CurlPlan remediation roadmap

The 2026-08-24 audit remediation runs in strict dependency order. Current proof lives in
[`docs/releases/2026-08-24-audit-remediation.md`](docs/releases/2026-08-24-audit-remediation.md).

| Phase | Dependency | Current state | Completion authority |
|---|---|---|---|
| P0 Honest release baseline | None | Local checkpoint committed at `73523784` | Non-mutating seed, full verifier exits, browser harness, Worker lock/build, account tests, negative gate |
| P1 Classic workflows and recovery | P0 | Local checkpoint committed at `6749e1e` | Browser CRUD/reload/failure/recovery plus modal, contrast, focus, calendar, and support-policy evidence |
| P2 Root web and offline boundaries | P0 | Open | Root semantics/correction/persistence and isolated install/offline/cache evidence |
| P3 Atomic data ownership | P0 | Open | One production authority plus transactional, convergent, bounded, rollback-safe persistence |
| P4 Identity and abuse boundaries | P3 | Open | Token, password, authorization, blocking, CORS/TLS, recovery, and abuse evidence |
| P5 Native and release readiness | P3 and P4 | Open | One native state owner, archive resources, device accessibility/performance, and final release record |

No phase inherits completion from source inspection alone. Unknown staging, deployment,
monitoring, rollback, device, or App Store evidence remains open in the release record.
