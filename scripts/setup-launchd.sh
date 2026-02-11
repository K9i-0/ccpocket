#!/usr/bin/env bash
# Register Bridge Server as a launchd service for persistent startup.
#
# Usage:
#   npm run setup                          # Default setup (port 8765)
#   npm run setup -- --port 9000           # Custom port
#   npm run setup -- --api-key SECRET      # With API key
#   npm run setup -- --uninstall           # Remove service
#
# Environment variables (overridden by CLI args):
#   BRIDGE_PORT     (default: 8765)
#   BRIDGE_HOST     (default: 0.0.0.0)
#   BRIDGE_API_KEY  (default: none)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_LABEL="com.ccpocket.bridge"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# Defaults (env vars as fallback)
PORT="${BRIDGE_PORT:-8765}"
HOST="${BRIDGE_HOST:-0.0.0.0}"
API_KEY="${BRIDGE_API_KEY:-}"
NO_START=false
UNINSTALL=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Register Bridge Server as a macOS launchd service.

Options:
  --port <port>       Bridge port (default: 8765)
  --host <host>       Bind address (default: 0.0.0.0)
  --api-key <key>     API key for authentication
  --no-start          Register only, don't start immediately
  --uninstall         Remove the launchd service
  -h, --help          Show this help
EOF
}

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) [[ $# -lt 2 ]] && { echo "Error: --port requires a value"; exit 1; }; PORT="$2"; shift 2 ;;
    --host) [[ $# -lt 2 ]] && { echo "Error: --host requires a value"; exit 1; }; HOST="$2"; shift 2 ;;
    --api-key) [[ $# -lt 2 ]] && { echo "Error: --api-key requires a value"; exit 1; }; API_KEY="$2"; shift 2 ;;
    --no-start) NO_START=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# --- Uninstall ---
if [ "$UNINSTALL" = true ]; then
  echo "==> Uninstalling Bridge Server service..."
  launchctl stop "$PLIST_LABEL" 2>/dev/null || true
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "    Service removed."
  exit 0
fi

# --- Detect Node.js ---
NODE_PATH=$(command -v node || true)
if [ -z "$NODE_PATH" ]; then
  for p in /usr/local/bin/node /opt/homebrew/bin/node; do
    if [ -x "$p" ]; then NODE_PATH="$p"; break; fi
  done
fi
if [ -z "$NODE_PATH" ]; then
  echo "ERROR: node not found. Install Node.js first."
  exit 1
fi
NODE_DIR=$(dirname "$NODE_PATH")
echo "==> Node.js: $NODE_PATH"

# --- Build if needed ---
if [ ! -d "$ROOT_DIR/packages/bridge/dist" ]; then
  echo "==> Building Bridge Server..."
  cd "$ROOT_DIR" && npm run bridge:build
fi

# --- Create LaunchAgents directory ---
mkdir -p "$HOME/Library/LaunchAgents"

# --- Build environment block ---
ENV_BLOCK="        <key>PATH</key>
        <string>$NODE_DIR:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>BRIDGE_PORT</key>
        <string>$PORT</string>
        <key>BRIDGE_HOST</key>
        <string>$HOST</string>"

if [ -n "$API_KEY" ]; then
  ENV_BLOCK="$ENV_BLOCK
        <key>BRIDGE_API_KEY</key>
        <string>$API_KEY</string>"
fi

# --- Generate plist ---
echo "==> Writing $PLIST_PATH"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_PATH</string>
        <string>$ROOT_DIR/packages/bridge/dist/index.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$ROOT_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
$ENV_BLOCK
    </dict>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/ccpocket-bridge.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ccpocket-bridge.err</string>
</dict>
</plist>
EOF

# --- Register with launchctl ---
echo "==> Registering service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

# --- Start ---
if [ "$NO_START" = false ]; then
  sleep 1
  launchctl start "$PLIST_LABEL" || true
  echo "==> Bridge Server started on port $PORT"
else
  echo "==> Service registered (not started). Run: launchctl start $PLIST_LABEL"
fi

echo "    Done."
