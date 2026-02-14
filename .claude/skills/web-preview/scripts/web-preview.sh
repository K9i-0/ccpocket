#!/usr/bin/env bash
# web-preview.sh - Flutter Webビルド → サーバー起動 → URL出力
#
# Usage: web-preview.sh [project_root]
# Output:
#   - LOCAL_URL: http://127.0.0.1:<port>
#   - URL: http://<tailscale-ip>:<port> (if available)
#   - PID: server process id

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PORT="${WEB_PREVIEW_PORT:-8888}"
WEB_BUILD_DIR="${PROJECT_ROOT}/apps/mobile/build/web"
PID_FILE="/tmp/ccpocket-web-preview-${PORT}.pid"
LOG_FILE="/tmp/ccpocket-web-preview-${PORT}.log"

# ── 1. Flutter Web ビルド ─────────────────────────
echo "=== Building Flutter Web (release) ==="
(cd "${PROJECT_ROOT}/apps/mobile" && flutter build web --release)

# ── 2. 既存サーバーの停止 ─────────────────────────
echo "=== Restarting HTTP server on port ${PORT} ==="
if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}" 2>/dev/null || true)"
  if [[ -n "${OLD_PID}" ]] && kill -0 "${OLD_PID}" 2>/dev/null; then
    kill "${OLD_PID}" 2>/dev/null || true
    sleep 0.5
    if kill -0 "${OLD_PID}" 2>/dev/null; then
      kill -9 "${OLD_PID}" 2>/dev/null || true
    fi
  fi
  rm -f "${PID_FILE}"
fi

# If another process still holds the port, stop it gracefully first.
EXISTING_PIDS="$(lsof -ti:"${PORT}" 2>/dev/null || true)"
if [[ -n "${EXISTING_PIDS}" ]]; then
  # shellcheck disable=SC2086
  kill ${EXISTING_PIDS} 2>/dev/null || true
  sleep 0.5
  STILL_PIDS="$(lsof -ti:"${PORT}" 2>/dev/null || true)"
  if [[ -n "${STILL_PIDS}" ]]; then
    # shellcheck disable=SC2086
    kill -9 ${STILL_PIDS} 2>/dev/null || true
  fi
fi

# ── 3. サーバー起動 (バックグラウンド) ────────────
nohup python3 -m http.server "${PORT}" --directory "${WEB_BUILD_DIR}" \
  >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!
echo "${SERVER_PID}" > "${PID_FILE}"

# Wait until server is actually reachable.
READY=false
for _ in {1..20}; do
  if curl -fsS --max-time 2 "http://127.0.0.1:${PORT}" >/dev/null 2>&1; then
    READY=true
    break
  fi
  sleep 0.3
done

# サーバーが起動したか確認
if [[ "${READY}" != "true" ]] || ! kill -0 "${SERVER_PID}" 2>/dev/null; then
  echo "ERROR: HTTP server failed to start on port ${PORT}" >&2
  echo "--- tail ${LOG_FILE} ---" >&2
  tail -n 40 "${LOG_FILE}" >&2 || true
  exit 1
fi

# ── 4. アクセスURL の決定 ─────────────────────────
# Playwright確認では local URL を優先。
# 共有用に Tailscale URL も出力する。
LOCAL_URL="http://127.0.0.1:${PORT}"
URL="${LOCAL_URL}"
if command -v tailscale &>/dev/null; then
  TS_IP="$(tailscale ip -4 2>/dev/null || true)"
  if [[ -n "${TS_IP}" ]]; then
    URL="http://${TS_IP}:${PORT}"
  fi
fi

echo "=== Server running ==="
echo "PID: ${SERVER_PID}"
echo "LOG: ${LOG_FILE}"
echo "LOCAL_URL: ${LOCAL_URL}"
echo "URL: ${URL}"
