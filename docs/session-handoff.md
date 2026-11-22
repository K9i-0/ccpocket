# Session handoff

## Goal

Stop a session and continue its task in a session of another agent: Claude
Code, Codex and Antigravity, in every direction. Typical uses are switching
when another agent suits the task better, and letting another agent do the
finishing work.

The chat's overflow menu offers "Hand off to …" for each of the other agents.
The source session is stopped; it stays in the recent sessions and can be
resumed later.

## Why a prompt and not native history

All three agents can be read: `sessionTranscriptMessages` returns the
conversation of any running session as `SessionHistoryMessage[]`. Writing is
what differs.

| Target | Way to give it earlier history | Used |
| --- | --- | --- |
| Antigravity | none; `agy` only has `session/new` and `session/prompt` | first prompt |
| Codex | `thread/inject_items` appends raw Responses items | first prompt |
| Claude | a fabricated JSONL transcript to resume | first prompt |

Antigravity only accepts a prompt, so a prompt is the one mechanism that
covers all pairs. `thread/inject_items` could later make Codex targets more
natural; a fabricated Claude transcript is fragile and was not tried. Thinking
blocks and encrypted Codex compaction summaries cannot be moved in any case.

## Flow

`handoff_session { sessionId, targetProvider, instruction? }`, handled in
`packages/bridge/src/websocket/handlers/session-handoff.ts`:

1. A running turn is interrupted and the Bridge waits for the session to go
   idle. The note has to be a turn of its own, and Antigravity would steer
   the running turn with the request instead.
2. The conversation is read while the source is alive (Codex history comes
   from its app-server). Reading before the next step keeps the note request
   and its reply out of what the target is given.
3. The source agent is asked for a handoff note in one last turn, through the
   normal input path, so it shows in the chat like any other turn. The Bridge
   waits up to three minutes.
4. The conversation is saved as Markdown under `~/.ccpocket/handoffs/`
   (tool calls and results included, long items shortened, files older than
   30 days removed).
5. The target is started through `handleStart` in the same project, worktree
   and workspace, with the handoff prompt as its `initialPrompt`.
6. The source is stopped, after the target was created. When the target
   cannot be started the source keeps running.

The note step is skipped, and the target starts from the Bridge-built context
alone, when the source cannot write it: the usage limit is reached, the
process is gone, input is already queued, the turn fails, the reply is empty
or the three minutes pass. When the user interrupts the note turn, the handoff
is cancelled and the source keeps running.

A second `handoff_session` for the same session is rejected while one is
under way. Failures are reported as `error` with `errorCode: "handoff_failed"`.

## The handoff prompt

Built by `buildHandoffPrompt` in `packages/bridge/src/session-handoff.ts`:

- the marker line `[ccpocket handoff: <source> → <target>]`
- what to do now: the user's `instruction`, or "continue the task"
- a reminder to check the working tree (`git status`, `git diff`), because an
  interrupted source can leave half-finished edits the note does not mention
- the handoff note, up to 12,000 characters
- the original request, when it is not among the recent messages
- the recent conversation: text of user and assistant messages only, newest
  first up to 12,000 characters, 2,000 per message
- the path of the saved transcript

A task can be handed over more than once. The conversation of the second
source then starts with the first handoff prompt. With a note, that prompt is
replaced by one line in the recent conversation, because the note covers it
and repeating it would nest prompts; without a note it is kept as context. It
is never used as the original request or as the session name.

The prompt has to be enough without the transcript file: whether a target can
read a path outside the project depends on its sandbox and approval mode.

The prompt is sent as written. `prepareInitialPrompt` is skipped
(`rawInitialPrompt`), because quoted user turns may contain skill triggers of
the other agent that must not be rewritten or attached.

## What carries over

| Item | Behaviour |
| --- | --- |
| Files | Same directory or worktree, so every change is already on disk |
| Workspace | Same project, or the same additional roots |
| Execution mode | `default` / `acceptEdits` / `fullAccess` mapped by `start`; plan mode is not carried over |
| Model, effort, sandbox | The target's defaults |
| Name | The source's name; without one, the first line of the first request (60 characters). It is written to the target's own storage once the provider has given the session an id |
| Rewind points | Not carried over; the target cannot rewind past the handoff |

## Protocol

All additions stay within protocol v1.

| Item | Direction | Compatibility |
| --- | --- | --- |
| `handoff_session` | App → Bridge | Older Bridges answer `unsupported_message`; the chat shows the update hint (`_unsupportedActions`) |
| `session_created.handoff` with `sourceSessionId` | Bridge → App | Optional field. Only sent in answer to `handoff_session`, which older apps do not send |
| `session_handoff_v1` | `protocolCapabilities` | The app shows the menu entries only with it |

`session_created` goes to the requesting client only, like a fork. The stopped
source and the new session reach other clients through the session list.

## App

- `features/chat_session/session_handoff.dart`: menu entries, the confirmation
  dialog with an optional instruction, and `openHandoffSession`.
- The offered targets are the agents of the new session sheet other than the
  current one (`visibleNewSessionTabs`), so an agent switched off in settings
  or missing on the Bridge machine is not offered.
- On `session_created` with `handoff`, the chat screen is replaced instead of
  switched in place: the provider differs, and Claude and Antigravity share a
  screen that takes the provider as an argument. A workspace pane selects the
  new session; a routed screen replaces its route.
- `widgets/bubbles/handoff_bubble.dart`: the note request and the handoff
  prompt are shown as a compact card that expands on tap. The card keys on the
  marker at the start of the text, because history reloaded from the agent's
  own transcript carries no other field.

## Antigravity

The note request and the handoff prompt are sent by the Bridge, but only
after the user chose the handoff in the app, so they count as user input and
are allowed with Google sign-in (decided 2026-11-22). Agent-driven
verification still follows the API-key rule in
[antigravity-acp-integration.md](antigravity-acp-integration.md).

## Verification

- Unit tests: `session-handoff.test.ts` (prompt, transcript, title),
  `session-handoff-handler.test.ts` (note step, fallbacks, cancellation,
  start options), `test/session_handoff_test.dart` (message, targets, card,
  dialog).
- Real agents on the test Bridge, driven over WebSocket (2026-11-22):
  Claude → Codex, Codex → Antigravity (API key) and Antigravity → Claude.
  Each target read the note and continued a four-step file task. The other
  three pairs use the same readers and starters but were not run.
- App on the iOS simulator: Claude → Codex from the menu, with an
  instruction; the card after reopening the session; the menu of the Codex
  chat. The chat was a workspace pane; replacing a routed screen
  (`context.router.replace`) was not exercised.
