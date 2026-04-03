# CC Pocket CLI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a terminal CLI package (`@ccpocket/cli`) and multi-client bridge support so phone and terminal can share live sessions.

**Architecture:** The CLI is a new `packages/cli/` package that connects to the existing bridge as a WebSocket client — the same way the Flutter app does. The bridge gets multi-client fan-out: sessions track a `Set<WebSocket>` of attached clients instead of broadcasting to all. New message types (`attach_session`, `detach_session`, `session_clients`, `client_joined`, `client_left`) coordinate multi-device presence. The CLI uses Ink (React for terminals) for the session picker and raw ANSI output for the session view.

**Tech Stack:** TypeScript, Ink + React, ws, bonjour-service, chalk, commander

**Spec:** `docs/superpowers/specs/2026-04-03-ccpocket-cli-design.md` (in prediction-markets-bot repo)

---

## File Structure

### Bridge changes (packages/bridge/)

| File | Action | Responsibility |
|------|--------|---------------|
| `src/parser.ts` | Modify | Add 5 new message types to `ClientMessage` and `ServerMessage` unions, extend `parseClientMessage` |
| `src/websocket.ts` | Modify | Track per-session client sets, route messages to attached clients, handle attach/detach/client presence |
| `src/session.ts` | No change | SessionManager stays as-is; client tracking lives in websocket.ts |
| `src/parser.test.ts` | Modify | Test parsing of new message types |
| `src/websocket.test.ts` | Modify | Test multi-client fan-out, attach/detach, first-responder approval |

### CLI package (packages/cli/)

| File | Action | Responsibility |
|------|--------|---------------|
| `package.json` | Create | Package config, bin entry, dependencies |
| `tsconfig.json` | Create | TypeScript config (ES2022, NodeNext, JSX react-jsx) |
| `bin/ccpocket.js` | Create | `#!/usr/bin/env node` entry shim |
| `src/index.ts` | Create | Entry point — arg parsing via commander, dispatches to screens |
| `src/bridge-client.ts` | Create | WebSocket connection, message send/receive, auto-reconnect, auth |
| `src/discovery.ts` | Create | mDNS listener + config fallback + manual URL |
| `src/config.ts` | Create | `~/.ccpocket/config.json` read/write |
| `src/renderer.ts` | Create | Bridge `ServerMessage` → ANSI terminal output (chalk) |
| `src/app.tsx` | Create | Ink root — screen router (home / new-session / session) |
| `src/screens/home.tsx` | Create | Session picker list (alternate screen) |
| `src/screens/new-session.tsx` | Create | Provider/path/mode prompts |
| `src/screens/session.tsx` | Create | Live session view (main screen, native scrollback) |
| `src/components/approval.tsx` | Create | Permission prompt (y/n/a) inline |
| `src/components/message.tsx` | Create | Assistant/tool output blocks |
| `src/components/status-bar.tsx` | Create | "also on: phone" indicator |
| `src/bridge-client.test.ts` | Create | WebSocket client unit tests |
| `src/config.test.ts` | Create | Config read/write tests |
| `src/renderer.test.ts` | Create | Message→ANSI rendering tests |
| `src/discovery.test.ts` | Create | Discovery fallback chain tests |

---

## Phase 1: Bridge Multi-Client Support

### Task 1: Add new message types to parser

**Files:**
- Modify: `packages/bridge/src/parser.ts`
- Modify: `packages/bridge/src/parser.test.ts`

- [ ] **Step 1: Write failing tests for new client→server message parsing**

In `packages/bridge/src/parser.test.ts`, add tests within the existing `describe("parseClientMessage", ...)` block:

```typescript
it("parses attach_session", () => {
  const msg = parseClientMessage(
    JSON.stringify({ type: "attach_session", sessionId: "abc123", clientType: "cli" }),
  );
  expect(msg).toEqual({ type: "attach_session", sessionId: "abc123", clientType: "cli" });
});

it("rejects attach_session without sessionId", () => {
  const msg = parseClientMessage(
    JSON.stringify({ type: "attach_session", clientType: "cli" }),
  );
  expect(msg).toBeNull();
});

it("parses attach_session with default clientType", () => {
  const msg = parseClientMessage(
    JSON.stringify({ type: "attach_session", sessionId: "abc123" }),
  );
  expect(msg).toEqual({ type: "attach_session", sessionId: "abc123" });
});

it("parses detach_session", () => {
  const msg = parseClientMessage(
    JSON.stringify({ type: "detach_session", sessionId: "abc123" }),
  );
  expect(msg).toEqual({ type: "detach_session", sessionId: "abc123" });
});

it("rejects detach_session without sessionId", () => {
  const msg = parseClientMessage(
    JSON.stringify({ type: "detach_session" }),
  );
  expect(msg).toBeNull();
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:bridge -- --run -t "attach_session|detach_session"`
Expected: FAIL — cases fall through to unknown message type

- [ ] **Step 3: Add new types to ClientMessage union**

In `packages/bridge/src/parser.ts`, add to the `ClientMessage` type union (after the `git_remote_status` entry):

```typescript
  | { type: "attach_session"; sessionId: string; clientType?: string }
  | { type: "detach_session"; sessionId: string };
```

- [ ] **Step 4: Add parsing cases to parseClientMessage**

In `packages/bridge/src/parser.ts`, inside `parseClientMessage`'s switch statement, add before the `default` case:

```typescript
      case "attach_session":
        if (typeof msg.sessionId !== "string") return null;
        if (msg.clientType !== undefined && typeof msg.clientType !== "string")
          return null;
        break;
      case "detach_session":
        if (typeof msg.sessionId !== "string") return null;
        break;
```

- [ ] **Step 5: Add new server→client message types to ServerMessage union**

In `packages/bridge/src/parser.ts`, add to the `ServerMessage` type union:

```typescript
  | {
      type: "session_clients";
      sessionId: string;
      clients: Array<{ clientId: string; clientType: string; connectedAt: string }>;
    }
  | {
      type: "client_joined";
      sessionId: string;
      client: { clientId: string; clientType: string };
    }
  | {
      type: "client_left";
      sessionId: string;
      client: { clientId: string; clientType: string };
    };
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:bridge -- --run -t "attach_session|detach_session"`
Expected: PASS

- [ ] **Step 7: Run full parser test suite**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:bridge -- --run src/parser.test.ts`
Expected: All tests PASS

- [ ] **Step 8: Type check**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc --noEmit -p packages/bridge/tsconfig.json`
Expected: No errors

- [ ] **Step 9: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/bridge/src/parser.ts packages/bridge/src/parser.test.ts
git commit -m "feat(bridge): add multi-client message types to parser

