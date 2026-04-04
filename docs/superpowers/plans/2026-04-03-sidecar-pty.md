# Sidecar PTY Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the SDK process the primary session owner (structured events for phone), with an on-demand sidecar PTY that spawns when a CLI client attaches (native terminal experience).

**Architecture:** Sessions always use SdkProcess/CodexProcess. When a CLI client attaches, `SessionManager.spawnSidecarPty()` launches `claude --resume <id>` or `codex --thread <id>` in a PTY. The sidecar emits raw bytes to CLI clients. When the last CLI client detaches, the sidecar is destroyed.

**Tech Stack:** TypeScript, node-pty, vitest

**Spec:** `docs/superpowers/specs/2026-04-03-sidecar-pty-design.md`

---

## File Structure

| File | Role | Action |
|---|---|---|
| `packages/bridge/src/pty-process.ts` | Sidecar PTY — spawns native CLI for display | Modify (remove ANSI parser, simplify) |
| `packages/bridge/src/pty-process.test.ts` | Tests for simplified PtyProcess | Modify (update tests) |
| `packages/bridge/src/session.ts` | SessionManager — add sidecar lifecycle | Modify |
| `packages/bridge/src/session.test.ts` | Tests for sidecar spawn/destroy | Modify (add sidecar tests) |
| `packages/bridge/src/websocket.ts` | Route pty_input/resize to sidecar, trigger spawn/destroy | Modify |
| `packages/bridge/src/websocket.test.ts` | Tests for sidecar routing | Modify (add sidecar tests) |
| `packages/bridge/src/ansi-parser.ts` | ANSI parser (no longer needed) | Delete |
| `packages/bridge/src/ansi-parser.test.ts` | ANSI parser tests | Delete |
| `packages/bridge/src/process-transport.ts` | IProcessTransport interface | No change |
| `packages/bridge/src/replay-buffer.ts` | ReplayBuffer | No change |
| `packages/cli/src/*` | CLI terminal client | No change |

---

### Task 1: Remove ANSI parser and simplify PtyProcess

PtyProcess currently imports AnsiParser, wires it up in `start()`, and emits structured `message` events from parsed output. As a sidecar, it only needs to emit raw `pty_data` bytes and lifecycle events. Remove the ANSI parser dependency and simplify.

**Files:**
- Delete: `packages/bridge/src/ansi-parser.ts`
- Delete: `packages/bridge/src/ansi-parser.test.ts`
- Modify: `packages/bridge/src/pty-process.ts`
- Modify: `packages/bridge/src/pty-process.test.ts`

- [ ] **Step 1: Delete the ANSI parser files**

```bash
git rm packages/bridge/src/ansi-parser.ts packages/bridge/src/ansi-parser.test.ts
```

- [ ] **Step 2: Simplify PtyProcess — remove ANSI parser wiring**

Replace the full contents of `packages/bridge/src/pty-process.ts` with:

