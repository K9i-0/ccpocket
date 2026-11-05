import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { join } from "node:path";
import { homedir } from "node:os";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { ProcessStatus, ServerMessage } from "./parser.js";
import { pathToSlug } from "./sessions-index.js";

const { codexInstances, sdkInstances, fakeDirs, fakeFiles } = vi.hoisted(
  () => ({
    codexInstances: [] as Array<{
      isWaitingForInput: boolean;
      start: ReturnType<typeof vi.fn>;
      getGoal: ReturnType<typeof vi.fn>;
      getPendingPermission: ReturnType<typeof vi.fn>;
      getPendingPermissions: ReturnType<typeof vi.fn>;
      stop: ReturnType<typeof vi.fn>;
      sendInputStructured: ReturnType<typeof vi.fn>;
      noteManualInput: ReturnType<typeof vi.fn>;
      getRecoveryState: ReturnType<typeof vi.fn>;
      steerInputStructured: ReturnType<typeof vi.fn>;
      emit: (event: string, ...args: unknown[]) => boolean;
    }>,
    sdkInstances: [] as Array<{
      permissionMode: string;
      getPendingPermissions: ReturnType<typeof vi.fn>;
      getPendingPermission: ReturnType<typeof vi.fn>;
      start: ReturnType<typeof vi.fn>;
      stop: ReturnType<typeof vi.fn>;
      rewindFiles: ReturnType<typeof vi.fn>;
      emit: (event: string, ...args: unknown[]) => boolean;
    }>,
    fakeDirs: new Set<string>(),
    fakeFiles: new Map<string, string>(),
  }),
);

vi.mock("node:fs", () => {
  const normalize = (value: unknown): string =>
    String(value).replaceAll("\\", "/");
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
  normalizeCodexReasoningEffortForModel: (
    model: unknown,
    effort: string | undefined,
  ) =>
    model === "gpt-6-astra" && (effort === "none" || effort === "minimal")
      ? "low"
      : effort,
  CodexProcess: class MockCodexProcess extends EventEmitter {
    public isWaitingForInput = false;
    public getGoal = vi.fn(async () => null);
    public getPendingPermission = vi.fn(() => undefined);
    public getPendingPermissions = vi.fn(() => {
      const pending = this.getPendingPermission();
      return pending ? [pending] : [];
    });
    public start = vi.fn((_: string, __?: unknown) => {});
    public stop = vi.fn(() => {});
    public sendInputStructured = vi.fn();
    public noteManualInput = vi.fn();
    public getRecoveryState = vi.fn(() => ({ phase: "off" }));
    public steerInputStructured = vi.fn(async () => {});

    constructor() {
      super();
      codexInstances.push(this);
    }
  },
}));

vi.mock("./sdk-process.js", () => ({
  SdkProcess: class MockSdkProcess extends EventEmitter {
    public permissionMode = "default";
    public getPendingPermissions = vi.fn(() => {
      const pending = this.getPendingPermission();
      return pending ? [pending] : [];
    });
    public getPendingPermission = vi.fn(() => undefined);
    public start = vi.fn((_: string, __?: unknown) => {});
    public stop = vi.fn(() => {});
    public rewindFiles = vi.fn(async () => ({ canRewind: false }));
    public status = "idle";
    public isTurnActive = false;
    public dispatchInput = vi.fn();
    public dispatchInputWithImages = vi.fn();
    public steerInput = vi.fn(() => true);

    constructor() {
      super();
      sdkInstances.push(this);
    }
  },
}));

import { SessionManager } from "./session.js";

