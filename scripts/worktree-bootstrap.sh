#!/usr/bin/env bash
# Prepare a git worktree by cloning heavy, gitignored caches from the main
# checkout, so a fresh worktree doesn't reinstall dependencies or re-download
# native assets (e.g. PDFium for pdfrx).
#
# Usage (run inside the worktree): bash scripts/worktree-bootstrap.sh
#
# On APFS, `cp -c` makes copy-on-write clones: near-instant and they use no
# extra disk until a file changes. Elsewhere it falls back to a plain copy for
# small directories and skips large ones (run the normal setup instead).
set -euo pipefail

worktree_root="$(git rev-parse --show-toplevel)"
common_dir="$(git rev-parse --path-format=absolute --git-common-dir)"
main_root="$(dirname "$common_dir")"

if [[ "$worktree_root" == "$main_root" ]]; then
  echo "worktree-bootstrap: already in the main checkout; nothing to do."
  exit 0
fi

# Caches that are safe to share as a starting point. Each is optional.
caches=(
  node_modules
  packages/bridge/node_modules
  apps/mobile/.dart_tool
  apps/mobile/android/.gradle
  apps/mobile/ios/Pods
)

clone_supported=false
probe_src="$(mktemp "$main_root/.wt-clone-probe.XXXXXX")"
probe_dst="$worktree_root/.wt-clone-probe.$$"
if cp -c "$probe_src" "$probe_dst" 2>/dev/null; then
  clone_supported=true
fi
rm -f "$probe_src" "$probe_dst"

for rel in "${caches[@]}"; do
  src="$main_root/$rel"
  dst="$worktree_root/$rel"
  [[ -d "$src" ]] || continue
  if [[ -e "$dst" ]]; then
    echo "worktree-bootstrap: keep existing $rel"
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  start=$(date +%s)
  if $clone_supported; then
    cp -c -R "$src" "$dst"
  else
    size_kb=$(du -sk "$src" | cut -f1)
    if (( size_kb > 512 * 1024 )); then
      echo "worktree-bootstrap: skip $rel (${size_kb}KB, no copy-on-write clone support)"
      continue
    fi
    cp -R "$src" "$dst"
  fi
  echo "worktree-bootstrap: cloned $rel in $(( $(date +%s) - start ))s"
done

# Point Flutter tooling at this worktree (rewrites absolute paths in
# .dart_tool/package_config.json and friends without re-downloading).
if [[ -d "$worktree_root/apps/mobile" ]] && command -v flutter >/dev/null 2>&1; then
  (cd "$worktree_root/apps/mobile" && flutter pub get --offline >/dev/null 2>&1 \
    || flutter pub get >/dev/null) && echo "worktree-bootstrap: flutter pub get done"
fi
