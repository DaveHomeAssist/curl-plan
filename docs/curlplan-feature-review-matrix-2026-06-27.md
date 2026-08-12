# CurlPlan Feature Review Matrix

Date: 2026-06-27

Target surface: `ios/CurlPlan.xcodeproj`

Purpose: give every retained feature a repeatable review row before future changes ship. A feature is not done because the UI renders. It is done when the user can enter the loop, complete the job, recover from bad input or mistakes, see the same truth on every related screen, relaunch, and still trust the result.

## Review Scale

| Rating | Meaning | Release rule |
| --- | --- | --- |
| Green | Source, mutation, propagation, correction, persistence, and proof are all present | Can ship |
| Yellow | Feature works in part, but proof, correction, or propagation is incomplete | Do not expand claims |
| Red | Feature creates or displays unsupported authority, stale facts, or an unfinishable loop | Remove, block, or rebuild before ship |

## Review Dimensions

| Dimension | Question |
| --- | --- |
| Source | Which state object or selector owns the visible fact? |
| Entry | Can a normal user find the feature from the expected screen? |
| Completion | Can the user finish the intended loop without hidden setup or debug state? |
| Correction | Can the user edit, undo, remove, retry, or recover? |
| Propagation | Do all related screens read the same source? |
| Persistence | Does relaunch preserve the final truth? |
| Claim control | Does the wording avoid public, official, GPS, live, or social authority the app does not have? |
| Proof | Which model tests, screenflows, scans, or build checks prove the feature? |

## Feature Matrix

