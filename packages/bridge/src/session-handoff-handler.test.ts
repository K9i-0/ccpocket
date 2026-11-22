import { beforeEach, describe, expect, it, vi } from "vitest";

const {
  handleStartMock,
  stopSessionAndNotifyMock,
  transcriptMock,
  writeTranscriptMock,
  waitRunningMock,
  waitIdleMock,
  workspaceMock,
} = vi.hoisted(() => ({
  handleStartMock: vi.fn(),
  stopSessionAndNotifyMock: vi.fn(),
  transcriptMock: vi.fn(),
  writeTranscriptMock: vi.fn(),
  waitRunningMock: vi.fn(),
  waitIdleMock: vi.fn(),
  workspaceMock: vi.fn(),
}));

vi.mock("./websocket/handlers/session-start.js", () => ({
  handleStart: handleStartMock,
}));
vi.mock("./websocket/handlers/session-catalog.js", () => ({
  stopSessionAndNotify: stopSessionAndNotifyMock,
}));
vi.mock("./websocket/session-history.js", () => ({
  sessionTranscriptMessages: transcriptMock,
}));
vi.mock("./websocket/rewind-fork.js", () => ({
  waitForSessionRunning: waitRunningMock,
  waitForSessionIdle: waitIdleMock,
}));
vi.mock("./websocket/workspaces.js", () => ({
  workspaceForRuntimeSession: workspaceMock,
}));
vi.mock("./sessions-index.js", () => ({
  renameClaudeSession: vi.fn().mockResolvedValue(true),
}));
vi.mock("./codex-process.js", () => ({
  CodexProcess: class CodexProcess {},
}));
vi.mock("./session-handoff.js", async () => {
  const actual = await vi.importActual<typeof import("./session-handoff.js")>(
    "./session-handoff.js",
  );
  return { ...actual, writeHandoffTranscript: writeTranscriptMock };
});

import { handleHandoffSession } from "./websocket/handlers/session-handoff.js";

const NOTE = "Goal: ship the login form. Done: markup. Remaining: validation and tests.";

function setup(overrides: Record<string, unknown> = {}) {
  const session: any = {
    id: "s-1",
    provider: "claude",
    projectPath: "/tmp/project",
    status: "idle",
    historyEntries: [] as Array<{ seq: number; message: any }>,
    process: { status: "idle", isRunning: true, interrupt: vi.fn() },
    ...overrides,
  };
  const sessions = new Map<string, any>([[session.id, session]]);
  const sent: any[] = [];
  /** What the source agent does when it receives the note request. */
  let reply: (seq: number) => void = (seq) => {
    session.historyEntries.push({
      seq: seq + 1,
      message: {
        type: "assistant",
        message: { content: [{ type: "text", text: NOTE }] },
      },
    });
    session.historyEntries.push({
      seq: seq + 2,
      message: { type: "result", subtype: "success" },
    });
  };
  const server: any = {
    sessionManager: {
      get: (id: string) => sessions.get(id),
      list: () => [{ id: session.id, executionMode: "acceptEdits" }],
      isUsageLimited: vi.fn(() => false),
    },
    send: (_ws: unknown, msg: unknown) => sent.push(msg),
    handleClientMessage: vi.fn(async (msg: any) => {
      const seq = session.historyEntries.length + 1;
      session.historyEntries.push({
        seq,
        message: {
          type: "user_input",
          text: msg.text,
          clientMessageId: msg.clientMessageId,
        },
      });
      reply(seq);
    }),
    antigravityStore: { setName: vi.fn() },
  };
  return {
    session,
    sessions,
    server,
    sent,
    ws: {} as any,
    setReply: (fn: (seq: number) => void) => {
      reply = fn;
    },
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  handleStartMock.mockResolvedValue("s-2");
  transcriptMock.mockResolvedValue([
    { role: "user", content: [{ type: "text", text: "Add a login form" }] },
    { role: "assistant", content: [{ type: "text", text: "Markup done." }] },
  ]);
  writeTranscriptMock.mockResolvedValue("/tmp/handoffs/t.md");
  waitRunningMock.mockResolvedValue(true);
  waitIdleMock.mockResolvedValue(true);
  workspaceMock.mockReturnValue(undefined);
});

