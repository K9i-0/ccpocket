import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { join } from "node:path";
import { homedir } from "node:os";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ProcessStatus, ServerMessage } from "./parser.js";
import { pathToSlug } from "./sessions-index.js";

const { codexInstances, sdkInstances, ptyInstances, fakeDirs, fakeFiles } = vi.hoisted(
  () => ({
    codexInstances: [] as Array<{
      start: ReturnType<typeof vi.fn>;
      stop: ReturnType<typeof vi.fn>;
      emit: (event: string, ...args: unknown[]) => boolean;
    }>,
    sdkInstances: [] as Array<{
      permissionMode: string;
      start: ReturnType<typeof vi.fn>;
      stop: ReturnType<typeof vi.fn>;
      rewindFiles: ReturnType<typeof vi.fn>;
      emit: (event: string, ...args: unknown[]) => boolean;
    }>,
    ptyInstances: [] as Array<{
      isPty: boolean;
      start: ReturnType<typeof vi.fn>;
      stop: ReturnType<typeof vi.fn>;
      emit: (event: string, ...args: unknown[]) => boolean;
    }>,
    fakeDirs: new Set<string>(),
    fakeFiles: new Map<string, string>(),
  }),
);

vi.mock("node:fs", () => {
  const normalize = (value: unknown): string => String(value);
  return {
    existsSync: vi.fn((path: unknown) => {
      const key = normalize(path);
      return fakeDirs.has(key) || fakeFiles.has(key);
    }),
    readFileSync: vi.fn((path: unknown) => {
      const key = normalize(path);
      const content = fakeFiles.get(key);
      if (content == null) {
        const err = new Error(
          `ENOENT: no such file or directory, open '${key}'`,
        );
        (err as NodeJS.ErrnoException).code = "ENOENT";
        throw err;
      }
      return content;
    }),
    readdirSync: vi.fn(
      (path: unknown, options?: { withFileTypes?: boolean }) => {
        const base = normalize(path);
        const prefix = base.endsWith("/") ? base : `${base}/`;
        const childNames = new Set<string>();

        for (const dir of fakeDirs) {
          if (!dir.startsWith(prefix)) continue;
          const rest = dir.slice(prefix.length);
          if (!rest || rest.includes("/")) continue;
          childNames.add(rest);
        }

        if (options?.withFileTypes) {
          return [...childNames].map((name) => ({
            name,
            isDirectory: () => true,
          }));
        }
        return [...childNames];
      },
    ),
  };
});

vi.mock("./codex-process.js", () => ({
  CodexProcess: class MockCodexProcess extends EventEmitter {
    public start = vi.fn((_: string, __?: unknown) => {});
    public stop = vi.fn(() => {});

    constructor() {
      super();
      codexInstances.push(this);
    }
  },
}));

vi.mock("./sdk-process.js", () => ({
  SdkProcess: class MockSdkProcess extends EventEmitter {
    public permissionMode = "default";
    public start = vi.fn((_: string, __?: unknown) => {});
    public stop = vi.fn(() => {});
    public rewindFiles = vi.fn(async () => ({ canRewind: false }));

    constructor() {
      super();
      sdkInstances.push(this);
    }
  },
}));

vi.mock("./pty-process.js", () => ({
  PtyProcess: class MockPtyProcess extends EventEmitter {
    public isPty = true;
    public start = vi.fn((_opts?: unknown) => {});
    public stop = vi.fn(() => {});
    public kill = vi.fn(() => {});
    public write = vi.fn((_data: string) => {});
    public sendInput = vi.fn((_text: string) => {});
    public sendApproval = vi.fn((_id: string) => {});
    public sendRejection = vi.fn((_id: string, _reason?: string) => {});
    public status = "idle" as const;
    public sessionId = null;

    constructor() {
      super();
      ptyInstances.push(this);
    }
  },
}));

import { SessionManager } from "./session.js";