```typescript
import { EventEmitter } from "node:events";
import { execFileSync } from "node:child_process";
import * as pty from "node-pty";
import type { IPty } from "node-pty";
import type { ProcessStartOptions } from "./process-transport.js";
import type { ProcessStatus } from "./parser.js";

/**
 * Sidecar PTY process — spawns the native CLI binary (`claude` or `codex`)
 * for terminal display. Emits raw `pty_data` bytes for CLI clients.
 *
 * This is NOT the primary session process. SdkProcess/CodexProcess own the
 * session and emit structured events for phone clients. PtyProcess is a
 * secondary display process that attaches to the same conversation via
 * `claude --resume` or `codex --thread`.
 *
 * Events emitted:
 * - "pty_data" (data: string)           — raw terminal bytes
 * - "status"   (status: ProcessStatus)  — lifecycle status changes
 * - "exit"     (code: number)           — process exited
 */
export class PtyProcess extends EventEmitter {
  private ptyProc: IPty | null = null;
  private _status: ProcessStatus = "idle";
  private dataDisposable: { dispose(): void } | null = null;
  private exitDisposable: { dispose(): void } | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  /**
   * Spawn the native CLI as a sidecar PTY.
   * For Claude: `claude --resume <sessionId> <projectPath> --verbose`
   * For Codex:  `codex --thread <sessionId> <projectPath>`
   */
  start(opts: ProcessStartOptions): void {
    const { projectPath, provider, sessionId } = opts;

    if (!sessionId) {
      throw new Error("Sidecar PTY requires a sessionId (--resume/--thread)");
    }

    const binaryName = provider === "codex" ? "codex" : "claude";
    let binary: string;
    try {
      binary = execFileSync("which", [binaryName], { encoding: "utf-8" }).trim();
    } catch {
      binary = binaryName;
    }

    const args = this.buildArgs(provider, projectPath, sessionId, opts.permissionMode);
    console.log(`[pty] Spawning sidecar: ${binary} ${args.join(" ")}`);

    this._status = "starting";
    this.emit("status", this._status);

    this.ptyProc = pty.spawn(binary, args, {
      name: "xterm-256color",
      cols: opts.cols ?? 80,
      rows: opts.rows ?? 24,
      cwd: projectPath,
      env: process.env as Record<string, string>,
    });

    this.dataDisposable = this.ptyProc.onData((data: string) => {
      this.emit("pty_data", data);
    });

    this.exitDisposable = this.ptyProc.onExit(
      ({ exitCode }: { exitCode: number; signal?: number }) => {
        this._status = "idle";
        this.emit("status", this._status);
        this.emit("exit", exitCode);
        this.cleanup();
      },
    );

    this._status = "running";
    this.emit("status", this._status);
  }

  /** Write raw bytes to the PTY (keystrokes from CLI client). */
  write(data: string): void {
    this.ptyProc?.write(data);
  }

  /** Resize the PTY terminal. */
  resize(cols: number, rows: number): void {
    this.ptyProc?.resize(cols, rows);
  }

  /** Graceful stop (SIGTERM). */
  stop(): void {
    this.ptyProc?.kill("SIGTERM");
  }

  /** Forceful kill (SIGKILL). */
  kill(): void {
    this.ptyProc?.kill("SIGKILL");
  }

  private buildArgs(
    provider: string,
    projectPath: string,
    sessionId: string,
    permissionMode?: string,
  ): string[] {
    if (provider === "codex") {
      return [projectPath, "--thread", sessionId];
    }
    const args = [projectPath, "--verbose", "--resume", sessionId];
    if (permissionMode === "bypassPermissions") {
      args.push("--dangerously-skip-permissions");
    }
    return args;
  }

  private cleanup(): void {
    this.dataDisposable?.dispose();
    this.exitDisposable?.dispose();
    this.dataDisposable = null;
    this.exitDisposable = null;
    this.ptyProc = null;
  }
}
```

