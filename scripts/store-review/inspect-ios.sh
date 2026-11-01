#!/usr/bin/env bash

set -euo pipefail

output_path="${1:-}"
bundle_id="${ASC_BUNDLE_ID:-com.k9i.ccpocket}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

for command in asc jq; do
  command -v "$command" >/dev/null || fail "Required command not found: $command"
done
for variable in ASC_ISSUER_ID ASC_KEY_ID ASC_PRIVATE_KEY; do
  [[ -n "${!variable:-}" ]] || fail "Required App Store Connect credential is empty: $variable"
done
[[ -n "$output_path" ]] || fail "Usage: inspect-ios.sh <output-json-path>"

apps_json=$(asc apps list --bundle-id "$bundle_id" --paginate --output json)
app_matches=$(jq --arg bundle_id "$bundle_id" \
  '[((.data // .)[]?) | select(.attributes.bundleId == $bundle_id)]' <<< "$apps_json")
app_count=$(jq 'length' <<< "$app_matches")
[[ "$app_count" == "1" ]] || fail "Expected exactly one app for ${bundle_id}, found ${app_count}"
app_id=$(jq -er '.[0].id' <<< "$app_matches")

versions_json=$(asc versions list \
  --app "$app_id" \
  --platform IOS \
  --paginate \
  --output json)
live_version=$(jq -cer '
  [((.data // .)[]?)
    | select(.attributes.platform == "IOS")
    | select(
        (if (.attributes.appVersionState // "") != ""
         then .attributes.appVersionState
         else .attributes.appStoreState
         end) as $state
        | $state == "READY_FOR_DISTRIBUTION" or $state == "READY_FOR_SALE"
      )]
  | sort_by(.attributes.createdDate // "")
  | last
' <<< "$versions_json") || fail "No live iOS version found"

version_id=$(jq -er '.id' <<< "$live_version")
version_detail=$(asc versions view \
  --version-id "$version_id" \
  --include-build \
  --output json)

version=$(jq -er '.versionString // .data.attributes.versionString' <<< "$version_detail")
build_number=$(jq -er '.buildVersion // (.data.relationships.build.data.id as $id | .included[]? | select(.type == "builds" and .id == $id) | .attributes.version)' <<< "$version_detail")
state=$(jq -er '.state // .data.attributes.appVersionState // .data.attributes.appStoreState' <<< "$version_detail")
[[ "$state" == "READY_FOR_DISTRIBUTION" || "$state" == "READY_FOR_SALE" ]] ||
  fail "Expected a live iOS state, got ${state}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Unexpected live version: ${version}"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || fail "Unexpected live build number: ${build_number}"

mkdir -p "$(dirname "$output_path")"
jq -n \
  --arg platform ios \
  --arg version "$version" \
  --arg buildNumber "$build_number" \
  --arg state "$state" \
  '{
    platform: $platform,
    version: $version,
    buildNumber: $buildNumber,
    state: $state
  }' > "$output_path"

echo "Live iOS version: ${version}+${build_number} (${state})"
