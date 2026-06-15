import { createServer } from "node:http";
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { execFileSync } from "node:child_process";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const {
  getSessionHistoryMock,
  getCodexSessionHistoryMock,
  codexThreadToSessionHistoryMock,
  extractMessageImagesMock,
  getAllRecentSessionsMock,
  getCodexSessionIndexMetadataMock,
  saveCodexSessionProfileMock,
  generateCommitMessageMock,
  gitCommitMock,
} = vi.hoisted(() => ({
  getSessionHistoryMock: vi.fn(),
  getCodexSessionHistoryMock: vi.fn(),
  codexThreadToSessionHistoryMock: vi.fn(),
  extractMessageImagesMock: vi.fn(),
  getAllRecentSessionsMock: vi.fn(),
  getCodexSessionIndexMetadataMock: vi.fn(),
  saveCodexSessionProfileMock: vi.fn(),
  generateCommitMessageMock: vi.fn(),
  gitCommitMock: vi.fn(),
}));

vi.mock("./sessions-index.js", () => ({
  getSessionHistory: getSessionHistoryMock,
  getCodexSessionHistory: getCodexSessionHistoryMock,
  codexThreadToSessionHistory: codexThreadToSessionHistoryMock,
  extractMessageImages: extractMessageImagesMock,
  codexUserTurnUuid: (ordinal: number) => `codex:user-turn:${ordinal}`,
  getAllRecentSessions: getAllRecentSessionsMock,
  getCodexSessionIndexMetadata: getCodexSessionIndexMetadataMock,
  saveCodexSessionProfile: saveCodexSessionProfileMock,
  renameClaudeSession: vi.fn().mockResolvedValue(true),
  renameCodexSession: vi.fn().mockResolvedValue(true),
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
    private onMessage: (sessionId: string, msg: any) => void;

    constructor(onMessage?: (sessionId: string, msg: any) => void) {
      this.onMessage = onMessage ?? (() => {});
    }

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
        status: "idle",
        sessionId: codexOptions && typeof codexOptions === "object" && "threadId" in codexOptions
          ? (codexOptions as { threadId?: string }).threadId
          : options?.sessionId,
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
        setModel: vi.fn(function (
          this: any,
          model: string,
          modelReasoningEffort?: string,
        ) {
          this.model = model;
          this.modelReasoningEffort = modelReasoningEffort;
        }),
        listThreads: vi.fn(async () => ({ data: [], nextCursor: null })),
        listAvailableModels: vi.fn(async () => []),
        readThread: vi.fn(async () => ({ id: "thread-read", turns: [] })),
        rollbackThread: vi.fn(async () => ({ id: "thread-rollback", turns: [] })),
        rollbackThreadById: vi.fn(async () => ({
          id: "thread-forked",
          turns: [],
        })),
        forkThread: vi.fn(async () => ({
          threadId: "thread-forked",
          thread: { id: "thread-forked", turns: [] },
        })),
        sendInput: vi.fn(() => false),
        sendInputWithImage: vi.fn(),
        sendInputWithImages: vi.fn(() => false),
        steerInputStructured: vi.fn(async () => {}),
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
        historyEntries: [],
        historyRevision: 0,
        historyLowWatermark: 1,
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

    queueCodexInput(id: string, input: any) {
      const session = this.sessions.get(id);
      if (!session || session.provider !== "codex" || session.codexQueuedInput) {
        return false;
      }
      session.codexQueuedInput = input;
      return true;
    }

    updateCodexQueuedInput(
      id: string,
      itemId: string,
      text: string,
      options?: { skills?: unknown[]; mentions?: unknown[] },
    ) {
      const session = this.sessions.get(id);
      if (!session?.codexQueuedInput || session.codexQueuedInput.itemId !== itemId) {
        return false;
      }
      session.codexQueuedInput = {
        ...session.codexQueuedInput,
        text,
        skills: options?.skills,
        mentions: options?.mentions,
      };
      return true;
    }

    cancelCodexQueuedInput(id: string, itemId: string) {
      const session = this.sessions.get(id);
      if (!session?.codexQueuedInput || session.codexQueuedInput.itemId !== itemId) {
        return false;
      }
      session.codexQueuedInput = undefined;
      return true;
    }

    async steerCodexQueuedInput(id: string, itemId: string) {
      const session = this.sessions.get(id);
      if (!session || session.provider !== "codex") {
        return { ok: false, error: "No active Codex session." };
      }
      const queued = session.codexQueuedInput;
      if (!queued || queued.itemId !== itemId) {
        return { ok: false, error: "Queued message not found." };
      }
      try {
        await session.process.steerInputStructured(queued.text, {
          images: queued.images,
          skills: queued.skills,
          mentions: queued.mentions,
        });
      } catch (err) {
        return {
          ok: false,
          error: err instanceof Error ? err.message : String(err),
        };
      }
      session.codexQueuedInput = undefined;
      const userMsg = {
        type: "user_input",
        text: queued.text,
        timestamp: new Date().toISOString(),
        ...(queued.userMessageUuid
          ? { userMessageUuid: queued.userMessageUuid }
          : {}),
        ...(queued.imageCount ? { imageCount: queued.imageCount } : {}),
        ...(queued.imageRefs ? { images: queued.imageRefs } : {}),
      };
      this.appendHistory(id, userMsg);
      this.onMessage(id, userMsg);
      return { ok: true };
    }

    appendHistory(id: string, msg: any) {
      const session = this.sessions.get(id);
      if (!session) return undefined;
      const entry = {
        seq: session.historyRevision + 1,
        message: msg,
      };
      msg.historySeq = entry.seq;
      session.historyRevision = entry.seq;
      session.history.push(msg);
      session.historyEntries.push(entry);
      if (session.history.length > 100) {
        session.history.shift();
        session.historyEntries.shift();
      }
      session.historyLowWatermark =
        session.historyEntries[0]?.seq ?? session.historyRevision + 1;
      return entry;
    }

    getHistorySince(id: string, sinceSeq: number) {
      const session = this.sessions.get(id);
      if (!session) return undefined;
      const entries = session.historyEntries;
      if (entries.length === 0) {
        return {
          kind: "delta",
          fromSeq: session.historyRevision + 1,
          toSeq: session.historyRevision,
          entries: [],
        };
      }
      const firstSeq = entries[0].seq;
      if (sinceSeq < firstSeq - 1) {
        return {
          kind: "snapshot",
          fromSeq: firstSeq,
          toSeq: session.historyRevision,
          entries,
          reason: "compacted",
        };
      }
      const deltaEntries = entries.filter((entry: any) => entry.seq > sinceSeq);
      return {
        kind: "delta",
        fromSeq: deltaEntries[0]?.seq ?? session.historyRevision + 1,
        toSeq: session.historyRevision,
        entries: deltaEntries,
      };
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
        queuedInput: s.codexQueuedInput,
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
        historyEntries: [],
        historyRevision: 0,
        historyLowWatermark: 1,
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
    codexThreadToSessionHistoryMock.mockReset();
    extractMessageImagesMock.mockReset();
    getAllRecentSessionsMock.mockReset();
    getCodexSessionIndexMetadataMock.mockReset();
    saveCodexSessionProfileMock.mockReset();
    generateCommitMessageMock.mockReset();
    gitCommitMock.mockReset();
    getAllRecentSessionsMock.mockResolvedValue({ sessions: [], hasMore: false });
    getCodexSessionIndexMetadataMock.mockResolvedValue(new Map());
    getCodexSessionHistoryMock.mockResolvedValue([]);
    codexThreadToSessionHistoryMock.mockReturnValue([]);
    extractMessageImagesMock.mockResolvedValue([]);
    saveCodexSessionProfileMock.mockResolvedValue(undefined);
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.unstubAllEnvs();
    httpServer.close();
  });

  it("echoes recent session request metadata for project scoped requests", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    getAllRecentSessionsMock.mockResolvedValue({
      sessions: [{ sessionId: "s1", projectPath: "/tmp/project" }],
      hasMore: true,
    });

    (bridge as any).handleClientMessage(
      {
        type: "list_recent_sessions",
        limit: 20,
        offset: 40,
        projectPath: "/tmp/project",
        requestScope: "project",
        provider: "claude",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();
    await new Promise((resolve) => setTimeout(resolve, 0));

    const recent = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "recent_sessions");
    expect(recent).toMatchObject({
      type: "recent_sessions",
      hasMore: true,
      limit: 20,
      offset: 40,
      projectPath: "/tmp/project",
      requestScope: "project",
    });

    bridge.close();
  });

  it("drops stale project scoped recent session responses after filter refresh", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    let resolveProject:
      | ((value: { sessions: any[]; hasMore: boolean }) => void)
      | undefined;
    let resolveList:
      | ((value: { sessions: any[]; hasMore: boolean }) => void)
      | undefined;
    getAllRecentSessionsMock
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveProject = resolve;
          }),
      )
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveList = resolve;
          }),
      );

    (bridge as any).handleClientMessage(
      {
        type: "list_recent_sessions",
        limit: 20,
        offset: 0,
        projectPath: "/tmp/project",
        requestScope: "project",
        provider: "claude",
      },
      ws,
    );
    (bridge as any).handleClientMessage(
      {
        type: "list_recent_sessions",
        limit: 20,
        offset: 0,
        provider: "claude",
      },
      ws,
    );

    resolveProject?.({
      sessions: [{ sessionId: "stale", projectPath: "/tmp/project" }],
      hasMore: true,
    });
    await new Promise((resolve) => setTimeout(resolve, 0));
    let recentMessages = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .filter((m: any) => m.type === "recent_sessions");
    expect(recentMessages).toHaveLength(0);

    resolveList?.({
      sessions: [{ sessionId: "fresh", projectPath: "/tmp/project" }],
      hasMore: false,
    });
    await new Promise((resolve) => setTimeout(resolve, 0));
    recentMessages = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .filter((m: any) => m.type === "recent_sessions");
    expect(recentMessages).toHaveLength(1);
    expect(recentMessages[0].sessions[0].sessionId).toBe("fresh");

    bridge.close();
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

  it("updates codex model list from app-server model/list", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).loadCodexModels = vi.fn(async () => [
      {
        model: "gpt-dynamic-default",
        supportedReasoningEfforts: ["low", "medium", "high"],
      },
      {
        model: "gpt-dynamic-fast",
        supportedReasoningEfforts: ["low"],
      },
    ]);

    await (bridge as any).refreshCodexModels("/tmp/project-models");
    (bridge as any).sendSessionList(ws);

    const sessionList = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((msg: any) => msg.type === "session_list");

    expect((bridge as any).loadCodexModels).toHaveBeenCalledWith(
      "/tmp/project-models",
    );
    expect(sessionList.codexModels).toEqual([
      "gpt-dynamic-default",
      "gpt-dynamic-fast",
    ]);
    expect(sessionList.codexModelReasoningEfforts).toEqual({
      "gpt-dynamic-default": ["low", "medium", "high"],
      "gpt-dynamic-fast": ["low"],
    });

    bridge.close();
  });

  it("falls back to built-in codex model list when model/list fails", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).loadCodexModels = vi.fn(async () => {
      throw new Error("unsupported method");
    });

    await (bridge as any).refreshCodexModels("/tmp/project-models");
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

    bridge.close();
  });

  it("suppresses conversation_queue for clients that did not opt in", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    const msg = {
      type: "conversation_queue",
      sessionId: "s-1",
      limit: 1,
      items: [],
    };

    (bridge as any).send(ws, msg);
    expect(ws.send).not.toHaveBeenCalled();

    await (bridge as any).handleClientMessage(
      {
        type: "client_capabilities",
        supportedServerMessages: ["conversation_queue"],
      },
      ws,
    );
    (bridge as any).send(ws, msg);
    expect(ws.send).toHaveBeenCalledWith(JSON.stringify(msg));

    bridge.close();
  });

  it("suppresses prompt_history_status for clients that did not opt in", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    const msg = {
      type: "prompt_history_status",
      bridgeInstanceId: "bridge-1",
      revision: 1,
      entryCount: 2,
    };

    (bridge as any).send(ws, msg);
    expect(ws.send).not.toHaveBeenCalled();

    await (bridge as any).handleClientMessage(
      {
        type: "client_capabilities",
        supportedServerMessages: ["prompt_history_status"],
      },
      ws,
    );
    (bridge as any).send(ws, msg);
    expect(ws.send).toHaveBeenCalledWith(JSON.stringify(msg));

    bridge.close();
  });

  it("rejects start when selected codex profile does not exist", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    vi.spyOn(bridge as any, "validateCodexProfile").mockResolvedValue(false);

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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
    await (bridge as any).handleClientMessage(
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

  it("serves get_history_delta with sequenced messages", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const manager = (bridge as any).sessionManager;
    const first = manager.appendHistory(sessionId, {
      type: "status",
      status: "running",
    });
    const second = manager.appendHistory(sessionId, {
      type: "status",
      status: "idle",
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: first.seq,
      },
      ws,
    );

    const delta = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "history_delta");
    expect(delta).toMatchObject({
      sessionId,
      fromSeq: second.seq,
      toSeq: second.seq,
      messages: [{ seq: second.seq, message: { type: "status", status: "idle" } }],
      status: "idle",
    });

    bridge.close();
  });

  it("includes resume past_history before get_history_delta", async () => {
    getSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "previous prompt" }],
      },
      {
        role: "assistant",
        content: [{ type: "text", text: "previous answer" }],
      },
    ]);
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 1,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "past_history",
      sessionId,
      claudeSessionId: "claude-session-1",
      messages: [
        { role: "user" },
        { role: "assistant" },
      ],
    });
    expect(sends[1]).toMatchObject({
      type: "history_delta",
      sessionId,
    });

    bridge.close();
  });

  it("serves codex history deltas from canonical thread/read", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        rawItemId: "raw-user-1",
        timestamp: "2026-05-29T00:00:00.000Z",
        content: [{ type: "text", text: "sync this thread" }],
      },
      {
        role: "assistant",
        uuid: "assistant-1",
        content: [{ type: "text", text: "synced" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_1";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_1",
      turns: [],
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    expect(session.process.readThread).toHaveBeenCalledWith(
      "thr_codex_1",
      true,
    );
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends.some((m: any) => m.type === "history_delta")).toBe(false);
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 2,
      status: "idle",
      reason: "reset",
      messages: [
        {
          seq: 1,
          message: {
            type: "user_input",
            text: "sync this thread",
            userMessageUuid: "codex:user-turn:1",
            timestamp: "2026-05-29T00:00:00.000Z",
          },
        },
        {
          seq: 2,
          message: {
            type: "assistant",
            messageUuid: "assistant-1",
            message: {
              role: "assistant",
              content: [{ type: "text", text: "synced" }],
              model: "gpt-5.3-codex",
            },
          },
        },
      ],
    });
    expect(session.pastMessages).toHaveLength(2);
    expect(session.history).toEqual([]);
    expect(session.historyEntries).toEqual([]);
    expect(session.historyRevision).toBe(2);
    expect(session.codexCanonicalHistoryRevision).toBe(2);
    expect(session.codexUserTurnUuidByRawId?.get("raw-user-1")).toBe(
      "codex:user-turn:1",
    );

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "next turn",
      },
      ws,
    );

    const inputSends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(inputSends[0]).toMatchObject({
      type: "user_input",
      text: "next turn",
      userMessageUuid: "codex:user-turn:2",
      historySeq: 3,
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 2,
      },
      ws,
    );

    expect(session.process.readThread).toHaveBeenCalledTimes(1);
    const deltaSends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(deltaSends[0]).toMatchObject({
      type: "history_delta",
      sessionId,
      fromSeq: 3,
      toSeq: 3,
      messages: [
        {
          seq: 3,
          message: {
            type: "user_input",
            text: "next turn",
            userMessageUuid: "codex:user-turn:2",
            historySeq: 3,
          },
        },
      ],
    });

    bridge.close();
  });

  it("serves codex get_history as legacy history from canonical thread/read", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        timestamp: "2026-05-29T00:00:00.000Z",
        content: [{ type: "text", text: "restore legacy shape" }],
      },
      {
        role: "assistant",
        uuid: "assistant-legacy-1",
        content: [{ type: "text", text: "legacy history restored" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_legacy";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_legacy",
      turns: [],
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history",
        sessionId,
      },
      ws,
    );

    expect(session.process.readThread).toHaveBeenCalledWith(
      "thr_codex_legacy",
      true,
    );
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends.some((m: any) => m.type === "history_snapshot")).toBe(false);
    expect(sends[0]).toMatchObject({
      type: "history",
      sessionId,
      messages: [
        {
          type: "user_input",
          text: "restore legacy shape",
          userMessageUuid: "codex:user-turn:1",
          timestamp: "2026-05-29T00:00:00.000Z",
        },
        {
          type: "assistant",
          messageUuid: "assistant-legacy-1",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "legacy history restored" }],
            model: "gpt-5.3-codex",
          },
        },
      ],
    });
    expect(sends[1]).toMatchObject({
      type: "status",
      status: "idle",
      sessionId,
    });

    bridge.close();
  });

  it("serves empty codex history for unmaterialized threads", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_empty";
    session.process.readThread.mockRejectedValue(
      new Error(
        "thread thr_codex_empty is not materialized yet; includeTurns is unavailable before first user message",
      ),
    );

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    expect(getCodexSessionHistoryMock).not.toHaveBeenCalled();
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends.some((m: any) => m.type === "error")).toBe(false);
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 0,
      messages: [],
      reason: "reset",
    });
    expect(session.pastMessages).toEqual([]);
    expect(session.history).toEqual([]);
    expect(session.historyRevision).toBe(0);
    expect(session.codexCanonicalHistoryRevision).toBe(0);

    bridge.close();
  });

  it("preserves codex live history when a canonical delta reset is needed", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        timestamp: "2026-05-29T00:00:00.000Z",
        content: [{ type: "text", text: "restore this thread" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const manager = (bridge as any).sessionManager;
    const session = manager.get(sessionId);
    session.claudeSessionId = "thr_codex_live";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_live",
      turns: [],
    });
    manager.appendHistory(sessionId, {
      type: "assistant",
      message: {
        id: "live-assistant-1",
        role: "assistant",
        content: [{ type: "text", text: "live answer still streaming" }],
        model: "gpt-5.3-codex",
      },
      messageUuid: "live-assistant-1",
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 2,
      reason: "reset",
      messages: [
        {
          seq: 1,
          message: {
            type: "user_input",
            text: "restore this thread",
            userMessageUuid: "codex:user-turn:1",
          },
        },
        {
          seq: 2,
          message: {
            type: "assistant",
            messageUuid: "live-assistant-1",
            message: {
              id: "live-assistant-1",
              role: "assistant",
              content: [{ type: "text", text: "live answer still streaming" }],
              model: "gpt-5.3-codex",
            },
          },
        },
      ],
    });
    expect(session.codexCanonicalHistoryRevision).toBe(1);
    expect(session.historyEntries).toMatchObject([
      {
        seq: 2,
        message: {
          type: "assistant",
          messageUuid: "live-assistant-1",
        },
      },
    ]);
    expect(session.historyRevision).toBe(2);

    bridge.close();
  });

  it("keeps codex live assistant with same text as canonical assistant when ids differ", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "assistant",
        uuid: "canonical-ok",
        content: [{ type: "text", text: "OK" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const manager = (bridge as any).sessionManager;
    const session = manager.get(sessionId);
    session.claudeSessionId = "thr_codex_same_text";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_same_text",
      turns: [],
    });
    manager.appendHistory(sessionId, {
      type: "assistant",
      message: {
        id: "live-ok",
        role: "assistant",
        content: [{ type: "text", text: "OK" }],
        model: "gpt-5.3-codex",
      },
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 2,
      messages: [
        {
          seq: 1,
          message: {
            type: "assistant",
            messageUuid: "canonical-ok",
            message: {
              id: "canonical-ok",
              role: "assistant",
              content: [{ type: "text", text: "OK" }],
              model: "gpt-5.3-codex",
            },
          },
        },
        {
          seq: 2,
          message: {
            type: "assistant",
            message: {
              id: "live-ok",
              role: "assistant",
              content: [{ type: "text", text: "OK" }],
              model: "gpt-5.3-codex",
            },
          },
        },
      ],
    });
    expect(session.historyEntries).toMatchObject([
      {
        seq: 2,
        message: {
          type: "assistant",
          message: {
            id: "live-ok",
          },
        },
      },
    ]);

    bridge.close();
  });

  it("deduplicates codex live tool use by canonical item id", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: "cmd-1",
            name: "Bash",
            input: { command: "npm test" },
          },
        ],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const manager = (bridge as any).sessionManager;
    const session = manager.get(sessionId);
    session.claudeSessionId = "thr_codex_tool_dedupe";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_tool_dedupe",
      turns: [],
    });
    manager.appendHistory(sessionId, {
      type: "assistant",
      message: {
        id: "cmd-1",
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: "cmd-1",
            name: "Bash",
            input: { command: "npm test" },
          },
        ],
        model: "gpt-5.3-codex",
      },
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 1,
      messages: [
        {
          seq: 1,
          message: {
            type: "assistant",
            message: {
              id: "cmd-1",
              content: [
                {
                  type: "tool_use",
                  id: "cmd-1",
                  name: "Bash",
                },
              ],
            },
          },
        },
      ],
    });
    expect(session.historyEntries).toEqual([]);
    expect(session.historyRevision).toBe(1);

    bridge.close();
  });

  it("deduplicates codex live tool result by canonical item id when content differs", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "tool_result",
        toolUseId: "cmd-1",
        toolName: "Bash",
        content: "status: completed\nexitCode: 0\nclean",
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const manager = (bridge as any).sessionManager;
    const session = manager.get(sessionId);
    session.claudeSessionId = "thr_codex_tool_result_dedupe";
    session.codexSettings = { model: "gpt-5.3-codex" };
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_tool_result_dedupe",
      turns: [],
    });
    manager.appendHistory(sessionId, {
      type: "tool_result",
      toolUseId: "cmd-1",
      toolName: "Bash",
      content: "clean",
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 1,
      messages: [
        {
          seq: 1,
          message: {
            type: "tool_result",
            toolUseId: "cmd-1",
            toolName: "Bash",
            content: "status: completed\nexitCode: 0\nclean",
          },
        },
      ],
    });
    expect(session.historyEntries).toEqual([]);
    expect(session.historyRevision).toBe(1);

    bridge.close();
  });

  it("preserves codex live history appended while canonical read is pending", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "stored before pending read" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
        model: "gpt-5.3-codex",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const manager = (bridge as any).sessionManager;
    const session = manager.get(sessionId);
    session.claudeSessionId = "thr_codex_pending";
    session.codexSettings = { model: "gpt-5.3-codex" };

    let resolveRead!: (thread: unknown) => void;
    const pendingRead = new Promise((resolve) => {
      resolveRead = resolve;
    });
    session.process.readThread.mockReturnValue(pendingRead);

    ws.send.mockClear();
    const pendingHistory = (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );
    await Promise.resolve();

    manager.appendHistory(sessionId, {
      type: "assistant",
      message: {
        id: "live-during-read",
        role: "assistant",
        content: [{ type: "text", text: "arrived during read" }],
        model: "gpt-5.3-codex",
      },
      messageUuid: "live-during-read",
    });
    resolveRead({ id: "thr_codex_pending", turns: [] });
    await pendingHistory;

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      sessionId,
      fromSeq: 1,
      toSeq: 2,
      messages: [
        {
          seq: 1,
          message: {
            type: "user_input",
            text: "stored before pending read",
            userMessageUuid: "codex:user-turn:1",
          },
        },
        {
          seq: 2,
          message: {
            type: "assistant",
            messageUuid: "live-during-read",
            message: {
              id: "live-during-read",
              role: "assistant",
              content: [{ type: "text", text: "arrived during read" }],
              model: "gpt-5.3-codex",
            },
          },
        },
      ],
    });
    expect(session.historyEntries).toMatchObject([
      {
        seq: 2,
        message: {
          type: "assistant",
          messageUuid: "live-during-read",
        },
      },
    ]);

    bridge.close();
  });

  it("keeps codex canonical tool result images in history snapshots", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "tool_result",
        toolUseId: "ig-1",
        toolName: "ImageGeneration",
        content: "status: completed",
        imageBase64: [{ data: "aGVsbG8=", mimeType: "image/png" }],
      },
    ]);
    const imageStore = {
      extractImagePaths: vi.fn(() => []),
      registerImages: vi.fn(async () => []),
      registerFromBase64: vi.fn(() => ({
        id: "img-canonical",
        url: "/images/img-canonical",
        mimeType: "image/png",
      })),
    };

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      imageStore: imageStore as any,
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_images";
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_images",
      turns: [],
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    expect(imageStore.registerFromBase64).toHaveBeenCalledWith(
      "aGVsbG8=",
      "image/png",
    );
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      messages: [
        {
          seq: 1,
          message: {
            type: "tool_result",
            toolUseId: "ig-1",
            toolName: "ImageGeneration",
            images: [
              {
                id: "img-canonical",
                url: "/images/img-canonical",
                mimeType: "image/png",
              },
            ],
          },
        },
      ],
    });

    bridge.close();
  });

  it("keeps codex canonical user image refs in history snapshots", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "look at this" }],
        imageCount: 2,
        imagePaths: ["/tmp/project-codex/local.png"],
        imageBase64: [{ data: "aGVsbG8=", mimeType: "image/png" }],
      },
    ]);
    const imageStore = {
      registerImages: vi.fn(async () => [
        {
          id: "img-local",
          url: "/images/img-local",
          mimeType: "image/png",
        },
      ]),
      registerFromBase64: vi.fn(() => ({
        id: "img-base64",
        url: "/images/img-base64",
        mimeType: "image/png",
      })),
    };

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      imageStore: imageStore as any,
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_user_images";
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_user_images",
      turns: [],
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );

    expect(imageStore.registerImages).toHaveBeenCalledWith(
      ["/tmp/project-codex/local.png"],
      resolve("/tmp/project-codex"),
    );
    expect(imageStore.registerFromBase64).toHaveBeenCalledWith(
      "aGVsbG8=",
      "image/png",
    );
    expect(extractMessageImagesMock).not.toHaveBeenCalled();
    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(sends[0]).toMatchObject({
      type: "history_snapshot",
      messages: [
        {
          seq: 1,
          message: {
            type: "user_input",
            text: "look at this",
            imageCount: 2,
            images: [
              {
                id: "img-local",
                url: "/images/img-local",
                mimeType: "image/png",
              },
              {
                id: "img-base64",
                url: "/images/img-base64",
                mimeType: "image/png",
              },
            ],
          },
        },
      ],
    });

    bridge.close();
  });

  it("reports codex canonical history read failures without JSONL fallback", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_error";
    session.process.readThread.mockRejectedValue(new Error("rpc unavailable"));

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history",
        sessionId,
      },
      ws,
    );

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(getCodexSessionHistoryMock).not.toHaveBeenCalled();
    expect(sends).toEqual([
      {
        type: "error",
        message:
          "Failed to read Codex thread history: rpc unavailable",
      },
    ]);

    bridge.close();
  });

  it("keeps restored image generation results in past history order", async () => {
    getSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        content: [{ type: "text", text: "$imagegen make a hero" }],
      },
      {
        role: "tool_result",
        toolUseId: "ig-1",
        toolName: "ImageGeneration",
        content: "status: completed\nsavedPath: /tmp/generated.png",
        imagePaths: ["/tmp/generated.png"],
      },
    ]);
    const imageStore = {
      extractImagePaths: vi.fn(() => []),
      registerImages: vi.fn(async () => [
        { id: "img-1", url: "/images/img-1", mimeType: "image/png" },
      ]),
    };

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      imageStore: imageStore as any,
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const resumeSends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = resumeSends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    const newSessionId = created.sessionId as string;

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      { type: "get_history", sessionId: newSessionId },
      ws,
    );

    const historySends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(historySends[0]).toMatchObject({
      type: "past_history",
      messages: [
        { role: "user" },
        {
          role: "tool_result",
          toolUseId: "ig-1",
          toolName: "ImageGeneration",
          images: [{ id: "img-1", url: "/images/img-1", mimeType: "image/png" }],
        },
      ],
    });
    expect(historySends[1]).toMatchObject({ type: "history", messages: [] });

    bridge.close();
  });

  it("restores user message images into past history", async () => {
    getSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        uuid: "user-msg-1",
        content: [{ type: "text", text: "What is in this image?" }],
        imageCount: 1,
      },
    ]);
    extractMessageImagesMock.mockResolvedValue([
      { base64: "aGVsbG8=", mimeType: "image/png" },
    ]);
    const imageStore = {
      registerFromBase64: vi.fn(() => ({
        id: "img-user",
        url: "/images/img-user",
        mimeType: "image/png",
      })),
    };

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      imageStore: imageStore as any,
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const resumeSends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = resumeSends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    const newSessionId = created.sessionId as string;

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      { type: "get_history", sessionId: newSessionId },
      ws,
    );

    const historySends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(extractMessageImagesMock).toHaveBeenCalledWith(
      "claude-session-1",
      "user-msg-1",
    );
    expect(historySends[0]).toMatchObject({
      type: "past_history",
      messages: [
        {
          role: "user",
          uuid: "user-msg-1",
          imageCount: 1,
          images: [
            { id: "img-user", url: "/images/img-user", mimeType: "image/png" },
          ],
        },
      ],
    });

    bridge.close();
  });

  it("registers restored image generation base64 results through regular history", async () => {
    getSessionHistoryMock.mockResolvedValue([
      {
        role: "tool_result",
        toolUseId: "ig-2",
        toolName: "ImageGeneration",
        content: "status: completed",
        imageBase64: [{ data: "aGVsbG8=", mimeType: "image/png" }],
      },
    ]);
    const imageStore = {
      extractImagePaths: vi.fn(() => []),
      registerImages: vi.fn(async () => []),
      registerFromBase64: vi.fn(() => ({
        id: "img-base64",
        url: "/images/img-base64",
        mimeType: "image/png",
      })),
    };

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      imageStore: imageStore as any,
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const resumeSends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = resumeSends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    const newSessionId = created.sessionId as string;

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      { type: "get_history", sessionId: newSessionId },
      ws,
    );

    const historySends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(imageStore.registerFromBase64).toHaveBeenCalledWith(
      "aGVsbG8=",
      "image/png",
    );
    expect(historySends[0]).toMatchObject({
      type: "past_history",
      messages: [
        {
          role: "tool_result",
          toolUseId: "ig-2",
          toolName: "ImageGeneration",
          images: [
            {
              id: "img-base64",
              url: "/images/img-base64",
              mimeType: "image/png",
            },
          ],
        },
      ],
    });
    expect(historySends[1]).toMatchObject({ type: "history", messages: [] });

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

    await (bridge as any).handleClientMessage(
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

  it("returns unstaged diff for mixed ASCII and non-ASCII untracked paths", async () => {
    const projectPath = mkdtempSync(resolve(tmpdir(), "ccpocket-diff-"));
    execFileSync("git", ["init"], { cwd: projectPath });
    execFileSync("git", ["config", "user.email", "test@test.com"], {
      cwd: projectPath,
    });
    execFileSync("git", ["config", "user.name", "Test"], { cwd: projectPath });
    writeFileSync(resolve(projectPath, "initial.txt"), "initial\n");
    execFileSync("git", ["add", "initial.txt"], { cwd: projectPath });
    execFileSync("git", ["commit", "-m", "initial"], { cwd: projectPath });
    mkdirSync(resolve(projectPath, "docs"));
    writeFileSync(resolve(projectPath, "docs", "啊.md"), "hello\n");
    writeFileSync(resolve(projectPath, "normal.txt"), "normal\n");

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: [projectPath],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    try {
      await (bridge as any).handleClientMessage(
        {
          type: "get_diff",
          projectPath,
          staged: false,
        },
        ws,
      );

      await expect
        .poll(() =>
          ws.send.mock.calls
            .map((c: unknown[]) => JSON.parse(c[0] as string))
            .find((m: any) => m.type === "diff_result"),
        )
        .toBeDefined();

      const diffResult = ws.send.mock.calls
        .map((c: unknown[]) => JSON.parse(c[0] as string))
        .find((m: any) => m.type === "diff_result");
      expect(diffResult.error).toBeUndefined();
      expect(diffResult.diff).toContain("diff --git a/docs/啊.md b/docs/啊.md");
      expect(diffResult.diff).toContain("diff --git a/normal.txt b/normal.txt");
      expect(diffResult.diff).not.toContain("\\345\\225");
    } finally {
      bridge.close();
      rmSync(projectPath, { recursive: true, force: true });
    }
  });

  it("returns all diff for mixed staged and non-ASCII untracked paths", async () => {
    const projectPath = mkdtempSync(resolve(tmpdir(), "ccpocket-diff-"));
    execFileSync("git", ["init"], { cwd: projectPath });
    execFileSync("git", ["config", "user.email", "test@test.com"], {
      cwd: projectPath,
    });
    execFileSync("git", ["config", "user.name", "Test"], { cwd: projectPath });
    writeFileSync(resolve(projectPath, "initial.txt"), "initial\n");
    execFileSync("git", ["add", "initial.txt"], { cwd: projectPath });
    execFileSync("git", ["commit", "-m", "initial"], { cwd: projectPath });
    writeFileSync(resolve(projectPath, "initial.txt"), "changed\n");
    execFileSync("git", ["add", "initial.txt"], { cwd: projectPath });
    mkdirSync(resolve(projectPath, "docs"));
    writeFileSync(resolve(projectPath, "docs", "啊.md"), "hello\n");

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: [projectPath],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    try {
      await (bridge as any).handleClientMessage(
        {
          type: "get_diff",
          projectPath,
        },
        ws,
      );

      await expect
        .poll(() =>
          ws.send.mock.calls
            .map((c: unknown[]) => JSON.parse(c[0] as string))
            .find((m: any) => m.type === "diff_result"),
        )
        .toBeDefined();

      const diffResult = ws.send.mock.calls
        .map((c: unknown[]) => JSON.parse(c[0] as string))
        .find((m: any) => m.type === "diff_result");
      expect(diffResult.error).toBeUndefined();
      expect(diffResult.diff).toContain("diff --git a/initial.txt b/initial.txt");
      expect(diffResult.diff).toContain("diff --git a/docs/啊.md b/docs/啊.md");
      expect(diffResult.diff).not.toContain("\\345\\225");
    } finally {
      bridge.close();
      rmSync(projectPath, { recursive: true, force: true });
    }
  });

  it("returns base64 image data for image file peek", async () => {
    const projectPath = mkdtempSync(resolve(tmpdir(), "ccpocket-bridge-"));
    const pngBase64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==";
    writeFileSync(resolve(projectPath, "pixel.png"), Buffer.from(pngBase64, "base64"));

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: [projectPath],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    try {
      await (bridge as any).handleClientMessage(
        {
          type: "read_file",
          projectPath,
          filePath: "pixel.png",
        },
        ws,
      );

      await expect.poll(() => ws.send.mock.calls.length).toBeGreaterThan(0);

      const sends = ws.send.mock.calls.map((c: unknown[]) =>
        JSON.parse(c[0] as string),
      );
      expect(sends).toContainEqual({
        type: "file_content",
        filePath: "pixel.png",
        kind: "image",
        content: "",
        base64: pngBase64,
        mimeType: "image/png",
        sizeBytes: Buffer.from(pngBase64, "base64").length,
      });
    } finally {
      bridge.close();
      rmSync(projectPath, { recursive: true, force: true });
    }
  });

  it("keeps text file peek responses as text content", async () => {
    const projectPath = mkdtempSync(resolve(tmpdir(), "ccpocket-bridge-"));
    writeFileSync(resolve(projectPath, "README.md"), "# Hello\n\nWorld\n");

    const bridge = new BridgeWebSocketServer({
      server: httpServer,
      allowedDirs: [projectPath],
    });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    try {
      await (bridge as any).handleClientMessage(
        {
          type: "read_file",
          projectPath,
          filePath: "README.md",
        },
        ws,
      );

      await expect.poll(() => ws.send.mock.calls.length).toBeGreaterThan(0);

      const sends = ws.send.mock.calls.map((c: unknown[]) =>
        JSON.parse(c[0] as string),
      );
      expect(sends).toContainEqual({
        type: "file_content",
        filePath: "README.md",
        kind: "text",
        content: "# Hello\n\nWorld\n",
        language: "markdown",
        totalLines: 4,
        truncated: false,
      });
    } finally {
      bridge.close();
      rmSync(projectPath, { recursive: true, force: true });
    }
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

      await expect.poll(() => ws.send.mock.calls.length).toBeGreaterThan(0);

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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

    await (bridge as any).handleClientMessage(
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

  it("preserves codex auto-review when enabling plan mode in-place", async () => {
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
        codexPermissionsMode: "autoReview",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    expect(session).toBeDefined();
    session.status = "idle";
    session.process.setApprovalPolicy("on-request");
    session.process.setApprovalsReviewer("auto_review");
    ws.send.mockClear();

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "plan",
        executionMode: "default",
        planMode: true,
      },
      ws,
    );

    const updatedSession = (bridge as any).sessionManager.get(sessionId);
    expect(updatedSession).toBeDefined();
    expect(updatedSession.id).toBe(sessionId);
    expect(updatedSession.codexSettings).toMatchObject({
      approvalPolicy: "on-request",
      approvalsReviewer: "auto_review",
      codexPermissionsMode: "autoReview",
    });
    expect(updatedSession.process.collaborationMode).toBe("plan");

    const messages = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const modeChanged = messages.find(
      (m: any) => m.type === "system" && m.subtype === "set_permission_mode",
    );
    expect(modeChanged).toMatchObject({
      approvalPolicy: "on-request",
      approvalsReviewer: "auto_review",
      codexPermissionsMode: "autoReview",
      planMode: true,
    });

    bridge.close();
  });

  it("updates codex model in-place and broadcasts session settings", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    (bridge as any).wss.clients.add(ws);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex-model",
        provider: "codex",
        model: "gpt-5.5",
        modelReasoningEffort: "high",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    const session = (bridge as any).sessionManager.get(sessionId);
    expect(session).toBeDefined();
    ws.send.mockClear();

    (bridge as any).handleClientMessage(
      {
        type: "set_codex_model",
        sessionId,
        model: "gpt-5.4-mini",
        modelReasoningEffort: "low",
      },
      ws,
    );

    expect(session.process.setModel).toHaveBeenCalledWith(
      "gpt-5.4-mini",
      "low",
    );
    expect(session.codexSettings).toMatchObject({
      model: "gpt-5.4-mini",
      modelReasoningEffort: "low",
    });

    const messages = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(
      messages.find(
        (m: any) => m.type === "system" && m.subtype === "set_codex_model",
      ),
    ).toMatchObject({
      sessionId,
      provider: "codex",
      model: "gpt-5.4-mini",
      modelReasoningEffort: "low",
    });
    expect(
      messages.find((m: any) => m.type === "session_list"),
    ).toMatchObject({
      sessions: expect.arrayContaining([
        expect.objectContaining({
          id: sessionId,
          codexSettings: expect.objectContaining({
            model: "gpt-5.4-mini",
            modelReasoningEffort: "low",
          }),
        }),
      ]),
    });

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

  it("starts codex custom permissions without bridge approval or sandbox overrides", async () => {
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
        codexPermissionsMode: "custom",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(created).toMatchObject({
      provider: "codex",
      codexPermissionsMode: "custom",
    });
    const session = (bridge as any).sessionManager.get(created.sessionId);
    expect(session.codexOptions.codexPermissionsMode).toBe("custom");
    expect(session.codexOptions.approvalPolicy).toBeUndefined();
    expect(session.codexOptions.approvalsReviewer).toBeUndefined();
    expect(session.codexOptions.sandboxMode).toBeUndefined();

    bridge.close();
  });

  it("switches codex to custom permissions by recreating without stale reviewer", async () => {
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
        codexPermissionsMode: "autoReview",
      },
      ws,
    );
    await Promise.resolve();

    const sends = ws.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    const created = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    const oldSessionId = created.sessionId as string;
    const oldSession = (bridge as any).sessionManager.get(oldSessionId);
    expect(oldSession.codexOptions.approvalsReviewer).toBe("auto_review");

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId: oldSessionId,
        mode: "default",
        codexPermissionsMode: "custom",
      },
      ws,
    );

    expect((bridge as any).sessionManager.get(oldSessionId)).toBeUndefined();
    const sessions = (bridge as any).sessionManager.list();
    expect(sessions).toHaveLength(1);
    const newSessionSummary = sessions[0];
    expect(newSessionSummary.id).not.toBe(oldSessionId);
    const newSession = (bridge as any).sessionManager.get(newSessionSummary.id);
    expect(newSession.codexOptions.codexPermissionsMode).toBe("custom");
    expect(newSession.codexOptions.approvalPolicy).toBeUndefined();
    expect(newSession.codexOptions.approvalsReviewer).toBeUndefined();
    expect(newSession.codexOptions.sandboxMode).toBeUndefined();

    const createdAfterSwitch = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(createdAfterSwitch).toMatchObject({
      provider: "codex",
      codexPermissionsMode: "custom",
      sourceSessionId: oldSessionId,
    });
    expect(createdAfterSwitch.approvalsReviewer).toBeUndefined();
    expect(createdAfterSwitch.approvalPolicy).toBeUndefined();
    expect(createdAfterSwitch.sandboxMode).toBeUndefined();

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
    (bridge as any).sessionManager.appendHistory(session.id, {
      type: "status",
      status: "running",
    });

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

  it("claude busy snapshot uses session.status, not isWaitingForInput", async () => {
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

    // The SDK is mid-turn (status running) but already holds a resolver for the
    // next input (isWaitingForInput true). The old logic read this as idle and
    // skipped the interrupt. sendInput returns a non-boolean here so the ack
    // must fall back to isAgentBusySnapshot, which now derives from status.
    session.status = "running";
    session.process.isWaitingForInput = true;
    session.process.sendInput.mockReturnValue(undefined);

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "interrupt while running",
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
    expect(session.process.sendInput).toHaveBeenCalledWith(
      "interrupt while running",
    );
    expect(session.process.interrupt).toHaveBeenCalledTimes(1);

    bridge.close();
  });

  it("echoes clientMessageId and acceptedSeq on input_ack", async () => {
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
        type: "input",
        sessionId,
        text: "strict input",
        clientMessageId: "cm-1",
        baseSeq: 0,
      },
      ws,
    );

    const inputAck = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "input_ack");
    expect(inputAck).toMatchObject({
      type: "input_ack",
      sessionId,
      clientMessageId: "cm-1",
      acceptedSeq: expect.any(Number),
      queued: false,
    });
    expect(inputAck.acceptedSeq).toBeGreaterThan(0);

    bridge.close();
  });

  it("broadcasts accepted claude user input to other connected clients", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    const otherWs = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    (bridge as any).wss.clients.add(ws);
    (bridge as any).wss.clients.add(otherWs);

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
    otherWs.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "hello from phone",
        clientMessageId: "cm-phone-1",
      },
      ws,
    );

    const peerMessages = otherWs.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(peerMessages.find((m: any) => m.type === "user_input")).toMatchObject({
      type: "user_input",
      sessionId,
      text: "hello from phone",
      clientMessageId: "cm-phone-1",
      historySeq: expect.any(Number),
    });
    expect(
      ws.send.mock.calls
        .map((c: unknown[]) => JSON.parse(c[0] as string))
        .some((m: any) => m.type === "user_input"),
    ).toBe(false);

    bridge.close();
  });

  it("rejects strict input when another user input exists after baseSeq", async () => {
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
    const baseSeq = (bridge as any).sessionManager.get(sessionId).historyRevision;
    (bridge as any).sessionManager.appendHistory(sessionId, {
      type: "user_input",
      text: "from another client",
    });

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "offline input",
        clientMessageId: "cm-conflict",
        baseSeq,
      },
      ws,
    );

    const rejected = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "input_rejected");
    expect(rejected).toMatchObject({
      type: "input_rejected",
      sessionId,
      clientMessageId: "cm-conflict",
      reason: "conflict",
    });

    bridge.close();
  });

  it("rejects codex strict input older than canonical baseline", async () => {
    codexThreadToSessionHistoryMock.mockReturnValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "canonical turn" }],
      },
    ]);

    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    await (bridge as any).handleClientMessage(
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
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thr_codex_base_seq";
    session.process.readThread.mockResolvedValue({
      id: "thr_codex_base_seq",
      turns: [],
    });

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "get_history_delta",
        sessionId,
        sinceSeq: 0,
      },
      ws,
    );
    expect(session.codexCanonicalHistoryRevision).toBe(1);

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "offline input",
        clientMessageId: "cm-codex-conflict",
        baseSeq: 0,
      },
      ws,
    );

    const rejected = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "input_rejected");
    expect(rejected).toMatchObject({
      type: "input_rejected",
      sessionId,
      clientMessageId: "cm-codex-conflict",
      reason: "conflict",
    });
    expect(
      ws.send.mock.calls
        .map((c: unknown[]) => JSON.parse(c[0] as string))
        .some((m: any) => m.type === "user_input"),
    ).toBe(false);

    bridge.close();
  });

  it("codex busy input is queued and included in session_list", async () => {
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

    let sent = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sent.find((m: any) => m.type === "input_ack")).toMatchObject({
      type: "input_ack",
      sessionId,
      queued: true,
    });
    expect(session.codexQueuedInput).toMatchObject({ text: "while busy" });
    expect(session.process.sendInput).not.toHaveBeenCalled();
    (bridge as any).sendSessionList(ws);
    sent = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const sessionList = sent.find((m: any) => m.type === "session_list");
    expect(sessionList.sessions[0].queuedInput).toMatchObject({
      text: "while busy",
    });

    bridge.close();
  });

  it("adds synthetic UUIDs to live codex user input", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "first codex turn",
        clientMessageId: "cm-codex-1",
      },
      ws,
    );

    const session = (bridge as any).sessionManager.get(sessionId);
    const userInput = session.history.find((message: any) => message.type === "user_input");
    expect(userInput).toMatchObject({
      type: "user_input",
      text: "first codex turn",
      userMessageUuid: "codex:user-turn:1",
    });
    const echoedUserInput = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find(
        (m: any) =>
          m.type === "user_input" && m.clientMessageId === "cm-codex-1",
      );
    expect(echoedUserInput).toMatchObject({
      type: "user_input",
      sessionId,
      text: "first codex turn",
      userMessageUuid: "codex:user-turn:1",
      clientMessageId: "cm-codex-1",
    });

    bridge.close();
  });

  it("broadcasts accepted codex user input with UUID to other connected clients", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    const otherWs = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    (bridge as any).wss.clients.add(ws);
    (bridge as any).wss.clients.add(otherWs);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;

    ws.send.mockClear();
    otherWs.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "codex from mac",
        clientMessageId: "cm-mac-1",
      },
      ws,
    );

    const peerMessages = otherWs.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(peerMessages.find((m: any) => m.type === "user_input")).toMatchObject({
      type: "user_input",
      sessionId,
      text: "codex from mac",
      clientMessageId: "cm-mac-1",
      userMessageUuid: "codex:user-turn:1",
      historySeq: expect.any(Number),
    });

    bridge.close();
  });

  it("rolls back codex conversation turns and recreates the bridge session", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    getCodexSessionHistoryMock.mockResolvedValue([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "first codex turn" }],
      },
    ]);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.claudeSessionId = "thread-rollback";
    session.process.sessionId = "thread-rollback";
    session.pastMessages = [
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "first codex turn" }],
      },
      {
        role: "assistant",
        content: [{ type: "text", text: "first answer" }],
      },
      {
        role: "user",
        uuid: "codex:user-turn:2",
        content: [{ type: "text", text: "second codex turn" }],
      },
    ];
    const rollbackThread = session.process.rollbackThread;

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "rewind",
        sessionId,
        targetUuid: "codex:user-turn:1",
        mode: "conversation",
      },
      ws,
    );
    await Promise.resolve();

    expect(rollbackThread).toHaveBeenCalledWith(2);
    expect(getCodexSessionHistoryMock).not.toHaveBeenCalled();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    expect(sends.find((m: any) => m.type === "rewind_result")).toMatchObject({
      success: true,
      mode: "conversation",
    });
    const newCreated = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(newCreated).toMatchObject({
      provider: "codex",
      projectPath: resolve("/tmp/project-codex"),
      sourceSessionId: sessionId,
    });
    const newSession = (bridge as any).sessionManager.get(newCreated.sessionId);
    expect(newSession.codexOptions).toMatchObject({ threadId: "thread-rollback" });
    expect(newSession.pastMessages).toEqual([]);

    bridge.close();
  });

  it("forks codex conversation at a target turn and rolls back only the fork", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.process.sessionId = "thread-source";
    session.process.forkThread.mockResolvedValueOnce({
      threadId: "thread-forked",
      thread: { id: "thread-forked", turns: [] },
    });
    session.history = [
      {
        type: "user_input",
        text: "first codex turn",
        userMessageUuid: "codex:user-turn:1",
      },
      {
        type: "assistant",
        message: {
          id: "a1",
          role: "assistant",
          content: [{ type: "text", text: "first answer" }],
          model: "",
        },
      },
      {
        type: "user_input",
        text: "second codex turn",
        userMessageUuid: "codex:user-turn:2",
      },
      {
        type: "assistant",
        message: { id: "a2", role: "assistant", content: [], model: "" },
      },
    ];

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "fork",
        sessionId,
        targetUuid: "codex:user-turn:1",
      },
      ws,
    );
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(session.process.forkThread).toHaveBeenCalledTimes(1);
    expect(session.process.rollbackThreadById).toHaveBeenCalledWith(
      "thread-forked",
      1,
    );
    expect(getCodexSessionHistoryMock).not.toHaveBeenCalled();

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const newCreated = sends.find(
      (m: any) => m.type === "system" && m.subtype === "session_created",
    );
    expect(newCreated).toMatchObject({
      provider: "codex",
      projectPath: resolve("/tmp/project-codex"),
      sourceSessionId: sessionId,
    });
    const oldSession = (bridge as any).sessionManager.get(sessionId);
    expect(oldSession).toBeDefined();
    const newSession = (bridge as any).sessionManager.get(newCreated.sessionId);
    expect(newSession.codexOptions).toMatchObject({ threadId: "thread-forked" });
    expect(newSession.pastMessages).toMatchObject([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "first codex turn" }],
      },
      {
        role: "assistant",
        uuid: undefined,
        content: [{ type: "text", text: "first answer" }],
      },
    ]);

    bridge.close();
  });

  it("rejects codex code rewind modes", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    ws.send.mockClear();

    await (bridge as any).handleClientMessage(
      {
        type: "rewind",
        sessionId: created.sessionId,
        targetUuid: "codex:user-turn:1",
        mode: "code",
      },
      ws,
    );

    const result = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "rewind_result");
    expect(result).toMatchObject({
      success: false,
      mode: "code",
      error: "Codex only supports conversation rewind",
    });

    bridge.close();
  });

  it("codex busy input is rejected when the queue is full", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.process.isWaitingForInput = false;
    session.codexQueuedInput = {
      itemId: "queued-1",
      text: "already queued",
      createdAt: new Date().toISOString(),
    };

    ws.send.mockClear();
    (bridge as any).handleClientMessage(
      {
        type: "input",
        sessionId,
        text: "second",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toMatchObject({
      type: "input_rejected",
      sessionId,
      reason: "Queue is full",
    });
    expect(session.process.sendInput).not.toHaveBeenCalled();

    bridge.close();
  });

  it("updates and cancels codex queued input", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.codexQueuedInput = {
      itemId: "queued-1",
      text: "original",
      createdAt: new Date().toISOString(),
    };

    (bridge as any).handleClientMessage(
      {
        type: "update_queued_input",
        sessionId,
        itemId: "queued-1",
        text: "edited",
      },
      ws,
    );
    expect(session.codexQueuedInput.text).toBe("edited");

    (bridge as any).handleClientMessage(
      {
        type: "cancel_queued_input",
        sessionId,
        itemId: "queued-1",
      },
      ws,
    );
    expect(session.codexQueuedInput).toBeUndefined();

    bridge.close();
  });

  it("steers codex queued input and clears the queue", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    const otherWs = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;
    (bridge as any).wss.clients.add(ws);
    (bridge as any).wss.clients.add(otherWs);

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-codex",
        provider: "codex",
      },
      ws,
    );
    await Promise.resolve();

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.codexQueuedInput = {
      itemId: "queued-1",
      text: "steer now",
      createdAt: new Date().toISOString(),
      userMessageUuid: "codex:user-turn:1",
      skills: [{ name: "skill", path: "/skills/skill" }],
    };
    ws.send.mockClear();
    otherWs.send.mockClear();

    await (bridge as any).handleClientMessage(
      {
        type: "steer_queued_input",
        sessionId,
        itemId: "queued-1",
      },
      ws,
    );

    expect(session.process.steerInputStructured).toHaveBeenCalledWith(
      "steer now",
      {
        images: undefined,
        skills: [{ name: "skill", path: "/skills/skill" }],
        mentions: undefined,
      },
    );
    expect(session.codexQueuedInput).toBeUndefined();
    const peerMessages = otherWs.send.mock.calls.map((c: unknown[]) =>
      JSON.parse(c[0] as string),
    );
    expect(peerMessages.find((m: any) => m.type === "user_input")).toMatchObject({
      type: "user_input",
      sessionId,
      text: "steer now",
      userMessageUuid: "codex:user-turn:1",
      historySeq: expect.any(Number),
    });

    bridge.close();
  });

  it("keeps codex queued input when steer fails", async () => {
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

    const created = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "system" && m.subtype === "session_created");
    const sessionId = created.sessionId as string;
    const session = (bridge as any).sessionManager.get(sessionId);
    session.codexQueuedInput = {
      itemId: "queued-1",
      text: "steer now",
      createdAt: new Date().toISOString(),
    };
    session.process.steerInputStructured.mockRejectedValueOnce(
      new Error("No active Codex turn to steer"),
    );

    ws.send.mockClear();
    await (bridge as any).handleClientMessage(
      {
        type: "steer_queued_input",
        sessionId,
        itemId: "queued-1",
      },
      ws,
    );

    expect(session.codexQueuedInput?.text).toBe("steer now");
    const error = ws.send.mock.calls
      .map((c: unknown[]) => JSON.parse(c[0] as string))
      .find((m: any) => m.type === "error");
    expect(error).toMatchObject({
      type: "error",
      errorCode: "queued_input_steer_failed",
    });

    bridge.close();
  });

  it("rejects steer_queued_input for claude sessions", async () => {
    const bridge = new BridgeWebSocketServer({ server: httpServer });
    const ws = {
      readyState: OPEN_STATE,
      send: vi.fn(),
    } as any;

    (bridge as any).handleClientMessage(
      {
        type: "start",
        projectPath: "/tmp/project-claude",
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
    await (bridge as any).handleClientMessage(
      {
        type: "steer_queued_input",
        sessionId,
        itemId: "queued-1",
      },
      ws,
    );

    const error = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(error).toMatchObject({
      type: "error",
      message: "No active Codex session.",
    });

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
    getCodexSessionIndexMetadataMock.mockResolvedValue(
      new Map([
        [
          "thr_codex_1",
          {
            codexSettings: {
              approvalPolicy: "never",
              sandboxMode: "danger-full-access",
              model: "gpt-5.3-codex",
            },
            resumeCwd: "/tmp/project-codex-worktree",
            firstPrompt: "Investigate crash in the parser",
            lastPrompt: "add a regression test",
            summary: "Fixed the off-by-one in the tokenizer",
          },
        ],
      ]),
    );

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
      sourceKinds: ["cli", "vscode", "appServer"],
    });
    expect(getCodexSessionIndexMetadataMock).toHaveBeenCalledWith([
      "thr_codex_1",
    ]);
    expect(getAllRecentSessionsMock).not.toHaveBeenCalled();
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
      // Rollout-parsed texts win over the thread/list preview blob.
      firstPrompt: "Investigate crash in the parser",
      lastPrompt: "add a regression test",
      summary: "Fixed the off-by-one in the tokenizer",
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
    expect(getCodexSessionIndexMetadataMock).toHaveBeenCalledWith([
      "thr_codex_2",
    ]);
    expect(getAllRecentSessionsMock).not.toHaveBeenCalled();
    expect(payload.sessions[0]).toMatchObject({
      provider: "codex",
      sessionId: "thr_codex_2",
      name: "Test failures",
      gitBranch: "fix/tests",
      projectPath: "/tmp/project-codex",
    });

    bridge.close();
  });

  it("merges codex thread/list into all-provider recent sessions without dropping scan-only codex sessions", async () => {
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
          id: "thr_codex_all",
          preview: "Codex canonical result",
          createdAt: 1771492643,
          updatedAt: 1771496243,
          cwd: "/tmp/project-codex",
          agentNickname: null,
          agentRole: null,
          gitBranch: "main",
          name: "Codex thread",
        },
      ],
      nextCursor: null,
    });
    getAllRecentSessionsMock.mockClear();
    getAllRecentSessionsMock.mockResolvedValue({
      sessions: [
        {
          sessionId: "scan_codex_only",
          provider: "codex",
          firstPrompt: "Codex scan-only result",
          created: "2026-03-01T00:00:00.000Z",
          modified: "2026-03-01T00:00:00.000Z",
          gitBranch: "main",
          projectPath: "/tmp/project-codex",
          isSidechain: false,
        },
        {
          sessionId: "thr_codex_all",
          provider: "codex",
          firstPrompt: "Stale scan duplicate",
          created: "2026-01-01T00:00:00.000Z",
          modified: "2026-01-01T00:00:00.000Z",
          gitBranch: "main",
          projectPath: "/tmp/project-codex",
          isSidechain: false,
        },
        {
          sessionId: "claude_recent",
          provider: "claude",
          firstPrompt: "Claude result",
          created: "2026-01-01T00:00:00.000Z",
          modified: "2026-01-01T00:00:00.000Z",
          gitBranch: "main",
          projectPath: "/tmp/project-claude",
          isSidechain: false,
        },
      ],
      hasMore: false,
    });
    getCodexSessionIndexMetadataMock.mockResolvedValue(new Map());

    const payload = await (bridge as any).listRecentSessions({
      type: "list_recent_sessions",
      limit: 20,
    });

    expect(getAllRecentSessionsMock).toHaveBeenCalledTimes(1);
    const scanOptions = getAllRecentSessionsMock.mock.calls[0][0];
    expect(scanOptions).toMatchObject({
      limit: 20,
      offset: 0,
    });
    expect(scanOptions).not.toHaveProperty("provider");
    expect(session.process.listThreads).toHaveBeenCalledWith({
      limit: 20,
      cwd: undefined,
      searchTerm: undefined,
      sourceKinds: ["cli", "vscode", "appServer"],
    });
    expect(payload.hasMore).toBe(false);
    expect(payload.sessions.map((s: any) => s.sessionId)).toEqual([
      "scan_codex_only",
      "thr_codex_all",
      "claude_recent",
    ]);
    expect(payload.sessions[1]).toMatchObject({
      sessionId: "thr_codex_all",
      provider: "codex",
      name: "Codex thread",
      firstPrompt: "Codex canonical result",
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
