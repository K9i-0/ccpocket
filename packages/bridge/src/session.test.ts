import { EventEmitter } from "node:events";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ProcessStatus, ServerMessage } from "./parser.js";

const { codexInstances, sdkInstances } = vi.hoisted(() => ({
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
  }>,
}));

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

import { SessionManager } from "./session.js";

describe("SessionManager codex path", () => {
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
    expect(afterExit?.history.at(-1)).toEqual({ type: "status", status: "idle" });
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
    proc.emit("message", { type: "stream_delta", text: "partial" } satisfies ServerMessage);
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
    expect(summary?.messageCount).toBe(3);
  });
});