| ID | Feature area | User job | Truth owner | Completion loop | Correction and recovery | Risk tier | Claim risk | Required proof commands or evidence | Current rating | Review trigger |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `FR-SETUP` | Setup and season start | Start demo, blank, or imported season | `AppData.setupComplete`, profile fields, `Seed.appData` | Clean install leads to setup, then main app with the selected season state | Return to setup, clear season, reset demo, import valid export | High | Allowed: local setup state, demo, blank, import. Banned: sync, account, cloud restore. | `swift test --scratch-path /tmp/curlplan-spm-build`; UI proof SF 01 and SF 09 | Green | Required for setup copy, seed, import, onboarding, Settings return-to-setup |
| `FR-PASSPORT` | Passport summary | Understand rinks, provinces, games, win rate, and route distance | `Store.seasonSummary` | Passport reads season facts from selectors, not static sample text | Result edits and deletes update games and win rate; unavailable distance displays as unavailable | High | Allowed: local season summary. Banned: GPS distance, official record, verified travel. | `swift test --scratch-path /tmp/curlplan-spm-build`; route distance UI proof; SF 02 | Green | Required for summary numbers, map overlay, record display, recent stops |
| `FR-STOPS` | Stop visits and map | Record presence at a rink and people met there | `StopVisit`, `isCurrentStop`, `peopleMetIDs(for:)` | Start visit, add people met, see active stop and stop detail update | End visit, relaunch, delete linked curler without blank rows | High | Allowed: local active visit. Banned: here now, GPS verified, live location. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 03; SF 04 | Green | Required for map pin, stop detail, current stop, people-met changes |
| `FR-RESULTS` | Results | Log a local game result and have it update the season | `GameResult`, result selectors, linked stop and curler refs | Create result, see receipt, feed card, Passport update, Stop Detail update, Profile form update | Edit win to loss, delete, undo, relaunch | High | Allowed: local result. Banned: official result, public score, external verification. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 02 | Green | Required for score, opponent, result card, result mutation, summary propagation |
| `FR-ROSTER` | Roster and profiles | Manage curlers and inspect derived history | `AppData.curlers`, profile selectors, imported history fallback | Add curler, search roster, open profile, copy share text, view shared rinks and form | Toggle circle, delete with confirmation, clean stale refs, relaunch | Medium | Allowed: local roster and profile. Banned: public roster, message delivery, remote identity. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 04; route/circle proof | Green | Required for roster row, profile stat, share, delete, search changes |
| `FR-CIRCLE` | Circle membership | Maintain a local following circle | `Curler.following` and store circle selectors | Follow from Discover, Roster, or Profile and see Discover/filter state change | Toggle off and on, delete curler, relaunch | Medium | Allowed: local circle membership. Banned: social graph, likes, comments, follows from other users. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 08; route/circle proof | Green | Required for follow, discover, feed-filter, profile action changes |
| `FR-LOCKER` | Locker feed | Review local season activity without fake social claims | `lockerFollowingFeed`, `discoverSuggestions`, `GameResult`, attendance selectors | Feed shows backed local results and attendance; search filters real posts | Delete backing result, filtered feed empties, Discover follow persists | High | Allowed: local feed, local discover suggestions. Banned: likes, comments, public feed, remote posts. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 02; SF 08 | Green | Required for feed ranking, filter, post, search, Discover changes |
| `FR-ATTENDANCE` | Spiel attendance | Track who is attending a spiel | `SpielAttendance`, `attendeeIDs(for:)` | Toggle attendance in Locker, open Spiels, count agrees | Toggle off/on, dedupe by attendee ID, relaunch | Medium | Allowed: local attendance. Banned: public RSVP, external attendance, real-time going list. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 05 | Green | Required for attendance count, attendee row, status chip changes |
| `FR-BONSPIEL-ROSTER` | Bonspiel roster | Manage team members under roster policy | `BonspielRecord.teams`, `BonspielRosterPolicy` | Add team member, remove eligible member, see roster policy and team rows | Block removal when member is locked into submitted lineup | High | Allowed: local bonspiel roster. Banned: official roster, public roster, verified eligibility. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 06 | Green | Required for team member, roster policy, spare, alternate, lock rule changes |
| `FR-BONSPIEL-LINEUP` | Bonspiel lineup | Submit and lock local game lineups | `BonspielGame.gameLineups`, `lineupIsLocked` | Submit valid team lineups, block invalid count, lock lineup | Try late edit after lock and receive blocked receipt | High | Allowed: local lineup lock. Banned: official lineup submission, governing-body lock. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 06 | Green | Required for lineup slot, lock window, submission, game status changes |
| `FR-BONSPIEL-SCORE` | Bonspiel scorecard | Record ends and locally confirm scorecard result | `BonspielGame.ends`, `BonspielResultFlags`, `BonspielScoreAgreement` | Record A score, B score, blanks, extra end, concession or forfeit, then confirm | Block premature confirmation, require extra end for tied regulation, relaunch finalized state | High | Allowed: local scorecard confirmation. Banned: official result, verified score, public score feed. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 07; scorecard edge proof; forfeit proof | Green | Required for end scoring, total, blank, concession, forfeit, confirmation, Locker result changes |
| `FR-SETTINGS` | Settings recovery | Export, import, clear, and reset without data loss | encoded `AppData` schema 4, import validation | Export copied JSON, clear through confirmation, import saved season, restore roster and result | Failed import preserves current season; reset demo recovers sample season | High | Allowed: local export and import. Banned: cloud backup, cross-device sync, account recovery. | `swift test --scratch-path /tmp/curlplan-spm-build`; SF 09 | Green | Required for JSON schema, import validation, clear, reset, Settings sheet changes |
| `FR-A11Y` | Small screen and accessibility reachability | Complete primary loops on constrained screens | SwiftUI layout, accessibility identifiers, content-size launch args | Core controls remain reachable on small device and accessibility-medium content size | Scrollable surfaces expose actions without overlap or hidden dead ends | Medium | Allowed: reachable local controls. Banned: hidden debug-only paths as proof. | `xcodebuild test ... -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests/testSmallScreenAccessibilityPrimaryControlsRemainReachable` | Green | Required for toolbar, sheet, button grid, tab, card, dynamic type changes |
| `FR-CLAIMS` | Unsupported authority guardrails | Avoid claims the local app cannot prove | Static visible text and claim ledger | App does not claim public roster, official result, GPS verification, here now, likes, or comments | Unsupported wording is removed or backed by real authority before ship | High | Allowed: explicitly local claims. Banned: public, official, GPS, here now, likes, comments, remote social authority. | `make feature-review`; the gate scans literal visible copy while permitting explicit local, demo, sample, unavailable, and not-live disclaimers | Green | Required for any copy, feed, profile, map, roster, result, sharing language change |

## Future Backend Matrix

These rows are not current app features. They are the required review contract before CurlPlan can ship account, sync, public identity, relationship, shared object, or social claims.

