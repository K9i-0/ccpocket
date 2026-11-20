#!/usr/bin/env bash
# Dual-glow Google Play feature graphics (1024x500), using real framed iPhone captures.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
META="$ROOT/apps/mobile/fastlane/metadata/android"
RAW="$ROOT/apps/mobile/fastlane/screenshots/en-US"
ICON="$ROOT/apps/mobile/assets/icon.png"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# Build rounded app icon (48x48)
magick "$ICON" -resize 48x48! \
  \( -size 48x48 xc:black -fill white -draw "roundrectangle 0,0 47,47 12,12" \) \
  -alpha off -compose CopyOpacity -composite "$work_dir/icon.png"

# Build a framed mini iPhone mockup with shadow
make_phone() {
  local src="$1" width="$2" angle="$3" out="$4"
  local bezel=8
  local screen_w=$((width - bezel * 2))
  local src_w src_h
  read -r src_w src_h <<< "$(magick identify -format '%w %h' "$src")"
  local screen_h=$((src_h * screen_w / src_w))
  local dev_h=$((screen_h + bezel * 2))
  local ir=$((screen_w * 11 / 100))
  local or=$((ir + bezel))

  magick -size "${screen_w}x${screen_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((screen_w-1)),$((screen_h-1)) ${ir},${ir}" \
    "$work_dir/pmask.png"
  magick "$src" -resize "${screen_w}x${screen_h}!" \
    \( "$work_dir/pmask.png" -alpha off \) -compose CopyOpacity -composite \
    "$work_dir/pscreen.png"

  magick -size "${width}x${dev_h}" "gradient:#424847-#161818" -colorspace sRGB \
    \( -size "${width}x${dev_h}" xc:black -fill white \
       -draw "roundrectangle 0,0 $((width-1)),$((dev_h-1)) ${or},${or}" \) \
    -alpha off -compose CopyOpacity -composite \
    -fill none -stroke "rgba(255,255,255,0.24)" -strokewidth 1.5 \
    -draw "roundrectangle 1,1 $((width-2)),$((dev_h-2)) ${or},${or}" \
    -fill "#0D0F0F" -stroke none \
    -draw "roundrectangle 3,3 $((width-4)),$((dev_h-4)) $((or-2)),$((or-2))" \
    "$work_dir/pscreen.png" -geometry "+${bezel}+${bezel}" -compose over -composite \
    -background none -rotate "$angle" \
    \( +clone -background black -shadow 72x22+0+16 \) +swap \
    -background none -layers merge +repage \
    "$out"
}

# Back phone: approvals list, tilted slightly left; Front phone: conversation, tilted slightly right
make_phone "$RAW/03_approval_list.png" 214 -6 "$work_dir/phone_back.png"
make_phone "$RAW/01_conversation.png" 236 5 "$work_dir/phone_front.png"

# Agent pill strip
make_agent_pill() {
  local label="$1" dot_color="$2" text_color="$3" border_color="$4" out="$5"
  magick -background none -font Helvetica-Bold -pointsize 16 \
    -fill "$text_color" "label:${label}" -trim +repage "$work_dir/ap_txt.png"
  local tw th pw ph r
  read -r tw th <<< "$(magick identify -format '%w %h' "$work_dir/ap_txt.png")"
  pw=$((tw + 38))
  ph=34
  r=17
  magick -size "${pw}x${ph}" xc:none -colorspace sRGB \
    -fill "rgba(255,255,255,0.05)" -stroke "$border_color" -strokewidth 1.5 \
    -draw "roundrectangle 1,1 $((pw-2)),$((ph-2)) ${r},${r}" \
    -fill "$dot_color" -stroke none -draw "circle 15,17 19,17" \
    "$work_dir/ap_txt.png" -gravity west -geometry +26+0 -composite \
    "$out"
}

make_agent_pill "Codex" "#5EEAD4" "#9BDDC5" "rgba(94,234,212,0.32)" "$work_dir/pill_codex.png"
make_agent_pill "Claude" "#F5A46A" "#FDBA74" "rgba(245,164,106,0.32)" "$work_dir/pill_claude.png"
make_agent_pill "Antigravity" "#8AB4F8" "#A8C7FA" "rgba(138,180,248,0.32)" "$work_dir/pill_agy.png"

# Prebuild shared base canvas with dual glows & subtle orbit
magick -size 760x760 "radial-gradient:#2BB38A-none" \
  -channel A -evaluate multiply 0.24 +channel "$work_dir/fg_g1.png"
magick -size 760x760 "radial-gradient:#E07838-none" \
  -channel A -evaluate multiply 0.20 +channel "$work_dir/fg_g2.png"

magick -size 1024x500 xc:'#0B0D0E' -colorspace sRGB \
  "$work_dir/fg_g1.png" -geometry "-160-240" -compose screen -composite \
  "$work_dir/fg_g2.png" -geometry "+440+40" -compose screen -composite \
  -fill none -stroke "rgba(255,255,255,0.05)" -strokewidth 1.5 \
  -draw "ellipse 760,260 280,220 0,360" \
  -draw "ellipse 760,260 340,265 0,360" \
  "$work_dir/phone_back.png" -geometry "+542+46" -compose over -composite \
  "$work_dir/phone_front.png" -geometry "+726+16" -compose over -composite \
  "$work_dir/base.png"

generate() {
  local locale="$1" line1="$2" line2="$3" font="$4" point="$5"
  local output="$META/$locale/images/featureGraphic.png"
  mkdir -p "$(dirname "$output")"

  local p1_w p2_w
  p1_w=$(magick identify -format '%w' "$work_dir/pill_codex.png")
  p2_w=$(magick identify -format '%w' "$work_dir/pill_claude.png")
  local x2=$((54 + p1_w + 10))
  local x3=$((x2 + p2_w + 10))

  magick "$work_dir/base.png" \
    "$work_dir/icon.png" -geometry "+54+52" -compose over -composite \
    -font Helvetica-Bold -pointsize 25 -fill '#F4F6F5' -annotate +116+85 'CC Pocket' \
    -font "$font" -pointsize "$point" -fill '#F4F6F5' -annotate +54+220 "$line1" \
    -font "$font" -pointsize "$point" -fill '#9BDDC5' -annotate +54+294 "$line2" \
    "$work_dir/pill_codex.png" -geometry "+54+390" -compose over -composite \
    "$work_dir/pill_claude.png" -geometry "+${x2}+390" -compose over -composite \
    "$work_dir/pill_agy.png" -geometry "+${x3}+390" -compose over -composite \
    -alpha off -depth 8 -define png:exclude-chunks=date,time "$output"
  echo "$output"
}

generate en-US 'Your agents.' 'In your pocket.' Helvetica-Bold 60
generate ja-JP 'エージェントを、' 'ポケットに。' '/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc' 52
generate zh-CN '把编程代理，' '装进口袋。' PingFang-SC-Semibold 56
generate ko-KR '에이전트를' '주머니에.' Apple-SD-Gothic-Neo-Bold 58
