#!/bin/bash
# Stop hook: タスク完了前にanalyzeとtestを実行

cd "$CLAUDE_PROJECT_DIR/apps/mobile" || exit 0

# 1. dart analyze を実行
ANALYZE_RESULT=$(dart analyze lib/ 2>&1)
ANALYZE_ERRORS=$(echo "$ANALYZE_RESULT" | grep -c "error -")

if [ "$ANALYZE_ERRORS" -gt 0 ]; then
  echo "dart analyze found $ANALYZE_ERRORS error(s). Please fix before completing:" >&2
  echo "$ANALYZE_RESULT" | grep "error -" | head -5 >&2
  exit 2
fi

# 2. テストを実行（lib/のDartファイルが変更されている場合のみ）
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null | grep "^apps/mobile/lib/.*\.dart$" | wc -l)

if [ "$CHANGED_FILES" -gt 0 ]; then
  TEST_RESULT=$(flutter test --no-pub 2>&1)
  TEST_EXIT=$?

  if [ $TEST_EXIT -ne 0 ]; then
    echo "Tests failed. Please fix before completing:" >&2
    echo "$TEST_RESULT" | tail -20 >&2
    exit 2
  fi
fi

echo "All checks passed (analyze: OK, tests: OK)"
exit 0