Key changes from the current PtyProcess:
- No longer implements `IProcessTransport` (it's a sidecar, not a session process)
- Removed AnsiParser import and all `message` event emissions
- Removed `sendInput`, `sendApproval`, `sendRejection`, `interrupt`, `isPty`, `isWaitingForInput`, `sessionId` — the sidecar doesn't need SDK-like methods
- `start()` now requires `sessionId` (always resuming an existing session)
- Added optional `cols`/`rows` in opts for initial terminal size
- Simplified to only: `write()`, `resize()`, `stop()`, `kill()`, lifecycle events

- [ ] **Step 3: Update ProcessStartOptions to include cols/rows**

In `packages/bridge/src/process-transport.ts`, add `cols` and `rows` to the interface:

```typescript
export interface ProcessStartOptions {
  projectPath: string;
  provider: Provider;
  sessionId?: string;            // Resume existing session
  permissionMode?: PermissionMode;
  model?: string;
  initialInput?: string;         // Auto-send on start
  cols?: number;                 // Initial terminal columns (PTY sidecar)
  rows?: number;                 // Initial terminal rows (PTY sidecar)
  [key: string]: unknown;        // Provider-specific passthrough
}
```

- [ ] **Step 4: Update PtyProcess tests**

Replace the contents of `packages/bridge/src/pty-process.test.ts` with:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";

const mockPty = {
  onData: vi.fn(),
  onExit: vi.fn(),
  write: vi.fn(),
  resize: vi.fn(),
  kill: vi.fn(),
  pid: 12345,
  cols: 80,
  rows: 24,
  process: "claude",
};

vi.mock("node-pty", () => ({
  spawn: vi.fn(() => mockPty),
}));

import { PtyProcess } from "./pty-process.js";
import * as pty from "node-pty";

describe("PtyProcess (sidecar)", () => {
  let proc: PtyProcess;
  let dataHandler: (data: string) => void;
  let exitHandler: (e: { exitCode: number; signal?: number }) => void;

  beforeEach(() => {
    vi.clearAllMocks();
    mockPty.onData.mockImplementation((cb: (data: string) => void) => {
      dataHandler = cb;
      return { dispose: vi.fn() };
    });
    mockPty.onExit.mockImplementation(
      (cb: (e: { exitCode: number; signal?: number }) => void) => {
        exitHandler = cb;
        return { dispose: vi.fn() };
      },
    );
    proc = new PtyProcess();
  });

  it("requires sessionId to start", () => {
    expect(() =>
      proc.start({ projectPath: "/tmp", provider: "claude" }),
    ).toThrow("Sidecar PTY requires a sessionId");
  });

  it("spawns claude with --resume for claude provider", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "claude",
      sessionId: "abc-123",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      ["/tmp/project", "--verbose", "--resume", "abc-123"],
      expect.objectContaining({ cols: 80, rows: 24 }),
    );
  });

  it("spawns codex with --thread for codex provider", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "codex",
      sessionId: "thread-456",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      ["/tmp/project", "--thread", "thread-456"],
      expect.objectContaining({ cols: 80, rows: 24 }),
    );
  });

  it("uses custom cols/rows when provided", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
      cols: 120,
      rows: 40,
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(Array),
      expect.objectContaining({ cols: 120, rows: 40 }),
    );
  });

  it("emits pty_data on data from PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const handler = vi.fn();
    proc.on("pty_data", handler);
    dataHandler("hello world");

    expect(handler).toHaveBeenCalledWith("hello world");
  });

  it("does NOT emit message events (no ANSI parser)", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const handler = vi.fn();
    proc.on("message", handler);
    dataHandler("⏺ some assistant text\r\n");

    expect(handler).not.toHaveBeenCalled();
  });

  it("emits status and exit on process exit", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const statuses: string[] = [];
    proc.on("status", (s) => statuses.push(s));
    const exitHandler2 = vi.fn();
    proc.on("exit", exitHandler2);

    exitHandler({ exitCode: 0 });

    expect(statuses).toContain("idle");
    expect(exitHandler2).toHaveBeenCalledWith(0);
  });

  it("write() sends raw bytes to PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.write("hello");
    expect(mockPty.write).toHaveBeenCalledWith("hello");
  });

  it("resize() resizes the PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.resize(120, 40);
    expect(mockPty.resize).toHaveBeenCalledWith(120, 40);
  });

  it("stop() sends SIGTERM", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.stop();
    expect(mockPty.kill).toHaveBeenCalledWith("SIGTERM");
  });

  it("includes --dangerously-skip-permissions for bypassPermissions", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "claude",
      sessionId: "abc",
      permissionMode: "bypassPermissions",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      expect.arrayContaining(["--dangerously-skip-permissions"]),
      expect.any(Object),
    );
  });
});
```

- [ ] **Step 5: Run tests to verify**

```bash
npx vitest run packages/bridge/src/pty-process.test.ts
```

Expected: All 9 tests PASS.

- [ ] **Step 6: Run full test suite + type check**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
npx vitest run
```

