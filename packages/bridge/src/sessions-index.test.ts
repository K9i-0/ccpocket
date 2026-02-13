import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  pathToSlug,
  isWorktreeSlug,
  normalizeWorktreePath,
  scanJsonlDir,
  getAllRecentSessions,
  getCodexSessionHistory,
} from "./sessions-index.js";

describe("pathToSlug", () => {
  it("converts a path to Claude directory slug", () => {
    expect(pathToSlug("/Users/x/Workspace/myproject")).toBe(
      "-Users-x-Workspace-myproject",
    );
  });

  it("handles nested paths", () => {
    expect(pathToSlug("/a/b/c/d")).toBe("-a-b-c-d");
  });

  it("handles paths with hyphens", () => {
    expect(pathToSlug("/Users/x/my-project")).toBe("-Users-x-my-project");
  });

  it("converts underscores to hyphens", () => {
    expect(pathToSlug("/Users/x/flutter_claude_sandbox")).toBe(
      "-Users-x-flutter-claude-sandbox",
    );
  });
});

describe("isWorktreeSlug", () => {
  const projectSlug = "-Users-x-Workspace-vibetunnel";

  it("matches worktree directory slugs", () => {
    expect(
      isWorktreeSlug(
        "-Users-x-Workspace-vibetunnel-worktrees-branch-abc",
        projectSlug,
      ),
    ).toBe(true);
  });

  it("does not match the project directory itself", () => {
    expect(isWorktreeSlug(projectSlug, projectSlug)).toBe(false);
  });

  it("does not match unrelated directories", () => {
    expect(
      isWorktreeSlug("-Users-x-Workspace-other-project", projectSlug),
    ).toBe(false);
  });

  it("does not match partial prefix collisions", () => {
    // "-vibetunnel-extra" is not the same as "-vibetunnel-worktrees-"
    expect(
      isWorktreeSlug(
        "-Users-x-Workspace-vibetunnel-extra",
        projectSlug,
      ),
    ).toBe(false);
  });
});

describe("normalizeWorktreePath", () => {
  it("normalizes a worktree path to the main project path", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket-worktrees/notice"),
    ).toBe("/Users/x/Workspace/ccpocket");
  });

  it("handles branch names with hyphens", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/gtri-worktrees/test-session-verify"),
    ).toBe("/Users/x/Workspace/gtri");
  });

  it("returns the original path when not a worktree path", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket"),
    ).toBe("/Users/x/Workspace/ccpocket");
  });

  it("returns the original path for empty string", () => {
    expect(normalizeWorktreePath("")).toBe("");
  });

  it("does not match paths ending with -worktrees (no branch segment)", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket-worktrees"),
    ).toBe("/Users/x/Workspace/ccpocket-worktrees");
  });

  it("does not match nested worktree-like paths", () => {
    // Only the last -worktrees/branch segment should match
    expect(
      normalizeWorktreePath("/Users/x/Workspace/foo-worktrees/bar/baz"),
    ).toBe("/Users/x/Workspace/foo-worktrees/bar/baz");
  });
});

