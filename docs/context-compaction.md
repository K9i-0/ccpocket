# Context compaction display

## Goal

Show context compaction in both the normal and performance chat modes:

- while the provider compacts, a trailing "Compacting context…" row
- after it, only the latest compaction boundary and later messages; the
  boundary card shows trigger, token counts, the Claude summary, and opens a
  read-only transcript of the earlier messages
- the same transcript also covers messages dropped from the live history
  window (Bridge keeps 100 live messages, the app cache 200), which is the
  common reason a running session "cannot scroll back"

Compaction never deleted messages: Claude Code keeps them in the session
JSONL, Codex in the thread. Only the display and the live window were short.

## Provider sources

### Claude

Frame order of a `/compact` run (Agent SDK 0.3.316, verified live):

1. `system/status` `status: "compacting"` → process status `compacting`
2. `system/status` `status: null`, `compact_result` → back to running
3. `system/init`
4. `system/compact_boundary` with `compact_metadata`
   (`trigger`, `pre_tokens`, `post_tokens`, `duration_ms`)
5. `user` with `isSynthetic: true` and string content: the summary prompt

`SdkProcess` holds the boundary and attaches the summary from the next frame,
then emits one `context_compaction`. Any other next frame or the end of the
stream emits it without a summary. The boundary previously re-broadcast a
stale `status: "compacting"` after compaction had finished; that mapping was
removed.

The JSONL transcript stores the boundary as `type: "system"`,
`subtype: "compact_boundary"`, `compactMetadata` (camelCase), followed by a
`user` entry with `isCompactSummary: true`. `getSessionHistory` turns them
into a `role: "compaction"` history message. The boundary links to the
previous turn through `logicalParentUuid`, so rewind-branch detection is
unchanged.

`context-compaction.ts` normalizes both casings and strips the summary
preamble (`Summary:` heading) and `<system-reminder>` blocks.

### Codex

`item/started` with a `contextCompaction` item sets status `compacting`;
`item/completed` emits `context_compaction` (id = item id, no tokens or
summary — Codex summaries are encrypted) and restores `running`/`idle`.
Thread history (`thread/read`, item pagination) contains the same item, so
`codexThreadToSessionHistory` and the rollout fallback (`context_compacted`
event) produce `role: "compaction"`. The canonical-history merge keys the
marker by item id (`compaction:<id>`) so reconnects do not duplicate it.

## Protocol

All additions stay within protocol v1.

| Item | Direction | Compatibility |
| --- | --- | --- |
| `context_compaction` | Bridge → App | Opt-in via `supportedServerMessages`; filtered from live, `history`, `history_delta`, `history_snapshot` for other clients |
| `past_history` `role: "compaction"` | Bridge → App | Removed for clients that do not list `context_compaction` |
| `olderHistoryAvailable` on `history` / `history_snapshot` | Bridge → App | Optional field, ignored by older apps |
| `get_session_transcript` → `session_transcript` | App → Bridge | Older Bridges answer `unsupported_message` |
| `context_compaction_v1` | `protocolCapabilities` | Advertises the above |

Older apps parse unknown server messages as `ErrorMessage`, so sending
`context_compaction` unconditionally would show error bubbles; hence the
opt-in.

`get_session_transcript { sessionId, requestId, beforeIndex?,
untilLatestCompaction?, limit? }` reads the full provider transcript
(Claude JSONL; Codex thread via app-server) on each request and returns one
page counted back from its exclusive end: `startIndex`, `endIndex`, `total`,
and `messages` in past-history format including compaction markers. The first
page uses `untilLatestCompaction` so it ends at the latest boundary. Default
page 200, maximum 1000. Errors carry the `requestId`
(`session_transcript_failed`, `session_not_found`).

## App display

- `compactionVisibleEntries` (chat list only) keeps the latest boundary and
  later rows. Session state keeps every entry because rewind, edit and fork
  use them. A boundary arriving live folds the earlier rows immediately.
- Without a boundary, `olderHistoryAvailable` (Bridge flag or app cache trim)
  adds an "Earlier messages" card.
- The performance-mode projection runs after the fold, so both modes show the
  same boundary.
- `session_transcript` and transcript-request errors (`requestId` prefix
  `transcript-`) are kept out of the chat and the runtime cache.
- The transcript screen (`features/session_transcript`) opens at the newest
  loaded message (the boundary) and loads older pages on demand. With an
  older Bridge it shows the Bridge update notice inside the screen.

## Fallback removal

The `past_history` compaction-role filter and the `context_compaction`
opt-in exist for apps released before `context_compaction_v1`. Remove them
when protocol v2 makes `context_compaction` a required server message. The
app's handling of a missing `olderHistoryAvailable`/`unsupported_message`
for the transcript can be removed when the minimum supported Bridge
advertises `context_compaction_v1`.

## Verification

- Bridge unit tests: metadata casing, summary cleanup, page ranges, SDK frame
  pairing (with and without summary), JSONL and Codex thread conversion,
  Codex item lifecycle, opt-in filtering for live/history/past_history,
  transcript paging and errors, Codex marker dedup key.
- App tests: parsing, fold/older-history/compacting projection with
  performance mode, handler restoration, runtime-store flag, transcript
  cubit paging/errors/old Bridge, card widget.
- Runtime: test Bridge on 8766 with a real Claude `/compact`, normal and
  performance mode, transcript screen. The Codex path was checked with the
  `Codex Compacting` mock scenario and unit tests, not a live compaction.
