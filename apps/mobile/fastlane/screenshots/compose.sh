#!/bin/bash
# Compose store screenshots: dark background + keyword/title text + screenshot
# Output: 1320x2868 (App Store 6.9" requirement)
set -euo pipefail
if [ -n "${PPO_OUTPUT_DIR:-}" ]; then
  echo "PPO_OUTPUT_DIR belongs to the retired illustration experiment. Use a separately designed treatment for a new experiment." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVAS_W=1320
CANVAS_H=2868
BG_COLOR="#101212"
MINT="#9BDDC5"
# Strip timestamps from PNG to avoid spurious git diffs
PNG_STRIP="-define png:exclude-chunks=date,time"

# Font settings
# Try font name first (works with system ImageMagick), fall back to file path (Homebrew)
resolve_font() {
  local name="$1" path="$2"
  if magick -list font 2>/dev/null | grep "Font: ${name}$" >/dev/null 2>&1; then
    echo "$name"
  else
    echo "$path"
  fi
}

resolve_font_candidates() {
  local fallback=""
  while [ "$#" -gt 0 ]; do
    local name="$1" path="$2"
    [ -z "$fallback" ] && fallback="$path"
    if magick -list font 2>/dev/null | grep "Font: ${name}$" >/dev/null 2>&1; then
      echo "$name"
      return
    fi
    if [ -f "$path" ]; then
      echo "$path"
      return
    fi
    shift 2
  done
  echo "$fallback"
}
FONT_EN_BOLD="$(resolve_font Helvetica-Bold /System/Library/Fonts/Helvetica.ttc)"
FONT_EN_REG="$(resolve_font Helvetica /System/Library/Fonts/Helvetica.ttc)"
FONT_JA_BOLD="$(resolve_font Hiragino-Sans-W7 '/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc')"
FONT_JA_REG="$(resolve_font Hiragino-Sans-W3 '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc')"
FONT_ZH_BOLD="$(resolve_font PingFang-SC-Semibold /System/Library/Fonts/PingFang.ttc)"
FONT_ZH_REG="$(resolve_font PingFang-SC-Regular /System/Library/Fonts/PingFang.ttc)"
FONT_KO_BOLD="$(resolve_font_candidates \
  Noto-Sans-CJK-KR-Bold /Library/Fonts/NotoSansCJKkr-Bold.otf \
  Pretendard-Bold /Library/Fonts/Pretendard-Bold.otf \
  Apple-SD-Gothic-Neo-Bold /System/Library/Fonts/AppleSDGothicNeo.ttc)"
FONT_KO_REG="$(resolve_font_candidates \
  Noto-Sans-CJK-KR-Regular /Library/Fonts/NotoSansCJKkr-Regular.otf \
  Pretendard-Regular /Library/Fonts/Pretendard-Regular.otf \
  Apple-SD-Gothic-Neo-Regular /System/Library/Fonts/AppleSDGothicNeo.ttc)"
