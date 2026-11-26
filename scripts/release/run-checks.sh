#!/usr/bin/env bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
log_dir=$(mktemp -d "${TMPDIR:-/tmp}/ccpocket-release-checks.XXXXXX")
started_at=$SECONDS

normalize_tail() {
  local log_path="$1"
  tr '\r' '\n' < "$log_path" | tail -n 120 | cut -c 1-500
}

run_analyze() {
  local label="$1"
  local target="$2"
  local log_path="$3"

  if (cd "$repo_root" && dart analyze "$target" >"$log_path" 2>&1); then
    local issue_count
    issue_count=$(grep -Eo '[0-9]+ issues? found' "$log_path" | tail -1 | grep -Eo '[0-9]+' || true)
    echo "$label success issues=${issue_count:-0}"
  else
    echo "$label failed log=$log_path" >&2
    normalize_tail "$log_path" >&2
    exit 1
  fi
}

run_flutter_test() {
  local label="$1"
  local target_dir="$2"
  local log_path="$3"
  local test_started_at=$SECONDS

  if (cd "$repo_root/$target_dir" && flutter test >"$log_path" 2>&1); then
    local result passed skipped
    result=$(grep -aoE '\+[0-9]+( ~[0-9]+)?: All tests passed!' "$log_path" | tail -1 || true)
    passed=$(sed -nE 's/^\+([0-9]+).*/\1/p' <<< "$result")
    skipped=$(sed -nE 's/^\+[0-9]+ ~([0-9]+).*/\1/p' <<< "$result")
    echo "$label success passed=${passed:-unknown} skipped=${skipped:-0} duration=$((SECONDS - test_started_at))s"
  else
    echo "$label failed log=$log_path" >&2
    normalize_tail "$log_path" >&2
    exit 1
  fi
}

run_analyze "ANALYZE(markdown_kit)" "packages/markdown_kit" "$log_dir/analyze-markdown-kit.log"
run_analyze "ANALYZE(mobile)" "apps/mobile" "$log_dir/analyze-mobile.log"
run_flutter_test "TEST(markdown_kit)" "packages/markdown_kit" "$log_dir/flutter-test-markdown-kit.log"
run_flutter_test "TEST(mobile)" "apps/mobile" "$log_dir/flutter-test-mobile.log"

echo "CHECKS success duration=$((SECONDS - started_at))s"
rm -rf "$log_dir"
