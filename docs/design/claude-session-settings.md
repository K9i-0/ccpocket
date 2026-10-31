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
