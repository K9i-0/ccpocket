#!/usr/bin/env bash
set -euo pipefail
# Deterministic media fixtures, never included in the shipped app or LP.
repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
fixture_dir="${1:-/private/tmp/ccpocket-lp-media}"
mkdir -p "$fixture_dir"
ffmpeg -hide_banner -loglevel error -y -loop 1 \
  -i "$repo_dir/apps/mobile/assets/icon.png" \
  -vf "scale=280:280,pad=640:360:(ow-iw)/2:(oh-ih)/2:color=0x111716,zoompan=z='min(zoom+0.0005,1.12)':d=300:s=640x360:fps=25,format=yuv420p" \
  -t 12 -c:v libx264 -movflags +faststart "$fixture_dir/pocket-preview.mp4"
ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=523.25:duration=12:sample_rate=44100' \
  -af 'volume=0.03,afade=t=in:d=0.1,afade=t=out:st=11:d=1' \
  "$fixture_dir/pocket-chime.wav"
printf 'Fixtures ready: %s\n' "$fixture_dir"