describe("handleHandoffSession", () => {
  it("asks for a note, starts the target with it and stops the source", async () => {
    const { server, ws, sent } = setup();

    await handleHandoffSession(
      server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ws,
    );

    const noteRequest = server.handleClientMessage.mock.calls[0];
    expect(noteRequest[0]).toMatchObject({ type: "input", sessionId: "s-1" });
    expect(noteRequest[0].text).toContain("handed over to Codex");
    // Echoed, because the app did not add the bubble itself.
    expect(noteRequest[2]).toBe(true);

    expect(handleStartMock).toHaveBeenCalledOnce();
    const [, start, , internal] = handleStartMock.mock.calls[0];
    expect(start).toMatchObject({
      type: "start",
      projectPath: "/tmp/project",
      provider: "codex",
      executionMode: "acceptEdits",
    });
    expect(start.initialPrompt).toContain("[ccpocket handoff: Claude Code → Codex]");
    expect(start.initialPrompt).toContain(NOTE);
    expect(start.initialPrompt).toContain("Add a login form");
    expect(start.initialPrompt).toContain("/tmp/handoffs/t.md");
    // The note request and its reply are not part of the quoted conversation.
    expect(start.initialPrompt).not.toContain("Write a handoff note");
    expect(internal).toEqual({
      handoffSourceSessionId: "s-1",
      rawInitialPrompt: true,
    });
    expect(stopSessionAndNotifyMock).toHaveBeenCalledWith(server, "s-1");
    expect(sent).toEqual([]);
  });

  it("passes the instruction, worktree, workspace and name on", async () => {
    const { server, ws } = setup({
      provider: "codex",
      name: "Login form",
      worktreePath: "/tmp/project-worktrees/login",
      worktreeBranch: "login",
    });
    workspaceMock.mockReturnValue({
      kind: "adhoc",
      rootPaths: ["/tmp/project", "/tmp/shared"],
    });

    await handleHandoffSession(
      server,
      {
        type: "handoff_session",
        sessionId: "s-1",
        targetProvider: "antigravity",
        instruction: "Only write the tests.",
      },
      ws,
    );

    const [, start, , internal] = handleStartMock.mock.calls[0];
    expect(start).toMatchObject({
      provider: "antigravity",
      existingWorktreePath: "/tmp/project-worktrees/login",
      worktreeBranch: "login",
      additionalWritableRoots: ["/tmp/shared"],
      autoRename: false,
    });
    expect(start.initialPrompt).toContain("Only write the tests.");
    expect(internal).toMatchObject({ name: "Login form" });
  });

  it("starts in the project of a project workspace", async () => {
    const { server, ws } = setup();
    workspaceMock.mockReturnValue({
      kind: "project",
      projectId: "p-1",
      rootPaths: ["/tmp/project", "/tmp/shared"],
    });

    await handleHandoffSession(
      server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ws,
    );

    const [, start] = handleStartMock.mock.calls[0];
    expect(start.projectId).toBe("p-1");
    expect(start.additionalWritableRoots).toBeUndefined();
  });

  it("interrupts a running turn before asking for the note", async () => {
    const { server, ws, session } = setup({ status: "running" });
    session.process.interrupt = vi.fn(() => {
      session.status = "idle";
    });

    await handleHandoffSession(
      server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ws,
    );

    expect(session.process.interrupt).toHaveBeenCalledOnce();
    expect(server.handleClientMessage).toHaveBeenCalledOnce();
    expect(handleStartMock).toHaveBeenCalledOnce();
  });

  it.each([
    ["the usage limit is reached", (ctx: ReturnType<typeof setup>) => {
      ctx.server.sessionManager.isUsageLimited.mockReturnValue(true);
    }],
    ["the agent process is gone", (ctx: ReturnType<typeof setup>) => {
      ctx.session.process.isRunning = false;
    }],
    ["input is already queued", (ctx: ReturnType<typeof setup>) => {
      ctx.session.queuedInput = { text: "later" };
    }],
  ])("hands off without asking when %s", async (_name, arrange) => {
    const ctx = setup();
    arrange(ctx);

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    expect(ctx.server.handleClientMessage).not.toHaveBeenCalled();
    const [, start] = handleStartMock.mock.calls[0];
    expect(start.initialPrompt).not.toContain("## Handoff note");
    expect(start.initialPrompt).toContain("Add a login form");
    expect(stopSessionAndNotifyMock).toHaveBeenCalledOnce();
  });

  it.each([
    ["the note turn fails", (seq: number, session: any) => {
      session.historyEntries.push({
        seq: seq + 1,
        message: { type: "result", subtype: "error", error: "overloaded" },
      });
    }],
    ["the reply is empty", (seq: number, session: any) => {
      session.historyEntries.push({
        seq: seq + 1,
        message: { type: "assistant", message: { content: [{ type: "text", text: "ok" }] } },
      });
    }],
  ])("falls back to the Bridge-built context when %s", async (_name, reply) => {
    const ctx = setup();
    ctx.setReply((seq) => reply(seq, ctx.session));

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    const [, start] = handleStartMock.mock.calls[0];
    expect(start.initialPrompt).not.toContain("## Handoff note");
    expect(stopSessionAndNotifyMock).toHaveBeenCalledOnce();
  });

  it("interrupts and falls back when the note takes too long", async () => {
    const ctx = setup();
    ctx.setReply(() => {});
    waitIdleMock.mockResolvedValueOnce(false).mockResolvedValue(true);

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    expect(ctx.session.process.interrupt).toHaveBeenCalledOnce();
    expect(handleStartMock).toHaveBeenCalledOnce();
    expect(stopSessionAndNotifyMock).toHaveBeenCalledOnce();
  });

  it("keeps the source when the user interrupts the note turn", async () => {
    const ctx = setup();
    ctx.setReply((seq) => {
      ctx.session.historyEntries.push({
        seq: seq + 1,
        message: { type: "result", subtype: "interrupted" },
      });
    });

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    expect(handleStartMock).not.toHaveBeenCalled();
    expect(stopSessionAndNotifyMock).not.toHaveBeenCalled();
    expect(ctx.sent).toEqual([
      expect.objectContaining({ type: "error", errorCode: "handoff_failed" }),
    ]);
  });

  it("keeps the source when the target cannot be started", async () => {
    const ctx = setup();
    handleStartMock.mockResolvedValue(undefined);

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    expect(stopSessionAndNotifyMock).not.toHaveBeenCalled();
  });

  it("still hands off when the transcript cannot be read or saved", async () => {
    const ctx = setup();
    transcriptMock.mockRejectedValue(new Error("rpc failed"));

    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );

    expect(writeTranscriptMock).not.toHaveBeenCalled();
    const [, start] = handleStartMock.mock.calls[0];
    expect(start.initialPrompt).toContain(NOTE);
    expect(start.initialPrompt).not.toContain("## Full transcript");
  });

  it("rejects an unknown session, the same provider and a second request", async () => {
    const ctx = setup();
    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "missing", targetProvider: "codex" },
      ctx.ws,
    );
    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "claude" },
      ctx.ws,
    );
    expect(ctx.sent.map((m) => m.message)).toEqual([
      "Session missing not found",
      "This session already runs in Claude Code",
    ]);

    let release!: () => void;
    transcriptMock.mockReturnValue(
      new Promise((resolve) => {
        release = () => resolve([]);
      }),
    );
    const first = handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );
    await handleHandoffSession(
      ctx.server,
      { type: "handoff_session", sessionId: "s-1", targetProvider: "codex" },
      ctx.ws,
    );
    expect(ctx.sent.at(-1).message).toBe(
      "A handoff of this session is already in progress",
    );
    release();
    await first;
    expect(handleStartMock).toHaveBeenCalledOnce();
  });
});
