# Sidecar PTY — CLI Terminal View for CC Pocket

## Problem

CC Pocket sessions are managed by SDK processes (SdkProcess for Claude, CodexProcess for Codex) that emit structured events for the phone app. Terminal users want the native CLI experience (colors, Ink TUI, status bar, keyboard shortcuts) — but spawning the CLI via PTY as the primary process breaks the phone experience because the ANSI parser can't reliably extract structured events from the full TUI output.

## Solution: Sidecar PTY

The SDK process remains the primary session owner. When a CLI terminal client attaches, a **sidecar PtyProcess** spawns alongside using `claude --resume <sessionId>` or `codex --thread <threadId>`. The sidecar is a secondary display process — it shows the native TUI to CLI clients while the SDK continues providing structured events to phone clients.

```
                 ┌─────────────────────────────────────────────┐
                 │              SessionManager                 │
                 │                                             │
   Phone ──WS──▶│  SdkProcess / CodexProcess  (always primary)│
                 │      │ emits structured ServerMessages       │
                 │      │    → phone gets clean events          │
                 │      │    → ReplayBuffer for reconnect       │
                 │      │                                       │
                 │      │ claudeSessionId / threadId             │
                 │      ▼                                       │
   CLI ────WS──▶│  PtyProcess (sidecar, on-demand)             │
                 │      spawns: claude --resume <id>            │
                 │           or: codex --thread <id>            │
                 │      → CLI gets raw PTY bytes                │
                 │      → destroyed when CLI detaches           │
                 └─────────────────────────────────────────────┘
```

## Sidecar PTY Lifecycle

### Spawn

When a CLI client sends `attach_session` with `clientType: "cli"` and the session has no sidecar PTY:

1. Check that `claudeSessionId` (Claude) or `threadId` (Codex) is available
2. Spawn `PtyProcess` with `claude --resume <id>` or `codex --thread <id>`
3. Wire `pty_data` events to broadcast raw bytes to CLI clients
4. Wire `exit` event to clean up the sidecar

If the session ID is not yet available (very early startup), buffer the attach request and spawn the sidecar once the SDK emits the session ID.

### Destroy

The sidecar PTY is destroyed when:

- The last CLI client detaches from the session
- The last CLI client's WebSocket disconnects
- The session itself is destroyed
- The sidecar PTY process exits on its own (e.g., user types `/exit` in CLI)

### Multiple CLI Clients

If a second CLI client attaches to the same session, it reuses the existing sidecar PTY. Both receive the same raw bytes. The sidecar is destroyed only when the last CLI client leaves.

## Message Routing

### Server → Client

| Event source | App (phone) client | CLI client |
|---|---|---|
| SDK structured events (`assistant`, `tool_result`, `permission_request`, `stream_delta`, etc.) | Receives | Does NOT receive |
| Sidecar PTY `pty_data` (raw terminal bytes) | Does NOT receive | Receives |
| Meta messages (`session_clients`, `error`, `status`) | Receives | Receives |

### Client → Server

| Input source | Handler |
|---|---|
| Phone `input` | SdkProcess/CodexProcess `.sendInput()` (unchanged) |
| Phone `approve`/`reject` | SdkProcess/CodexProcess `.sendApproval()`/`.sendRejection()` (unchanged) |
| CLI `pty_input` | Sidecar PtyProcess `.write()` (raw bytes to `claude --resume` PTY) |
| CLI `pty_resize` | Sidecar PtyProcess `.resize()` |

## Changes from Current PTY Branch

### Keep

- `IProcessTransport` interface (`process-transport.ts`)
- `PtyProcess` class (`pty-process.ts`) — becomes the sidecar
- `ReplayBuffer` + tests (`replay-buffer.ts`)
- CLI package (`packages/cli/`) — `pty-session.ts`, `bridge-client.ts`, `app.tsx`, `index.ts`, screens
- `pty_input`, `pty_output`, `pty_resize` message types in `parser.ts`
- Dual routing in `broadcastSessionMessage`
- `node-pty` dependency

### Remove

- `AnsiParser` + `ansi-parser.ts` + `ansi-parser.test.ts` — not needed, SDK provides structured events
- `usePty = true` toggle in `session.ts` — sessions always use SdkProcess/CodexProcess
- ANSI parser wiring in `PtyProcess`

### Modify

| File | Change |
|---|---|
| `session.ts` | Remove `usePty` toggle. Add `ptyProcess: PtyProcess \| null` to `SessionInfo`. Add `spawnSidecarPty()` and `destroySidecarPty()` methods. Route sidecar `pty_data` through `onMessage`. Clean up sidecar in `destroy()`. |
| `websocket.ts` | `attach_session` with `clientType: "cli"` calls `spawnSidecarPty()`. Detach/disconnect destroys sidecar when last CLI client leaves. `pty_input`/`pty_resize` route to `session.ptyProcess` instead of `session.process`. |
| `pty-process.ts` | Remove ANSI parser import and wiring. Simplify to emit only `pty_data` and lifecycle events (`status`, `exit`). Spawn with `--resume`/`--thread` from an existing session ID. |

### Untouched

- `sdk-process.ts`, `codex-process.ts` — no changes
- `replay-buffer.ts` — no changes
- All Flutter/mobile code — no changes
- CLI package screens/components — no changes

## Error Handling

**Sidecar fails to spawn:** Send `error` message to CLI client. SDK process and phone are unaffected. CLI client can retry by reattaching.

**Sidecar exits unexpectedly:** Clean up sidecar, notify CLI clients. SDK process continues. CLI returns to Ink home screen.

**Session destroyed while sidecar active:** `destroy()` kills both SDK process and sidecar PTY.

**CLI attaches before session ID available:** Buffer the attach request. Listen for SDK's `system` event with `sessionId`. Spawn sidecar once available. If SDK errors out, send error to CLI client.

**Concurrent input from phone and CLI:** Not prevented. Claude/Codex handle concurrent inputs gracefully (last-write-wins). Low real-world risk — primary usage is one device at a time.

**node-pty compatibility:** Requires `node-gyp rebuild` for Node v25.9.0+. Document the requirement or add a postinstall script.
