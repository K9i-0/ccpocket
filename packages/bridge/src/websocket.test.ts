import { createServer } from "node:http";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const {
  getSessionHistoryMock,
  getCodexSessionHistoryMock,
  getAllRecentSessionsMock,
  saveCodexSessionProfileMock,
  generateCommitMessageMock,
  gitCommitMock,
} = vi.hoisted(() => ({
  getSessionHistoryMock: vi.fn(),
  getCodexSessionHistoryMock: vi.fn(),
  getAllRecentSessionsMock: vi.fn(),
  saveCodexSessionProfileMock: vi.fn(),
  generateCommitMessageMock: vi.fn(),
  gitCommitMock: vi.fn(),
}));

vi.mock("./sessions-index.js", () => ({
  getSessionHistory: getSessionHistoryMock,
  getCodexSessionHistory: getCodexSessionHistoryMock,
  getAllRecentSessions: getAllRecentSessionsMock,
  saveCodexSessionProfile: saveCodexSessionProfileMock,
}));

vi.mock("./debug-trace-store.js", () => ({
  DebugTraceStore: class MockDebugTraceStore {
    init() {
      return Promise.resolve();
    }

    getTraceFilePath(sessionId: string) {
      return `/tmp/${sessionId}.jsonl`;
    }

    getBundleFilePath(sessionId: string, generatedAt: string) {
      return `/tmp/${sessionId}-${generatedAt}.json`;
    }

    saveBundle(sessionId: string, generatedAt: string) {
      return this.getBundleFilePath(sessionId, generatedAt);
    }

    saveBundleAtPath() {}

    record() {}
  },
}));

vi.mock("./git-assist.js", () => ({
  generateCommitMessage: generateCommitMessageMock,
}));

vi.mock("./git-operations.js", async () => {
  const actual = await vi.importActual<typeof import("./git-operations.js")>(
    "./git-operations.js",
  );
  return {
    ...actual,
    gitCommit: gitCommitMock,
  };
});

vi.mock("./session.js", () => ({
  SessionManager: class MockSessionManager {
    private sessions = new Map<string, any>();
    private seq = 0;

    constructor() {}

    create(
      projectPath: string,
      options?: {
        sessionId?: string;
        continueMode?: boolean;
        permissionMode?: string;
        initialInput?: string;
      },
      pastMessages?: unknown[],
      _worktreeOptions?: unknown,
      provider: "claude" | "codex" = "claude",
      codexOptions?: unknown,
    ): string {
      const id = `s-${++this.seq}`;
      const process = {
        isWaitingForInput: true,
        setPermissionMode: vi.fn(async () => {}),
        approvalPolicy: "never",
        approvalsReviewer: "user",
        collaborationMode: "default",
        setApprovalPolicy: vi.fn(function (this: any, value: string) {
          this.approvalPolicy = value;
        }),
        setApprovalsReviewer: vi.fn(function (this: any, value: string) {
          this.approvalsReviewer = value;
        }),
        setCollaborationMode: vi.fn(function (this: any, value: string) {
          this.collaborationMode = value;
        }),
        listThreads: vi.fn(async () => ({ data: [], nextCursor: null })),
        sendInput: vi.fn(() => false),
        sendInputWithImage: vi.fn(),
        sendInputWithImages: vi.fn(() => false),
        approve: vi.fn(),
        approveAlways: vi.fn(),
        reject: vi.fn(),
        answer: vi.fn(),
        interrupt: vi.fn(),
        getPendingPermission: vi.fn(() => undefined),
      };
      this.sessions.set(id, {
        id,
        projectPath,
        startOptions: options,
        claudeSessionId: options?.sessionId,
        pastMessages,
        codexOptions,
        codexSettings: codexOptions,
        history: [],
        status: "idle",
        provider,
        createdAt: new Date(),
        lastActivityAt: new Date(),
        process,
      });
      return id;
    }

    get(id: string) {
      return this.sessions.get(id);
    }

    list() {
      return Array.from(this.sessions.values()).map((s) => ({
        id: s.id,
        provider: s.provider,
        projectPath: s.projectPath,
        claudeSessionId: s.claudeSessionId,
        status: s.status,
        createdAt: "",
        lastActivityAt: "",
        gitBranch: "",
        lastMessage: "",
        codexSettings: s.codexSettings,
      }));
    }

    getCachedCommands() {
      return undefined;
    }

    destroy(id: string) {
      this.sessions.delete(id);
    }

    destroyAll() {}

    async rewindFiles(_id: string, _targetUuid: string, _dryRun?: boolean) {
      return { canRewind: true, filesChanged: ["test.ts"], insertions: 1, deletions: 0 };
    }

    rewindConversation(
      id: string,
      _targetUuid: string,
      onReady: (newSessionId: string) => void,
    ) {
      const session = this.sessions.get(id);
      if (!session) throw new Error(`Session ${id} not found`);
      this.sessions.delete(id);
      const newId = `s-${++this.seq}`;
      const process = {
        isWaitingForInput: true,
        setPermissionMode: vi.fn(async () => {}),
        approvalPolicy: "never",
        approvalsReviewer: "user",
        collaborationMode: "default",
        setApprovalPolicy: vi.fn(function (this: any, value: string) {
          this.approvalPolicy = value;
        }),
        setApprovalsReviewer: vi.fn(function (this: any, value: string) {
          this.approvalsReviewer = value;
        }),
        setCollaborationMode: vi.fn(function (this: any, value: string) {
          this.collaborationMode = value;
        }),
        listThreads: vi.fn(async () => ({ data: [], nextCursor: null })),
        sendInput: vi.fn(() => false),
        sendInputWithImage: vi.fn(),
        sendInputWithImages: vi.fn(() => false),
        approve: vi.fn(),
        approveAlways: vi.fn(),
        reject: vi.fn(),
        answer: vi.fn(),
        interrupt: vi.fn(),
        getPendingPermission: vi.fn(() => undefined),
      };
      this.sessions.set(newId, {
        id: newId,
        projectPath: session.projectPath,
        startOptions: session.startOptions,
        claudeSessionId: session.claudeSessionId,
        history: [],
        status: "idle",
        provider: session.provider,
        createdAt: new Date(),
        lastActivityAt: new Date(),
        process,
      });
      onReady(newId);
    }
  },
}));