Add attach_session, detach_session (client→server) and
session_clients, client_joined, client_left (server→client)
message types for multi-device session support."
```

---

### Task 2: Multi-client session tracking in websocket.ts

**Files:**
- Modify: `packages/bridge/src/websocket.ts`

This task changes the bridge's message routing from "broadcast to all" to "send to attached clients per session." The key changes:

1. Add a `sessionClients` map: `Map<string, Map<WebSocket, { clientId: string; clientType: string; connectedAt: Date }>>`
2. On `start`/`resume_session`, auto-attach the requesting client
3. On `broadcastSessionMessage`, send only to clients in the session's set
4. Handle `attach_session` and `detach_session` messages
5. On WS disconnect, remove client from all sessions (session stays alive if other clients remain)

- [ ] **Step 1: Add client tracking data structures**

At the top of the `BridgeWebSocketServer` class (after the existing private fields around line 253), add:

```typescript
  /** Per-session client tracking for multi-device fan-out. */
  private sessionClients = new Map<
    string,
    Map<WebSocket, { clientId: string; clientType: string; connectedAt: Date }>
  >();
  private nextClientId = 0;
```

- [ ] **Step 2: Add helper methods for client management**

Add these private methods to `BridgeWebSocketServer` (before `broadcastSessionMessage`):

```typescript
  /** Generate a unique client ID for this bridge instance. */
  private generateClientId(): string {
    return `client-${++this.nextClientId}`;
  }

  /** Attach a WebSocket client to a session. Returns the clientId. */
  private attachClient(
    sessionId: string,
    ws: WebSocket,
    clientType: string = "app",
  ): string {
    let clients = this.sessionClients.get(sessionId);
    if (!clients) {
      clients = new Map();
      this.sessionClients.set(sessionId, clients);
    }

    // Check if this ws is already attached
    const existing = clients.get(ws);
    if (existing) return existing.clientId;

    const clientId = this.generateClientId();
    clients.set(ws, { clientId, clientType, connectedAt: new Date() });

    // Notify other attached clients
    const joinMsg = JSON.stringify({
      type: "client_joined",
      sessionId,
      client: { clientId, clientType },
    });
    for (const [otherWs] of clients) {
      if (otherWs !== ws && otherWs.readyState === WebSocket.OPEN) {
        otherWs.send(joinMsg);
      }
    }

    // Send current client list to the newly attached client
    const clientList = Array.from(clients.values()).map((c) => ({
      clientId: c.clientId,
      clientType: c.clientType,
      connectedAt: c.connectedAt.toISOString(),
    }));
    this.send(ws, { type: "session_clients", sessionId, clients: clientList });

    return clientId;
  }

  /** Detach a WebSocket client from a session. */
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

    // Clean up empty session client maps
    if (clients.size === 0) {
      this.sessionClients.delete(sessionId);
    }
  }

  /** Detach a WebSocket client from ALL sessions (on disconnect). */
  private detachClientFromAll(ws: WebSocket): void {
    for (const sessionId of this.sessionClients.keys()) {
      this.detachClient(sessionId, ws);
    }
  }
```

- [ ] **Step 3: Update broadcastSessionMessage for per-session routing**

Replace the current `broadcastSessionMessage` method (around line 3414). The new version sends to attached clients first, then falls back to broadcasting to all if no clients are attached (backward compatibility with the Flutter app which doesn't send `attach_session` yet):

```typescript
  private broadcastSessionMessage(sessionId: string, msg: ServerMessage): void {
    this.maybeSendPushNotification(sessionId, msg);
    this.recordDebugEvent(sessionId, {
      direction: "outgoing",
      channel: "session",
      type: msg.type,
      detail: this.summarizeServerMessage(msg),
    });
    this.recordingStore?.record(sessionId, "outgoing", msg);

    // Update recording meta with claudeSessionId when it becomes available
    if (
      (msg.type === "system" || msg.type === "result") &&
      "sessionId" in msg &&
      msg.sessionId
    ) {
      const session = this.sessionManager.get(sessionId);
      if (session) {
        this.recordingStore?.saveMeta(sessionId, {
          bridgeSessionId: sessionId,
          claudeSessionId: msg.sessionId as string,
          projectPath: session.projectPath,
          createdAt: session.createdAt.toISOString(),
        });
      }
    }

    const data = JSON.stringify({ ...msg, sessionId });
    const clients = this.sessionClients.get(sessionId);

    if (clients && clients.size > 0) {
      // Send to attached clients only
      for (const [ws] of clients) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(data);
        }
      }
    } else {
      // Fallback: broadcast to all (backward compat for apps that don't attach)
      for (const client of this.wss.clients) {
        if (client.readyState === WebSocket.OPEN) {
          client.send(data);
        }
      }
    }
  }
```

- [ ] **Step 4: Auto-attach clients on session start**

In `handleClientMessage`, in the `case "start"` block, after the session is created and `session_created` is sent (search for `this.broadcastSessionList()` after start), add:

```typescript
          // Auto-attach the requesting client
          this.attachClient(sessionId, ws);
```

Do the same in the `case "resume_session"` block, after the session is created.

- [ ] **Step 5: Handle attach_session and detach_session messages**

In `handleClientMessage`'s switch statement, add new cases (before the default):

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

        // Send session_created so the client has full session metadata
        const createdMsg = this.buildSessionCreatedMessage({
          sessionId: msg.sessionId,
          provider: session.provider,
          projectPath: session.projectPath,
          session,
        });
        this.send(ws, createdMsg);

        // Send current history so the attaching client catches up
        if (session.pastMessages && session.pastMessages.length > 0) {
          this.send(ws, {
            type: "past_history",
            claudeSessionId: session.claudeSessionId ?? msg.sessionId,
            messages: session.pastMessages,
          } as Record<string, unknown>);
        }
        this.send(ws, {
          type: "history",
          messages: session.history,
          sessionId: msg.sessionId,
        } as Record<string, unknown>);

        break;
      }

      case "detach_session": {
        this.detachClient(msg.sessionId, ws);
        break;
      }
```

- [ ] **Step 6: Clean up on WebSocket disconnect**

In `handleConnection`, update the `ws.on("close", ...)` handler (around line 542):

```typescript
    ws.on("close", () => {
      console.log("[ws] Client disconnected");
      this.detachClientFromAll(ws);
    });
```

- [ ] **Step 7: Clean up session clients when session is destroyed**

In `handleClientMessage`, in the `case "stop_session"` block, after `this.sessionManager.destroy(msg.sessionId)`, add:

```typescript
          this.sessionClients.delete(msg.sessionId);
```

- [ ] **Step 8: Type check**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc --noEmit -p packages/bridge/tsconfig.json`
Expected: No errors

- [ ] **Step 9: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/bridge/src/websocket.ts
git commit -m "feat(bridge): multi-client session tracking and fan-out

Sessions now track attached WebSocket clients via a per-session
client set. Messages route to attached clients instead of broadcasting
to all. Falls back to broadcast for backward compatibility with apps
that don't send attach_session.

New message handling: attach_session, detach_session with client
presence notifications (client_joined, client_left, session_clients)."
```

---

### Task 3: Bridge multi-client tests

**Files:**
- Modify: `packages/bridge/src/websocket.test.ts`

- [ ] **Step 1: Read existing websocket tests to understand the pattern**

Run: `head -80 packages/bridge/src/websocket.test.ts` to see how the test file sets up mocks. Follow the same patterns.

- [ ] **Step 2: Write multi-client fan-out tests**

Add a new `describe("multi-client sessions", ...)` block at the end of the test file. The test approach depends on the existing test patterns (mock WebSocket, mock SessionManager, or integration-style). Write tests for:

