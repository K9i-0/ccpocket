import { EventEmitter } from "node:events";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { spawnMock, fakeChildren } = vi.hoisted(() => ({
  spawnMock: vi.fn(),
  fakeChildren: [] as FakeChildProcess[],
}));

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

vi.mock("node:child_process", () => ({
  spawn: spawnMock,
}));

import { buildCodexSpawnSpec, CodexProcess } from "./codex-process.js";

describe("CodexProcess (app-server)", () => {
  beforeEach(() => {
    spawnMock.mockReset();
    fakeChildren.length = 0;
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
  });

  it("starts codex app-server and sends initialize + thread/start", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-a", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "gpt-5.3-codex",
    });

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "codex",
      ["app-server", "--listen", "stdio://"],
      expect.objectContaining({ cwd: "/tmp/project-a" }),
    );

    const child = fakeChildren[0];
    await tick();

    const initReq = nextOutgoingRequest(child);
    expect(initReq.method).toBe("initialize");
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await tick();
    const initialized = nextOutgoingNotification(child);
    expect(initialized.method).toBe("initialized");

    const startReq = nextOutgoingRequest(child);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).toMatchObject({
      cwd: "/tmp/project-a",
      approvalPolicy: "on-request",
      sandbox: "workspace-write",
      model: "gpt-5.3-codex",
    });

    child.stdout.emit(
      "data",
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

  it("sends selected profile via config override on thread/start", async () => {
    const proc = new CodexProcess("linux");

    proc.start("/tmp/project-profile", {
      profile: "ccpocket",
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
    });

    const child = fakeChildren[0];
    await tick();

    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await tick();
    nextOutgoingNotification(child); // initialized

    const startReq = nextOutgoingRequest(child);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).toMatchObject({
      cwd: "/tmp/project-profile",
      approvalPolicy: "on-request",
      sandbox: "workspace-write",
      config: {
        profile: "ccpocket",
      },
    });

    proc.stop();
  });

  it("uses cmd.exe to launch codex app-server on Windows", () => {
    const proc = new CodexProcess("win32");

    proc.start("D:\\Users\\alice\\repo");

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "cmd.exe",
      ["/d", "/s", "/c", "codex app-server --listen stdio://"],
      expect.objectContaining({
        cwd: "D:\\Users\\alice\\repo",
        windowsVerbatimArguments: true,
      }),
    );

    proc.stop();
  });

  it("builds a normalized Windows spawn spec", () => {
    expect(buildCodexSpawnSpec("\\\\?\\D:\\Users\\alice\\repo", "win32")).toEqual(
      {
        command: "cmd.exe",
        args: ["/d", "/s", "/c", "codex app-server --listen stdio://"],
        options: expect.objectContaining({
          cwd: "D:\\Users\\alice\\repo",
          stdio: "pipe",
          windowsVerbatimArguments: true,
        }),
      },
    );
  });

  it("ignores placeholder codex model names from resume state", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-placeholder", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "codex",
    });

    const child = fakeChildren[0];
    await tick();

    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await tick();
    nextOutgoingNotification(child); // initialized

    const startReq = nextOutgoingRequest(child);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).not.toHaveProperty("model");

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        id: startReq.id,
        result: { thread: { id: "thr_placeholder" } },
      })}\n`,
    );

    await tick();
    drainSkillsList(child);

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
    const turnReq = nextOutgoingRequest(child);
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
    const proc = new CodexProcess("linux");

    const initializePromise = proc.initializeOnly("/tmp/project-init-only");

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "codex",
      ["app-server", "--listen", "stdio://"],
      expect.objectContaining({ cwd: "/tmp/project-init-only" }),
    );

    const child = fakeChildren[0];
    await tick();

    const initReq = nextOutgoingRequest(child);
    expect(initReq.method).toBe("initialize");
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );

    await initializePromise;

    const initialized = nextOutgoingNotification(child);
    expect(initialized.method).toBe("initialized");
    expect(() => nextOutgoingRequest(child)).toThrow();

    proc.stop();
  });

  it("emits permission_request and responds on approve", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-b");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_2" } } })}\n`,
    );

    await tick();
    drainSkillsList(child);
    proc.sendInput("run ls");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    expect(turnReq.method).toBe("turn/start");

    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_1" } } })}\n`,
    );
    child.stdout.emit(
      "data",
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_1" } } })}\n`,
    );
    child.stdout.emit(
      "data",
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
    const approvalResponse = nextOutgoingResponse(child);
    expect(approvalResponse).toMatchObject({
      id: "req-approval-1",
      result: { decision: "accept" },
    });

    child.stdout.emit(
      "data",
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
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-c");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_3" } } })}\n`,
    );

    await tick();
    drainSkillsList(child);
    proc.sendInput("ask me a question");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    expect(turnReq.method).toBe("turn/start");
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_2" } } })}\n`,
    );
    child.stdout.emit(
      "data",
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_2" } } })}\n`,
    );

    child.stdout.emit(
      "data",
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
    const answerResponse = nextOutgoingResponse(child);
    expect(answerResponse).toMatchObject({
      id: "req-user-input-1",
      result: {
        answers: {
          q1: { answers: ["A"] },
        },
      },
    });

    child.stdout.emit(
      "data",
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
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-perms");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_perms" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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

    const response = nextOutgoingResponse(child);
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
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-elicitation");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_elicit" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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
    expect(proc.getPendingPermission("req-elicit-1")).toMatchObject({
      toolUseId: "req-elicit-1",
      toolName: "McpElicitation",
    });

    proc.answer("req-elicit-1", "true");
    await tick();

    const response = nextOutgoingResponse(child);
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

  it("maps MCP tool approval elicitation to dynamic options and always allow response", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-mcp-approval");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_mcp_approval" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
      `${JSON.stringify({
        id: "req-mcp-approval-1",
        method: "mcpServer/elicitation/request",
        params: {
          threadId: "thr_mcp_approval",
          turnId: "turn_mcp_approval",
          serverName: "revenuecat",
          mode: "form",
          _meta: {
            codex_approval_kind: "mcp_tool_call",
            persist: ["session", "always"],
          },
          message: 'Allow the revenuecat MCP server to run tool "delete-package-from-offering"?',
          requestedSchema: {
            type: "object",
            properties: {},
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "req-mcp-approval-1",
        toolName: "McpElicitation",
        input: expect.objectContaining({
          questions: [
            expect.objectContaining({
              header: "Approve app tool call?",
              options: [
                expect.objectContaining({ label: "Allow" }),
                expect.objectContaining({ label: "Allow for this session" }),
                expect.objectContaining({ label: "Always allow" }),
                expect.objectContaining({ label: "Cancel" }),
              ],
            }),
          ],
        }),
      }),
    );

    proc.answer("req-mcp-approval-1", "Always allow");
    await tick();

    const response = nextOutgoingResponse(child);
    expect(response).toMatchObject({
      id: "req-mcp-approval-1",
      result: {
        action: "accept",
        content: null,
        _meta: {
          persist: "always",
        },
      },
    });

    proc.stop();
  });

  it("omits session remember choices when MCP approval persist modes are absent", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-mcp-approval-basic");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_mcp_basic" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
      `${JSON.stringify({
        id: "req-mcp-approval-2",
        method: "mcpServer/elicitation/request",
        params: {
          threadId: "thr_mcp_basic",
          turnId: "turn_mcp_basic",
          serverName: "revenuecat",
          mode: "form",
          _meta: {
            codex_approval_kind: "mcp_tool_call",
          },
          message: 'Allow the revenuecat MCP server to run tool "delete-package-from-offering"?',
          requestedSchema: {
            type: "object",
            properties: {},
          },
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "req-mcp-approval-2",
        toolName: "McpElicitation",
        input: expect.objectContaining({
          questions: [
            expect.objectContaining({
              options: [
                expect.objectContaining({ label: "Allow" }),
                expect.objectContaining({ label: "Cancel" }),
              ],
            }),
          ],
        }),
      }),
    );

    expect(proc.getPendingPermission("req-mcp-approval-2")).toMatchObject({
      toolUseId: "req-mcp-approval-2",
      toolName: "McpElicitation",
    });

    proc.stop();
  });

  it("clears pending requests when serverRequest/resolved arrives", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-resolved");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_resolved" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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
    child.stdout.emit(
      "data",
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
    const proc = new CodexProcess("linux");

    proc.start("/tmp/project-approve-always");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_always" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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

    const response = nextOutgoingResponse(child);
    expect(response).toMatchObject({
      id: "req-always-1",
      result: { decision: "acceptForSession" },
    });

    proc.stop();
  });

  it("maps dynamic tool calls into tool_use and tool_result messages", async () => {
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-dynamic-tool");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_dynamic" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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
    child.stdout.emit(
      "data",
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
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-mcp-images");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child);
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_mcp" } } })}\n`,
    );

    await tick();
    child.stdout.emit(
      "data",
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
    const proc = new CodexProcess("linux");
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-d");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: initReq.id, result: {} })}\n`,
    );
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_4" } } })}\n`,
    );

    await tick();
    drainSkillsList(child);
    proc.sendInput("make a plan");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_3" } } })}\n`,
    );
    child.stdout.emit(
      "data",
      `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_3" } } })}\n`,
    );

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        method: "item/plan/delta",
        params: { delta: "1. gather requirements" },
      })}\n`,
    );
    child.stdout.emit(
      "data",
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
  child: FakeChildProcess,
  predicate: (value: Record<string, unknown>) => boolean,
): Record<string, unknown> {
  const lines = child.stdin.writes
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
  child.stdin.writes =
    remaining.length > 0 ? [`${remaining.join("\n")}\n`] : [];

  return parsed[index];
}

function nextOutgoingRequest(child: FakeChildProcess): Record<string, unknown> {
  return consumeOutgoing(
    child,
    (value) => typeof value.method === "string" && value.id !== undefined,
  );
}

/** Consume and reply to the background skills/list request that fires after thread/start. */
function drainSkillsList(child: FakeChildProcess): void {
  try {
    const req = consumeOutgoing(
      child,
      (value) => value.method === "skills/list" && value.id !== undefined,
    );
    child.stdout.emit(
      "data",
      `${JSON.stringify({ id: req.id, result: { data: [] } })}\n`,
    );
  } catch {
    // skills/list may not have been emitted yet — safe to ignore
  }
}

function nextOutgoingNotification(
  child: FakeChildProcess,
): Record<string, unknown> {
  return consumeOutgoing(
    child,
    (value) => typeof value.method === "string" && value.id === undefined,
  );
}

function nextOutgoingResponse(
  child: FakeChildProcess,
): Record<string, unknown> {
  return consumeOutgoing(
    child,
    (value) =>
      value.id !== undefined &&
      value.result !== undefined &&
      value.method === undefined,
  );
}

async function tick(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}
