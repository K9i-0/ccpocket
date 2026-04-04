import { EventEmitter } from "node:events";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { spawnMock, fakeChildren, fakeWebSockets, FakeWebSocket, FakeChildProcess } = vi.hoisted(() => {
  const { EventEmitter } = require("node:events");

  class FakeWritable extends EventEmitter {
    public writes: string[] = [];
    write(chunk: string): boolean {
      this.writes.push(chunk);
      this.emit("write", chunk);
      return true;
    }
  }

  class FakeReadable extends EventEmitter {
    setEncoding(_encoding: string): void {}
  }

  class FakeChildProcess extends EventEmitter {
    public stdout = new FakeReadable();
    public stderr = new FakeReadable();
    public stdin = new FakeWritable();
    public killed = false;

    kill(_signal?: NodeJS.Signals): boolean {
      this.killed = true;
      this.emit("exit", 0);
      return true;
    }
  }

  const fakeWebSockets: InstanceType<typeof FakeWebSocket>[] = [];

  class FakeWebSocket extends EventEmitter {
    static OPEN = 1;
    public readyState = 1; // OPEN
    public sends: string[] = [];
    public url: string;

    constructor(url: string) {
      super();
      this.url = url;
      fakeWebSockets.push(this);
      setTimeout(() => this.emit("open"), 0);
    }

    send(data: string): void {
      this.sends.push(data);
      this.emit("send", data);
    }

    terminate(): void {
      this.readyState = 3;
      this.removeAllListeners();
    }

    injectMessage(data: string): void {
      this.emit("message", data);
    }
  }

  return {
    spawnMock: vi.fn(),
    fakeChildren: [] as InstanceType<typeof FakeChildProcess>[],
    fakeWebSockets,
    FakeWebSocket,
    FakeChildProcess,
  };
});

vi.mock("node:child_process", () => ({
  spawn: spawnMock,
}));

vi.mock("ws", () => ({
  WebSocket: FakeWebSocket,
}));

vi.mock("node:net", () => ({
  createServer: () => {
    const { EventEmitter } = require("node:events");
    const srv = new EventEmitter();
    srv.listen = (_port: number, _host: string, cb: () => void) => {
      setTimeout(cb, 0);
    };
    srv.address = () => ({ port: 54321 });
    srv.close = (cb?: () => void) => { if (cb) cb(); };
    return srv;
  },
}));

import { CodexProcess } from "./codex-process.js";

