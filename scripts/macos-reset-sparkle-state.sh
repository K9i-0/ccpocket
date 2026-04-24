#!/usr/bin/env bash

set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.k9i.ccpocket}"

delete_default() {
  local key="$1"
  defaults delete "$BUNDLE_ID" "$key" >/dev/null 2>&1 || true
}

delete_default "SULastCheckTime"
delete_default "ccpocket.sparkle.feed_url_override"

echo "Reset Sparkle state for $BUNDLE_ID"
echo "  deleted SULastCheckTime"
echo "  deleted ccpocket.sparkle.feed_url_override"
