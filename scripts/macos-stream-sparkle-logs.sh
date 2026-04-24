#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-stream}"
LAST="${2:-20m}"
PREDICATE='(process CONTAINS[c] "Sparkle") || (process CONTAINS[c] "Autoupdate") || (subsystem CONTAINS[c] "sparkle") || (eventMessage CONTAINS[c] "Sparkle") || (eventMessage CONTAINS[c] "[CCPocket][Sparkle]")'

case "$MODE" in
  stream)
    log stream --style compact --info --debug --predicate "$PREDICATE"
    ;;
  show)
    log show --last "$LAST" --style compact --info --debug --predicate "$PREDICATE"
    ;;
  *)
    echo "usage: $0 [stream|show] [last-duration]" >&2
    echo "examples:" >&2
    echo "  $0 stream" >&2
    echo "  $0 show 20m" >&2
    exit 1
    ;;
esac
