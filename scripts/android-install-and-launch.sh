#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/mobile"
DEVICE_ID="${1:-emulator-5554}"
APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="com.k9i.ccpocket"

cd "$APP_DIR"
flutter build apk --debug --target lib/main.dart

adb -s "$DEVICE_ID" install -r "$APK_PATH"
adb -s "$DEVICE_ID" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1
