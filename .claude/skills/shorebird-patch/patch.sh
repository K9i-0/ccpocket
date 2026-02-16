#!/usr/bin/env bash
# patch.sh - Shorebird パッチ作成 (stable)
#
# Usage: patch.sh <ios|android> <release-version> [extra-args...]
# Example: patch.sh ios 1.7.0+20
#
# 常に --allow-asset-diffs を付与し、非TTY環境でも安定動作する。

set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <ios|android> <release-version> [extra-args...]"
  echo "Example: $0 ios 1.7.0+20"
  exit 1
fi

PLATFORM="$1"
RELEASE_VERSION="$2"
shift 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../../apps/mobile"

echo "=== Shorebird Patch ($PLATFORM) ==="
echo "Release version: $RELEASE_VERSION"
echo "Track: stable"
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating $PLATFORM patch (stable) ---"
shorebird patch "$PLATFORM" \
  --release-version="$RELEASE_VERSION" \
  --allow-asset-diffs \
  "$@"

echo ""
echo "=== Done ==="
echo "Patch published to stable. Users will receive it on next app restart."
