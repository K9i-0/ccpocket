#!/usr/bin/env bash
# patch-android.sh - Android向けShorebirdパッチ作成 (staging)
#
# Usage: patch-android.sh <release-version> [extra-args...]
# Example: patch-android.sh 1.0.0+1
#
# 常に --allow-asset-diffs を付与し、非TTY環境でも安定動作する。

set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <release-version> [extra-args...]"
  echo "Example: $0 1.0.0+1"
  exit 1
fi

RELEASE_VERSION="$1"
shift

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../apps/mobile"

echo "=== Shorebird Patch (Android) ==="
echo "Release version: $RELEASE_VERSION"
echo "Track: staging"
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating Android patch (staging) ---"
shorebird patch android \
  --release-version="$RELEASE_VERSION" \
  --track=staging \
  --allow-asset-diffs \
  "$@"

echo ""
echo "=== Done ==="
echo "Next: Verify with 'scripts/shorebird/preview.sh $RELEASE_VERSION <patch-number>'"
echo "Then promote with 'scripts/shorebird/promote.sh $RELEASE_VERSION <patch-number>'"
