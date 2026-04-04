import { describe, it, expect, vi, beforeEach } from "vitest";

const mockPty = {
  onData: vi.fn(),
  onExit: vi.fn(),
  write: vi.fn(),
  resize: vi.fn(),
  kill: vi.fn(),
  pid: 12345,
  cols: 80,
  rows: 24,
  process: "claude",
};

vi.mock("node-pty", () => ({
  spawn: vi.fn(() => mockPty),
}));

import { PtyProcess } from "./pty-process.js";
import * as pty from "node-pty";

describe("PtyProcess (sidecar)", () => {
  let proc: PtyProcess;
  let dataHandler: (data: string) => void;
  let exitHandler: (e: { exitCode: number; signal?: number }) => void;

  beforeEach(() => {
    vi.clearAllMocks();
    mockPty.onData.mockImplementation((cb: (data: string) => void) => {
      dataHandler = cb;
      return { dispose: vi.fn() };
    });
    mockPty.onExit.mockImplementation(
      (cb: (e: { exitCode: number; signal?: number }) => void) => {
        exitHandler = cb;
        return { dispose: vi.fn() };
      },
    );
    proc = new PtyProcess();
  });

  it("requires sessionId to start", () => {
    expect(() =>
      proc.start({ projectPath: "/tmp", provider: "claude" }),
    ).toThrow("Sidecar PTY requires a sessionId");
  });

  it("spawns claude with --resume for claude provider", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "claude",
      sessionId: "abc-123",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      ["/tmp/project", "--verbose", "--resume", "abc-123"],
      expect.objectContaining({ cols: 80, rows: 24 }),
    );
  });

  it("spawns codex with --thread for codex provider", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "codex",
      sessionId: "thread-456",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      ["/tmp/project", "--thread", "thread-456"],
      expect.objectContaining({ cols: 80, rows: 24 }),
    );
  });

  it("uses custom cols/rows when provided", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
      cols: 120,
      rows: 40,
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      expect.any(Array),
      expect.objectContaining({ cols: 120, rows: 40 }),
    );
  });

  it("emits pty_data on data from PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const handler = vi.fn();
    proc.on("pty_data", handler);
    dataHandler("hello world");

    expect(handler).toHaveBeenCalledWith("hello world");
  });

  it("does NOT emit message events (no ANSI parser)", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const handler = vi.fn();
    proc.on("message", handler);
    dataHandler("⏺ some assistant text\r\n");

    expect(handler).not.toHaveBeenCalled();
  });

  it("emits status and exit on process exit", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    const statuses: string[] = [];
    proc.on("status", (s) => statuses.push(s));
    const exitHandler2 = vi.fn();
    proc.on("exit", exitHandler2);

    exitHandler({ exitCode: 0 });

    expect(statuses).toContain("idle");
    expect(exitHandler2).toHaveBeenCalledWith(0);
  });

  it("write() sends raw bytes to PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.write("hello");
    expect(mockPty.write).toHaveBeenCalledWith("hello");
  });

  it("resize() resizes the PTY", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.resize(120, 40);
    expect(mockPty.resize).toHaveBeenCalledWith(120, 40);
  });

  it("stop() sends SIGTERM", () => {
    proc.start({
      projectPath: "/tmp",
      provider: "claude",
      sessionId: "abc",
    });

    proc.stop();
    expect(mockPty.kill).toHaveBeenCalledWith("SIGTERM");
  });

  it("includes --dangerously-skip-permissions for bypassPermissions", () => {
    proc.start({
      projectPath: "/tmp/project",
      provider: "claude",
      sessionId: "abc",
      permissionMode: "bypassPermissions",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      expect.any(String),
      expect.arrayContaining(["--dangerously-skip-permissions"]),
      expect.any(Object),
    );
  });
});
