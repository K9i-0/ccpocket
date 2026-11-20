#!/bin/bash
# Compose store screenshots: dual-glow carbon canvas + pill kicker + two-tone headline + titanium-bezel device
# Output: 1320x2868 (App Store 6.9" & Google Play), 1398x2034 (iPhone Duo), 2752x2064 (iPad landscape)
set -euo pipefail
if [ -n "${PPO_OUTPUT_DIR:-}" ]; then
  echo "PPO_OUTPUT_DIR belongs to the retired illustration experiment. Use a separately designed treatment for a new experiment." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANVAS_W=1320
CANVAS_H=2868
BG_COLOR="#0B0D0E"
WHITE="#F4F6F5"
MINT="#9BDDC5"
SUBTITLE_COLOR="#A8B3AF"
# Strip timestamps from PNG to avoid spurious git diffs
PNG_STRIP="-define png:exclude-chunks=date,time"

# Font settings
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

# Screenshot definitions:
# key | kicker | glow1 | glow2 | accent | kw1_en | kw2_en | tt_en | kw1_ja | kw2_ja | tt_ja | kw1_zh | kw2_zh | tt_zh | kw1_ko | kw2_ko | tt_ko
SCREENSHOTS=(
  "01_conversation|CODEX · CLAUDE · ANTIGRAVITY|#2BB38A|#D96B2B|#9BDDC5|Your agents.|In your pocket.|Codex, Claude, and Antigravity in one chat UI.|エージェントを、|ポケットに。|Codex・Claude・AntigravityをひとつのチャットUIで。|把编程代理，|装进口袋。|在一个聊天界面操控 Codex、Claude 和 Antigravity。|에이전트를|주머니에.|Codex, Claude, Antigravity를 하나의 채팅 UI로."
  "02_recent_sessions|THREE AGENTS · ONE LIST|#2BB38A|#4C8BF5|#9BDDC5|Three agents.|One timeline.|Pick up any session across phone, iPad, and Mac.|3つのエージェントを、|ひとつの一覧に。|スマホ・iPad・Macで、同じ作業の続きから。|三大代理，|同一列表。|在手机、iPad 和 Mac 上无缝继续任意会话。|세 에이전트를|한 목록에서.|휴대폰, iPad, Mac 어디서든 같은 작업 이어가기."
  "03_approval_list|ONE-TAP APPROVALS|#E07838|#2BB38A|#F5B380|Your next move.|One tap away.|Approve commands, edits, and plans from one list.|次の判断を、|ワンタップで。|コマンド実行もプラン承認も、ひとつの一覧から。|下一步操作，|轻点即批。|在一个列表中审批命令、文件编辑与实施计划。|다음 결정도|한 번의 탭으로.|명령 실행, 편집, 플랜 승인을 한 목록에서."
  "04_git_review|DIFF REVIEW & GIT|#32B27C|#D96B2B|#9BDDC5|Review diffs.|Ship changes.|Comment on code, stage, commit, and push.|差分を見て、|そのまま反映。|行コメントからstage、commit、pushまで。|审查差异，|直接提交。|评论代码差异，完成暂存、提交与推送。|diff 검토부터|바로 반영까지.|코드 댓글, stage, commit, push를 한 번에."
  "05_network_resilience|OFFLINE-FIRST QUEUE|#2FA89B|#D4883A|#9BDDC5|Weak signal.|Zero lost work.|Queued prompts send automatically on reconnect.|電波が途切れても、|止まらない。|送信待ちを保持し、再接続後に自動で送信。|弱网断连，|输入不丢。|消息自动排队，恢复连接后即刻发送。|신호가 끊겨도|작업은 그대로.|메시지를 보관하고 재연결되면 자동 전송."
  "06_imagegen|IMAGE GENERATION|#E07838|#2BB38A|#F5B380|An idea.|An image.|Generate with Codex or Antigravity. View in chat.|アイデアを、|そのまま画像に。|Codex・Antigravityで生成し、チャットで確認。|灵光一现，|即刻成图。|用 Codex 或 Antigravity 生成，在聊天中查看。|아이디어를|바로 이미지로.|Codex·Antigravity로 생성하고 채팅에서 확인."
  "07_video|IN-APP VIDEO|#4C8BF5|#2BB38A|#9EC5FB|Press play.|Stay in flow.|Preview video, scrub frames, or go full screen.|つくった動画を、|その場で再生。|シーク、再生速度の調整、全画面表示まで。|即点即播，|留在应用内。|预览视频、拖动进度、倍速与全屏播放。|만든 영상을|바로 재생.|탐색, 배속 조절, 전체 화면까지 앱 안에서."
  "08_audio|IN-APP AUDIO|#E07838|#2FA89B|#F5B380|Listen right|inside the app.|Play generated audio without switching tools.|音も、そのまま。|アプリの中で。|アプリを切り替えずに、音声ファイルを試聴。|听一听，|继续创作。|无需切换应用，直接试听音频文件。|소리도 바로|앱 안에서.|앱을 바꾸지 않고 오디오 파일을 재생."
)