Expected: Type check passes. Some tests in `session.test.ts` and `websocket.test.ts` may fail because they reference PtyProcess as an IProcessTransport — those will be fixed in Task 2.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor(bridge): simplify PtyProcess to sidecar role, remove ANSI parser"
```

---

### Task 2: Revert session.ts to SDK-primary, add sidecar support

Remove the `usePty = true` toggle so sessions always use SdkProcess/CodexProcess. Add `ptyProcess` field to `SessionInfo` and `spawnSidecarPty()` / `destroySidecarPty()` methods.

**Files:**
- Modify: `packages/bridge/src/session.ts`

- [ ] **Step 1: Add `ptyProcess` to SessionInfo**

In `packages/bridge/src/session.ts`, add the field to the `SessionInfo` interface (after the `process` field, around line 41):

```typescript
export interface SessionInfo {
  id: string;
  process: IProcessTransport;
  /** On-demand sidecar PTY for CLI terminal clients. Null when no CLI is attached. */
  ptyProcess: PtyProcess | null;
  replayBuffer: ReplayBuffer;
  // ... rest unchanged
}
```

- [ ] **Step 2: Remove `usePty` toggle, always use SDK/Codex process**

In the `create()` method (around lines 191-202), replace the process creation block:

```typescript
    // Old code:
    // const usePty = true; // Toggle for migration rollback
    // let proc: IProcessTransport;
    // if (usePty) {
    //   proc = new PtyProcess();
    // } else if (effectiveProvider === "codex") {

    // New code:
    let proc: IProcessTransport;
    if (effectiveProvider === "codex") {
      proc = new CodexProcess();
    } else {
      proc = new SdkProcess();
    }
```

- [ ] **Step 3: Initialize ptyProcess as null in session creation**

In the session object creation (around line 242), add `ptyProcess: null`:

```typescript
    const session: SessionInfo = {
      id,
      process: proc,
      ptyProcess: null,
      replayBuffer,
      // ... rest unchanged
    };
```

- [ ] **Step 4: Remove PtyProcess start branch, restore SDK/Codex start**

Replace the process start block (around lines 562-573):

```typescript
    // Old code:
    // if (proc instanceof PtyProcess) {
    //   proc.start({...});
    // } else if (effectiveProvider === "codex") {

    // New code — always SDK or Codex:
    if (effectiveProvider === "codex") {
      (proc as CodexProcess).start(effectiveCwd, codexOptions);
    } else {
      (proc as SdkProcess).start(effectiveCwd, options);
    }
```

- [ ] **Step 5: Remove the proc.on("pty_data") handler**

Delete the `pty_data` handler that was added for PtyProcess (around lines 275-277):

```typescript
    // DELETE these lines:
    // proc.on("pty_data", (data: string) => {
    //   this.onMessage(id, { type: "pty_output", sessionId: id, data });
    // });
