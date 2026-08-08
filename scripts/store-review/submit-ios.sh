#!/usr/bin/env bash

set -euo pipefail

version="${1:-}"
build_number="${2:-}"
release_type="${3:-KEEP}"
bundle_id="${ASC_BUNDLE_ID:-com.k9i.ccpocket}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

log() {
  echo "[submit-ios] $*"
}

for command in asc jq; do
  command -v "$command" >/dev/null || fail "Required command not found: $command"
done
for variable in ASC_ISSUER_ID ASC_KEY_ID ASC_PRIVATE_KEY; do
  [[ -n "${!variable:-}" ]] || fail "Required App Store Connect credential is empty: $variable"
done

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must use X.Y.Z format"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || fail "build_number must be a positive integer"
[[ "$release_type" == "KEEP" || "$release_type" == "MANUAL" || "$release_type" == "AFTER_APPROVAL" ]] ||
  fail "release_type must be KEEP, MANUAL, or AFTER_APPROVAL"

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

if [[ "$version_count" == "0" ]]; then
  create_release_type="$release_type"
  if [[ "$create_release_type" == "KEEP" ]]; then
    create_release_type="MANUAL"
  fi
  log "Creating App Store version ${version} with release type ${create_release_type}"
  created_version_json=$(asc versions create \
    --app "$app_id" \
    --version "$version" \
    --platform IOS \
    --release-type "$create_release_type" \
    --output json)
  version_id=$(jq -er '.id // .data.id' <<< "$created_version_json")
elif [[ "$version_count" == "1" ]]; then
  version_id=$(jq -er '.[0].id' <<< "$version_matches")
else
  fail "Found multiple iOS App Store versions for ${version}"
fi

version_detail=$(asc versions view \
  --version-id "$version_id" \
  --include-build \
  --include-submission \
  --output json)
version_state=$(jq -r '.state // "UNKNOWN"' <<< "$version_detail")
attached_build_id=$(jq -r '.buildId // empty' <<< "$version_detail")

if [[ -n "$attached_build_id" && "$attached_build_id" != "$build_id" ]]; then
  fail "App Store version ${version} already has a different build attached (${attached_build_id}); refusing to replace it with ${build_id}"
fi

review_status=$(asc review status \
  --app "$app_id" \
  --version-id "$version_id" \
  --platform IOS \
  --output json)
review_state=$(jq -r '.reviewState // "UNKNOWN"' <<< "$review_status")
review_blocker_count=$(jq '(.blockers // []) | length' <<< "$review_status")
if [[ ("$review_state" == "WAITING_FOR_REVIEW" || "$review_state" == "IN_REVIEW" || "$review_state" == "COMPLETE") && "$review_blocker_count" == "0" ]]; then
  [[ "$attached_build_id" == "$build_id" ]] ||
    fail "Submitted App Store version does not report the expected attached build ${build_id}"
  log "Version is already in review lifecycle state ${review_state}; no submission mutation needed."
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    # The backticks are Markdown literals, not shell substitutions.
    # shellcheck disable=SC2016
    printf '### iOS App Review\n\n- Version: `%s (%s)`\n- State: `%s`\n- Result: already submitted\n' \
      "$version" "$build_number" "$review_state" >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi
if [[ ("$review_state" == "WAITING_FOR_REVIEW" || "$review_state" == "IN_REVIEW") && "$review_blocker_count" != "0" ]]; then
  fail "App Review is already active but asc reports ${review_blocker_count} blocker(s); refusing a duplicate submission"
fi

if [[ "$release_type" != "KEEP" ]]; then
  log "Applying iOS release type ${release_type} (current version state: ${version_state})"
  asc versions update \
    --version-id "$version_id" \
    --release-type "$release_type" \
    --output table
fi

if [[ -z "$attached_build_id" ]]; then
  log "Attaching exact build ${build_id} to App Store version ${version_id}"
  asc versions attach-build \
    --version-id "$version_id" \
    --build-id "$build_id" \
    --output table
fi

if [[ "$version_state" == "READY_FOR_REVIEW" &&
      ("$review_state" == "NOT_SUBMITTED" || "$review_state" == "READY_FOR_REVIEW") ]]; then
  log "Version is already attached to a ready review submission; skipping editable-state validation before retry"
else
  log "Running App Store submission validation"
  asc validate \
    --app "$app_id" \
    --version-id "$version_id" \
    --platform IOS \
    --output table
  asc review doctor \
    --app "$app_id" \
    --version-id "$version_id" \
    --platform IOS \
    --output table
fi

