#!/usr/bin/env bash

set -euo pipefail

version="${1:-}"
build_number="${2:-}"
bundle_id="${ASC_BUNDLE_ID:-com.k9i.ccpocket}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

log() {
  echo "[release-ios] $*"
}

for command in asc jq; do
  command -v "$command" >/dev/null || fail "Required command not found: $command"
done
for variable in ASC_ISSUER_ID ASC_KEY_ID ASC_PRIVATE_KEY; do
  [[ -n "${!variable:-}" ]] || fail "Required App Store Connect credential is empty: $variable"
done

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must use X.Y.Z format"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || fail "build_number must be a positive integer"

apps_json=$(asc apps list --bundle-id "$bundle_id" --paginate --output json)
app_matches=$(jq --arg bundle_id "$bundle_id" \
  '[((.data // .)[]?) | select(.attributes.bundleId == $bundle_id)]' <<< "$apps_json")
app_count=$(jq 'length' <<< "$app_matches")
[[ "$app_count" == "1" ]] || fail "Expected exactly one app for ${bundle_id}, found ${app_count}"
app_id=$(jq -er '.[0].id' <<< "$app_matches")

build_json=$(asc builds info \
  --app "$app_id" \
  --build-number "$build_number" \
  --version "$version" \
  --platform IOS \
  --output json)
build_id=$(jq -er '.data.id // .id' <<< "$build_json")
resolved_build_number=$(jq -er '.data.attributes.version // .version' <<< "$build_json")
[[ "$resolved_build_number" == "$build_number" ]] ||
  fail "Resolved build number ${resolved_build_number} does not match ${build_number}"

versions_json=$(asc versions list \
  --app "$app_id" \
  --version "$version" \
  --platform IOS \
  --paginate \
  --output json)
version_matches=$(jq --arg version "$version" \
  '[((.data // .)[]?) | select(.attributes.versionString == $version and .attributes.platform == "IOS")]' \
  <<< "$versions_json")
version_count=$(jq 'length' <<< "$version_matches")
[[ "$version_count" == "1" ]] ||
  fail "Expected exactly one iOS App Store version for ${version}, found ${version_count}"
version_id=$(jq -er '.[0].id' <<< "$version_matches")

version_detail=$(asc versions view \
  --version-id "$version_id" \
  --include-build \
  --output json)
version_state=$(jq -r '.state // .data.attributes.appVersionState // .data.attributes.appStoreState // "UNKNOWN"' <<< "$version_detail")
attached_build_id=$(jq -r '.buildId // .data.relationships.build.data.id // empty' <<< "$version_detail")
[[ "$attached_build_id" == "$build_id" ]] ||
  fail "App Store version ${version} is not attached to expected build ${build_id}"

case "$version_state" in
  READY_FOR_DISTRIBUTION|READY_FOR_SALE)
    log "${version} (${build_number}) is already ready for distribution; no mutation needed"
    ;;
  PROCESSING_FOR_DISTRIBUTION|PROCESSING_FOR_APP_STORE|PENDING_APPLE_RELEASE)
    log "${version} (${build_number}) is already processing for distribution; no mutation needed"
    ;;
  PENDING_DEVELOPER_RELEASE)
    log "Requesting manual release of ${version} (${build_number})"
    asc versions release --version-id "$version_id" --confirm --output json
    ;;
  *)
    fail "Version state ${version_state} does not allow a manual release request"
    ;;
esac

final_detail=$(asc versions view --version-id "$version_id" --include-build --output json)
final_state=$(jq -r '.state // .data.attributes.appVersionState // .data.attributes.appStoreState // "UNKNOWN"' <<< "$final_detail")
case "$final_state" in
  PENDING_DEVELOPER_RELEASE|PROCESSING_FOR_DISTRIBUTION|PROCESSING_FOR_APP_STORE|PENDING_APPLE_RELEASE|READY_FOR_DISTRIBUTION|READY_FOR_SALE) ;;
  *) fail "Unexpected state after release request: ${final_state}" ;;
esac

log "Release request accepted; current state: ${final_state}"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '### iOS Manual Release\n\n- Version: `%s (%s)`\n- State: `%s`\n' \
    "$version" "$build_number" "$final_state" >> "$GITHUB_STEP_SUMMARY"
fi
