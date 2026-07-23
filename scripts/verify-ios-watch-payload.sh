#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 <included|excluded> <path-to-ipa-or-app>" >&2
  exit 64
}

if [[ $# -ne 2 ]]; then
  usage
fi

expected="$1"
artifact_path="$2"

if [[ "$expected" != "included" && "$expected" != "excluded" ]]; then
  usage
fi

if [[ ! -e "$artifact_path" ]]; then
  echo "Artifact does not exist: $artifact_path" >&2
  exit 66
fi

temporary_directory=""
cleanup() {
  if [[ -n "$temporary_directory" && -d "$temporary_directory" ]]; then
    rm -rf "$temporary_directory"
  fi
}
trap cleanup EXIT

if [[ "$artifact_path" == *.ipa ]]; then
  temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/ccpocket-watch-payload.XXXXXX")"
  unzip -q "$artifact_path" -d "$temporary_directory"
  runner_app="$temporary_directory/Payload/Runner.app"
else
  runner_app="$artifact_path"
fi

if [[ ! -d "$runner_app" ]]; then
  echo "Runner.app was not found in: $artifact_path" >&2
  exit 65
fi

watch_app="$runner_app/Watch/ccpocket Watch App.app"
watch_widget="$watch_app/PlugIns/ccpocket Watch Widget.appex"

if [[ "$expected" == "included" ]]; then
  if [[ ! -d "$watch_app" ]]; then
    echo "Expected Apple Watch app is missing: $watch_app" >&2
    exit 1
  fi
  if [[ ! -d "$watch_widget" ]]; then
    echo "Expected Apple Watch widget is missing: $watch_widget" >&2
    exit 1
  fi
  echo "Verified Apple Watch app and widget are included."
  exit 0
fi

if [[ -e "$runner_app/Watch" ]]; then
  echo "Public iPhone build unexpectedly contains Apple Watch content." >&2
  exit 1
fi

echo "Verified public iPhone build contains no Apple Watch content."
