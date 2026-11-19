#!/usr/bin/env bash
# Per-checkout E2E environment: a test Bridge on a free port and a dedicated
# (optionally slimmed) iOS simulator, so several worktrees can run E2E at once
# without touching the production Bridge (8765) or each other.
#
# Usage (from any directory inside the checkout or worktree):
#   bash scripts/e2e-env.sh bridge              # pick a free port, run Bridge in the foreground
#   bash scripts/e2e-env.sh sim [name]          # create/reuse + slim + boot a simulator, print its UDID
#   bash scripts/e2e-env.sh connect <udid> <port>   # connect the app on <udid> to the Bridge on <port>
#   bash scripts/e2e-env.sh sim-delete [name|udid]  # shut down and delete the simulator
#
# Environment:
#   E2E_BRIDGE_PORT       use this port instead of picking one
#   E2E_SIM_DEVICE_TYPE   simulator device type for new simulators (default: "iPhone 17")
#   BRIDGE_API_KEY        token for `connect` (default: ~/.ccpocket/bridge-api-key)
#   CCPOCKET_ANTIGRAVITY_API_KEY  Gemini API key for Antigravity sessions
#                         (default: GEMINI_API_KEY in .env.antigravity.local)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"

# 8765 is production; 8767/8768 are the Codex app-server default/fallback.
candidate_ports() {
  echo 8766
  seq 8769 8799
}

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

default_sim_name() {
  echo "ccpocket-e2e-$(basename "$root")"
}

# Prints the UDID of an available simulator named exactly $1, if any.
find_sim() {
  xcrun simctl list devices available -j |
    python3 -I -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name:
            print(d["udid"])
            raise SystemExit
' "$1"
}

sim_state() {
  xcrun simctl list devices -j |
    python3 -I -c '
import json, sys
udid = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["udid"] == udid:
            print(d["state"])
' "$1"
}

cmd_bridge() {
  local port="${E2E_BRIDGE_PORT:-}"
  if [[ -z "$port" ]]; then
    for p in $(candidate_ports); do
      if ! port_in_use "$p"; then
        port="$p"
        break
      fi
    done
  fi
  if [[ -z "$port" ]]; then
    echo "e2e-env: no free test port in 8766, 8769-8799" >&2
    exit 1
  fi
  if [[ "$port" == 8765 ]]; then
    echo "e2e-env: refusing to use the production port 8765" >&2
    exit 1
  fi
  echo "e2e-env: test Bridge port $port (checkout: $root)"
  echo "e2e-env: connect with: bash scripts/e2e-env.sh connect <udid> $port"
  # If another agent grabbed the port meanwhile, the Bridge exits with
  # EADDRINUSE; run this command again to pick the next port.
  cd "$root"
  # Agents drive this Bridge, so Antigravity must never run on a Google login
  # here (docs/antigravity-acp-integration.md). The Bridge refuses to send a
  # prompt unless the API key below is verified.
  export CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY=1
  local key_file="$root/.env.antigravity.local"
  if [[ -z "${CCPOCKET_ANTIGRAVITY_API_KEY:-}" && -f "$key_file" ]]; then
    CCPOCKET_ANTIGRAVITY_API_KEY="$(sed -n 's/^GEMINI_API_KEY=//p' "$key_file" | head -1)"
    export CCPOCKET_ANTIGRAVITY_API_KEY
  fi
  BRIDGE_PORT="$port" exec npm run bridge
}

cmd_sim() {
  local name="${1:-$(default_sim_name)}"
  local device_type="${E2E_SIM_DEVICE_TYPE:-iPhone 17}"
  local udid
  udid="$(find_sim "$name")"
  if [[ -z "$udid" ]]; then
    # A fresh simulator, not a clone: clones carry the source's app data,
    # including a saved Bridge URL.
    udid="$(xcrun simctl create "$name" "$device_type")"
    echo "e2e-env: created simulator $name ($udid)" >&2
  else
    echo "e2e-env: reusing simulator $name ($udid)" >&2
  fi

  if command -v simslim >/dev/null 2>&1; then
    # Applies the slim profile and leaves the simulator booted. Quick when it
    # is already slim.
    simslim on "$udid" >&2
  else
    echo "e2e-env: simslim not installed; using a stock simulator" \
      "(brew install mobai-app/tap/simslim)" >&2
    if [[ "$(sim_state "$udid")" != "Booted" ]]; then
      xcrun simctl boot "$udid"
    fi
    xcrun simctl bootstatus "$udid" >/dev/null
  fi
  echo "$udid"
}

cmd_connect() {
  local udid="${1:?usage: e2e-env.sh connect <udid> <port>}"
  local port="${2:?usage: e2e-env.sh connect <udid> <port>}"
  local api_key="${BRIDGE_API_KEY:-}"
  local key_file="$HOME/.ccpocket/bridge-api-key"
  if [[ -z "$api_key" && -f "$key_file" ]]; then
    api_key="$(tr -d '[:space:]' <"$key_file")"
  fi
  if [[ -z "$api_key" ]]; then
    echo "e2e-env: no API key; start the Bridge first or set BRIDGE_API_KEY" >&2
    exit 1
  fi
  local link
  link="$(python3 -I -c '
import sys, urllib.parse
print("ccpocket://connect?" + urllib.parse.urlencode({"url": "ws://localhost:" + sys.argv[1], "token": sys.argv[2]}))
' "$port" "$api_key")"
  xcrun simctl openurl "$udid" "$link"
  echo "e2e-env: sent connect link for ws://localhost:$port to $udid"
}

cmd_sim_delete() {
  local target="${1:-$(default_sim_name)}"
  local udid="$target"
  if [[ -z "$(sim_state "$target")" ]]; then
    udid="$(find_sim "$target")"
  fi
  if [[ -z "$udid" ]]; then
    echo "e2e-env: no simulator named or with UDID $target" >&2
    exit 1
  fi
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl delete "$udid"
  echo "e2e-env: deleted simulator $udid"
}

case "${1:-}" in
  bridge) shift; cmd_bridge "$@" ;;
  sim) shift; cmd_sim "$@" ;;
  connect) shift; cmd_connect "$@" ;;
  sim-delete) shift; cmd_sim_delete "$@" ;;
  *)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