describe("SessionManager codex path", () => {
  it("preserves goal transitions queued during the initial lookup", async () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => forwarded.push(msg));
    manager.create("/tmp/goal-order", undefined, undefined, undefined, "codex");
    let resolveLookup!: (goal: null) => void;
    codexInstances[0].getGoal.mockImplementationOnce(() => new Promise(resolve => { resolveLookup = resolve; }));
    const goal = { threadId: "thread", objective: "Ship", status: "active",
      tokenBudget: null, tokensUsed: 0, timeUsedSeconds: 0, createdAt: 1, updatedAt: 2 };
    codexInstances[0].emit("message", { type: "system", subtype: "init" });
    codexInstances[0].emit("message", { type: "goal_state", goal });
    codexInstances[0].emit("message", { type: "status", status: "running" });
    codexInstances[0].emit("message", { type: "goal_state", goal: { ...goal, status: "complete" } });
    codexInstances[0].emit("message", { type: "result", subtype: "success" });
    expect(forwarded).toEqual([]);
    resolveLookup(null);
    await vi.waitFor(() => expect(forwarded.at(-1)).toMatchObject({
      type: "result", notification: "none",
    }));
    expect(forwarded.filter(msg => "notification" in msg && msg.notification === "goal_complete")).toHaveLength(1);
    expect(forwarded.map(msg => msg.type)).toEqual(["goal_state", "system", "goal_state", "status", "goal_state", "result"]);
  });

  it("preserves ordinary completion on goal-unsupported app-servers", async () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => forwarded.push(msg));
    manager.create("/tmp/goal-unsupported", undefined, undefined, undefined, "codex");
    codexInstances[0].getGoal.mockRejectedValue(Object.assign(new Error("Method not found"), { code: -32601 }));
    codexInstances[0].emit("message", { type: "system", subtype: "init" });
    codexInstances[0].emit("message", { type: "result", subtype: "success" });
    await vi.waitFor(() => expect(forwarded.at(-1)?.type).toBe("result"));
    expect(forwarded.at(-1)).not.toHaveProperty("notification", "none");
    expect(codexInstances[0].getGoal).toHaveBeenCalledTimes(1);
  });

  it("suppresses success after transient lookup failure and retries", async () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => forwarded.push(msg));
    manager.create("/tmp/goal-timeout", undefined, undefined, undefined, "codex");
    codexInstances[0].getGoal.mockRejectedValueOnce(new Error("timed out"));
    codexInstances[0].emit("message", { type: "result", subtype: "success" });
    await vi.waitFor(() => expect(forwarded.at(-1)).toMatchObject({ notification: "none" }));
    codexInstances[0].emit("message", { type: "result", subtype: "success" });
    await vi.waitFor(() => expect(forwarded.filter(msg => msg.type === "result")).toHaveLength(2));
    expect(forwarded.at(-1)).not.toHaveProperty("notification", "none");
  });

  beforeEach(() => {
    codexInstances.length = 0;
    sdkInstances.length = 0;
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
    expect(sdkInstances).toHaveLength(0);
    expect(codexInstances[0].start).toHaveBeenCalledTimes(1);
    expect(codexInstances[0].start).toHaveBeenCalledWith(
      "/tmp/project-codex",
      expect.objectContaining({
        threadId: "thread-1",
        sandboxMode: "workspace-write",
        approvalPolicy: "on-request",
        model: "gpt-5.3-codex",
        modelReasoningEffort: "high",
        networkAccessEnabled: true,
        webSearchMode: "live",
      }),
    );

    const session = manager.get(sessionId);
    expect(session?.provider).toBe("codex");
    expect(manager.list()[0].codexSettings?.codexPermissionsMode).toBe(
      "default",
    );
  });

  it("includes an optional Codex question in session context after turn completion", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex-optional-question",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const pendingPermission = {
      toolUseId: "optional-question",
      toolName: "AskUserQuestion",
      input: {
        isBlocking: false,
        questions: [{ id: "choice", question: "Choose?" }],
      },
    };

    codexInstances[0].getPendingPermission.mockReturnValue(pendingPermission);
    codexInstances[0].emit("status", "idle");

    expect(manager.summary(sessionId)).toMatchObject({
      status: "idle",
      pendingPermission,
    });
  });

  it("includes a non-blocking Claude question in session context after turn completion", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-claude-optional-question",
      undefined,
      undefined,
      undefined,
      "claude",
    );
    const pendingInput = {
      toolUseId: "optional-question",
      toolName: "AskUserQuestion",
      input: {
        isBlocking: false,
        questions: [{ id: "choice", question: "Choose?" }],
      },
    };

    sdkInstances[0].getPendingPermission.mockReturnValue(pendingInput);
    sdkInstances[0].emit("status", "idle");

    expect(manager.summary(sessionId)).toMatchObject({
      status: "idle",
      pendingPermission: pendingInput,
    });
  });

  it("does not publish a stale blocking Codex question after the turn is idle", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex-blocking-question",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].getPendingPermission.mockReturnValue({
      toolUseId: "blocking-question",
      toolName: "AskUserQuestion",
      input: {
        isBlocking: true,
        questions: [{ id: "choice", question: "Choose?" }],
      },
    });
    codexInstances[0].emit("status", "idle");

    expect(manager.summary(sessionId)?.pendingPermission).toBeUndefined();
  });

  it("skips a non-actionable request to expose an idle non-blocking question", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex-eligible-question",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const blockingApproval = {
      toolUseId: "blocking-approval",
      toolName: "Bash",
      input: { command: "git status" },
    };
    const optionalQuestion = {
      toolUseId: "optional-question",
      toolName: "AskUserQuestion",
      input: {
        isBlocking: false,
        questions: [{ id: "choice", question: "Choose?" }],
      },
    };

    codexInstances[0].getPendingPermissions.mockReturnValue([
      blockingApproval,
      optionalQuestion,
    ]);
    codexInstances[0].emit("status", "idle");

    expect(manager.summary(sessionId)?.pendingPermission).toEqual(
      optionalQuestion,
    );
  });

  it("refreshes session context as queued Codex questions advance", async () => {
    const onSessionUpdated = vi.fn();
    const manager = new SessionManager(
      () => {},
      undefined,
      undefined,
      undefined,
      undefined,
      onSessionUpdated,
    );
    const sessionId = manager.create(
      "/tmp/project-codex-question-queue",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const first = {
      toolUseId: "question-first",
      toolName: "AskUserQuestion",
      input: { isBlocking: false, questions: [{ id: "first", question: "First?" }] },
    };
    const second = {
      toolUseId: "question-second",
      toolName: "AskUserQuestion",
      input: { isBlocking: false, questions: [{ id: "second", question: "Second?" }] },
    };

    codexInstances[0].getPendingPermission.mockReturnValue(first);
    codexInstances[0].emit("message", {
      type: "permission_request",
      ...first,
    });
    await vi.waitFor(() => expect(onSessionUpdated).toHaveBeenCalledTimes(1));
    expect(manager.summary(sessionId)?.pendingPermission).toEqual(first);

    codexInstances[0].getPendingPermission.mockReturnValue(second);
    codexInstances[0].emit("message", {
      type: "tool_result",
      toolUseId: first.toolUseId,
      content: "Answered",
      permissionOutcome: "answered",
    });
    await vi.waitFor(() => expect(onSessionUpdated).toHaveBeenCalledTimes(2));
    expect(manager.summary(sessionId)?.pendingPermission).toEqual(second);
  });

  it("normalizes GPT-6 Astra effort before storing and starting", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-astra",
      undefined,
      undefined,
      undefined,
      "codex",
      {
        model: "gpt-6-astra",
        modelReasoningEffort: "none",
      },
    );

    expect(codexInstances[0].start).toHaveBeenCalledWith(
      "/tmp/project-astra",
      expect.objectContaining({
        model: "gpt-6-astra",
        modelReasoningEffort: "low",
      }),
    );
    expect(manager.get(sessionId)?.codexSettings?.modelReasoningEffort).toBe(
      "low",
    );
  });

  it("re-derives permissions after incremental runtime settings", async () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex-permissions",
      undefined,
      undefined,
      undefined,
      "codex",
      {
        codexPermissionsMode: "default",
        approvalPolicy: "on-request",
        sandboxMode: "workspace-write",
      },
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "init",
      approvalPolicy: "on-request",
      sandboxMode: "read-only",
    });

    await vi.waitFor(() => expect(manager.get(sessionId)?.codexSettings?.codexPermissionsMode)
      .toBeUndefined());
    expect(manager.list()[0].codexSettings?.codexPermissionsMode).toBe(
      "custom",
    );
  });

  it("caches codex plugin completion metadata", () => {
    const manager = new SessionManager(() => {});
    manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      plugins: ["sample"],
      pluginMetadata: [
        {
          id: "sample@test",
          name: "sample",
          path: "plugin://sample@test",
          marketplaceName: "test",
          installed: true,
          enabled: true,
        },
      ],
    } satisfies ServerMessage);

    expect(
      manager.getCachedCommands("codex", "/tmp/project-codex"),
    ).toMatchObject({
      plugins: ["sample"],
      pluginMetadata: [
        expect.objectContaining({
          id: "sample@test",
          path: "plugin://sample@test",
        }),
      ],
    });
  });

  it("separates completion caches by provider", () => {
    const manager = new SessionManager(() => {});
    manager.create(
      "/tmp/shared-project",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    manager.create(
      "/tmp/shared-project",
      undefined,
      undefined,
      undefined,
      "claude",
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      skills: ["codex-skill"],
    } satisfies ServerMessage);
    sdkInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      slashCommands: ["claude-command"],
    } satisfies ServerMessage);

    expect(
      manager.getCachedCommands("codex", "/tmp/shared-project")?.skills,
    ).toEqual(["codex-skill"]);
    expect(
      manager.getCachedCommands("claude", "/tmp/shared-project")
        ?.slashCommands,
    ).toEqual(["claude-command"]);
  });

  it("keys completion caches by the effective worktree cwd", () => {
    const manager = new SessionManager(() => {});
    manager.create(
      "/tmp/base-project",
      undefined,
      undefined,
      { existingWorktreePath: "/tmp/project-worktree" },
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      skills: ["worktree-skill"],
    } satisfies ServerMessage);

    expect(
      manager.getCachedCommands("codex", "/tmp/project-worktree")?.skills,
    ).toEqual(["worktree-skill"]);
    expect(
      manager.getCachedCommands("codex", "/tmp/base-project"),
    ).toBeUndefined();
  });

  it("replaces cached completion entities with an empty snapshot", () => {
    const manager = new SessionManager(() => {});
    manager.create(
      "/tmp/project-empty",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      skills: ["removed-skill"],
    } satisfies ServerMessage);
    codexInstances[0].emit("message", {
      type: "system",
      subtype: "supported_commands",
      slashCommands: [],
      skills: [],
      skillMetadata: [],
      apps: [],
      appMetadata: [],
      plugins: [],
      pluginMetadata: [],
    } satisfies ServerMessage);

    expect(manager.getCachedCommands("codex", "/tmp/project-empty")).toEqual({
      slashCommands: [],
      skills: [],
      skillMetadata: [],
      apps: [],
      appMetadata: [],
      plugins: [],
      pluginMetadata: [],
    });
  });

  it("stores codex additional writable roots for resume metadata", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
      {
        additionalWritableRoots: ["/tmp/shared"],
      },
    );

    expect(codexInstances[0].start).toHaveBeenCalledWith(
      "/tmp/project-codex",
      expect.objectContaining({
        additionalWritableRoots: ["/tmp/shared"],
      }),
    );
    expect(manager.get(sessionId)?.codexSettings).toMatchObject({
      additionalWritableRoots: ["/tmp/shared"],
    });
  });

  it("returns only newer retained history entries for a history delta", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create("/tmp/project-history-delta");

    const first = manager.appendHistory(sessionId, {
      type: "status",
      status: "running",
    } as ServerMessage);
    const second = manager.appendHistory(sessionId, {
      type: "assistant",
      message: {
        id: "msg-1",
        role: "assistant",
        content: [{ type: "text", text: "hello" }],
        model: "test",
      },
    } as ServerMessage);

    const result = manager.getHistorySince(sessionId, first?.seq ?? 0);

    expect(result).toMatchObject({
      kind: "delta",
      fromSeq: second?.seq,
      toSeq: second?.seq,
    });
    expect(result?.entries).toHaveLength(1);
    expect(result?.entries[0]).toMatchObject({
      seq: second?.seq,
      message: { type: "assistant" },
    });
  });

  it("returns a history snapshot when the requested sequence was compacted", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create("/tmp/project-history-snapshot");

    for (let i = 0; i < 105; i++) {
      manager.appendHistory(sessionId, {
        type: "status",
        status: i % 2 === 0 ? "running" : "idle",
      } as ServerMessage);
    }

    const session = manager.get(sessionId);
    const result = manager.getHistorySince(sessionId, 0);

    expect(session?.history).toHaveLength(100);
    expect(result).toMatchObject({
      kind: "snapshot",
      fromSeq: 6,
      toSeq: 105,
      reason: "compacted",
    });
    expect(result?.entries).toHaveLength(100);
    expect(result?.entries[0].seq).toBe(6);
  });

  it("trims history as a chronological tail instead of preserving only user inputs", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create("/tmp/project-history-tail");

    for (let i = 0; i < 60; i++) {
      manager.appendHistory(sessionId, {
        type: "user_input",
        text: `question ${i}`,
      } as ServerMessage);
      manager.appendHistory(sessionId, {
        type: "assistant",
        message: {
          id: `answer-${i}`,
          role: "assistant",
          content: [{ type: "text", text: `answer ${i}` }],
          model: "test",
        },
      } as ServerMessage);
    }

    const session = manager.get(sessionId);
    const result = manager.getHistorySince(sessionId, 0);

    expect(session?.history).toHaveLength(100);
    expect(result).toMatchObject({
      kind: "snapshot",
      fromSeq: 21,
      toSeq: 120,
    });
    expect(result?.entries.map((entry) => entry.seq)).toEqual(
      Array.from({ length: 100 }, (_, i) => i + 21),
    );
    expect(
      result?.entries.slice(0, 6).map((entry) => entry.message.type),
    ).toEqual([
      "user_input",
      "assistant",
      "user_input",
      "assistant",
      "user_input",
      "assistant",
    ]);
  });

  it("retains the latest Codex user anchor after history compaction", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex-history-anchor",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    manager.appendHistory(sessionId, {
      type: "user_input",
      text: "delegate this task",
      userMessageUuid: "codex:user-turn:1",
    });
    for (let index = 0; index < 100; index++) {
      manager.appendHistory(sessionId, {
        type: "status",
        status: index % 2 === 0 ? "running" : "idle",
      });
    }

    const session = manager.get(sessionId);
    expect(session?.history).toHaveLength(100);
    expect(session?.history.some((message) => message.type === "user_input"))
      .toBe(false);
    expect(session?.codexLatestUserInput).toMatchObject({
      type: "user_input",
      text: "delegate this task",
      userMessageUuid: "codex:user-turn:1",
    });
  });

  it("keeps history delta sequences isolated per running session", () => {
    const manager = new SessionManager(() => {});
    const sessionA = manager.create("/tmp/project-history-a");
    const sessionB = manager.create("/tmp/project-history-b");

    manager.appendHistory(sessionA, {
      type: "status",
      status: "running",
    } as ServerMessage);
    manager.appendHistory(sessionB, {
      type: "status",
      status: "running",
    } as ServerMessage);
    manager.appendHistory(sessionA, {
      type: "status",
      status: "idle",
    } as ServerMessage);

    expect(manager.getHistorySince(sessionA, 0)?.toSeq).toBe(2);
    expect(manager.getHistorySince(sessionB, 0)?.toSeq).toBe(1);
  });

  it("updates codex session settings and broadcasts the resolved thread id", async () => {
    const onSessionUpdated = vi.fn();
    const manager = new SessionManager(
      () => {},
      undefined,
      undefined,
      undefined,
      undefined,
      onSessionUpdated,
    );
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

    await vi.waitFor(() => expect(manager.get(sessionId)?.claudeSessionId).toBe("thread-runtime"));
    const session = manager.get(sessionId);
    expect(onSessionUpdated).toHaveBeenCalledOnce();
    expect(onSessionUpdated).toHaveBeenCalledWith(sessionId);
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
    expect(afterExit?.history.at(-1)).toMatchObject({
      type: "status",
      status: "idle",
      historySeq: 1,
    });
  });

  it("evicts the least recently active idle session above the retention limit", () => {
    const onSessionUpdated = vi.fn();
    const manager = new SessionManager(
      () => {},
      undefined,
      undefined,
      undefined,
      undefined,
      onSessionUpdated,
    );
    const sessionIds = Array.from({ length: 31 }, (_, index) => {
      const id = manager.create(
        `/tmp/project-idle-${index}`,
        undefined,
        undefined,
        undefined,
        "codex",
      );
      manager.get(id)!.lastActivityAt = new Date(Date.now() - 60_000 + index * 1000);
      return id;
    });

    for (const process of codexInstances) {
      process.emit("status", "idle" satisfies ProcessStatus);
    }

    expect(manager.get(sessionIds[0])).toBeUndefined();
    expect(codexInstances[0].stop).toHaveBeenCalledOnce();
    expect(manager.get(sessionIds[1])).toBeDefined();
    expect(manager.list()).toHaveLength(30);
    expect(onSessionUpdated).toHaveBeenCalledOnce();
    manager.destroyAll();
  });

  it("retains sessions waiting for automatic recovery when trimming idle sessions", () => {
    const manager = new SessionManager(() => {});
    const ids = Array.from({ length: 31 }, (_, i) => manager.create(`/tmp/pending-${i}`, undefined, undefined, undefined, "codex"));
    codexInstances[0].getRecoveryState.mockReturnValue({ phase: "waiting" });
    ids.forEach((id, i) => { manager.get(id)!.lastActivityAt = new Date(Date.now() - 60_000 + i * 1000); });
    codexInstances.forEach((proc) => proc.emit("status", "idle"));
    expect(manager.get(ids[0])).toBeDefined();
    expect(manager.get(ids[1])).toBeUndefined();
    manager.destroyAll();
  });

  describe("periodic idle reclamation", () => {
    let manager: SessionManager;
    beforeEach(() => {
      vi.useFakeTimers();
      vi.stubEnv("BRIDGE_IDLE_SESSION_TTL_MINUTES", "15");
      manager = new SessionManager(() => {});
    });
    afterEach(() => {
      manager.destroyAll();
      vi.useRealTimers();
      vi.unstubAllEnvs();
    });

    it.each([undefined, "", "0", "-1", "invalid", "15minutes", "Infinity"])(
      "disables time-based reclamation for TTL %s",
      (value) => {
        manager.destroyAll();
        vi.stubEnv("BRIDGE_IDLE_SESSION_TTL_MINUTES", value);
        manager = new SessionManager(() => {});
        const id = manager.create("/tmp/retained", undefined, undefined, undefined, "codex");
        codexInstances[0].emit("status", "idle");
        vi.advanceTimersByTime(24 * 60 * 60_000);
        expect(manager.get(id)).toBeDefined();
        expect(codexInstances[0].stop).not.toHaveBeenCalled();
      },
    );

    it("reclaims expired idle sessions without requiring a new session event", () => {
      const id = manager.create("/tmp/expired", undefined, undefined, undefined, "codex");
      codexInstances[0].emit("status", "idle");
      vi.advanceTimersByTime(14 * 60_000);
      expect(manager.get(id)).toBeDefined();
      vi.advanceTimersByTime(60_000);
      expect(manager.get(id)).toBeUndefined();
      expect(codexInstances[0].stop).toHaveBeenCalledOnce();
    });

    it("retains active sessions and all pending user work beyond the TTL", () => {
      const ids = Array.from({ length: 5 }, (_, i) => manager.create(`/tmp/protected-${i}`, undefined, undefined, undefined, "codex"));
      codexInstances.slice(1).forEach((proc) => proc.emit("status", "idle"));
      manager.get(ids[1])!.queuedInput = { itemId: "queued", text: "next", createdAt: new Date().toISOString() };
      codexInstances[2].getRecoveryState.mockReturnValue({ phase: "waiting" });
      codexInstances[3].getPendingPermissions.mockReturnValue([{ toolUseId: "question", toolName: "AskUserQuestion", input: { isBlocking: false } }]);
      codexInstances[4].emit("status", "waiting_approval");
      vi.advanceTimersByTime(16 * 60_000);
      ids.forEach((id) => expect(manager.get(id)).toBeDefined());
    });

    it("retains Claude questions even when protected sessions exceed the cap", () => {
      const ids = Array.from({ length: 31 }, (_, i) =>
        manager.create(`/tmp/claude-protected-${i}`));
      sdkInstances.forEach((proc) => {
        proc.getPendingPermissions.mockReturnValue([{
          toolUseId: "question", toolName: "AskUserQuestion",
          input: { isBlocking: false },
        }]);
        proc.emit("status", "idle");
      });
      vi.advanceTimersByTime(16 * 60_000);
      ids.forEach((id) => expect(manager.get(id)).toBeDefined());
    });

    it("uses refreshed activity and reclaims work only after its protection ends", () => {
      const id = manager.create("/tmp/refreshed", undefined, undefined, undefined, "codex");
      codexInstances[0].emit("status", "idle");
      codexInstances[0].getRecoveryState.mockReturnValue({ phase: "waiting" });
      vi.advanceTimersByTime(20 * 60_000);
      manager.get(id)!.lastActivityAt = new Date();
      codexInstances[0].getRecoveryState.mockReturnValue({ phase: "off" });
      vi.advanceTimersByTime(14 * 60_000);
      expect(manager.get(id)).toBeDefined();
      vi.advanceTimersByTime(60_000);
      expect(manager.get(id)).toBeUndefined();
    });

    it("clears the interval when the manager is destroyed", () => {
      expect(vi.getTimerCount()).toBe(1);
      manager.destroyAll();
      expect(vi.getTimerCount()).toBe(0);
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
    const proc = codexInstances[0] as (typeof codexInstances)[number] & {
      agentNickname?: string;
      agentRole?: string;
    };
    proc.agentNickname = "Atlas";
    proc.agentRole = "explorer";

    const summary = manager.list().find((entry) => entry.id == sessionId);
    expect(summary?.agentNickname).toBe("Atlas");
    expect(summary?.agentRole).toBe("explorer");
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

  it("defers process messages until the session is published", async () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => forwarded.push(msg));
    const sessionId = manager.create(
      "/tmp/project-deferred-resume",
      undefined,
      undefined,
      undefined,
      "codex",
      { threadId: "thread-deferred" },
      { deferProcessMessages: true },
    );

    codexInstances[0].emit("message", {
      type: "system",
      subtype: "init",
      sessionId: "thread-deferred",
      provider: "codex",
    } satisfies ServerMessage);
    codexInstances[0].emit("message", {
      type: "status",
      status: "idle",
    } satisfies ServerMessage);

    expect(forwarded).toEqual([]);
    expect(manager.list()).toEqual([]);
    expect(manager.summary(sessionId)).toBeUndefined();
    expect(manager.releaseDeferredProcessMessages(sessionId)).toBe(true);
    await vi.waitFor(() => expect(forwarded.map((message) => message.type)).toEqual([
      "goal_state",
      "system",
      "status",
    ]));
    expect(manager.list().map((session) => session.id)).toEqual([sessionId]);
    expect(manager.summary(sessionId)?.id).toBe(sessionId);
    expect(manager.releaseDeferredProcessMessages(sessionId)).toBe(false);
  });

  it("discards deferred process messages when the session is destroyed", () => {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_, msg) => forwarded.push(msg));
    const sessionId = manager.create(
      "/tmp/project-failed-resume",
      undefined,
      undefined,
      undefined,
      "codex",
      { threadId: "thread-conflict" },
      { deferProcessMessages: true },
    );

    codexInstances[0].emit("message", {
      type: "error",
      message: "writer conflict",
    } satisfies ServerMessage);
    codexInstances[0].emit("message", {
      type: "result",
      subtype: "error",
      error: "writer conflict",
    } satisfies ServerMessage);

    expect(manager.destroy(sessionId)).toBe(true);
    expect(forwarded).toEqual([]);
    expect(manager.releaseDeferredProcessMessages(sessionId)).toBe(false);
  });

  describe("readClaudePlanUsage", () => {
    it("reads from the first Claude session that answers", async () => {
      const manager = new SessionManager(() => {});
      manager.create("/tmp/codex-usage", undefined, undefined, undefined, "codex");
      manager.create("/tmp/claude-a");
      const first = sdkInstances.at(-1) as any;
      first.readPlanUsage = vi.fn(async () => { throw new Error("closed"); });
      manager.create("/tmp/claude-b");
      const second = sdkInstances.at(-1) as any;
      second.readPlanUsage = vi.fn(async () => ({ rate_limits_available: true }));

      await expect(manager.readClaudePlanUsage()).resolves.toEqual({ rate_limits_available: true });
      expect(first.readPlanUsage).toHaveBeenCalledOnce();
    });

    it("resolves undefined without a Claude session", async () => {
      const manager = new SessionManager(() => {});
      manager.create("/tmp/codex-only", undefined, undefined, undefined, "codex");
      await expect(manager.readClaudePlanUsage()).resolves.toBeUndefined();
    });
  });

  describe("usage-limit queue", () => {
    beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-11-03T00:00:00Z")); });
    afterEach(() => vi.useRealTimers());
    function setup(provider: "claude" | "codex") {
      const forwarded: ServerMessage[] = [];
      const manager = new SessionManager((_, message) => forwarded.push(message));
      const id = manager.create("/tmp/limited", undefined, undefined, undefined, provider);
      const proc = (provider === "codex" ? codexInstances.at(-1) : sdkInstances.at(-1)) as any;
      proc.isWaitingForInput = true;
      proc.readUsageLimitResetAt = vi.fn(async () => undefined);
      const send = provider === "codex" ? proc.sendInputStructured : proc.dispatchInput;
      const input = { itemId: "queued-limit", text: "continue", clientMessageId: "cm-limit", createdAt: new Date().toISOString() };
      return { manager, id, proc, send, input, forwarded };
    }

    it.each(["claude", "codex"] as const)("holds %s input until reset, then sends the edited input exactly once", async (provider) => {
      const { manager, id, proc, send, input, forwarded } = setup(provider);
      const reset = Date.now() + 3600000;
      proc.emit("usage_limit", reset);
      expect(manager.queueInput(id, input)).toBe(true);
      proc.emit("input_ready");
      expect(manager.summary(id)?.queuedInput?.retryAt).toBe(new Date(reset).toISOString());
      expect(await manager.steerQueuedInput(id, input.itemId)).toMatchObject({ ok: false });
      manager.updateQueuedInput(id, input.itemId, "edited");
      await vi.advanceTimersByTimeAsync(3599999);
      expect(send).not.toHaveBeenCalled();
      await vi.advanceTimersByTimeAsync(1);
      proc.emit("input_ready");
      expect(send).toHaveBeenCalledTimes(1);
      expect(send.mock.calls[0][0]).toBe("edited");
      expect(manager.get(id)?.queuedInput).toBeUndefined();
      expect(forwarded.filter(m => m.type === "user_input")).toHaveLength(1);
      manager.destroy(id);
    });

    it.each(["claude", "codex"] as const)("queues %s steer input and retains a pre-existing queue when the limit arrives", async (provider) => {
      const { manager, id, proc, send, input } = setup(provider);
      manager.queueInput(id, input);
      proc.emit("usage_limit", Date.now() + 60000);
      proc.emit("input_ready");
      expect(send).not.toHaveBeenCalled();
      expect(await manager.steerInput(id, { ...input, itemId: "second" })).toBe("rejected");
      manager.cancelQueuedInput(id, input.itemId);
      expect(await manager.steerInput(id, { ...input, itemId: "second" })).toBe("queued");
      await vi.advanceTimersByTimeAsync(60000);
      expect(send).toHaveBeenCalledTimes(1);
      manager.destroy(id);
    });

    it.each(["cancel", "destroy", "exit"])("does not send after %s", async (action) => {
      const { manager, id, proc, send, input } = setup("codex");
      proc.emit("usage_limit", Date.now() + 60000);
      manager.queueInput(id, input);
      if (action === "cancel") manager.cancelQueuedInput(id, input.itemId);
      else if (action === "destroy") manager.destroy(id);
      else proc.emit("exit");
      await vi.advanceTimersByTimeAsync(120000);
      expect(send).not.toHaveBeenCalled();
      manager.destroy(id);
    });

    it("waits for input readiness if the reset happens during another turn", async () => {
      const { manager, id, proc, send, input } = setup("codex");
      proc.emit("usage_limit", Date.now() + 60000);
      manager.queueInput(id, input);
      proc.isWaitingForInput = false;
      await vi.advanceTimersByTimeAsync(60000);
      expect(send).not.toHaveBeenCalled();
      proc.isWaitingForInput = true;
      proc.emit("input_ready");
      expect(send).toHaveBeenCalledTimes(1);
      manager.destroy(id);
    });

    it("keeps unknown limits queued when usage fails and sends only after confirmation", async () => {
      const { manager, id, proc, send, input } = setup("claude");
      proc.readUsageLimitResetAt.mockRejectedValueOnce(new Error("offline"));
      proc.emit("usage_limit");
      manager.queueInput(id, input);
      expect(manager.summary(id)?.queuedInput).toMatchObject({ waitingForUsageLimit: true });
      expect(manager.summary(id)?.queuedInput?.retryAt).toBeUndefined();
      await vi.advanceTimersByTimeAsync(60000);
      expect(send).not.toHaveBeenCalled();
      expect(manager.get(id)?.queuedInput).toBeDefined();
      proc.readUsageLimitResetAt.mockResolvedValueOnce(Date.now() + 3600000);
      await vi.advanceTimersByTimeAsync(60000);
      expect(send).not.toHaveBeenCalled();
      await vi.advanceTimersByTimeAsync(3540000);
      expect(send).toHaveBeenCalledTimes(1);
      manager.destroy(id);
    });

    it("keeps a newer rejection while a reset lookup is in flight", async () => {
      const { manager, id, proc, send, input } = setup("codex");
      let resolve!: (value: undefined) => void;
      proc.readUsageLimitResetAt.mockReturnValueOnce(new Promise(r => { resolve = r; }));
      proc.emit("usage_limit");
      manager.queueInput(id, input);
      await vi.advanceTimersByTimeAsync(60000);
      proc.emit("usage_limit");
      resolve(undefined);
      await vi.advanceTimersByTimeAsync(0);
      expect(send).not.toHaveBeenCalled();
      await vi.advanceTimersByTimeAsync(60000);
      expect(send).toHaveBeenCalledTimes(1);
      manager.destroy(id);
    });

    it("re-arms longer limits without overflowing Node timers", async () => {
      const { manager, id, proc, send, input } = setup("codex");
      proc.emit("usage_limit");
      manager.queueInput(id, input);
      const day = 86400000;
      proc.emit("usage_limit", Date.now() + 40 * day);
      await vi.advanceTimersByTimeAsync(30 * day);
      expect(send).not.toHaveBeenCalled();
      await vi.advanceTimersByTimeAsync(10 * day);
      expect(send).toHaveBeenCalledTimes(1);
      manager.destroy(id);
    });
  });

  it("drains queued codex input when the process becomes ready", () => {
    const forwarded: Array<{ sessionId: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((sessionId, msg) => {
      forwarded.push({ sessionId, msg });
    });

    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const queued = manager.queueInput(sessionId, {
      itemId: "queued-1",
      clientMessageId: "cm-follow-up",
      text: "Follow up",
      createdAt: "2026-04-25T00:00:00.000Z",
      imageCount: 1,
      images: [{ base64: "aGVsbG8=", mimeType: "image/png" }],
      imageRefs: [{ id: "img-1", url: "/images/img-1", mimeType: "image/png" }],
      skills: [{ name: "skill", path: "/skills/skill" }],
      mentions: [{ name: "note", path: "/tmp/note.md" }],
    });
    expect(queued).toBe(true);

    const proc = codexInstances[0];
    proc.isWaitingForInput = true;
    proc.emit("input_ready");

    expect(manager.get(sessionId)?.queuedInput).toBeUndefined();
    expect(
      manager.list().find((s) => s.id === sessionId)?.queuedInput,
    ).toBeUndefined();
    expect(proc.noteManualInput).toHaveBeenCalled();
    expect(proc.sendInputStructured).toHaveBeenCalledWith("Follow up", {
      images: [{ base64: "aGVsbG8=", mimeType: "image/png" }],
      skills: [{ name: "skill", path: "/skills/skill" }],
      mentions: [{ name: "note", path: "/tmp/note.md" }],
    });

    const queueMessages = forwarded
      .filter((entry) => entry.msg.type === "conversation_queue")
      .map(
        (entry) =>
          entry.msg as Extract<ServerMessage, { type: "conversation_queue" }>,
      );
    expect(queueMessages).toHaveLength(2);
    expect(queueMessages[0].items).toHaveLength(1);
    expect(queueMessages[1].items).toEqual([]);

    expect(
      forwarded.some(
        (entry) =>
          entry.sessionId === sessionId &&
          entry.msg.type === "user_input" &&
          entry.msg.text === "Follow up" &&
          entry.msg.clientMessageId === "cm-follow-up" &&
          "imageCount" in entry.msg &&
          entry.msg.imageCount === 1,
      ),
    ).toBe(true);
  });

  it("steers queued codex input and broadcasts the promoted user message", async () => {
    const forwarded: Array<{ sessionId: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((sessionId, msg) => {
      forwarded.push({ sessionId, msg });
    });

    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    expect(
      manager.queueInput(sessionId, {
        itemId: "queued-1",
        text: "Steer this",
        createdAt: "2026-04-25T00:00:00.000Z",
        skills: [{ name: "skill", path: "/skills/skill" }],
        mentions: [{ name: "note", path: "/tmp/note.md" }],
      }),
    ).toBe(true);

    const result = await manager.steerQueuedInput(sessionId, "queued-1");

    expect(result).toEqual({ ok: true });
    expect(manager.get(sessionId)?.queuedInput).toBeUndefined();
    expect(codexInstances[0].steerInputStructured).toHaveBeenCalledWith(
      "Steer this",
      {
        images: undefined,
        skills: [{ name: "skill", path: "/skills/skill" }],
        mentions: [{ name: "note", path: "/tmp/note.md" }],
      },
    );
    expect(
      forwarded.some(
        (entry) =>
          entry.sessionId === sessionId &&
          entry.msg.type === "conversation_queue" &&
          entry.msg.items.length === 0,
      ),
    ).toBe(true);
    expect(
      forwarded.some(
        (entry) =>
          entry.sessionId === sessionId &&
          entry.msg.type === "user_input" &&
          entry.msg.text === "Steer this",
      ),
    ).toBe(true);
  });

  it("keeps queued codex input when steer fails", async () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    expect(
      manager.queueInput(sessionId, {
        itemId: "queued-1",
        text: "Steer this",
        createdAt: "2026-04-25T00:00:00.000Z",
      }),
    ).toBe(true);
    codexInstances[0].steerInputStructured.mockRejectedValueOnce(
      new Error("No active Codex turn to steer"),
    );

    const result = await manager.steerQueuedInput(sessionId, "queued-1");

    expect(result).toEqual({
      ok: false,
      error: "No active Codex turn to steer",
    });
    expect(manager.get(sessionId)?.queuedInput?.text).toBe("Steer this");
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

  it("preserves process message order while tool result enrichment is pending", async () => {
    const forwarded: ServerMessage[] = [];
    let finishImageRegistration: ((value: []) => void) | undefined;
    const imageStore = {
      extractImagePaths: vi.fn(() => ["/tmp/generated.png"]),
      registerImages: vi.fn(
        () =>
          new Promise<[]>(resolve => {
            finishImageRegistration = resolve;
          }),
      ),
    };
    const manager = new SessionManager((_, msg) => {
      forwarded.push(msg);
    }, imageStore as any);
    const sessionId = manager.create(
      "/tmp/project-ordered-history",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    codexInstances[0].emit("message", {
      type: "tool_result",
      toolUseId: "image-tool-1",
      toolName: "Bash",
      content: "/tmp/generated.png",
    } satisfies ServerMessage);
    codexInstances[0].emit("message", {
      type: "result",
      subtype: "success",
    } satisfies ServerMessage);

    expect(forwarded).toEqual([]);

    finishImageRegistration?.([]);
    await new Promise(resolve => setTimeout(resolve, 0));

    expect(forwarded.map(message => message.type)).toEqual([
      "tool_result",
      "goal_state",
      "result",
    ]);
    expect(
      manager
        .get(sessionId)
        ?.historyEntries.map(entry => ({
          seq: entry.seq,
          type: entry.message.type,
        })),
    ).toEqual([
      { seq: 1, type: "tool_result" },
      { seq: 2, type: "result" },
    ]);
  });
});

describe("SessionManager rewindConversation", () => {
  const rewindable = (manager: SessionManager, id: string) => {
    const session = manager.get(id)!;
    session.claudeSessionId = "claude-session-1";
    session.history.push(
      { type: "user_input", text: "first", userMessageUuid: "user-1" } as ServerMessage,
      {
        type: "assistant",
        message: { role: "assistant", content: [] },
        messageUuid: "assistant-1",
      } as unknown as ServerMessage,
      { type: "user_input", text: "second", userMessageUuid: "user-2" } as ServerMessage,
    );
    (sdkInstances.at(-1) as unknown as { settings: unknown }).settings = {
      model: "opus",
      effort: "high",
      fastMode: true,
    };
  };

  it.each([
    ["resuming at the previous assistant", "user-2", { sessionId: "claude-session-1", resumeSessionAt: "assistant-1" }],
    ["starting fresh from the first turn", "user-1", {}],
  ])("keeps sandbox and model settings when %s", (_label, target, expected) => {
    const manager = new SessionManager(() => {});
    const id = manager.create("/tmp/rewind", { sandboxEnabled: true });
    rewindable(manager, id);

    const onReady = vi.fn();
    manager.rewindConversation(id, target, onReady);

    const newId = onReady.mock.calls[0][0] as string;
    expect(manager.get(newId)?.sandboxEnabled).toBe(true);
    expect(sdkInstances.at(-1)!.start).toHaveBeenCalledWith(
      "/tmp/rewind",
      expect.objectContaining({
        ...expected,
        permissionMode: "default",
        sandboxEnabled: true,
        model: "opus",
        effort: "high",
        fastMode: true,
      }),
    );
    manager.destroyAll();
  });
});

describe("SessionManager prompt retraction", () => {
  const setup = () => {
    const manager = new SessionManager(() => {});
    const id = manager.create("/tmp/retract");
    const proc = sdkInstances.at(-1)!;
    (proc as unknown as { settings: unknown }).settings = {};
    const session = manager.get(id)!;
    session.claudeSessionId = "claude-session-1";
    return { manager, id, proc, session };
  };
  const assistant = (uuid: string, content: unknown[]) =>
    ({
      type: "assistant",
      message: { id: uuid, role: "assistant", content, model: "m" },
      messageUuid: uuid,
    }) as unknown as ServerMessage;

  it("offers the latest prompt until visible output arrives", () => {
    const { manager, id, proc } = setup();
    manager.appendHistory(id, { type: "user_input", text: "typo" } as ServerMessage);
    expect(manager.retractableUserInput(id)?.text).toBe("typo");

    proc.emit("message", { type: "thinking_delta", text: "hmm" });
    proc.emit("message", { type: "stream_delta", text: "  " });
    expect(manager.retractableUserInput(id)?.text).toBe("typo");

    proc.emit("message", { type: "stream_delta", text: "Sure" });
    expect(manager.retractableUserInput(id)).toBeNull();
    manager.destroyAll();
  });

  it("treats tool use as output", () => {
    const { manager, id, proc } = setup();
    manager.appendHistory(id, { type: "user_input", text: "go" } as ServerMessage);
    proc.emit("message", assistant("a1", [{ type: "tool_use", id: "t", name: "Bash", input: {} }]));
    expect(manager.retractableUserInput(id)).toBeNull();
    manager.destroyAll();
  });

  it("does not retract prompts with images or synthetic input", () => {
    const { manager, id } = setup();
    manager.appendHistory(id, { type: "user_input", text: "pic", imageCount: 1 } as ServerMessage);
    expect(manager.retractableUserInput(id)).toBeNull();
    manager.appendHistory(id, { type: "user_input", text: "x", isSynthetic: true } as ServerMessage);
    expect(manager.retractableUserInput(id)).toBeNull();
    manager.destroyAll();
  });

  const idle = (proc: { emit: (e: string, ...a: unknown[]) => boolean }) =>
    proc.emit("status", "idle");

  it("restarts the same process at the assistant before the latest prompt", async () => {
    const { manager, id, proc, session } = setup();
    idle(proc);
    manager.appendHistory(id, { type: "user_input", text: "first", userMessageUuid: "u1" } as ServerMessage);
    manager.appendHistory(id, assistant("a1", [{ type: "text", text: "hi" }]));
    manager.appendHistory(id, { type: "user_input", text: "typo" } as ServerMessage);
    proc.start.mockClear();
    const forwarded = vi.spyOn(manager as unknown as { onMessage: (...a: unknown[]) => void }, "onMessage");

    const result = await manager.rewindInPlace(id, null);

    expect(result.text).toBe("typo");
    expect(manager.get(id)).toBe(session);
    expect(proc.start).toHaveBeenCalledWith(
      "/tmp/retract",
      expect.objectContaining({ sessionId: "claude-session-1", resumeSessionAt: "a1" }),
    );
    expect(session.history.map((m) => m.type)).toEqual(["user_input", "assistant"]);
    expect(manager.getHistorySince(id, session.historyRevision - 1)?.kind).toBe("snapshot");
    expect(forwarded).toHaveBeenCalledWith(id, { type: "conversation_rewound" });
    manager.destroyAll();
  });

  it("rewinds an earlier prompt by uuid, dropping later turns", async () => {
    const { manager, id, proc, session } = setup();
    idle(proc);
    manager.appendHistory(id, { type: "user_input", text: "first", userMessageUuid: "u1" } as ServerMessage);
    manager.appendHistory(id, assistant("a1", [{ type: "text", text: "hi" }]));
    manager.appendHistory(id, { type: "user_input", text: "second", userMessageUuid: "u2" } as ServerMessage);
    manager.appendHistory(id, assistant("a2", [{ type: "text", text: "yo" }]));
    manager.appendHistory(id, { type: "user_input", text: "third", userMessageUuid: "u3" } as ServerMessage);

    const result = await manager.rewindInPlace(id, "u2");

    expect(result.text).toBe("second");
    expect(proc.start).toHaveBeenLastCalledWith(
      "/tmp/retract",
      expect.objectContaining({ resumeSessionAt: "a1" }),
    );
    expect(session.history.filter((m) => m.type === "user_input")).toHaveLength(1);
    manager.destroyAll();
  });

  it("rewinds into resumed past history", async () => {
    const { manager, id, proc, session } = setup();
    idle(proc);
    session.pastMessages = [
      { role: "user", uuid: "p1", content: [{ type: "text", text: "old" }] },
      { role: "assistant", uuid: "pa1", content: [] },
      { role: "user", uuid: "p2", content: "older typo" },
    ];
    manager.appendHistory(id, { type: "user_input", text: "live", userMessageUuid: "u9" } as ServerMessage);

    const result = await manager.rewindInPlace(id, "p2");

    expect(result.text).toBe("older typo");
    expect(proc.start).toHaveBeenLastCalledWith(
      "/tmp/retract",
      expect.objectContaining({ resumeSessionAt: "pa1" }),
    );
    expect(session.pastMessages).toHaveLength(2);
    expect(session.history).toHaveLength(0);
    manager.destroyAll();
  });

  it("starts empty when the rewound prompt was the first turn", async () => {
    const { manager, id, proc } = setup();
    idle(proc);
    manager.get(id)!.claudeSessionId = undefined;
    manager.appendHistory(id, { type: "user_input", text: "typo" } as ServerMessage);
    proc.start.mockClear();

    await manager.rewindInPlace(id, null);

    const options = proc.start.mock.calls[0][1];
    expect(options.resumeSessionAt).toBeUndefined();
    expect(options.sessionId).toBeUndefined();
    manager.destroyAll();
  });

  it("refuses to drop earlier turns when no rewind point is known", async () => {
    const { manager, id, proc } = setup();
    idle(proc);
    manager.appendHistory(id, { type: "user_input", text: "first" } as ServerMessage);
    manager.appendHistory(id, { type: "user_input", text: "typo" } as ServerMessage);
    proc.start.mockClear();

    await expect(manager.rewindInPlace(id, null)).rejects.toThrow(
      "Cannot locate the turn before the rewound prompt",
    );
    expect(proc.start).not.toHaveBeenCalled();
    manager.destroyAll();
  });

  it("refuses while the agent is running", async () => {
    const { manager, id, proc } = setup();
    proc.emit("status", "running");
    manager.appendHistory(id, { type: "user_input", text: "typo" } as ServerMessage);
    await expect(manager.rewindInPlace(id, null)).rejects.toThrow("running");
    manager.destroyAll();
  });
});

describe("SessionManager idle eviction with background tasks", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.stubEnv("BRIDGE_IDLE_SESSION_TTL_MINUTES", "15");
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllEnvs();
  });

  it("retains idle sessions whose background tasks are still running", () => {
    const manager = new SessionManager(() => {});
    const busy = manager.create("/tmp/bg-busy");
    const idle = manager.create("/tmp/bg-idle");
    sdkInstances.forEach((proc) => proc.emit("status", "idle"));
    manager.get(busy)!.backgroundTasks = [
      { taskId: "t1", taskType: "local_agent", description: "Explore" },
    ];
    manager.get(idle)!.backgroundTasks = [];

    vi.advanceTimersByTime(16 * 60_000);

    expect(manager.get(busy)).toBeDefined();
    expect(manager.get(idle)).toBeUndefined();
    manager.destroyAll();
  });
});