describe("scanJsonlDir", () => {
  const testDir = join(tmpdir(), "ccpocket-test-scanJsonl-" + Date.now());

  beforeEach(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true });
  });

  it("returns empty for nonexistent directory", async () => {
    const result = await scanJsonlDir("/nonexistent/path");
    expect(result).toEqual([]);
  });

  it("returns empty for directory with no JSONL files", async () => {
    writeFileSync(join(testDir, "readme.txt"), "hello");
    const result = await scanJsonlDir(testDir);
    expect(result).toEqual([]);
  });

  it("parses a JSONL session file correctly", async () => {
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "hello world" }],
        },
        cwd: "/my/project",
        gitBranch: "main",
        sessionId: "test-session-1",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
      JSON.stringify({
        type: "assistant",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Hi there!" }],
        },
        sessionId: "test-session-1",
        timestamp: "2026-01-01T00:00:01.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "test-session-1.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);

    const entry = result[0];
    expect(entry.sessionId).toBe("test-session-1");
    expect(entry.provider).toBe("claude");
    expect(entry.firstPrompt).toBe("hello world");
    expect(entry.messageCount).toBe(2);
    expect(entry.created).toBe("2026-01-01T00:00:00.000Z");
    expect(entry.modified).toBe("2026-01-01T00:00:01.000Z");
    expect(entry.gitBranch).toBe("main");
    expect(entry.projectPath).toBe("/my/project");
    expect(entry.isSidechain).toBe(false);
  });

  it("extracts summary from summary entries", async () => {
    const lines = [
      JSON.stringify({
        type: "summary",
        summary: "This is a session summary",
      }),
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "test prompt" }],
        },
        cwd: "/proj",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "session-with-summary.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].summary).toBe("This is a session summary");
  });

  it("skips JSONL files with no user/assistant messages", async () => {
    const lines = [
      JSON.stringify({ type: "queue-operation", operation: "dequeue" }),
    ];
    writeFileSync(
      join(testDir, "empty-session.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toEqual([]);
  });

  it("handles multiple JSONL files", async () => {
    for (const id of ["session-a", "session-b"]) {
      const lines = [
        JSON.stringify({
          type: "user",
          message: {
            role: "user",
            content: [{ type: "text", text: `prompt for ${id}` }],
          },
          cwd: "/proj",
          timestamp: "2026-01-01T00:00:00.000Z",
        }),
      ];
      writeFileSync(join(testDir, `${id}.jsonl`), lines.join("\n"));
    }

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(2);
    const ids = result.map((e) => e.sessionId).sort();
    expect(ids).toEqual(["session-a", "session-b"]);
  });

  it("handles malformed JSON lines gracefully", async () => {
    const lines = [
      "not valid json",
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "valid line" }],
        },
        cwd: "/proj",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "mixed.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].firstPrompt).toBe("valid line");
  });

  it("handles string content in user messages", async () => {
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: "plain string prompt",
        },
        cwd: "/proj",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "string-content.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].firstPrompt).toBe("plain string prompt");
  });

  it("normalizes worktree cwd to main project path", async () => {
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "worktree prompt" }],
        },
        cwd: "/Users/x/Workspace/myproject-worktrees/feature-branch",
        gitBranch: "feature-branch",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "wt-session.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].projectPath).toBe("/Users/x/Workspace/myproject");
  });

  it("detects sidechain sessions", async () => {
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "sidechain test" }],
        },
        cwd: "/proj",
        isSidechain: true,
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "sidechain.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].isSidechain).toBe(true);
  });
});

describe("codex sessions integration", () => {
  const oldHome = process.env.HOME;
  const tempHome = mkdtempSync(join(tmpdir(), "ccpocket-test-codex-home-"));

  beforeEach(() => {
    process.env.HOME = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    rmSync(tempHome, { recursive: true, force: true });
  });

  it("includes codex sessions in getAllRecentSessions", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68010";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        timestamp: "2026-02-13T11:26:43.995Z",
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a", git: { branch: "main" } },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T11:26:44.100Z",
        type: "event_msg",
        payload: { type: "user_message", message: "hello codex" },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T11:26:45.100Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "hello from assistant" }],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const { sessions } = await getAllRecentSessions({
      projectPath: "/tmp/project-a",
      limit: 200,
    });
    const entry = sessions.find((s) => s.sessionId === threadId);
    expect(entry).toBeDefined();
    expect(entry?.provider).toBe("codex");
    expect(entry?.projectPath).toBe("/tmp/project-a");
    expect(entry?.firstPrompt).toBe("hello codex");
  });

  it("reads codex history from jsonl", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68010";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "show me the diff" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "Here is the diff summary." }],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);
    expect(history).toHaveLength(2);
    expect(history[0].role).toBe("user");
    expect(history[0].content[0].text).toBe("show me the diff");
    expect(history[1].role).toBe("assistant");
    expect(history[1].content[0].text).toBe("Here is the diff summary.");
  });
});
