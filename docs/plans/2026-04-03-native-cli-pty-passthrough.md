# Native CLI via PTY Passthrough — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bridge's SDK/subprocess process management with PTY-based spawning of native `claude` and `codex` CLI binaries so terminal clients see the real native CLI, while phone clients receive structured events derived from an ANSI parser.

**Architecture:** The bridge spawns native CLI binaries via `node-pty`. Raw PTY bytes are forwarded to terminal clients (`clientType: "cli"`) for native CLI experience. An ANSI parser extracts structured events from the same PTY stream for phone clients (`clientType: "app"`). All process backends (`PtyProcess`, `SdkProcess`, `CodexProcess`) implement a common `IProcessTransport` interface so `SessionManager` is backend-agnostic. A `ReplayBuffer` with sequence tracking enables efficient phone reconnection.

**Tech Stack:** TypeScript ESM, node-pty (native PTY), Node.js `EventEmitter`, Ink (React for terminals), vitest

**Design spec:** `docs/superpowers/specs/2026-04-03-native-cli-pty-design.md`

---

## File Structure

### New files
| File | Responsibility |
|---|---|
| `packages/bridge/src/process-transport.ts` | `IProcessTransport` interface + `ProcessStartOptions` type |
| `packages/bridge/src/replay-buffer.ts` | Bounded ring buffer with sequence tracking for phone reconnection |
| `packages/bridge/src/replay-buffer.test.ts` | ReplayBuffer tests |
| `packages/bridge/src/ansi-parser.ts` | ANSI parser state machine — strips escape codes, detects CLI patterns, emits `ServerMessage` |
| `packages/bridge/src/ansi-parser.test.ts` | Parser tests with simulated PTY output |
| `packages/bridge/src/pty-process.ts` | `PtyProcess` — spawns native CLI via node-pty, implements `IProcessTransport` |
| `packages/bridge/src/pty-process.test.ts` | PtyProcess tests (mocked node-pty) |
| `packages/cli/src/pty-session.ts` | Raw PTY session handler — stdin/stdout passthrough, replaces Ink session view |

### Modified files
| File | Changes |
|---|---|
| `packages/bridge/package.json` | Add `node-pty` dependency |
| `packages/bridge/src/parser.ts` | Add `pty_input`, `pty_output`, `pty_resize` message types; add `lastSeq` to `attach_session` |
| `packages/bridge/src/session.ts` | Use `IProcessTransport` for process type; add `ReplayBuffer` per session; support `usePty` flag |
| `packages/bridge/src/websocket.ts` | Handle `pty_input`/`pty_resize`; route `pty_output` to cli clients; seq-based replay on attach |
| `packages/cli/src/app.tsx` | Add `onEnterRawSession` callback to exit Ink for PTY passthrough |
| `packages/cli/src/index.ts` | Ink ↔ raw PTY session loop |

---

## Task 1: IProcessTransport Interface + node-pty Dependency

**Files:**
- Create: `packages/bridge/src/process-transport.ts`
- Modify: `packages/bridge/package.json`

- [ ] **Step 1: Add node-pty dependency**

```bash
cd packages/bridge && npm install node-pty
```

Verify it installed (native addon — requires Xcode CLI tools on macOS):
```bash
node -e "require('node-pty')"
```
Expected: no error.

- [ ] **Step 2: Create the IProcessTransport interface**

Create `packages/bridge/src/process-transport.ts`:

```typescript
import { EventEmitter } from "node:events";
import type { ProcessStatus, ServerMessage, Provider } from "./parser.js";

/** Options passed to IProcessTransport.start(). */
export interface ProcessStartOptions {
  projectPath: string;
  provider: Provider;
  sessionId?: string;            // Resume existing session
  permissionMode?: string;       // Claude: "default" | "acceptEdits" | "bypassPermissions"
  model?: string;
  initialInput?: string;         // Auto-send on start
  [key: string]: unknown;        // Provider-specific passthrough
}

/**
 * Common interface for all process backends (PtyProcess, SdkProcess, CodexProcess).
 * SessionManager interacts with processes exclusively through this interface.
 *
 * Events emitted:
 * - "message"  (msg: ServerMessage)  — structured events for phone clients
 * - "pty_data" (data: string)        — raw PTY bytes for terminal clients (PTY only)
 * - "status"   (status: ProcessStatus)
 * - "exit"     (code: number | null)
 */
export interface IProcessTransport extends EventEmitter {
  start(opts: ProcessStartOptions): void;
  stop(): void;
  kill(): void;

  /** Raw input — PTY keystrokes or no-op for SDK processes. */
  write(data: string): void;

  /** User message — adds newline/CR for PTY, queues for SDK. */
  sendInput(text: string): void;

  /** Approve a pending tool call. */
  sendApproval(id: string): void;

  /** Reject a pending tool call. */
  sendRejection(id: string, reason?: string): void;

  /** Current process status. */
  readonly status: ProcessStatus;

  /** Whether this transport emits pty_data events. */
  readonly isPty: boolean;

  /** The native session ID (Claude session UUID or Codex thread ID). */
  readonly sessionId: string | null;
}
```

- [ ] **Step 3: Run type check**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add packages/bridge/src/process-transport.ts packages/bridge/package.json packages/bridge/package-lock.json
git commit -m "feat(bridge): add IProcessTransport interface and node-pty dependency"
```

---

## Task 2: ReplayBuffer (TDD)

**Files:**
- Create: `packages/bridge/src/replay-buffer.ts`
- Create: `packages/bridge/src/replay-buffer.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/bridge/src/replay-buffer.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { ReplayBuffer } from "./replay-buffer.js";

