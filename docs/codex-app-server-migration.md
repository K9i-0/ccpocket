# Codex app-server Migration (Bridge)

## Goal

Enable real approval flow for Codex sessions in ccpocket by migrating from `@openai/codex-sdk` stream handling to `codex app-server` JSON-RPC.

## Scope

- Bridge server only (`packages/bridge`)
- Keep existing mobile WS protocol (`permission_request`, `approve`, `reject`) compatible
- No behavioral change for Claude sessions

## Design Decisions

1. Transport: `stdio://` via `codex app-server --listen stdio://`
2. Runtime wiring: keep `SessionManager` / `BridgeWebSocketServer` APIs stable
3. Approval mapping:
   - server request `item/commandExecution/requestApproval` -> WS `permission_request` (`toolName: Bash`)
   - server request `item/fileChange/requestApproval` -> WS `permission_request` (`toolName: FileChange`)
   - WS `approve`/`approve_always`/`reject` -> JSON-RPC response `{decision: accept|decline}`
4. Keep Codex start options parity where possible:
   - `approvalPolicy`, `sandboxMode`, `model`, `modelReasoningEffort`

## Implemented

- Replaced `packages/bridge/src/codex-process.ts` with app-server based process:
  - initialize handshake (`initialize` / `initialized`)
  - `thread/start` / `thread/resume`
  - `turn/start` / `turn/interrupt`
  - JSON-RPC request/response routing
  - approval request handling and pending state management
  - status propagation (`idle` / `running` / `waiting_approval`)
  - conversion from app-server item notifications to bridge `ServerMessage`
- Updated `packages/bridge/src/websocket.ts`:
  - Codex sessions now accept `approve`, `approve_always`, `reject`
- Updated `packages/bridge/src/session.ts`:
  - pending permission summary now works for both Claude and Codex processes
- Added/updated tests:
  - `packages/bridge/src/codex-process.test.ts`
  - `packages/bridge/src/websocket.test.ts` (expectation fix)

## Validation

Executed:

- `npx tsc --noEmit -p packages/bridge/tsconfig.json`
- `cd packages/bridge && npx vitest run src/codex-process.test.ts src/session.test.ts src/websocket.test.ts`

Result: passed.

Additional full-suite run:

- `cd packages/bridge && npx vitest run`

Result: one unrelated existing failure in `src/version.test.ts` (expected version mismatch).

## Follow-ups

1. Add optional backend flag (`CODEX_BACKEND=sdk|app-server`) if rollback path is required.
2. Add E2E scenario with a real Codex session and actual approval UI interaction on mobile.
3. Verify optional app-server fields (`webSearchMode`, network policy) against pinned Codex CLI version in production.
