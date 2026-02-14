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

# shorebird.yaml から app_id を取得
APP_ID=$(grep 'app_id:' shorebird.yaml | head -1 | awk '{print $2}')

if [ -z "$APP_ID" ]; then
  echo "Error: Could not find app_id in shorebird.yaml"
  exit 1
fi

echo "=== Shorebird Preview ==="
echo "App ID: $APP_ID"
echo "Release version: $RELEASE_VERSION"
echo "Patch number: $PATCH_NUMBER"
echo "Track: staging"
echo ""

shorebird preview \
  --app-id "$APP_ID" \
  --release-version "$RELEASE_VERSION" \
  --patch-number "$PATCH_NUMBER" \
  --track=staging \
  "$@"
