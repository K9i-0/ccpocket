#!/usr/bin/env bash
# Restart Bridge Server + Flutter app (marionette) for development
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE_PORT="${BRIDGE_PORT:-8765}"
DEVICE="${1:-}"
TARGET="lib/marionette_main.dart"

# --- Bridge Server ---
echo "==> Stopping Bridge Server (port $BRIDGE_PORT)..."
BRIDGE_PID=$(lsof -ti :"$BRIDGE_PORT" 2>/dev/null || true)
if [ -n "$BRIDGE_PID" ]; then
  kill "$BRIDGE_PID" 2>/dev/null || true
  sleep 1
  echo "    Killed PID $BRIDGE_PID"
else
  echo "    Not running"
fi

echo "==> Starting Bridge Server..."
cd "$ROOT_DIR"
npm run bridge &
BRIDGE_BG_PID=$!
sleep 2

# Verify
if lsof -ti :"$BRIDGE_PORT" >/dev/null 2>&1; then
  echo "    Bridge Server running on port $BRIDGE_PORT"
else
  echo "    ERROR: Bridge Server failed to start"
  exit 1
fi

# --- Flutter App ---
echo "==> Launching Flutter app ($TARGET)..."
cd "$ROOT_DIR/apps/mobile"

FLUTTER_ARGS=(-t "$TARGET")
if [ -n "$DEVICE" ]; then
  FLUTTER_ARGS+=(-d "$DEVICE")
fi

flutter run "${FLUTTER_ARGS[@]}"

# Cleanup: stop bridge when flutter exits
echo "==> Stopping Bridge Server..."
kill "$BRIDGE_BG_PID" 2>/dev/null || true