describe("CodexProcess (app-server)", () => {
  beforeEach(() => {
    spawnMock.mockReset();
    fakeChildren.length = 0;
    fakeWebSockets.length = 0;
    spawnMock.mockImplementation(() => {
      const child = new FakeChildProcess();
      fakeChildren.push(child);
      return child;
    });
  });

  afterEach(() => {
    for (const child of fakeChildren) {
      if (!child.killed) {
        child.kill();
      }
    }
    for (const ws of fakeWebSockets) {
      ws.terminate();
    }
  });

  it("starts codex app-server and sends initialize + thread/start", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-a", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "gpt-5.3-codex",
    });

    const ws = await waitForWs();

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "codex",
      ["app-server", "--listen", "ws://0.0.0.0:54321"],
      expect.objectContaining({ cwd: "/tmp/project-a" }),
    );

    await tick();

    const initReq = nextOutgoingRequest(ws);
    expect(initReq.method).toBe("initialize");
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await tick();
    const initialized = nextOutgoingNotification(ws);
    expect(initialized.method).toBe("initialized");

    const startReq = nextOutgoingRequest(ws);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).toMatchObject({
      cwd: "/tmp/project-a",
      approvalPolicy: "on-request",
      sandbox: "workspace-write",
      model: "gpt-5.3-codex",
    });

    ws.injectMessage(
      `${JSON.stringify({
        id: startReq.id,
        result: {
          thread: { id: "thr_1" },
          model: "gpt-5.3-codex",
          approvalPolicy: "on-request",
          sandbox: {
            type: "workspaceWrite",
            networkAccess: false,
          },
        },
      })}\n`,
    );
    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "system",
        subtype: "init",
        provider: "codex",
        sessionId: "thr_1",
        model: "gpt-5.3-codex",
        approvalPolicy: "on-request",
        sandboxMode: "workspace-write",
        networkAccessEnabled: false,
      }),
    );

    proc.stop();
  });

  it("ignores placeholder codex model names from resume state", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-placeholder", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "codex",
    });

    const ws = await waitForWs();
    await tick();

    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await tick();
    nextOutgoingNotification(ws); // initialized

    const startReq = nextOutgoingRequest(ws);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).not.toHaveProperty("model");

    ws.injectMessage(
      `${JSON.stringify({
        id: startReq.id,
        result: { thread: { id: "thr_placeholder" } },
      })}\n`,
    );

    await tick();
    drainSkillsList(ws);

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "system",
        subtype: "init",
        provider: "codex",
        sessionId: "thr_placeholder",
      }),
    );
    expect(messages).not.toContainEqual(
      expect.objectContaining({
        type: "system",
        subtype: "init",
        model: "codex",
      }),
    );

    proc.sendInput("continue");
    await tick();
    const turnReq = nextOutgoingRequest(ws);
    expect(turnReq.method).toBe("turn/start");
    expect(turnReq.params).not.toHaveProperty("model");
    expect(turnReq.params).toMatchObject({
      collaborationMode: {
        mode: "default",
        settings: {
          model: "gpt-5.4",
        },
      },
    });

    proc.stop();
  });

  it("can initialize app-server without starting a thread", async () => {
    const proc = new CodexProcess();

    const initializePromise = proc.initializeOnly("/tmp/project-init-only");

    const ws = await waitForWs();

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "codex",
      ["app-server", "--listen", "ws://0.0.0.0:54321"],
      expect.objectContaining({ cwd: "/tmp/project-init-only" }),
    );

    await tick();

    const initReq = nextOutgoingRequest(ws);
    expect(initReq.method).toBe("initialize");
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await initializePromise;

    const initialized = nextOutgoingNotification(ws);
    expect(initialized.method).toBe("initialized");
    expect(() => nextOutgoingRequest(ws)).toThrow();

    proc.stop();
  });

  it("emits permission_request and responds on approve", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-b");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws); // initialized
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_2" } } })}\n`,
    );

    await tick();
    drainSkillsList(ws);
    proc.sendInput("run ls");
    await tick();
    const turnReq = nextOutgoingRequest(ws);
    expect(turnReq.method).toBe("turn/start");

    ws.injectMessage(
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_1" } } })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_1" } } })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({
        id: "req-approval-1",
        method: "item/commandExecution/requestApproval",
        params: {
          itemId: "item_cmd_1",
          command: "ls -la",
          cwd: "/tmp/project-b",
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "item_cmd_1",
        toolName: "Bash",
      }),
    );

    proc.approve("item_cmd_1");
    await tick();
    const approvalResponse = nextOutgoingResponse(ws);
    expect(approvalResponse).toMatchObject({
      id: "req-approval-1",
      result: { decision: "accept" },
    });

    ws.injectMessage(
      `${JSON.stringify({
        method: "turn/completed",
        params: { turn: { id: "turn_1", status: "completed" } },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "result",
        subtype: "success",
        sessionId: "thr_2",
      }),
    );

    proc.stop();
  });

  it("emits AskUserQuestion and responds on answer", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-c");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws); // initialized
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_3" } } })}\n`,
    );

    await tick();
    drainSkillsList(ws);
    proc.sendInput("ask me a question");
    await tick();
    const turnReq = nextOutgoingRequest(ws);
    expect(turnReq.method).toBe("turn/start");
    ws.injectMessage(
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_2" } } })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_2" } } })}\n`,
    );

    ws.injectMessage(
      `${JSON.stringify({
        id: "req-user-input-1",
        method: "item/tool/requestUserInput",
        params: {
          itemId: "item_user_input_1",
          questions: [
            {
              id: "q1",
              header: "Runtime",
              question: "Pick one option",
              options: [
                { label: "A", description: "Option A" },
                { label: "B", description: "Option B" },
              ],
            },
          ],
          threadId: "thr_3",
          turnId: "turn_2",
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "item_user_input_1",
        toolName: "AskUserQuestion",
      }),
    );

    proc.answer("item_user_input_1", "A");
    await tick();
    const answerResponse = nextOutgoingResponse(ws);
    expect(answerResponse).toMatchObject({
      id: "req-user-input-1",
      result: {
        answers: {
          q1: { answers: ["A"] },
        },
      },
    });

    ws.injectMessage(
      `${JSON.stringify({
        method: "turn/completed",
        params: { turn: { id: "turn_2", status: "completed" } },
      })}\n`,
    );
    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "result",
        subtype: "success",
        sessionId: "thr_3",
      }),
    );

    proc.stop();
  });

  it("responds to permission grants with granted scope and requested permissions", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-perms");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_perms" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        id: "req-perms-1",
        method: "item/permissions/requestApproval",
        params: {
          itemId: "perm_item_1",
          threadId: "thr_perms",
          turnId: "turn_perms",
          reason: "Need write access",
          permissions: {
            fileSystem: {
              write: ["/tmp/project-perms"],
            },
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "perm_item_1",
        toolName: "Permissions",
      }),
    );

    proc.approveAlways("perm_item_1");
    await tick();

    const response = nextOutgoingResponse(ws);
    expect(response).toMatchObject({
      id: "req-perms-1",
      result: {
        scope: "session",
        permissions: {
          fileSystem: {
            write: ["/tmp/project-perms"],
          },
        },
      },
    });

    proc.stop();
  });

  it("maps MCP elicitation form requests to answer flow", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-elicitation");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_elicit" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        id: "req-elicit-1",
        method: "mcpServer/elicitation/request",
        params: {
          threadId: "thr_elicit",
          turnId: "turn_elicit",
          serverName: "codex_apps",
          mode: "form",
          message: "Confirm this operation",
          requestedSchema: {
            type: "object",
            properties: {
              confirmed: {
                type: "boolean",
                title: "Confirmed",
                description: "Whether to continue",
              },
            },
            required: ["confirmed"],
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "req-elicit-1",
        toolName: "McpElicitation",
      }),
    );

    proc.answer("req-elicit-1", "true");
    await tick();

    const response = nextOutgoingResponse(ws);
    expect(response).toMatchObject({
      id: "req-elicit-1",
      result: {
        action: "accept",
        content: {
          confirmed: "true",
        },
      },
    });

    proc.stop();
  });

  it("clears pending requests when serverRequest/resolved arrives", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-resolved");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_resolved" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        id: "req-resolved-1",
        method: "item/commandExecution/requestApproval",
        params: {
          itemId: "item_resolved_1",
          command: "pwd",
          cwd: "/tmp/project-resolved",
        },
      })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        method: "serverRequest/resolved",
        params: {
          threadId: "thr_resolved",
          requestId: "req-resolved-1",
        },
      })}\n`,
    );
    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_resolved",
        toolUseId: "item_resolved_1",
      }),
    );

    proc.stop();
  });

  it("uses acceptForSession for command approvals", async () => {
    const proc = new CodexProcess();

    proc.start("/tmp/project-approve-always");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_always" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        id: "req-always-1",
        method: "item/commandExecution/requestApproval",
        params: {
          itemId: "item_always_1",
          command: "git status",
          cwd: "/tmp/project-approve-always",
        },
      })}\n`,
    );

    await tick();
    proc.approveAlways("item_always_1");
    await tick();

    const response = nextOutgoingResponse(ws);
    expect(response).toMatchObject({
      id: "req-always-1",
      result: { decision: "acceptForSession" },
    });

    proc.stop();
  });

  it("maps dynamic tool calls into tool_use and tool_result messages", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-dynamic-tool");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_dynamic" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        method: "item/started",
        params: {
          item: {
            type: "dynamicToolCall",
            id: "dyn_tool_1",
            tool: "open_pr",
            arguments: {
              repo: "openai/codex",
              title: "Add protocol support",
            },
            status: "inProgress",
          },
        },
      })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({
        method: "item/completed",
        params: {
          item: {
            type: "dynamicToolCall",
            id: "dyn_tool_1",
            tool: "open_pr",
            arguments: {
              repo: "openai/codex",
              title: "Add protocol support",
            },
            status: "completed",
            success: true,
            contentItems: [
              {
                type: "inputText",
                text: "Created PR #42",
              },
            ],
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "assistant",
        message: expect.objectContaining({
          content: expect.arrayContaining([
            expect.objectContaining({
              type: "tool_use",
              id: "dyn_tool_1",
              name: "open_pr",
              input: {
                repo: "openai/codex",
                title: "Add protocol support",
              },
            }),
          ]),
        }),
      }),
    );
    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "tool_result",
        toolUseId: "dyn_tool_1",
        toolName: "open_pr",
        content: expect.stringContaining("Created PR #42"),
      }),
    );
    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "tool_result",
        toolUseId: "dyn_tool_1",
        content: expect.stringContaining("success: true"),
      }),
    );

    proc.stop();
  });

  it("preserves MCP image outputs as raw content blocks for downstream rendering", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-mcp-images");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws);
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_mcp" } } })}\n`,
    );

    await tick();
    ws.injectMessage(
      `${JSON.stringify({
        method: "item/completed",
        params: {
          item: {
            type: "mcpToolCall",
            id: "mcp_tool_1",
            server: "marionette",
            tool: "take_screenshots",
            arguments: {},
            result: {
              content: [
                {
                  type: "image",
                  data: "aGVsbG8=",
                  mimeType: "image/png",
                },
              ],
            },
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "assistant",
        message: expect.objectContaining({
          content: expect.arrayContaining([
            expect.objectContaining({
              type: "tool_use",
              id: "mcp_tool_1",
              name: "mcp:marionette/take_screenshots",
              input: {},
            }),
          ]),
        }),
      }),
    );
    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "tool_result",
        toolUseId: "mcp_tool_1",
        toolName: "mcp:marionette/take_screenshots",
        content: "Generated 1 image",
        rawContentBlocks: [
          {
            type: "image",
            source: {
              type: "base64",
              data: "aGVsbG8=",
              media_type: "image/png",
            },
          },
        ],
      }),
    );

    proc.stop();
  });

  it("emits plan notifications as regular stream messages", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-d");
    const ws = await waitForWs();

    await tick();
    const initReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(ws); // initialized
    const threadReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_4" } } })}\n`,
    );

    await tick();
    drainSkillsList(ws);
    proc.sendInput("make a plan");
    await tick();
    const turnReq = nextOutgoingRequest(ws);
    ws.injectMessage(
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_3" } } })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_3" } } })}\n`,
    );

    ws.injectMessage(
      `${JSON.stringify({
        method: "item/plan/delta",
        params: { delta: "1. gather requirements" },
      })}\n`,
    );
    ws.injectMessage(
      `${JSON.stringify({
        method: "turn/plan/updated",
        params: {
          explanation: "Initial plan drafted",
          plan: [{ step: "Gather requirements", status: "inProgress" }],
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "thinking_delta",
        text: "1. gather requirements",
      }),
    );
    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "assistant",
        message: expect.objectContaining({
          role: "assistant",
          content: expect.arrayContaining([
            expect.objectContaining({
              type: "text",
              text: expect.stringContaining(
                "Plan update: Initial plan drafted",
              ),
            }),
          ]),
        }),
      }),
    );

    proc.stop();
  });
});

