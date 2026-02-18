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
    expect(entry?.resumeCwd).toBeUndefined();
    expect(entry?.firstPrompt).toBe("hello codex");
  });

  it("normalizes codex worktree projectPath and keeps resumeCwd for resume targets", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68077";
    const mainProjectPath = "/tmp/project-a";
    const worktreePath = "/tmp/project-a-worktrees/feature-x";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        timestamp: "2026-02-13T12:00:00.000Z",
        type: "session_meta",
        payload: { id: threadId, cwd: worktreePath, git: { branch: "feature/x" } },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T12:00:01.000Z",
        type: "event_msg",
        payload: { type: "user_message", message: "resume this worktree session" },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T12:00:02.000Z",
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "worktree response" }],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const { sessions } = await getAllRecentSessions({ limit: 200 });
    const entry = sessions.find((s) => s.sessionId === threadId);
    expect(entry).toBeDefined();
    expect(entry?.provider).toBe("codex");
    expect(entry?.projectPath).toBe(mainProjectPath);
    expect(entry?.resumeCwd).toBe(worktreePath);

    const mainFilter = await getAllRecentSessions({
      projectPath: mainProjectPath,
      limit: 200,
    });
    expect(mainFilter.sessions.some((s) => s.sessionId === threadId)).toBe(true);

    const worktreeFilter = await getAllRecentSessions({
      projectPath: worktreePath,
      limit: 200,
    });
    expect(worktreeFilter.sessions.some((s) => s.sessionId === threadId)).toBe(true);
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

  it("restores codex tool-use history from response_item entries", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68012";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            {
              type: "input_text",
              text: "# AGENTS.md instructions for /tmp/project-a",
            },
          ],
        },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "check simulator status" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "function_call",
          name: "mcp__dart-mcp__list_running_apps",
          call_id: "call-1",
          arguments: "{\"root\":\"/tmp/project-a\"}",
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "custom_tool_call",
          name: "apply_patch",
          call_id: "call-2",
          input: "*** Begin Patch\n*** End Patch\n",
          status: "completed",
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "web_search_call",
          status: "completed",
          action: {
            type: "search",
            query: "ccpocket codex mcp history restore",
          },
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "Checked all logs." }],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);

    expect(history).toHaveLength(5);
    expect(history[0]).toEqual({
      role: "user",
      content: [{ type: "text", text: "check simulator status" }],
    });
    expect(history[1]).toEqual({
      role: "assistant",
      content: [
        {
          type: "tool_use",
          id: "call-1",
          name: "mcp:dart-mcp/list_running_apps",
          input: { root: "/tmp/project-a" },
        },
      ],
    });
    expect(history[2].content[0].type).toBe("tool_use");
    expect(history[2].content[0].name).toBe("apply_patch");
    expect(history[3]).toEqual({
      role: "assistant",
      content: [
        {
          type: "tool_use",
          id: "web-search-5",
          name: "WebSearch",
          input: { query: "ccpocket codex mcp history restore" },
        },
      ],
    });
    expect(history[4]).toEqual({
      role: "assistant",
      content: [{ type: "text", text: "Checked all logs." }],
    });
  });

  it("renders placeholder text for image-only codex user messages", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68013";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: {
          type: "user_message",
          message: "",
          images: [{ id: "img1" }],
          local_images: [{ path: "/tmp/1.png" }],
          text_elements: [],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);
    expect(history).toEqual([
      {
        role: "user",
        content: [{ type: "text", text: "[Image attached x2]" }],
        imageCount: 2,
      },
    ]);
  });

  it("supports legacy codex response_item tool schemas", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68014";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "legacy tool schema" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "command_execution",
          id: "cmd-1",
          command: "git status",
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "mcp_tool_call",
          id: "mcp-1",
          server: "dart-mcp",
          tool: "launch_app",
          arguments: { device: "ios" },
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);
    expect(history).toEqual([
      {
        role: "user",
        content: [{ type: "text", text: "legacy tool schema" }],
      },
      {
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: "cmd-1",
            name: "Bash",
            input: { command: "git status" },
          },
        ],
      },
      {
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: "mcp-1",
            name: "mcp:dart-mcp/launch_app",
            input: { device: "ios" },
          },
        ],
      },
    ]);
  });

  it("joins multiple assistant output_text chunks and ignores non-text chunks", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68011";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "summarize this" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [
            { type: "output_text", text: "Line 1" },
            { type: "reasoning", text: "hidden reasoning" },
            { type: "output_text", text: "Line 2" },
          ],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);
    expect(history).toHaveLength(2);
    expect(history[1].role).toBe("assistant");
    expect(history[1].content[0].text).toBe("Line 1\nLine 2");
  });

  it("does not match loosely similar filename suffixes for threadId lookup", async () => {
    const requestedThreadId = "123";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    // Similar suffix ("abc123") should not be treated as threadId "123".
    writeFileSync(
      join(codexDir, "rollout-2026-02-13T11-26-43-abc123.jsonl"),
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: "abc123", cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "wrong session" },
        }),
      ].join("\n"),
    );

    // Exact "-123" suffix should be matched.
    writeFileSync(
      join(codexDir, "rollout-2026-02-13T11-26-43-123.jsonl"),
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: requestedThreadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "correct session" },
        }),
      ].join("\n"),
    );

    const history = await getCodexSessionHistory(requestedThreadId);
    expect(history).toHaveLength(1);
    expect(history[0].role).toBe("user");
    expect(history[0].content[0].text).toBe("correct session");
  });

  it("does not trust -threadId filename suffix when session_meta.id differs", async () => {
    const requestedThreadId = "123";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    // Filename ends with -123 but meta id is different: must not match.
    writeFileSync(
      join(codexDir, "rollout-2026-02-13T11-26-43-123.jsonl"),
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: "not-123", cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "wrong session" },
        }),
      ].join("\n"),
    );

    // Exact basename match should still work.
    writeFileSync(
      join(codexDir, "123.jsonl"),
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: requestedThreadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "correct session" },
        }),
      ].join("\n"),
    );

    const history = await getCodexSessionHistory(requestedThreadId);
    expect(history).toHaveLength(1);
    expect(history[0].content[0].text).toBe("correct session");
  });
});