log "Submitting ${version} (${build_number}) for App Review"
if [[ "$version_state" == "READY_FOR_REVIEW" &&
      ("$review_state" == "NOT_SUBMITTED" || "$review_state" == "READY_FOR_REVIEW") ]]; then
  ready_submissions_json=$(asc review submissions-list \
    --app "$app_id" \
    --platform IOS \
    --state READY_FOR_REVIEW \
    --include app,items,appStoreVersionForReview \
    --item-fields appStoreVersion \
    --paginate \
    --output json)
  matching_submissions=$(jq --arg version_id "$version_id" \
    '[((.data // .)[]?) | select(.relationships.appStoreVersionForReview.data.id == $version_id)]' \
    <<< "$ready_submissions_json")
  matching_submission_count=$(jq 'length' <<< "$matching_submissions")
  [[ "$matching_submission_count" == "1" ]] ||
    fail "Expected exactly one ready review submission for App Store version ${version_id}, found ${matching_submission_count}"
  submission_id=$(jq -er '.[0].id' <<< "$matching_submissions")

  submission_items_json=$(asc review items-list \
    --submission "$submission_id" \
    --fields state,appStoreVersion \
    --include appStoreVersion \
    --paginate \
    --output json)
  submission_item_count=$(jq '[((.data // .)[]?)] | length' <<< "$submission_items_json")
  [[ "$submission_item_count" == "1" ]] ||
    fail "Review submission ${submission_id} must contain exactly one item, found ${submission_item_count}"
  submission_item_version_id=$(jq -er '(.data // .)[0].relationships.appStoreVersion.data.id' <<< "$submission_items_json")
  submission_item_state=$(jq -er '(.data // .)[0].attributes.state' <<< "$submission_items_json")
  [[ "$submission_item_version_id" == "$version_id" ]] ||
    fail "Review submission ${submission_id} contains App Store version ${submission_item_version_id}, expected ${version_id}"
  [[ "$submission_item_state" == "READY_FOR_REVIEW" ]] ||
    fail "Review submission ${submission_id} item is ${submission_item_state}, expected READY_FOR_REVIEW"

  log "Submitting verified ready review submission ${submission_id}"
  submission_json=$(asc review submissions-submit \
    --id "$submission_id" \
    --confirm \
    --output json)
  already_submitted=false
else
  submission_json=$(asc review submit \
    --app "$app_id" \
    --version-id "$version_id" \
    --build "$build_id" \
    --platform IOS \
    --confirm \
    --output json)
  submission_id=$(jq -r '.submissionId // .data.id // .id // empty' <<< "$submission_json")
  already_submitted=$(jq -r '.alreadySubmitted // false' <<< "$submission_json")
fi

for attempt in $(seq 1 30); do
  if [[ -n "$submission_id" && "$already_submitted" != "true" ]]; then
    submission_status=$(asc review submissions-get --id "$submission_id" --output json)
    review_state=$(jq -r '.data.attributes.state // .state // "UNKNOWN"' <<< "$submission_status")
  else
    review_status=$(asc review status \
      --app "$app_id" \
      --version-id "$version_id" \
      --platform IOS \
      --output json)
    review_state=$(jq -r '.reviewState // "UNKNOWN"' <<< "$review_status")
  fi
  case "$review_state" in
    WAITING_FOR_REVIEW | IN_REVIEW)
      log "App Review state confirmed: ${review_state}"
      if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        # The backticks are Markdown literals, not shell substitutions.
        # shellcheck disable=SC2016
        printf '### iOS App Review\n\n- Version: `%s (%s)`\n- Submission: `%s`\n- State: `%s`\n' \
          "$version" "$build_number" "${submission_id:-n/a}" "$review_state" >> "$GITHUB_STEP_SUMMARY"
      fi
      exit 0
      ;;
    COMPLETE)
      review_status=$(asc review status \
        --app "$app_id" \
        --version-id "$version_id" \
        --platform IOS \
        --output json)
      review_blocker_count=$(jq '(.blockers // []) | length' <<< "$review_status")
      if [[ "$review_blocker_count" == "0" ]]; then
        log "App Review state confirmed: COMPLETE"
        exit 0
      fi
      asc review doctor \
        --app "$app_id" \
        --version-id "$version_id" \
        --platform IOS \
        --output table || true
      fail "The latest review is COMPLETE but ${review_blocker_count} blocker(s) remain; a new submission was not created"
      ;;
    UNRESOLVED_ISSUES | CANCELED)
      asc review doctor \
        --app "$app_id" \
        --version-id "$version_id" \
        --platform IOS \
        --output table || true
      fail "App Review entered terminal failure state ${review_state}"
      ;;
  esac

  log "Waiting for App Review state to update (${attempt}/30, current: ${review_state})"
  sleep 10
done

fail "Timed out waiting for App Review to reach WAITING_FOR_REVIEW or IN_REVIEW (last state: ${review_state})"
