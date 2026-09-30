# Codex usage-limit recovery

Status: implemented after the 2026-09-30 product decision. Default OFF; enable
from the Codex chat menu → Automatic recovery for the current Bridge session.

## Problem and prior work

[Issue #82](https://github.com/K9i-0/ccpocket/issues/82) describes long-running
mobile tasks stopping at usage limits. The request evolved from buffering many
`continue` messages to responding to actual failures. @augumn provided a self-use
implementation, including manual-input precedence, visible retry messages, and
a retry limit:

- [Initial implementation](https://github.com/augumn/ccpocket/commit/a59c77bd7cd67f1bd78c48c2b615f4a4ee92925c)
- [Recovery hardening](https://github.com/augumn/ccpocket/commit/63f47f22996ed1e1c4dd357bf69a00d6d369d21b)

That implementation defaults to enabled, waits a fixed 10 seconds, allows five
consecutive failures, and resets the counter when meaningful progress appears.
The inspected branch head was `09dcce53cb42a633956d4632ece23b236d9af0ea`.
Its self-use workflow and unrelated fork changes are outside this implementation.

## First-release behavior

- Default OFF. Enable explicitly per Bridge session; do not inherit the choice
  into a fork, resumed session after Bridge restart, or unrelated new session.
- Cover explicit usage-limit / HTTP 429 failures only. Authentication errors,
  permissions, user cancellation, transport ambiguity, and arbitrary tool
  failures remain manual.
- Bridge owns the timer, so it survives mobile disconnect/backgrounding but
  is cancelled when the Bridge session stops or the Bridge restarts.
- Show enabled/waiting/exhausted state, the reason, scheduled time, and attempt
  count. Provide cancellation while waiting; manual input cancels pending work.
- Prefer structured retry/reset times from the error or account rate-limit
  information. If a usable reset time is unavailable, use bounded exponential
  backoff (10, 20, 40, 80, 160 seconds for the five attempts) rather than a
  tight fixed-10-second loop. A later reset time is never shortened.
- Allow at most five automatic submissions per manual-input cycle. Meaningful
  progress does not replenish this total budget or reset the backoff.
  After exhaustion, keep the session usable and require manual input for a new
  recovery cycle. Toggling OFF then ON also resets the allowance. This avoids an unbounded loop of partial progress and failures.

## Execution and cancellation semantics

Distinguish a rejected `turn/start` from a failed turn that already executed work.
A confirmed pre-start rejection may retry the original typed input, preserving
images, skills, and mentions without deleting temporary assets prematurely.
An in-progress failure uses a visible continuation message, not a replay of the
original task. A continuation instruction is not an exactly-once guarantee;
the agent can still repeat completed operations and consume additional usage.

Do not schedule from a free-floating warning or an error carrying `willRetry`:
the current process already recognizes upstream retry ownership. Deduplicate
failure notifications against the current thread/turn and give each pending
retry a generation token. Before sending, recheck that the same session and
generation remain enabled, no newer manual input or active turn intervened,
and no approval, plan decision, or user question is pending.

Preserve goal stops (`paused`, `complete`, `budgetLimited`, and human-input
blocking); do not use recovery to bypass token budgets or create/resume goals.
This first release covers Bridge-owned Codex sessions only, not shared-client
takeover or recovery of orphaned processes.

## Protocol and UI boundaries

`set_codex_recovery` carries `sessionId` and an explicit boolean `enabled`;
`cancel_codex_recovery` cancels a pending wait without resetting the attempt
allowance. Both apply only to active Codex sessions. `codex_recovery_state` is an
opt-in server event carrying `enabled`, `phase` (off/armed/waiting/exhausted/blocked),
`attempts`, `maxAttempts`, `retryAt` (Unix milliseconds or null), and `reason`.
Bridge owns the state and sends it after history replay on reconnect. Flutter
stores it in ChatSessionCubit and updates the switch only after acknowledgement.
Runtime input objects stay server-side.

Older Bridges must produce the normal `unsupported_message` update guidance
through `_unsupportedActions`; do not show a successful enable state until the
Bridge acknowledges it. Older clients connected to a newer Bridge must still
receive understandable ordinary error messages, without unknown opt-in events.

## Validation

Bridge tests cover disabled behavior, confirmed 429/usage-limit failures,
non-retryable errors, reset time and fallback delays, attempt exhaustion,
duplicate terminal events, upstream retry ownership, cancellation races,
manual-input precedence, stop/restart, preserved attachments, and goal/approval
guards. Use fake clocks rather than spending live model usage.

Flutter tests cover enable/disable, waiting and exhausted presentation,
cancellation, reconnect state, and old-Bridge update guidance. A loopback Bridge WebSocket test exercises state delivery and cancellation across
client disconnect;
production port 8765 remains untouched.

## Compatibility, limits, and evidence

The user accepted default-OFF per-session recovery. The design follows @augumn's
failure-driven continuation and manual-input precedence while replacing default-ON,
fixed delay, and progress-reset retry counts. No multi-message FIFO is introduced.

A fresh goal lookup is required before each automatic send. Unknown/unsupported
Goal RPCs fail closed and show attention-required state. Explicit paused, blocked,
complete, budgetLimited goals and numeric token-budget exhaustion cannot be
bypassed. This may prevent recovery with older Codex versions even when ordinary
chat works; manual input remains available.

Timers and original input are kept only in memory. Waiting sessions are excluded
from idle-session retention eviction. Reset metadata is a best-effort signal:
when unavailable, retries may still hit the limit and exhaust the allowance.
Continuation prompts cannot guarantee exactly-once tool execution.

Validation includes deterministic input-loop and timer tests, real loopback
WebSocket negotiation/reconnect/cancel, Flutter state/protocol/widget tests,
narrow-screen large-text layout, and a rendered settings-panel inspection.
The full Bridge suite passed 1,289 tests; the full Flutter suite passed 1,944
tests (four skipped). TypeScript checking passed; Dart analysis reported only
47 existing informational lints. Tests inject failures and do not consume live model usage. A real-provider 429
and an iOS simulator runtime were not used for this validation.