```

- [ ] **Step 6: Add spawnSidecarPty() method**

Add this method to the `SessionManager` class (before `destroy()`):

```typescript
  /**
   * Spawn a sidecar PTY for CLI terminal display.
   * The PTY attaches to the existing session via --resume/--thread.
   * Returns the PtyProcess, or null if already running or session ID unavailable.
   */
  spawnSidecarPty(
    sessionId: string,
    cols?: number,
    rows?: number,
  ): PtyProcess | null {
    const session = this.sessions.get(sessionId);
    if (!session) return null;

    // Already has a sidecar
    if (session.ptyProcess) return session.ptyProcess;

    // Need the native session ID to --resume/--thread
    const nativeSessionId = session.claudeSessionId;
    if (!nativeSessionId) {
      console.log(`[session] Cannot spawn sidecar PTY: no session ID yet for ${sessionId}`);
      return null;
    }

    const effectiveCwd = session.worktreePath ?? session.projectPath;
    const ptyProc = new PtyProcess();

    // Forward raw PTY bytes through broadcast
    ptyProc.on("pty_data", (data: string) => {
      this.onMessage(sessionId, { type: "pty_output", sessionId, data } as any);
    });

    // Clean up sidecar on exit
    ptyProc.on("exit", () => {
      console.log(`[session] Sidecar PTY exited for session ${sessionId}`);
      if (session.ptyProcess === ptyProc) {
        session.ptyProcess = null;
      }
    });

    try {
      ptyProc.start({
        projectPath: effectiveCwd,
        provider: session.provider,
        sessionId: nativeSessionId,
        permissionMode: session.permissionMode,
        cols,
        rows,
      });
    } catch (err) {
      console.error(`[session] Failed to spawn sidecar PTY:`, err);
      ptyProc.removeAllListeners();
      return null;
    }

    session.ptyProcess = ptyProc;
    console.log(`[session] Spawned sidecar PTY for session ${sessionId} (native: ${nativeSessionId})`);
    return ptyProc;
  }

  /**
   * Destroy the sidecar PTY for a session.
   * Called when the last CLI client detaches.
   */
  destroySidecarPty(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (!session?.ptyProcess) return;

    session.ptyProcess.stop();
    session.ptyProcess.removeAllListeners();
    session.ptyProcess = null;
    console.log(`[session] Destroyed sidecar PTY for session ${sessionId}`);
  }
```

- [ ] **Step 7: Update destroy() to also clean up sidecar**

In the `destroy()` method (around line 1004):

```typescript
  destroy(id: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    // Destroy sidecar PTY if present
    if (session.ptyProcess) {
      session.ptyProcess.stop();
      session.ptyProcess.removeAllListeners();
      session.ptyProcess = null;
    }
    session.process.stop();
    session.process.removeAllListeners();
    this.sessions.delete(id);
    console.log(`[session] Destroyed session ${id}`);
    return true;
  }
```

- [ ] **Step 8: Remove PtyProcess import if no longer used in create()**

At the top of `session.ts`, the import `import { PtyProcess } from "./pty-process.js";` is still needed for `spawnSidecarPty()`. Keep it.

- [ ] **Step 9: Run type check**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
```

Expected: May have errors in websocket.ts referencing `session.process.isPty` — those are fixed in Task 3.

- [ ] **Step 10: Commit**

```bash
git add packages/bridge/src/session.ts
git commit -m "refactor(bridge): revert to SDK-primary sessions, add sidecar PTY spawn/destroy"
```

---

### Task 3: Update websocket.ts — route pty_input/resize to sidecar

Change `pty_input` and `pty_resize` handlers to target `session.ptyProcess` instead of `session.process`. Trigger sidecar spawn on CLI attach, destroy on CLI detach.

**Files:**
- Modify: `packages/bridge/src/websocket.ts`

- [ ] **Step 1: Update `attach_session` to spawn sidecar for CLI clients**

In the `attach_session` case (around line 3303), after `this.attachClient(...)` add sidecar spawn logic:

```typescript
      case "attach_session": {
        const session = this.sessionManager.get(msg.sessionId);
        if (!session) {
          this.send(ws, {
            type: "error",
            message: `Session ${msg.sessionId} not found`,
          });
          break;
        }

        this.attachClient(msg.sessionId, ws, msg.clientType);

        // Spawn sidecar PTY for CLI clients
        if (msg.clientType === "cli") {
          const cols = typeof msg.cols === "number" ? msg.cols : undefined;
          const rows = typeof msg.rows === "number" ? msg.rows : undefined;
          const ptyProc = this.sessionManager.spawnSidecarPty(
            msg.sessionId,
            cols,
            rows,
          );
          if (!ptyProc && !session.ptyProcess) {
            // Session ID not available yet — will spawn when it arrives
            // (handled by a listener added below)
            if (!session.claudeSessionId) {
              this.deferSidecarSpawn(msg.sessionId, ws, cols, rows);
            } else {
              this.send(ws, {
                type: "error",
                message: "Failed to start CLI view",
              });
            }
          }
        }

        // Send session_created so the client has full session metadata
        const createdMsg = this.buildSessionCreatedMessage({
          sessionId: msg.sessionId,
          provider: session.provider,
          projectPath: session.projectPath,
          session,
        });
        this.send(ws, createdMsg);

        // ... rest of attach_session unchanged (replay, history, etc.)
```

