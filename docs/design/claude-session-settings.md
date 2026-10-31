# Claude model, effort and fast mode in a running session

Claude sessions can change model, effort and fast mode without a restart, with
the same quick/advanced panel Codex uses (session mode bar chip and the new
session sheet).

## Wire protocol

- Client → Bridge: `set_claude_settings { sessionId, model?, effort?, fastMode? }`.
  At least one field is required. `model` is a value from `claudeModels`
  (`default` resets to Claude Code's default model).
- Bridge → clients: `system` / `claude_settings { model?, effort?, fastMode }`.
  It is broadcast after a change and sent with `get_history` and history deltas.
  A rejected change returns `error` (`set_claude_settings_rejected`) followed by
  the current `claude_settings` so the requester can roll back.
- Session summaries include `claudeSettings { model?, effort?, fastMode? }`.
- `start` / `resume_session` accept `claudeFastMode`.
- `claudeModelOptions[].supportsFastMode` marks models that support fast mode.
- The Bridge advertises `claude_session_settings_v1`. The app shows the Claude
  model chip only when the capability is present; older Bridges otherwise answer
  `set_claude_settings` with `unsupported_message`, which shows the update hint.
  Remove the gate when protocol v2 makes the capability required.

## Bridge behavior

`SdkProcess.updateSettings` calls `Query.setModel` for model changes and
`Query.applyFlagSettings({ effortLevel, fastMode })` for effort and fast mode.
Effort is re-applied after a model switch so the new model keeps it; models
without effort support downgrade silently in Claude Code. Changes take effect from
the next request; a running turn keeps its model. The selected values (not the
resolved model id from `system/init`) are reported back.

The app stores the selected values in the per-session Claude settings so resuming
the session starts with them.

## Fork from an assistant message

`fork { sessionId, targetUuid }` now also accepts Claude sessions. For Claude the
target is the UUID of the assistant message that ends the kept turn (Codex keeps
using the user-turn UUID). The Bridge validates the UUID against the Claude
transcript and starts a new session with `resume`, `forkSession: true` and
`resumeSessionAt`, copying the selected model/effort/fast mode and permission
mode. The source session keeps running. The new session's provider id arrives
with the first `system/init`, so it is not pre-populated. The app shows the fork
action on Claude assistant messages only when the Bridge advertises
`claude_fork_v1` (older Bridges reply `fork_failed`).
