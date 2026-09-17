# GLB preview size and short-lived cache

## Decision (2026-09-17)

The local Seedance_Madogiwa-voxel-game checkout contains 532 GLB paths
(including ignored copies and build outputs). 42 exceed the former 20 MiB
limit. The largest is 44.86 MiB (`fukuchan.glb` in
`04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917/`). Set both Bridge
and app limits to 50 MiB (52,428,800 bytes). This accommodates current
assets with some headroom; file size alone does not bound decoded texture
or GPU memory, so device rendering performance still depends on the model.

## Cache and freshness

- The app retains validated GLB source bytes in memory for five minutes
  from download completion, with a 100 MiB total LRU budget. Expiry timers
  release idle entries; lookups also check expiry after suspension.
- Cache keys are full capability URLs, including the Bridge origin.
  GPU scenes are recreated per viewer and are not cached.
- Each opening still requests `read_model_file`. Bridge performs existing
  allowlist/path validation and stats the file before reusing a model URL.
  Reuse requires matching canonical path, MIME type, device, inode, size,
  mtime and ctime. A changed file gets a new capability and cache miss.
  Serving an outdated model capability fails instead of serving changed bytes.
- Failed/incomplete downloads and invalid GLBs are not cached. Retry removes
  cached bytes before downloading again. Closing a viewer cancels its active
  HTTP client. Concurrent cold previews may each download; completed previews
  reuse source bytes.
- HTTP responses retain `private, no-store`; this is an explicit app memory
  cache, not a persistent browser/disk cache. Audio/video behavior is unchanged.

## Compatibility

No message fields or capability URL formats change. Existing apps work with
new Bridge versions. Older Bridge versions retain their 20 MiB limit and
issue a new URL each time, so both components must be updated for the larger
limit and repeat-preview cache hits. Bridge capability expiry/eviction can
cause an earlier cache miss, which is safe. An old Bridge size error is shown
using the app's current limit text; update Bridge to align the limits.

## Validation

Dart tests cover fixed expiry, URL isolation, LRU eviction, capacity and
replacement. Bridge tests cover URL reuse, same-size edits, expired
capabilities, download separation and the 50 MiB boundary.
