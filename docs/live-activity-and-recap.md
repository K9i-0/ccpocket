# Live Agent Activity & Claude Session Recap

ccpocket surfaces mid-turn agent progress across **Claude**, **Codex**, and **Antigravity** sessions, as well as Claude Code's **Session Recap** (`away_summary` / `/recap`).

## 1. Protocol & Backward Compatibility

Both new WebSocket message types are opt-in via `client_capabilities.supportedServerMessages` (`OPT_IN_SERVER_MESSAGES` in `packages/bridge/src/websocket.ts`):

- **`agent_activity`**:
  - Ephemeral per-session status (`{ type: "agent_activity", sessionId, activity: AgentActivityState | null }`).
  - Kept out of `session.history` (never increments `historyRevision` or triggers `SessionRuntimeStore` sequence gaps) and stored on `SessionInfo.agentActivity` so newly-connected or re-synced clients immediately receive the active snapshot alongside `background_tasks`.
  - Older clients that do not advertise `agent_activity` never receive it; newer clients connected to older Bridges gracefully fall back to deriving `_AgentActivityBar` labels from incomplete `tool_use` blocks and `ProcessStatus.running`.
- **`session_recap`**:
  - Transcript message (`{ type: "session_recap", content, source, timestamp }`) and `past_history` item (`{ role: "recap", recap: { content, source } }`).
  - Filtered from live/history/past_history payloads for clients that do not advertise `session_recap`.

## 2. Provider Coverage

### Claude (`packages/bridge/src/sdk-process.ts` & `sessions-index.ts`)
- **Summarized Adaptive Thinking**: Passes `--thinking-display=summarized` (and `{ thinking: { type: "adaptive", display: "summarized" } }` on Opus 4.7+) so adaptive thinking streams readable `thinking_delta` progress instead of silent `omitted` blocks. When a provider still emits redacted thinking (`system/thinking_tokens`), `agent_activity.thinkingTokens` displays live token progress (`Thinking (1.5k tokens)...`).
- **Streaming Tool JSON (`content_block_start` / `input_json_delta`)**: Publishes `preparingTool: true` with extracted file/command/query hints while large `Edit`/`Write`/`Bash` JSON arguments are still being generated before `assistant` arrives.
- **Tool Elapsed Time & Classifier Summaries**: Forwards `tool_progress` (`elapsedSeconds`), `system/task_summary` (`detail`), and `agentProgressSummaries: true` (`system/task_progress` `summary` / `last_tool_name` for both foreground subagents and `background_tasks`).
- **Parallel Tool Results**: Emits all `tool_result` blocks in multi-tool `user` frames so parallel `Read`/`Grep`/`Edit` calls never leave stale incomplete tool entries.
- **Session Recap (`recap:`)**:
  - Live `system/away_summary` frames and `/recap` `<local-command-stdout>` outputs emit `session_recap`.
  - `readClaudeSessionMessages` extracts the latest trailing `away_summary` from `.jsonl` transcripts (omitting older intermediate `away_summary` snapshots superseded by later turns) so reopening an idle Claude session displays a concise `recap:` card at the bottom.

### Codex (`packages/bridge/src/codex-process.ts`)
- **Immediate Tool Start**: Emits `assistant(tool_use)` on `item/started` for `mcpToolCall` and `webSearch` (in addition to `commandExecution`, `fileChange`, `dynamicToolCall`, `imageGeneration`, `collabAgentToolCall`), deduplicating the fallback `assistant` emit on `item/completed`.
- **MCP Progress**: Forwards `item/mcpToolCall/progress` messages via `agent_activity`.
- **Reasoning Stream Deduplication**: Tracks streamed reasoning items across `summaryTextDelta` / `textDelta` / `summaryPartAdded` so `item/completed` does not duplicate already-streamed thinking text, while still falling back to `item.summary` (including `string[]` summaries) when no deltas preceded completion.

### Mobile UI (`apps/mobile/`)
- `StreamingStateCubit` holds `AgentActivityInfo? activity` separately from `ChatSessionCubit` to avoid full screen/toolbar rebuilds on 1s progress ticks.
- `ChatMessageHandler` & `ChatSessionCubit` clear `StreamingStateCubit` text/thinking buffers when `AssistantServerMessage` commits (including thinking-only turns with no `stream_delta`), and reset all streaming/activity state on `ResultMessage` and `StatusMessage(idle | starting)`.
- `findLatestIncompleteToolUse` ignores notification-only `UpdatePlan` items, terminal-status history items, and rounds superseded by later assistant text.
