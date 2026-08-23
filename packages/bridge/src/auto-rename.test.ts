import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { join, resolve } from "node:path";
import type { ServerMessage } from "./parser.js";

const {
  execFileSyncMock,
  mkdtempSyncMock,
  readFileSyncMock,
  rmSyncMock,
} = vi.hoisted(() => ({
  execFileSyncMock: vi.fn(),
  mkdtempSyncMock: vi.fn(),
  readFileSyncMock: vi.fn(),
  rmSyncMock: vi.fn(),
}));

vi.mock("node:child_process", () => ({
  execFileSync: execFileSyncMock,
}));

vi.mock("node:fs", () => ({
  mkdtempSync: mkdtempSyncMock,
  readFileSync: readFileSyncMock,
  rmSync: rmSyncMock,
}));

import {
  buildAutoRenamePrompt,
  buildAutoRenameTranscript,
  generateAutoRenameName,
  sanitizeAutoRenameName,
} from "./auto-rename.js";

const originalAssistModel = process.env.BRIDGE_CODEX_ASSIST_MODEL;
const originalAssistReasoningEffort =
  process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT;

describe("auto rename", () => {
  beforeEach(() => {
    execFileSyncMock.mockReset();
    mkdtempSyncMock.mockReset();
    readFileSyncMock.mockReset();
    rmSyncMock.mockReset();
    mkdtempSyncMock.mockReturnValue("/tmp/ccpocket-auto-rename-1");
    delete process.env.BRIDGE_CODEX_ASSIST_MODEL;
    delete process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT;
  });

  afterEach(() => {
    restoreEnvVar("BRIDGE_CODEX_ASSIST_MODEL", originalAssistModel);
    restoreEnvVar(
      "BRIDGE_CODEX_ASSIST_REASONING_EFFORT",
      originalAssistReasoningEffort,
    );
  });

  it("builds transcript from the first user input only", () => {
    const history = [
      { type: "status", status: "running" },
      {
        type: "tool_result",
        toolUseId: "tool-1",
        content: "secret tool output",
      },
      {
        type: "user_input",
        text: "Fix Android push notifications",
        timestamp: "2026-05-01T00:00:00.000Z",
      },
      {
        type: "assistant",
        message: {
          role: "assistant",
          content: [
            { type: "tool_use", id: "t1", name: "Read", input: {} },
            { type: "text", text: "SSHログインに失敗しました。" },
          ],
        },
      },
      {
        type: "user_input",
        text: "second turn should be ignored",
        timestamp: "2026-05-01T00:01:00.000Z",
      },
    ] as ServerMessage[];

    const transcript = buildAutoRenameTranscript(history);

    expect(transcript).toEqual({
      userText: "Fix Android push notifications",
    });
    const prompt = buildAutoRenamePrompt(transcript!);
    expect(prompt).toContain("Never translate it");
    expect(prompt).toContain("natural, specific noun phrase");
    expect(prompt).toContain("Use only the USER text");
    expect(prompt).not.toContain("SSHログインに失敗しました");
    expect(prompt).not.toContain("secret tool output");
    expect(prompt).not.toContain("tool_use");
    expect(prompt).not.toContain("second turn should be ignored");
  });

  it("returns null when no user input exists", () => {
    expect(
      buildAutoRenameTranscript([
        { type: "status", status: "running" } as ServerMessage,
      ]),
    ).toBeNull();
  });

  it("sanitizes model output", () => {
    expect(sanitizeAutoRenameName('"未プッシュ差分レビュー。"\n')).toBe(
      "未プッシュ差分レビュー",
    );
    expect(sanitizeAutoRenameName('{"name":"未プッシュ差分レビュー"}')).toBeNull();
    expect(sanitizeAutoRenameName("name: 未プッシュ差分レビュー")).toBeNull();
  });

  it("uses the Claude CLI for Claude sessions", () => {
    execFileSyncMock.mockReturnValue("`依存関係更新`\n");

    const name = generateAutoRenameName({
      provider: "claude",
      projectPath: "/tmp/project",
      model: "claude-haiku-4-6",
      transcript: {
        userText: "依存関係を更新して",
      },
    });

    expect(name).toBe("依存関係更新");
    expect(execFileSyncMock).toHaveBeenCalledWith(
      "claude",
      [
        "-p",
        "--model",
        "claude-haiku-4-6",
        expect.stringContaining("Use only the USER text"),
      ],
      expect.objectContaining({
        cwd: resolve("/tmp/project"),
        encoding: "utf-8",
        maxBuffer: 1024 * 1024,
      }),
    );
    expect(readFileSyncMock).not.toHaveBeenCalled();
  });

  it("uses the Codex Luna model for Codex sessions", () => {
    readFileSyncMock.mockReturnValue("`Claude SDK最新版更新`\n");

    const name = generateAutoRenameName({
      provider: "codex",
      projectPath: "/tmp/project",
      model: "gpt-5.5",
      transcript: {
        userText: "Claude Agent SDKを更新して",
      },
    });

    expect(name).toBe("Claude SDK最新版更新");
    expect(execFileSyncMock).toHaveBeenCalledWith(
      "codex",
      [
        "exec",
        "-m",
        "gpt-5.6-luna",
        "-c",
        'model_reasoning_effort="none"',
        "-o",
        join("/tmp/ccpocket-auto-rename-1", "session-name.txt"),
        "-",
      ],
      expect.objectContaining({
        cwd: resolve("/tmp/project"),
        encoding: "utf-8",
        maxBuffer: 1024 * 1024,
      }),
    );
    expect(execFileSyncMock.mock.calls[0][2].input).toContain(
      "Use only the USER text",
    );
    expect(readFileSyncMock).toHaveBeenCalledWith(
      "/tmp/ccpocket-auto-rename-1/session-name.txt",
      "utf-8",
    );
    expect(rmSyncMock).toHaveBeenCalledWith("/tmp/ccpocket-auto-rename-1", {
      recursive: true,
      force: true,
    });
  });

  it("uses Codex assist environment overrides", () => {
    process.env.BRIDGE_CODEX_ASSIST_MODEL = "gpt-oss:20b-cloud";
    process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT = "low";
    readFileSyncMock.mockReturnValue("Custom gateway rename\n");

    generateAutoRenameName({
      provider: "codex",
      projectPath: "/tmp/project",
      transcript: { userText: "Rename this session" },
    });

    expect(execFileSyncMock).toHaveBeenCalledWith(
      "codex",
      expect.arrayContaining([
        "exec",
        "-m",
        "gpt-oss:20b-cloud",
        "-c",
        'model_reasoning_effort="low"',
      ]),
      expect.any(Object),
    );
  });
});

function restoreEnvVar(key: string, value: string | undefined): void {
  if (value === undefined) {
    delete process.env[key];
    return;
  }
  process.env[key] = value;
}
