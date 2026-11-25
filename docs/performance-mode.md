# Display mode & performance filtering / 表示モードと配信フィルタ

Display mode reduces Bridge → mobile delivery as well as transcript rendering
with per-category controls and presets (`All`, `Recommended`, `Custom`).

Default and per-session overrides are device preferences:
- `settings_chat_display_filter`: JSON object storing the 6 category booleans.
- `settings_lite_mode`: kept in sync with `isFiltered` for backward compatibility
  and migration (an existing `true` value migrates to the `Recommended` preset).
- `settings_session_lite_mode:<sessionId>`: per-session override (`false` = `All`,
  `true` = `Recommended`, absent = inherit default).

## Categories and presets

Essential items are always preserved regardless of filter settings:
- User input and attachments
- Assistant prose and markdown-embedded assistant images (`AssistantServerMessage.images`)
- Plans (`ExitPlanMode`, and plan-file `Write` under `/.claude/plans/` on the Bridge
  because the approval UI derives plan text from them)
- Questions and approvals (`AskUserQuestion`, approval requests, `permissionOutcome`
  completion markers and answered question text)
- Image generation (`ImageGeneration` tool calls and results, without `rawContentBlocks`)
- Errors, status, completion chips, compaction, recaps, Explorer/file and explicitly
  requested image endpoints

Configurable categories (`PerformanceFilter` / `ChatDisplayFilter`):

| Key | Scope | All | Recommended |
| --- | --- | :-: | :-: |
| `tasks` | `TodoWrite` (including Antigravity `update_steps`), Codex `UpdatePlan`, Claude `TaskCreate` / `TaskUpdate` | ON | ON |
| `thinking` | `thinking` blocks and live `thinking_delta` streams | ON | ON |
| `subagents` | `SwarmPost`, `swarm` (`action: "add"`), `tool_use_summary`, `Agent` / `Task` / `SubAgent` / `invoke_subagent` | ON | ON |
| `codeEdits` | `Edit`, `Write`, `MultiEdit`, `NotebookEdit`, `FileChange`, `FileEdit`, `apply_patch` | ON | OFF |
| `otherTools` | All remaining tool calls (`Bash`, `Read`, `Grep`, `Glob`, `WebSearch`, `WebFetch`, MCP, etc.) | ON | OFF |
| `toolResults` | Non-essential `tool_result` bodies and incidental images (e.g. simulator screenshots) | ON | OFF |

## Delivery policy

Filtering runs per WebSocket **before JSON serialization** for live messages, legacy history,
past history, and sequenced snapshots/deltas.

- When all 6 categories are `true` (`All`), filtering is bypassed completely and
  `history_delta`/`history_snapshot` frames are not marked `filtered: true`.
- When `toolResults` is `false`, non-essential `tool_result` frames are reduced to a
  payload-free marker carrying `toolUseId`, routing metadata, `permissionOutcome`
  (plus `content` when `permissionOutcome === "answered"`), and `toolName: "SwarmPost"`
  for board posts.
- When `thinking` is `false`, both `thinking` blocks and live `thinking_delta` events
  are omitted.
- Omitted live events are replaced with a small `session_activity` at most once per
  second per session/client. This reports observed activity, not proof that a stalled
  agent is healthy. Elapsed time in the UI is time observed by the client, not server
  execution duration.

Canonical agent/Bridge histories remain complete. Other clients and `All` mode retain
full delivery. This does not reduce agent computation or all Bridge ingestion/image
registration work.

## Protocol and compatibility (`performance_mode_v2`)

New Bridges advertise both `performance_mode_v1` and `performance_mode_v2`.

`client_capabilities` accepts optional:
- `deliveryRevision: integer`
- `performanceMode: boolean` and `sessionPerformanceModes: Record<string, boolean>` (v1)
- `performanceFilter: PerformanceFilter` and
  `sessionPerformanceFilters: Record<string, PerformanceFilter>` (v2)

When a revision is supplied, the Bridge responds with `performance_mode_state` carrying
that revision after applying preferences. Initial capabilities precede queued history
requests and are resent on reconnect.

Compatibility matrix:
- **New app ↔ New Bridge (`performance_mode_v2`)**: Bridge uses `performanceFilter` /
  `sessionPerformanceFilters` directly for per-category delivery reduction.
- **New app ↔ Older Bridge (`performance_mode_v1` only or older)**:
  - A v1 Bridge ignores `performanceFilter` and drops tasks, subagents, edits, other
    tools, and tool results whenever `performanceMode: true`.
  - To avoid losing categories the user enabled (such as `tasks` in `Recommended`),
    the app only sets the legacy `performanceMode: true` when `tasks`, `subagents`,
    `codeEdits`, `otherTools`, and `toolResults` are all `false`. Otherwise it sends
    `performanceMode: false` (full delivery), applies its local UI projection, and
    shows the Bridge update notice in the activity pill.
- **Older app ↔ New Bridge**: Older apps send only `performanceMode` /
  `sessionPerformanceModes` without `performanceFilter`. The Bridge falls back to the
  legacy v1 projection (keeping thinking and Swarm conversation while omitting other
  tools, summaries, and tool results).

## Switching and history recovery

The app waits for the latest acknowledgement, then invalidates affected transcript caches
and requests full history for open sessions. Invalidation includes sessions touched during
rapid toggles even when the final preference equals the starting preference. Older
acknowledgements cannot reset current history. Past-history deduplication resets at this
ordered boundary; local user entries are retained for pending input and attachment recovery.
Explorer/context metadata survives invalidation. Closed sessions fetch fresh history when
opened. Switching to `All` therefore restores the complete transcript.

Filtered snapshots/deltas preserve canonical `fromSeq`/`toSeq` and entry sequence numbers
and set `filtered: true`. Clients accept intentional gaps only when the response begins at
or before the next expected sequence. Live activity can report the latest observed
`historySeq`; it is excluded from the transcript cache.

## Verification

Tests cover non-mutating projections, large payload reduction, per-category v2 toggles
(tasks, thinking/thinking_delta, subagents/summaries, code edits, other tools, tool
results), v1 backward compatibility, image/approval/plan retention, completion markers,
sparse cursors, independent client preferences, session overrides, acknowledgement
ordering, restoration after switching back, and the settings UI presets/toggles.
