#!/bin/bash
# Compose store screenshots: dark background + keyword/title text + screenshot
# Output: 1320x2868 (App Store 6.9" requirement)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVAS_W=1320
CANVAS_H=2868
BG_COLOR="#141416"

# Font settings
FONT_EN_BOLD="Helvetica-Bold"
FONT_EN_REG="Helvetica"
FONT_JA_BOLD="Hiragino-Sans-W7"
FONT_JA_REG="Hiragino-Sans-W3"

# Screenshot definitions: key, keyword_en, title_en, keyword_ja, title_ja
SCREENSHOTS=(
  "01_session_list|Desktop coding AI|in your pocket|PCのコーディングAIを|スマホから操作"
  "02_approval_list|Multiple sessions|Approve at a glance|複数セッション一覧|まとめて承認対応"
  "03_multi_question|Mobile-first UI|Questions, answered instantly|モバイル最適化|承認UIで素早く回答"
  "04_markdown_input|Write rich prompts|Bullet lists made easy|リッチなプロンプト|箇条書きが簡単"
  "05_named_sessions|Name your sessions|Organize your projects|セッションに名前|プロジェクトを整理"
  "06_image_attach|Attach images|From clipboard or gallery|画像を添付|クリップボードから貼り付け"
  "07_git_diff|Review diffs|See every change at once|差分を確認|変更を一覧表示"
  "08_new_session|Start fresh|Start from your phone|新しいセッション|スマホから開始"
)

compose_screenshot() {
  local key="$1" keyword="$2" title="$3" lang_dir="$4" font_bold="$5" font_reg="$6"
  local input="${SCRIPT_DIR}/${lang_dir}/${key}.png"
  local output="${SCRIPT_DIR}/${lang_dir}/${key}_framed.png"

  if [ ! -f "$input" ]; then
    echo "SKIP: $input not found"
    return
  fi

  # Get input dimensions
  local src_w src_h
  read -r src_w src_h <<< "$(magick identify -format '%w %h' "$input")"

  # Scale screenshot to fit with side padding
  local pad=80
  local max_w=$((CANVAS_W - pad * 2))
  local scale_ratio
  scale_ratio=$(echo "scale=6; $max_w / $src_w" | bc)
  local scaled_w=$max_w
  local scaled_h
  scaled_h=$(echo "$src_h * $scale_ratio / 1" | bc)

  # Text area at top
  local text_area_h=600

  # Cap screenshot height if it overflows
  local avail_h=$((CANVAS_H - text_area_h - 20))
  if [ "$scaled_h" -gt "$avail_h" ]; then
    scale_ratio=$(echo "scale=6; $avail_h / $src_h" | bc)
    scaled_h=$avail_h
    scaled_w=$(echo "$src_w * $scale_ratio / 1" | bc)
  fi

  local ss_x=$(( (CANVAS_W - scaled_w) / 2 ))
  local ss_y=$text_area_h

  local corner_radius=150

  echo "Composing: $key ($lang_dir)"

  # Create rounded-corner mask for screenshot
  magick -size "${scaled_w}x${scaled_h}" xc:none \
    -fill white -draw "roundrectangle 0,0 $((scaled_w-1)),$((scaled_h-1)) ${corner_radius},${corner_radius}" \
    /tmp/mask_$$.png

  # Apply mask to resized screenshot
  magick "$input" -resize "${scaled_w}x${scaled_h}" \
    /tmp/mask_$$.png -alpha off -compose CopyOpacity -composite \
    /tmp/ss_$$.png

  # Create an iPhone-like bezel (stroke around the mask)
  magick -size "${scaled_w}x${scaled_h}" xc:none \
    -fill none -stroke "#333333" -strokewidth 12 \
    -draw "roundrectangle 6,6 $((scaled_w-7)),$((scaled_h-7)) ${corner_radius},${corner_radius}" \
    /tmp/bezel_$$.png
    
  # Combine screenshot and bezel
  magick /tmp/ss_$$.png /tmp/bezel_$$.png -composite /tmp/framed_ss_$$.png

  # Compose final image with gradient background (Clean White style)
  magick -size "${CANVAS_W}x${CANVAS_H}" gradient:"#FFFFFF-#F4F4F5" \
    /tmp/framed_ss_$$.png -geometry "+${ss_x}+${ss_y}" -composite \
    -gravity North \
    -font "$font_bold" -pointsize 110 -fill "#111111" \
    -annotate +0+180 "$keyword" \
    -font "$font_reg" -pointsize 72 -fill "rgba(17,17,17,0.75)" \
    -annotate +0+320 "$title" \
    -depth 8 "$output"

  rm -f /tmp/mask_$$.png /tmp/ss_$$.png /tmp/bezel_$$.png /tmp/framed_ss_$$.png
  echo "  -> $output"
}