describe("SessionManager codex path", () => {
  beforeEach(() => {
    codexInstances.length = 0;
    sdkInstances.length = 0;
    ptyInstances.length = 0;
  });

  it("creates a codex session and forwards codex start options", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
      {
        threadId: "thread-1",
        sandboxMode: "workspace-write",
        approvalPolicy: "on-request",
        model: "gpt-5.3-codex",
        modelReasoningEffort: "high",
        networkAccessEnabled: true,
        webSearchMode: "live",
      },
    );

    expect(codexInstances).toHaveLength(1);
    expect(codexInstances[0].start).toHaveBeenCalledTimes(1);
    expect(codexInstances[0].start).toHaveBeenCalledWith(
      "/tmp/project-codex",
      expect.objectContaining({
        threadId: "thread-1",
        sandboxMode: "workspace-write",
      }),
    );

    const session = manager.get(sessionId);
    expect(session?.provider).toBe("codex");
  });

  it("updates codex session settings from runtime init metadata", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
      {
        sandboxMode: "workspace-write",
      },
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "init",
      provider: "codex",
      sessionId: "thread-runtime",
      model: "gpt-5.4",
      approvalPolicy: "never",
      sandboxMode: "workspace-write",
      networkAccessEnabled: false,
    });
    codexInstances[0].emit("message", {
      type: "assistant",
      message: {
        id: "msg_1",
        role: "assistant",
        model: "gpt-5.4",
        content: [],
      },
    });

    const session = manager.get(sessionId);
    expect(session?.claudeSessionId).toBe("thread-runtime");
    expect(session?.codexSettings).toMatchObject({
      model: "gpt-5.4",
      approvalPolicy: "never",
      sandboxMode: "workspace-write",
      networkAccessEnabled: false,
    });
  });

  it("ignores placeholder codex model names from runtime messages", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "init",
      provider: "codex",
      sessionId: "thread-runtime",
      model: "codex",
      sandboxMode: "workspace-write",
    });
    codexInstances[0].emit("message", {
      type: "assistant",
      message: {
        id: "msg_1",
        role: "assistant",
        model: "codex",
        content: [],
      },
    });

    const session = manager.get(sessionId);
    expect(session?.codexSettings?.model).toBeUndefined();
  });

  it("uses existing worktree path as cwd for codex resume sessions", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-main",
      undefined,
      [
        {
          role: "user",
          content: [{ type: "text", text: "resume from worktree" }],
        },
      ],
      {
        existingWorktreePath: "/tmp/project-main-worktrees/feature-x",
        worktreeBranch: "feature/x",
      },
      "codex",
      {
        threadId: "thread-worktree",
        sandboxMode: "workspace-write",
      },
    );

    expect(codexInstances).toHaveLength(1);
    expect(codexInstances[0].start).toHaveBeenCalledTimes(1);
    expect(codexInstances[0].start).toHaveBeenCalledWith(
      "/tmp/project-main-worktrees/feature-x",
      expect.objectContaining({
        threadId: "thread-worktree",
        sandboxMode: "workspace-write",
      }),
    );

    const session = manager.get(sessionId);
    expect(session?.projectPath).toBe("/tmp/project-main");
    expect(session?.worktreePath).toBe("/tmp/project-main-worktrees/feature-x");
    expect(session?.worktreeBranch).toBe("feature/x");
  });

  it("stores codex worktree mapping when threadId is known at start", () => {
    const setMapping = vi.fn();
    const manager = new SessionManager(
      () => {},
      undefined,
      undefined,
      undefined,
      { get: vi.fn(), set: setMapping } as any,
    );

    manager.create(
      "/tmp/project-main",
      undefined,
      undefined,
      {
        existingWorktreePath: "/tmp/project-main-worktrees/feature-y",
        worktreeBranch: "feature/y",
      },
      "codex",
      {
        threadId: "thread-with-worktree",
        sandboxMode: "workspace-write",
      },
    );

    expect(setMapping).toHaveBeenCalledWith("thread-with-worktree", {
      worktreePath: "/tmp/project-main-worktrees/feature-y",
      worktreeBranch: "feature/y",
      projectPath: "/tmp/project-main",
    });
  });

  it("updates status from process events and sets idle on exit", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const proc = codexInstances[0];
    const session = manager.get(sessionId);
    expect(session?.status).toBe("starting");

    proc.emit("status", "running" satisfies ProcessStatus);
    expect(manager.get(sessionId)?.status).toBe("running");

    proc.emit("exit", 0);
    const afterExit = manager.get(sessionId);
    expect(afterExit?.status).toBe("idle");
    expect(afterExit?.history.at(-1)).toEqual({
      type: "status",
      status: "idle",
    });
  });

  it("includes codex agent metadata in session summaries", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    // With usePty=true, PtyProcess is used — instanceof CodexProcess is false,
    // so agent metadata is not surfaced. This test verifies the PTY path.
    const summary = manager.list().find((entry) => entry.id == sessionId);
    expect(summary?.agentNickname).toBeUndefined();
    expect(summary?.agentRole).toBeUndefined();
  });

  it("counts past messages and excludes streaming deltas from history", () => {
    const forwarded: Array<{ sessionId: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((sessionId, msg) => {
      forwarded.push({ sessionId, msg });
    });

    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      [
        { role: "user", content: [{ type: "text", text: "old question" }] },
        { role: "assistant", content: [{ type: "text", text: "old answer" }] },
      ],
      undefined,
      "codex",
    );

    const proc = codexInstances[0];
    proc.emit("message", {
      type: "stream_delta",
      text: "partial",
    } satisfies ServerMessage);
    proc.emit("message", {
      type: "assistant",
      message: {
        id: "a1",
        role: "assistant",
        content: [{ type: "text", text: "new answer" }],
        model: "codex",
      },
    } satisfies ServerMessage);

    const session = manager.get(sessionId);
    expect(session?.history).toHaveLength(1);
    expect(session?.history[0].type).toBe("assistant");
    expect(forwarded).toHaveLength(2);

    const summary = manager.list().find((s) => s.id === sessionId);
    expect(summary).toBeDefined();
  });

  it("extracts Codex MCP base64 images into images for history and forwarding", async () => {
    const forwarded: Array<{ sessionId: string; msg: ServerMessage }> = [];
    const imageStore = {
      extractImagePaths: vi.fn(() => []),
      registerImages: vi.fn(async () => []),
      registerFromBase64: vi.fn(() => ({
        id: "img-codex-1",
        url: "/images/img-codex-1",
        mimeType: "image/png",
      })),
    };
    const manager = new SessionManager((sessionId, msg) => {
      forwarded.push({ sessionId, msg });
    }, imageStore as any);

    const sessionId = manager.create(
      "/tmp/project-codex-images",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "tool_result",
      toolUseId: "mcp-img-1",
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
    } as ServerMessage);

    await new Promise((resolve) => setTimeout(resolve, 0));

    const forwardedMsg = forwarded.at(-1)?.msg as
      | Record<string, unknown>
      | undefined;
    expect(forwardedMsg).toBeDefined();
    expect(forwardedMsg?.type).toBe("tool_result");
    expect(forwardedMsg?.images).toEqual([
      {
        id: "img-codex-1",
        url: "/images/img-codex-1",
        mimeType: "image/png",
      },
    ]);
    expect(forwardedMsg).not.toHaveProperty("rawContentBlocks");

    const historyMsg = manager.get(sessionId)?.history.at(-1) as
      | Record<string, unknown>
      | undefined;
    expect(historyMsg).toBeDefined();
    expect(historyMsg?.images).toEqual([
      {
        id: "img-codex-1",
        url: "/images/img-codex-1",
        mimeType: "image/png",
      },
    ]);
    expect(historyMsg).not.toHaveProperty("rawContentBlocks");
  });
});