```typescript
describe("multi-client sessions", () => {
  it("attach_session sends history and session_clients to new client", async () => {
    // 1. Client A starts a session (gets auto-attached)
    // 2. Client B sends attach_session
    // 3. Client B receives session_created, history, and session_clients
    // 4. Client A receives client_joined
  });

  it("detach_session removes client without stopping session", async () => {
    // 1. Client A and B attached to session
    // 2. Client A sends detach_session
    // 3. Client B receives client_left
    // 4. Session still active
  });

  it("session messages route only to attached clients", async () => {
    // 1. Client A attached to session 1
    // 2. Client B NOT attached to session 1
    // 3. Session 1 produces a message
    // 4. Client A receives it, Client B does not
  });

  it("first approval wins — subsequent clients see tool proceed", async () => {
    // 1. Client A and B attached
    // 2. Session sends permission_request
    // 3. Client A sends approve
    // 4. Both clients see the tool proceed (via normal message fan-out)
  });

  it("ws disconnect removes client from all sessions", async () => {
    // 1. Client attached to session
    // 2. Client disconnects (ws close)
    // 3. Session client list is empty
  });

  it("fallback broadcast when no clients explicitly attached", async () => {
    // 1. Session exists but no attach_session was sent
    // 2. Session produces message
    // 3. All connected ws clients receive it (backward compat)
  });
});
```

Note: The exact test implementation depends on how the existing `websocket.test.ts` mocks the WebSocket server. Follow the existing patterns. Use `vi.fn()` for WebSocket `send` methods.

- [ ] **Step 3: Run the tests**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:bridge -- --run -t "multi-client"`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/bridge/src/websocket.test.ts
git commit -m "test(bridge): multi-client session tracking tests

Tests for attach/detach, per-session message routing, first-responder
approval, disconnect cleanup, and backward-compat broadcast fallback."
```

---

## Phase 2: CLI Package Scaffold

### Task 4: CLI package setup

**Files:**
- Create: `packages/cli/package.json`
- Create: `packages/cli/tsconfig.json`
- Create: `packages/cli/bin/ccpocket.js`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "@ccpocket/cli",
  "version": "0.1.0",
  "description": "Terminal client for CC Pocket — attach to live Claude/Codex sessions from your terminal",
  "type": "module",
  "license": "MIT",
  "author": "K9i",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/K9i-0/ccpocket.git",
    "directory": "packages/cli"
  },
  "bin": {
    "ccpocket": "./bin/ccpocket.js"
  },
  "main": "dist/index.js",
  "files": ["dist", "bin"],
  "engines": {
    "node": ">=18.0.0"
  },
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "ink": "^5.1.0",
    "ink-text-input": "^6.0.0",
    "react": "^18.3.1",
    "ws": "^8.18.0",
    "bonjour-service": "^1.3.0",
    "chalk": "^5.4.1",
    "commander": "^13.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^18.3.0",
    "@types/ws": "^8.5.0",
    "tsx": "^4.19.0",
    "typescript": "^5.7.0",
    "vitest": "^4.0.18"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "sourceMap": true,
    "jsx": "react-jsx"
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "src/**/*.test.ts"]
}
```

- [ ] **Step 3: Create bin/ccpocket.js entry shim**

```javascript
#!/usr/bin/env node
import("../dist/index.js");
```

- [ ] **Step 4: Install dependencies**

Run: `cd /Users/devlin/GitHub/ccpocket && npm install`
Expected: Workspaces resolve, packages/cli dependencies installed

- [ ] **Step 5: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/package.json packages/cli/tsconfig.json packages/cli/bin/ccpocket.js package-lock.json
git commit -m "feat(cli): scaffold @ccpocket/cli package

Package setup with Ink, React, ws, commander, chalk, bonjour-service.
Bin entry at ccpocket → bin/ccpocket.js."
```

---

### Task 5: Config module

**Files:**
- Create: `packages/cli/src/config.ts`
- Create: `packages/cli/src/config.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/cli/src/config.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";

const fakeFiles = new Map<string, string>();

vi.mock("node:fs", () => ({
  existsSync: vi.fn((p: string) => fakeFiles.has(p)),
  readFileSync: vi.fn((p: string) => {
    const c = fakeFiles.get(p);
    if (!c) throw new Error("ENOENT");
    return c;
  }),
  mkdirSync: vi.fn(),
  writeFileSync: vi.fn(),
}));

vi.mock("node:os", () => ({
  homedir: () => "/mock-home",
}));

import { loadConfig, saveConfig, type Config } from "./config.js";

describe("config", () => {
  beforeEach(() => {
    fakeFiles.clear();
  });

  it("returns defaults when no config file exists", () => {
    const config = loadConfig();
    expect(config.bridgeUrl).toBeUndefined();
    expect(config.defaultProvider).toBe("claude");
  });

  it("reads existing config file", () => {
    fakeFiles.set(
      "/mock-home/.ccpocket/config.json",
      JSON.stringify({ bridgeUrl: "ws://10.0.0.1:8765", defaultProvider: "codex" }),
    );
    const config = loadConfig();
    expect(config.bridgeUrl).toBe("ws://10.0.0.1:8765");
    expect(config.defaultProvider).toBe("codex");
  });

  it("returns defaults on malformed JSON", () => {
    fakeFiles.set("/mock-home/.ccpocket/config.json", "not json");
    const config = loadConfig();
    expect(config.defaultProvider).toBe("claude");
  });
});
```

- [ ] **Step 2: Create vitest.config.ts for CLI package**

Create `packages/cli/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "config"`
Expected: FAIL — module not found

- [ ] **Step 4: Implement config module**

Create `packages/cli/src/config.ts`:

```typescript
import { existsSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";

export interface Config {
  bridgeUrl?: string;
  remoteBridgeUrl?: string;
  defaultProvider: "claude" | "codex";
  defaultPermissionMode: "default" | "acceptEdits" | "bypassPermissions" | "plan";
}

const CONFIG_PATH = join(homedir(), ".ccpocket", "config.json");

const DEFAULTS: Config = {
  defaultProvider: "claude",
  defaultPermissionMode: "default",
};

export function loadConfig(): Config {
  try {
    if (!existsSync(CONFIG_PATH)) return { ...DEFAULTS };
    const raw = readFileSync(CONFIG_PATH, "utf-8");
    const parsed = JSON.parse(raw) as Partial<Config>;
    return { ...DEFAULTS, ...parsed };
  } catch {
    return { ...DEFAULTS };
  }
}

export function saveConfig(config: Partial<Config>): void {
  const existing = loadConfig();
  const merged = { ...existing, ...config };
  const dir = dirname(CONFIG_PATH);
  mkdirSync(dir, { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(merged, null, 2) + "\n", "utf-8");
}

export function getConfigPath(): string {
  return CONFIG_PATH;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "config"`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/config.ts packages/cli/src/config.test.ts packages/cli/vitest.config.ts
git commit -m "feat(cli): config module for ~/.ccpocket/config.json

