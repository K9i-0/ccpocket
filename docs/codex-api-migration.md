# Codex app-server API migration (0.153.4)

Verified against the locally generated app-server TypeScript schema and
https://learn.chatgpt.com/docs/app-server.

- Read history with `thread/read(includeTurns: false)` and ascending
  `thread/turns/list(itemsView: full)` pages. Only method-not-found falls back
  to legacy full-history reads for older Codex installations. New threads
  with no materialized history return an empty turn list.
- Resume with `excludeTurns: true`; session history is fetched separately.
- Fork with `lastTurnId` and `excludeTurns: true`, then read the fork through
  the paginated API. Verify its boundary before attaching a new session;
  older servers can silently ignore unknown fields.
- Conversation rewind creates a fork ending before the selected user message.
  Rewinding before the first user message starts a fresh thread. The original
  stored thread remains intact. No `thread/rollback` calls remain.
- Boundaries inside a turn containing multiple user messages (steering) are
  rejected: the fork API supports complete turns, not individual items.
- `serviceTiers` is authoritative, including an empty array. Read deprecated
  `additionalSpeedTiers` only when the current field is absent.
- `isBlocking: false` questions do not change execution to approval-waiting.
  They remain answerable after turn completion and during history restoration
  until explicitly answered or resolved. Session-context synchronization also
  preserves optional questions. Missing `isBlocking` retains the old
  blocking behavior.

Validation covers Bridge RPC routing/state tests, Flutter history restoration,
TypeScript/Dart analysis, and an isolated real app-server smoke test using a
synthetic two-turn rollout. The smoke test does not generate model responses
or modify production session history.

An iPhone 17 Pro simulator with a local mock Bridge verified restoration during
running, retention after result/idle, answer delivery, and dismissal on
`permission_resolved`. The test app and mock were stopped afterward.
