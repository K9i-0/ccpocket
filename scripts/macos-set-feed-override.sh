#!/usr/bin/env bash

set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.k9i.ccpocket}"
DEFAULTS_KEY="ccpocket.sparkle.feed_url_override"
FEED_URL="${1:-}"

if [[ -n "$FEED_URL" ]]; then
  defaults write "$BUNDLE_ID" "$DEFAULTS_KEY" -string "$FEED_URL"
  echo "Set Sparkle feed override:"
  echo "  $FEED_URL"
else
  defaults delete "$BUNDLE_ID" "$DEFAULTS_KEY" >/dev/null 2>&1 || true
  echo "Cleared Sparkle feed override."
fi

defaults delete "$BUNDLE_ID" SULastCheckTime >/dev/null 2>&1 || true
echo "Reset SULastCheckTime for immediate re-check."