function consumeOutgoing(
  ws: FakeWebSocket,
  predicate: (value: Record<string, unknown>) => boolean,
): Record<string, unknown> {
  const lines = ws.sends
    .flatMap((chunk) => chunk.split("\n"))
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const parsed = lines.map(
    (line) => JSON.parse(line) as Record<string, unknown>,
  );
  const index = parsed.findIndex(predicate);
  if (index < 0) {
    throw new Error("Expected outgoing JSON-RPC message was not found");
  }
  const remaining = lines.filter((_, lineIndex) => lineIndex !== index);
  ws.sends =
    remaining.length > 0 ? [`${remaining.join("\n")}\n`] : [];

  return parsed[index];
}

function nextOutgoingRequest(ws: FakeWebSocket): Record<string, unknown> {
  return consumeOutgoing(
    ws,
    (value) => typeof value.method === "string" && value.id !== undefined,
  );
}

/** Consume and reply to the background skills/list request that fires after thread/start. */
function drainSkillsList(ws: FakeWebSocket): void {
  try {
    const req = consumeOutgoing(
      ws,
      (value) => value.method === "skills/list" && value.id !== undefined,
    );
    ws.injectMessage(
      `${JSON.stringify({ id: req.id, result: { data: [] } })}\n`,
    );
  } catch {
    // skills/list may not have been emitted yet — safe to ignore
  }
}

function nextOutgoingNotification(
  ws: FakeWebSocket,
): Record<string, unknown> {
  return consumeOutgoing(
    ws,
    (value) => typeof value.method === "string" && value.id === undefined,
  );
}

function nextOutgoingResponse(
  ws: FakeWebSocket,
): Record<string, unknown> {
  return consumeOutgoing(
    ws,
    (value) =>
      value.id !== undefined &&
      value.result !== undefined &&
      value.method === undefined,
  );
}

/** Wait for the async WS connection to establish after proc.start(). */
async function waitForWs(): Promise<InstanceType<typeof FakeWebSocket>> {
  // Need real time for: findFreePort setTimeout(cb, 0), connectWs setTimeout(tryConnect, 50), WS open setTimeout(0)
  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setTimeout(r, 10));
    if (fakeWebSockets.length > 0) break;
  }
  const ws = fakeWebSockets[fakeWebSockets.length - 1];
  if (!ws) throw new Error("No FakeWebSocket was created");
  // Wait one more tick for the "open" event to fire
  await new Promise((r) => setTimeout(r, 10));
  return ws;
}

async function tick(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}