describe("SessionManager claude input queue", () => {
  beforeEach(() => {
    codexInstances.length = 0;
    sdkInstances.length = 0;
  });

  function createClaude() {
    const forwarded: ServerMessage[] = [];
    const manager = new SessionManager((_sessionId, msg) => {
      forwarded.push(msg);
    });
    const sessionId = manager.create("/tmp/project-claude");
    const proc = sdkInstances.at(-1)!;
    proc.status = "running";
    proc.isTurnActive = true;
    return { manager, sessionId, proc, forwarded };
  }

  it("holds queued claude input until the turn becomes idle", () => {
    const { manager, sessionId, proc, forwarded } = createClaude();
    expect(
      manager.queueInput(sessionId, {
        itemId: "queued-1",
        clientMessageId: "cm-1",
        text: "after this turn",
        createdAt: "2026-10-31T00:00:00.000Z",
      }),
    ).toBe(true);
    expect(manager.list().find((s) => s.id === sessionId)?.queuedInput)
      .toMatchObject({ itemId: "queued-1", text: "after this turn" });

    proc.emit("status", "waiting_approval");
    expect(proc.dispatchInput).not.toHaveBeenCalled();

    proc.status = "idle";
    proc.isTurnActive = false;
    // A bare idle (e.g. from stop) must not send the queued prompt.
    proc.emit("status", "idle");
    expect(proc.dispatchInput).not.toHaveBeenCalled();

    proc.emit("input_ready");

    expect(proc.dispatchInput).toHaveBeenCalledWith("after this turn");
    expect(manager.get(sessionId)?.queuedInput).toBeUndefined();
    expect(forwarded.find((m) => m.type === "user_input")).toMatchObject({
      type: "user_input",
      text: "after this turn",
      clientMessageId: "cm-1",
    });
    expect(
      forwarded.find((m) => m.type === "user_input" && "userMessageUuid" in m),
    ).toBeUndefined();
  });

  it("steers claude queued input without waiting for the turn", async () => {
    const { manager, sessionId, proc, forwarded } = createClaude();
    manager.queueInput(sessionId, {
      itemId: "queued-1",
      text: "add this now",
      createdAt: "2026-10-31T00:00:00.000Z",
      imageCount: 1,
      images: [{ base64: "aGVsbG8=", mimeType: "image/png" }],
    });

    const result = await manager.steerQueuedInput(sessionId, "queued-1");

    expect(result).toEqual({ ok: true });
    expect(proc.steerInput).toHaveBeenCalledWith("add this now", [
      { base64: "aGVsbG8=", mimeType: "image/png" },
    ]);
    expect(manager.get(sessionId)?.queuedInput).toBeUndefined();
    const queueEvents = forwarded.filter((m) => m.type === "conversation_queue");
    expect(queueEvents.at(-1)).toMatchObject({ items: [] });
  });

  it("queues new steer input when the steer is rejected", async () => {
    const { manager, sessionId, proc } = createClaude();
    proc.steerInput.mockImplementationOnce(() => {
      throw new Error("not ready");
    });

    const outcome = await manager.steerInput(sessionId, {
      itemId: "queued-2",
      text: "retry later",
      createdAt: "2026-10-31T00:00:00.000Z",
    });

    expect(outcome).toBe("queued");
    expect(manager.get(sessionId)?.queuedInput?.text).toBe("retry later");
  });

  it("sends a failed codex steer right away when the turn already ended", async () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );
    const proc = codexInstances.at(-1)!;
    proc.steerInputStructured.mockRejectedValueOnce(new Error("no turn"));
    proc.isWaitingForInput = true;

    const outcome = await manager.steerInput(sessionId, {
      itemId: "late-steer",
      text: "late",
      createdAt: "2026-10-31T00:00:00.000Z",
    });

    expect(outcome).toBe("steered");
    expect(manager.get(sessionId)?.queuedInput).toBeUndefined();
    expect(proc.sendInputStructured).toHaveBeenCalledWith("late", {
      images: undefined,
      skills: undefined,
      mentions: undefined,
    });
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
    fakeDirs.clear();
    fakeFiles.clear();
  });

  it("skips uuids of turns abandoned by a rewind when backfilling", () => {
    const testId = randomUUID();
    const projectPath = `/tmp/ccpocket-backfill-${testId}`;
    const threadId = `thread-${testId}`;
    const line = (type: string, uuid: string, parentUuid: string | null, text: string) =>
      JSON.stringify({ type, uuid, parentUuid, message: { role: type, content: [{ type: "text", text }] } });
    // "again" was sent, rewound, then resent unchanged on a new branch.
    registerHistoryJsonl(projectPath, threadId, [
      line("user", "u1", null, "first"),
      line("assistant", "a1", "u1", "ok"),
      line("user", "old-again", "a1", "again"),
      line("assistant", "a2", "old-again", "ok"),
      line("user", "new-again", "a1", "again"),
      line("assistant", "a3", "new-again", "ok"),
    ]);

    const manager = new SessionManager(() => {});
    const sessionId = manager.create(projectPath);
    const session = manager.get(sessionId)!;
    session.claudeSessionId = threadId;
    manager.appendHistory(sessionId, { type: "user_input", text: "again" } as ServerMessage);

    sdkInstances[0].emit("message", {
      type: "result",
      subtype: "success",
      sessionId: threadId,
    } satisfies ServerMessage);

    const userInput = session.history.find((msg) => msg.type === "user_input") as
      | { userMessageUuid?: string }
      | undefined;
    expect(userInput?.userMessageUuid).toBe("new-again");
    manager.destroyAll();
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
    manager.appendHistory(sessionId, {
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
    manager.appendHistory(sessionId, {
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

  it("SDK echo merge works for text-only user_input even when echo text changes", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create("/tmp/project-merge-text");

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    // Text-only user_input (no imageCount)
    manager.appendHistory(sessionId, {
      type: "user_input",
      text: "hello world",
    } as ServerMessage);

    // SDK echo with UUID
    sdkInstances[0].emit("message", {
      type: "user_input",
      text: "hello world normalized",
      userMessageUuid: "uuid-text",
    } as ServerMessage);

    const userInputs = session.history.filter((msg) => msg.type === "user_input");
    expect(userInputs).toHaveLength(1);
    const merged = userInputs[0] as Record<string, unknown> | undefined;
    expect(merged).toBeDefined();
    expect(merged?.userMessageUuid).toBe("uuid-text");
    expect(merged?.text).toBe("hello world");
  });

  it("merges Codex user echo when mobile placeholder has a synthetic UUID", () => {
    const broadcasts: Array<{ id: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((id, msg) => {
      broadcasts.push({ id, msg });
    });
    const sessionId = manager.create(
      "/tmp/project-merge-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    manager.appendHistory(sessionId, {
      type: "user_input",
      text: "sync this turn",
      userMessageUuid: "codex:user-turn:1",
      clientMessageId: "cm-codex-merge",
    } as ServerMessage);

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "sync this turn",
      userMessageUuid: "item-real-1",
    } as ServerMessage);

    let userInputs = session.history.filter(
      (msg) => msg.type === "user_input",
    );
    expect(userInputs).toHaveLength(1);
    expect(userInputs[0]).toMatchObject({
      type: "user_input",
      text: "sync this turn",
      userMessageUuid: "codex:user-turn:1",
      clientMessageId: "cm-codex-merge",
    });
    expect(broadcasts.at(-1)).toMatchObject({
      id: sessionId,
      msg: {
        type: "user_input",
        text: "sync this turn",
        userMessageUuid: "codex:user-turn:1",
        clientMessageId: "cm-codex-merge",
      },
    });

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "sync this turn",
      userMessageUuid: "item-real-2",
    } as ServerMessage);

    userInputs = session.history.filter((msg) => msg.type === "user_input");
    expect(userInputs).toHaveLength(2);
    expect(userInputs[1]).toMatchObject({
      type: "user_input",
      text: "sync this turn",
      userMessageUuid: "codex:user-turn:2",
    });
  });

  it("does not merge distinct real Codex user item IDs with identical text", () => {
    const broadcasts: Array<{ id: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((id, msg) => {
      broadcasts.push({ id, msg });
    });
    const sessionId = manager.create(
      "/tmp/project-distinct-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    manager.appendHistory(sessionId, {
      type: "user_input",
      text: "repeat",
      userMessageUuid: "item-real-1",
    } as ServerMessage);

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "repeat",
      userMessageUuid: "item-real-2",
    } as ServerMessage);

    expect(
      session.history.filter((msg) => msg.type === "user_input"),
    ).toHaveLength(2);
    expect(
      session.history.filter((msg) => msg.type === "user_input")[1],
    ).toMatchObject({
      type: "user_input",
      text: "repeat",
      userMessageUuid: "codex:user-turn:2",
    });
    expect(broadcasts.at(-1)).toMatchObject({
      id: sessionId,
      msg: {
        type: "user_input",
        text: "repeat",
      },
    });
    expect(
      "userMessageUuid" in (broadcasts.at(-1)?.msg ?? {}),
    ).toBe(false);
  });

  it("counts resumed Codex past messages when assigning remote user turn UUIDs", () => {
    const broadcasts: Array<{ id: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((id, msg) => {
      broadcasts.push({ id, msg });
    });
    const sessionId = manager.create(
      "/tmp/project-resumed-codex",
      undefined,
      [
        {
          role: "user",
          uuid: "codex:user-turn:1",
          content: [{ type: "text", text: "old turn" }],
        },
      ],
      undefined,
      "codex",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "remote after resume",
      userMessageUuid: "item-real-after-resume",
    } as ServerMessage);

    expect(session.history).toContainEqual(
      expect.objectContaining({
        type: "user_input",
        text: "remote after resume",
        userMessageUuid: "codex:user-turn:2",
      }),
    );
    expect(broadcasts.at(-1)).toMatchObject({
      id: sessionId,
      msg: {
        type: "user_input",
        text: "remote after resume",
      },
    });
    expect(
      "userMessageUuid" in (broadcasts.at(-1)?.msg ?? {}),
    ).toBe(false);
  });

  it("suppresses Codex raw user echo already restored from canonical history", () => {
    const broadcasts: Array<{ id: string; msg: ServerMessage }> = [];
    const manager = new SessionManager((id, msg) => {
      broadcasts.push({ id, msg });
    });
    const sessionId = manager.create(
      "/tmp/project-canonical-codex",
      undefined,
      [
        {
          role: "user",
          uuid: "codex:user-turn:1",
          rawItemId: "raw-user-1",
          content: [{ type: "text", text: "canonical turn" }],
        },
      ],
      undefined,
      "codex",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;
    expect(session.codexUserTurnUuidByRawId?.get("raw-user-1")).toBe(
      "codex:user-turn:1",
    );

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "canonical turn",
      userMessageUuid: "raw-user-1",
    } as ServerMessage);

    expect(
      session.history.filter((msg) => msg.type === "user_input"),
    ).toHaveLength(0);
    expect(broadcasts).toHaveLength(0);

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "next remote",
      userMessageUuid: "raw-user-2",
    } as ServerMessage);

    expect(session.history).toContainEqual(
      expect.objectContaining({
        type: "user_input",
        text: "next remote",
        userMessageUuid: "codex:user-turn:2",
      }),
    );
  });

  it("counts queued Codex input when assigning remote user turn UUIDs", () => {
    const manager = new SessionManager(() => {});
    const sessionId = manager.create(
      "/tmp/project-queued-codex",
      undefined,
      undefined,
      undefined,
      "codex",
    );

    const session = manager.get(sessionId);
    expect(session).toBeDefined();
    if (!session) return;

    manager.appendHistory(sessionId, {
      type: "user_input",
      text: "first local",
      userMessageUuid: "codex:user-turn:1",
    } as ServerMessage);
    expect(
      manager.queueInput(sessionId, {
        itemId: "queued-1",
        text: "queued local",
        createdAt: "2026-05-12T10:00:00.000Z",
        userMessageUuid: "codex:user-turn:2",
      }),
    ).toBe(true);

    codexInstances[0].emit("message", {
      type: "user_input",
      text: "remote while queued",
      userMessageUuid: "item-real-queued-race",
    } as ServerMessage);

    expect(session.history).toContainEqual(
      expect.objectContaining({
        type: "user_input",
        text: "remote while queued",
        userMessageUuid: "codex:user-turn:3",
      }),
    );
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
    manager.appendHistory(sessionId, {
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
