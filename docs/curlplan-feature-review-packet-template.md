# CurlPlan Feature Review Packet

Date:

Reviewer:

Change:

## Changed Files

| Path | Source |
| --- | --- |
|  | `git diff`, PR, or manual list |

## Impacted Feature Rows

| Row ID | Feature area | Why impacted | Current rating |
| --- | --- | --- | --- |
|  |  |  | Green / Yellow / Red |

## Truth Loop Review

| Dimension | Evidence | Result |
| --- | --- | --- |
| Source owner named |  | Pass / Fail / N/A |
| Entry path reachable |  | Pass / Fail / N/A |
| Completion path works |  | Pass / Fail / N/A |
| Correction or recovery exists |  | Pass / Fail / N/A |
| Propagation uses same source |  | Pass / Fail / N/A |
| Relaunch persistence proven |  | Pass / Fail / N/A |
| Claim control clean |  | Pass / Fail / N/A |

## Commands Run

| Command | Result | Evidence |
| --- | --- | --- |
| `scripts/feature_review_matrix_check.sh ...` |  |  |
| `swift test --scratch-path /tmp/curlplan-spm-build` |  |  |
| `xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived-status CODE_SIGNING_ALLOWED=NO build` |  |  |
| `rg -in "likes\|comments\|public roster\|here now\|GPS verification\|official result" ios/CurlPlan ios/CurlPlanUITests tests/CurlPlanCoreTests -g '*.swift'` |  |  |

## Screenflow Evidence

| Screenflow | Required? | Result | Evidence |
| --- | --- | --- | --- |
| SF 01 setup | Yes / No |  |  |
| SF 02 results | Yes / No |  |  |
| SF 03 stops | Yes / No |  |  |
| SF 04 roster/profile | Yes / No |  |  |
| SF 05 attendance | Yes / No |  |  |
| SF 06 bonspiel roster/lineup | Yes / No |  |  |
| SF 07 bonspiel scorecard | Yes / No |  |  |
| SF 08 locker/discover | Yes / No |  |  |
| SF 09 settings recovery | Yes / No |  |  |
| SF 10 accessibility/small screen | Yes / No |  |  |

## Residual Risk

| Risk | Owner | Disposition |
| --- | --- | --- |
|  |  | none / follow-up / blocker |

## Release Call

| Field | Value |
| --- | --- |
| Lowest row rating | Green / Yellow / Red |
| Ship decision | Ship / Hold / Remove claim / Rebuild loop |
| Required follow-up |  |

## Definition Of Done Check

1. Changed files are mapped to feature review rows.
2. Every impacted row has a truth owner.
3. Every impacted row has an entry, completion, correction, propagation, and persistence path.
4. Unsupported authority scans return no unbacked matches.
5. Model proof is run or explicitly marked not applicable with a reason.
6. UI proof is run or explicitly marked not applicable with a reason.
7. Build proof is run when Swift source or Xcode project files change.
8. Commands, results, residual risks, and lowest feature rating are recorded.
9. Final release call uses the lowest impacted rating.
