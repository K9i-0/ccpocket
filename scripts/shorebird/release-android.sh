#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../apps/mobile"

echo "=== Shorebird Release (Android) ==="
echo "Project: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating Android release ---"
shorebird release android "$@"

echo ""
echo "=== Done ==="
echo "Next: Upload the AAB to Play Console for review."