describe("ReplayBuffer", () => {
  it("appends events with incrementing sequence numbers", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "status", status: "running" });
    buf.append({ type: "stream_delta", text: "hello" });

    const events = buf.replayFrom(0);
    expect(events).toHaveLength(2);
    expect(events[0].seq).toBe(1);
    expect(events[1].seq).toBe(2);
    expect(events[1].msg).toEqual({ type: "stream_delta", text: "hello" });
  });

  it("replays only events after lastSeq", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" });
    buf.append({ type: "stream_delta", text: "b" });
    buf.append({ type: "stream_delta", text: "c" });

    const events = buf.replayFrom(2);
    expect(events).toHaveLength(1);
    expect(events[0].seq).toBe(3);
    expect(events[0].msg).toEqual({ type: "stream_delta", text: "c" });
  });

  it("returns all events when lastSeq is 0", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" });
    buf.append({ type: "stream_delta", text: "b" });

    expect(buf.replayFrom(0)).toHaveLength(2);
  });

  it("evicts oldest events when max count exceeded", () => {
    const buf = new ReplayBuffer({ maxCount: 3 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const events = buf.replayFrom(0);
    expect(events).toHaveLength(3);
    expect(events[0].seq).toBe(3); // oldest surviving
    expect(events[2].seq).toBe(5);
  });

  it("detects gap when lastSeq is older than buffer start", () => {
    const buf = new ReplayBuffer({ maxCount: 2 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const result = buf.replayWithGapInfo(1); // seq 1 is long gone
    expect(result.gap).toBe(true);
    expect(result.events).toHaveLength(2); // sends full buffer
  });

  it("no gap when lastSeq is within buffer range", () => {
    const buf = new ReplayBuffer({ maxCount: 10 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const result = buf.replayWithGapInfo(3);
    expect(result.gap).toBe(false);
    expect(result.events).toHaveLength(2); // seq 4 and 5
  });

  it("evicts when total size exceeds maxBytes", () => {
    const buf = new ReplayBuffer({ maxCount: 1000, maxBytes: 100 });
    // Each event is roughly ~40 bytes when serialized
    for (let i = 0; i < 10; i++) {
      buf.append({ type: "stream_delta", text: "x".repeat(20) });
    }

    // Should have evicted to stay under 100 bytes
    expect(buf.length).toBeLessThan(10);
    expect(buf.length).toBeGreaterThan(0);
  });

  it("returns empty array when empty", () => {
    const buf = new ReplayBuffer();
    expect(buf.replayFrom(0)).toEqual([]);
    expect(buf.replayFrom(99)).toEqual([]);
  });

  it("clear removes all events and resets nextSeq", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" });
    buf.clear();
    expect(buf.replayFrom(0)).toEqual([]);
    expect(buf.length).toBe(0);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/bridge && npx vitest run src/replay-buffer.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement ReplayBuffer**

Create `packages/bridge/src/replay-buffer.ts`:

```typescript
import type { ServerMessage } from "./parser.js";

export interface ReplayEvent {
  seq: number;
  msg: ServerMessage;
  timestamp: number;
}

export interface ReplayBufferOptions {
  maxCount?: number;  // Default 500
  maxBytes?: number;  // Default 5MB
}

export interface ReplayResult {
  events: ReplayEvent[];
  gap: boolean;
}

export class ReplayBuffer {
  private events: ReplayEvent[] = [];
  private nextSeq = 1;
  private totalBytes = 0;
  private readonly maxCount: number;
  private readonly maxBytes: number;

  constructor(opts?: ReplayBufferOptions) {
    this.maxCount = opts?.maxCount ?? 500;
    this.maxBytes = opts?.maxBytes ?? 5 * 1024 * 1024;
  }

  get length(): number {
    return this.events.length;
  }

  append(msg: ServerMessage): number {
    const seq = this.nextSeq++;
    const size = JSON.stringify(msg).length;
    this.events.push({ seq, msg, timestamp: Date.now() });
    this.totalBytes += size;

    // Evict oldest while over limits
    while (
      this.events.length > this.maxCount ||
      (this.totalBytes > this.maxBytes && this.events.length > 1)
    ) {
      const evicted = this.events.shift()!;
      this.totalBytes -= JSON.stringify(evicted.msg).length;
    }

    return seq;
  }

  /** Replay all events with seq > lastSeq. */
  replayFrom(lastSeq: number): ReplayEvent[] {
    return this.events.filter((e) => e.seq > lastSeq);
  }

  /** Replay with gap detection. */
  replayWithGapInfo(lastSeq: number): ReplayResult {
    if (this.events.length === 0) {
      return { events: [], gap: false };
    }

    const oldestSeq = this.events[0].seq;
    const gap = lastSeq > 0 && lastSeq < oldestSeq;

    return {
      events: gap ? [...this.events] : this.replayFrom(lastSeq),
      gap,
    };
  }

  clear(): void {
    this.events = [];
    this.nextSeq = 1;
    this.totalBytes = 0;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd packages/bridge && npx vitest run src/replay-buffer.test.ts
```
Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/bridge/src/replay-buffer.ts packages/bridge/src/replay-buffer.test.ts
git commit -m "feat(bridge): add ReplayBuffer with sequence tracking and gap detection"
```

---

## Task 3: Update Message Types in parser.ts

**Files:**
- Modify: `packages/bridge/src/parser.ts`

- [ ] **Step 1: Add pty_input to ClientMessage union**

In `packages/bridge/src/parser.ts`, at the end of the `ClientMessage` union (before the final line `| { type: "detach_session"; sessionId: string };`), add:

```typescript
  | { type: "pty_input"; sessionId: string; data: string }
  | { type: "pty_resize"; sessionId: string; cols: number; rows: number }
```

And update `attach_session` to include `lastSeq`:

```typescript
  | { type: "attach_session"; sessionId: string; clientType?: string; lastSeq?: number }
```

- [ ] **Step 2: Add pty_output to ServerMessage union**

In the `ServerMessage` union, add:

```typescript
  | { type: "pty_output"; sessionId: string; data: string }
```

- [ ] **Step 3: Update parseClientMessage validation**

In the `parseClientMessage` function, add validation cases for the new types. Find the `switch` statement and add before the `default` case:

```typescript
      case "pty_input":
        if (typeof msg.sessionId !== "string") return null;
        if (typeof msg.data !== "string") return null;
        break;
      case "pty_resize":
        if (typeof msg.sessionId !== "string") return null;
        if (typeof msg.cols !== "number") return null;
        if (typeof msg.rows !== "number") return null;
        break;
```

And update the existing `attach_session` validation to allow `lastSeq`:

```typescript
      case "attach_session":
        if (typeof msg.sessionId !== "string") return null;
        if (msg.clientType !== undefined && typeof msg.clientType !== "string")
          return null;
        if (msg.lastSeq !== undefined && typeof msg.lastSeq !== "number")
          return null;
        break;
```

- [ ] **Step 4: Run type check and existing tests**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json && cd packages/bridge && npx vitest run
```
Expected: type check passes, all existing tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/bridge/src/parser.ts
git commit -m "feat(bridge): add PTY message types (pty_input, pty_output, pty_resize, lastSeq)"
```

---

## Task 4: ANSI Parser (TDD)

**Files:**
- Create: `packages/bridge/src/ansi-parser.ts`
- Create: `packages/bridge/src/ansi-parser.test.ts`

The ANSI parser strips escape codes from PTY output, detects Claude CLI patterns (markers, tool calls, permissions, cost summaries), and emits structured `ServerMessage` objects for phone clients.

**Reference:** Claude CLI uses `⏺` (U+23FA) as the assistant marker, `⎿` (U+23BF) for tool results/responses, and `Allow …? ([y]es, [n]o, …)` for permission prompts.

- [ ] **Step 1: Write failing tests**

Create `packages/bridge/src/ansi-parser.test.ts`:

```typescript
import { describe, it, expect, vi } from "vitest";
import { AnsiParser } from "./ansi-parser.js";
import type { ServerMessage } from "./parser.js";

function collectMessages(parser: AnsiParser, chunks: string[]): ServerMessage[] {
  const msgs: ServerMessage[] = [];
  parser.on("message", (msg) => msgs.push(msg));
  for (const chunk of chunks) {
    parser.feed(chunk);
  }
  parser.flush();
  return msgs;
}

describe("AnsiParser", () => {
  describe("ANSI stripping", () => {
    it("strips SGR color codes", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\x1b[1m\x1b[34m⏺\x1b[0m Hello world\r\n",
      ]);
      const textMsgs = msgs.filter((m) => m.type === "assistant");
      expect(textMsgs.length).toBeGreaterThan(0);
    });

    it("strips cursor movement codes", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\x1b[2K\x1b[1G⏺ Test\r\n",
      ]);
      const textMsgs = msgs.filter((m) => m.type === "assistant");
      expect(textMsgs.length).toBeGreaterThan(0);
    });
  });

  describe("Claude profile — assistant text", () => {
    it("emits stream_delta for text after ⏺ marker", () => {
      const parser = new AnsiParser("claude");
      const msgs: ServerMessage[] = [];
      parser.on("message", (msg) => msgs.push(msg));

      parser.feed("⏺ Hello ");
      parser.feed("world\r\n");
      parser.flush();

      const deltas = msgs.filter((m) => m.type === "stream_delta");
      expect(deltas.length).toBeGreaterThan(0);

      const assistant = msgs.filter((m) => m.type === "assistant");
      expect(assistant.length).toBe(1);
    });

    it("emits assistant message with full accumulated text on flush", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "⏺ Line one\r\n",
        "  Line two\r\n",
      ]);

      const assistant = msgs.find((m) => m.type === "assistant") as Extract<
        ServerMessage,
        { type: "assistant" }
      >;
      expect(assistant).toBeDefined();
      expect(assistant.message.content[0]).toMatchObject({
        type: "text",
        text: expect.stringContaining("Line one"),
      });
    });
  });

  describe("Claude profile — tool calls", () => {
    it("detects tool call header and emits assistant with tool_use", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "⏺ I'll read the file.\r\n",
        "\r\n",
        "⎿ Read(src/index.ts)\r\n",
        "  1 | import foo from 'bar'\r\n",
        "  2 | console.log(foo)\r\n",
        "\r\n",
      ]);

      const assistants = msgs.filter((m) => m.type === "assistant");
      expect(assistants.length).toBeGreaterThanOrEqual(1);

      const toolResults = msgs.filter((m) => m.type === "tool_result");
      expect(toolResults.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe("Claude profile — permission prompts", () => {
    it("emits permission_request on Allow? pattern", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "⎿ Write(src/foo.ts)\r\n",
        "  new content here\r\n",
        "\r\n",
        "  Allow? ([y]es, [n]o, [a]lways)\r\n",
      ]);

      const perms = msgs.filter((m) => m.type === "permission_request");
      expect(perms.length).toBe(1);
    });
  });

  describe("Claude profile — cost/result", () => {
    it("emits result on Cost: line", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "⏺ Done!\r\n",
        "\r\n",
        "Cost: $0.05 · Duration: 12s\r\n",
      ]);

      const results = msgs.filter((m) => m.type === "result");
      expect(results.length).toBe(1);
      const result = results[0] as Extract<ServerMessage, { type: "result" }>;
      expect(result.cost).toBeCloseTo(0.05);
      expect(result.duration).toBe(12);
    });
  });

  describe("Claude profile — session ID capture", () => {
    it("emits system init with session ID", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "Session: abc-123-def\r\n",
        "⏺ Hello\r\n",
      ]);

      const system = msgs.find(
        (m) => m.type === "system" && m.subtype === "init",
      ) as Extract<ServerMessage, { type: "system" }>;
      expect(system).toBeDefined();
      expect(system.sessionId).toBe("abc-123-def");
    });
  });

  describe("graceful degradation", () => {
    it("emits generic assistant text for unrecognized output", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "some random unrecognized output\r\n",
      ]);

      // Should still emit something — never silently swallow output
      expect(msgs.length).toBeGreaterThan(0);
    });
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/bridge && npx vitest run src/ansi-parser.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement AnsiParser**