# Screenshot definitions: key, keyword_en, title_en, keyword_ja, title_ja, keyword_zh, title_zh, keyword_ko, title_ko
SCREENSHOTS=(
  "01_conversation|Your agents.\nIn your pocket.|Codex and Claude, made for your phone.|エージェントを、\nポケットに。|CodexとClaudeを、チャット感覚で。|把编程代理，\n装进口袋。|像聊天一样使用 Codex 和 Claude。|에이전트를\n주머니에.|Codex와 Claude를 채팅처럼."
  "02_recent_sessions|Pick up\nwhere you left off.|Open the same work on your phone or Mac.|どこでも、\n続きから。|スマホでもMacでも、同じ作業を。|换个设备，\n继续工作。|手机或 Mac，都能打开同一项工作。|어디서든\n이어서.|휴대폰이나 Mac에서 같은 작업을."
  "03_approval_list|Your next move.\nOne tap away.|Review waiting approvals in one place.|次の判断を、\nワンタップで。|複数セッションの承認を、ひとつの一覧で。|下一步，\n轻点就好。|在一个列表中查看待审批操作。|다음 결정도\n한 번의 탭으로.|여러 세션의 승인 대기를 한곳에서."
  "04_git_review|Review it.\nShip it.|Inspect diffs, stage, commit, and push.|差分を見て、\nそのまま反映。|レビューからコミット、pushまで。|查看差异，\n提交变更。|审查、暂存、提交和推送。|검토하고,\n반영하세요.|diff 확인부터 커밋과 push까지."
  "05_network_resilience|Bad signal.\nKeep your place.|Queued messages send after reconnecting.|電波が途切れても、\nその先へ。|入力を保持。再接続後に自動送信。|断网也不丢\n输入。|消息暂存，重连后自动发送。|연결이 끊겨도\n입력은 그대로.|메시지를 보관하고 재연결 후 전송."
  "06_imagegen|An idea.\nAn image.|Generate with Codex Imagegen. View in chat.|アイデアを、\n画像に。|Codex Imagegenで生成。チャットで確認。|把想法，\n变成图片。|用 Codex Imagegen 生成，在聊天中查看。|아이디어를\n이미지로.|Codex Imagegen으로 만들고 채팅에서 확인."
  "07_video|Press play.\nStay in the app.|Preview video, seek, or go full screen.|つくった動画を、\nその場で再生。|シークも、全画面表示も。|视频预览，\n就在这里。|拖动进度，切换全屏。|만든 영상을\n바로 재생.|탐색부터 전체 화면까지."
  "08_audio|Listen.\nKeep creating.|Play audio files without switching apps.|音も、そのまま。\nアプリの中で。|アプリを切り替えずに試聴。|听一听，\n继续创作。|无需切换应用即可播放音频。|소리도\n앱 안에서.|앱을 바꾸지 않고 오디오 재생."
)

IPAD_SCREENSHOTS=(
  "01_workspace_overview|Workspace on iPad|Chat, sessions, and Git side by side|iPadワークスペース|会話、セッション、Gitを並べて確認|iPad 工作区|聊天、会话和 Git 并排显示|iPad 워크스페이스|채팅, 세션, Git을 나란히"
  "02_workspace_explorer|Explorer beside chat|Keep project files next to the conversation|チャット横にExplorer|会話しながらファイル確認|聊天旁的 Explorer|对话旁边查看项目文件|채팅 옆 Explorer|대화 옆에서 파일 확인"
  "03_approval_context|Approve in context|Answer without leaving the workspace|文脈のまま承認|ワークスペースを離れず判断|在上下文中审批|不离开工作区即可回答|맥락 안에서 승인|워크스페이스를 떠나지 않고 답변"
  "04_approval_queue|Approval queue|Review waiting sessions together|承認キュー|複数セッションの待ちをまとめて処理|审批队列|集中处理等待中的会话|승인 대기열|기다리는 세션을 한곳에서 처리"
  "05_dark_workspace|Focused dark workspace|A desktop-like layout on iPad and foldables|集中できるダーク画面|iPadやフォルダブルでデスクトップのように|专注深色工作区|在 iPad 和折叠屏上获得桌面式布局|집중을 위한 다크 화면|iPad와 폴더블에서 데스크톱 같은 레이아웃"
)

phone_key_is_current() {
  local candidate="$1"
  local entry key
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key _ <<< "$entry"
    if [ "$candidate" = "$key" ]; then
      return 0
    fi
  done
  return 1
}

cleanup_obsolete_phone_outputs() {
  local lang_dir="$1"
  local dir="${SCRIPT_DIR}/${lang_dir}"
  [ -d "$dir" ] || return

  local f name key
  shopt -s nullglob
  for f in "$dir"/0[1-8]_*.png; do
    name="$(basename "$f" .png)"
    key="${name%_framed}"
    if ! phone_key_is_current "$key"; then
      rm -f "$f"
      echo "Removed obsolete screenshot: $f"
    fi
  done
  shopt -u nullglob
}

