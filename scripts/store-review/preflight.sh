#!/usr/bin/env bash

set -euo pipefail

platform="${1:-}"
version="${2:-}"
build_number="${3:-}"
confirmation="${4:-}"
ios_release_type="${5:-AFTER_APPROVAL}"
android_release_status="${6:-completed}"
android_user_fraction="${7:-0.1}"
ios_review_scope="${8:-UNCONFIRMED}"

fail() {
  echo "::error::$*" >&2
  exit 1
}

require_non_empty_file() {
  local path="$1"
  local max_chars="$2"

  [[ -s "$path" ]] || fail "Missing or empty store metadata: $path"

  local char_count
  char_count=$(wc -m < "$path" | tr -d ' ')
  if ((char_count > max_chars)); then
    fail "$path is ${char_count} characters (maximum: ${max_chars})"
  fi
}

check_release_tag() {
  local tag="$1"

  git rev-parse --verify --quiet "refs/tags/${tag}^{commit}" >/dev/null ||
    fail "Release tag not found: $tag"

  local tagged_version
  tagged_version=$(git show "${tag}:apps/mobile/pubspec.yaml" |
    awk '$1 == "version:" { print $2; exit }')
  [[ "$tagged_version" == "${version}+${build_number}" ]] ||
    fail "${tag} contains version ${tagged_version:-<missing>}, expected ${version}+${build_number}"
}

check_release_workflow() {
  local workflow="$1"
  local tag="$2"

  if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
    echo "Skipping GitHub release workflow verification outside GitHub Actions."
    return
  fi

  command -v gh >/dev/null || fail "Required command not found in GitHub Actions: gh"
  command -v jq >/dev/null || fail "Required command not found in GitHub Actions: jq"

  local tag_sha
  tag_sha=$(git rev-parse "refs/tags/${tag}^{commit}")

  local runs_json
  runs_json=$(gh run list \
    --repo "${GITHUB_REPOSITORY:?}" \
    --workflow "$workflow" \
    --branch "$tag" \
    --limit 20 \
    --json headBranch,headSha,status,conclusion,url)

  local successful_run_url
  successful_run_url=$(jq -r --arg tag "$tag" --arg tag_sha "$tag_sha" \
    '[.[] | select(.headBranch == $tag and .headSha == $tag_sha and .status == "completed" and .conclusion == "success")][0].url // empty' \
    <<< "$runs_json")
  [[ -n "$successful_run_url" ]] ||
    fail "No successful ${workflow} run found for ${tag}"

  echo "Verified release workflow: $successful_run_url"
}

[[ "$platform" == "ios" || "$platform" == "android" || "$platform" == "both" ]] ||
  fail "platform must be ios, android, or both"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  fail "version must use X.Y.Z format"
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] ||
  fail "build_number must be a positive integer"
[[ "$confirmation" == "SUBMIT ${version}+${build_number}" ]] ||
  fail "confirmation must exactly match: SUBMIT ${version}+${build_number}"
[[ "$ios_release_type" == "KEEP" || "$ios_release_type" == "MANUAL" || "$ios_release_type" == "AFTER_APPROVAL" ]] ||
  fail "ios_release_type must be KEEP, MANUAL, or AFTER_APPROVAL"
[[ "$android_release_status" == "inProgress" || "$android_release_status" == "completed" ]] ||
  fail "android_release_status must be inProgress or completed"

if [[ "$android_release_status" == "inProgress" ]]; then
  [[ "$android_user_fraction" =~ ^(0|1)(\.[0-9]+)?$ ]] ||
    fail "android_user_fraction must be a decimal greater than 0 and less than 1"
  awk -v fraction="$android_user_fraction" 'BEGIN { exit !(fraction > 0 && fraction < 1) }' ||
    fail "android_user_fraction must be greater than 0 and less than 1"
fi

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ "$platform" == "ios" || "$platform" == "both" ]]; then
  [[ "$ios_review_scope" == "APP_VERSION_ONLY" ]] ||
    fail "iOS automation only supports APP_VERSION_ONLY; new IAP/subscription review items require a separate submission flow"
  check_release_tag "ios/v${version}+${build_number}"
  check_release_workflow "ios-release.yml" "ios/v${version}+${build_number}"
  for locale in en-US ja ko zh-Hans; do
    require_non_empty_file \
      "apps/mobile/fastlane/metadata/${locale}/release_notes.txt" \
      4000
  done
fi

if [[ "$platform" == "android" || "$platform" == "both" ]]; then
  check_release_tag "android/v${version}+${build_number}"
  check_release_workflow "android-release.yml" "android/v${version}+${build_number}"
  for locale in en-US ja-JP ko-KR zh-CN; do
    require_non_empty_file \
      "apps/mobile/fastlane/metadata/android/${locale}/changelogs/${build_number}.txt" \
      500
  done
fi

echo "Store review preflight passed for ${platform} ${version}+${build_number}."
