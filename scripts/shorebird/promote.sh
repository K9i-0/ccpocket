#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <release-version> <patch-number> [extra-args...]"
  echo "Example: $0 1.0.0+1 1"
  exit 1
fi

RELEASE_VERSION="$1"
PATCH_NUMBER="$2"
shift 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../apps/mobile"

cd "$PROJECT_DIR"

echo "=== Shorebird Promote (staging → stable) ==="
echo "Release version: $RELEASE_VERSION"
echo "Patch number: $PATCH_NUMBER"
echo ""

read -p "Promote patch #$PATCH_NUMBER to stable? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

shorebird patches set-track \
  --release "$RELEASE_VERSION" \
  --patch "$PATCH_NUMBER" \
  --track=stable \
  "$@"

echo ""
echo "=== Done ==="
echo "Patch #$PATCH_NUMBER has been promoted to stable."
