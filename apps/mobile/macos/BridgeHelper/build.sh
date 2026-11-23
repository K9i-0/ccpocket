#!/bin/sh
# Builds "CC Pocket Bridge.app" (helper + LaunchAgent launcher) into the app
# bundle. Runs as a build phase of the Runner target, before Xcode signs the
# app; the release workflow re-signs it with Developer ID.
# See docs/design/local-bridge-management.md.
set -eu

SRC="${SRCROOT}/BridgeHelper"
HELPER="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Helpers/CC Pocket Bridge.app"
OBJ="${DERIVED_FILE_DIR:-${TARGET_TEMP_DIR}}/BridgeHelper"
MIN_MACOS=13.0

rm -rf "$HELPER" "$OBJ"
mkdir -p "$HELPER/Contents/MacOS" "$HELPER/Contents/Library/LaunchAgents" "$OBJ"

build() { # <source> <object name> <executable name>
  slices=""
  for arch in ${ARCHS:-$(uname -m)}; do
    xcrun swiftc -O -target "${arch}-apple-macos${MIN_MACOS}" \
      -module-name BridgeHelper "$SRC/$1" -o "$OBJ/$2-$arch"
    slices="$slices $OBJ/$2-$arch"
  done
  # shellcheck disable=SC2086
  xcrun lipo -create $slices -output "$HELPER/Contents/MacOS/$3"
}
build Helper.swift helper "CC Pocket Bridge"
build Launcher.swift launcher bridge-launcher

sed -e "s/__HELPER_BUNDLE_ID__/${PRODUCT_BUNDLE_IDENTIFIER}.bridge-helper/" \
  -e "s/__VERSION__/${MARKETING_VERSION:-${FLUTTER_BUILD_NAME:-1.0.0}}/" \
  -e "s/__BUILD_NUMBER__/${CURRENT_PROJECT_VERSION:-${FLUTTER_BUILD_NUMBER:-1}}/" \
  "$SRC/Info.plist" > "$HELPER/Contents/Info.plist"
cp "$SRC/com.k9i.ccpocket.bridge-agent.plist" "$HELPER/Contents/Library/LaunchAgents/"

if [ "${CODE_SIGNING_ALLOWED:-YES}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  # Deliberately no entitlements: the helper and the launcher must not be
  # sandboxed, or the Bridge could not run agents in project folders.
  for item in "$HELPER/Contents/MacOS/bridge-launcher" "$HELPER"; do
    codesign --force --options runtime --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$item"
  done
fi