Create `packages/bridge/src/ansi-parser.ts`:

```typescript
import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import type {
  ServerMessage,
  AssistantMessage,
  AssistantContent,
  Provider,
} from "./parser.js";

/** Strip all ANSI escape sequences from a string. */
function stripAnsi(str: string): string {
  // CSI sequences, OSC sequences, single-char escapes
  return str.replace(
    // eslint-disable-next-line no-control-regex
    /\x1b(?:\[[0-9;]*[A-Za-z@]|\][^\x07]*\x07|[()][0-2]|[>=<])/g,
    "",
  );
}

type ParserState =
  | "idle"
  | "streaming_text"
  | "tool_call"
  | "tool_result"
  | "permission_prompt";

/**
 * ANSI parser: sits between PTY output and phone clients.
 * Feeds raw PTY chunks, emits structured ServerMessage objects.
 *
 * Events:
 * - "message" (msg: ServerMessage)
 * - "session_id" (id: string) — captured session/thread ID
 */
export class AnsiParser extends EventEmitter {
  private state: ParserState = "idle";
  private textBuffer = "";
  private toolName = "";
  private toolInput = "";
  private toolResultBuffer = "";
  private currentToolUseId = "";
  private lineBuffer = "";
  private provider: Provider;
  private capturedSessionId: string | null = null;

  constructor(provider: Provider) {
    super();
    this.provider = provider;
  }

  /** Feed a chunk of raw PTY output. */
  feed(chunk: string): void {
    this.lineBuffer += chunk;

    // Process complete lines
    let newlineIdx: number;
    while ((newlineIdx = this.lineBuffer.indexOf("\n")) !== -1) {
      const rawLine = this.lineBuffer.slice(0, newlineIdx);
      this.lineBuffer = this.lineBuffer.slice(newlineIdx + 1);
      const line = stripAnsi(rawLine).replace(/\r$/, "");
      this.processLine(line);
    }

    // Emit stream deltas for partial content in streaming state
    if (this.state === "streaming_text" && this.lineBuffer.length > 0) {
      const partial = stripAnsi(this.lineBuffer);
      if (partial.length > 0) {
        this.emit("message", { type: "stream_delta", text: partial } as ServerMessage);
      }
    }
  }

  /** Flush remaining buffer (call on session end or before finalization). */
  flush(): void {
    if (this.lineBuffer.length > 0) {
      const line = stripAnsi(this.lineBuffer).replace(/\r$/, "");
      this.lineBuffer = "";
      if (line.length > 0) {
        this.processLine(line);
      }
    }
    this.finalizeCurrentState();
  }

  private processLine(line: string): void {
    // Session ID capture (Claude: "Session: <uuid>")
    const sessionMatch = line.match(/^Session:\s+(\S+)/);
    if (sessionMatch && !this.capturedSessionId) {
      this.capturedSessionId = sessionMatch[1];
      this.emit("session_id", this.capturedSessionId);
      this.emit("message", {
        type: "system",
        subtype: "init",
        sessionId: this.capturedSessionId,
      } as ServerMessage);
      return;
    }

    // Cost/result line: "Cost: $X.XX · Duration: Xs"
    const costMatch = line.match(
      /Cost:\s*\$([0-9.]+)\s*·\s*Duration:\s*([0-9.]+)s/,
    );
    if (costMatch) {
      this.finalizeCurrentState();
      this.emit("message", {
        type: "result",
        subtype: "success",
        cost: parseFloat(costMatch[1]),
        duration: parseFloat(costMatch[2]),
      } as ServerMessage);
      this.emit("message", {
        type: "status",
        status: "idle",
      } as ServerMessage);
      return;
    }

    // Permission prompt: "Allow?" or "[y]es"
    if (/Allow\s*\?/i.test(line) || /\[y\]es.*\[n\]o/.test(line)) {
      this.finalizeCurrentState();
      this.state = "permission_prompt";
      this.emit("message", {
        type: "permission_request",
        toolUseId: this.currentToolUseId || randomUUID(),
        toolName: this.toolName || "unknown",
        input: this.toolInput ? { command: this.toolInput } : {},
      } as ServerMessage);
      return;
    }

    // Tool call header: "⎿ ToolName(args)" or "⎿ ToolName path"
    const toolMatch = line.match(/^⎿\s+(\w+)\(([^)]*)\)/);
    const toolMatchAlt = line.match(/^⎿\s+(\w+)\s+(.+)/);
    if (toolMatch || toolMatchAlt) {
      this.finalizeCurrentState();
      const match = toolMatch || toolMatchAlt!;
      this.toolName = match[1];
      this.toolInput = match[2] || "";
      this.currentToolUseId = randomUUID();
      this.state = "tool_call";

      // Emit tool_use as assistant message
      const content: AssistantContent[] = [
        {
          type: "tool_use",
          id: this.currentToolUseId,
          name: this.toolName,
          input: this.parseToolInput(this.toolInput),
        },
      ];
      this.emitAssistant(content);
      this.state = "tool_result";
      this.toolResultBuffer = "";
      return;
    }

    // Assistant marker: "⏺" followed by text
    if (line.startsWith("⏺")) {
      this.finalizeCurrentState();
      this.state = "streaming_text";
      const text = line.slice(1).trimStart();
      if (text) {
        this.textBuffer += text + "\n";
        this.emit("message", {
          type: "stream_delta",
          text: text,
        } as ServerMessage);
        this.emit("message", {
          type: "status",
          status: "running",
        } as ServerMessage);
      }
      return;
    }

    // State-specific processing
    switch (this.state) {
      case "streaming_text": {
        this.textBuffer += line + "\n";
        if (line.trim().length > 0) {
          this.emit("message", {
            type: "stream_delta",
            text: line,
          } as ServerMessage);
        }
        break;
      }

      case "tool_result": {
        if (line.startsWith("  ") || line.trim() === "") {
          // Indented content = tool result output
          this.toolResultBuffer += line + "\n";
        } else {
          // Unindented line = end of tool result, re-process this line
          this.finalizeCurrentState();
          this.processLine(line);
        }
        break;
      }

      case "permission_prompt": {
        // Waiting for resolution — ignore lines until state changes
        break;
      }

      case "idle":
      default: {
        // Unrecognized output — emit as generic assistant text
        if (line.trim().length > 0) {
          this.textBuffer += line + "\n";
          this.state = "streaming_text";
          this.emit("message", {
            type: "stream_delta",
            text: line,
          } as ServerMessage);
        }
        break;
      }
    }
  }

  private finalizeCurrentState(): void {
    switch (this.state) {
      case "streaming_text": {
        if (this.textBuffer.trim().length > 0) {
          this.emitAssistant([
            { type: "text", text: this.textBuffer.trim() },
          ]);
        }
        this.textBuffer = "";
        break;
      }

      case "tool_result": {
        if (this.toolResultBuffer.trim().length > 0) {
          this.emit("message", {
            type: "tool_result",
            toolUseId: this.currentToolUseId,
            content: this.toolResultBuffer.trim(),
            toolName: this.toolName,
          } as ServerMessage);
        }
        this.toolResultBuffer = "";
        break;
      }

      case "tool_call":
      case "permission_prompt":
      case "idle":
        break;
    }

    this.state = "idle";
  }

  private emitAssistant(content: AssistantContent[]): void {
    const msg: AssistantMessage = {
      id: randomUUID(),
      role: "assistant",
      content,
      model: "unknown", // CLI doesn't always expose model in output
    };
    this.emit("message", {
      type: "assistant",
      message: msg,
    } as ServerMessage);
  }

  private parseToolInput(raw: string): Record<string, unknown> {
    if (!raw) return {};
    // Simple heuristic: if it looks like a path, use file_path key
    if (raw.startsWith("/") || raw.startsWith("src/") || raw.includes(".")) {
      return { file_path: raw };
    }
    return { command: raw };
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd packages/bridge && npx vitest run src/ansi-parser.test.ts
```
Expected: all tests PASS. Adjust patterns if any fail — the real Claude output format may differ slightly; this establishes the pattern detection framework.

