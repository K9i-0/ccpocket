#!/usr/bin/env bash
# Detect when a newer Flutter stable is released AND Shorebird supports it,
# then open a GitHub issue (once per version). Dependabot cannot track the
# Flutter SDK itself, so this runs from .github/workflows/flutter-stable-check.yml.
#
# Env:
#   DRY_RUN=1   print the would-be issue instead of creating it
#   GH_TOKEN    required by `gh` when not in DRY_RUN
set -euo pipefail

cd "$(dirname "$0")/.."

# Same parsing as the release workflows, so the two never disagree.
pinned=$(grep 'flutter' .mise.toml | sed 's/.*= *"//' | sed 's/"//')
pinned_shorebird=$(grep 'shorebird' .mise.toml | sed 's/.*= *"//' | sed 's/"//')

stable=$(curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json |
  jq -r '.current_release.stable as $h | [.releases[] | select(.hash == $h)][0].version')

if [[ -z "$stable" || "$stable" == "null" ]]; then
  echo "::error::Failed to resolve Flutter stable version" >&2
  exit 1
fi

echo "pinned=$pinned stable=$stable"

newest=$(printf '%s\n%s\n' "$pinned" "$stable" | sort -V | tail -1)
if [[ "$stable" == "$pinned" || "$newest" != "$stable" ]]; then
  echo "Up to date (Flutter $pinned)."
  exit 0
fi

# shorebird CLI resolves --flutter-version via these branches on its fork.
if ! git ls-remote --exit-code https://github.com/shorebirdtech/flutter.git \
  "refs/heads/flutter_release/$stable" >/dev/null; then
  echo "Flutter $stable is out, but Shorebird does not support it yet."
  exit 0
fi

latest_cli=$(git ls-remote --tags --refs https://github.com/shorebirdtech/shorebird.git |
  awk -F/ '{print $NF}' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -1)

title="chore(mobile): Flutter $stable stable が Shorebird 対応済み"
body=$(cat <<EOF
Flutter の新しい stable が公開され、Shorebird でも利用可能になりました。

| | 現在 (\`.mise.toml\`) | 最新 |
|---|---|---|
| Flutter | $pinned | **$stable** |
| Shorebird CLI | $pinned_shorebird | $latest_cli |

- Shorebird fork: https://github.com/shorebirdtech/flutter/tree/flutter_release/$stable
- Shorebird CLI releases: https://github.com/shorebirdtech/shorebird/releases
- Flutter hotfix issue: https://github.com/flutter/flutter/issues?q=%5Bhotfix%5D+$stable

アップグレードは \`flutter-upgrade\` スキル（\`.claude/skills/flutter-upgrade/SKILL.md\`）で進める。
既存リリースへのパッチは旧バージョンのままにする必要がある点に注意。

_このIssueは \`.github/workflows/flutter-stable-check.yml\` が自動作成しました。_
EOF
)

if [[ "${DRY_RUN:-}" == "1" ]]; then
  echo "[dry-run] would create issue: $title"
  echo "$body"
  exit 0
fi

existing=$(gh issue list --state all --label dependencies --limit 100 --json title \
  --jq "map(select(.title == \"$title\")) | length")
if [[ "$existing" != "0" ]]; then
  echo "Issue already exists: $title"
  exit 0
fi

gh issue create --title "$title" --body "$body" --label dependencies
