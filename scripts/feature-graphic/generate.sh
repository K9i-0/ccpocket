#!/usr/bin/env bash
# Mint feature graphics, using the same real iPhone captures as the store set.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
META="$ROOT/apps/mobile/fastlane/metadata/android"
RAW="$ROOT/apps/mobile/fastlane/screenshots/en-US"
ICON="$ROOT/apps/mobile/assets/icon.png"
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

magick "$RAW/01_conversation.png" -resize 200x "$work_dir/chat.png"
magick "$RAW/06_imagegen.png" -resize 200x "$work_dir/imagegen.png"
magick "$ICON" -resize 40x40 "$work_dir/icon.png"

generate() {
  local locale="$1" headline="$2" font="$3" point="$4"
  local output="$META/$locale/images/featureGraphic.png"
  mkdir -p "$(dirname "$output")"
  magick -background none -size 540x200 -gravity west \
    -font "$font" -pointsize "$point" -fill '#9BDDC5' \
    caption:"$(printf '%b' "$headline")" "$work_dir/title.png"
  magick -size 1024x500 xc:'#101212' \
    "$work_dir/icon.png" -geometry +52+54 -composite \
    -font Helvetica-Bold -pointsize 24 -fill '#F4F5F4' -annotate +106+83 'CC Pocket' \
    "$work_dir/title.png" -geometry +52+150 -composite \
    -font Helvetica -pointsize 20 -fill '#A6B0AD' -annotate +54+387 'Codex / Claude' \
    "$work_dir/chat.png" -geometry +614+56 -composite \
    "$work_dir/imagegen.png" -geometry +836+130 -composite \
    -alpha off -depth 8 -define png:exclude-chunks=date,time "$output"
  echo "$output"
}

generate en-US 'Your agents.\nIn your pocket.' Helvetica-Bold 58
generate ja-JP 'エージェントを、\nポケットに。' '/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc' 52
generate zh-CN '把编程代理，\n装进口袋。' PingFang-SC-Semibold 56
generate ko-KR '에이전트를\n주머니에.' Apple-SD-Gothic-Neo-Bold 60
