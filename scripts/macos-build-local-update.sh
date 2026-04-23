#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/mobile"
FEED_DIR="${3:-$ROOT_DIR/tmp/sparkle-local-feed}"
VERSION="${1:-}"
BUILD_NUMBER="${2:-}"
MODE="${MODE:-release}"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "usage: $0 <version> <build-number> [feed-dir]" >&2
  exit 1
fi

if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "MODE must be 'release' or 'debug'" >&2
  exit 1
fi

mkdir -p "$FEED_DIR"

pushd "$APP_DIR" >/dev/null
flutter build macos "--$MODE" --build-name "$VERSION" --build-number "$BUILD_NUMBER"
popd >/dev/null

APP_PATH="$APP_DIR/build/macos/Build/Products/${MODE^}/CC Pocket.app"
ARCHIVE_NAME="CC-Pocket-local-v${VERSION}.zip"
ARCHIVE_PATH="$FEED_DIR/$ARCHIVE_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at: $APP_PATH" >&2
  exit 1
fi

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

cat >"$FEED_DIR/update.json" <<EOF
{
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "archiveName": "$ARCHIVE_NAME"
}
EOF

echo "Built local update archive:"
echo "  $ARCHIVE_PATH"
