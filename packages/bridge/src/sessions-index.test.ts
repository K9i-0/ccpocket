import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { pathToSlug, isWorktreeSlug, scanJsonlDir } from "./sessions-index.js";

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
