#!/usr/bin/env bash
# patch.sh - Shorebird パッチ作成 (staging)
#
# Usage: patch.sh <ios|android> <release-version> [extra-args...]
# Example: patch.sh ios 1.7.0+20
#
# デフォルトで staging トラックに配信する。
# stable に昇格するには promote.sh を使う。
# 常に --allow-asset-diffs と --allow-native-diffs を付与し、非TTY環境でも安定動作する。

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
echo "Track: staging"
echo ""

cd "$PROJECT_DIR"

echo "--- Creating $PLATFORM patch (staging) ---"
# --no-tree-shake-icons: Keep MaterialIcons font stable across release/patch builds.
# TODO: Remove once Shorebird supports asset patching (https://github.com/shorebirdtech/shorebird/issues/318)
shorebird patch "$PLATFORM" \
  --release-version="$RELEASE_VERSION" \
  --track=staging \
  --allow-asset-diffs \
  --allow-native-diffs \
  -- --no-tree-shake-icons \
  "$@"

echo ""
echo "=== Done ==="
echo "Patch published to staging."
echo ""
echo "Next steps:"
echo "  1. Verify: Open debug screen → set track to 'Staging' → restart app"
echo "  2. Promote: bash $SCRIPT_DIR/promote.sh <release-version> <patch-number>"