for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key _ <<< "$entry"
  test -f "${SCRIPT_DIR}/en-US/${key}.png" || { echo "Missing raw capture: $key" >&2; exit 1; }
done
for entry in "${IPAD_SCREENSHOTS[@]}"; do
  IFS='|' read -r key _ <<< "$entry"
  test -f "${SCRIPT_DIR}/en-US/ipad_${key}.png" || { echo "Missing iPad capture: $key" >&2; exit 1; }
done

for lang_dir in en-US ja zh-CN ko; do
  cleanup_obsolete_phone_outputs "$lang_dir"
done

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

  # Fit the complete screen inside a separate hardware bezel. Never draw the
  # frame on top of screenshot pixels, and derive concentric corner radii.
  local bezel=16
  local pad=110
  local ss_y=520
  local max_w=$((CANVAS_W - pad * 2 - bezel * 2))
  local max_h=$((CANVAS_H - ss_y - 90 - bezel * 2))
  local scale_ratio
  scale_ratio=$(echo "scale=8; $max_w / $src_w" | bc)
  local screen_w=$max_w
  local screen_h
  screen_h=$(echo "$src_h * $scale_ratio / 1" | bc)
  if [ "$screen_h" -gt "$max_h" ]; then
    scale_ratio=$(echo "scale=8; $max_h / $src_h" | bc)
    screen_h=$max_h
    screen_w=$(echo "$src_w * $scale_ratio / 1" | bc)
  fi
  local device_w=$((screen_w + bezel * 2))
  local device_h=$((screen_h + bezel * 2))
  local ss_x=$(( (CANVAS_W - device_w) / 2 ))
  local inner_radius=$((screen_w * 105 / 1000))
  local outer_radius=$((inner_radius + bezel))

  echo "Composing: $key ($lang_dir)"

  # The mask uses luminance; the source image keeps its own native UI colors.
  magick -size "${screen_w}x${screen_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((screen_w-1)),$((screen_h-1)) ${inner_radius},${inner_radius}" \
    /tmp/mask_$$.png
  magick "$input" -resize "${screen_w}x${screen_h}!" \
    \( /tmp/mask_$$.png -alpha off \) -compose CopyOpacity -composite \
    /tmp/ss_$$.png

  # Keep the outer edge, bezel, and screen separate and concentric.
  magick -size "${device_w}x${device_h}" xc:none \
    -fill '#252828' -stroke '#525957' -strokewidth 3 \
    -draw "roundrectangle 2,2 $((device_w-3)),$((device_h-3)) ${outer_radius},${outer_radius}" \
    /tmp/ss_$$.png -geometry "+${bezel}+${bezel}" -composite \
    /tmp/framed_ss_$$.png

  local bg_gradient="xc:$BG_COLOR"
  local text_fill="$MINT"
  local subtitle_fill="#A6B0AD"

  magick -background none -size "1120x255" -gravity west \
    -font "$font_bold" -pointsize 98 -fill "$text_fill" \
    caption:"$(printf '%b' "$keyword")" /tmp/keyword_$$.png

  magick -background none -size "1120x150" -gravity west \
    -font "$font_reg" -pointsize 44 -fill "$subtitle_fill" \
    caption:"$title" /tmp/title_$$.png

  magick -size "${CANVAS_W}x${CANVAS_H}" "$bg_gradient" \
    /tmp/framed_ss_$$.png -geometry "+${ss_x}+${ss_y}" -composite \
    /tmp/keyword_$$.png -geometry "+100+60" -composite \
    /tmp/title_$$.png -geometry "+100+310" -composite \
    -alpha off -depth 8 $PNG_STRIP "$output"

  rm -f /tmp/mask_$$.png /tmp/ss_$$.png /tmp/bezel_$$.png /tmp/framed_ss_$$.png \
    /tmp/keyword_$$.png /tmp/title_$$.png
  echo "  -> $output"
}

