# CurlPlan Accounts And Social Roadmap

Date: 2026-06-28

Target surface: `ios/CurlPlan.xcodeproj`

Status: the local season journal remains the shipped product truth. Clerk plus the Cloudflare Worker/D1 plane is the selected production account and data authority, but the native app has not completed that integration or its controlled staging proof. Production account, cloud, public, remote social, and moderation claims remain gated.

Last verified: 2026-08-24. Local Worker, custom-verifier, and Swift contract suites pass. No live deployment, D1 migration, credential configuration, signed archive, or device screenflow was authorized or verified in this audit. The July Tailscale deployment record is historical only and is not current production authority.

## Goal

Move CurlPlan from a truthful local season journal to a truthful account-backed curling network without introducing fake cloud, fake social, fake public roster, fake official result, or unverifiable presence claims.

## Operating Stance

| Rule | Requirement |
| --- | --- |
| Backend authority before copy | UI copy can say account, sync, public, follow, reaction, comment, message, invite, report, or notification only after an API-backed source exists |
| Local remains useful | The app must still support offline local capture, but pending or unsynced state must be visible |
| Privacy first | Public identity, discoverability, roster visibility, and shared objects default private until the user opts in |
| Server enforces permissions | SwiftUI hiding is not access control; every backend read and write checks account, ownership, visibility, and block state |
| Delete means delete path | Account deletion must remove or anonymize account-owned data and revoke sessions |
| Social after safety | Public comments and messages wait until block, report, moderation, rate-limit, and audit paths exist |

## Current Truth Boundary

Today, CurlPlan has a proven local `AccountSeasonPayload` season document, local roster membership, local attendance, local scorecards, and local export/import. The Worker/D1 source implements the selected production-shaped account-data boundary, and the custom handle/password service remains a quarantined local development verifier. Neither local implementation is deployed proof. The following production claims remain blocked:

| Blocked claim | Missing authority |
| --- | --- |
| Production sign in, sign out, account restore | Clerk application configuration, controlled TLS staging, native integration, production release configuration, recovery policy, and retained in-app screenflow proof |
| Cloud sync | Controlled D1 migration/staging proof, native state ownership, offline queue, conflict UI, and cross-device screenflow |
| Public profile or public roster | Profile visibility API, search/discovery rules, permission checks |
| Remote follow/friend/team graph | Relationship graph API and block enforcement |
| Shared spiel, bonspiel, team, RSVP, lineup, scorecard | Shared object ownership, membership, visibility, collaborator permissions |
| Reactions, comments, messages, notifications | Interaction API, moderation, notification delivery, rate limits |
| Report, block, content removal | Trust and safety workflows, audit logs, moderation state |

## Executable Contract Progress

The repo now includes a SwiftPM contract seam, a Clerk-authenticated Worker/D1 implementation, and a quarantined custom Node verifier. These prove local contracts but do not make production account, cloud, or social claims shippable.