# iPad definitions:
# key | kicker | glow1 | glow2 | accent | kw_en | tt_en | kw_ja | tt_ja | kw_zh | tt_zh | kw_ko | tt_ko
IPAD_SCREENSHOTS=(
  "01_workspace_overview|IPAD WORKSPACE|#2BB38A|#D96B2B|#9BDDC5|Workspace on iPad|Chat, sessions, and Git side by side|iPadワークスペース|会話、セッション、Gitを並べて確認|iPad 工作区|聊天、会话和 Git 并排显示|iPad 워크스페이스|채팅, 세션, Git을 나란히"
  "02_workspace_explorer|EXPLORER BESIDE CHAT|#2BB38A|#4C8BF5|#9BDDC5|Explorer beside chat|Keep project files next to the conversation|チャット横にExplorer|会話しながらファイル確認|聊天旁的 Explorer|对话旁边查看项目文件|채팅 옆 Explorer|대화 옆에서 파일 확인"
  "03_approval_context|APPROVE IN CONTEXT|#E07838|#2BB38A|#F5B380|Approve in context|Answer without leaving the workspace|文脈のまま承認|ワークスペースを離れず判断|在上下文中审批|不离开工作区即可回答|맥락 안에서 승인|워크스페이스를 떠나지 않고 답변"
  "04_approval_queue|APPROVAL QUEUE|#E07838|#4C8BF5|#F5B380|Approval queue|Review waiting sessions together|承認キュー|複数セッションの待ちをまとめて処理|审批队列|集中处理等待中的会话|승인 대기열|기다리는 세션을 한곳에서 처리"
  "05_dark_workspace|FOCUSED DARK MODE|#2BB38A|#D96B2B|#9BDDC5|Focused dark workspace|A desktop-like layout on iPad and foldables|集中できるダーク画面|iPadやフォルダブルでデスクトップのように|专注深色工作区|在 iPad 和折叠屏上获得桌面式布局|집중을 위한 다크 화면|iPad와 폴더블에서 데스크톱 같은 레이아웃"
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
for entry in "${SCREENSHOTS[@]}"; do
  IFS='|' read -r key _ <<< "$entry"
  test -f "${SCRIPT_DIR}/en-US/duo_${key}.png" || { echo "Missing iPhone Duo capture: $key" >&2; exit 1; }
  read -r duo_w duo_h <<< "$(magick identify -format '%w %h' "${SCRIPT_DIR}/en-US/duo_${key}.png")"
  [ "$duo_w" = 1398 ] && [ "$duo_h" = 2034 ] ||
    { echo "iPhone Duo capture $key is ${duo_w}x${duo_h}; expected the cover display at 1398x2034" >&2; exit 1; }
done

for lang_dir in en-US ja zh-CN ko; do
  cleanup_obsolete_phone_outputs "$lang_dir"
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Build a subtle dual-glow carbon canvas
make_canvas() {
  local w="$1" h="$2" glow1="$3" glow2="$4" out="$5"
  local g1_size=$((w * 115 / 100))
  local g2_size=$((w * 110 / 100))
  local g1_x=$((w * 35 / 100))
  local g1_y=$((-h * 14 / 100))
  local g2_x=$((-w * 30 / 100))
  local g2_y=$((h * 52 / 100))

  magick -size "${g1_size}x${g1_size}" "radial-gradient:${glow1}-none" \
    -channel A -evaluate multiply 0.20 +channel "$WORK_DIR/g1.png"
  magick -size "${g2_size}x${g2_size}" "radial-gradient:${glow2}-none" \
    -channel A -evaluate multiply 0.14 +channel "$WORK_DIR/g2.png"

  magick -size "${w}x${h}" "xc:${BG_COLOR}" -colorspace sRGB \
    "$WORK_DIR/g1.png" -geometry "+${g1_x}+${g1_y}" -compose screen -composite \
    "$WORK_DIR/g2.png" -geometry "+${g2_x}+${g2_y}" -compose screen -composite \
    -fill none -stroke "rgba(255,255,255,0.035)" -strokewidth 2 \
    -draw "ellipse $((w/2)),$((h*58/100)) $((w*62/100)),$((h*36/100)) 0,360" \
    "$out"
}

# Render a crisp pill badge with auto-fitted width
make_pill() {
  local label="$1" accent="$2" pointsize="$3" pad_x="$4" pad_y="$5" out="$6"
  magick -background none -font "$FONT_EN_BOLD" -pointsize "$pointsize" \
    -kerning 2.2 -fill "$accent" "label:${label}" -trim +repage "$WORK_DIR/pill_txt.png"
  local tw th pw ph r
  read -r tw th <<< "$(magick identify -format '%w %h' "$WORK_DIR/pill_txt.png")"
  pw=$((tw + pad_x * 2))
  ph=$((th + pad_y * 2))
  r=$((ph / 2))
  magick -size "${pw}x${ph}" xc:none -colorspace sRGB \
    -fill "rgba(255,255,255,0.05)" -stroke "rgba(255,255,255,0.16)" -strokewidth 2 \
    -draw "roundrectangle 1,1 $((pw-2)),$((ph-2)) ${r},${r}" \
    "$WORK_DIR/pill_txt.png" -gravity center -composite \
    "$out"
}

compose_screenshot() {
  local key="$1" kicker="$2" glow1="$3" glow2="$4" accent="$5"
  local kw1="$6" kw2="$7" title="$8" lang_dir="$9" font_bold="${10}" font_reg="${11}"
  local input="${SCRIPT_DIR}/${lang_dir}/${key}.png"
  local output="${SCRIPT_DIR}/${lang_dir}/${key}_framed.png"

  if [ ! -f "$input" ]; then
    echo "SKIP: $input not found"
    return
  fi

  local src_w src_h
  read -r src_w src_h <<< "$(magick identify -format '%w %h' "$input")"

  # Fit the complete screen inside a separate titanium hardware bezel.
  local bezel=18
  local pad=114
  local ss_y=590
  local max_w=$((CANVAS_W - pad * 2 - bezel * 2))
  local max_h=$((CANVAS_H - ss_y - 76 - bezel * 2))
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

  # 1. Dual-glow canvas
  make_canvas "$CANVAS_W" "$CANVAS_H" "$glow1" "$glow2" "$WORK_DIR/canvas.png"

  # 2. Screen masked cleanly (preserves native UI colors)
  magick -size "${screen_w}x${screen_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((screen_w-1)),$((screen_h-1)) ${inner_radius},${inner_radius}" \
    "$WORK_DIR/mask.png"
  magick "$input" -resize "${screen_w}x${screen_h}!" \
    \( "$WORK_DIR/mask.png" -alpha off \) -compose CopyOpacity -composite \
    "$WORK_DIR/ss.png"

  # 3. Titanium bezel with subtle metallic sheen & outer stroke + soft shadow
  magick -size "${device_w}x${device_h}" "gradient:#3B4140-#181B1B" -colorspace sRGB \
    \( -size "${device_w}x${device_h}" xc:black -fill white \
       -draw "roundrectangle 0,0 $((device_w-1)),$((device_h-1)) ${outer_radius},${outer_radius}" \) \
    -alpha off -compose CopyOpacity -composite \
    -fill none -stroke "rgba(255,255,255,0.22)" -strokewidth 3 \
    -draw "roundrectangle 2,2 $((device_w-3)),$((device_h-3)) ${outer_radius},${outer_radius}" \
    -fill "#0D0F0F" -stroke none \
    -draw "roundrectangle 7,7 $((device_w-8)),$((device_h-8)) $((outer_radius-5)),$((outer_radius-5))" \
    "$WORK_DIR/ss.png" -geometry "+${bezel}+${bezel}" -compose over -composite \
    "$WORK_DIR/framed_ss.png"

  # Soft ambient drop shadow behind device
  magick "$WORK_DIR/framed_ss.png" \
    \( +clone -background black -shadow 68x36+0+28 \) +swap \
    -background none -layers merge +repage \
    "$WORK_DIR/framed_shadow.png"
  local sh_w sh_h
  read -r sh_w sh_h <<< "$(magick identify -format '%w %h' "$WORK_DIR/framed_shadow.png")"
  local sh_x=$(( (CANVAS_W - sh_w) / 2 ))
  local sh_y=$((ss_y - (sh_h - device_h) / 2 + 12))

  # 4. Kicker pill + two-tone headline + subtitle
  make_pill "$kicker" "$accent" 24 24 14 "$WORK_DIR/pill.png"

  local kw_pt=96
  if [ "$lang_dir" = "ja" ] || [ "$lang_dir" = "zh-CN" ] || [ "$lang_dir" = "ko" ]; then
    kw_pt=88
  fi
  magick -background none -size "1120x120" -gravity west \
    -font "$font_bold" -pointsize "$kw_pt" -fill "$WHITE" \
    caption:"$kw1" "$WORK_DIR/kw1.png"
  magick -background none -size "1120x120" -gravity west \
    -font "$font_bold" -pointsize "$kw_pt" -fill "$accent" \
    caption:"$kw2" "$WORK_DIR/kw2.png"
  magick -background none -size "1120x125" -gravity west \
    -font "$font_reg" -pointsize 41 -fill "$SUBTITLE_COLOR" \
    caption:"$title" "$WORK_DIR/title.png"

  magick "$WORK_DIR/canvas.png" \
    "$WORK_DIR/framed_shadow.png" -geometry "+${sh_x}+${sh_y}" -compose over -composite \
    "$WORK_DIR/pill.png" -geometry "+100+72" -compose over -composite \
    "$WORK_DIR/kw1.png" -geometry "+100+160" -compose over -composite \
    "$WORK_DIR/kw2.png" -geometry "+100+274" -compose over -composite \
    "$WORK_DIR/title.png" -geometry "+100+412" -compose over -composite \
    -alpha off -depth 8 $PNG_STRIP "$output"

  echo "  -> $output"
}

for phone_locale in "en-US|EN" "ja|JA" "zh-CN|ZH" "ko|KO"; do
  IFS='|' read -r lang_dir font_key <<< "$phone_locale"
  echo ""
  echo "=== Phone ${lang_dir} ==="
  mkdir -p "${SCRIPT_DIR}/${lang_dir}"
  bold_var="FONT_${font_key}_BOLD"
  reg_var="FONT_${font_key}_REG"
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key kicker g1 g2 accent kw1_en kw2_en tt_en kw1_ja kw2_ja tt_ja kw1_zh kw2_zh tt_zh kw1_ko kw2_ko tt_ko <<< "$entry"
    if [ "$lang_dir" != "en-US" ] && [ "${LOCALIZED_PHONE_CAPTURES:-false}" != "true" ]; then
      cp "${SCRIPT_DIR}/en-US/${key}.png" "${SCRIPT_DIR}/${lang_dir}/${key}.png"
    fi
    case "$lang_dir" in
      en-US) kw1="$kw1_en"; kw2="$kw2_en"; tt="$tt_en" ;;
      ja) kw1="$kw1_ja"; kw2="$kw2_ja"; tt="$tt_ja" ;;
      zh-CN) kw1="$kw1_zh"; kw2="$kw2_zh"; tt="$tt_zh" ;;
      ko) kw1="$kw1_ko"; kw2="$kw2_ko"; tt="$tt_ko" ;;
    esac
    compose_screenshot "$key" "$kicker" "$g1" "$g2" "$accent" "$kw1" "$kw2" "$tt" "$lang_dir" "${!bold_var}" "${!reg_var}"
  done
