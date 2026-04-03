import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock node-pty before importing PtyProcess
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

describe("PtyProcess", () => {
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

  it("spawns claude via node-pty on start", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "claude",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "claude",
      expect.arrayContaining(["--verbose"]),
      expect.objectContaining({ cwd: "/tmp/test" }),
    );
  });

  it("spawns codex for codex provider", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "codex",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "codex",
      expect.any(Array),
      expect.objectContaining({ cwd: "/tmp/test" }),
    );
  });

  it("emits pty_data on PTY output", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const ptyData: string[] = [];
    proc.on("pty_data", (data: string) => ptyData.push(data));

    dataHandler("hello world\r\n");
    expect(ptyData).toEqual(["hello world\r\n"]);
  });

  it("emits structured messages via ANSI parser", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    dataHandler("⏺ Hello from Claude\r\n");

    const deltas = messages.filter((m: any) => m.type === "stream_delta");
    expect(deltas.length).toBeGreaterThan(0);
  });

  it("writes raw data to PTY on write()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.write("hello");
    expect(mockPty.write).toHaveBeenCalledWith("hello");
  });

  it("writes text + newline on sendInput()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendInput("tell me about cats");
    expect(mockPty.write).toHaveBeenCalledWith("tell me about cats\n");
  });

  it("writes y + newline on sendApproval()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendApproval("tool-123");
    expect(mockPty.write).toHaveBeenCalledWith("y\n");
  });

  it("writes n + newline on sendRejection()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.sendRejection("tool-123");
    expect(mockPty.write).toHaveBeenCalledWith("n\n");
  });

  it("emits exit on PTY exit", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });

    const exits: unknown[] = [];
    proc.on("exit", (code) => exits.push(code));

    exitHandler({ exitCode: 0 });
    expect(exits).toEqual([0]);
  });

  it("kills PTY on stop()", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.stop();
    expect(mockPty.kill).toHaveBeenCalled();
  });

  it("isPty returns true", () => {
    expect(proc.isPty).toBe(true);
  });

  it("resizes PTY", () => {
    proc.start({ projectPath: "/tmp/test", provider: "claude" });
    proc.resize(120, 40);
    expect(mockPty.resize).toHaveBeenCalledWith(120, 40);
  });

  it("includes --resume flag when sessionId provided", async () => {
    const pty = await import("node-pty");
    proc.start({
      projectPath: "/tmp/test",
      provider: "claude",
      sessionId: "abc-123",
    });

    expect(pty.spawn).toHaveBeenCalledWith(
      "claude",
      expect.arrayContaining(["--resume", "abc-123"]),
      expect.any(Object),
    );
  });
});
