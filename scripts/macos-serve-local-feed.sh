#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FEED_DIR="${1:-$ROOT_DIR/tmp/sparkle-local-feed}"
PORT="${2:-8899}"

if [[ ! -d "$FEED_DIR" ]]; then
  echo "Feed directory does not exist: $FEED_DIR" >&2
  exit 1
fi

echo "Serving local Sparkle feed from $FEED_DIR"
echo "  http://127.0.0.1:${PORT}/appcast.xml"

cd "$FEED_DIR"
python3 -m http.server "$PORT"