import { BridgeWebSocketServer } from "./websocket.js";

describe("BridgeWebSocketServer resume/get_history flow", () => {
  const OPEN_STATE = 1;
  let httpServer: ReturnType<typeof createServer>;
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
    httpServer = createServer();
    getSessionHistoryMock.mockReset();
    getCodexSessionHistoryMock.mockReset();
    getAllRecentSessionsMock.mockReset();
    saveCodexSessionProfileMock.mockReset();
    generateCommitMessageMock.mockReset();
    gitCommitMock.mockReset();
    getAllRecentSessionsMock.mockResolvedValue({ sessions: [], hasMore: false });
    getCodexSessionHistoryMock.mockResolvedValue([]);
    saveCodexSessionProfileMock.mockResolvedValue(undefined);
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.unstubAllEnvs();
    httpServer.close();
  });

  it("sends codex model list without deprecated models", () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).codexProfiles = ["ccpocket", "research"];
    (bridge as any).defaultCodexProfile = "ccpocket";

    (bridge as any).sendSessionList(ws);

    const sessionList = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((msg: any) => msg.type === "session_list");

    expect(sessionList.codexModels).toEqual([
      "gpt-5.5",
      "gpt-5.4",
      "gpt-5.4-mini",
      "gpt-5.3-codex",
      "gpt-5.3-codex-spark",
    ]);
    expect(sessionList.codexModels).not.toContain("gpt-5.2-codex");
    expect(sessionList.codexProfiles).toEqual(["ccpocket", "research"]);
    expect(sessionList.defaultCodexProfile).toBe("ccpocket");

    bridge.close();
  });

  it("rejects start when selected codex profile does not exist", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    vi.spyOn(bridge as any, "validateCodexProfile").mockResolvedValue(false);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "codex",
        profile: "missing",
      },
      ws,
    );

    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends).toContainEqual(
      expect.objectContaining({
        type: "error",
        message: "Codex profile not found: missing",
      }),
    );

    bridge.close();
  });

  it("forwards selected codex profile on start", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    vi.spyOn(bridge as any, "validateCodexProfile").mockResolvedValue(true);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "codex",
        profile: "ccpocket",
      },
      ws,
    );

    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions).toMatchObject({
      profile: "ccpocket",
    });

    bridge.close();
  });

  it("normalizes and forwards additional writable roots on codex start", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "codex",
        additionalWritableRoots: ["../shared", "/tmp/project-a/../shared"],
      },
      ws,
    );

    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions).toMatchObject({
      additionalWritableRoots: [resolve("/tmp/shared")],
    });

    bridge.close();
  });

  it("rejects additional writable roots outside bridge allowed directories", async () => {
    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: ["/tmp/project-a"],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "codex",
        additionalWritableRoots: ["/tmp/other"],
      },
      ws,
    );

    await Promise.resolve();

    expect((bridge as any).sessionManager.get("s-1")).toBeUndefined();
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends).toContainEqual(
      expect.objectContaining({
        type: "error",
        errorCode: "path_not_allowed",
      }),
    );

    bridge.close();
  });

  it("forwards selected codex profile on resume", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    vi.spyOn(bridge as any, "loadCodexProfiles").mockResolvedValue({
      profiles: ["ccpocket"],
      defaultProfile: "ccpocket",
    });

    await (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "thr_123",
        projectPath: "/tmp/project-a",
        provider: "codex",
        profile: "ccpocket",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions).toMatchObject({
      threadId: "thr_123",
      profile: "ccpocket",
    });

    bridge.close();
  });

  it("falls back to the default codex profile on resume when the saved profile no longer exists", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    vi.spyOn(bridge as any, "loadCodexProfiles").mockResolvedValue({
      profiles: ["ccpocket"],
      defaultProfile: "ccpocket",
    });

    await (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "thr_123",
        projectPath: "/tmp/project-a",
        provider: "codex",
        profile: "research",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions).toMatchObject({
      threadId: "thr_123",
      profile: "ccpocket",
    });
    expect(saveCodexSessionProfileMock).toHaveBeenCalledWith(
      "thr_123",
      "ccpocket",
    );
    expect(ws.send).not.toHaveBeenCalledWith(
      expect.stringContaining("Codex profile not found"),
    );

    bridge.close();
  });

  it("forwards additional writable roots on codex resume", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "thr_123",
        projectPath: "/tmp/project-a",
        provider: "codex",
        additionalWritableRoots: ["/tmp/shared"],
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions).toMatchObject({
      threadId: "thr_123",
      additionalWritableRoots: [resolve("/tmp/shared")],
    });

    bridge.close();
  });

  it("does not send past_history on resume_session and sends it on get_history with sessionId", async () => {
    getSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "restored question" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "claude-session-1",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();
    const resumeSends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(resumeSends.some((m: any) => m.type === "past_history")).toBe(false);

    const created = resumeSends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    expect(created.provider).toBe("claude");
    const newSessionId = created.sessionId as string;

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      { type: "get_history", sessionId: newSessionId },
      ws,
    );

    const historySends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(historySends[0]).toMatchObject({
      type: "past_history",
      sessionId: newSessionId,
    });
    expect(historySends[1]).toMatchObject({ type: "history", sessionId: newSessionId });
    expect(historySends[2]).toMatchObject({ type: "status", sessionId: newSessionId });

    bridge.close();
  });

  it("allows Windows subdirectories under BRIDGE_ALLOWED_DIRS", async () => {
    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: ["D:\\Users\\alice"],
      platform: "win32",
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "D:\\Users\\alice\\src\\ccpocket",
        provider: "claude",
      },
      ws,
    );

    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(created).toBeDefined();
    expect(created.projectPath).toBe("D:\\Users\\alice\\src\\ccpocket");

    bridge.close();
  });

  it("returns a friendly error for symbolic links to directories", async () => {
    const projectPath = mkdtempSync(resolve(tmpdir(), "ccpocket-bridge-"));
    const targetDir = resolve(projectPath, "target-dir");
    const symlinkPath = resolve(projectPath, "linked-dir");
    mkdirSync(targetDir);
    symlinkSync("target-dir", symlinkPath);

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: [projectPath],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    try {
      (bridge as any).handleClientMessage(
        {
          type: "read_file",
          projectPath,
          filePath: "linked-dir",
        },
        ws,
      );

      await new Promise((resolveDelay) => setTimeout(resolveDelay, 25));

      const sends = ws.send.mock.calls.map((c: unknown[]) =>
        JSON.parse(c[0] as string),
      );
      expect(sends).toContainEqual({
        type: "file_content",
        filePath: "linked-dir",
        content: "",
        error:
          "This symbolic link points to a directory (target-dir). Open the target directory instead.",
      });
    } finally {
      bridge.close();
      rmSync(projectPath, { recursive: true, force: true });
    }
  });

  it("normalizes extended Windows project paths during resume", async () => {
    getCodexSessionHistoryMock.mockResolvedValue([]);

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: ["D:\\Users\\alice"],
      platform: "win32",
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "thr-win32",
        projectPath: "\\\\?\\D:\\Users\\alice\\src\\ccpocket",
        provider: "codex",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(created).toBeDefined();
    expect(created.projectPath).toBe("D:\\Users\\alice\\src\\ccpocket");

    bridge.close();
  });

  it("sends provider=codex on codex resume_session", async () => {
    getCodexSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "restored codex question" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      platform: "darwin",
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "codex-thread-1",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    expect(created.provider).toBe("codex");

    bridge.close();
  });

  it("preserves internal codex sandbox mode on resume_session", async () => {
    getCodexSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "restored codex question" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "codex-thread-danger",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        sandboxMode: "danger-full-access",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const session = (bridge as any).sessionManager.get("s-1");
    expect(session.codexOptions?.sandboxMode).toBe("danger-full-access");

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created?.sandboxMode).toBe("off");

    bridge.close();
  });

  it("uses stored worktree mapping for codex resume when available", async () => {
    getCodexSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "restored codex question" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    const worktreeStore = (bridge as any).worktreeStore;
    vi.spyOn(worktreeStore, "get").mockReturnValue({
      worktreePath: "/tmp/project-main-worktrees/feature-x",
      worktreeBranch: "feature/x",
      projectPath: "/tmp/project-main",
    });

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "codex-thread-with-mapping",
        projectPath: "/tmp/incorrect-project-path",
        provider: "codex",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    expect(created.provider).toBe("codex");
    expect(created.projectPath).toBe(resolve("/tmp/project-main"));

    bridge.close();
  });

  it("forwards set_permission_mode to Claude session process", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    const setPermissionModeMock = session.process.setPermissionMode as ReturnType<typeof vi.fn>;

    const callCountBefore = ws.send.mock.calls.length;
    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "plan",
      },
      ws,
    );
    await Promise.resolve();

    expect(setPermissionModeMock).toHaveBeenCalledTimes(1);
    expect(setPermissionModeMock).toHaveBeenCalledWith("plan");
    expect(ws.send.mock.calls).toHaveLength(callCountBefore);

    bridge.close();
  });

  it("falls back Claude auto mode to default on start when auto is unavailable", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    const sessionManager = (bridge as any).sessionManager;
    const realCreate = sessionManager.create.bind(sessionManager);
    let failFirstCreate = true;
    const createSpy = vi
      .spyOn(sessionManager, "create")
      .mockImplementation((...args: any[]) => {
        if (failFirstCreate) {
          failFirstCreate = false;
          throw new Error('Permission mode "auto" is unavailable for your plan');
        }
        return realCreate(...args);
      });

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-auto",
        provider: "claude",
        permissionMode: "auto",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    expect(createSpy.mock.calls[0]?.[1]?.permissionMode).toBe("auto");
    expect(createSpy.mock.calls[1]?.[1]?.permissionMode).toBe("default");

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const tip = sends.find((m: any) => m.type === "system" && m.subtype === "tip");

    expect(created).toMatchObject({
      permissionMode: "default",
      executionMode: "default",
      planMode: false,
    });
    expect(tip).toMatchObject({
      tipCode: "auto_mode_fallback_default",
      sessionId: created.sessionId,
    });

    bridge.close();
  });

  it("falls back Claude auto mode to default on resume when auto is unavailable", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    getSessionHistoryMock.mockResolvedValue([]);

    const sessionManager = (bridge as any).sessionManager;
    const realCreate = sessionManager.create.bind(sessionManager);
    let failFirstCreate = true;
    const createSpy = vi
      .spyOn(sessionManager, "create")
      .mockImplementation((...args: any[]) => {
        if (failFirstCreate) {
          failFirstCreate = false;
          throw new Error('Permission mode "auto" is unavailable for your plan');
        }
        return realCreate(...args);
      });

    (bridge as any).handleClientMessage(
      {
        type: "resume_session",
        sessionId: "claude-resume-1",
        projectPath: "/tmp/project-auto",
        provider: "claude",
        permissionMode: "auto",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    expect(createSpy.mock.calls[0]?.[1]?.permissionMode).toBe("auto");
    expect(createSpy.mock.calls[1]?.[1]?.permissionMode).toBe("default");

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const tip = sends.find((m: any) => m.type === "system" && m.subtype === "tip");

    expect(created).toMatchObject({
      permissionMode: "default",
      executionMode: "default",
      planMode: false,
      claudeSessionId: "claude-resume-1",
    });
    expect(tip).toMatchObject({
      tipCode: "auto_mode_fallback_default",
      sessionId: created.sessionId,
    });

    bridge.close();
  });

  it("returns structured error when Claude auto mode cannot be enabled in-session", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();

    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    const setPermissionModeMock = session.process.setPermissionMode as ReturnType<typeof vi.fn>;
    setPermissionModeMock.mockRejectedValue(
      new Error('Permission mode "auto" is unavailable for your plan'),
    );

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "auto",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toEqual({
      type: "error",
      message:
        "Auto mode is unavailable in this environment. Keeping the current permission mode.",
      errorCode: "auto_mode_unavailable",
    });

    bridge.close();
  });

  it("maps set_permission_mode plan to collaborationMode for codex session in-place when idle", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    expect(session).toBeDefined();
    session.status = "idle";
    (session.process as any).setApprovalPolicy("on-request");

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "plan",
      },
      ws,
    );

    const updatedSession = (bridge as any).sessionManager.get(sessionId);
    expect(updatedSession).toBeDefined();
    expect(updatedSession.id).toBe(sessionId);
    expect((bridge as any).sessionManager.list()).toHaveLength(1);

    bridge.close();
  });

  it("maps set_permission_mode plan to collaborationMode for codex session with restart when active", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const oldSessionId = created.sessionId as string;

    const oldSession = (bridge as any).sessionManager.get(oldSessionId);
    expect(oldSession).toBeDefined();
    oldSession.status = "running";

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId: oldSessionId,
        mode: "plan",
      },
      ws,
    );

    expect((bridge as any).sessionManager.get(oldSessionId)).toBeUndefined();

    const sessions = (bridge as any).sessionManager.list();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].id).not.toBe(oldSessionId);
    expect(sessions[0].provider).toBe("codex");

    bridge.close();
  });

  it("maps set_permission_mode to approval_policy for codex session", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    (bridge as any).wss.clients.add(ws);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    ws.send.mockClear();

    // Should not return an error — it maps to approval_policy internally
    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "bypassPermissions",
        approvalsReviewer: "auto_review",
      },
      ws,
    );

    const lastMessages = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const errors = lastMessages.filter((m: any) => m.type === "error");
    // No errors should be produced for valid permission mode on codex
    expect(errors.length).toBe(0);
    expect(session.process.setApprovalsReviewer).toHaveBeenCalledWith(
      "auto_review",
    );
    expect(session.codexSettings).toMatchObject({
      approvalPolicy: "on-request",
      approvalsReviewer: "auto_review",
    });
    const sessionList = lastMessages.find(
      (m: any) => m.type === "session_list",
    );
    expect(sessionList?.sessions[0].codexSettings).toMatchObject({
      approvalsReviewer: "auto_review",
    });

    bridge.close();
  });

  it("includes explicit execution and plan modes when codex sandbox change recreates session", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        executionMode: "fullAccess",
        planMode: true,
      },
      ws,
    );
    await Promise.resolve();

    const initialMessages = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = initialMessages.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const oldSessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(oldSessionId);
    session.process.approvalPolicy = "never";
    session.process.collaborationMode = "plan";

    const buildSessionCreatedMessageSpy = vi.spyOn(
      bridge as any,
      "buildSessionCreatedMessage",
    );
    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "set_sandbox_mode",
        sessionId: oldSessionId,
        sandboxMode: "off",
      },
      ws,
    );

    const params = buildSessionCreatedMessageSpy.mock.calls.at(-1)?.[0];
    expect(params).toBeDefined();
    expect(params.executionMode).toBe("fullAccess");
    expect(params.planMode).toBe(true);
    expect(params.permissionMode).toBe("plan");
    expect(params.sandboxMode).toBe("off");

    bridge.close();
  });

  it("includes permissionMode in codex session_created on start", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        permissionMode: "bypassPermissions",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toMatchObject({
      provider: "codex",
      permissionMode: "bypassPermissions",
    });

    bridge.close();
  });

  it("returns error when set_permission_mode is sent without active session", () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId: "missing",
        mode: "plan",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toEqual({
      type: "error",
      message: "No active session.",
    });

    bridge.close();
  });

  it("can force set_permission_mode failure for testing", () => {
    vi.stubEnv("BRIDGE_FAIL_SET_PERMISSION_MODE", "1");
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId: "s-1",
        mode: "plan",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toEqual({
      type: "error",
      message: "Failed to set permission mode: forced test failure",
      errorCode: "set_permission_mode_rejected",
    });

    bridge.close();
  });

  it("can force set_sandbox_mode failure for testing", () => {
    vi.stubEnv("BRIDGE_FAIL_SET_SANDBOX_MODE", "1");
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "set_sandbox_mode",
        sessionId: "s-1",
        sandboxMode: "off",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toEqual({
      type: "error",
      message: "Failed to set sandbox mode: forced test failure",
      errorCode: "set_sandbox_mode_rejected",
    });

    bridge.close();
  });

  it("returns debug_bundle for an active session", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    session.history.push({ type: "status", status: "running" });

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "get_debug_bundle",
        sessionId,
        includeDiff: false,
        traceLimit: 50,
      },
      ws,
    );

    const bundle = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(bundle.type).toBe("debug_bundle");
    expect(bundle.sessionId).toBe(sessionId);
    expect(bundle.session.provider).toBe("claude");
    // History may contain a system/tip (git_not_available) before the running status
    expect(bundle.historySummary.some((s: string) => s.includes("running"))).toBe(true);
    expect(Array.isArray(bundle.debugTrace)).toBe(true);
    expect(typeof bundle.traceFilePath).toBe("string");
    expect(typeof bundle.savedBundlePath).toBe("string");
    expect(bundle.reproRecipe).toMatchObject({
      wsUrlHint: expect.any(String),
      resumeSessionMessage: expect.objectContaining({
        type: "resume_session",
        provider: "claude",
      }),
    });
    expect(typeof bundle.agentPrompt).toBe("string");

    bridge.close();
  });

  it("does not create debug trace buckets for unknown session ids", () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId: "missing-session",
        mode: "plan",
      },
      ws,
    );

    expect((bridge as any).debugEvents.size).toBe(0);
    bridge.close();
  });

  it("cleans debug events when session is stopped", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    expect((bridge as any).debugEvents.has(sessionId)).toBe(true);

    (bridge as any).handleClientMessage(
      {
        type: "stop_session",
        sessionId,
      },
      ws,
    );

    expect((bridge as any).debugEvents.has(sessionId)).toBe(false);
    bridge.close();
  });

  it("clearContext approve recreates session immediately with plan input", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "claude-session-1";
    (session.process.getPendingPermission as ReturnType<typeof vi.fn>).mockReturnValue({
      toolUseId: "tool-exit-1",
      toolName: "ExitPlanMode",
      input: { plan: "original plan text" },
    });
    const broadcastSpy = vi.spyOn(bridge as any, "broadcast");

    (bridge as any).handleClientMessage(
      {
        type: "approve",
        id: "tool-exit-1",
        clearContext: true,
        sessionId,
      },
      ws,
    );

    expect((bridge as any).sessionManager.get(sessionId)).toBeUndefined();
    expect(session.process.approve).not.toHaveBeenCalled();

    const sessions = (bridge as any).sessionManager.list();
    expect(sessions).toHaveLength(1);
    const newSession = (bridge as any).sessionManager.get(sessions[0].id);
    expect(newSession.startOptions).toMatchObject({
      sessionId: "claude-session-1",
      continueMode: true,
      initialInput: "original plan text",
    });
    const clearContextCreated = broadcastSpy.mock.calls
      .map((call: unknown[]) => call[0] as Record<string, unknown>)
      .find(
        (m) =>
          m.type === "system" &&
          m.subtype === "session_created" &&
          m.clearContext === true,
      );
    expect(clearContextCreated).toMatchObject({
      sourceSessionId: sessionId,
    });

    bridge.close();
  });

  it("sends push notification once per permission toolUseId", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    globalThis.fetch = fetchMock as unknown as typeof globalThis.fetch;
    const mockAuth = {
      uid: "bridge-test",
      getIdToken: vi.fn(async () => "mock-token"),
      initialize: vi.fn(async () => {}),
    };

    const bridge = new BridgeWebSocketServer({ server: httpServer, firebaseAuth: mockAuth as any });
    (bridge as any).broadcastSessionMessage("s-1", {
      type: "permission_request",
      toolUseId: "tool-1",
      toolName: "AskUserQuestion",
      input: {},
    });
    (bridge as any).broadcastSessionMessage("s-1", {
      type: "permission_request",
      toolUseId: "tool-1",
      toolName: "AskUserQuestion",
      input: {},
    });

    await Promise.resolve();
    await Promise.resolve();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const payload = JSON.parse(String(init.body)) as Record<string, unknown>;
    expect(payload).toMatchObject({
      op: "notify",
      bridgeId: "bridge-test",
      eventType: "ask_user_question",
    });

    bridge.close();
  });

  it("sends push notification for successful result and skips stopped result", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    globalThis.fetch = fetchMock as unknown as typeof globalThis.fetch;
    const mockAuth = {
      uid: "bridge-test",
      getIdToken: vi.fn(async () => "mock-token"),
      initialize: vi.fn(async () => {}),
    };

    const bridge = new BridgeWebSocketServer({ server: httpServer, firebaseAuth: mockAuth as any });
    (bridge as any).broadcastSessionMessage("s-1", {
      type: "result",
      subtype: "success",
      duration: 3.2,
      cost: 0.0045,
    });
    (bridge as any).broadcastSessionMessage("s-1", {
      type: "result",
      subtype: "stopped",
    });

    await Promise.resolve();
    await Promise.resolve();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    const payload = JSON.parse(String(init.body)) as Record<string, unknown>;
    expect(payload).toMatchObject({
      op: "notify",
      bridgeId: "bridge-test",
      eventType: "session_completed",
    });

    bridge.close();
  });

  it("claude busy input is acked as queued and interrupts current turn", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    session.process.isWaitingForInput = false;
    session.process.sendInput.mockReturnValue(true);

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "interrupt this",
      },
      ws,
    );

    const inputAck = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "input_ack");
    expect(inputAck).toMatchObject({
      type: "input_ack",
      sessionId,
      queued: true,
    });

    expect(session.process.sendInput).toHaveBeenCalledWith("interrupt this");
    expect(session.process.interrupt).toHaveBeenCalledTimes(1);

    bridge.close();
  });

  it("claude input uses enqueue result for queued ack and interrupt", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);

    // Simulate race: snapshot says idle, but SDK queues the input.
    session.process.isWaitingForInput = true;
    session.process.sendInput.mockReturnValue(true);

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "race queued",
      },
      ws,
    );

    const inputAck = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "input_ack");
    expect(inputAck).toMatchObject({
      type: "input_ack",
      sessionId,
      queued: true,
    });
    expect(session.process.interrupt).toHaveBeenCalledTimes(1);

    bridge.close();
  });

  it("codex busy input is rejected", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    session.process.isWaitingForInput = false;

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "while busy",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toMatchObject({
      type: "input_rejected",
      sessionId,
      reason: "Process is busy",
    });
    expect(session.process.sendInput).not.toHaveBeenCalled();

    bridge.close();
  });

  it("includes sourceSessionId in rewind conversation session_created", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = { readyState: OPEN_STATE, send: vi.fn() } as any;

    // Create a session first
    (bridge as any).handleClientMessage(
      { type: "start", projectPath: "/tmp/rewind-test", provider: "claude" },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();

    // Send rewind (conversation mode)
    (bridge as any).handleClientMessage(
      { type: "rewind", sessionId, targetUuid: "user-msg-1", mode: "conversation" },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const rewindSends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const rewindCreated = rewindSends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(rewindCreated).toBeDefined();
    expect(rewindCreated.sourceSessionId).toBe(sessionId);

    bridge.close();
  });

  it("includes sourceSessionId in rewind both session_created", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = { readyState: OPEN_STATE, send: vi.fn() } as any;

    (bridge as any).handleClientMessage(
      { type: "start", projectPath: "/tmp/rewind-both-test", provider: "claude" },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();

    // Send rewind (both mode)
    (bridge as any).handleClientMessage(
      { type: "rewind", sessionId, targetUuid: "user-msg-1", mode: "both" },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const rewindSends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const rewindCreated = rewindSends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(rewindCreated).toBeDefined();
    expect(rewindCreated.sourceSessionId).toBe(sessionId);

    bridge.close();
  });

  it("uses active codex thread/list for codex recent sessions", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );

    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const session = (bridge as any).sessionManager.get(created.sessionId);
    session.process.listThreads.mockResolvedValue({
      data: [
        {
          id: "thr_codex_1",
          preview: "Investigate crash",
          createdAt: 1771492643,
          updatedAt: 1771496243,
          cwd: "/tmp/project-codex",
          agentNickname: "Atlas",
          agentRole: "explorer",
          gitBranch: "feat/protocol",
          name: "Crash triage",
        },
      ],
      nextCursor: null,
    });
    getAllRecentSessionsMock.mockResolvedValue({
      sessions: [
        {
          sessionId: "thr_codex_1",
          provider: "codex",
          projectPath: "/tmp/project-codex",
          firstPrompt: "Investigate crash",
          created: "2026-02-19T10:10:43.000Z",
          modified: "2026-02-19T11:10:43.000Z",
          gitBranch: "feat/protocol",
          isSidechain: false,
          codexSettings: {
            approvalPolicy: "never",
            sandboxMode: "danger-full-access",
            model: "gpt-5.3-codex",
          },
          resumeCwd: "/tmp/project-codex-worktree",
        },
      ],
      hasMore: false,
    });

    const payload = await (bridge as any).listRecentCodexThreads(
      {
        type: "list_recent_sessions",
        provider: "codex",
        projectPath: "/tmp/project-codex",
      },
    );

    expect(session.process.listThreads).toHaveBeenCalledWith({
      limit: 20,
      cwd: "/tmp/project-codex",
      searchTerm: undefined,
    });
    expect(getAllRecentSessionsMock).toHaveBeenCalledWith({
      provider: "codex",
      projectPath: "/tmp/project-codex",
      archivedSessionIds: expect.any(Set),
    });
    expect(payload.sessions).toHaveLength(1);
    expect(payload.sessions[0]).toMatchObject({
      provider: "codex",
      sessionId: "thr_codex_1",
      name: "Crash triage",
      agentNickname: "Atlas",
      agentRole: "explorer",
      gitBranch: "feat/protocol",
      projectPath: "/tmp/project-codex",
      resumeCwd: "/tmp/project-codex-worktree",
      codexSettings: {
        approvalPolicy: "never",
        sandboxMode: "danger-full-access",
        model: "gpt-5.3-codex",
      },
    });

    bridge.close();
  });

  it("uses standalone codex app-server for codex recent sessions when no active session exists", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const stop = vi.fn();

    (bridge as any).createStandaloneCodexProcess = vi.fn(async () => ({
      listThreads: vi.fn(async () => ({
        data: [
          {
            id: "thr_codex_2",
            preview: "Review failing tests",
            createdAt: 1771492643,
            updatedAt: 1771496243,
            cwd: "/tmp/project-codex",
            agentNickname: null,
            agentRole: null,
            gitBranch: "fix/tests",
            name: "Test failures",
          },
        ],
        nextCursor: null,
      })),
      stop,
    }));

    const payload = await (bridge as any).listRecentCodexThreads(
      {
        type: "list_recent_sessions",
        provider: "codex",
        projectPath: "/tmp/project-codex",
      },
    );

    expect((bridge as any).createStandaloneCodexProcess).toHaveBeenCalledWith(
      "/tmp/project-codex",
    );
    expect(stop).toHaveBeenCalledTimes(1);
    expect(getAllRecentSessionsMock).toHaveBeenCalledWith({
      provider: "codex",
      projectPath: "/tmp/project-codex",
      archivedSessionIds: expect.any(Set),
    });
    expect(payload.sessions[0]).toMatchObject({
      provider: "codex",
      sessionId: "thr_codex_2",
      name: "Test failures",
      gitBranch: "fix/tests",
      projectPath: "/tmp/project-codex",
    });

    bridge.close();
  });

  it("rejects git_commit autoGenerate without sessionId", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "git_commit",
        projectPath: "/tmp/project-a",
        autoGenerate: true,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends).toContainEqual({
      type: "git_commit_result",
      success: false,
      error: "git_commit with autoGenerate=true requires sessionId",
    });

    bridge.close();
  });

  it("rejects git_commit autoGenerate when projectPath does not match session cwd", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "git_commit",
        sessionId,
        projectPath: "/tmp/other-project",
        autoGenerate: true,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends).toContainEqual({
      type: "git_commit_result",
      success: false,
      error: "git_commit projectPath must match the active session cwd",
    });

    bridge.close();
  });

  it("auto-generates commit message for claude session", async () => {
    generateCommitMessageMock.mockReturnValue("feat: generated by claude");
    gitCommitMock.mockReturnValue({
      hash: "abc1234",
      message: "feat: generated by claude",
    });

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-a",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "git_commit",
        sessionId,
        projectPath: "/tmp/project-a",
        autoGenerate: true,
      },
      ws,
    );

    expect(generateCommitMessageMock).toHaveBeenCalledWith({
      provider: "claude",
      projectPath: "/tmp/project-a",
      model: undefined,
    });
    expect(gitCommitMock).toHaveBeenCalledWith(
      "/tmp/project-a",
      "feat: generated by claude",
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends).toContainEqual({
      type: "git_commit_result",
      success: true,
      commitHash: "abc1234",
      message: "feat: generated by claude",
    });

    bridge.close();
  });

  it("auto-generates commit message for codex session", async () => {
    generateCommitMessageMock.mockReturnValue("fix: generated by codex");
    gitCommitMock.mockReturnValue({
      hash: "def5678",
      message: "fix: generated by codex",
    });

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.4",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "git_commit",
        sessionId,
        projectPath: "/tmp/project-codex",
        autoGenerate: true,
      },
      ws,
    );

    expect(generateCommitMessageMock).toHaveBeenCalledWith({
      provider: "codex",
      projectPath: "/tmp/project-codex",
      model: "gpt-5.4",
    });
    expect(gitCommitMock).toHaveBeenCalledWith(
      "/tmp/project-codex",
      "fix: generated by codex",
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends).toContainEqual({
      type: "git_commit_result",
      success: true,
      commitHash: "def5678",
      message: "fix: generated by codex",
    });

    bridge.close();
  });
});
