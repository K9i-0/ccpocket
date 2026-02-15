#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../apps/mobile"

echo "=== Shorebird Release (iOS) ==="
echo "Project: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating iOS release ---"
# --no-codesign: CI環境や署名を別工程で行う場合に使用
# ローカルで署名する場合は --no-codesign を外す
shorebird release ios "$@"

echo ""
echo "=== Done ==="
echo "Next: Sign the IPA and upload to App Store Connect."