- [ ] **Step 5: Commit**

```bash
git add packages/bridge/src/ansi-parser.ts packages/bridge/src/ansi-parser.test.ts
git commit -m "feat(bridge): add ANSI parser state machine with Claude profile"
```

---

## Task 5: PtyProcess (TDD)

**Files:**
- Create: `packages/bridge/src/pty-process.ts`
- Create: `packages/bridge/src/pty-process.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/bridge/src/pty-process.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { EventEmitter } from "node:events";

// Mock node-pty before importing PtyProcess
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

describe("PtyProcess", () => {
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

  it("spawns claude via node-pty on start", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "claude",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "claude",
      expect.arrayContaining(["--verbose"]),
      expect.objectContaining({ cwd: "/tmp/test" }),
    );
  });

  it("spawns codex for codex provider", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "codex",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "codex",
      expect.any(Array),
      expect.objectContaining({ cwd: "/tmp/test" }),
    );
  });

  it("emits pty_data on PTY output", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const ptyData: string[] = [];
    proc.on("pty_data", (data: string) => ptyData.push(data));

    dataHandler("hello world\r\n");
    expect(ptyData).toEqual(["hello world\r\n"]);
  });

  it("emits structured messages via ANSI parser", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    dataHandler("⏺ Hello from Claude\r\n");

    const deltas = messages.filter((m: any) => m.type === "stream_delta");
    expect(deltas.length).toBeGreaterThan(0);
  });

  it("writes raw data to PTY on write()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.write("hello");
    expect(mockPty.write).toHaveBeenCalledWith("hello");
  });

  it("writes text + CR on sendInput()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendInput("tell me about cats");
    expect(mockPty.write).toHaveBeenCalledWith("tell me about cats\n");
  });

  it("writes y + CR on sendApproval()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendApproval("tool-123");
    expect(mockPty.write).toHaveBeenCalledWith("y\n");
  });

  it("writes n + CR on sendRejection()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendRejection("tool-123");
    expect(mockPty.write).toHaveBeenCalledWith("n\n");
  });

  it("emits exit on PTY exit", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const exits: unknown[] = [];
    proc.on("exit", (code) => exits.push(code));

    exitHandler({ exitCode: 0 });
    expect(exits).toEqual([0]);
  });

  it("kills PTY on stop()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.stop();
    expect(mockPty.kill).toHaveBeenCalled();
  });

  it("isPty returns true", () => {
    expect(proc.isPty).toBe(true);
  });

  it("resizes PTY", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.resize(120, 40);
    expect(mockPty.resize).toHaveBeenCalledWith(120, 40);
  });

  it("includes --resume flag when sessionId provided", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "claude",
      sessionId: "abc-123",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "claude",
      expect.arrayContaining(["--resume", "abc-123"]),
      expect.any(Object),
    );
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/bridge && npx vitest run src/pty-process.test.ts
```
Expected: FAIL — module not found.