| Artifact | Purpose |
| --- | --- |
| `ios/CurlPlan/AccountBackendAPI.swift` | Defines REST-shaped routes, response envelopes, machine-readable API errors, a session-scoped client, an in-memory transport, and a file-backed snapshot transport that can be replaced by a real network transport |
| `ios/CurlPlan/AccountHTTPBackend.swift` | Defines the async HTTP adapter, typed JSON request bodies (including the handle/password create and sign-in bodies), bearer session headers, URL path and query construction, success decoding, and API error envelope mapping |
| `ios/CurlPlan/AccountRuntime.swift` | Implements resumable development-verifier lifecycle checkpoints, keeps bearer sessions in memory, persists only account lifecycle metadata, and ignores even a saved custom-backend URL unless the process explicitly enables the development feature |
| `ios/CurlPlan/AuthView.swift` | Keeps the public preview credential-free and exposes password-gated retry or rollback only for an explicitly enabled custom verifier with an interrupted account lifecycle |
| `ios/CurlPlan/AccountSocialContracts.swift` | Defines account, password credential, session, profile, account-scoped season, sync receipt, offline mutation, relationship, shared object, interaction, report, moderation contract models, the backend snapshot envelope, and a salted-hash `PasswordHasher` so the in-app contract store rejects wrong passwords without storing plaintext |
| `api/` | Owns the selected production-shaped Clerk token verification, exact-origin CORS, account-scoped Worker routes, schema 4 D1 state, atomic version checks, idempotency receipts, export, restore, and deletion contracts |
| `services/account-backend/server.mjs` | Provides a quarantined local HTTP proof with NFKC/scrypt credentials, bounded sessions and abuse state, exact-origin CORS, authorization and blocking, versioned season changes, content-addressed record persistence, backup recovery, and fail-closed runtime configuration |
| `scripts/verify-account-backend.mjs` | Runs AS 01 through AS 12 backend slices over real HTTP against the local backend, including weak-password rejection and wrong-password sign-in rejection, and restarts the backend to prove deleted account state survives |
| `tests/CurlPlanCoreTests/AccountSocialContractTests.swift` | Proves the first backend truth rules: account restore across sessions, account deletion revocation, stale sync conflict, offline queue persistence, private/public profile search, block enforcement, server-backed follow/unfollow, shared object permissions, and report/moderation state |
| `tests/CurlPlanCoreTests/AccountBackendPersistenceTests.swift` | Proves the contract state survives backend restart: account season restore, account deletion revocation, public profile search, relationship graph, shared scorecard membership, interaction state, and moderation state |
| `tests/CurlPlanCoreTests/AccountHTTPBackendTests.swift` | Proves the network boundary: method and path selection, JSON request bodies, bearer session headers, query encoding, signed-out client guard, backend error envelopes, and network failure mapping |
| `tests/CurlPlanCoreTests/AccountRuntimeTests.swift` | Proves unconfigured app builds make zero backend account requests, configured builds create/import/sign out/restore through HTTP, and bearer session IDs are not persisted in defaults |
| `Package.swift` | Includes the contract source in the SwiftPM core target and points tests at the repo's lowercase `tests/CurlPlanCoreTests` path |

Production authentication is Clerk-issued identity validated by the Worker through issuer, audience, subject, time, algorithm, signing-use, and JWKS-rotation checks. The separate custom verifier accepts a handle and NFKC-normalized password for development contract exercises only; it stores asynchronous scrypt credentials, equalizes unknown-handle work, returns generic failures, and never persists plaintext. The native development runtime persists lifecycle metadata but neither passwords nor bearer session tokens.

The custom Node backend and any historical private deployment are verification infrastructure, not production infrastructure. Product copy must still treat production account, cloud, social, public profile, shared object, report, moderation, and notification claims as blocked until the app is wired to the selected managed plane and the matching staging and device screenflows are green.

## System Overview

```text
SwiftUI app
  -> Clerk client and managed session
  -> CurlPlan Cloudflare Worker
       -> Clerk JWT verification and exact-origin CORS
       -> D1 account profiles and schema 4 season documents
       -> versioned mutations and idempotency receipts
       -> export, restore, deletion, graph, shared object, and safety routes

Explicit development flag only
  -> quarantined custom handle/password verifier
  -> private persisted manifest plus content-addressed records
```

The backend becomes the source of truth for account identity, cloud sync, public discoverability, relationship state, shared objects, social interactions, reports, blocks, and deletion. The local app remains the fast working copy and must label pending, failed, conflicted, private, and server-confirmed states distinctly.

## Components

| Component | Responsibility | Inputs | Outputs | Owner |
| --- | --- | --- | --- | --- |
| Auth service | Prove production account identity and issue revocable managed sessions | Clerk sign-in or recovery flow | Account ID, access token, session state | Clerk |
| Account API | Manage profile, settings, deletion, export, device sessions | Authenticated requests | Account profile, privacy settings, export package, deletion status | Backend |
| Migration adapter | Attach existing local `AccountSeasonPayload` to an account without corrupting local state | Local export JSON, account ID, schema version | Account-scoped season document and migration receipt | App + backend |
| Sync engine | Replicate account-scoped season state across devices | Local changes, server changes, version vector | Synced document, pending queue, conflict receipts | App + backend |
| Public identity service | Control handles, public profile, searchability, home club display | Profile settings, privacy flags | Search index rows and profile payloads | Backend |
| Relationship graph | Store follows, friend requests, team links, blocks, invitations | Account IDs, target IDs, relationship action | Relationship edge, request state, block state | Backend |
| Shared object service | Own shared spiels, bonspiels, teams, attendance, scorecards | Object mutations and membership context | Authorized shared object state | Backend |
| Social interaction service | Store reactions, comments, messages, invites, notifications | Interaction mutation, object ID, actor ID | Interaction record and notification event | Backend |
| Trust and safety service | Enforce reports, block visibility, moderation, rate limits, audit logs | Reports, content events, admin decisions | Hidden content, enforcement receipt, audit trail | Backend |
| Review gate | Prevent premature product claims | Changed files, API coverage, tests, claim scans | Pass/fail review packet | Maintainer |

