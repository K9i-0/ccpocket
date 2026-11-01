# Background work status

How ccpocket shows sessions whose turn has ended while background work keeps
running, and when it sends the "completed" notification.

## Claude

Claude Code ends a turn with a `result` even while background tasks (subagents,
`run_in_background` shells, monitors, workflows) are live. When a task reports
back, the CLI starts a follow-up turn by itself and emits another `result`.

Observed with Agent SDK 0.3.316 (`CLAUDE_CODE_EMIT_SESSION_STATE_EVENTS=1`, one
background subagent that runs `sleep 25` in a background shell):

```
4.0  background_tasks_changed [local_agent]
5.6  result "launched"
12.8 subagent ends, its shell keeps running → follow-up turn
16.5 result "…still waiting"
16.5 session_state_changed idle      (shell still live)
34.7 background_tasks_changed []  → [local_agent]   (subagent resumes)
36.0 session_state_changed running   → follow-up turn
37.7 result "bg complete"
37.7 session_state_changed idle
```

- Every `result` before 37.7 used to show the session as Ready and push Done.
- `session_state_changed: idle` is not enough: it fires while a subagent's
  shell is still running, and the subagent resumes later.
- The task set can empty for a moment before a task resumes or a follow-up
  turn starts.
- User input sent while only background work runs starts a turn immediately,
  so the process `status` must stay `idle`. Marking it `running` would route
  input through the interrupt-and-queue path.

### Decisions

- **Display.** The app shows a Claude session as Working when its raw status is
  idle and `backgroundTaskCount > 0`. Shells and monitors count as well as
  agents, as decided with the user. A long-lived dev server therefore keeps the
  session Working, without a completion push, until it is stopped. The user
  accepted this.
- **Completion push.** The Bridge (`BackgroundCompletionGate`) holds a
  successful Claude `result` while background tasks are live. Once the session
  stays idle without background tasks for 2 s, it pushes the latest held
  result. A later result with no background work replaces the held one and is
  pushed directly. Error results are pushed immediately. Stopped results
  discard the held one.
- **Local notification fallback.** The app's `ChatSessionCubit` applies the
  same rule to `notifySessionComplete`.
- **Chat completion chips.** In Claude chats, a successful result chip is
  hidden when a later result follows without user input in between (a
  follow-up turn Claude started itself), or when it is the latest result and
  background tasks are still live. A result whose text is shown nowhere else
  stays visible. Codex chats are unchanged, because goal mode runs
  consecutive turns on purpose.
- **Stop.** Between turns, `interrupt` on a Claude session with background
  tasks calls the SDK's `stopTask` for each task. During a turn it interrupts
  the turn as before. The chat screen's background bar shows a stop button
  only between turns.

## Codex

app-server v2 has no background-work signal. A thread becomes `Idle` when its
turn completes, even while a unified-exec terminal or a child agent thread is
still running. A finished child does not start a parent turn (except a parent
in durable sleep), so Codex never repeats completions the way Claude does.

`CodexBackgroundTracker` derives the set in the same way as the Codex TUI:

- `commandExecution` items with `source: unifiedExecStartup` and a `processId`
  are live from `item/started` until `item/completed`.
- Threads whose `thread/started` names this thread as `parentThreadId` are child
  agents. They are active per `thread/status/changed` and `turn/started` /
  `turn/completed`, and are removed on `thread/closed`. Their notifications are
  consumed so that they never drive the parent's status.
- Work that belongs to the turn in progress is foreground and is left out until
  that turn ends.

Codex sessions stay Ready. They show the count as a quiet badge and the task
list in the chat screen's background bar. Completion pushes are not held.

## Protocol

- `background_tasks` (`{ tasks: BackgroundTaskInfo[] }`, REPLACE semantics) is
  now also sent for Codex sessions, with `taskType` `codex_terminal` or
  `codex_agent`. Clients opt in through `supportedServerMessages`, as before.
- The session list adds `backgroundAgentCount`, which counts the agents among
  `backgroundTaskCount`. Agent task types are `local_agent`, `remote_agent`,
  `local_workflow` and `codex_agent`.
- No new client message. Older Bridges ignore an idle `interrupt`, and older
  apps keep showing such sessions as Ready.

## Card display

- Agents explain why the session is Working, so they go in the status row:
  `Working · 2 agents`.
- Shells, monitors and Codex work get a small icon with a count instead of the
  former `Background N` pill. The pill was wide enough to overlap the status
  label.