- [ ] **Step 3: Implement PtyProcess**

Create `packages/bridge/src/pty-process.ts`:

```typescript
import { EventEmitter } from "node:events";
import * as pty from "node-pty";
import type { IPty } from "node-pty";
import { AnsiParser } from "./ansi-parser.js";
import type { IProcessTransport, ProcessStartOptions } from "./process-transport.js";
import type { ProcessStatus, ServerMessage } from "./parser.js";

export class PtyProcess extends EventEmitter implements IProcessTransport {
  private ptyProc: IPty | null = null;
  private parser: AnsiParser | null = null;
  private _status: ProcessStatus = "idle";
  private _sessionId: string | null = null;
  private dataDisposable: { dispose(): void } | null = null;
  private exitDisposable: { dispose(): void } | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  get isPty(): boolean {
    return true;
  }

  get sessionId(): string | null {
    return this._sessionId;
  }

  start(opts: ProcessStartOptions): void {
    const { projectPath, provider, sessionId, permissionMode } = opts;

    const binary = provider === "codex" ? "codex" : "claude";
    const args = this.buildArgs(provider, projectPath, sessionId, permissionMode);

    this.parser = new AnsiParser(provider);
    this.parser.on("message", (msg: ServerMessage) => {
      this.emit("message", msg);
    });
    this.parser.on("session_id", (id: string) => {
      this._sessionId = id;
    });

    this._status = "starting";
    this.emit("status", this._status);

    this.ptyProc = pty.spawn(binary, args, {
      name: "xterm-256color",
      cols: 80,
      rows: 24,
      cwd: projectPath,
      env: process.env as Record<string, string>,
    });

    this.dataDisposable = this.ptyProc.onData((data: string) => {
      // Forward raw bytes to terminal clients
      this.emit("pty_data", data);
      // Feed into ANSI parser for phone clients
      this.parser?.feed(data);
    });

    this.exitDisposable = this.ptyProc.onExit(
      ({ exitCode }: { exitCode: number; signal?: number }) => {
        this.parser?.flush();
        this._status = "idle";
        this.emit("status", this._status);
        this.emit("exit", exitCode);
        this.cleanup();
      },
    );

    this._status = "running";
    this.emit("status", this._status);

    // Auto-send initial input if provided
    if (opts.initialInput) {
      setTimeout(() => this.sendInput(opts.initialInput!), 500);
    }
  }

  stop(): void {
    this.ptyProc?.kill("SIGTERM");
  }

  kill(): void {
    this.ptyProc?.kill("SIGKILL");
  }

  write(data: string): void {
    this.ptyProc?.write(data);
  }

  sendInput(text: string): void {
    this.ptyProc?.write(text + "\n");
  }

  sendApproval(_id: string): void {
    this.ptyProc?.write("y\n");
  }

  sendRejection(_id: string, _reason?: string): void {
    this.ptyProc?.write("n\n");
  }

  /** Resize the PTY terminal. */
  resize(cols: number, rows: number): void {
    this.ptyProc?.resize(cols, rows);
  }

  private buildArgs(
    provider: string,
    projectPath: string,
    sessionId?: string,
    permissionMode?: string,
  ): string[] {
    if (provider === "codex") {
      const args = [projectPath];
      if (sessionId) args.push("--thread", sessionId);
      return args;
    }

    // Claude
    const args = [projectPath, "--verbose"];
    if (sessionId) {
      args.push("--resume", sessionId);
    }
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

- [ ] **Step 4: Run tests**

```bash
cd packages/bridge && npx vitest run src/pty-process.test.ts
```
Expected: all tests PASS.

- [ ] **Step 5: Run full bridge test suite**

```bash
cd packages/bridge && npx vitest run
```
Expected: all tests pass (existing + new).

- [ ] **Step 6: Commit**

```bash
git add packages/bridge/src/pty-process.ts packages/bridge/src/pty-process.test.ts
git commit -m "feat(bridge): add PtyProcess — spawns native CLI via node-pty"
```

---

## Task 6: SdkProcess & CodexProcess IProcessTransport Compat

**Files:**
- Modify: `packages/bridge/src/sdk-process.ts`
- Modify: `packages/bridge/src/codex-process.ts`

Add `implements IProcessTransport` to existing process classes. They already have compatible methods — we add the missing ones as no-ops.

- [ ] **Step 1: Update SdkProcess**

In `packages/bridge/src/sdk-process.ts`, add the import and implements clause:

```typescript
import type { IProcessTransport, ProcessStartOptions } from "./process-transport.js";
```

Add `implements IProcessTransport` to the class declaration. Then add the missing methods:

```typescript
  /** Raw PTY write — no-op for SDK process. */
  write(_data: string): void {
    // No PTY — raw write not supported
  }

  /** Not a PTY process. */
  get isPty(): boolean {
    return false;
  }

  /** Kill the process. */
  kill(): void {
    this.stop();
  }

  /** Approve a tool call (alias for approve). */
  sendApproval(id: string): void {
    this.approve(id);
  }

  /** Reject a tool call (alias for reject). */
  sendRejection(id: string, reason?: string): void {
    this.reject(id, reason);
  }
