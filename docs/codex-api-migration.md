# Codex app-server API migration (0.153.4)

## Full Access handoff to Desktop (0.157.0)

For explicit `fullAccess` sessions, Bridge sends
`permissions: ":danger-full-access"` on both `thread/start` and `thread/resume`
when the initialize response identifies stable Codex 0.157.0 or newer.
`approvalPolicy: "never"` and `approvalsReviewer: "user"` remain explicit.
The new field cannot be combined with `sandbox` or `sandboxPolicy`.

Legacy `sandbox: "danger-full-access"` produces no active permission profile.
An isolated 0.157.0 resume of a saved turn with that legacy setting restored
`sandbox_mode` from config while preserving `approval_policy: "never"`.
With a workspace-write config, Desktop consequently recognized Custom and
the effective sandbox changed. A saved
`active_permission_profile: {"id": ":danger-full-access"}` preserved Full
Access on resume. Auto Review already used workspace-write in this scenario.

Older, prerelease, and unidentified servers keep the legacy sandbox request:
older servers may silently ignore unknown request fields, so sending only
`permissions` without verified support could select an unintended sandbox.
0.157.0 is the verified compatibility floor, not a claim about the first
release introducing the API. Named config profiles, Custom, and other modes
keep their existing behavior. Existing rollouts are not rewritten; explicitly
resuming Full Access through an updated Bridge applies the profile to the
session, which subsequent turns can persist for Desktop handoff.

Validation includes start/resume request regression tests and isolated real
app-server checks with temporary session metadata, without model generation
or changes to production sessions.

## Previous API migration

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

## Default-mode questions (0.163.0)

Checked the latest npm stable release (`@openai/codex` 0.163.0) and its
`app-server generate-ts --experimental` output. The wire request remains
`item/tool/requestUserInput`; answers remain keyed by question ID. In this
schema `autoResolutionMs` is deprecated in favor of `isBlocking`.

The upstream [tool configuration](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/tools/src/tool_config.rs)
gates Default-mode questions on `features.default_mode_request_user_input`.
The [handler](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/tools/handlers/request_user_input.rs)
sets `isBlocking` only for Plan mode. Bridge now enables the feature via the
thread-local `config.features` override on both `thread/start` and
`thread/resume`, preserving existing profile and reasoning overrides in the
request. This does not edit user config or
change the session's collaboration mode or approval policy.

The existing Flutter question UI and Bridge optional-input lifecycle already
handle this request without requiring Plan mode. No new Bridge/client message
is needed. Older Codex versions that do not implement the feature cannot gain
Default-mode questions from this override; the existing Plan-mode path and
missing-`isBlocking` blocking fallback remain intact. No timer auto-selects an
answer, and `serverRequest/resolved` remains authoritative for dismissal.

Validation: start/resume configuration regression tests (including coexistence
with profile and reasoning overrides), existing blocking/non-blocking question
lifecycle tests, 10 Flutter pending-input state tests, TypeScript checking,
and an isolated 0.163.0 ephemeral
`thread/start` smoke test. No model turn or production Bridge restart is needed.
