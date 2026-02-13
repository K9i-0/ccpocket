import { createServer } from "node:http";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { getSessionHistoryMock, getCodexSessionHistoryMock, getAllRecentSessionsMock } = vi.hoisted(() => ({
  getSessionHistoryMock: vi.fn(),
  getCodexSessionHistoryMock: vi.fn(),
  getAllRecentSessionsMock: vi.fn(),
}));

vi.mock("./sessions-index.js", () => ({
  getSessionHistory: getSessionHistoryMock,
  getCodexSessionHistory: getCodexSessionHistoryMock,
  getAllRecentSessions: getAllRecentSessionsMock,
}));

vi.mock("./session.js", () => ({
  SessionManager: class MockSessionManager {
    private sessions = new Map<string, any>();
    private seq = 0;

    constructor() {}

    create(
      projectPath: string,
      options?: { sessionId?: string },
      pastMessages?: unknown[],
      _worktreeOptions?: unknown,
      provider: "claude" | "codex" = "claude",
    ): string {
      const id = `s-${++this.seq}`;
      const process = {
        setPermissionMode: vi.fn(async () => {}),
        sendInput: vi.fn(),
        sendInputWithImage: vi.fn(),
        approve: vi.fn(),
        approveAlways: vi.fn(),
        reject: vi.fn(),
        answer: vi.fn(),
        interrupt: vi.fn(),
      };
      this.sessions.set(id, {
        id,
        projectPath,
        claudeSessionId: options?.sessionId,
        pastMessages,
        history: [],
        status: "idle",
        provider,
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
        messageCount: (s.pastMessages?.length ?? 0) + s.history.length,
      }));
    }

    getCachedCommands() {
      return undefined;
    }

    destroyAll() {}
  },
}));

import { BridgeWebSocketServer } from "./websocket.js";

describe("BridgeWebSocketServer resume/get_history flow", () => {
  const OPEN_STATE = 1;
  let httpServer: ReturnType<typeof createServer>;

  beforeEach(() => {
    httpServer = createServer();
    getSessionHistoryMock.mockReset();
    getCodexSessionHistoryMock.mockReset();
    getAllRecentSessionsMock.mockReset();
    getAllRecentSessionsMock.mockResolvedValue({ sessions: [], hasMore: false });
  });

  afterEach(() => {
    httpServer.close();
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

  it("sends provider=codex on codex resume_session", async () => {
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

  it("returns error when set_permission_mode is sent to codex session", () => {
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

    const sends = ws.send.mock.calls.map((c: unknown[]) => JSON.parse(c[0] as string));
    const created = sends.find((m: any) => m.type === "system" && m.subtype === "session_created");
    expect(created).toBeDefined();
    const sessionId = created.sessionId as string;

    (bridge as any).handleClientMessage(
      {
        type: "set_permission_mode",
        sessionId,
        mode: "plan",
      },
      ws,
    );

    const last = JSON.parse(ws.send.mock.calls.at(-1)?.[0] as string);
    expect(last).toEqual({
      type: "error",
      message: "Codex sessions do not support runtime permission mode changes",
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
});
