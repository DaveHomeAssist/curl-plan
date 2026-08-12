# CurlPlan Feature Review Gate Implementation Plan

Date: 2026-06-27

Target surface: `ios/CurlPlan.xcodeproj`

Related docs:

| Doc | Role |
| --- | --- |
| `docs/curlplan-feature-review-matrix-2026-06-27.md` | Feature-level review contract |
| `docs/curlplan-visible-claim-ledger-2026-06-26.md` | Visible claim truth ledger |
| `docs/curlplan-ui-screenflow-evidence-2026-06-26.md` | UI loop evidence |
| `docs/curlplan-rigorous-truth-implementation-plan-2026-06-26.md` | Full truth-loop acceptance standard |

## Goal

Make the feature review matrix enforceable enough that a future CurlPlan change cannot quietly ship a misleading feature, stale claim, unfinishable loop, or unproven workflow.

## Implied Goal

Preserve user trust by turning every app feature into a reviewed local truth loop: a named source of truth, reachable UI entry, successful completion path, correction path, relaunch persistence proof, claim scan, and named test evidence.

## Operating Constraints

| Constraint | Rule |
| --- | --- |
| Local app boundary | Do not require a backend, cloud sync, official scoring feed, social graph, GPS verification, or public publishing path |
| Existing architecture | Keep `AppData` as the persisted season document and `Store` as the mutation boundary |
| Review scope | Keep checks feature-focused; do not block a Passport-only change on unrelated bonspiel UI tests unless shared state is touched |
| Git reliability | Avoid broad `git status` as a required gate in this iCloud-backed checkout; prefer bounded changed-file and diff checks |
| Human review | The gate should produce a compact review packet, not a second product spec |
| Proof standard | Model tests, UI screenflow evidence, build, and static claim scans must be named, not implied |

## System Overview

The feature review gate maps changed files to feature rows, maps feature rows to required proof, runs the smallest sufficient checks, and outputs a review packet that a maintainer can use before merging or shipping.

```text
Changed files
  -> feature impact mapper
  -> feature review matrix rows
  -> required proof plan
  -> model/build/scan/UI evidence
  -> review packet
  -> commit or release decision
```

## Implemented Artifacts

| Artifact | Status | Role |
| --- | --- | --- |
| `docs/curlplan-feature-review-matrix-2026-06-27.md` | Implemented | Row IDs, risk tiers, claim risks, file map, proof commands, revalidation rules |
| `scripts/feature_review_matrix_check.sh` | Implemented | Changed-file mapper, proof-command output, unsupported-claim scan, unmapped-source failure |
| `Makefile` | Implemented | One-command local runner: `make feature-review` |
| `.github/workflows/verify.yml` | Implemented | CI-safe gate that runs claim scan and PR base diff mapping without simulator-only checks |
| `docs/curlplan-feature-review-packet-template.md` | Implemented | Required packet structure for changed files, impacted rows, evidence, residual risk, release call |
| `docs/reviews/curlplan-feature-review-2344504-2026-06-27.md` | Implemented | Completed review packet for the prior Passport/Spiels truth-loop change |

## Components

| Component | Responsibility | Inputs | Outputs | Owner |
| --- | --- | --- | --- | --- |
| Feature review matrix | Defines feature rows, truth owners, proof, and review triggers | Current app domains and claim ledger | Review rows and feature ratings | CurlPlan maintainer |
| File-to-feature map | Maps source paths to affected feature rows | Changed file paths | Impacted feature row IDs | CurlPlan maintainer |
| Proof command registry | Stores copyable commands and test names for each row | Matrix rows and test suite names | Required proof checklist | CurlPlan maintainer |
| Claim scan gate | Finds unsupported public, official, GPS, live, likes, comments, and social-authority wording | Swift source and UI tests | Pass/fail claim scan result | CurlPlan maintainer |
| Review packet generator | Produces the human-readable feature review packet | Impacted rows and evidence results | Markdown review packet | CurlPlan maintainer |
| Release decision rule | Decides whether the change can ship | Review packet and evidence | Green, Yellow, or Red release call | CurlPlan maintainer |

## Interface Contracts

| Interface | Format | Contract | Failure handling |
| --- | --- | --- | --- |
| Changed files to feature rows | Markdown table or script output | Every touched source path maps to at least one feature row or `docs-only` | Missing mapping blocks release with Yellow |
| Feature row to proof | Matrix row with test names and commands | Each row lists model proof, UI proof, claim scan, and build relevance | Missing proof blocks release with Yellow |
| Claim scan | `rg` command output | No unsupported authority matches in active Swift surfaces | Match blocks release until removed or ledger-backed |
| Evidence packet | Markdown | Lists impacted rows, commands run, result, residual risk, and release call | Missing packet blocks release with Yellow |
| Status update | Status Runs or repo doc | Final light matches lowest impacted feature row | Source unreachable is Grey, not Green |

## Implementation Plan

### Phase 1: Immediate Unblockers

Goal: make the current matrix usable in the next feature review without writing new automation.

Tasks:

