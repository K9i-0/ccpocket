#!/bin/bash
# Generate Android feature graphics using Playwright CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANDROID_META="$ROOT/apps/mobile/fastlane/metadata/android"
SCREENSHOTS_ROOT="$ROOT/apps/mobile/fastlane/screenshots"

# Use iOS app icon (1024x1024, with background — iOS-style rounded corners applied via CSS)
ICON="$ROOT/apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"

generate() {
  local lang="$1"
  local template_name="template-${lang}.html"
  local screenshots_dir output_dir temp_html

  if [ "$lang" = "ja" ]; then
    screenshots_dir="$SCREENSHOTS_ROOT/ja"
    output_dir="$ANDROID_META/ja-JP/images"
  else
    screenshots_dir="$SCREENSHOTS_ROOT/en-US"
    output_dir="$ANDROID_META/en-US/images"
  fi

  echo "📸 Generating $(echo $lang | tr '[:lower:]' '[:upper:]') feature graphic..."

  temp_html="$SCRIPT_DIR/_temp_${lang}.html"

  # Use raw screenshots (no frame, no cropping)
  sed -e "s|ICON_PATH|file://${ICON}|g" \
      -e "s|SCREENSHOT_1_PATH|file://${screenshots_dir}/01_session_list.png|g" \
      -e "s|SCREENSHOT_2_PATH|file://${screenshots_dir}/04_markdown_input.png|g" \
      "$SCRIPT_DIR/$template_name" > "$temp_html"

  npx playwright screenshot \
    --viewport-size "1024,500" \
    "file://${temp_html}" \
    "${output_dir}/featureGraphic.png"

  rm -f "$temp_html"
  echo "✅ $(echo $lang | tr '[:lower:]' '[:upper:]'): ${output_dir}/featureGraphic.png"
}

echo "🎨 Generating feature graphics..."
echo ""
generate "en"
generate "ja"

echo ""
echo "🎉 Done!"