- [ ] **Step 2: Add deferSidecarSpawn helper**

Add a private method to the WebSocketServer class:

```typescript
  /**
   * Defer sidecar PTY spawn until the SDK process emits a session ID.
   * Used when a CLI client attaches before the session ID is available.
   */
  private deferSidecarSpawn(
    sessionId: string,
    ws: WebSocket,
    cols?: number,
    rows?: number,
  ): void {
    const session = this.sessionManager.get(sessionId);
    if (!session) return;

    console.log(`[ws] Deferring sidecar PTY spawn for ${sessionId} (waiting for session ID)`);

    const onMessage = (msg: Record<string, unknown>) => {
      if (
        (msg.type === "system" || msg.type === "result") &&
        "sessionId" in msg &&
        msg.sessionId
      ) {
        session.process.off("message", onMessage);
        // Now we have a session ID — spawn the sidecar
        const ptyProc = this.sessionManager.spawnSidecarPty(sessionId, cols, rows);
        if (!ptyProc) {
          this.send(ws, { type: "error", message: "Failed to start CLI view" });
        }
      }
    };

    session.process.on("message", onMessage);

    // Clean up if the client disconnects before we get a session ID
    ws.once("close", () => {
      session.process.off("message", onMessage);
    });
  }
```

- [ ] **Step 3: Update `pty_input` to route to sidecar**

Replace the `pty_input` case (around line 3359):

```typescript
      case "pty_input": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "Session not found" });
          return;
        }
        if (!session.ptyProcess) {
          this.send(ws, { type: "error", message: "No CLI view active for this session" });
          return;
        }
        this.attachClient(session.id, ws, "cli");
        session.ptyProcess.write(msg.data);
        break;
      }
```

- [ ] **Step 4: Update `pty_resize` to route to sidecar**

Replace the `pty_resize` case (around line 3375):

```typescript
      case "pty_resize": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "Session not found" });
          return;
        }
        if (session.ptyProcess) {
          session.ptyProcess.resize(msg.cols, msg.rows);
        }
        break;
      }
```

- [ ] **Step 5: Destroy sidecar when last CLI client detaches**

In the `detachClient()` method (around line 3585), after removing the client from the map, check if any CLI clients remain:

```typescript
  private detachClient(sessionId: string, ws: WebSocket): void {
    const clients = this.sessionClients.get(sessionId);
    if (!clients) return;

    const info = clients.get(ws);
    if (!info) return;

    clients.delete(ws);

    // Notify remaining clients
    const leftMsg = JSON.stringify({
      type: "client_left",
      sessionId,
      client: { clientId: info.clientId, clientType: info.clientType },
    });
    for (const [otherWs] of clients) {
      if (otherWs.readyState === WebSocket.OPEN) {
        otherWs.send(leftMsg);
      }
    }

    // If a CLI client left, check if any CLI clients remain
    if (info.clientType === "cli") {
      const hasCliClients = [...clients.values()].some(
        (c) => c.clientType === "cli",
      );
      if (!hasCliClients) {
        this.sessionManager.destroySidecarPty(sessionId);
      }
    }

    // Clean up empty session client maps
    if (clients.size === 0) {
      this.sessionClients.delete(sessionId);
    }
  }
```

- [ ] **Step 6: Update broadcastSessionMessage — pty_output comes from sidecar now**

The `broadcastSessionMessage` routing logic (around line 3652) should stay the same — it already routes `pty_output` to CLI clients only. The only difference is the source: `pty_output` messages now come from `spawnSidecarPty()`'s `pty_data` handler instead of the primary process. No code change needed here.