| ID | Feature area | User job | Truth owner | Completion loop | Correction and recovery | Risk tier | Claim risk | Required proof commands or evidence | Current rating | Review trigger |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `FR-ACCOUNT` | Account foundation | Sign in, sign out, delete account, export data, and restore on a second device | Auth service with handle/password credentials, `Account`, `PasswordCredential`, `Session`, `AccountProfile`, account-scoped `SeasonDocument` | Account A authenticates with handle and password, creates season data, signs out, signs in on another device, restores same season, exports, deletes account | Sign out revokes session, delete account revokes sessions and removes credential plus owned data, wrong and weak passwords are rejected, expired session shows honest state | High | Allowed only after deployed backend exists: account, sign in, restore, cloud account. Banned until then: account restore, cloud backup, server session. | `node scripts/verify-account-remote.mjs http://dominic:8787` (AS 01, AS 02, AS 03 against deployed backend); weak/wrong password negative tests; session revocation; container-restart persistence; Swift `AccountHTTPBackendTests`/`AccountRuntimeTests` | Yellow: credential auth green; service deployed to the dominic tailnet and AS 01-03 pass against it; Debug Run app targets it. Gated until the in-app create/sign-in UI screenflow is proven and the service is publicly reachable with TLS and rate limits | Required for any sign-in, account, restore, session, profile ownership, export, or delete account work |
| `FR-SYNC` | Cloud sync without social | Keep account-scoped season data consistent across devices | Sync API, `SeasonDocument`, `SeasonChange`, offline queue, version/conflict receipts | Device A edits, server stores version, device B receives update; offline edits queue, relaunch, reconnect, and sync | Failed sync preserves local work, stale base version creates conflict receipt, user resolves conflict | High | Allowed only after backend exists: synced, cloud, pending, conflict. Banned until then: always up to date, cloud saved, cross-device restore. | Sync unit/integration tests; AS 04, AS 05; conflict negative tests | Red until implemented | Required for any sync copy, remote persistence, pending state, offline queue, or cross-device behavior |
| `FR-PUBLIC-ID` | Public identity | Opt into a public profile and control discoverability | Public identity API, `AccountProfile.visibility`, search index, block state | Private default, user opts public/searchable, other account finds profile, private account stays hidden | Privacy toggles remove profile from search, block hides profile, suspended/deleted accounts disappear | High | Allowed only after backend exists: public profile, searchable, discoverable. Banned until then: public roster, public identity, remote profile. | Profile API authorization tests; AS 06, AS 08 | Red until implemented | Required for handle, avatar, public profile, discoverability, search, visibility, or home club public display |
| `FR-RELATIONSHIP` | Relationship graph | Follow, friend, invite, teammate, and block other accounts | Relationship graph API, relationship edge cache, block enforcement | Follow/unfollow updates server, second device agrees, feed filters by server graph | Duplicate requests dedupe, rejected/revoked states display, block removes interaction paths | High | Allowed only after backend exists: follows, friends, teammates, invites, social graph. Banned until then: remote follow, social feed, other-user circle. | Graph API tests; AS 07, AS 08; block bypass negative tests | Red until implemented | Required for follow, friend, teammate, invite, block, graph-backed feed, or remote circle work |
| `FR-SHARED-OBJECTS` | Shared curling objects | Share spiels, bonspiels, teams, attendance, rosters, lineups, and scorecards with members | Shared object API, `SharedObject`, `Membership`, role permissions, object versions | Account A creates shared object, invites B, B joins/RSVPs, both see same server state | Unauthorized edits denied, stale versions blocked, removed members lose access | High | Allowed only after backend exists: shared spiel, public/team roster, remote RSVP, shared scorecard. Banned until then: public roster, shared lineup, remote score. | Shared object tests; AS 09, AS 10 | Red until implemented | Required for shared spiel, shared bonspiel, shared roster, team membership, remote RSVP, lineup, or scorecard work |
| `FR-SOCIAL` | Social interactions | React, comment, message, invite, report, and receive notifications | Interaction API, notification service, moderation state, block state | Create/edit/delete/report interactions, notifications deliver to allowed recipients, hidden/deleted states display | User deletes own interaction, reports another, blocked users cannot interact, rate limits show retry state | High | Allowed only after trust and safety exists: reactions, comments, messages, notifications. Banned until then: likes, comments, public conversation, DM. | Interaction tests; AS 11; rate-limit and block negative tests | Red until implemented | Required for reaction, comment, message, notification, report-from-interaction, or public conversation work |
| `FR-TRUST-SAFETY` | Trust, safety, and compliance | Block, report, moderate, export, and delete data safely | Trust/safety API, report queue, audit log, rate limits, privacy policy, App Store privacy labels | Reported content can be hidden/reviewed; blocks apply across API/UI; export and deletion match policy | Restore wrongly hidden content, unblock, revoke sessions, complete deletion/anonymization | High | Allowed only after backend exists: report, moderation, privacy export, account deletion. Banned until then: safe public comments, moderated community. | Trust/safety tests; AS 08, AS 12; direct API block bypass tests | Red until implemented | Required before public comments/messages, account deletion, reporting, moderation, privacy labels, or public social launch |