Read/write bridge URL, default provider, permission mode.
Falls back to sensible defaults when file is missing or malformed."
```

---

### Task 6: Bridge client (WebSocket connection)

**Files:**
- Create: `packages/cli/src/bridge-client.ts`
- Create: `packages/cli/src/bridge-client.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/cli/src/bridge-client.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { EventEmitter } from "node:events";

// Mock ws module
const mockWsInstances: Array<EventEmitter & { send: ReturnType<typeof vi.fn>; close: ReturnType<typeof vi.fn>; readyState: number }> = [];

vi.mock("ws", () => {
  const OPEN = 1;
  class MockWebSocket extends EventEmitter {
    readyState = OPEN;
    send = vi.fn();
    close = vi.fn();
    static OPEN = OPEN;
    constructor() {
      super();
      mockWsInstances.push(this as any);
      // Simulate connection
      setTimeout(() => this.emit("open"), 0);
    }
  }
  return { WebSocket: MockWebSocket, default: { WebSocket: MockWebSocket } };
});

import { BridgeClient } from "./bridge-client.js";

describe("BridgeClient", () => {
  beforeEach(() => {
    mockWsInstances.length = 0;
  });

  it("connects to bridge URL", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    expect(mockWsInstances).toHaveLength(1);
    client.disconnect();
  });

  it("sends messages as JSON", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    client.send({ type: "list_sessions" });
    expect(mockWsInstances[0].send).toHaveBeenCalledWith(
      JSON.stringify({ type: "list_sessions" }),
    );
    client.disconnect();
  });

  it("emits parsed messages", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    const messages: unknown[] = [];
    client.on("message", (msg) => messages.push(msg));
    mockWsInstances[0].emit("message", JSON.stringify({ type: "session_list", sessions: [] }));
    expect(messages).toHaveLength(1);
    expect((messages[0] as any).type).toBe("session_list");
    client.disconnect();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "BridgeClient"`
Expected: FAIL — module not found

- [ ] **Step 3: Implement bridge client**

Create `packages/cli/src/bridge-client.ts`:

```typescript
import { EventEmitter } from "node:events";
import { WebSocket } from "ws";

export interface BridgeClientEvents {
  message: [msg: Record<string, unknown>];
  open: [];
  close: [code: number, reason: string];
  error: [err: Error];
}

export class BridgeClient extends EventEmitter<BridgeClientEvents> {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private shouldReconnect = true;

  constructor(url: string, apiKey?: string) {
    super();
    this.url = apiKey ? `${url}?token=${encodeURIComponent(apiKey)}` : url;
    this.connect();
  }

  private connect(): void {
    this.ws = new WebSocket(this.url);

    this.ws.on("open", () => {
      this.emit("open");
    });

    this.ws.on("message", (data) => {
      try {
        const msg = JSON.parse(data.toString()) as Record<string, unknown>;
        this.emit("message", msg);
      } catch {
        // ignore malformed messages
      }
    });

    this.ws.on("close", (code, reason) => {
      this.emit("close", code, reason.toString());
      if (this.shouldReconnect) {
        this.reconnectTimer = setTimeout(() => this.connect(), 3000);
      }
    });

    this.ws.on("error", (err) => {
      this.emit("error", err);
    });
  }

  send(msg: Record<string, unknown>): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msg));
    }
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.ws?.close();
    this.ws = null;
  }

  get connected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "BridgeClient"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/bridge-client.ts packages/cli/src/bridge-client.test.ts
git commit -m "feat(cli): WebSocket bridge client with auto-reconnect

EventEmitter-based client that connects to bridge, parses JSON messages,
and auto-reconnects on disconnect. Supports API key auth via query param."
```

---

### Task 7: mDNS discovery

**Files:**
- Create: `packages/cli/src/discovery.ts`
- Create: `packages/cli/src/discovery.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/cli/src/discovery.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("./config.js", () => ({
  loadConfig: vi.fn(() => ({})),
}));

let mockBonjourCallback: ((service: { addresses: string[]; port: number }) => void) | null = null;

vi.mock("bonjour-service", () => ({
  Bonjour: class {
    find(opts: unknown, cb: (service: { addresses: string[]; port: number }) => void) {
      mockBonjourCallback = cb;
      return { stop: vi.fn() };
    }
    destroy() {}
  },
}));

import { discoverBridge } from "./discovery.js";
import { loadConfig } from "./config.js";