done

# === iPad Landscape (2752x2064) ===
IPAD_CANVAS_W=2752
IPAD_CANVAS_H=2064

compose_ipad_screenshot() {
  local key="$1" kicker="$2" glow1="$3" glow2="$4" accent="$5"
  local keyword="$6" title="$7" lang_dir="$8" font_bold="$9" font_reg="${10}" src_dir="${11}"
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

  local text_area_h=430
  local avail_h=$((IPAD_CANVAS_H - text_area_h - 86))
  if [ "$scaled_h" -gt "$avail_h" ]; then
    scale_ratio=$(echo "scale=6; $avail_h / $src_h" | bc)
    scaled_h=$avail_h
    scaled_w=$(echo "$src_w * $scale_ratio / 1" | bc)
  fi

  local ss_x=$(( (IPAD_CANVAS_W - scaled_w) / 2 ))
  local ss_y=$text_area_h

  echo "Composing iPad: ipad_$key ($lang_dir)"

  make_canvas "$IPAD_CANVAS_W" "$IPAD_CANVAS_H" "$glow1" "$glow2" "$WORK_DIR/ipad_canvas.png"

  local bezel_thickness=36
  local screen_w=$((scaled_w - bezel_thickness * 2))
  local screen_h=$((scaled_h - bezel_thickness * 2))
  local inner_radius=38
  local outer_radius=74

  magick "$input" -resize "${screen_w}x${screen_h}!" "$WORK_DIR/ipad_screen.png"
  magick -size "${screen_w}x${screen_h}" xc:black \
    -fill white -draw "roundrectangle 0,0 $((screen_w-1)),$((screen_h-1)) ${inner_radius},${inner_radius}" \
    "$WORK_DIR/ipad_inner_mask.png"
  magick "$WORK_DIR/ipad_screen.png" \( "$WORK_DIR/ipad_inner_mask.png" -alpha off \) \
    -compose CopyOpacity -composite "$WORK_DIR/ipad_screen_masked.png"

  magick -size "${scaled_w}x${scaled_h}" "gradient:#343938-#141616" -colorspace sRGB \
    \( -size "${scaled_w}x${scaled_h}" xc:black -fill white \
       -draw "roundrectangle 0,0 $((scaled_w-1)),$((scaled_h-1)) ${outer_radius},${outer_radius}" \) \
    -alpha off -compose CopyOpacity -composite \
    -fill none -stroke "rgba(255,255,255,0.20)" -strokewidth 4 \
    -draw "roundrectangle 2,2 $((scaled_w-3)),$((scaled_h-3)) ${outer_radius},${outer_radius}" \
    -fill "#0D0F0F" -stroke none \
    -draw "roundrectangle 8,8 $((scaled_w-9)),$((scaled_h-9)) $((outer_radius-6)),$((outer_radius-6))" \
    "$WORK_DIR/ipad_screen_masked.png" -geometry "+${bezel_thickness}+${bezel_thickness}" -compose over -composite \
    "$WORK_DIR/ipad_device.png"

  magick "$WORK_DIR/ipad_device.png" \
    \( +clone -background black -shadow 70x44+0+32 \) +swap \
    -background none -layers merge +repage \
    "$WORK_DIR/ipad_shadow.png"
  local sh_w sh_h
  read -r sh_w sh_h <<< "$(magick identify -format '%w %h' "$WORK_DIR/ipad_shadow.png")"
  local sh_x=$(( (IPAD_CANVAS_W - sh_w) / 2 ))
  local sh_y=$((ss_y - (sh_h - scaled_h) / 2 + 12))

  make_pill "$kicker" "$accent" 30 30 16 "$WORK_DIR/ipad_pill.png"

  magick "$WORK_DIR/ipad_canvas.png" \
    "$WORK_DIR/ipad_shadow.png" -geometry "+${sh_x}+${sh_y}" -compose over -composite \
    "$WORK_DIR/ipad_pill.png" -gravity North -geometry "+0+68" -compose over -composite \
    -gravity North \
    -font "$font_bold" -pointsize 102 -fill "$WHITE" \
    -annotate +0+164 "$keyword" \
    -font "$font_reg" -pointsize 56 -fill "$SUBTITLE_COLOR" \
    -annotate +0+314 "$title" \
    -alpha off -depth 8 $PNG_STRIP "$output"

  echo "  -> $output"
}