# Process English
echo "=== English ==="
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja <<< "$entry"
  compose_screenshot "$key" "$kw_en" "$tt_en" "en-US" "$FONT_EN_BOLD" "$FONT_EN_REG"
done

# Process Japanese
echo ""
echo "=== Japanese ==="
mkdir -p "${SCRIPT_DIR}/ja"
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja <<< "$entry"
  # Copy source screenshot to ja dir if not exists
  if [ ! -f "${SCRIPT_DIR}/ja/${key}.png" ]; then
    cp "${SCRIPT_DIR}/en-US/${key}.png" "${SCRIPT_DIR}/ja/${key}.png" 2>/dev/null || true
  fi
  compose_screenshot "$key" "$kw_ja" "$tt_ja" "ja" "$FONT_JA_BOLD" "$FONT_JA_REG"
done

# === iPad (2064x2752) ===
IPAD_CANVAS_W=2064
IPAD_CANVAS_H=2752

compose_ipad_screenshot() {
  local key="$1" keyword="$2" title="$3" lang_dir="$4" font_bold="$5" font_reg="$6" src_dir="$7"
  local input="${SCRIPT_DIR}/${src_dir}/ipad_${key}.png"
  local output="${SCRIPT_DIR}/${lang_dir}/ipad_${key}_framed.png"

  if [ ! -f "$input" ]; then
    echo "SKIP: $input not found"
    return
  fi

  local src_w src_h
  read -r src_w src_h <<< "$(magick identify -format '%w %h' "$input")"

  local pad=100
  local max_w=$((IPAD_CANVAS_W - pad * 2))
  local scale_ratio
  scale_ratio=$(echo "scale=6; $max_w / $src_w" | bc)
  local scaled_w=$max_w
  local scaled_h
  scaled_h=$(echo "$src_h * $scale_ratio / 1" | bc)

  local text_area_h=500

  local avail_h=$((IPAD_CANVAS_H - text_area_h - 20))
  if [ "$scaled_h" -gt "$avail_h" ]; then
    scale_ratio=$(echo "scale=6; $avail_h / $src_h" | bc)
    scaled_h=$avail_h
    scaled_w=$(echo "$src_w * $scale_ratio / 1" | bc)
  fi

  local ss_x=$(( (IPAD_CANVAS_W - scaled_w) / 2 ))
  local ss_y=$text_area_h

  echo "Composing iPad: ipad_$key ($lang_dir)"

  # iPad hardware bezel sizes
  local bezel_thickness=36
  local screen_w=$((scaled_w - bezel_thickness * 2))
  local screen_h=$((scaled_h - bezel_thickness * 2))
  local inner_radius=40
  local outer_radius=76

  # 1. Resize input to screen size
  local tmp_screen=/tmp/screen_$$.png
  magick "$input" -resize "${screen_w}x${screen_h}!" "$tmp_screen"

  # 2. Mask the screen for inner curves
  magick -size "${screen_w}x${screen_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((screen_w-1)),$((screen_h-1)) ${inner_radius},${inner_radius}" \
    /tmp/inner_mask_$$.png
  magick "$tmp_screen" \( /tmp/inner_mask_$$.png -alpha off \) -compose CopyOpacity -composite /tmp/screen_masked_$$.png

  # 3. Create the outer iPad hardware bezel shape (ensure sRGB colorspace)
  local tmp_bezel=/tmp/bezel_$$.png
  magick -size "${scaled_w}x${scaled_h}" xc:none -colorspace sRGB \
    -fill "#111111" -draw "roundrectangle 0,0 $((scaled_w-1)),$((scaled_h-1)) ${outer_radius},${outer_radius}" \
    "$tmp_bezel"

  # 4. Composite the screen onto the bezel (preserve color)
  local tmp_device=/tmp/device_$$.png
  magick "$tmp_bezel" -colorspace sRGB /tmp/screen_masked_$$.png -geometry "+${bezel_thickness}+${bezel_thickness}" -composite "$tmp_device"

  # 5. Thin outline frame for realism
  magick -size "${scaled_w}x${scaled_h}" xc:none \
    -fill none -stroke "#333333" -strokewidth 4 \
    -draw "roundrectangle 2,2 $((scaled_w-3)),$((scaled_h-3)) ${outer_radius},${outer_radius}" \
    /tmp/outline_$$.png
  magick "$tmp_device" /tmp/outline_$$.png -composite "$tmp_device"

  # Compose final image with gradient background (Clean White style)
  magick -size "${IPAD_CANVAS_W}x${IPAD_CANVAS_H}" gradient:"#FFFFFF-#F4F4F5" \
    "$tmp_device" -geometry "+${ss_x}+${ss_y}" -composite \
    -gravity North \
    -font "$font_bold" -pointsize 100 -fill "#111111" \
    -annotate +0+150 "$keyword" \
    -font "$font_reg" -pointsize 64 -fill "rgba(17,17,17,0.75)" \
    -annotate +0+280 "$title" \
    -depth 8 "$output"

  rm -f /tmp/screen_$$.png /tmp/inner_mask_$$.png /tmp/screen_masked_$$.png /tmp/bezel_$$.png /tmp/device_$$.png /tmp/outline_$$.png
  echo "  -> $output"
}

