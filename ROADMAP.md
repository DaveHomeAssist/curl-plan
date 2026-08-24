# CurlPlan remediation roadmap

The 2026-08-24 audit remediation runs in strict dependency order. Current proof lives in
[`docs/releases/2026-08-24-audit-remediation.md`](docs/releases/2026-08-24-audit-remediation.md).

| Phase | Dependency | Current state | Completion authority |
|---|---|---|---|
| P0 Honest release baseline | None | Local checkpoint committed at `73523784` | Non-mutating seed, full verifier exits, browser harness, Worker lock/build, account tests, negative gate |
| P1 Classic workflows and recovery | P0 | Local checkpoint committed at `6749e1e` | Browser CRUD/reload/failure/recovery plus modal, contrast, focus, calendar, and support-policy evidence |
| P2 Root web and offline boundaries | P0 | Local checkpoint committed at `f659a29` | Root semantics/correction/CRUD, durable failure recovery, bounded imports, both-theme Axe, 200 percent mobile-equivalent reflow, and isolated install/offline/cache evidence |
| P3 Atomic data ownership | P0 | Local checkpoint committed at `af8ac0f` | Clerk + Worker/D1 authority, schema 4 bounded CAS/idempotency/lifecycle, hostile-key rejection, rejected-plane quarantine, per-record development commits, and Swift failed-write rollback |
| P4 Identity and abuse boundaries | P3 | Local implementation committed at `77908ad`; staging gates committed at `0e8e6d4`; phase exit open | Token, password, authorization, blocking, CORS, recovery, abuse, D1 migration rehearsal, and staging-verifier fixture checks are green locally; real Clerk + Worker/D1 controlled TLS staging proof is still required |
| P5 Native and release readiness | P3 and P4 | Not started because P4 exit is open | One native state owner, archive resources, device accessibility/performance, and final release record |

No phase inherits completion from source inspection alone. Unknown staging, deployment,
monitoring, rollback, device, or App Store evidence remains open in the release record.