- [ ] **Step 7: Run type check**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
```

Expected: PASS (or minor issues to fix inline).

- [ ] **Step 8: Commit**

```bash
git add packages/bridge/src/websocket.ts
git commit -m "feat(bridge): route pty_input/resize to sidecar, spawn on CLI attach, destroy on detach"
```

---

### Task 4: Update existing tests

Fix any existing tests that broke from the session.ts and websocket.ts changes. Add new tests for sidecar lifecycle.

**Files:**
- Modify: `packages/bridge/src/session.test.ts`
- Modify: `packages/bridge/src/websocket.test.ts`

- [ ] **Step 1: Check which tests are failing**

```bash
npx vitest run 2>&1 | tail -30
```

Identify failures and fix them. Common issues:
- Tests that set `usePty = true` or reference PtyProcess as the primary process
- Tests that check `session.process.isPty`
- Tests that reference AnsiParser imports

- [ ] **Step 2: Add sidecar spawn/destroy tests to session.test.ts**

Add a new describe block to `packages/bridge/src/session.test.ts`:

```typescript
describe("sidecar PTY", () => {
  it("spawnSidecarPty returns null when session has no claudeSessionId", () => {
    const onMessage = vi.fn();
    const mgr = new SessionManager(onMessage);
    const id = mgr.create("/tmp", {});
    const session = mgr.get(id)!;
    // Clear the pre-populated sessionId
    session.claudeSessionId = undefined;

    const result = mgr.spawnSidecarPty(id);
    expect(result).toBeNull();
    expect(session.ptyProcess).toBeNull();
  });

  it("spawnSidecarPty returns existing sidecar if already spawned", () => {
    const onMessage = vi.fn();
    const mgr = new SessionManager(onMessage);
    const id = mgr.create("/tmp", { sessionId: "test-session" });
    const session = mgr.get(id)!;
    session.claudeSessionId = "test-session";

    // Mock PtyProcess to avoid actually spawning
    const mockPty = { on: vi.fn(), start: vi.fn(), stop: vi.fn(), removeAllListeners: vi.fn() };
    session.ptyProcess = mockPty as any;

    const result = mgr.spawnSidecarPty(id);
    expect(result).toBe(mockPty);
  });

  it("destroySidecarPty cleans up the sidecar", () => {
    const onMessage = vi.fn();
    const mgr = new SessionManager(onMessage);
    const id = mgr.create("/tmp", {});
    const session = mgr.get(id)!;

    const mockPty = { stop: vi.fn(), removeAllListeners: vi.fn() };
    session.ptyProcess = mockPty as any;

    mgr.destroySidecarPty(id);
    expect(mockPty.stop).toHaveBeenCalled();
    expect(mockPty.removeAllListeners).toHaveBeenCalled();
    expect(session.ptyProcess).toBeNull();
  });

  it("destroy() also destroys sidecar PTY", () => {
    const onMessage = vi.fn();
    const mgr = new SessionManager(onMessage);
    const id = mgr.create("/tmp", {});
    const session = mgr.get(id)!;

    const mockPty = { stop: vi.fn(), removeAllListeners: vi.fn() };
    session.ptyProcess = mockPty as any;

    mgr.destroy(id);
    expect(mockPty.stop).toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run full test suite**

```bash
npx vitest run
```

Expected: All tests PASS.

- [ ] **Step 4: Run type check**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
npx tsc --noEmit -p packages/cli/tsconfig.json
```

Expected: PASS for both.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test(bridge): fix tests for sidecar PTY architecture, add sidecar lifecycle tests"
```

---

### Task 5: Update CLI package for sidecar attach

The CLI package's `pty-session.ts` already handles raw PTY passthrough correctly. The main change is that `attach_session` should send `cols` and `rows` so the sidecar PTY spawns with the right terminal size. Also update `index.ts` start command to wait for session creation before entering raw mode.

**Files:**
- Modify: `packages/cli/src/pty-session.ts`
- Modify: `packages/cli/src/index.ts`

- [ ] **Step 1: Send cols/rows with attach_session**

In `packages/cli/src/pty-session.ts`, update the attach message (around line 18):

```typescript
    // Attach to session as CLI client — include terminal size for sidecar PTY
    client.send({
      type: "attach_session",
      sessionId,
      clientType: "cli",
      cols: stdout.columns,
      rows: stdout.rows,
    });
```

And remove the separate `pty_resize` message that immediately follows (around line 23-30), since cols/rows are now sent with attach:

```typescript
    // DELETE this block — cols/rows now sent with attach_session:
    // if (stdout.columns && stdout.rows) {
    //   client.send({
    //     type: "pty_resize",
    //     sessionId,
    //     cols: stdout.columns,
    //     rows: stdout.rows,
    //   });
    // }
```

- [ ] **Step 2: Update pty-session.ts onSessionEnd to handle sidecar exit**

The `onSessionEnd` handler currently listens for `"idle"`, `"exited"`, `"stopped"` status. When the sidecar PTY exits (e.g., user types `/exit` in the CLI), the bridge will send a status message. This already works — no change needed.

However, also watch for an `error` message in case the sidecar fails to spawn:

```typescript
    // Handle session end — sidecar PTY sends "idle" when it exits
    const onSessionEnd = (msg: Record<string, unknown>) => {
      if (msg.sessionId !== sessionId) return;
      if (
        msg.type === "status" &&
        (msg.status === "idle" || msg.status === "exited" || msg.status === "stopped")
      ) {
        cleanup();
      }
      // Also handle sidecar spawn failure
      if (msg.type === "error" && msg.message === "Failed to start CLI view") {
        console.error("Failed to start CLI view for this session.");
        cleanup();
      }
    };
```

- [ ] **Step 3: Run CLI type check**

```bash
npx tsc --noEmit -p packages/cli/tsconfig.json
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/cli/src/pty-session.ts packages/cli/src/index.ts
git commit -m "feat(cli): send terminal size with attach, handle sidecar spawn failure"
```

---

### Task 6: End-to-end verification

Build everything, start the bridge, and verify both phone and CLI work.

**Files:** None (verification only)

- [ ] **Step 1: Build bridge and CLI**

```bash
npm run bridge:build
npm run build --workspace=packages/cli
```

- [ ] **Step 2: Run full test suite**

```bash
npx vitest run
```

Expected: All tests PASS.

- [ ] **Step 3: Type check all packages**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
npx tsc --noEmit -p packages/cli/tsconfig.json
```

Expected: PASS for both.

- [ ] **Step 4: Manual test — phone (SDK primary)**

1. Start bridge: `npm run bridge`
2. Open phone app, connect to bridge
3. Start a new session — should work exactly as before (structured messages, streaming, tools, permissions)
4. Verify: no PTY-related errors in bridge logs

- [ ] **Step 5: Manual test — CLI attach (sidecar PTY)**

1. With bridge running and a session active from step 4:
2. In a terminal: `cd /Users/devlin/GitHub/ccpocket && npx tsx packages/cli/src/index.ts`
3. Select the active session from the Ink home screen
4. Verify: native Claude TUI appears (colors, status bar, Ink UI)
5. Type a message at the CLI — Claude should process it
6. Ctrl+D to detach — should return to Ink home screen
7. Check bridge logs: sidecar PTY should be destroyed after detach

- [ ] **Step 6: Manual test — phone + CLI simultaneously**

1. Start a session from phone
2. Attach CLI to the same session
3. Send a message from the phone — both phone and CLI should see Claude's response
4. Send a message from the CLI — phone should see the response via SDK events

- [ ] **Step 7: Final commit with any adjustments**

If any fixes were needed during manual testing, commit them:

```bash
git add -A
git commit -m "fix(bridge): adjustments from end-to-end testing"
```