echo ""
echo "=== iPad English ==="
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_en" "$tt_en" "en-US" "$FONT_EN_BOLD" "$FONT_EN_REG" "en-US"
done

echo ""
echo "=== iPad Japanese ==="
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_ja" "$tt_ja" "ja" "$FONT_JA_BOLD" "$FONT_JA_REG" "en-US"
done

# === README banner (4 screenshots side by side, resized to 1200px width) ===
echo ""
echo "=== README banner ==="
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
README_IMG_DIR="${REPO_ROOT}/docs/images"
mkdir -p "$README_IMG_DIR"

README_KEYS=("01_session_list" "03_multi_question" "04_markdown_input" "05_named_sessions")

for lang_dir in en-US ja; do
  README_INPUTS=()
  for k in "${README_KEYS[@]}"; do
    README_INPUTS+=("${SCRIPT_DIR}/${lang_dir}/${k}_framed.png")
  done

  if [ "$lang_dir" = "en-US" ]; then
    README_OUTPUT="${README_IMG_DIR}/screenshots.png"
  else
    README_OUTPUT="${README_IMG_DIR}/screenshots-${lang_dir}.png"
  fi

  magick "${README_INPUTS[@]}" +append -resize 1200x "$README_OUTPUT"
  echo "  -> $README_OUTPUT ($(du -h "$README_OUTPUT" | cut -f1))"
done

# === Copy framed screenshots to store upload directories ===
# iOS: screenshots/store/{en-US,ja}/ (used by fastlane deliver)
# Android: metadata/android/{en-US,ja-JP}/images/phoneScreenshots/
echo ""
echo "=== Store upload directories ==="
STORE_DIR="${SCRIPT_DIR}/store"
ANDROID_META="${SCRIPT_DIR}/../../fastlane/metadata/android"

for lang_dir in en-US ja; do
  # iOS store directory
  store_lang_dir="${STORE_DIR}/${lang_dir}"
  mkdir -p "$store_lang_dir"
  rm -f "$store_lang_dir"/*.png
  for f in "${SCRIPT_DIR}/${lang_dir}"/*_framed.png; do
    [ -f "$f" ] || continue
    name=$(basename "$f" | sed 's/_framed//')
    cp "$f" "$store_lang_dir/$name"
  done
  echo "  iOS  -> $store_lang_dir/ ($(ls "$store_lang_dir" | wc -l | tr -d ' ') files)"

  # Android metadata directory (phone screenshots only)
  if [ "$lang_dir" = "en-US" ]; then
    android_lang="en-US"
  else
    android_lang="ja-JP"
  fi
  android_ss_dir="${ANDROID_META}/${android_lang}/images/phoneScreenshots"
  mkdir -p "$android_ss_dir"
  rm -f "$android_ss_dir"/*.png
  for f in "${SCRIPT_DIR}/${lang_dir}"/*_framed.png; do
    [ -f "$f" ] || continue
    name=$(basename "$f" | sed 's/_framed//')
    # Skip iPad screenshots (Android phone screenshots only)
    case "$name" in ipad_*) continue ;; esac
    cp "$f" "$android_ss_dir/$name"
  done
  echo "  Android -> $android_ss_dir/ ($(ls "$android_ss_dir" | wc -l | tr -d ' ') files)"
done

echo ""
echo "Done! Framed screenshots have '_framed' suffix."
