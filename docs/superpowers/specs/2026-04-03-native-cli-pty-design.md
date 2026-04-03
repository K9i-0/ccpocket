# Native CLI via PTY Passthrough — Design Spec

## Goal

Replace the bridge's SDK/subprocess process management with PTY-based spawning of native `claude` and `codex` CLI binaries. Terminal clients get the real native CLI experience (raw PTY passthrough). Phone clients get full structured events derived from an ANSI parser.

## Architecture

```
                         ┌─ pty_output (raw bytes) ──→ Terminal client (native CLI)
claude/codex (PTY) ──→ Bridge ─┤
                         └─ ANSI parser → structured events ──→ Phone client (app)
```

- **Terminal clients** (`clientType: "cli"`): receive `pty_output` messages containing raw PTY bytes, piped directly to `process.stdout`. Keystrokes sent back as `pty_input`.
- **Phone clients** (`clientType: "app"`): receive `assistant`, `tool_result`, `permission_request`, etc. — the same structured messages as today, now derived from the ANSI parser instead of the SDK.
- The `clientType` field in `attach_session` determines which stream a client receives.

## Bridge Process Changes

### IProcessTransport interface

Inspired by Remodex's `createCodexTransport()` abstraction, all process backends implement a common transport interface. This lets `SessionManager` treat PTY, SDK, and Codex processes uniformly.

```typescript
interface IProcessTransport extends EventEmitter {
  // Lifecycle
  start(opts: ProcessStartOptions): void;
  stop(): void;
  kill(): void;

  // Input
  write(data: string): void;           // raw input (PTY keystrokes or SDK text)
  sendInput(text: string): void;       // user message (adds newline for PTY)
  sendApproval(id: string): void;      // tool approval
  sendRejection(id: string, reason?: string): void;

  // Events emitted
  //   "message"  → ServerMessage (structured, for phone clients)
  //   "pty_data" → string (raw bytes, for terminal clients — PTY only)
  //   "status"   → string
  //   "exit"     → { code: number }
}
```

`PtyProcess`, `SdkProcess`, and `CodexProcess` all implement `IProcessTransport`. During migration, old classes stay in repo behind the same interface. `SessionManager.createProcess()` selects the backend based on provider + a `usePty` flag.

### PtyProcess class

A new `PtyProcess` class implements `IProcessTransport` using PTY-based spawning. Located at `packages/bridge/src/pty-process.ts`.

**Spawning:**
- Uses `node-pty` to create a pseudo-terminal
- Claude: `pty.spawn("claude", [projectPath, "--verbose"], { cwd: projectPath })`
- Codex: `pty.spawn("codex", [projectPath], { cwd: projectPath })`
- Resume: `claude --resume <sessionId>` / codex equivalent
- Permission mode flags passed through (e.g. `--dangerously-skip-permissions`)

**Data flow from PTY:**
- `pty.onData(rawBytes)` fires for all output
- Bridge simultaneously:
  1. Forwards raw bytes to all terminal clients as `pty_output`
  2. Feeds bytes into `AnsiParser` which emits structured events for phone clients

**Input to PTY (IProcessTransport methods):**
- `write(data)` → `pty.write(data)` — raw keystrokes from terminal client `pty_input`
- `sendInput(text)` → `pty.write(text + "\n")` — phone user message
- `sendApproval(id)` → `pty.write("y\n")` — phone tool approval
- `sendRejection(id)` → `pty.write("n\n")` — phone tool rejection

**Session lifecycle:**
- `PtyProcess` implements `IProcessTransport` (extends `EventEmitter`)
- Emits: `message` (structured events from parser), `pty_data` (raw bytes), `status`, `exit`
- `SessionManager` uses it the same way as current process classes via the shared interface

**Session ID capture:**
- When `claude` starts, it prints a session ID in its init output
- The ANSI parser captures this and stores it in `SessionInfo.claudeSessionId`
- This enables `claude --resume <id>` for subsequent attaches
- Same pattern for Codex thread IDs

**Auth:**
- The `claude`/`codex` binaries handle their own auth internally
- Bridge only needs to verify the binary exists on PATH before spawning
- Auth failures appear as native error messages in the PTY output

### What gets replaced

