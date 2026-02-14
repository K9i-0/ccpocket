#!/usr/bin/env bash
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

FLUTTER_VERSION="${FLUTTER_VERSION:-$(flutter --version --machine | grep -o '"frameworkVersion":"[^"]*"' | cut -d'"' -f4)}"

echo "=== Shorebird Patch (iOS) ==="
echo "Release version: $RELEASE_VERSION"
echo "Flutter version: $FLUTTER_VERSION"
echo "Track: staging"
echo ""

cd "$PROJECT_DIR"

# 静的検証
echo "--- Running dart analyze ---"
dart analyze .

echo ""
echo "--- Creating iOS patch (staging) ---"
shorebird patch ios \
  --release-version="$RELEASE_VERSION" \
  --flutter-version="$FLUTTER_VERSION" \
  --track=staging \
  "$@"

echo ""
echo "=== Done ==="
echo "Next: Verify with 'scripts/shorebird/preview.sh $RELEASE_VERSION <patch-number>'"
echo "Then promote with 'scripts/shorebird/promote.sh $RELEASE_VERSION <patch-number>'"