for ipad_locale in "en-US|EN" "ja|JA" "zh-CN|ZH" "ko|KO"; do
  IFS='|' read -r lang_dir font_key <<< "$ipad_locale"
  echo ""
  echo "=== iPad ${lang_dir} ==="
  bold_var="FONT_${font_key}_BOLD"
  reg_var="FONT_${font_key}_REG"
  for entry in "${IPAD_SCREENSHOTS[@]}"; do
    IFS='|' read -r key kicker g1 g2 accent kw_en tt_en kw_ja tt_ja kw_zh tt_zh kw_ko tt_ko <<< "$entry"
    case "$lang_dir" in
      en-US) kw="$kw_en"; tt="$tt_en" ;;
      ja) kw="$kw_ja"; tt="$tt_ja" ;;
      zh-CN) kw="$kw_zh"; tt="$tt_zh" ;;
      ko) kw="$kw_ko"; tt="$tt_ko" ;;
    esac
    compose_ipad_screenshot "$key" "$kicker" "$g1" "$g2" "$accent" "$kw" "$tt" "$lang_dir" "${!bold_var}" "${!reg_var}" "en-US"
  done
done

# === iPhone Duo cover display, portrait (1398x2034) ===
DUO_CANVAS_W=1398
DUO_CANVAS_H=2034