```

Note: `SdkProcess` already has `start()`, `stop()`, `sendInput()`, `status`, and `sessionId` — these satisfy the interface. The `start()` signature differs (`start(projectPath, options?)` vs `start(opts)`), so add an overload that accepts `ProcessStartOptions`:

```typescript
  start(opts: ProcessStartOptions): void;
  start(projectPath: string, options?: StartOptions): void;
  start(optsOrPath: ProcessStartOptions | string, options?: StartOptions): void {
    if (typeof optsOrPath === "string") {
      // Original call pattern
      this._start(optsOrPath, options);
    } else {
      // IProcessTransport call pattern
      this._start(optsOrPath.projectPath, {
        sessionId: optsOrPath.sessionId,
        permissionMode: optsOrPath.permissionMode as any,
        model: optsOrPath.model,
        initialInput: optsOrPath.initialInput,
      });
    }
  }
```

Move the original `start` implementation into a private `_start` method.

- [ ] **Step 2: Update CodexProcess**

Same pattern in `packages/bridge/src/codex-process.ts`. Add import, implements clause, and missing methods:

```typescript
import type { IProcessTransport, ProcessStartOptions } from "./process-transport.js";
```

Add `implements IProcessTransport`. Then add:

```typescript
  write(_data: string): void { }

  get isPty(): boolean {
    return false;
  }

  kill(): void {
    this.stop();
  }

  sendApproval(id: string): void {
    this.approve(id);
  }

  sendRejection(id: string, _reason?: string): void {
    this.reject(id);
  }
```

Add the same start-method overload pattern as SdkProcess.

- [ ] **Step 3: Run type check and tests**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json && cd packages/bridge && npx vitest run
```
Expected: no type errors, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add packages/bridge/src/sdk-process.ts packages/bridge/src/codex-process.ts
git commit -m "refactor(bridge): SdkProcess and CodexProcess implement IProcessTransport"
```

---

## Task 7: SessionManager Integration

**Files:**
- Modify: `packages/bridge/src/session.ts`

Update SessionManager to use `IProcessTransport` as the process type, add `ReplayBuffer` per session, and support a `usePty` flag to select between PtyProcess and legacy backends.

- [ ] **Step 1: Add imports**

In `packages/bridge/src/session.ts`, add:

```typescript
import type { IProcessTransport } from "./process-transport.js";
import { PtyProcess } from "./pty-process.js";
import { ReplayBuffer } from "./replay-buffer.js";
```

- [ ] **Step 2: Update SessionInfo type**

Change the `process` field type and add replay buffer:

```typescript
// In SessionInfo interface:
process: IProcessTransport;   // Was: SdkProcess | CodexProcess
replayBuffer: ReplayBuffer;   // NEW
```

- [ ] **Step 3: Update create() to support PTY**

In the `create()` method, add PTY process creation. The approach: always use PTY for new sessions (the `usePty` flag defaults to true, can be overridden for rollback).

Find where `create()` instantiates `new SdkProcess()` or `new CodexProcess()`. Add a branch above:

```typescript
const usePty = true; // Toggle for migration rollback

let proc: IProcessTransport;
if (usePty) {
  proc = new PtyProcess();
} else if (provider === "codex") {
  proc = new CodexProcess();
} else {
  proc = new SdkProcess();
}
```

- [ ] **Step 4: Initialize ReplayBuffer and wire it to process messages**

After creating the session, add the buffer and wire structured events into it:

```typescript
const replayBuffer = new ReplayBuffer();

// After the existing proc.on("message") listener that calls onMessage():
proc.on("message", (msg: ServerMessage) => {
  replayBuffer.append(msg);
});
```

Store it in `SessionInfo`:

```typescript
const session: SessionInfo = {
  // ... existing fields ...
  process: proc,
  replayBuffer,
};
```

- [ ] **Step 5: Add pty_data forwarding**

Add a listener for `pty_data` events that the websocket layer can use:

```typescript
proc.on("pty_data", (data: string) => {
  this.onMessage(sessionId, { type: "pty_output", sessionId, data } as any);
});
```

Note: `pty_output` is in the ServerMessage union (added in Task 3), so this will route through the normal broadcast path. The websocket layer will filter by `clientType`.

- [ ] **Step 6: Run type check and tests**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json && cd packages/bridge && npx vitest run
```
Expected: passes. Some existing session tests may need updates if they assert on the process type — update those to use `IProcessTransport`.

- [ ] **Step 7: Commit**

```bash
git add packages/bridge/src/session.ts
git commit -m "feat(bridge): SessionManager uses IProcessTransport + ReplayBuffer per session"
```

---

## Task 8: websocket.ts Dual Routing

**Files:**
- Modify: `packages/bridge/src/websocket.ts`

Handle `pty_input` and `pty_resize` messages from CLI clients. Route `pty_output` only to `"cli"` clients and structured events only to `"app"` clients. Support seq-based replay on `attach_session` with `lastSeq`.

- [ ] **Step 1: Handle pty_input message**

In the message handler `switch` statement in `websocket.ts`, add a case for `pty_input`:

```typescript
case "pty_input": {
  const session = this.resolveSession(msg.sessionId);
  if (!session) {
    this.send(ws, { type: "error", message: "Session not found" });
    return;
  }
  this.attachClient(session.id, ws);
  // Write raw bytes to PTY
  session.process.write(msg.data);
  break;
}
```

- [ ] **Step 2: Handle pty_resize message**

Add a case for `pty_resize`:

```typescript
case "pty_resize": {
  const session = this.resolveSession(msg.sessionId);
  if (!session) {
    this.send(ws, { type: "error", message: "Session not found" });
    return;
  }
  // PtyProcess has resize(), other processes don't
  if (session.process.isPty) {
    (session.process as any).resize(msg.cols, msg.rows);
  }
  break;
}
```

- [ ] **Step 3: Update broadcastSessionMessage to route by clientType**

Find the `broadcastSessionMessage` method. Currently it sends all messages to all attached clients. Add clientType-based routing:

```typescript
private broadcastSessionMessage(sessionId: string, msg: ServerMessage): void {
  // ... existing push notification + debug trace + recording logic stays ...

  const data = JSON.stringify({ ...msg, sessionId });
  const clients = this.sessionClients.get(sessionId);

  if (clients && clients.size > 0) {
    for (const [ws, info] of clients) {
      if (ws.readyState !== WebSocket.OPEN) continue;

      if (msg.type === "pty_output") {
        // Raw PTY bytes → only cli clients
        if (info.clientType === "cli") {
          ws.send(data);
        }
      } else {
        // Structured events → only app clients (and cli for backward compat messages like session_clients)
        // Note: cli clients in PTY mode don't need structured events — they see the raw terminal
        if (info.clientType !== "cli" || isMetaMessage(msg)) {
          ws.send(data);
        }
      }
    }
  } else {
    // Fallback broadcast (backward compat)
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }
}
```