# Process English
echo "=== English ==="
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  compose_screenshot "$key" "$kw_en" "$tt_en" "en-US" "$FONT_EN_BOLD" "$FONT_EN_REG"
done

# Process Japanese
echo ""
echo "=== Japanese ==="
mkdir -p "${SCRIPT_DIR}/ja"
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  # Always copy latest source screenshot from en-US
  cp "${SCRIPT_DIR}/en-US/${key}.png" "${SCRIPT_DIR}/ja/${key}.png" 2>/dev/null || true
  compose_screenshot "$key" "$kw_ja" "$tt_ja" "ja" "$FONT_JA_BOLD" "$FONT_JA_REG"
done

# Process Chinese (Simplified)
echo ""
echo "=== Chinese (Simplified) ==="
mkdir -p "${SCRIPT_DIR}/zh-CN"
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  # Always copy latest source screenshot from en-US
  cp "${SCRIPT_DIR}/en-US/${key}.png" "${SCRIPT_DIR}/zh-CN/${key}.png" 2>/dev/null || true
  compose_screenshot "$key" "$kw_zh" "$tt_zh" "zh-CN" "$FONT_ZH_BOLD" "$FONT_ZH_REG"
done

# Process Korean
echo ""
echo "=== Korean ==="
mkdir -p "${SCRIPT_DIR}/ko"
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  # Always copy latest source screenshot from en-US
  cp "${SCRIPT_DIR}/en-US/${key}.png" "${SCRIPT_DIR}/ko/${key}.png" 2>/dev/null || true
  compose_screenshot "$key" "$kw_ko" "$tt_ko" "ko" "$FONT_KO_BOLD" "$FONT_KO_REG"
done

# === iPad Landscape (2752x2064) ===
IPAD_CANVAS_W=2752
IPAD_CANVAS_H=2064

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

  local pad=140
  local max_w=$((IPAD_CANVAS_W - pad * 2))
  local scale_ratio
  scale_ratio=$(echo "scale=6; $max_w / $src_w" | bc)
  local scaled_w=$max_w
  local scaled_h
  scaled_h=$(echo "$src_h * $scale_ratio / 1" | bc)

  local text_area_h=360

  local avail_h=$((IPAD_CANVAS_H - text_area_h - 100))
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

  local bg_gradient="xc:$BG_COLOR"
  local text_fill="$MINT"
  local subtitle_fill="#A6B0AD"

  magick -size "${IPAD_CANVAS_W}x${IPAD_CANVAS_H}" "$bg_gradient" \
    "$tmp_device" -geometry "+${ss_x}+${ss_y}" -composite \
    -gravity North \
    -font "$font_bold" -pointsize 106 -fill "$text_fill" \
    -annotate +0+96 "$keyword" \
    -font "$font_reg" -pointsize 62 -fill "$subtitle_fill" \
    -annotate +0+260 "$title" \
    -alpha off -depth 8 $PNG_STRIP "$output"

  rm -f /tmp/screen_$$.png /tmp/inner_mask_$$.png /tmp/screen_masked_$$.png /tmp/bezel_$$.png /tmp/device_$$.png /tmp/outline_$$.png
  echo "  -> $output"
}

echo ""
echo "=== iPad English ==="
for entry in "${IPAD_SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_en" "$tt_en" "en-US" "$FONT_EN_BOLD" "$FONT_EN_REG" "en-US"
done

echo ""
echo "=== iPad Japanese ==="
for entry in "${IPAD_SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_ja" "$tt_ja" "ja" "$FONT_JA_BOLD" "$FONT_JA_REG" "en-US"
done

echo ""
echo "=== iPad Chinese (Simplified) ==="
for entry in "${IPAD_SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_zh" "$tt_zh" "zh-CN" "$FONT_ZH_BOLD" "$FONT_ZH_REG" "en-US"
done