## File Impact Map

| Path | Feature row IDs |
| --- | --- |
| `ios/CurlPlan/AccountBackendAPI.swift` | `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `ios/CurlPlan/AccountHTTPBackend.swift` | `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `ios/CurlPlan/AccountRuntime.swift` | `FR-ACCOUNT`, `FR-SYNC`, `FR-SETTINGS`, `FR-CLAIMS` |
| `ios/CurlPlan/AccountSocialContracts.swift` | `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `services/account-backend/**` | `gate-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `scripts/verify-account-backend.mjs` | `gate-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/AccountBackendAPITests.swift` | `test-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/AccountBackendPersistenceTests.swift` | `test-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/AccountHTTPBackendTests.swift` | `test-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/AccountRuntimeTests.swift` | `test-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-SETTINGS`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/AccountSocialContractTests.swift` | `test-support`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `ios/CurlPlan/Models.swift` | `FR-SETUP`, `FR-PASSPORT`, `FR-STOPS`, `FR-RESULTS`, `FR-ROSTER`, `FR-CIRCLE`, `FR-LOCKER`, `FR-ATTENDANCE`, `FR-BONSPIEL-ROSTER`, `FR-BONSPIEL-LINEUP`, `FR-BONSPIEL-SCORE`, `FR-SETTINGS`, `FR-CLAIMS` |
| `ios/CurlPlan/Seed.generated.swift`, `ios/CurlPlan/Clubs.generated.swift` | `build-support`, `FR-SETUP`, `FR-PASSPORT`, `FR-STOPS`, `FR-RESULTS`, `FR-ROSTER`, `FR-CIRCLE`, `FR-LOCKER`, `FR-ATTENDANCE`, `FR-CLAIMS` |
| `ios/CurlPlan/CurlPlanApp.swift` | `FR-SETUP`, `FR-SETTINGS`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/RootView.swift` | `FR-SETUP`, `FR-PASSPORT`, `FR-LOCKER`, `FR-ROSTER`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/PassportView.swift` | `FR-PASSPORT`, `FR-STOPS`, `FR-RESULTS`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/LiveMapView.swift` | `FR-STOPS`, `FR-PASSPORT`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/StopDetailView.swift` | `FR-STOPS`, `FR-RESULTS`, `FR-ROSTER`, `FR-CIRCLE`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/LockerRoomView.swift` | `FR-LOCKER`, `FR-RESULTS`, `FR-CIRCLE`, `FR-ATTENDANCE`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/RosterView.swift` | `FR-ROSTER`, `FR-CIRCLE`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/CurlerProfileView.swift` | `FR-ROSTER`, `FR-CIRCLE`, `FR-STOPS`, `FR-RESULTS`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/SpielsView.swift` | `FR-ATTENDANCE`, `FR-BONSPIEL-ROSTER`, `FR-BONSPIEL-LINEUP`, `FR-BONSPIEL-SCORE`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/SettingsSheet.swift` | `FR-SETTINGS`, `FR-SETUP`, `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/Components.swift` | `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/Theme.swift` | `FR-A11Y`, `FR-CLAIMS` |
| `ios/CurlPlan/Assets.xcassets/**` | `build-support` |
| `ios/CurlPlan/PrivacyInfo.xcprivacy` | `build-support` |
| `ios/CurlPlan/Info.plist` | `build-support` |
| `ios/CurlPlan.xcodeproj/**` | `build-support` |
| `ios/CurlPlanUITests/CurlPlanPrimaryScreenflowUITests.swift` | `test-support`, `FR-A11Y`, `FR-CLAIMS` |
| `tests/CurlPlanCoreTests/TruthLoopTests.swift` | `test-support`, all model-backed feature rows |
| `Package.swift` | `build-support`, all model-backed feature rows, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY`, `FR-CLAIMS` |
| `.github/workflows/verify.yml` | `gate-support`, `build-support` |
| `Makefile` | `gate-support` |
| `scripts/feature_review_matrix_check.sh` | `gate-support` |
| `docs/curlplan-feature-review-*.md` | `docs-only`, `gate-support` |
| `docs/curlplan-accounts-social-roadmap-*.md` | `docs-only`, `FR-ACCOUNT`, `FR-SYNC`, `FR-PUBLIC-ID`, `FR-RELATIONSHIP`, `FR-SHARED-OBJECTS`, `FR-SOCIAL`, `FR-TRUST-SAFETY` |
| `docs/reviews/*.md` | `docs-only`, `gate-support` |

## Revalidation Rules

| Scope | Required revalidation | Optional revalidation |
| --- | --- | --- |
| High-risk feature rows | Before any release touching a mapped source file, claim copy, persistence path, scoring path, roster policy, setup/import/export path, or result propagation path | Quarterly manual skim when no mapped files changed |
| Medium-risk feature rows | Before release when mapped UI, selector, search, follow, attendance, or accessibility files change | Manual skim after large visual-only layout work |
| `build-support` | Run simulator build proof when package, Xcode project, app asset, privacy manifest, or CI workflow files change | Full UI screenflow only when build-support changes alter runtime behavior |
| `gate-support` | Run `make feature-review`, unmapped-path negative check, and claim scan after matrix, script, workflow, or Makefile edits | Sample review packet refresh when the matrix wording changes materially |
| `docs-only` | Confirm docs do not expand app claims beyond the claim ledger | No app proof when docs do not describe shippable behavior |

## Trigger Control

Required triggers are the mapped source paths listed above plus visible copy changes that can mislead the user. Optional triggers are review aids only; they do not block a change unless they reveal a missing truth owner, missing proof, unsupported claim, or unfinishable user loop.

False positives are handled by narrowing the file map or adding a specific support row. Do not bypass an unmapped source failure by relabeling a user-facing feature as docs-only.

## Review Packet Template

Use `docs/curlplan-feature-review-packet-template.md` for completed reviews. A packet must include changed files, impacted row IDs, commands run, evidence, residual risk, and the final release call.

## Review Pass Template

Use this pass for every future feature change:

| Step | Required output |
| --- | --- |
| 1. Name feature area | One row from the matrix, or a new row if this is a new feature |
| 2. Name truth owner | State object, selector, or explicit new source object |
| 3. Walk user loop | Entry, input, save, feedback, propagation, correction, persistence |
| 4. Scan claims | Confirm no unsupported public, official, GPS, live, likes, comments, or social authority wording |
| 5. Prove model behavior | Existing or new model test names |
| 6. Prove screenflow | Existing or new UI test or manual screenflow evidence |
| 7. Assign rating | Green, Yellow, or Red with the exact laggard if not Green |

## Definition Of Done For A Feature Row

1. The row has one truth owner.
2. The user can enter and finish the loop from the app UI.
3. Bad input is blocked without losing useful user work.
4. The user can correct the fact without resetting the app.
5. Every related screen reads the same source.
6. Relaunch preserves the final truth.
7. The claim ledger has no unsupported wording for the feature.
8. Model proof and screenflow proof are named.

## Current Review Result

| Scope | Result | Evidence |
| --- | --- | --- |
| Local season contract | Green | `docs/curlplan-rigorous-truth-implementation-plan-2026-06-26.md` says no open truth-loop gaps remain as of 2026-06-27 |
| Source commit | Green | Commit `2344504` adds the audit docs and CurlPlan source changes |
| Release caution | Green with maintenance trigger | Matrix ratings stay green only while future changes rerun the relevant review row and gate evidence |
