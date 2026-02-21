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
  "01_session_list|Your AI agents|in your pocket|AIエージェントを|ポケットから操作"
  "02_coding_session|Real-time streaming|Watch your agent code|リアルタイム表示|コーディングをライブで"
  "03_task_planning|Structured planning|with thinking & tasks|構造化プランニング|思考とタスク管理"
  "04_approval_flow|Approve tools|right from your phone|ツール承認を|スマホから即座に"
  "05_ask_question|Interactive Q&A|Your agent asks, you decide|エージェントが質問|あなたが判断"
  "06_recent_sessions|All your sessions|organized by project|セッション一覧|プロジェクト別に管理"
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
  local text_area_h=500

  # Cap screenshot height if it overflows
  local avail_h=$((CANVAS_H - text_area_h - 20))
  if [ "$scaled_h" -gt "$avail_h" ]; then
    scale_ratio=$(echo "scale=6; $avail_h / $src_h" | bc)
    scaled_h=$avail_h
    scaled_w=$(echo "$src_w * $scale_ratio / 1" | bc)
  fi

  local ss_x=$(( (CANVAS_W - scaled_w) / 2 ))
  local ss_y=$text_area_h

  local corner_radius=36

  echo "Composing: $key ($lang_dir)"

  # Create rounded-corner mask
  magick -size "${scaled_w}x${scaled_h}" xc:none \
    -fill white -draw "roundrectangle 0,0 $((scaled_w-1)),$((scaled_h-1)) ${corner_radius},${corner_radius}" \
    /tmp/mask_$$.png

  # Apply mask to resized screenshot
  magick "$input" -resize "${scaled_w}x${scaled_h}" \
    /tmp/mask_$$.png -alpha off -compose CopyOpacity -composite \
    /tmp/ss_$$.png

  # Compose final image
  magick -size "${CANVAS_W}x${CANVAS_H}" "xc:${BG_COLOR}" \
    /tmp/ss_$$.png -geometry "+${ss_x}+${ss_y}" -composite \
    -gravity North \
    -font "$font_bold" -pointsize 82 -fill white \
    -annotate +0+160 "$keyword" \
    -font "$font_reg" -pointsize 54 -fill "rgba(255,255,255,0.75)" \
    -annotate +0+270 "$title" \
    "$output"

  rm -f /tmp/mask_$$.png /tmp/ss_$$.png
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

echo ""
echo "Done! Framed screenshots have '_framed' suffix."
