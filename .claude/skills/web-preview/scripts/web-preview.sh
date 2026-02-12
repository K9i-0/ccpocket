#!/usr/bin/env bash
# web-preview.sh - Flutter Webビルド → サーバー起動 → URL出力
#
# Usage: web-preview.sh [project_root]
# Output: 最終行に "URL: http://<ip>:<port>" を出力する

set -euo pipefail

PROJECT_ROOT="${1:-.}"
PORT=8888
WEB_BUILD_DIR="${PROJECT_ROOT}/apps/mobile/build/web"

# ── 1. Flutter Web ビルド ─────────────────────────
echo "=== Building Flutter Web (release) ==="
(cd "${PROJECT_ROOT}/apps/mobile" && flutter build web --release)

# ── 2. 既存サーバーの停止 ─────────────────────────
echo "=== Restarting HTTP server on port ${PORT} ==="
lsof -ti:"${PORT}" | xargs kill -9 2>/dev/null || true
sleep 0.5

# ── 3. サーバー起動 (バックグラウンド) ────────────
(cd "${WEB_BUILD_DIR}" && python3 -m http.server "${PORT}" &>/dev/null &)
sleep 1

# サーバーが起動したか確認
if ! lsof -ti:"${PORT}" &>/dev/null; then
  echo "ERROR: HTTP server failed to start on port ${PORT}" >&2
  exit 1
fi

# ── 4. アクセスURL の決定 ─────────────────────────
# Tailscale IP を優先、なければ localhost
if command -v tailscale &>/dev/null; then
  IP=$(tailscale ip -4 2>/dev/null || echo "localhost")
else
  IP="localhost"
fi

echo "=== Server running ==="
echo "URL: http://${IP}:${PORT}"