Add the helper function:

```typescript
/** Messages that all client types need (session lifecycle, client presence). */
function isMetaMessage(msg: ServerMessage): boolean {
  return (
    msg.type === "session_clients" ||
    msg.type === "client_joined" ||
    msg.type === "client_left" ||
    msg.type === "error" ||
    (msg.type === "system" && (msg as any).subtype === "session_created")
  );
}
```

- [ ] **Step 4: Add seq-based replay on attach_session**

In the `attach_session` handler, after the existing history sending logic, add replay buffer support:

```typescript
case "attach_session": {
  // ... existing validation and attachClient call ...

  const session = this.sessionManager.get(msg.sessionId);
  if (!session) { /* error */ return; }

  if (msg.lastSeq !== undefined && msg.lastSeq > 0) {
    // Seq-based replay for reconnecting phone clients
    const { events, gap } = session.replayBuffer.replayWithGapInfo(msg.lastSeq);
    if (gap) {
      this.send(ws, { type: "history", messages: events.map((e) => e.msg), gap: true, sessionId: msg.sessionId } as any);
    } else {
      for (const event of events) {
        this.send(ws, { ...event.msg, sessionId: msg.sessionId, seq: event.seq } as any);
      }
    }
  } else if (msg.clientType !== "cli") {
    // First connect (no lastSeq) — send full history for app clients
    // Existing history logic stays here
  }
  // CLI clients don't get history — they see the live PTY stream
  break;
}
```

- [ ] **Step 5: Run type check and tests**

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json && cd packages/bridge && npx vitest run
```
Expected: passes. If existing websocket tests mock the process and expect all clients to receive all messages, they may need updating for the clientType routing.

- [ ] **Step 6: Commit**

```bash
git add packages/bridge/src/websocket.ts
git commit -m "feat(bridge): dual routing by clientType — PTY bytes to cli, structured events to app"
```

---

## Task 9: CLI Raw PTY Session

**Files:**
- Create: `packages/cli/src/pty-session.ts`
- Modify: `packages/cli/src/app.tsx`
- Modify: `packages/cli/src/index.ts`

Replace the Ink-based session view with raw terminal passthrough. When entering a session, Ink unmounts, stdin enters raw mode, and keystrokes flow as `pty_input` while `pty_output` flows to stdout. On Ctrl+D, terminal state is restored and Ink re-renders.

- [ ] **Step 1: Create pty-session.ts — raw PTY session handler**

Create `packages/cli/src/pty-session.ts`:

```typescript
import type { BridgeClient } from "./bridge-client.js";

/**
 * Run a raw PTY session — direct terminal passthrough.
 * Resolves when the user detaches (Ctrl+D) or the session ends.
 */
export async function runPtySession(
  client: BridgeClient,
  sessionId: string,
): Promise<void> {
  return new Promise<void>((resolve) => {
    const stdin = process.stdin;
    const stdout = process.stdout;

    // Attach to session as CLI client
    client.send({
      type: "attach_session",
      sessionId,
      clientType: "cli",
    });

    // Send terminal dimensions
    if (stdout.columns && stdout.rows) {
      client.send({
        type: "pty_resize",
        sessionId,
        cols: stdout.columns,
        rows: stdout.rows,
      });
    }

    // Enter raw mode
    const wasRaw = stdin.isRaw;
    if (stdin.isTTY) {
      stdin.setRawMode(true);
    }
    stdin.resume();

    // Forward keystrokes → bridge
    const onStdinData = (data: Buffer) => {
      // Ctrl+D (0x04) = detach
      if (data.length === 1 && data[0] === 0x04) {
        cleanup();
        return;
      }

      client.send({
        type: "pty_input",
        sessionId,
        data: data.toString("utf-8"),
      });
    };

    // Forward PTY output → terminal
    const onMessage = (msg: Record<string, unknown>) => {
      if (msg.sessionId !== sessionId) return;

      if (msg.type === "pty_output") {
        stdout.write(msg.data as string);
      }
    };

    // Handle terminal resize
    const onResize = () => {
      if (stdout.columns && stdout.rows) {
        client.send({
          type: "pty_resize",
          sessionId,
          cols: stdout.columns,
          rows: stdout.rows,
        });
      }
    };

    // Handle session end
    const onSessionEnd = (msg: Record<string, unknown>) => {
      if (msg.sessionId !== sessionId) return;
      if (
        msg.type === "status" &&
        (msg.status === "exited" || msg.status === "stopped")
      ) {
        cleanup();
      }
    };

    // Wire up listeners
    stdin.on("data", onStdinData);
    client.on("message", onMessage);
    client.on("message", onSessionEnd);
    stdout.on("resize", onResize);

    function cleanup() {
      // Restore terminal state
      stdin.off("data", onStdinData);
      client.off("message", onMessage);
      client.off("message", onSessionEnd);
      stdout.off("resize", onResize);

      if (stdin.isTTY) {
        stdin.setRawMode(wasRaw ?? false);
      }
      stdin.pause();

      // Detach from session
      client.send({ type: "detach_session", sessionId });

      // Clear screen and show cursor
      stdout.write("\x1b[2J\x1b[H\x1b[?25h");

      resolve();
    }
  });
}
```

- [ ] **Step 2: Update app.tsx — add onEnterRawSession callback**

In `packages/cli/src/app.tsx`, add an `onEnterRawSession` prop. When the user selects a session, call this callback instead of rendering the Ink SessionScreen:

```typescript
import React, { useState } from "react";
import { Box, Text, useApp } from "ink";
import type { BridgeClient } from "./bridge-client.js";
import { HomeScreen } from "./screens/home.js";
import { NewSessionScreen } from "./screens/new-session.js";

type Screen =
  | { name: "home" }
  | { name: "new-session" };

interface AppProps {
  client: BridgeClient;
  initialScreen?: { name: "home" } | { name: "new-session" };
  onEnterRawSession: (sessionId: string) => void;
}