describe("SessionManager claude UUID backfill", () => {
  const registerHistoryJsonl = (
    projectLikePath: string,
    threadId: string,
    lines: string[],
  ): void => {
    const projectsDir = join(homedir(), ".claude", "projects");
    const dir = join(projectsDir, pathToSlug(projectLikePath));
    fakeDirs.add(projectsDir);
    fakeDirs.add(dir);
    fakeFiles.set(join(dir, `${threadId}.jsonl`), `${lines.join("\n")}\n`);
  };

  beforeEach(() => {
    codexInstances.length = 0;
    sdkInstances.length = 0;
    ptyInstances.length = 0;
    fakeDirs.clear();
    fakeFiles.clear();
  });

  it("backfills user UUIDs from worktree history jsonl", () => {
    const testId = randomUUID();
    const projectPath = `/tmp/ccpocket-main-${testId}`;
    const worktreePath = `/tmp/ccpocket-main-${testId}-worktrees/feat`;
    const threadId = `thread-${testId}`;

    registerHistoryJsonl(worktreePath, threadId, [
      JSON.stringify({
        type: "user",
        uuid: "user-uuid-1",
        message: {
          content: [{ type: "text", text: "hello from worktree" }],
        },
      }),
    ]);

    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => {
      forwarded.push(msg);
    });
    const sessionId = manager.create(
      projectPath,
      undefined,
      undefined,
      { existingWorktreePath: worktreePath, worktreeBranch: "feat" },
      "claude",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    session.claudeSessionId = threadId;
    session.history.push({
      type: "user_input",
      text: "hello from worktree",
    } as ServerMessage);

    sdkInstances[0].emit("message", {
      type: "result",
      subtype: "success",
      sessionId: threadId,
    } satisfies ServerMessage);

    const userInput = session.history.find((msg) => msg.type === "user_input");
    expect(userInput).toBeDefined();
    expect(
      userInput && "userMessageUuid" in userInput
        ? userInput.userMessageUuid
        : undefined,
    ).toBe("user-uuid-1");
    expect(
      forwarded.some(
        (msg) =>
          msg.type === "user_input" &&
          "userMessageUuid" in msg &&
          msg.userMessageUuid === "user-uuid-1",
      ),
    ).toBe(true);
  });

  it("SDK echo merge preserves imageCount from original user_input", () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => {
      forwarded.push(msg);
    });
    const sessionId = manager.create("/tmp/project-merge");

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    // Simulate websocket.ts pushing user_input with imageCount
    session.history.push({
      type: "user_input",
      text: "check this screenshot",
      imageCount: 2,
    } as ServerMessage);

    // Simulate SDK echoing back user_input with UUID (no imageCount)
    sdkInstances[0].emit("message", {
      type: "user_input",
      text: "check this screenshot",
      userMessageUuid: "uuid-img",
    } as ServerMessage);

    // The merged entry should have BOTH userMessageUuid AND imageCount
    const merged = session.history.find(
      (msg) => msg.type === "user_input" && "userMessageUuid" in msg,
    ) as Record<string, unknown> | undefined;
    expect(merged).toBeDefined();
    expect(merged?.userMessageUuid).toBe("uuid-img");
    expect(merged?.imageCount).toBe(2);
    expect(merged?.text).toBe("check this screenshot");
  });

  it("SDK echo merge works for text-only user_input (no imageCount)", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create("/tmp/project-merge-text");

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    // Text-only user_input (no imageCount)
    session.history.push({
      type: "user_input",
      text: "hello world",
    } as ServerMessage);

    // SDK echo with UUID
    sdkInstances[0].emit("message", {
      type: "user_input",
      text: "hello world",
      userMessageUuid: "uuid-text",
    } as ServerMessage);

    const merged = session.history.find(
      (msg) => msg.type === "user_input" && "userMessageUuid" in msg,
    ) as Record<string, unknown> | undefined;
    expect(merged).toBeDefined();
    expect(merged?.userMessageUuid).toBe("uuid-text");
    expect(merged?.text).toBe("hello world");
  });

  it("falls back to scanning all project dirs when primary slug lookup misses", () => {
    const testId = randomUUID();
    const projectPath = `/tmp/ccpocket-main-${testId}`;
    const unrelatedPath = `/tmp/ccpocket-other-${testId}`;
    const threadId = `thread-${testId}`;

    registerHistoryJsonl(unrelatedPath, threadId, [
      JSON.stringify({
        type: "user",
        uuid: "user-uuid-fallback",
        message: {
          content: [{ type: "text", text: "fallback match" }],
        },
      }),
    ]);

    const manager = new SessionManager(() => {});
    const sessionId = manager.create(projectPath);
    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    session.claudeSessionId = threadId;
    session.history.push({
      type: "user_input",
      text: "fallback match",
    } as ServerMessage);

    sdkInstances[0].emit("message", {
      type: "result",
      subtype: "success",
      sessionId: threadId,
    } satisfies ServerMessage);

    const userInput = session.history.find((msg) => msg.type === "user_input");
    expect(userInput).toBeDefined();
    expect(
      userInput && "userMessageUuid" in userInput
        ? userInput.userMessageUuid
        : undefined,
    ).toBe("user-uuid-fallback");
  });
});

describe("sidecar PTY", () => {
  beforeEach(() => {
    codexInstances.length = 0;
    sdkInstances.length = 0;
    ptyInstances.length = 0;
  });

  it("spawnSidecarPty returns null when session has no claudeSessionId", () => {
    const onMessage = vi.fn();
    const mgr = new SessionManager(onMessage);
    const id = mgr.create("/tmp", {});
    const session = mgr.get(id)!;
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
