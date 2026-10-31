# Claude background tasks

A Claude turn can end while work it started keeps running: `run_in_background`
shells, Monitor watches, and background subagents. The CLI reports the turn's
`result` and goes idle, then starts a new turn on its own when a task finishes
(`task_notification`). Before this change the app showed such a session as done,
because the Bridge dropped every task event.

## Source of truth

The Agent SDK emits `system/background_tasks_changed` with the full set of live
tasks whenever membership changes. The SDK documents it as a level signal with
replace semantics, so the Bridge mirrors that set instead of pairing the
`task_started` / `task_notification` edges. Tasks marked `ambient` (or
`skip_transcript`) are not activity and are left out.

`SdkProcess` keeps the current set, emits it when it changes, and clears it when
the query starts, stops or exits, because background tasks end with the CLI
process.

## Wire protocol

- New server message `background_tasks`:
  `{ type, sessionId, tasks: [{ taskId, taskType, description?, subagentType? }] }`.
  Each message replaces the previous set; an empty list means nothing runs.
- It is opt-in: the Bridge only sends it to clients that list
  `background_tasks` in `client_capabilities.supportedServerMessages`. Older apps
  would otherwise show it as an unknown message.
- It is session state, not chat history. Like `conversation_queue`, the Bridge
  sends the current set with every history response (`history`,
  `history_delta`, `history_snapshot`) so a reconnecting client recovers it.
- The session summary gains `backgroundTaskCount` (omitted when zero). Older apps
  ignore the field.

Codex sessions do not send this message.

## App

- The session screen shows a "Running in background" bar above the input with
  the first task's description and how many more run. It is shown regardless of
  the turn status.
- Running session cards show a "Background N" badge.
- Performance mode labels an idle session with background tasks as
  "Background running" instead of "Idle".

The turn status itself is unchanged: `idle` still means the agent can take a new
message, which the CLI accepts while background tasks run.