export function App({ client, initialScreen, onEnterRawSession }: AppProps) {
  const [screen, setScreen] = useState<Screen>(initialScreen ?? { name: "home" });
  const { exit } = useApp();

  switch (screen.name) {
    case "home":
      return (
        <HomeScreen
          client={client}
          onAttach={(sessionId) => onEnterRawSession(sessionId)}
          onNew={() => setScreen({ name: "new-session" })}
          onQuit={() => exit()}
        />
      );
    case "new-session":
      return (
        <NewSessionScreen
          client={client}
          onCreated={(sessionId) => onEnterRawSession(sessionId)}
          onCancel={() => setScreen({ name: "home" })}
        />
      );
  }
}
```

Note: The `"session"` screen variant is removed from the `Screen` type — sessions are now handled by raw PTY passthrough outside of Ink.

- [ ] **Step 3: Update index.ts — Ink ↔ raw PTY loop**

Replace `packages/cli/src/index.ts` with a loop that alternates between Ink (home/new-session) and raw PTY sessions:

```typescript
import { Command } from "commander";
import { render } from "ink";
import React from "react";
import { App } from "./app.js";
import { BridgeClient } from "./bridge-client.js";
import { discoverBridge } from "./discovery.js";
import { runPtySession } from "./pty-session.js";

const program = new Command()
  .name("ccpocket")
  .description("Terminal client for CC Pocket")
  .version("0.1.0")
  .option("--url <url>", "Bridge WebSocket URL")
  .option("--api-key <key>", "Bridge API key");

program
  .command("attach <sessionId>")
  .description("Attach to a running session")
  .action(async (sessionId: string) => {
    const url = await resolveUrl(program.opts().url);
    if (!url) {
      console.error("Could not find bridge. Use --url to specify.");
      process.exit(1);
    }
    const client = new BridgeClient(url, program.opts().apiKey);

    // Wait for connection, then go straight to raw PTY session
    await new Promise<void>((resolve) => {
      client.on("open", () => resolve());
    });
    await runPtySession(client, sessionId);
    client.disconnect();
  });

program
  .command("start <path>")
  .description("Start a new session")
  .option("--provider <provider>", "Provider (claude/codex)", "claude")
  .action(async (path: string, opts: { provider: string }) => {
    const url = await resolveUrl(program.opts().url);
    if (!url) {
      console.error("Could not find bridge. Use --url to specify.");
      process.exit(1);
    }
    const client = new BridgeClient(url, program.opts().apiKey);

    // Wait for connection, start session, then enter raw PTY mode
    const sessionId = await new Promise<string>((resolve) => {
      client.on("open", () => {
        client.send({
          type: "start",
          projectPath: path,
          provider: opts.provider,
        });
      });
      client.on("message", (msg) => {
        if (
          msg.type === "system" &&
          msg.subtype === "session_created" &&
          msg.sessionId
        ) {
          resolve(msg.sessionId as string);
        }
      });
    });

    await runPtySession(client, sessionId);
    client.disconnect();
  });

// Default command: session picker with Ink ↔ raw PTY loop
program.action(async () => {
  const url = await resolveUrl(program.opts().url);
  if (!url) {
    console.error("Could not find bridge. Use --url to specify.");
    process.exit(1);
  }
  const client = new BridgeClient(url, program.opts().apiKey);

  // Loop: Ink screen → raw session → back to Ink
  let running = true;
  while (running) {
    const result = await new Promise<{ action: "session"; sessionId: string } | { action: "quit" }>(
      (resolve) => {
        const { unmount } = render(
          React.createElement(App, {
            client,
            onEnterRawSession: (sessionId: string) => {
              unmount();
              resolve({ action: "session", sessionId });
            },
          }),
        );
      },
    );

    if (result.action === "quit") {
      running = false;
    } else {
      await runPtySession(client, result.sessionId);
      // After raw session ends, loop back to Ink home screen
    }
  }

  client.disconnect();
});

async function resolveUrl(explicit?: string): Promise<string | null> {
  if (explicit) return explicit;
  console.log("  Discovering bridge...");
  const url = await discoverBridge();
  if (url) console.log(`  Found bridge at ${url}`);
  return url;
}

program.parse();
```

- [ ] **Step 4: Run type check**

```bash
npx tsc --noEmit -p packages/cli/tsconfig.json
```
Expected: passes. The old `SessionScreen` import is removed from `app.tsx`. The `session.tsx` file still exists but is no longer imported — leave it for rollback safety.

- [ ] **Step 5: Build and smoke test**

```bash
cd /Users/devlin/GitHub/ccpocket && npm run cli:build
```

Smoke test (requires bridge running):
```bash
node packages/cli/dist/index.js
```
Expected: Ink home screen appears. Select a session → Ink unmounts, raw PTY output streams. Ctrl+D → back to Ink home screen.

- [ ] **Step 6: Commit**

```bash
git add packages/cli/src/pty-session.ts packages/cli/src/app.tsx packages/cli/src/index.ts
git commit -m "feat(cli): raw PTY session passthrough — native CLI experience"
```

---

## Self-Review Checklist

### Spec coverage

| Spec requirement | Task |
|---|---|
| IProcessTransport interface | Task 1 |
| PtyProcess using node-pty | Task 5 |
| ANSI parser state machine | Task 4 |
| Provider profiles (Claude) | Task 4 |
| Graceful degradation | Task 4 (idle state fallback) |
| ReplayBuffer with seq tracking | Task 2 |
| New message types (pty_input/output/resize) | Task 3 |
| attach_session with lastSeq | Task 3 + Task 8 |
| Broadcasting by clientType | Task 8 |
| CLI raw PTY passthrough | Task 9 |
| SdkProcess/CodexProcess backward compat | Task 6 |
| SessionManager integration | Task 7 |
| Session ID capture | Task 4 (parser) + Task 5 (PtyProcess wiring) |
| Terminal resize propagation | Task 9 (pty-session.ts) + Task 8 (pty_resize handler) |
| Ctrl+D detach → Ink home | Task 9 |
| Remodex patterns (transport, replay, routing) | Tasks 1, 2, 8 |

### Not covered (future work)

- **Codex ANSI parser profile**: Claude profile implemented; Codex gets graceful degradation (raw text). Add Codex-specific patterns when format is captured.
- **Phone-side `lastSeq` tracking**: Bridge-side replay buffer is ready. The Flutter app needs to persist `lastSeq` per session and send it on reconnect — this is a mobile task.
- **Remove old SdkProcess/CodexProcess**: Keep during migration. Remove after PTY is stable in production.
- **E2E tests with real PTY**: Current tests mock node-pty. Add integration tests that spawn a real process after the basic flow is verified.

### Type consistency

- `IProcessTransport.start(opts: ProcessStartOptions)` — used in Task 1, 5, 6, 7 ✓
- `ReplayBuffer.append(msg: ServerMessage)` / `.replayWithGapInfo(lastSeq)` — used in Task 2, 7, 8 ✓
- `AnsiParser.feed(chunk)` / `.flush()` / `.on("message")` — used in Task 4, 5 ✓
- `PtyProcess.resize(cols, rows)` — used in Task 5, 8 ✓
- `ServerMessage` with `pty_output` type — added in Task 3, emitted in Task 7, routed in Task 8 ✓
- `ClientMessage` with `pty_input`, `pty_resize` types — added in Task 3, handled in Task 8 ✓