## Data Model Direction

Use stable server IDs for remote objects and preserve local IDs for migration receipts. Do not expose sequential IDs in client URLs or payloads where authorization is still required.

| Entity | Required fields | Notes |
| --- | --- | --- |
| `Account` | `id`, `createdAt`, `status`, `deletedAt` | Status supports active, suspended, deletion_pending, deleted |
| `Session` | `id`, `accountID`, `deviceID`, `createdAt`, `expiresAt`, `revokedAt` | Logout revokes server-side session |
| `AccountProfile` | `accountID`, `handle`, `displayName`, `homeClub`, `avatarURL`, `visibility`, `searchable` | Handle uniqueness enforced server-side |
| `SeasonDocument` | `id`, `accountID`, `schemaVersion`, `version`, `body`, `updatedAt` | `body` starts as current `AccountSeasonPayload`; normalize before write |
| `SeasonChange` | `id`, `seasonID`, `actorID`, `baseVersion`, `patch`, `createdAt`, `clientMutationID` | Enables receipts, retry, and conflict explanation |
| `RelationshipEdge` | `id`, `actorID`, `targetID`, `type`, `state`, `createdAt` | Types: follow, friend_request, teammate, block, invite |
| `SharedObject` | `id`, `type`, `ownerID`, `visibility`, `seasonLinkID`, `createdAt` | Types: spiel, bonspiel, team, roster, lineup, scorecard |
| `Membership` | `id`, `objectID`, `accountID`, `role`, `state` | Roles: owner, admin, teammate, invited, viewer |
| `Interaction` | `id`, `objectID`, `actorID`, `type`, `body`, `state`, `createdAt`, `deletedAt` | Types: RSVP, invite, reaction, comment, message |
| `Report` | `id`, `reporterID`, `targetType`, `targetID`, `reason`, `state`, `createdAt` | State drives moderation queue |
| `AuditEvent` | `id`, `actorID`, `action`, `targetType`, `targetID`, `metadata`, `createdAt` | Redact sensitive payloads |

## API Contract

| Area | Endpoints | Required error states |
| --- | --- | --- |
| Auth | `POST /auth/sign-in`, `POST /auth/refresh`, `POST /auth/sign-out`, `GET /sessions` | invalid credentials, expired session, revoked session, rate limited |
| Account | `GET /me`, `PATCH /me/profile`, `POST /me/export`, `DELETE /me` | unauthorized, validation failed, deletion pending, export not ready |
| Migration | `POST /me/season/import-local`, `GET /me/season` | schema unsupported, merge conflict, account already has season |
| Sync | `GET /season/{id}?since=version`, `POST /season/{id}/changes`, `POST /season/{id}/resolve-conflict` | stale base version, conflict, offline queued, server unavailable |
| Public identity | `GET /profiles/{handle}`, `GET /profiles/search`, `PATCH /me/privacy` | private profile, blocked, not searchable |
| Relationships | `POST /relationships`, `PATCH /relationships/{id}`, `DELETE /relationships/{id}` | blocked, duplicate request, unauthorized target |
| Shared objects | `POST /shared-objects`, `GET /shared-objects/{id}`, `PATCH /shared-objects/{id}` | not member, insufficient role, object private, stale version |
| Interactions | `POST /interactions`, `PATCH /interactions/{id}`, `DELETE /interactions/{id}` | blocked, rate limited, hidden by moderation, closed object |
| Trust and safety | `POST /reports`, `POST /blocks`, `DELETE /blocks/{id}` | duplicate report, blocked target hidden, moderation locked |

## Phase Roadmap

### Phase 1: Account Foundation

Build real account claims: sign in, sign out, delete account, export data, restore on a second device.

Current status (verified locally 2026-08-24): Clerk plus Worker/D1 is the sole selected production plane. Worker token, CORS, atomic data, migration, lifecycle, export, restore, and deletion contracts pass locally. The custom credential service passes its abuse, authorization, persistence, and recovery contracts while remaining quarantined by default.

- No current private or public deployment was queried or changed in this audit.
- The native development runtime is disabled unless both its feature flag and backend URL are explicit. Only interrupted development-account setup exposes retry and rollback controls.
- Release and Archive remain unproven for managed identity, and the shipped preview retains local-only claims.