1. Add stable row IDs to `docs/curlplan-feature-review-matrix-2026-06-27.md`.
2. Add columns for `Risk tier`, `Claim risk`, and `Required proof commands`.
3. Add a small `File Impact Map` section that maps app files to matrix row IDs.
4. Add a `Review Packet Template` section with fields for changed files, impacted rows, commands run, evidence, and release call.
5. Document the bounded git checks that work in this checkout.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Row IDs | Every feature row has a stable ID such as `FR-SETUP`, `FR-RESULTS`, or `FR-BONSPIEL-SCORE` |
| Risk tier | Every row has High, Medium, or Low risk based on likelihood of misleading the user |
| Claim risk | Every row states allowed claims and banned claims |
| Proof commands | Every row names at least one exact model, UI, build, or scan command |
| File map | Every active CurlPlan Swift file maps to one or more feature rows |
| Review template | A reviewer can fill out the packet without inventing headings |

### Phase 2: Structural Fixes

Goal: make the gate repeatable and hard to skip.

Tasks:

1. Add `scripts/feature_review_matrix_check.sh`.
2. The script accepts changed file paths or reads a bounded diff for named paths.
3. The script prints impacted feature rows.
4. The script prints required proof commands for those rows.
5. The script runs the unsupported-claim scan.
6. The script exits nonzero when a touched source path has no feature-row mapping.
7. Add `docs/curlplan-feature-review-packet-template.md`.

Definition of done:

| Requirement | Done when |
| --- | --- |
| Script exists | `scripts/feature_review_matrix_check.sh` is executable and documented |
| Impact output | Running the script on changed source files prints feature row IDs and names |
| Proof output | Running the script prints exact proof commands for impacted rows |
| Unmapped files | Unmapped source files produce a clear failure |
| Claim scan | Unsupported claim matches fail the script with the matching line |
| Template | Review packet template matches the matrix fields and gate output |

### Phase 3: Scale Improvements

Goal: make the gate part of normal repo operation without over-testing unrelated loops.

Tasks:

1. Add a package or Makefile task such as `make feature-review`.
2. Add CI wiring if this repo gets active CI for the iOS target.
3. Add a `docs/reviews/` folder for completed review packets.
4. Add a recurring review date or revalidation rule for high-risk feature rows.
5. Track false positives and split broad triggers into required vs optional triggers.

Definition of done:

| Requirement | Done when |
| --- | --- |
| One command | Maintainer can run one command to get impacted rows and required proof |
| Evidence storage | Completed review packets are saved under `docs/reviews/` |
| CI optionality | CI runs non-simulator checks without requiring local-only simulator artifacts |
| Revalidation | High-risk rows have a stated recheck trigger |
| Review load | Required triggers are specific enough that review noise stays low |

## Feature Review Definition Of Done

A future feature change is done only when all of these are true:

1. Changed files are mapped to feature review rows.
2. Every impacted row has a truth owner.
3. Every impacted row has an entry, completion, correction, propagation, and persistence path.
4. Unsupported authority scans return no unbacked matches.
5. Model proof is run or explicitly marked not applicable with a reason.
6. UI proof is run or explicitly marked not applicable with a reason.
7. Build proof is run when Swift source or Xcode project files change.
8. A review packet records commands, results, residual risks, and the lowest feature rating.
9. The final release call uses the lowest rating across impacted rows.

## Gate Definition Of Done

The feature review gate itself is done when:

1. The matrix has stable row IDs, risk tier, claim risk, proof commands, and review triggers.
2. Active Swift source paths are mapped to matrix rows.
3. A script can print impacted rows from a changed-file list.
4. The script fails on unmapped source paths.
5. The script runs the unsupported-claim scan.
6. A review packet template exists.
7. One completed packet is created for a real or sample CurlPlan change.
8. The docs explain which checks are local-only and which are CI-safe.

CI-safe checks are `make feature-review`, path mapping, unmapped-source failure, and unsupported-claim scans. Local-only checks are simulator builds, simulator UI tests, relaunch screenflows, and manual screenflow evidence that require installed Apple tooling or a booted simulator.

## Success Metrics

| Metric | Target |
| --- | --- |
| Mapping coverage | 100 percent of active `ios/CurlPlan/*.swift` files map to feature rows |
| Proof coverage | 100 percent of matrix rows name at least one proof command or evidence source |
| Claim scan | 0 unsupported authority matches in active Swift source |
| Review packet completeness | 100 percent of feature changes include impacted rows, evidence, rating, and residual risk |
| False-positive load | Required review triggers are narrow enough that unrelated changes do not demand full app proof |

## Trade-offs

| Trade-off | Decision |
| --- | --- |
| More process vs faster edits | Add only the smallest gate that prevents misleading user-facing claims |
| Full UI suite vs impacted UI proof | Prefer impacted screenflow proof unless shared state or navigation changes require broader testing |
| CI enforcement vs local simulator reality | Keep simulator-heavy proof local until CI can reliably run iOS UI tests |
| Strict mapping vs developer flexibility | Fail unmapped source files, but allow docs-only and test-only classifications |

## Stop Doing

1. Stop treating the matrix as a static audit artifact.
2. Stop accepting feature changes without naming impacted rows.
3. Stop relying on broad claims like "tests passed" without linking tests to feature rows.
4. Stop expanding app copy into public, official, GPS, live, or social authority without a real source of truth.

## Highest-Leverage Refactor

Create the file-to-feature map and proof command registry first. That turns the matrix from a reference document into a release gate without requiring a large automation build.
