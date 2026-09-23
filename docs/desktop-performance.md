# Desktop / local Bridge performance

## Decision

Adopt two measured, behavior-preserving Bridge optimizations:

- Media HTTP streams: increase the file read buffer from 64 KiB to 256 KiB.
- Text preview: count newlines and slice the visible prefix instead of allocating
  an array containing every line, including lines that will never be displayed.

Keep file access and Git execution in the Bridge. No protocol, client, capability
URL, path authorization, Range, cache, or Git behavior changes are required.
Old clients continue to work. The existing macOS sandbox/file-access model stays
unchanged. These improvements also apply to non-desktop clients using this Bridge.

## Reproduce

From the repository root, with dependencies installed and FFmpeg on PATH:

```sh
node --import tsx scripts/benchmark-desktop.mts /tmp/desktop-performance.json
```

The script creates temporary fixtures and listens on OS-assigned loopback ports;
it does not connect to or restart the production Bridge. It deletes its fixtures
and closes its servers on completion. FFmpeg absence/failure is reported as
`videoError`, not treated as a successful video measurement.

Each comparison has one warmup per variant, 11 samples per variant, and rotating
execution order. Values below are medians from the saved
[raw results](benchmarks/desktop-performance.json). Samples and environment details
are included there. The reported p95 is effectively the maximum of 11 samples,
not a statistically stable tail-latency estimate.

These are warm-cache, localhost **component measurements**, not application
interaction timings. Cold disk, remote networks, playback buffering, Flutter
rendering, syntax highlighting, and image decoding are not measured.

## Results and adoption

| Candidate / fixture | Before | Candidate | Decision |
|---|---:|---:|---|
| 128 MiB media HTTP transfer, 64 → 256 KiB buffer | 78.44 ms | 49.33 ms | Adopt; 37% shorter transfer |
| 1 MiB range, 64 → 256 KiB buffer | 0.88 ms | 0.54 ms | Same change; small absolute gain |
| 64 KiB range, 64 → 256 KiB buffer | 0.28 ms | 0.27 ms | No meaningful absolute gain |
| 128 MiB media HTTP transfer, 64 KiB → 1 MiB buffer | 78.44 ms | 36.68 ms | Do not adopt 1 MiB; choose smaller per-stream buffer |
| Large text line processing, split → scan | 32.59 ms | 5.13 ms | Adopt; 84% shorter processing |
| Small text line processing, split → scan | 0.069 ms | 0.043 ms | Same change; negligible absolute cost |
| MP4 first decoded frame, current 64 KiB HTTP → direct file | 55.67 ms | 53.61 ms | Do not add direct file access for this gain |
| MP4 seek to 10s and decode, current HTTP → direct file | 66.43 ms | 62.04 ms | Same decision |
| MP4 first frame, 64 → 256 KiB HTTP buffer | 55.67 ms | 56.47 ms | Do not claim a playback startup improvement |
| Faststart MP4 first frame, 64 → 256 KiB HTTP buffer | 55.04 ms | 54.92 ms | No startup improvement |
| 4 MiB image-like payload, Base64 WS → binary HTTP | 16.63 ms | 2.08 ms | Promising transport candidate; defer client/protocol migration |
| Git, 3 files with one changed line each, WS → direct | 17.90 ms | 17.62 ms | Only 0.28 ms difference; keep Bridge execution |
| Git, 200 files with all 700 lines changed, WS → direct | 112.34 ms | 87.30 ms | Transport saving exists for unusually large diffs; defer direct execution |
| Same large Git fixture, all-file direct diff → one-file diff | 87.30 ms | 10.95 ms | Promising, but not equivalent work; defer UI/protocol redesign |
| Same large Git fixture, all-file diff → names/status only | 87.30 ms | 43.58 ms | Potential initial list optimization; not a replacement for full diff |

The first two exploratory runs also found 128 MiB transfers improving from
82–83 ms to 46–48 ms and large-text processing from about 32 ms to 5 ms.
The final run uses the actual adopted text helper and MediaStore implementation.
The benchmark reconstructs the original stream buffer size in a temporary module;
all registration, path validation and HTTP behavior are shared with production.

256 KiB is a conservative resource tradeoff, not the measured throughput maximum.
It adds up to 192 KiB of read buffering per active stream relative to 64 KiB;
1 MiB would add up to 960 KiB. This is only the read buffer, not total stream
memory. Concurrent slow-client memory behavior has not been benchmarked. Existing
backpressure, disconnect cleanup, file-handle ownership and error behavior remain.

## Interpretation and limits

- Media already uses HTTP byte ranges. The 128 MiB full-transfer result must not
  be interpreted as a video startup result: a player need not read the entire file
  before showing a frame.
- Video uses a generated 15-second 1280×720 H.264 MP4, both tail metadata and
  faststart layouts. FFmpeg decodes one frame to a null output; the measured time
  includes process startup/teardown. This is a decoder proxy, not media_kit or
  time-to-first-visible-frame. Seek measurement starts a new decoder at 10 seconds,
  not an interactive seek in an already-running player.
- Text fixtures contain Japanese text and newlines. Their names describe target
  sizes (64 KiB / 16 MiB); they are generated by repeating a source line, not exact
  byte-size allocations. Measurements exclude readFile, JSON, transport and UI.
  Exact total line count, trailing empty lines, CRLF and truncation semantics are
  preserved. The entire file is still read; this change is not a file-size limit.
- The image fixture is binary data, not a decoded image. WS includes JSON/Base64
  encoding and decoding plus full buffering; HTTP is consumed as a stream. A real
  HTTP image client may also buffer the entire response. It needs an end-to-end
  comparison before adoption, plus old-Bridge fallback and export-path checks.
- Git WS is a minimal JSON WebSocket proxy around the same Git command, not the
  full Bridge handler. One-file and name/status queries return less information;
  the time savings do not establish an equivalent replacement for the existing
  screen. The final large fixture produces less than the production 10 MiB command
  output limit (the early exploratory fixture exceeded that limit and was reduced).
  The fixtures contain tracked changes and do not model the Bridge's
  untracked-file handling, index interactions, Dart diff parsing or rendering.

## Candidates requiring further evidence

- **Actual video preview latency:** measure click → metadata response → player open
  → first visible frame, plus an in-player seek, in a macOS profile/release build.
  The component results do not establish the cause of any perceived UI delay.
- **File-scoped Git loading:** prototype initial file list + selected-file diff,
  including staged/unstaged, untracked files, hunk actions and old-Bridge fallback;
  compare initial display and repeated navigation before adopting.
- **Image binary transport:** compare full client decode/display and repeated opens.
- **Preview/diff caching and background refresh:** measure real repeated navigation
  and invalidation behavior before selecting a cache lifetime. No stale-result
  behavior was introduced based on synthetic cache-hit timings.
- **Fetch frequency:** real authenticated remote-fetch latency and the UI's waiting
  behavior were not measured. Local loopback tests cannot establish the benefit of
  changing remote freshness. No fetch policy changes were made.
- **Open in editor/Finder:** a desktop workflow feature rather than a measured
  internal preview optimization; not included in this performance change.

## Verification

- `npx vitest run src/media-store.test.ts src/text-preview.test.ts src/websocket.test.ts`
  (from `packages/bridge`): passed.
- `npx tsc --noEmit -p packages/bridge/tsconfig.json`: passed.
- Independent review: no material findings; measurement limits documented above.
- No Flutter source changes or claimed Flutter UI/E2E verification.
