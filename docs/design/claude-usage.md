# Claude plan usage

Issue: [#235](https://github.com/K9i-0/ccpocket/issues/235)

## Source

Claude plan usage (5-hour / 7-day windows) is read only through the Claude
Agent SDK experimental API
`Query.usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET({ skipBehaviors: true })`
(available since SDK `0.3.169`).

- The Bridge never reads credential files, Keychain entries, or OAuth tokens
  for usage, and never calls claude.ai endpoints directly. The SDK resolves
  authentication exactly as it does for sessions.
- The same preflight as Claude sessions applies (`canStartClaudeSdk()`), and an
  `oauth` auth source is rejected unless `BRIDGE_ALLOW_CLAUDE_OAUTH=1`.
- `skipBehaviors: true` avoids scanning every transcript from the last week.
- The unstable method name and response shape are isolated in
  `packages/bridge/src/claude-usage.ts`. The response is treated as `unknown`
  and validated field by field.

## Lifecycle

Each request starts a temporary Query with an idle prompt (no turn is sent),
drains its iterator, awaits `initializationResult()`, calls the usage API, and
`close()`s the Query in `finally`. Init + usage share a 15 s timeout.
Concurrent requests share one in-flight read; completed results are not cached
so manual refresh always fetches fresh data. Active sessions are not touched.

## Protocol

No new message types. `usage_result.providers` may now contain a `claude`
entry, ordered before `codex`.

| Situation | `claude` entry |
|-----------|----------------|
| Plan limits available | `fiveHour` / `sevenDay` (either may be null) |
| Account has a model-scoped weekly limit (e.g. Fable on Max and above) | `modelWindows: [{ label, utilization, resetsAt }]` added |
| Not configured, API key / Bedrock / Vertex, OAuth not opted in, `rate_limits_available: false`, SDK without the API | omitted |
| Timeout or SDK error after auth check | `error` set, windows null |

`modelWindows` maps `rate_limits.model_scoped[]` from the SDK response. Labels
come from the server `display_name`, so the Bridge does not hardcode model
names. Entries with null utilization/reset or an empty label are dropped, and
the field is omitted when none remain (never sent for Codex). It is retained
with the other windows after a failed refresh. The app shows these rows only in
the settings usage card, not in the session list summary.

Codex is always fetched in parallel and is never blocked by a Claude failure.

## Compatibility

- Older apps only read the `codex` entry, so the extra entry is ignored.
- Newer apps against an older Bridge simply receive Codex only.
- `modelWindows` is optional: older apps ignore it, and newer apps treat a
  missing field as no model-scoped limit.

## Verification limits

The maintainer environment uses API key auth, which returns
`rate_limits_available: false`. Real subscription numbers have not been
verified end to end; the UI was verified with mock data.

`model_scoped` was checked against a real Max subscription (2026-11-10, SDK
`0.3.316`): it returned `[{ display_name: "Fable", utilization, resets_at }]`,
matching the claude.ai usage page. The page's "up to 50% of the weekly limit"
note comes from the undocumented `weekly_scoped_shares` and is not shown.