compose_duo_screenshot() {
  local key="$1" kicker="$2" glow1="$3" glow2="$4" accent="$5"
  local kw1="$6" kw2="$7" title="$8" lang_dir="$9" font_bold="${10}" font_reg="${11}"
  local input="${SCRIPT_DIR}/en-US/duo_${key}.png"
  local output="${SCRIPT_DIR}/${lang_dir}/duo_${key}_framed.png"

  local frame_svg="${SCRIPT_DIR}/assets/iphone-duo-closed-frame.svg"
  local screen_svg="${SCRIPT_DIR}/assets/iphone-duo-closed-screen.svg"
  local screen_offset=51
  local ss_y=490
  local device_h=$((DUO_CANVAS_H - ss_y - 54))

  echo "Composing iPhone Duo: duo_$key ($lang_dir)"

  make_canvas "$DUO_CANVAS_W" "$DUO_CANVAS_H" "$glow1" "$glow2" "$WORK_DIR/duo_canvas.png"

  magick -background black "msvg:${screen_svg}" -alpha off "$WORK_DIR/duo_mask.png"
  magick "$input" \( "$WORK_DIR/duo_mask.png" -alpha off \) -compose CopyOpacity -composite \
    "$WORK_DIR/duo_ss.png"
  magick -background none "msvg:${frame_svg}" PNG32:"$WORK_DIR/duo_body.png"
  magick "$WORK_DIR/duo_body.png" "$WORK_DIR/duo_ss.png" \
    -geometry "+${screen_offset}+${screen_offset}" -compose over -composite \
    -resize "x${device_h}" "$WORK_DIR/duo_framed.png"

  magick "$WORK_DIR/duo_framed.png" \
    \( +clone -background black -shadow 68x30+0+22 \) +swap \
    -background none -layers merge +repage \
    "$WORK_DIR/duo_shadow.png"
  local sh_w sh_h
  read -r sh_w sh_h <<< "$(magick identify -format '%w %h' "$WORK_DIR/duo_shadow.png")"
  local sh_x=$(( (DUO_CANVAS_W - sh_w) / 2 ))
  local sh_y=$((ss_y - (sh_h - device_h) / 2 + 8))

  make_pill "$kicker" "$accent" 22 22 12 "$WORK_DIR/duo_pill.png"

  local kw_pt=84
  if [ "$lang_dir" = "ja" ] || [ "$lang_dir" = "zh-CN" ] || [ "$lang_dir" = "ko" ]; then
    kw_pt=78
  fi
  magick -background none -size "1200x105" -gravity west \
    -font "$font_bold" -pointsize "$kw_pt" -fill "$WHITE" \
    caption:"$kw1" "$WORK_DIR/duo_kw1.png"
  magick -background none -size "1200x105" -gravity west \
    -font "$font_bold" -pointsize "$kw_pt" -fill "$accent" \
    caption:"$kw2" "$WORK_DIR/duo_kw2.png"
  magick -background none -size "1200x100" -gravity west \
    -font "$font_reg" -pointsize 38 -fill "$SUBTITLE_COLOR" \
    caption:"$title" "$WORK_DIR/duo_title.png"

  magick "$WORK_DIR/duo_canvas.png" \
    "$WORK_DIR/duo_shadow.png" -geometry "+${sh_x}+${sh_y}" -compose over -composite \
    "$WORK_DIR/duo_pill.png" -geometry "+100+48" -compose over -composite \
    "$WORK_DIR/duo_kw1.png" -geometry "+100+124" -compose over -composite \
    "$WORK_DIR/duo_kw2.png" -geometry "+100+224" -compose over -composite \
    "$WORK_DIR/duo_title.png" -geometry "+100+342" -compose over -composite \
    -alpha off -depth 8 $PNG_STRIP "$output"

  echo "  -> $output"
}

