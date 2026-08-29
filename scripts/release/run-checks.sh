#!/usr/bin/env bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
log_dir=$(mktemp -d "${TMPDIR:-/tmp}/ccpocket-release-checks.XXXXXX")
analyze_log="$log_dir/analyze.log"
test_log="$log_dir/flutter-test.log"
started_at=$SECONDS

normalize_tail() {
  local log_path="$1"
  tr '\r' '\n' < "$log_path" | tail -n 120 | cut -c 1-500
}

if (cd "$repo_root" && dart analyze apps/mobile >"$analyze_log" 2>&1); then
  issue_count=$(grep -Eo '[0-9]+ issues? found' "$analyze_log" | tail -1 | grep -Eo '[0-9]+' || true)
  echo "ANALYZE success issues=${issue_count:-0}"
else
  echo "ANALYZE failed log=$analyze_log" >&2
  normalize_tail "$analyze_log" >&2
  exit 1
fi

test_started_at=$SECONDS
if (cd "$repo_root/apps/mobile" && flutter test >"$test_log" 2>&1); then
  result=$(grep -aoE '\+[0-9]+( ~[0-9]+)?: All tests passed!' "$test_log" | tail -1 || true)
  passed=$(sed -nE 's/^\+([0-9]+).*/\1/p' <<< "$result")
  skipped=$(sed -nE 's/^\+[0-9]+ ~([0-9]+).*/\1/p' <<< "$result")
  echo "TEST success passed=${passed:-unknown} skipped=${skipped:-0} duration=$((SECONDS - test_started_at))s"
else
  echo "TEST failed log=$test_log" >&2
  normalize_tail "$test_log" >&2
  exit 1
fi

echo "CHECKS success duration=$((SECONDS - started_at))s"
rm -rf "$log_dir"
