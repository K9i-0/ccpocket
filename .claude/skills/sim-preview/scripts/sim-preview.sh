#!/bin/bash
set -euo pipefail

# Device Hubのみを前景起動する。アプリ起動・HTTPS設定はSKILL.mdを参照。
# 空きポートを選ぶ場合: SIM_PREVIEW_PORT=3401 bash sim-preview.sh
# オプション確認: bash sim-preview.sh --help

if [[ "${1:-}" == "--help" && $# -eq 1 ]]; then
  exec npm exec --yes --package=expo-device-hub@0.10.1 -- expo-device-hub --help
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: SIM_PREVIEW_PORT=3400 bash sim-preview.sh [--help]" >&2
  exit 2
fi

PREVIEW_PORT="${SIM_PREVIEW_PORT:-3400}"
if [[ ! "$PREVIEW_PORT" =~ ^[0-9]{1,5}$ ]] || (( 10#$PREVIEW_PORT < 1 || 10#$PREVIEW_PORT > 65535 )); then
  echo "SIM_PREVIEW_PORT must be between 1 and 65535" >&2
  exit 2
fi
PREVIEW_PORT=$((10#$PREVIEW_PORT))

for tool in npm lsof; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required command not found: $tool" >&2
    exit 1
  fi
done
if lsof -nP -iTCP:"$PREVIEW_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PREVIEW_PORT is in use. Reuse the existing Hub or choose SIM_PREVIEW_PORT." >&2
  exit 1
fi

exec npm exec --yes --package=expo-device-hub@0.10.1 -- expo-device-hub \
  --host 127.0.0.1 \
  --port "$PREVIEW_PORT" \
  --platform ios \
  --transport h264 \
  --max-dimension 1000 \
  --video-bitrate 2500000 \
  --video-fps 30