for duo_locale in "en-US|EN" "ja|JA" "zh-CN|ZH" "ko|KO"; do
  IFS='|' read -r lang_dir font_key <<< "$duo_locale"
  echo ""
  echo "=== iPhone Duo ${lang_dir} ==="
  bold_var="FONT_${font_key}_BOLD"
  reg_var="FONT_${font_key}_REG"
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key kicker g1 g2 accent kw1_en kw2_en tt_en kw1_ja kw2_ja tt_ja kw1_zh kw2_zh tt_zh kw1_ko kw2_ko tt_ko <<< "$entry"
    case "$lang_dir" in
      en-US) kw1="$kw1_en"; kw2="$kw2_en"; tt="$tt_en" ;;
      ja) kw1="$kw1_ja"; kw2="$kw2_ja"; tt="$tt_ja" ;;
      zh-CN) kw1="$kw1_zh"; kw2="$kw2_zh"; tt="$tt_zh" ;;
      ko) kw1="$kw1_ko"; kw2="$kw2_ko"; tt="$tt_ko" ;;
    esac
    compose_duo_screenshot "$key" "$kicker" "$g1" "$g2" "$accent" "$kw1" "$kw2" "$tt" "$lang_dir" "${!bold_var}" "${!reg_var}"
  done
done

# === README banner (4 flagship workflow screenshots side by side, 1800px width) ===
echo ""
echo "=== README banner ==="
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
README_IMG_DIR="${REPO_ROOT}/docs/images"
mkdir -p "$README_IMG_DIR"

README_KEYS=("01_conversation" "02_recent_sessions" "03_approval_list" "04_git_review")

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
echo ""
echo "=== Store upload directories ==="
STORE_DIR="${SCRIPT_DIR}/store"
ANDROID_META="${SCRIPT_DIR}/../../fastlane/metadata/android"

for lang_dir in en-US ja zh-CN ko; do
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

  duo_lang_dir="${SCRIPT_DIR}/store_duo/${ios_lang}"
  mkdir -p "$duo_lang_dir"
  rm -f "$duo_lang_dir"/*.png
  for entry in "${SCREENSHOTS[@]}"; do
    IFS='|' read -r key _ <<< "$entry"
    cp "${SCRIPT_DIR}/${lang_dir}/duo_${key}_framed.png" "$duo_lang_dir/duo_${key}.png"
  done
  echo "  Duo  -> $duo_lang_dir/ ($(ls "$duo_lang_dir" | wc -l | tr -d ' ') files)"

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
