# Reflex prototype: state/action introspection for the session list

Status: prototype (2026-11). One screen only. Based on Shopify's
[Reflex](https://shopify.engineering/reflex) write-up.

## Idea

Agents can write screens quickly but proving they work means building, booting
a simulator and driving pixels. Reflex makes each screen's **state** (JSON) and
**actions** (named operations with parameter schemas) directly addressable, so

- behavior tests drive the real logic headlessly, faking only the network, and
- agents inspect and operate a running app without widget keys or screenshots.

ccpocket already has most of the shape: Cubits are "actions in, state out", and
Flutter has no cross-platform duplication (Shopify's largest cost).

## What was added

| Piece | File | Notes |
| --- | --- | --- |
| Transport injection | `apps/mobile/lib/services/bridge_service.dart` | Optional `channelFactory` (default `WebSocketChannel.connect`). The only production change to the service. |
| Node contract | `apps/mobile/lib/core/reflex/reflex_node.dart` | `name`, `stateJson()`, `actions`, `dispatch(action, args)`. |
| Session list node | `apps/mobile/lib/features/session_list/state/session_list_reflex.dart` | Hand-written projection of `SessionListState` plus an action table mapped to `SessionListCubit` methods. |
| Registry + debug extensions | `apps/mobile/lib/core/reflex/reflex_registry.dart`, `apps/mobile/lib/services/reflex_extension.dart` | `ccpocket.reflex.tree` / `ccpocket.reflex.dispatch` Marionette extensions; not registered in release builds. |
| Fixture Bridge | `apps/mobile/test/reflex/fixture_bridge.dart` | In-memory socket pair (`package:web_socket/testing.dart`). Answers via handlers; records unhandled request types and the tests fail on them. |
| Driver | `apps/mobile/test/reflex/reflex_driver.dart` | `act` + `precondition` (poll until predicate, dump last state on timeout). |
| Behavior tests | `apps/mobile/test/reflex/session_list_behavior_test.dart` | 7 tests: initial load, provider filter, search debounce, named-only, pin persistence, `recent_sessions_failed`, unknown action. |

Unlike `MockBridgeService`/`ReplayBridgeService`, the tests run the real
`BridgeService` (handshake, request IDs, response correlation, error
acceptance) and the real Cubit; only the socket is fake.

## Using it at runtime (debug/profile)

```
call_custom_extension ccpocket.reflex.tree     {"node": "session_list"}
call_custom_extension ccpocket.reflex.dispatch {"node": "session_list",
  "action": "setProviderFilter", "args": "{\"provider\":\"codex\"}"}
```

`dispatch` returns the state immediately after the action; Bridge-backed
results arrive later, so poll `tree` until `isInitialLoading` is false.
Actions change real state (for example the provider filter is persisted), so
restore anything you change on a user's device.

## Measurements (this machine, 2026-11-06)

- Behavior tests: tens of ms per case once warm; 200–550 ms for cases that wait
  for the 300 ms search debounce or ran under load. The first case pays ~0.5 s
  of one-time warm-up.
- `flutter test` process startup dominates on this machine (~75 s wall-clock
  for any single file, including the existing `session_list_cubit_test.dart`),
  so batching Reflex tests into one invocation matters more than per-case cost.
- Runtime: against the test Bridge (8766) on the iPhone simulator,
  `reflex.tree` returned the session list state (20 sessions, roughly 5 KB of
  JSON including the action list) while `get_interactive_elements` returned 52
  layout-level elements for only the visible part of the screen, and
  `setProviderFilter` → Codex-only state matched the screenshot.

## Lessons

- **Fixtures drift.** The first error-path test failed because the fixture's
  `recent_sessions_failed` lacked `requestId`/`offset`, which the real Bridge
  sends and the client requires. Fixtures should be copied from
  `packages/bridge/src/websocket.ts` and ideally shared with Bridge tests later.
- **Unhandled-request check is useful.** Recording the client's baseline
  chatter first (`client_capabilities`, then `list_sessions`,
  `list_recent_sessions`, `list_project_history`, `list_projects` on refresh)
  made the strict check cheap to adopt.
- **State projection is a design choice.** The node exposes ids, names,
  provider, project and pinned flags; large lists still produce large JSON.
  Paging or summary fields may be needed for agent use.

## Not done / next steps

- Only `SessionListCubit` has a node. Chat (`ChatSessionCubit`) is the
  higher-value target: approval, streaming and queue behavior are where
  Marionette E2E is slowest.
- No headless CLI: agents use the Marionette extensions on a running app, and
  tests use `flutter test`.
- Nodes have no tree/focus model yet (which screen is in front).