- `SdkProcess` (sdk-process.ts) — replaced by PtyProcess for Claude
- `CodexProcess` (codex-process.ts) — replaced by PtyProcess for Codex
- `@anthropic-ai/claude-agent-sdk` dependency — no longer needed

Old files stay in repo during migration for rollback safety. Remove once PTY approach is stable.

## ANSI Parser

Located at `packages/bridge/src/ansi-parser.ts`. Sits between PTY output and phone clients. Strips ANSI escape codes, detects patterns, emits structured `ServerMessage` objects.

### Pattern detection

| PTY pattern | Structured event |
|---|---|
| `⏺` followed by text | `assistant` (text content block) |
| `⎿ ToolName /path` | `assistant` (tool_use content block) |
| Indented text after tool call | `tool_result` |
| `Allow?` / `[y]es [n]o` | `permission_request` |
| Streaming characters | `stream_delta` |
| `Cost: $X.XX · Duration: Xs` | `result` |
| Spinner / status text | `status` |

### State machine

The parser maintains state and transitions based on detected patterns:

- `idle` — waiting for content
- `streaming_text` — accumulating assistant text (emit `stream_delta`)
- `tool_call` — detected tool use header, collecting details
- `tool_result` — collecting indented tool output
- `permission_prompt` — detected Allow? prompt, waiting for resolution

State machine is more reliable than line-by-line regex since CLI output uses multi-line blocks.

### Provider profiles

Claude and Codex have different output formatting. Each provider gets its own parser profile (pattern set + state transitions).

### Graceful degradation

If the parser cannot identify a pattern, it emits a generic `assistant` text message with the raw content. The phone always sees something — worst case it's unstructured text rather than a nicely formatted tool call.

## New Message Types

### Client → Server

```typescript
| { type: "pty_input"; sessionId: string; data: string }
```

Raw keystrokes from terminal client. Bridge writes directly to PTY stdin.

### Server → Client

```typescript
| { type: "pty_output"; sessionId: string; data: string }
| { type: "pty_resize"; sessionId: string; cols: number; rows: number }
```

`pty_output` carries raw PTY bytes as a UTF-8 string. `pty_resize` propagates terminal size changes so the CLI layout adapts.

## CLI Session Mode Changes

When the CLI enters a session, it switches from Ink to **raw terminal mode**:

1. Exit Ink rendering
2. `process.stdin.setRawMode(true)` — capture every keystroke
3. `process.stdin.on("data")` → send as `pty_input` to bridge
4. On `pty_output` message → `process.stdout.write(data)`
5. Send terminal dimensions on attach, listen for resize events → send `pty_resize`
6. On Ctrl+D (detach) → restore terminal state, return to Ink home screen

The Ink-based home screen, new session screen, and bridge discovery are unchanged. Only the **session view** changes from Ink rendering to raw PTY passthrough.

## Broadcasting Logic

`broadcastSessionMessage` in websocket.ts routes based on `clientType`:

- `"cli"` clients → receive `pty_output` (raw PTY bytes)
- `"app"` clients → receive structured events (from ANSI parser)
- Multiple terminal clients all get the same PTY stream (shared terminal view)
- Multiple phone clients all get the same structured events

## Reconnect Replay Buffer

Inspired by Remodex's bounded outbound buffer with sequence-based replay. When a phone client disconnects and reconnects (common on mobile networks), it needs to catch up on missed structured events without restarting the session.

### Design

Each session maintains a `ReplayBuffer` of structured events (not raw PTY bytes — those are for terminal clients only).

```typescript
interface ReplayBuffer {
  events: Array<{ seq: number; msg: ServerMessage; timestamp: number }>;
  nextSeq: number;
}
```

**Bounds:** 500 messages or 5MB total payload, whichever is hit first. Oldest events evicted on overflow (ring buffer).

**Write path:** Every structured event emitted by the ANSI parser is appended to the buffer with an incrementing sequence number before being broadcast to phone clients.

**Read path (reconnect):** When a phone client sends `attach_session`, it includes an optional `lastSeq` field:

```typescript
| { type: "attach_session"; sessionId: string; clientType: "app"; lastSeq?: number }
```

- If `lastSeq` is provided: bridge replays all events with `seq > lastSeq`
- If `lastSeq` is omitted (first connect): bridge sends full buffer contents as `history`
- If `lastSeq` is older than the buffer's oldest entry: bridge sends full buffer + a `gap` flag so the app knows events were lost

