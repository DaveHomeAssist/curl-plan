# CurlPlan release evidence

This directory is the authoritative release ledger. Create one record named
`YYYY-MM-DD-<scope>.md` for each integration or production checkpoint; do not split one
release across roadmap notes, chat transcripts, or multiple status documents.

Each record must link the exact commit, environment, commands and exit codes, browser and
accessibility evidence, CI/deployment results, monitoring, backup/restore, and rollback.
Unknown evidence stays `Open`; it is never inferred from source inspection, an HTTP 200,
or a simulator build.

Status meanings:

- `Closed`: current direct evidence satisfies the gate.
- `Open`: evidence has not been gathered or an authorized external action has not occurred.
- `Blocked`: a named condition prevents gathering the required evidence.
- `Not applicable`: the record explains why the gate does not apply.

Current program record: [2026-08-24 audit remediation](2026-08-24-audit-remediation.md).