describe("discoverBridge", () => {
  beforeEach(() => {
    mockBonjourCallback = null;
  });

  it("returns saved config URL first", async () => {
    vi.mocked(loadConfig).mockReturnValue({
      bridgeUrl: "ws://saved:8765",
      defaultProvider: "claude",
      defaultPermissionMode: "default",
    });
    const url = await discoverBridge();
    expect(url).toBe("ws://saved:8765");
  });

  it("falls back to mDNS discovery", async () => {
    vi.mocked(loadConfig).mockReturnValue({
      defaultProvider: "claude",
      defaultPermissionMode: "default",
    });
    const promise = discoverBridge(2000);
    // Simulate mDNS finding a service
    setTimeout(() => {
      mockBonjourCallback?.({ addresses: ["10.0.0.5"], port: 8765 });
    }, 50);
    const url = await promise;
    expect(url).toBe("ws://10.0.0.5:8765");
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "discoverBridge"`
Expected: FAIL — module not found

- [ ] **Step 3: Implement discovery module**

Create `packages/cli/src/discovery.ts`:

```typescript
import { Bonjour } from "bonjour-service";
import { loadConfig } from "./config.js";

/**
 * Discover the bridge URL. Priority:
 * 1. Saved config (bridgeUrl)
 * 2. mDNS (_ccpocket._tcp)
 * 3. null (not found)
 */
export async function discoverBridge(timeoutMs = 5000): Promise<string | null> {
  // 1. Check saved config
  const config = loadConfig();
  if (config.bridgeUrl) return config.bridgeUrl;

  // 2. mDNS discovery
  return new Promise<string | null>((resolve) => {
    const bonjour = new Bonjour();
    let resolved = false;

    const browser = bonjour.find({ type: "ccpocket" }, (service) => {
      if (resolved) return;
      resolved = true;
      browser.stop();
      bonjour.destroy();

      const addr = service.addresses?.[0];
      const port = service.port ?? 8765;
      if (addr) {
        resolve(`ws://${addr}:${port}`);
      } else {
        resolve(null);
      }
    });

    setTimeout(() => {
      if (resolved) return;
      resolved = true;
      browser.stop();
      bonjour.destroy();

      // 3. Try remoteBridgeUrl from config as last resort
      if (config.remoteBridgeUrl) {
        resolve(config.remoteBridgeUrl);
      } else {
        resolve(null);
      }
    }, timeoutMs);
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "discoverBridge"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/discovery.ts packages/cli/src/discovery.test.ts
git commit -m "feat(cli): bridge discovery via saved config + mDNS

Tries saved bridgeUrl first, then mDNS _ccpocket._tcp, then
remoteBridgeUrl fallback. 5s timeout on mDNS scan."
```

---

### Task 8: Message renderer (bridge messages → ANSI)

**Files:**
- Create: `packages/cli/src/renderer.ts`
- Create: `packages/cli/src/renderer.test.ts`

- [ ] **Step 1: Write failing tests**

Create `packages/cli/src/renderer.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { renderMessage } from "./renderer.js";

describe("renderMessage", () => {
  it("renders assistant text", () => {
    const output = renderMessage({
      type: "assistant",
      message: {
        id: "1",
        role: "assistant",
        content: [{ type: "text", text: "Hello world" }],
        model: "claude-opus-4-6",
      },
    });
    expect(output).toContain("Hello world");
  });

  it("renders tool_use with name and indented input", () => {
    const output = renderMessage({
      type: "assistant",
      message: {
        id: "2",
        role: "assistant",
        content: [{
          type: "tool_use",
          id: "tu1",
          name: "Read",
          input: { file_path: "/src/main.ts" },
        }],
        model: "claude-opus-4-6",
      },
    });
    expect(output).toContain("Read");
    expect(output).toContain("/src/main.ts");
  });

  it("renders tool_result content", () => {
    const output = renderMessage({
      type: "tool_result",
      toolUseId: "tu1",
      content: "file contents here",
    });
    expect(output).toContain("file contents here");
  });

  it("renders permission_request", () => {
    const output = renderMessage({
      type: "permission_request",
      toolUseId: "tu1",
      toolName: "Edit",
      input: { file_path: "/src/app.ts" },
    });
    expect(output).toContain("Edit");
    expect(output).toContain("/src/app.ts");
  });

  it("renders status messages", () => {
    const output = renderMessage({ type: "status", status: "running" });
    expect(output).toContain("running");
  });

  it("renders errors", () => {
    const output = renderMessage({ type: "error", message: "Something broke" });
    expect(output).toContain("Something broke");
  });

  it("returns empty string for stream_delta (handled separately)", () => {
    const output = renderMessage({ type: "stream_delta", text: "partial" });
    expect(output).toBe("");
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "renderMessage"`
Expected: FAIL

- [ ] **Step 3: Implement renderer**

Create `packages/cli/src/renderer.ts`:

```typescript
import chalk from "chalk";

type ServerMsg = Record<string, unknown>;

/**
 * Convert a bridge ServerMessage into formatted ANSI terminal output.
 * Returns empty string for messages that should be handled differently
 * (e.g., stream_delta is written char-by-char, permission_request needs interactive prompt).
 */
export function renderMessage(msg: ServerMsg): string {
  switch (msg.type) {
    case "assistant":
      return renderAssistant(msg);
    case "tool_result":
      return renderToolResult(msg);
    case "permission_request":
      return renderPermissionRequest(msg);
    case "status":
      return chalk.dim(`  ─ ${msg.status} ─`);
    case "error":
      return chalk.red(`✗ Error: ${msg.message}`);
    case "result":
      return renderResult(msg);
    case "user_input":
      return chalk.bold.blue(`\n> ${msg.text}\n`);
    case "stream_delta":
    case "thinking_delta":
      return ""; // Handled via streaming write
    default:
      return "";
  }
}

function renderAssistant(msg: ServerMsg): string {
  const message = msg.message as {
    content: Array<{ type: string; text?: string; name?: string; input?: Record<string, unknown>; thinking?: string }>;
  };
  const parts: string[] = [];

  for (const block of message.content) {
    switch (block.type) {
      case "text":
        parts.push(`\n${chalk.bold("⏺")} ${block.text}\n`);
        break;
      case "tool_use":
        parts.push(renderToolUse(block.name!, block.input!));
        break;
      case "thinking":
        // Thinking blocks are typically hidden; show dimmed summary
        if (block.thinking) {
          const preview = block.thinking.slice(0, 100).replace(/\n/g, " ");
          parts.push(chalk.dim(`  💭 ${preview}${block.thinking.length > 100 ? "..." : ""}`));
        }
        break;
    }
  }
  return parts.join("\n");
}

function renderToolUse(name: string, input: Record<string, unknown>): string {
  const header = chalk.cyan(`  ⎿ ${name}`);

  // Format common tool inputs nicely
  if (name === "Read" || name === "Write" || name === "Edit") {
    const path = input.file_path ?? input.path ?? "";
    return `${header} ${chalk.dim(String(path))}`;
  }
  if (name === "Bash") {
    const cmd = input.command ?? "";
    return `${header}\n    ${chalk.dim(String(cmd))}`;
  }
  if (name === "Grep") {
    return `${header} ${chalk.dim(`pattern="${input.pattern}"`)}`;
  }

  // Generic: show first key-value
  const entries = Object.entries(input).slice(0, 2);
  const summary = entries.map(([k, v]) => `${k}=${JSON.stringify(v)}`).join(" ");
  return `${header} ${chalk.dim(summary.slice(0, 120))}`;
}

function renderToolResult(msg: ServerMsg): string {
  const content = String(msg.content ?? "");
  const toolName = msg.toolName ? chalk.dim(` (${msg.toolName})`) : "";
  if (!content.trim()) return "";

  // Truncate very long results
  const maxLines = 20;
  const lines = content.split("\n");
  const truncated = lines.length > maxLines;
  const shown = lines.slice(0, maxLines).join("\n");

  return `${chalk.dim("  ⎿")}${toolName}\n${indent(shown, 4)}${truncated ? chalk.dim(`\n    ... (${lines.length - maxLines} more lines)`) : ""}`;
}

function renderPermissionRequest(msg: ServerMsg): string {
  const tool = String(msg.toolName ?? "unknown");
  const input = msg.input as Record<string, unknown> | undefined;
  const path = input?.file_path ?? input?.command ?? "";
  return `\n${chalk.yellow.bold("⚠ Permission required:")} ${chalk.bold(tool)}${path ? ` ${chalk.dim(String(path))}` : ""}`;
}

function renderResult(msg: ServerMsg): string {
  const parts: string[] = [];
  if (msg.cost != null) {
    parts.push(`Cost: $${(msg.cost as number).toFixed(4)}`);
  }
  if (msg.duration != null) {
    const secs = ((msg.duration as number) / 1000).toFixed(1);
    parts.push(`Duration: ${secs}s`);
  }
  if (parts.length === 0) return "";
  return chalk.dim(`\n  ─ ${parts.join(" · ")} ─\n`);
}

function indent(text: string, spaces: number): string {
  const pad = " ".repeat(spaces);
  return text
    .split("\n")
    .map((line) => pad + line)
    .join("\n");
}

/**
 * Render a diff-style edit block with red/green coloring.
 */
export function renderDiff(oldStr: string, newStr: string): string {
  const lines: string[] = [];
  for (const line of oldStr.split("\n")) {
    lines.push(chalk.red(`- ${line}`));
  }
  for (const line of newStr.split("\n")) {
    lines.push(chalk.green(`+ ${line}`));
  }
  return lines.join("\n");
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npx vitest run -t "renderMessage"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/renderer.ts packages/cli/src/renderer.test.ts
git commit -m "feat(cli): bridge message renderer with ANSI formatting

Converts ServerMessage types to terminal output: assistant text,
tool_use with smart formatting per tool name, tool_result with
truncation, permission requests, status, errors, and result summaries."
```

---

## Phase 3: CLI Screens (Ink Components)

### Task 9: Ink app shell and screen router

**Files:**
- Create: `packages/cli/src/app.tsx`
- Create: `packages/cli/src/index.ts`

- [ ] **Step 1: Create the app shell with screen routing**

Create `packages/cli/src/app.tsx`:

```tsx
import React, { useState } from "react";
import { Box, Text, useApp } from "ink";
import type { BridgeClient } from "./bridge-client.js";
import { HomeScreen } from "./screens/home.js";
import { SessionScreen } from "./screens/session.js";
import { NewSessionScreen } from "./screens/new-session.js";

type Screen =
  | { name: "home" }
  | { name: "session"; sessionId: string }
  | { name: "new-session" };

interface AppProps {
  client: BridgeClient;
  initialScreen?: Screen;
}

export function App({ client, initialScreen }: AppProps) {
  const [screen, setScreen] = useState<Screen>(initialScreen ?? { name: "home" });
  const { exit } = useApp();

  switch (screen.name) {
    case "home":
      return (
        <HomeScreen
          client={client}
          onAttach={(sessionId) => setScreen({ name: "session", sessionId })}
          onNew={() => setScreen({ name: "new-session" })}
          onQuit={() => exit()}
        />
      );
    case "session":
      return (
        <SessionScreen
          client={client}
          sessionId={screen.sessionId}
          onDetach={() => setScreen({ name: "home" })}
        />
      );
    case "new-session":
      return (
        <NewSessionScreen
          client={client}
          onCreated={(sessionId) => setScreen({ name: "session", sessionId })}
          onCancel={() => setScreen({ name: "home" })}
        />
      );
  }
}
```

- [ ] **Step 2: Create the CLI entry point**

Create `packages/cli/src/index.ts`:

```typescript
import { Command } from "commander";
import { render } from "ink";
import React from "react";
import { App } from "./app.js";
import { BridgeClient } from "./bridge-client.js";
import { discoverBridge } from "./discovery.js";
import { loadConfig } from "./config.js";

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
    render(
      React.createElement(App, {
        client,
        initialScreen: { name: "session", sessionId },
      }),
    );
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
    // Wait for connection, then start session
    client.on("open", () => {
      client.send({
        type: "start",
        projectPath: path,
        provider: opts.provider,
      });
    });
    // The session_created response will contain the sessionId
    client.on("message", (msg) => {
      if (msg.type === "system" && msg.subtype === "session_created" && msg.sessionId) {
        render(
          React.createElement(App, {
            client,
            initialScreen: { name: "session", sessionId: msg.sessionId as string },
          }),
        );
      }
    });
  });

// Default command: show session picker
program.action(async () => {
  const url = await resolveUrl(program.opts().url);
  if (!url) {
    console.error("Could not find bridge. Use --url to specify.");
    process.exit(1);
  }
  const client = new BridgeClient(url, program.opts().apiKey);
  render(React.createElement(App, { client }));
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

- [ ] **Step 3: Type check**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc --noEmit -p packages/cli/tsconfig.json`
Expected: Errors about missing screen components (expected — we create those next)

- [ ] **Step 4: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/app.tsx packages/cli/src/index.ts
git commit -m "feat(cli): app shell with screen router and CLI entry point

Commander-based CLI with subcommands: attach, start, and default
session picker. Ink-based React app with home/session/new-session screens."
```

---

### Task 10: Home screen (session picker)

**Files:**
- Create: `packages/cli/src/screens/home.tsx`

- [ ] **Step 1: Implement the session picker**

Create `packages/cli/src/screens/home.tsx`:

```tsx
import React, { useState, useEffect } from "react";
import { Box, Text, useInput, useApp } from "ink";
import type { BridgeClient } from "../bridge-client.js";

interface Session {
  id: string;
  provider: string;
  projectPath: string;
  name?: string;
  status: string;
  lastActivityAt: string;
  lastMessage: string;
}

interface HomeScreenProps {
  client: BridgeClient;
  onAttach: (sessionId: string) => void;
  onNew: () => void;
  onQuit: () => void;
}

export function HomeScreen({ client, onAttach, onNew, onQuit }: HomeScreenProps) {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const { exit } = useApp();

  useEffect(() => {
    const handler = (msg: Record<string, unknown>) => {
      if (msg.type === "session_list" && Array.isArray(msg.sessions)) {
        setSessions(msg.sessions as Session[]);
      }
    };
    client.on("message", handler);
    // Request session list
    client.send({ type: "list_sessions" });
    return () => {
      client.off("message", handler);
    };
  }, [client]);

  useInput((input, key) => {
    if (input === "q") {
      onQuit();
      exit();
      return;
    }
    if (input === "n") {
      onNew();
      return;
    }
    if (input === "a" || key.return) {
      if (sessions[selectedIndex]) {
        onAttach(sessions[selectedIndex].id);
      }
      return;
    }
    if (key.upArrow) {
      setSelectedIndex((i) => Math.max(0, i - 1));
    }
    if (key.downArrow) {
      setSelectedIndex((i) => Math.min(sessions.length - 1, i + 1));
    }
  });

  return (
    <Box flexDirection="column" padding={1}>
      <Text bold>CC Pocket — Sessions</Text>
      <Text dimColor>{""}</Text>
      {sessions.length === 0 ? (
        <Text dimColor>  No active sessions. Press [n] to start one.</Text>
      ) : (
        sessions.map((s, i) => {
          const selected = i === selectedIndex;
          const icon = s.status === "idle" ? "○" : "●";
          const name = s.name ?? s.projectPath.split("/").pop() ?? s.projectPath;
          const age = formatAge(s.lastActivityAt);
          const provider = s.provider === "codex" ? "Codex" : "Claude";
          return (
            <Text key={s.id}>
              {selected ? "❯ " : "  "}
              {icon} {name} ({provider}, {age})
              {s.lastMessage ? ` — ${s.lastMessage.slice(0, 50)}` : ""}
            </Text>
          );
        })
      )}
      <Text dimColor>{""}</Text>
      <Text dimColor>  [a]ttach  [n]ew  [q]uit</Text>
    </Box>
  );
}

function formatAge(isoDate: string): string {
  const diff = Date.now() - new Date(isoDate).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
```

- [ ] **Step 2: Type check**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc --noEmit -p packages/cli/tsconfig.json 2>&1 | head -20`
Expected: May have errors for missing session/new-session screens (expected)

- [ ] **Step 3: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/screens/home.tsx
git commit -m "feat(cli): session picker home screen

Lists active sessions with provider, age, and last message.
Arrow keys to select, [a]ttach, [n]ew session, [q]uit."
```

---

### Task 11: New session screen

**Files:**
- Create: `packages/cli/src/screens/new-session.tsx`

- [ ] **Step 1: Implement new session prompts**

Create `packages/cli/src/screens/new-session.tsx`:

```tsx
import React, { useState } from "react";
import { Box, Text, useInput } from "ink";
import TextInput from "ink-text-input";
import type { BridgeClient } from "../bridge-client.js";
import { loadConfig } from "../config.js";

interface NewSessionScreenProps {
  client: BridgeClient;
  onCreated: (sessionId: string) => void;
  onCancel: () => void;
}

type Step = "path" | "provider" | "starting";

export function NewSessionScreen({ client, onCreated, onCancel }: NewSessionScreenProps) {
  const config = loadConfig();
  const [step, setStep] = useState<Step>("path");
  const [projectPath, setProjectPath] = useState("");
  const [provider, setProvider] = useState<"claude" | "codex">(config.defaultProvider);

  useInput((input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }
  });

  React.useEffect(() => {
    const handler = (msg: Record<string, unknown>) => {
      if (msg.type === "system" && msg.subtype === "session_created" && msg.sessionId) {
        onCreated(msg.sessionId as string);
      }
      if (msg.type === "error") {
        setStep("path"); // Go back on error
      }
    };
    client.on("message", handler);
    return () => {
      client.off("message", handler);
    };
  }, [client, onCreated]);

  const handleSubmitPath = (value: string) => {
    const resolved = value.startsWith("~")
      ? value.replace("~", process.env.HOME ?? "")
      : value;
    setProjectPath(resolved);
    setStep("provider");
  };

  const handleSubmitProvider = () => {
    setStep("starting");
    client.send({
      type: "start",
      projectPath,
      provider,
    });
  };

  return (
    <Box flexDirection="column" padding={1}>
      <Text bold>New Session</Text>
      <Text dimColor>Press Escape to cancel</Text>
      <Text>{""}</Text>

      {step === "path" && (
        <Box>
          <Text>Project path: </Text>
          <TextInput
            value={projectPath}
            onChange={setProjectPath}
            onSubmit={handleSubmitPath}
            placeholder="~/GitHub/my-project"
          />
        </Box>
      )}

      {step === "provider" && (
        <Box flexDirection="column">
          <Text dimColor>Project: {projectPath}</Text>
          <Box>
            <Text>Provider [{provider === "claude" ? "Claude" : "Codex"}]: </Text>
            <ProviderToggle value={provider} onChange={setProvider} onSubmit={handleSubmitProvider} />
          </Box>
        </Box>
      )}

      {step === "starting" && (
        <Text dimColor>Starting {provider} session for {projectPath}...</Text>
      )}
    </Box>
  );
}

function ProviderToggle({
  value,
  onChange,
  onSubmit,
}: {
  value: "claude" | "codex";
  onChange: (v: "claude" | "codex") => void;
  onSubmit: () => void;
}) {
  useInput((input, key) => {
    if (key.return) {
      onSubmit();
      return;
    }
    if (key.leftArrow || key.rightArrow || input === "c") {
      onChange(value === "claude" ? "codex" : "claude");
    }
  });

  return (
    <Text>
      {value === "claude" ? "▸ Claude  Codex" : "  Claude  ▸ Codex"}
    </Text>
  );
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/screens/new-session.tsx
git commit -m "feat(cli): new session screen with path and provider prompts

Text input for project path (~ expansion), arrow-key provider toggle,
sends start message to bridge, transitions to session view on creation."
```

---

### Task 12: Session screen with live output and approval prompt

**Files:**
- Create: `packages/cli/src/screens/session.tsx`
- Create: `packages/cli/src/components/approval.tsx`
- Create: `packages/cli/src/components/message.tsx`
- Create: `packages/cli/src/components/status-bar.tsx`

- [ ] **Step 1: Create the status bar component**

Create `packages/cli/src/components/status-bar.tsx`:

```tsx
import React from "react";
import { Box, Text } from "ink";

interface StatusBarProps {
  sessionId: string;
  provider: string;
  projectPath: string;
  clients: Array<{ clientId: string; clientType: string }>;
}

export function StatusBar({ provider, projectPath, clients }: StatusBarProps) {
  const otherClients = clients.filter((c) => c.clientType !== "cli");
  const alsoOn = otherClients.length > 0
    ? ` also on: ${otherClients.map((c) => c.clientType).join(", ")}`
    : "";
  const project = projectPath.split("/").pop() ?? projectPath;
  const providerLabel = provider === "codex" ? "Codex" : "Claude";

  return (
    <Box>
      <Text dimColor>
        ── Attached to {project} ({providerLabel}) ──{alsoOn ? ` ${alsoOn}` : ""} ──
      </Text>
    </Box>
  );
}
```

- [ ] **Step 2: Create the approval prompt component**

Create `packages/cli/src/components/approval.tsx`:

```tsx
import React from "react";
import { Box, Text, useInput } from "ink";

interface ApprovalProps {
  toolName: string;
  input: Record<string, unknown>;
  onApprove: () => void;
  onReject: () => void;
  onApproveAlways: () => void;
}

export function ApprovalPrompt({ toolName, input, onApprove, onReject, onApproveAlways }: ApprovalProps) {
  useInput((char) => {
    switch (char.toLowerCase()) {
      case "y":
        onApprove();
        break;
      case "n":
        onReject();
        break;
      case "a":
        onApproveAlways();
        break;
    }
  });

  const path = input.file_path ?? input.command ?? "";

  return (
    <Box flexDirection="column">
      <Text>
        <Text color="yellow" bold>Allow?</Text>{" "}
        <Text bold>{toolName}</Text>{path ? ` ${String(path)}` : ""}
      </Text>
      <Text dimColor>  [y]es  [n]o  [a]lways</Text>
    </Box>
  );
}
```

- [ ] **Step 3: Create the message display component**

Create `packages/cli/src/components/message.tsx`:

```tsx
import React from "react";
import { Text } from "ink";
import { renderMessage } from "../renderer.js";

interface MessageProps {
  msg: Record<string, unknown>;
}

export function Message({ msg }: MessageProps) {
  const rendered = renderMessage(msg);
  if (!rendered) return null;
  return <Text>{rendered}</Text>;
}
```

- [ ] **Step 4: Create the session screen**

Create `packages/cli/src/screens/session.tsx`:

```tsx
import React, { useState, useEffect, useCallback } from "react";
import { Box, Text, useInput, useApp } from "ink";
import TextInput from "ink-text-input";
import type { BridgeClient } from "../bridge-client.js";
import { renderMessage } from "../renderer.js";
import { StatusBar } from "../components/status-bar.js";
import { ApprovalPrompt } from "../components/approval.js";

interface SessionScreenProps {
  client: BridgeClient;
  sessionId: string;
  onDetach: () => void;
}

interface PendingApproval {
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
}

interface ClientInfo {
  clientId: string;
  clientType: string;
}

export function SessionScreen({ client, sessionId, onDetach }: SessionScreenProps) {
  const [output, setOutput] = useState<string[]>([]);
  const [streamBuffer, setStreamBuffer] = useState("");
  const [inputValue, setInputValue] = useState("");
  const [status, setStatus] = useState<string>("connecting");
  const [pendingApproval, setPendingApproval] = useState<PendingApproval | null>(null);
  const [clients, setClients] = useState<ClientInfo[]>([]);
  const [provider, setProvider] = useState("claude");
  const [projectPath, setProjectPath] = useState("");
  const { exit } = useApp();

  const appendOutput = useCallback((text: string) => {
    if (!text) return;
    setOutput((prev) => [...prev, text]);
  }, []);

  useEffect(() => {
    // Attach to the session
    client.send({ type: "attach_session", sessionId, clientType: "cli" });

    const handler = (msg: Record<string, unknown>) => {
      // Only process messages for our session
      if (msg.sessionId && msg.sessionId !== sessionId) return;

      switch (msg.type) {
        case "system":
          if (msg.subtype === "session_created") {
            setProvider(String(msg.provider ?? "claude"));
            setProjectPath(String(msg.projectPath ?? ""));
          }
          break;

        case "session_clients":
          setClients(msg.clients as ClientInfo[]);
          break;

        case "client_joined":
        case "client_left": {
          // Re-request client list for simplicity
          // (or update locally — but re-request is simpler and correct)
          break;
        }

        case "status":
          setStatus(String(msg.status));
          break;

        case "stream_delta":
          setStreamBuffer((prev) => prev + String(msg.text ?? ""));
          break;

        case "permission_request":
          // Flush stream buffer before showing prompt
          setStreamBuffer((prev) => {
            if (prev) appendOutput(prev);
            return "";
          });
          setPendingApproval({
            toolUseId: String(msg.toolUseId),
            toolName: String(msg.toolName),
            input: (msg.input as Record<string, unknown>) ?? {},
          });
          break;

        case "permission_resolved":
          setPendingApproval(null);
          break;

        case "assistant":
          // Flush any pending stream buffer
          setStreamBuffer((prev) => {
            if (prev) appendOutput(prev);
            return "";
          });
          appendOutput(renderMessage(msg));
          break;

        case "history":
          // Replay history messages
          if (Array.isArray(msg.messages)) {
            for (const histMsg of msg.messages as Record<string, unknown>[]) {
              const rendered = renderMessage(histMsg);
              if (rendered) appendOutput(rendered);
            }
          }
          setStatus("connected");
          break;

        default:
          appendOutput(renderMessage(msg));
          break;
      }
    };

    client.on("message", handler);
    return () => {
      client.off("message", handler);
    };
  }, [client, sessionId, appendOutput]);

  // Ctrl+D to detach
  useInput((_input, key) => {
    if (key.ctrl && _input === "d") {
      client.send({ type: "detach_session", sessionId });
      onDetach();
    }
  }, { isActive: !pendingApproval });

  const handleSubmitInput = (text: string) => {
    if (!text.trim()) return;
    setInputValue("");
    appendOutput(`\n> ${text}\n`);
    client.send({ type: "input", text, sessionId });
  };

  const handleApprove = () => {
    if (!pendingApproval) return;
    client.send({ type: "approve", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  const handleReject = () => {
    if (!pendingApproval) return;
    client.send({ type: "reject", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  const handleApproveAlways = () => {
    if (!pendingApproval) return;
    client.send({ type: "approve_always", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  return (
    <Box flexDirection="column">
      <StatusBar
        sessionId={sessionId}
        provider={provider}
        projectPath={projectPath}
        clients={clients}
      />
      <Text>{""}</Text>

      {/* Session output */}
      {output.map((line, i) => (
        <Text key={i}>{line}</Text>
      ))}

      {/* Streaming text */}
      {streamBuffer && <Text>{streamBuffer}</Text>}

      {/* Approval prompt or input */}
      {pendingApproval ? (
        <ApprovalPrompt
          toolName={pendingApproval.toolName}
          input={pendingApproval.input}
          onApprove={handleApprove}
          onReject={handleReject}
          onApproveAlways={handleApproveAlways}
        />
      ) : status === "idle" || status === "connected" ? (
        <Box>
          <Text bold color="blue">&gt; </Text>
          <TextInput
            value={inputValue}
            onChange={setInputValue}
            onSubmit={handleSubmitInput}
            placeholder="Type a message..."
          />
        </Box>
      ) : null}

      <Text dimColor>  Ctrl+D: detach</Text>
    </Box>
  );
}
```

- [ ] **Step 5: Type check**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc --noEmit -p packages/cli/tsconfig.json`
Expected: No errors (all screen components now exist)

- [ ] **Step 6: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add packages/cli/src/screens/session.tsx packages/cli/src/components/approval.tsx packages/cli/src/components/message.tsx packages/cli/src/components/status-bar.tsx
git commit -m "feat(cli): session screen with live output, streaming, and approval

Full session view: message history replay, streaming text buffer,
permission request prompts (y/n/a), multi-client status bar,
text input for messages, Ctrl+D to detach."
```

---

## Phase 4: Integration and Polish

### Task 13: Build and manual test

**Files:** No new files — verification only.

- [ ] **Step 1: Build the bridge**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run bridge:build`
Expected: Clean build, no errors

- [ ] **Step 2: Build the CLI**

Run: `cd /Users/devlin/GitHub/ccpocket && npx tsc -p packages/cli/tsconfig.json`
Expected: Clean build, no errors

- [ ] **Step 3: Run all bridge tests**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:bridge`
Expected: All tests pass

- [ ] **Step 4: Run all CLI tests**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test --workspace=packages/cli`
Expected: All tests pass

- [ ] **Step 5: Link CLI globally for manual testing**

Run: `cd /Users/devlin/GitHub/ccpocket/packages/cli && npm link`
Then: `ccpocket --help`
Expected: Shows CLI help with subcommands

- [ ] **Step 6: Manual smoke test (if bridge is running)**

1. Start bridge: `cd /Users/devlin/GitHub/ccpocket && npm run bridge`
2. In another terminal: `ccpocket --url ws://localhost:8765`
3. Verify: session list appears
4. Press [n], enter project path, select provider → session starts
5. Ctrl+D → detach → back to session list

- [ ] **Step 7: Commit any fixes from manual testing**

```bash
cd /Users/devlin/GitHub/ccpocket && git add -A && git commit -m "fix(cli): manual test fixes"
```

---

### Task 14: Add CLI scripts to root package.json

**Files:**
- Modify: `packages/cli/package.json` (add vitest.config reference if needed)
- Modify: root `package.json`

- [ ] **Step 1: Add CLI workspace scripts to root package.json**

Add these scripts to the root `package.json` `"scripts"` object:

```json
    "cli": "npm run dev --workspace=packages/cli",
    "cli:build": "npm run build --workspace=packages/cli",
    "test:cli": "npm run test --workspace=packages/cli"
```

- [ ] **Step 2: Verify workspace scripts work**

Run: `cd /Users/devlin/GitHub/ccpocket && npm run test:cli`
Expected: CLI tests pass

- [ ] **Step 3: Commit**

```bash
cd /Users/devlin/GitHub/ccpocket && git add package.json
git commit -m "chore: add CLI workspace scripts to root package.json"
```

---

## Verification Checklist

Before considering this complete, verify all success criteria from the spec:

1. [ ] Start session on phone → run `ccpocket` → see it active → attach → see live output
2. [ ] Start session via `ccpocket` → open CC Pocket app → see it active → tap → see live output
3. [ ] Both devices show same output in real-time, either can send input and approve
4. [ ] Detach from one device → session continues on the other
5. [ ] Session view renders output similar to running `claude`/`codex` directly
6. [ ] `ccpocket` with no args auto-discovers bridge (mDNS or saved config)
