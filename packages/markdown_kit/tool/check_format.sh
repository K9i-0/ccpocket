#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
git ls-files --cached --others --exclude-standard -z -- '*.dart' |
  xargs -0 dart format --output=none --set-exit-if-changed
