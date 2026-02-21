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
  "01_session_list|Your AI agents|in your pocket|AIエージェントを|スマホから操作"
  "02_coding_session|Never miss a line|Live output, wherever you are|リアルタイム出力|ツール実行をそのまま表示"
  "03_task_planning|Know what's next|See your agent's plan unfold|思考とタスク|エージェントの計画を確認"
  "04_approval_flow|Stay in control|Approve or reject, instantly|ツール承認|実行前に許可・拒否"
  "05_ask_question|Agents need you|Answer questions on the go|質問に回答|エージェントからの質問に対応"
  "06_recent_sessions|Multiple projects|One app for every codebase|プロジェクト別|セッションをまとめて管理"
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

  # Compose final image with gradient background (Tech Teal/Green style)
  magick -size "${CANVAS_W}x${CANVAS_H}" gradient:"#0F766E-#34D399" \
    /tmp/framed_ss_$$.png -geometry "+${ss_x}+${ss_y}" -composite \
    -gravity North \
    -font "$font_bold" -pointsize 110 -fill white \
    -annotate +0+180 "$keyword" \
    -font "$font_reg" -pointsize 72 -fill "rgba(255,255,255,0.75)" \
    -annotate +0+320 "$title" \
    "$output"

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

echo ""
echo "Done! Framed screenshots have '_framed' suffix."
