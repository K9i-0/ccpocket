#!/usr/bin/env bash
# release.sh - Shorebird リリース作成
#
# Usage: release.sh <ios|android> [extra-args...]
# Example: release.sh ios --export-method development
#
# extra-args は shorebird release にそのまま渡される。

set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <ios|android> [extra-args...]"
  echo "Example: $0 ios --export-method development"
  exit 1
fi

PLATFORM="$1"
shift

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../../apps/mobile"

echo "=== Shorebird Release ($PLATFORM) ==="
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating $PLATFORM release ---"
shorebird release "$PLATFORM" "$@"

echo ""
echo "=== Done ==="
