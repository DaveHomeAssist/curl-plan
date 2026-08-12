# CurlPlan Branch Integration Decision

Date: 2026-08-12

Integration branch: `codex/integrate-account-foundation-20260812`

Sources:

- `origin/main` at `b5a7f13`
- `origin/feat/account-foundation-credential-auth` at `8749ccc`

## Authority decision

`main` remains authoritative for the web app, generated seed, native `Store`,
web/native parity, CRDT-ready state, navigation, accessibility, and the
Cloudflare Worker synchronization scaffold.

The feature branch's replacement `AppData` graph predates those changes. It is
not merged into `main`, because doing so would regress current parity and state
contracts. The account service and tests now transport a versioned
`AccountSeasonPayload` containing the current `AppState` plus the minimum
account profile fields required for restore.

The credential backend remains a development verifier. It is not a public
production authentication authority and its presence does not make account,
cloud-sync, social, or App Store claims production-ready.

## Semantic slice disposition

| Original commit | Decision | Result |
| --- | --- | --- |
| `2344504` | Partial | Truth-loop evidence retained; superseded native Store UI omitted. |
| `f3c4846` | Accepted | Feature-review matrix and CI gate retained with pinned Actions. |
| `1a269ad` | Reworked | Account service, API, runtime, transport, tests, icons, privacy manifest, and documentation retained; payload adapted to current `AppState`. |
| `77ea91e` | Superseded | UI test targets the discarded replacement Store and is not carried forward. |
| `819c1e0` | Partial | Research and development transport notes retained; project generation remains owned by current `main`. |
| `3f4bccd` | Deferred | Spiel date/route model depends on the discarded Store graph. Reimplement against current Store under its own reviewed feature. |
| `5e62a94` | Deferred | Venue geocoder model depends on the discarded Store graph. |
| `9b5c021` | Superseded | Current `main` already contains the canonical Club/Rink terminology pass. |
| `05c5aa4` | Deferred | Measured map coordinates depend on the deferred venue model. |
| `90750e3` | Deferred | Bonspiel game scheduling depends on the discarded Store graph. |
| `41bd86b` | Reworked | Development account controls remain configuration-gated; no public account UI is exposed. |
| `2b561c7` | Superseded | Tests cover deferred Store-specific features and are not valid on current `main`. |
| `473d943` | Superseded | Current product copy and credential-free public-preview policy remain authoritative. |
| `8749ccc` | Accepted | Account roadmap retains the development-service truth boundary. |

## Required proof before integration can merge

1. Root, classic, parity, merge, and sync API web verifiers pass.
2. Account backend verifier passes without contacting the development host.
3. Swift package account-contract tests pass from a clean scratch path.
4. The generated Xcode project is stable and an unsigned simulator build passes.
5. The public preview remains credential-free and no production account claim is introduced.
