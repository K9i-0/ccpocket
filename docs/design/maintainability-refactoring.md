# Maintainability refactoring audit

## Goal

Keep compatibility handling at system boundaries, while making the normal path
explicit and testable. A fallback is retained only when it has a concrete
compatibility purpose and a defined exit condition.

## Audit scope

- Bridge: all 29,282 non-test TypeScript lines under `packages/bridge/src`
- Mobile: all 94,998 non-generated Dart lines under `apps/mobile/lib`
- Signals: file size, branch density, duplicated validation/persistence,
  swallowed exceptions, legacy/fallback markers, and existing test coverage

The scan found these highest-risk concentration points:

| Priority | Area | Signal | Intended responsibility |
| --- | --- | --- | --- |
| P0 | `websocket.ts::handleClientMessage` | 4,253 lines; estimated cyclomatic complexity 629 | Route an already validated client command to one domain handler |
| P0 | `parser.ts::parseClientMessage` | 867 lines and complexity 436 before this change | Validate the wire contract without applying business rules |
| P1 | `bridge_service.dart` | 2,850 lines; 288 branch markers | Own the connection lifecycle and delegate history/offline-queue policies |
| P1 | `chat_session_cubit.dart` | 2,230 lines; 231 branch markers | Coordinate chat state transitions, not protocol normalization |
| P1 | `messages.dart` | 4,786 lines; 151 branch markers | Define message types; parsing should be grouped by protocol domain |
| P2 | Claude/Codex session screens | 4,019 combined lines with duplicated helpers | Compose provider-specific UI from shared session components |

Silent catches were reviewed as a heuristic, not treated as defects by
themselves: 228 Bridge catches and 62 Mobile `catch (_)` sites remain. File,
network, discovery, and optional-platform boundaries legitimately need
best-effort behavior, but parsing and persisted-schema code should not invent
values after a failure.

## Refactoring completed

### Session command validation

`start` and `resume_session` now share one validation contract. The validator
accepts optional fields only when their wire types and enum values are valid.
Start-specific fields are validated separately.

This fixes existing holes for invalid `provider`, `sandboxMode`, `sessionId`,
`continue`, and worktree fields. Table-driven tests require invalid shared
options to be rejected consistently by both commands.

After extraction, `parseClientMessage` is 621 lines with estimated complexity
339. Further reduction should split its switch into session, prompt-history,
filesystem, and Git validators without changing the public protocol.

### New-session defaults

`SessionStartDefaultsStore` is now the only owner of provider-scoped defaults.
Its contract is:

1. Read a correctly scoped value when available.
2. Reject a value stored under the wrong provider key.
3. Use the legacy shared key only for one-time migration.
4. Persist the migrated provider value and remove the legacy key after the
   replacement writes succeed.
5. Remove obsolete legacy data after an explicit save.

The session list and deep-link resume path now use the same implementation.

### Codex project profiles

`CodexProjectProfileStore` is now the only owner of project-to-profile
persistence. It normalizes project paths and accepts only non-empty string
profile names. Corrupt storage is treated as empty and is replaced only by a
subsequent explicit save; arbitrary JSON values are no longer coerced with
`toString()`.

## Fallback policy for follow-up work

- Protocol input: reject malformed values; do not coerce them.
- Persisted migrations: migrate once, verify the replacement write, then
  remove the legacy source.
- Missing optional metadata: keep it unknown instead of guessing a factual
  value.
- Network/version compatibility: keep a fallback only when older peers are a
  supported case; make the activation observable and cover the fallback with a
  compatibility test.
- UI composition: use a neutral empty/error state rather than catching all
  failures inside rendering helpers.

## Recommended next slices

1. Characterize and extract Git, prompt-history, and file commands from
   `BridgeWebSocketServer.handleClientMessage` into domain handlers.
2. Split `BridgeService` into connection lifecycle, offline outbox, and history
   synchronization collaborators, preserving reconnect tests before moving
   code.
3. Split `messages.dart` parsing by protocol domain and replace duplicated
   Claude/Codex screen helpers with shared session components.

Each slice should reduce one responsibility at a time and retain a red-green
test demonstrating either the removed defect or the preserved compatibility
behavior.
