#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "feature-review: rg is required" >&2
  exit 2
fi

rows_file=$(mktemp "${TMPDIR:-/tmp}/curlplan-feature-rows.XXXXXX")
unmapped_file=$(mktemp "${TMPDIR:-/tmp}/curlplan-feature-unmapped.XXXXXX")
files_file=$(mktemp "${TMPDIR:-/tmp}/curlplan-feature-files.XXXXXX")

cleanup() {
  rm -f "$rows_file" "$unmapped_file" "$files_file"
}
trap cleanup EXIT INT TERM

add_rows() {
  for row in "$@"; do
    printf '%s\n' "$row" >> "$rows_file"
  done
}

mark_unmapped() {
  printf '%s\n' "$1" >> "$unmapped_file"
}

REVIEW_PATHS="ios/CurlPlan ios/CurlPlan.xcodeproj ios/CurlPlanUITests tests/CurlPlanCoreTests docs scripts services Package.swift Makefile .github/workflows"

if [ "$#" -gt 0 ]; then
  for path in "$@"; do
    printf '%s\n' "$path" >> "$files_file"
  done
elif [ -n "${FEATURE_REVIEW_BASE:-}" ]; then
  git diff --name-only "$FEATURE_REVIEW_BASE"...HEAD -- $REVIEW_PATHS 2>/dev/null | sort -u > "$files_file"
else
  {
    git diff --name-only HEAD -- $REVIEW_PATHS 2>/dev/null || true
    git diff --cached --name-only -- $REVIEW_PATHS 2>/dev/null || true
    git ls-files --others --exclude-standard -- $REVIEW_PATHS 2>/dev/null || true
  } | sort -u > "$files_file"
fi

if [ ! -s "$files_file" ]; then
  echo "Feature review gate: no changed files in bounded CurlPlan review scope."
  echo "Claim scan: running anyway."
fi

