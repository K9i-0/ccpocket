#!/usr/bin/env bash
# promote.sh - Shorebirdパッチを staging → stable にプロモート
#
# Usage: promote.sh <release-version> <patch-number> [--force] [extra-args...]
# Example: promote.sh 1.0.0+1 2
#          promote.sh 1.0.0+1 2 --force   # 確認プロンプトをスキップ
#
# --force を指定すると確認プロンプトなしで即座にプロモートする。
# 非TTY環境（Claude Code等）では --force を推奨。

set -euo pipefail
export PATH="$HOME/.shorebird/bin:$PATH"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <release-version> <patch-number> [--force] [extra-args...]"
  echo "Example: $0 1.0.0+1 1"
  echo "         $0 1.0.0+1 1 --force"
  exit 1
fi

RELEASE_VERSION="$1"
PATCH_NUMBER="$2"
shift 2

# --force フラグの検出
FORCE=false
EXTRA_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then
    FORCE=true
  else
    EXTRA_ARGS+=("$arg")
  fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../../apps/mobile"

cd "$PROJECT_DIR"

echo "=== Shorebird Promote (staging → stable) ==="
echo "Release version: $RELEASE_VERSION"
echo "Patch number: $PATCH_NUMBER"
echo ""

if [[ "$FORCE" != "true" ]]; then
  read -p "Promote patch #$PATCH_NUMBER to stable? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
  fi
fi

shorebird patches set-track \
  --release "$RELEASE_VERSION" \
  --patch "$PATCH_NUMBER" \
  --track=stable \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

echo ""
echo "=== Done ==="
echo "Patch #$PATCH_NUMBER has been promoted to stable."