**Terminal clients don't use the replay buffer.** They get the live PTY screen state via `pty_output` — the terminal itself is the replay mechanism (scrollback).

### Why not replay raw PTY bytes?

Raw PTY bytes include ANSI cursor positioning, screen clears, and partial redraws. Replaying them would produce garbled output. Structured events are idempotent and can be safely replayed to reconstruct the phone's conversation view.

## File Structure

### New files
- `packages/bridge/src/process-transport.ts` — `IProcessTransport` interface definition
- `packages/bridge/src/pty-process.ts` — PtyProcess class (implements IProcessTransport)
- `packages/bridge/src/ansi-parser.ts` — ANSI parser state machine
- `packages/bridge/src/ansi-parser.test.ts` — Parser tests with captured PTY output samples
- `packages/bridge/src/replay-buffer.ts` — Bounded ring buffer with sequence tracking
- `packages/bridge/src/replay-buffer.test.ts` — Replay buffer tests (overflow, gap detection, replay from seq)

### Modified files
- `packages/bridge/src/session.ts` — Use PtyProcess via IProcessTransport; integrate ReplayBuffer per session
- `packages/bridge/src/websocket.ts` — Handle `pty_input`/`pty_resize`, route by client type, seq-based replay on attach
- `packages/bridge/src/parser.ts` — Add new message types (pty_input, pty_output, pty_resize, attach_session with lastSeq)
- `packages/bridge/src/sdk-process.ts` — Implement IProcessTransport interface (backward compat)
- `packages/bridge/src/codex-process.ts` — Implement IProcessTransport interface (backward compat)
- `packages/cli/src/screens/session.tsx` — Replace Ink rendering with raw PTY passthrough

### Unchanged
- `packages/cli/src/screens/home.tsx` — stays Ink
- `packages/cli/src/screens/new-session.tsx` — stays Ink
- Phone app — unchanged, receives same structured events

### Dependencies
- Add `node-pty` to bridge package
- `@anthropic-ai/claude-agent-sdk` removable after migration verified

## Maintenance

The ANSI parser depends on `claude`/`codex` CLI output conventions. When these CLIs update their output format:

1. Capture new PTY output samples
2. Update parser patterns and tests
3. The terminal client is unaffected (raw passthrough doesn't care about format)
4. Only the phone-side structured events need parser updates

## Patterns Borrowed from Remodex

[Remodex](https://github.com/Emanuele-web04/remodex) is an open-source iPhone remote for Codex CLI. While it uses structured JSON-RPC (not PTY), three architectural patterns transfer well:

| Remodex pattern | Our adaptation |
|---|---|
| `createCodexTransport()` — unified interface with `send/onMessage/onClose/shutdown` for both spawn and WebSocket backends | `IProcessTransport` — common interface for `PtyProcess`, `SdkProcess`, `CodexProcess`. SessionManager is backend-agnostic. |
| Bounded outbound buffer (500 msg / 10MB) + monotonic sequence counters for reconnect replay | `ReplayBuffer` — structured event ring buffer per session. Phone sends `lastSeq` on re-attach, bridge replays missed events. |
| Handler chain routing — bridge intercepts its own commands, forwards rest to Codex | `broadcastSessionMessage` routes by `clientType` — raw PTY bytes to `cli`, structured events to `app`. Bridge-level messages (list, stop, rename) handled before reaching the process. |

**What Remodex doesn't solve** (our unique challenges):
- ANSI parsing (Remodex's Codex speaks JSON-RPC natively)
- Dual-mode output (Remodex has one client type)
- PTY lifecycle management (resize, signal forwarding, flow control)
- Terminal state reconstruction for mid-session phone connects

## Success Criteria

1. `ccpocket start ~/project` → native `claude` CLI appears in terminal, identical to running `claude` directly
2. Phone app shows the same session with full structured events (tool calls, approvals, text)
3. Phone can send input and approve tools — appears in the native CLI as if typed locally
4. `ccpocket attach <id>` from computer → native CLI attaches to phone-started session
5. Detach (Ctrl+D) returns to Ink home screen cleanly, terminal state restored
6. Multiple terminal clients see the same PTY output (shared view)