echo ""
echo "=== iPad Korean ==="
for entry in "${IPAD_SCREENSHOTS[@]}"; do
  IFS='|' read -r key kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
  compose_ipad_screenshot "$key" "$kw_ko" "$tt_ko" "ko" "$FONT_KO_BOLD" "$FONT_KO_REG" "en-US"
done

# === README banner (4 screenshots side by side, resized to 1200px width) ===
echo ""
echo "=== README banner ==="
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
README_IMG_DIR="${REPO_ROOT}/docs/images"
mkdir -p "$README_IMG_DIR"

README_KEYS=("01_conversation" "03_approval_list" "06_imagegen" "07_video")

for lang_dir in en-US ja zh-CN ko; do
  README_INPUTS=()
  for k in "${README_KEYS[@]}"; do
    README_INPUTS+=("${SCRIPT_DIR}/${lang_dir}/${k}_framed.png")
  done

  if [ "$lang_dir" = "en-US" ]; then
    README_OUTPUT="${README_IMG_DIR}/screenshots.png"
  else
    README_OUTPUT="${README_IMG_DIR}/screenshots-${lang_dir}.png"
  fi

  magick "${README_INPUTS[@]}" +append -resize 1800x -alpha off -depth 8 $PNG_STRIP "$README_OUTPUT"
  echo "  -> $README_OUTPUT ($(du -h "$README_OUTPUT" | cut -f1))"
done

# === Copy framed screenshots to store upload directories ===
# iOS: screenshots/store/{en-US,ja,zh-Hans,ko}/ (used by fastlane deliver)
# Android: metadata/android/{en-US,ja-JP,zh-CN,ko-KR}/images/phoneScreenshots/
echo ""
echo "=== Store upload directories ==="
STORE_DIR="${SCRIPT_DIR}/store"
ANDROID_META="${SCRIPT_DIR}/../../fastlane/metadata/android"

for lang_dir in en-US ja zh-CN ko; do
  # iOS uses zh-Hans for Simplified Chinese, while Android keeps zh-CN.
  if [ "$lang_dir" = "zh-CN" ]; then
    ios_lang="zh-Hans"
  else
    ios_lang="$lang_dir"
  fi
  store_lang_dir="${STORE_DIR}/${ios_lang}"
  mkdir -p "$store_lang_dir"
  rm -f "$store_lang_dir"/*.png
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key _ <<< "$entry"
    f="${SCRIPT_DIR}/${lang_dir}/${key}_framed.png"
    [ -f "$f" ] || continue
    cp "$f" "$store_lang_dir/${key}.png"
  done
  for entry in "${IPAD_SCREENSHOTS[@]}"; do
    IFS='|' read -r key _ <<< "$entry"
    f="${SCRIPT_DIR}/${lang_dir}/ipad_${key}_framed.png"
    [ -f "$f" ] || continue
    cp "$f" "$store_lang_dir/ipad_${key}.png"
  done
  echo "  iOS  -> $store_lang_dir/ ($(ls "$store_lang_dir" | wc -l | tr -d ' ') files)"

  # Android metadata directory (phone screenshots only)
  if [ "$lang_dir" = "en-US" ]; then
    android_lang="en-US"
  elif [ "$lang_dir" = "ja" ]; then
    android_lang="ja-JP"
  elif [ "$lang_dir" = "ko" ]; then
    android_lang="ko-KR"
  else
    android_lang="zh-CN"
  fi
  android_ss_dir="${ANDROID_META}/${android_lang}/images/phoneScreenshots"
  mkdir -p "$android_ss_dir"
  rm -f "$android_ss_dir"/*.png
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key _ <<< "$entry"
    f="${SCRIPT_DIR}/${lang_dir}/${key}_framed.png"
    [ -f "$f" ] || continue
    cp "$f" "$android_ss_dir/${key}.png"
  done
  echo "  Android -> $android_ss_dir/ ($(ls "$android_ss_dir" | wc -l | tr -d ' ') files)"
done

echo "Done! Framed screenshots have '_framed' suffix."
