#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FEED_DIR="${1:-$ROOT_DIR/tmp/sparkle-local-feed}"
BASE_URL="${2:-}"
RELEASE_NOTES_URL="${3:-}"
UPDATE_JSON="$FEED_DIR/update.json"

if [[ -z "$BASE_URL" ]]; then
  echo "usage: $0 [feed-dir] <base-url> [release-notes-url]" >&2
  exit 1
fi

if [[ ! -f "$UPDATE_JSON" ]]; then
  echo "Missing update metadata at: $UPDATE_JSON" >&2
  echo "Run scripts/macos-build-local-update.sh first." >&2
  exit 1
fi

VERSION="$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).fetch("version")' "$UPDATE_JSON")"
BUILD_NUMBER="$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).fetch("buildNumber")' "$UPDATE_JSON")"
ARCHIVE_NAME="$(ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).fetch("archiveName")' "$UPDATE_JSON")"
ARCHIVE_PATH="$FEED_DIR/$ARCHIVE_NAME"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Missing archive at: $ARCHIVE_PATH" >&2
  exit 1
fi

CONTENT_LENGTH="$(stat -f%z "$ARCHIVE_PATH")"
PUB_DATE="$(LC_ALL=C date -Ru)"
ARCHIVE_URL="${BASE_URL%/}/$ARCHIVE_NAME"
NOTES_XML=""

if [[ -n "$RELEASE_NOTES_URL" ]]; then
  NOTES_XML="    <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>"
fi

cat >"$FEED_DIR/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>CC Pocket Local Updates</title>
    <link>${BASE_URL%/}/appcast.xml</link>
    <description>Local Sparkle feed for CC Pocket</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
$NOTES_XML
      <enclosure
        url="$ARCHIVE_URL"
        sparkle:version="$BUILD_NUMBER"
        sparkle:shortVersionString="$VERSION"
        length="$CONTENT_LENGTH"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Generated local appcast:"
echo "  $FEED_DIR/appcast.xml"
