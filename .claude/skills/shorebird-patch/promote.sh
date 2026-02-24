#!/usr/bin/env bash
# promote.sh - Shorebird パッチを staging → stable に昇格
#
# Usage: promote.sh <release-version> <patch-number>
# Example: promote.sh 1.7.0+20 3

set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <release-version> <patch-number>"
  echo "Example: $0 1.7.0+20 3"
  exit 1
fi

RELEASE_VERSION="$1"
PATCH_NUMBER="$2"

echo "=== Shorebird Promote ==="
echo "Release version: $RELEASE_VERSION"
echo "Patch number: $PATCH_NUMBER"
echo "Track: staging → stable"
echo ""

shorebird patch promote \
  --release-version="$RELEASE_VERSION" \
  --patch-number="$PATCH_NUMBER"

echo ""
echo "=== Done ==="
echo "Patch $PATCH_NUMBER promoted to stable. All users will receive it on next app restart."