while IFS= read -r path; do
  [ -n "$path" ] || continue
  case "$path" in
    ios/CurlPlan/AccountBackendAPI.swift)
      add_rows FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    ios/CurlPlan/AccountHTTPBackend.swift)
      add_rows FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    ios/CurlPlan/AccountRuntime.swift)
      add_rows FR-ACCOUNT FR-SYNC FR-SETTINGS FR-CLAIMS
      ;;
    ios/CurlPlan/AccountSocialContracts.swift)
      add_rows FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    ios/CurlPlan/Models.swift)
      add_rows FR-SETUP FR-PASSPORT FR-STOPS FR-RESULTS FR-ROSTER FR-CIRCLE FR-LOCKER FR-ATTENDANCE FR-BONSPIEL-ROSTER FR-BONSPIEL-LINEUP FR-BONSPIEL-SCORE FR-SETTINGS FR-CLAIMS
      ;;
    ios/CurlPlan/CurlPlanApp.swift)
      add_rows FR-SETUP FR-SETTINGS FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/RootView.swift)
      add_rows FR-SETUP FR-PASSPORT FR-LOCKER FR-ROSTER FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/PassportView.swift)
      add_rows FR-PASSPORT FR-STOPS FR-RESULTS FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/LiveMapView.swift)
      add_rows FR-STOPS FR-PASSPORT FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/StopDetailView.swift)
      add_rows FR-STOPS FR-RESULTS FR-ROSTER FR-CIRCLE FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/LockerRoomView.swift)
      add_rows FR-LOCKER FR-RESULTS FR-CIRCLE FR-ATTENDANCE FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/RosterView.swift)
      add_rows FR-ROSTER FR-CIRCLE FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/CurlerProfileView.swift)
      add_rows FR-ROSTER FR-CIRCLE FR-STOPS FR-RESULTS FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/SpielsView.swift)
      add_rows FR-ATTENDANCE FR-BONSPIEL-ROSTER FR-BONSPIEL-LINEUP FR-BONSPIEL-SCORE FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/SettingsSheet.swift)
      add_rows FR-SETTINGS FR-SETUP FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/Components.swift|ios/CurlPlan/Theme.swift)
      add_rows FR-A11Y FR-CLAIMS
      ;;
    ios/CurlPlan/Assets.xcassets/*|ios/CurlPlan/PrivacyInfo.xcprivacy|ios/CurlPlan.xcodeproj/*)
      add_rows build-support
      ;;
    ios/CurlPlan/*.swift)
      mark_unmapped "$path"
      ;;
    ios/CurlPlanUITests/*.swift|ios/CurlPlanUITests/*/*.swift)
      add_rows test-support FR-A11Y FR-CLAIMS
      ;;
    tests/CurlPlanCoreTests/AccountBackendAPITests.swift|tests/CurlPlanCoreTests/AccountBackendPersistenceTests.swift|tests/CurlPlanCoreTests/AccountHTTPBackendTests.swift|tests/CurlPlanCoreTests/AccountRuntimeTests.swift|tests/CurlPlanCoreTests/AccountSocialContractTests.swift|Tests/CurlPlanCoreTests/AccountBackendAPITests.swift|Tests/CurlPlanCoreTests/AccountBackendPersistenceTests.swift|Tests/CurlPlanCoreTests/AccountHTTPBackendTests.swift|Tests/CurlPlanCoreTests/AccountRuntimeTests.swift|Tests/CurlPlanCoreTests/AccountSocialContractTests.swift)
      add_rows test-support FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    tests/CurlPlanCoreTests/*.swift|Tests/CurlPlanCoreTests/*.swift)
      add_rows test-support FR-SETUP FR-PASSPORT FR-STOPS FR-RESULTS FR-ROSTER FR-CIRCLE FR-LOCKER FR-ATTENDANCE FR-BONSPIEL-ROSTER FR-BONSPIEL-LINEUP FR-BONSPIEL-SCORE FR-SETTINGS FR-CLAIMS
      ;;
    Package.swift)
      add_rows build-support FR-SETUP FR-PASSPORT FR-STOPS FR-RESULTS FR-ROSTER FR-CIRCLE FR-LOCKER FR-ATTENDANCE FR-BONSPIEL-ROSTER FR-BONSPIEL-LINEUP FR-BONSPIEL-SCORE FR-SETTINGS FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    services/account-backend/*|scripts/verify-account-backend.mjs)
      add_rows gate-support FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY FR-CLAIMS
      ;;
    Makefile|scripts/feature_review_matrix_check.sh|scripts/*)
      add_rows gate-support
      ;;
    .github/workflows/*)
      add_rows gate-support build-support
      ;;
    docs/curlplan-accounts-social-roadmap-*.md)
      add_rows docs-only FR-ACCOUNT FR-SYNC FR-PUBLIC-ID FR-RELATIONSHIP FR-SHARED-OBJECTS FR-SOCIAL FR-TRUST-SAFETY
      ;;
    docs/curlplan-feature-review-*.md|docs/reviews/*.md)
      add_rows docs-only gate-support
      ;;
    docs/*.md)
      add_rows docs-only
      ;;
    ios/*|tests/*|Tests/*)
      mark_unmapped "$path"
      ;;
    *)
      :
      ;;
  esac
done < "$files_file"

echo "Feature review gate"
echo
echo "Changed files:"
if [ -s "$files_file" ]; then
  sed 's/^/- /' "$files_file"
else
  echo "- none in bounded scope"
fi

echo
echo "Impacted rows:"
if [ -s "$rows_file" ]; then
  sort -u "$rows_file" | while IFS= read -r row; do
    case "$row" in
      FR-SETUP) echo "- FR-SETUP: Setup and season start" ;;
      FR-PASSPORT) echo "- FR-PASSPORT: Passport summary" ;;
      FR-STOPS) echo "- FR-STOPS: Stop visits and map" ;;
      FR-RESULTS) echo "- FR-RESULTS: Results" ;;
      FR-ROSTER) echo "- FR-ROSTER: Roster and profiles" ;;
      FR-CIRCLE) echo "- FR-CIRCLE: Circle membership" ;;
      FR-LOCKER) echo "- FR-LOCKER: Locker feed" ;;
      FR-ATTENDANCE) echo "- FR-ATTENDANCE: Spiel attendance" ;;
      FR-BONSPIEL-ROSTER) echo "- FR-BONSPIEL-ROSTER: Bonspiel roster" ;;
      FR-BONSPIEL-LINEUP) echo "- FR-BONSPIEL-LINEUP: Bonspiel lineup" ;;
      FR-BONSPIEL-SCORE) echo "- FR-BONSPIEL-SCORE: Bonspiel scorecard" ;;
      FR-SETTINGS) echo "- FR-SETTINGS: Settings recovery" ;;
      FR-A11Y) echo "- FR-A11Y: Small screen and accessibility reachability" ;;
      FR-CLAIMS) echo "- FR-CLAIMS: Unsupported authority guardrails" ;;
      FR-ACCOUNT) echo "- FR-ACCOUNT: Account foundation" ;;
      FR-SYNC) echo "- FR-SYNC: Cloud sync without social" ;;
      FR-PUBLIC-ID) echo "- FR-PUBLIC-ID: Public identity" ;;
      FR-RELATIONSHIP) echo "- FR-RELATIONSHIP: Relationship graph" ;;
      FR-SHARED-OBJECTS) echo "- FR-SHARED-OBJECTS: Shared curling objects" ;;
      FR-SOCIAL) echo "- FR-SOCIAL: Social interactions" ;;
      FR-TRUST-SAFETY) echo "- FR-TRUST-SAFETY: Trust, safety, and compliance" ;;
      docs-only) echo "- docs-only: Documentation-only change" ;;
      gate-support) echo "- gate-support: Feature review gate tooling or docs" ;;
      test-support) echo "- test-support: Test support change" ;;
      build-support) echo "- build-support: Build/package change" ;;
      *) echo "- $row" ;;
    esac
  done
else
  echo "- none"
fi

echo
echo "Required proof commands:"
if [ -s "$rows_file" ]; then
  if grep -Eq 'FR-SETUP|FR-PASSPORT|FR-STOPS|FR-RESULTS|FR-ROSTER|FR-CIRCLE|FR-LOCKER|FR-ATTENDANCE|FR-BONSPIEL-ROSTER|FR-BONSPIEL-LINEUP|FR-BONSPIEL-SCORE|FR-SETTINGS' "$rows_file"; then
    echo "- swift test --scratch-path /tmp/curlplan-spm-build"
  fi
  if grep -Eq 'build-support|FR-A11Y|FR-SETUP|FR-PASSPORT|FR-STOPS|FR-RESULTS|FR-ROSTER|FR-CIRCLE|FR-LOCKER|FR-ATTENDANCE|FR-BONSPIEL-ROSTER|FR-BONSPIEL-LINEUP|FR-BONSPIEL-SCORE|FR-SETTINGS' "$rows_file"; then
    echo "- xcodebuild -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/curlplan-truth-derived-status CODE_SIGNING_ALLOWED=NO build"
  fi
  if grep -q 'FR-A11Y' "$rows_file"; then
    echo "- xcodebuild test -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination '<small-device-id>' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests/testSmallScreenAccessibilityPrimaryControlsRemainReachable"
  fi
  if grep -q 'FR-BONSPIEL-SCORE' "$rows_file"; then
    echo "- xcodebuild test -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination '<simulator-id>' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests/testBonspielScorecardEndScoringEdgesSurviveRelaunch -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests/testBonspielForfeitResultSurvivesRelaunch"
  fi
  if grep -q 'FR-CIRCLE' "$rows_file"; then
    echo "- xcodebuild test -project ios/CurlPlan.xcodeproj -scheme CurlPlan -configuration Debug -destination '<simulator-id>' -derivedDataPath /tmp/curlplan-truth-derived CODE_SIGNING_ALLOWED=NO -only-testing:CurlPlanUITests/CurlPlanPrimaryScreenflowUITests/testRouteDistanceAndCircleMembershipSurfacesStayTruthfulAcrossRelaunch"
  fi
  if grep -Eq 'FR-ACCOUNT|FR-SYNC|FR-PUBLIC-ID|FR-RELATIONSHIP|FR-SHARED-OBJECTS|FR-SOCIAL|FR-TRUST-SAFETY' "$rows_file"; then
    echo "- docs/curlplan-accounts-social-roadmap-2026-06-28.md: run the phase-specific AS screenflow and backend authorization tests before shipping backend-backed claims"
  fi
  if grep -Eq 'FR-ACCOUNT|FR-SYNC|FR-TRUST-SAFETY' "$rows_file" && grep -Eq 'services/account-backend/|scripts/verify-account-backend.mjs' "$files_file"; then
    echo "- node scripts/verify-account-backend.mjs"
  fi
  printf '%s\n' "- rg -in \"likes|comments|public roster|here now|GPS verification|official result\" ios/CurlPlan ios/CurlPlanUITests tests/CurlPlanCoreTests -g '*.swift'"
  printf '%s\n' "- rg -in \"\\b(Text|Label|Button)\\([^\\n]*(official|public roster|likes|comments|gps|here now|live)\" ios/CurlPlan -g '*.swift'"
else
  echo "- claim scans only"
fi

echo
echo "Claim scan:"
claim_failed=0
if rg -in "likes|comments|public roster|here now|GPS verification|official result" ios/CurlPlan ios/CurlPlanUITests tests/CurlPlanCoreTests -g '*.swift'; then
  claim_failed=1
fi
if rg -in "\b(Text|Label|Button)\([^\n]*(official|public roster|likes|comments|gps|here now|live)" ios/CurlPlan -g '*.swift'; then
  claim_failed=1
fi
if [ "$claim_failed" -eq 0 ]; then
  echo "- PASS: no unsupported authority matches"
else
  echo "- FAIL: unsupported authority matches found" >&2
fi

exit_code=0
if [ -s "$unmapped_file" ]; then
  echo
  echo "Unmapped source paths:" >&2
  sort -u "$unmapped_file" | sed 's/^/- /' >&2
  exit_code=1
fi
if [ "$claim_failed" -ne 0 ]; then
  exit_code=1
fi

exit "$exit_code"
