#!/usr/bin/env bash
# Withdraw an iOS version that is waiting for App Review and turn it into the
# next candidate: cancel its submission, rename the version and attach the new
# build. App Store Connect keeps one editable version per platform, so the
# next version cannot be created next to a pending one.
#
# Only a version that is still WAITING_FOR_REVIEW is withdrawn; a review that
# has started is left alone. Re-running after a partial run continues from the
# state it finds.
#
# Usage: withdraw-ios.sh <pending X.Y.Z> <new X.Y.Z> <new build number>

set -euo pipefail

pending_version="${1:-}"
version="${2:-}"
build_number="${3:-}"
bundle_id="${ASC_BUNDLE_ID:-com.k9i.ccpocket}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

log() {
  echo "[withdraw-ios] $*"
}

for command in asc jq; do
  command -v "$command" >/dev/null || fail "Required command not found: $command"
done
for variable in ASC_ISSUER_ID ASC_KEY_ID ASC_PRIVATE_KEY; do
  [[ -n "${!variable:-}" ]] || fail "Required App Store Connect credential is empty: $variable"
done

[[ "$pending_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "pending version must use X.Y.Z format"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must use X.Y.Z format"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || fail "build_number must be a positive integer"
[[ "$pending_version" != "$version" ]] || fail "pending and new version are the same"

version_state_of() {
  jq -r '.state // .data.attributes.appVersionState // .data.attributes.appStoreState // "UNKNOWN"'
}

is_editable() {
  case "$1" in
    PREPARE_FOR_SUBMISSION | DEVELOPER_REJECTED | REJECTED | METADATA_REJECTED) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the JSON array of iOS versions whose version string is exactly $1.
versions_named() {
  local json
  json=$(asc versions list \
    --app "$app_id" \
    --version "$1" \
    --platform IOS \
    --paginate \
    --output json)
  jq --arg version "$1" \
    '[((.data // .)[]?) | select(.attributes.versionString == $version and .attributes.platform == "IOS")]' \
    <<< "$json"
}

log "Resolving App Store Connect app for ${bundle_id}"
apps_json=$(asc apps list --bundle-id "$bundle_id" --paginate --output json)
app_matches=$(jq --arg bundle_id "$bundle_id" \
  '[((.data // .)[]?) | select(.attributes.bundleId == $bundle_id)]' <<< "$apps_json")
app_count=$(jq 'length' <<< "$app_matches")
[[ "$app_count" == "1" ]] || fail "Expected exactly one app for ${bundle_id}, found ${app_count}"
app_id=$(jq -er '.[0].id' <<< "$app_matches")

log "Waiting for exact build ${version} (${build_number})"
asc builds wait \
  --app "$app_id" \
  --build-number "$build_number" \
  --version "$version" \
  --platform IOS \
  --timeout 30m \
  --poll-interval 30s \
  --fail-on-invalid \
  --output table
build_json=$(asc builds info \
  --app "$app_id" \
  --build-number "$build_number" \
  --version "$version" \
  --platform IOS \
  --output json)
build_id=$(jq -er '.data.id // .id' <<< "$build_json")

pending_matches=$(versions_named "$pending_version")
new_matches=$(versions_named "$version")
pending_count=$(jq 'length' <<< "$pending_matches")
new_count=$(jq 'length' <<< "$new_matches")

if [[ "$pending_count" == "1" && "$new_count" == "0" ]]; then
  version_id=$(jq -er '.[0].id' <<< "$pending_matches")
  renamed=false
elif [[ "$pending_count" == "0" && "$new_count" == "1" ]]; then
  # A previous run already renamed the version.
  version_id=$(jq -er '.[0].id' <<< "$new_matches")
  renamed=true
else
  fail "Expected one iOS version named ${pending_version} and none named ${version} (found ${pending_count} and ${new_count})"
fi

view_state() {
  asc versions view --version-id "$version_id" --include-build --include-submission --output json |
    version_state_of
}

state=$(view_state)
log "Version ${version_id} is ${state}"

if [[ "$state" == "WAITING_FOR_REVIEW" ]]; then
  [[ "$renamed" == "false" ]] ||
    fail "Version ${version} is already waiting for review; nothing to withdraw"
  log "Canceling the review submission of ${pending_version}"
  asc submit cancel --version-id "$version_id" --app "$app_id" --confirm --output table
elif ! is_editable "$state"; then
  fail "Version is ${state}; only a version that is WAITING_FOR_REVIEW is withdrawn"
fi

for attempt in $(seq 1 40); do
  state=$(view_state)
  if is_editable "$state"; then
    break
  fi
  log "Waiting for the version to become editable (state: ${state}, attempt ${attempt}/40)"
  sleep 15
done
is_editable "$state" || fail "Version did not become editable after the cancellation (state: ${state})"

if [[ "$renamed" == "false" ]]; then
  log "Renaming App Store version ${pending_version} to ${version}"
  asc versions update --version-id "$version_id" --version "$version" --output table
fi

log "Attaching build ${version} (${build_number})"
asc versions attach-build --version-id "$version_id" --build-id "$build_id" --output table

detail=$(asc versions view --version-id "$version_id" --include-build --include-submission --output json)
final_version=$(jq -r '.versionString // .data.attributes.versionString // empty' <<< "$detail")
final_build_id=$(jq -r '.buildId // .data.relationships.build.data.id // empty' <<< "$detail")
[[ "$final_version" == "$version" ]] ||
  fail "Version string is ${final_version:-unknown} after the rename, expected ${version}"
[[ "$final_build_id" == "$build_id" ]] ||
  fail "Attached build is ${final_build_id:-none}, expected ${build_id}"

log "Version ${version} (${build_number}) is ready for metadata and submission."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  # The backticks are Markdown literals, not shell substitutions.
  # shellcheck disable=SC2016
  printf '### iOS review withdrawn\n\n- Withdrawn: `%s`\n- Now: `%s (%s)`\n- State: `%s`\n' \
    "$pending_version" "$version" "$build_number" "$(version_state_of <<< "$detail")" >> "$GITHUB_STEP_SUMMARY"
fi