Remaining for Phase 1 ship: configure Clerk and Worker/D1 in a controlled TLS staging environment, migrate an isolated D1 target, connect the native app to that selected boundary, prove create/sign-in/recovery/export/delete and second-device restore on real simulator or device surfaces, complete password/account recovery policy, and inspect the signed archive. Product copy stays gated until those proofs are green.

Deliverables:

1. Auth provider integration with revocable sessions.
2. `AccountProfile` and account-scoped `SeasonDocument`.
3. Local `AccountSeasonPayload` migration adapter with schema validation and migration receipt.
4. Settings account surface: signed out, signed in, sync unavailable, export, delete account, sign out.
5. Two-device restore test fixture.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Sign in | Account A can authenticate, receives server session, and UI labels the session as server-backed |
| Sign out | Session revokes server-side and local account-only views become signed-out |
| Delete account | Account deletion revokes sessions and removes or anonymizes account-owned data |
| Export data | Account export includes profile, season document, shared objects owned by account, and audit-safe metadata |
| Restore on new device | Account A signs in on device B and sees the same season from backend state |
| Claim control | No local-only screen claims cloud restore unless response came from account API |

### Phase 2: Cloud Sync Without Social

Move season truth from single-device persistence to account-backed sync with conflict handling.

Deliverables:

1. `SeasonChange` log with `baseVersion`, `clientMutationID`, server version, and mutation receipt.
2. Offline queue that labels pending changes and retries safely.
3. Conflict state for stale base versions.
4. Local-to-server and server-to-local reducer tests for all `SeasonDomain` changes.
5. Settings sync diagnostics: last synced, pending, failed, conflicted.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Local edits sync | Device A edits season, server stores version, device B receives same state |
| Offline edits | Device A queues changes offline, labels pending, syncs after reconnect |
| Relaunch | Pending and synced states survive app relaunch |
| Failed sync | User sees retryable failure without losing local work |
| Conflict resolution | Stale version produces a conflict receipt with keep local, keep server, or merge where safe |
| No silent cloud claim | UI distinguishes local, pending, failed, conflicted, and synced |

### Phase 3: Public Identity Layer

Add optional public profiles, handles, avatar/name, home club, and visibility controls.

Deliverables:

1. Public profile API with `visibility` and `searchable` flags.
2. Handle reservation and validation.
3. Profile search that excludes private, blocked, suspended, and deleted accounts.
4. Privacy settings screen with preview of public fields.
5. Block-aware profile fetch.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Private default | New accounts are not discoverable unless opted in |
| Public discoverability | Public searchable profile appears in search with API-backed fields |
| Block enforcement | Blocking hides profile and interactions server-side and in UI |
| Claim source | Every visible public profile field comes from `AccountProfile`, not local roster data |

### Phase 4: Relationship Graph

Replace local circle semantics with server-backed follow, friend, teammate, invitation, and block state.

Deliverables:

1. Relationship edge API.
2. Local cache of account-backed graph with pending state.
3. Follow/unfollow, friend request, teammate invite, block/unblock flows.
4. Feed filters that use server-backed graph state.
5. Authorization tests for blocked and private accounts.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Follow/unfollow | Device A follows B, server stores edge, device A and second device agree |
| Request state | Friend/team requests show pending, accepted, declined, and revoked states |
| Feed filter | Following feed uses server relationship state and excludes blocked/private content |
| Block enforcement | Blocked users cannot view, follow, invite, message, comment, or appear in search |

### Phase 5: Shared Curling Objects

Introduce shared spiels, bonspiels, teams, attendance, lineups, and scorecards with ownership.

Deliverables:

1. Shared object API with owner, role, visibility, and version.
2. Membership model for teams, spiels, bonspiels, and scorecards.
3. RSVP and attendance backed by shared object membership.
4. Roster, lineup, and scorecard permission model.
5. Two-account tests for shared object visibility and edits.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Join shared spiel | Account A creates a spiel, invites B, B accepts, both see same object |
| RSVP | B toggles RSVP, A sees updated count after server confirmation |
| Roster/lineup | Only authorized roles can change roster or lineup |
| Scorecard | Scorecard changes are versioned, permission-checked, and visible to members |
| Boundary | Non-members and blocked accounts receive denial from API and UI |

### Phase 6: Social Interactions

Add low-risk interactions first: RSVP, teammate invites, and reactions. Add comments and messages only after trust and safety is live.

Deliverables:

1. Interaction API for RSVP, invite, reaction, comment, and message.
2. Create, edit, delete, report, and block paths for every interaction type.
3. Notification events for invites, RSVP changes, reactions, comments, messages, reports, and moderation outcomes.
4. Rate limits for interactions and notifications.
5. Hidden/deleted/moderated states in UI.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Low-risk interactions | RSVP, invite, and reaction have create/delete paths and server receipts |
| Comments/messages | Comments and messages wait until report, block, edit, delete, moderation, and notification paths exist |
| Notification behavior | Notifications are deduped, permission-aware, and suppress blocked users |
| User control | Users can delete their interactions and report others from the same surface |

### Phase 7: Trust, Safety, And Compliance

Ship before public comments/messages.

Deliverables:

1. Report flow and moderation queue.
2. Block enforcement across search, profile, relationships, shared objects, interactions, and notifications.
3. Abuse throttles and audit logs.
4. Privacy policy, terms, App Store privacy labels, data retention policy.
5. Account deletion and data export verification.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Report handling | Reported content can be hidden, reviewed, restored, or removed with audit trail |
| Block coverage | Blocked users cannot interact through direct API calls, not only hidden UI |
| Rate limits | Auth, follow, invite, reaction, comment, message, and report endpoints throttle abuse |
| Compliance | Privacy labels and policy match actual data collection and sharing |
| Deletion | Delete account revokes sessions and removes/anonymizes data according to retention policy |

## Required Screenflow Passes

| ID | Flow | Proof |
| --- | --- | --- |
| AS 01 | Account A signs up, creates season data, signs out, signs back in | API integration test plus iOS UI proof |
| AS 02 | Account A signs in on device B and restores same season | two-simulator or simulator plus API fixture proof |
| AS 03 | Account A deletes account and all sessions lose access | backend auth test plus UI proof |
| AS 04 | Device A edits offline, relaunches, reconnects, syncs | offline queue unit test plus UI proof |
| AS 05 | Device A and B edit same field; conflict is shown and resolved | sync conflict integration test plus UI proof |
| AS 06 | Private profile is not searchable; public profile is searchable | backend authorization test plus UI proof |
| AS 07 | A follows/unfollows B; second device and feed agree | graph API test plus UI proof |
| AS 08 | A blocks B; B cannot fetch profile, interact, invite, or appear in search | negative API tests plus UI proof |
| AS 09 | A creates shared spiel, invites B, B RSVPs, both see count | shared object integration test plus UI proof |
| AS 10 | Unauthorized account attempts roster/lineup/scorecard edit and is denied | backend authorization test |
| AS 11 | Reaction/comment/message create, edit, delete, report, and moderation hide state | interaction integration test plus UI proof |
| AS 12 | Privacy export and delete account artifacts match policy | backend compliance test |

## Backend Truth Tests

| Test class | Must prove |
| --- | --- |
| Auth tests | session creation, refresh, revocation, expiry, rate limit, deleted account denial |
| Authorization tests | owner/member/blocked/private checks on every endpoint |
| Migration tests | valid local `AccountSeasonPayload`, invalid schema, duplicate import, existing remote season, idempotent retry |
| Sync tests | base version, conflict, retry, dedupe by `clientMutationID`, cross-device propagation |
| Graph tests | follow, unfollow, friend request, invite, block, unblock, graph cache invalidation |
| Shared object tests | object visibility, role checks, member-only reads, stale version denial |
| Interaction tests | create, edit, delete, report, hidden, moderated, rate-limited, notification suppression |
| Deletion/export tests | export completeness, session revocation, data removal/anonymization, retention exceptions |

## Release Gates

1. Add account/social rows to the feature review matrix before writing UI copy.
2. Expand the claim scan when code introduces account/social text.
3. Run backend authorization tests before any public profile, graph, shared object, or interaction release.
4. Run two-account screenflows before any screen claims remote visibility.
5. Keep local-only language until the API response is the source of truth.
6. Keep comments/messages behind a feature flag until trust and safety is green.

## Stop Doing

1. Stop treating local circle membership as a social graph.
2. Stop treating export/import as cloud restore.
3. Stop using public, shared, follow, RSVP, reaction, comment, message, invite, report, or notification language without backend receipts.
4. Stop adding comments or messages before block, report, moderation, audit, and rate-limit paths exist.

## Highest-Leverage First Build

Build account foundation plus sync diagnostics before public identity. That creates honest account restore, gives the app a server truth boundary, and prevents social features from becoming decorative local state with public-sounding labels.
