# Codex usage-limit recovery proposal

Status: proposed; default behavior awaits product decision. No automatic recovery
is enabled by this document.

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
Its self-use workflow and unrelated fork changes are outside this proposal.

## Recommended first release

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
  backoff rather than a tight fixed-10-second loop. Final delay values can be
  tuned without changing the product behavior.
- Allow at most five automatic submissions per manual-input cycle. Meaningful
  progress can reset the backoff delay, but does not replenish this total budget.
  After exhaustion, keep the session usable and require manual input or explicit
  re-arming. This avoids an unbounded loop of partial progress and failures.

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

Add an explicit session action and a structured recovery-state event using the
existing capability negotiation. Store authoritative pending state in Bridge,
send it on reconnect, and render it through the existing Flutter chat state
management. The state needs enabled, phase, attempt budget, retry timestamp,
and last failure reason. Runtime input objects stay server-side.

Older Bridges must produce the normal `unsupported_message` update guidance
through `_unsupportedActions`; do not show a successful enable state until the
Bridge acknowledges it. Older clients connected to a newer Bridge must still
receive understandable ordinary error messages, without unknown opt-in events.

## Validation before adoption

Bridge tests must cover disabled behavior, confirmed 429/usage-limit failures,
non-retryable errors, reset time and fallback delays, attempt exhaustion,
duplicate terminal events, upstream retry ownership, cancellation races,
manual-input precedence, stop/restart, preserved attachments, and goal/approval
guards. Use fake clocks rather than spending live model usage.

Flutter tests must cover enable/disable, waiting and exhausted presentation,
cancellation, reconnect state, and old-Bridge update guidance. A separate test
Bridge must exercise state delivery and cancellation across mobile disconnect;
production port 8765 remains untouched.

## Product decision

Choose whether to ship the recommended default-OFF per-session behavior, make
recovery default-ON, or keep this change at design stage. Default-ON reduces setup
but allows delayed execution and additional usage without a per-session choice.
The implementation should begin after this decision; the list/history fixes in
PR #261 are independent.
