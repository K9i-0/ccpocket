# Bridge session ownership v1

Status: implemented for the Bridge protocol. Mobile consumption is the M5
milestone of `ccpocket-bridge-cross-device-stability-v1`.

## Identity boundaries

Ownership v1 separates three identities that older clients exposed through a
single `sessionId` label:

- `bridgeGeneration` is a UUID created once by each Bridge process. Any Bridge
  restart changes it.
- `bridgeSessionId` is the short in-memory runtime identifier owned by that
  generation. It is never reconstructed from disk.
- `providerThreadId` is the persistent Claude session or Codex thread UUID. It
  can outlive every Bridge generation and can be discovered without owning a
  live writer.

`SessionInfo.id`, `SessionSummary.id`, `claudeSessionId`, and the protocol's
`sessionId` remain deprecated compatibility projections for one connected App
window. They must not be used to infer generation, writer ownership, or a safe
cross-device mutation target. An ownership-v1 client advertises
`sessionOwnershipVersion: 1` in `client_capabilities` and uses the explicit
fields thereafter.

## Ownership projection

Live session lists, recent discovery, persisted history, and resume results
return the following closed projection:

| Field | Values and meaning |
| --- | --- |
| `recordKind` | `live`, `recent`, `history`, or `resume` |
| `origin` | `bridge`, `external`, or `disk` |
| `owner` | `bridge`, `external`, `none`, or fail-closed `unknown` |
| `runtimeStatus` | Bridge process status, `not_running`, `restarting`, or `unknown` |
| `attachmentState` | `owned`, `external_idle`, `external_active`, `external_unknown`, or `unavailable` |
| `capabilities` | Explicit allowed actions; absence denies an action |
| `readOnlyReason` | A closed reason or `null` for an owned mutable runtime |

Bridge-owned live records expose the actual runtime status and the owned
capability set. A `recent` or `history` record derived from persisted provider
state is always `origin=disk`, `owner=unknown`, and read-only. Disk discovery
never upgrades itself to a live ownership claim, even if an untrusted stored
record contains owner-like fields.

Persisted history is read with provider read APIs and does not call
`thread/resume`, create a `SessionInfo`, or claim a writer. External idle versus
active is decided only by a controlled resume attempt: successful provider init
becomes an owned `resume` record; an app-server active-writer response becomes
`writer_conflict` and leaves no Bridge runtime.

## Mutation and resume rules

Ownership-v1 `input`, approve/approve-always, reject, answer, interrupt, stop,
fork, and archive messages must carry all of:

- `bridgeSessionId`;
- the current `bridgeGeneration`;
- `providerThreadId` (a nullable value is explicit for a new thread not yet
  bound by provider init).

The Bridge rejects a missing tuple, a stale generation, a missing runtime, or a
provider-thread mismatch before calling a process method. The deprecated
`sessionId` is normalized only after the explicit tuple passes.

External resume carries `providerThreadId`, current `bridgeGeneration`, and
`expectedOwner`. It validates the legacy projection, allowed project path,
thread existence, current generation, and the in-memory Bridge owner registry
before starting a runtime. A Codex resume does not emit `session_created` until
the matching `system/init` confirms provider ownership. `-32600` active-writer
responses map to `writer_conflict`; the attempted runtime is destroyed and the
safe result is read-only history.

## Failure envelope

Every ownership-v1 control error includes:

```json
{
  "type": "error",
  "operation": "resume_session",
  "bridgeSessionId": null,
  "providerThreadId": "provider-thread-id",
  "bridgeGeneration": "current-generation",
  "errorCode": "writer_conflict",
  "retryable": true,
  "recoveryAction": "open_read_only"
}
```

The closed M4 codes are `session_not_found`, `thread_not_found`,
`writer_conflict`, `path_not_allowed`, `stale_generation`,
`bridge_restarting`, and `unsupported_operation`. Recovery actions are
machine-readable UI directions such as `refresh_sessions`, `refresh_history`,
`refresh_session`, `choose_allowed_path`, `open_read_only`, and
`attach_owned_session`. Unknown codes or actions must be rendered as
unavailable/read-only by the client.

## Updater readiness

Updater readiness derives active turns, approvals, questions, and busy workers
only from records whose ownership projection is `owner=bridge` and
`attachmentState=owned`. Persisted external records, disk counts, or a raw
session total cannot block or authorize promotion.
