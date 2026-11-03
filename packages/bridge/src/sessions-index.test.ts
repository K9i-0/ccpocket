import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { execFileSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  realpathSync,
  rmSync,
  statSync,
  utimesSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  pathToSlug,
  isWorktreeSlug,
  normalizeWorktreePath,
  scanJsonlDir,
  getAllRecentSessions,
  getPinnedCodexSessions,
  selectPinnedRecentSessions,
  getCodexSessionIndexMetadata,
  claudeAbandonedBranchUuids,
  getCodexSessionHistory,
  loadCodexSessionNames,
  extractMessageImages,
  codexThreadToSessionHistory,
  getSessionHistory,
  getClaudeSessionName,
} from "./sessions-index.js";
import { buildAutoRenamePrompt } from "./auto-rename.js";

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

  it("matches Claude project slugs for Windows drive paths", () => {
    expect(pathToSlug("C:\\Users\\29642")).toBe("C--Users-29642");
  });
});

describe("codexThreadToSessionHistory", () => {
  it("converts official thread turns into display history", () => {
    const history = codexThreadToSessionHistory({
      turns: [
        {
          startedAt: 1700000000,
          completedAt: 1700000001,
          items: [
            {
              type: "userMessage",
              id: "u1",
              content: [{ type: "text", text: "hello" }],
            },
            {
              type: "agentMessage",
              id: "a1",
              text: "hi",
              phase: null,
              memoryCitation: null,
            },
            {
              type: "commandExecution",
              id: "cmd1",
              command: "git status",
              cwd: "/tmp/repo",
              pluginId: "openai.browser",
              scriptPath: "/tmp/openai.browser/run.sh",
              status: "completed",
              aggregatedOutput: "clean",
              exitCode: 0,
            },
          ],
        },
      ],
    });

    expect(history).toMatchObject([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        rawItemId: "u1",
        content: [{ type: "text", text: "hello" }],
      },
      {
        role: "assistant",
        uuid: "a1",
        content: [{ type: "text", text: "hi" }],
      },
      {
        role: "assistant",
        uuid: "cmd1",
        content: [
          {
            type: "tool_use",
            id: "cmd1",
            name: "Bash",
            input: {
              command: "git status",
              cwd: "/tmp/repo",
              pluginId: "openai.browser",
              scriptPath: "/tmp/openai.browser/run.sh",
            },
          },
        ],
      },
      {
        role: "tool_result",
        toolUseId: "cmd1",
        toolName: "Bash",
        content: "status: completed\nexitCode: 0\nclean",
      },
    ]);
  });

  it("preserves distinct official agentMessage ids with duplicate text", () => {
    const history = codexThreadToSessionHistory({
      turns: [
        {
          items: [
            { type: "agentMessage", id: "a1", text: "same reply" },
            { type: "agentMessage", id: "a2", text: "same reply" },
          ],
        },
      ],
    });

    expect(history).toEqual([
      {
        role: "assistant",
        uuid: "a1",
        content: [{ type: "text", text: "same reply" }],
      },
      {
        role: "assistant",
        uuid: "a2",
        content: [{ type: "text", text: "same reply" }],
      },
    ]);
  });

  it("preserves official tool item ids and user image refs", () => {
    const history = codexThreadToSessionHistory({
      turns: [
        {
          items: [
            {
              type: "userMessage",
              id: "u1",
              content: [
                { type: "text", text: "inspect this" },
                { type: "localImage", path: "/tmp/local.png" },
                {
                  type: "image",
                  imageUrl: "data:image/png;base64,aW1hZ2U=",
                },
              ],
            },
            {
              type: "imageGeneration",
              id: "img1",
              status: "completed",
            },
          ],
        },
      ],
    });

    expect(history[0]).toMatchObject({
      role: "user",
      uuid: "codex:user-turn:1",
      rawItemId: "u1",
      content: [{ type: "text", text: "inspect this" }],
      imageCount: 2,
      imagePaths: ["/tmp/local.png"],
      imageBase64: [{ data: "aW1hZ2U=", mimeType: "image/png" }],
    });
    expect(history[1]).toMatchObject({
      role: "assistant",
      uuid: "img1",
      content: [
        {
          type: "tool_use",
          id: "img1",
          name: "ImageGeneration",
        },
      ],
    });
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

  it("matches Claude Code worktree directory slugs", () => {
    // /Users/x/Workspace/vibetunnel/.claude/worktrees/feature
    expect(
      isWorktreeSlug(
        "-Users-x-Workspace-vibetunnel--claude-worktrees-feature",
        projectSlug,
      ),
    ).toBe(true);
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

  it("normalizes a Claude Code worktree path to the repository path", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket/.claude/worktrees/fix-a1b2"),
    ).toBe("/Users/x/Workspace/ccpocket");
  });

  it("normalizes Windows-style Claude Code worktree paths", () => {
    expect(
      normalizeWorktreePath("C:\\work\\ccpocket\\.claude\\worktrees\\fix-a1b2"),
    ).toBe("C:\\work\\ccpocket");
  });

  it("does not match paths inside a Claude Code worktree", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket/.claude/worktrees/fix/apps"),
    ).toBe("/Users/x/Workspace/ccpocket/.claude/worktrees/fix/apps");
  });

  it("does not match the Claude Code worktrees root itself", () => {
    expect(
      normalizeWorktreePath("/Users/x/Workspace/ccpocket/.claude/worktrees"),
    ).toBe("/Users/x/Workspace/ccpocket/.claude/worktrees");
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
    expect(entry.created).toBe("2026-01-01T00:00:00.000Z");
    expect(entry.modified).toBe("2026-01-01T00:00:01.000Z");
    expect(entry.gitBranch).toBe("main");
    expect(entry.projectPath).toBe("/my/project");
    expect(entry.isSidechain).toBe(false);
  });

  it("treats the last Claude custom-title entry as authoritative", async () => {
    const lines = [
      JSON.stringify({
        type: "custom-title",
        customTitle: "Old title",
        sessionId: "test-session-title",
      }),
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [{ type: "text", text: "hello title" }],
        },
        cwd: "/my/project",
        gitBranch: "main",
        sessionId: "test-session-title",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
      JSON.stringify({
        type: "custom-title",
        customTitle: "",
        sessionId: "test-session-title",
      }),
    ];
    writeFileSync(
      join(testDir, "test-session-title.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].firstPrompt).toBe("hello title");
    expect(result[0].name).toBeUndefined();
  });

  it("excludes Claude auto-rename helper sessions", async () => {
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [
            {
              type: "text",
              text: buildAutoRenamePrompt({ userText: "real task" }),
            },
          ],
        },
        cwd: "/my/project",
        gitBranch: "main",
        sessionId: "auto-rename-helper",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
      JSON.stringify({
        type: "assistant",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Real task name" }],
        },
        sessionId: "auto-rename-helper",
        timestamp: "2026-01-01T00:00:01.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "auto-rename-helper.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toEqual([]);
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
    // Fast parser skips summary entries for performance (summary comes from sessions-index.json)
    expect(result[0].summary).toBeUndefined();
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

  it("extracts projectPath via streaming fallback when first message exceeds HEAD_BYTES", async () => {
    // Simulate the bug: a user message with large base64 image data pushes
    // the cwd field beyond the 16KB HEAD_BYTES window of the fast parser.
    const largePadding = "x".repeat(20000); // > 16KB
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", data: largePadding },
            },
            { type: "text", text: "analyze this image" },
          ],
        },
        cwd: "/Users/test/big-image-project",
        gitBranch: "feature/images",
        sessionId: "large-msg-session",
        timestamp: "2026-03-01T00:00:00.000Z",
      }),
      JSON.stringify({
        type: "assistant",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "I see the image." }],
        },
        sessionId: "large-msg-session",
        timestamp: "2026-03-01T00:00:01.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "large-msg-session.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);

    const entry = result[0];
    expect(entry.sessionId).toBe("large-msg-session");
    // The critical assertion: projectPath must be extracted even when
    // the cwd field is beyond the fast-read HEAD_BYTES window.
    expect(entry.projectPath).toBe("/Users/test/big-image-project");
    expect(entry.gitBranch).toBe("feature/images");
    expect(entry.firstPrompt).toBe("analyze this image");
  });

  it("prefers the original cwd over later cwd values when first line exceeds HEAD_BYTES", async () => {
    const largePadding = "x".repeat(20000); // > 16KB
    const lines = [
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", data: largePadding } },
            { type: "text", text: "restore this session correctly" },
          ],
        },
        cwd: "/Users/test/original-project",
        gitBranch: "main",
        sessionId: "cwd-drift-session",
        timestamp: "2026-03-01T00:00:00.000Z",
      }),
      JSON.stringify({
        type: "assistant",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Working..." }],
        },
        cwd: "/Users/test/later-project/subdir",
        gitBranch: "feature/drift",
        sessionId: "cwd-drift-session",
        timestamp: "2026-03-01T00:00:01.000Z",
      }),
    ];
    writeFileSync(
      join(testDir, "cwd-drift-session.jsonl"),
      lines.join("\n"),
    );

    const result = await scanJsonlDir(testDir);
    expect(result).toHaveLength(1);
    expect(result[0].projectPath).toBe("/Users/test/original-project");
    expect(result[0].gitBranch).toBe("main");
    expect(result[0].firstPrompt).toBe("restore this session correctly");
  });

  it("skips jsonl files when sessionId is excluded", async () => {
    writeFileSync(
      join(testDir, "included.jsonl"),
      JSON.stringify({
        type: "user",
        message: { role: "user", content: "included session" },
        cwd: "/proj",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    );
    writeFileSync(
      join(testDir, "excluded.jsonl"),
      JSON.stringify({
        type: "user",
        message: { role: "user", content: "excluded session" },
        cwd: "/proj",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    );

    const result = await scanJsonlDir(testDir, {
      excludeSessionIds: new Set(["excluded"]),
    });

    expect(result).toHaveLength(1);
    expect(result[0].sessionId).toBe("included");
  });
});

describe("codex sessions integration", () => {
  const oldHome = process.env.HOME;
  const oldUserProfile = process.env.USERPROFILE;
  const tempHome = mkdtempSync(join(tmpdir(), "ccpocket-test-codex-home-"));

  beforeEach(() => {
    process.env.HOME = tempHome;
    process.env.USERPROFILE = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    process.env.USERPROFILE = oldUserProfile;
    rmSync(tempHome, { recursive: true, force: true });
  });

  it("clears a Codex session name when a later index entry is empty", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68000";
    const indexPath = join(tempHome, ".codex", "session_index.jsonl");
    mkdirSync(join(tempHome, ".codex"), { recursive: true });
    writeFileSync(
      indexPath,
      [
        JSON.stringify({ id: threadId, thread_name: "nfs" }),
        JSON.stringify({ id: threadId, thread_name: "" }),
      ].join("\n"),
    );

    await expect(loadCodexSessionNames()).resolves.toEqual(new Map());
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

  it("uses the newest rollout when a Codex thread has continuation files", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68001";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    const oldPath = join(codexDir, `rollout-2026-02-13T10-00-00-${threadId}.jsonl`);
    const continuationPath = join(
      codexDir,
      `rollout-2026-02-13T12-00-00-${threadId}_019c56c1-0000-7000-8000-000000000001.jsonl`,
    );
    const entry = (text: string) => [
      JSON.stringify({ type: "session_meta", payload: { id: threadId, cwd: "/tmp/project-a" } }),
      JSON.stringify({ type: "event_msg", payload: { type: "user_message", message: text } }),
    ].join("\n");
    writeFileSync(oldPath, entry("stale history"));
    writeFileSync(continuationPath, entry("current history"));
    utimesSync(oldPath, new Date(1_700_000_000_000), new Date(1_700_000_000_000));
    utimesSync(continuationPath, new Date(1_700_000_100_000), new Date(1_700_000_100_000));

    await expect(getCodexSessionHistory(threadId)).resolves.toMatchObject([
      { content: [{ type: "text", text: "current history" }] },
    ]);
  });

  it("applies a caller session filter before pagination", async () => {
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    for (const [id, timestamp] of [
      ["newer-other", "2026-02-13T12:00:00.000Z"],
      ["older-target", "2026-02-13T11:00:00.000Z"],
    ] as const) {
      writeFileSync(
        join(codexDir, `rollout-${id}.jsonl`),
        [
          JSON.stringify({
            timestamp,
            type: "session_meta",
            payload: { id, cwd: "/tmp/shared" },
          }),
          JSON.stringify({
            timestamp,
            type: "event_msg",
            payload: { type: "user_message", message: id },
          }),
        ].join("\n"),
      );
    }

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 1,
      sessionFilter: (session) => session.sessionId === "older-target",
    });

    expect(result.sessions.map((session) => session.sessionId)).toEqual([
      "older-target",
    ]);
    expect(result.hasMore).toBe(false);
  });

  it("excludes codex subagent sessions from recent sessions", async () => {
    const userThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68020";
    const subagentThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68021";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${userThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: userThreadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "user visible session" },
        }),
      ].join("\n"),
    );
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-01-00-${subagentThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:01:00.000Z",
          type: "session_meta",
          payload: {
            id: subagentThreadId,
            cwd: "/tmp/project-a",
            source: { subagent: { other: "guardian" } },
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:01:01.000Z",
          type: "turn_context",
          payload: { model: "codex-auto-review" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:01:02.000Z",
          type: "event_msg",
          payload: {
            type: "user_message",
            message: "The following is the Codex agent history...",
          },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions.map((s) => s.sessionId)).toEqual([userThreadId]);
  });

  it("excludes codex auto review sessions by model as a fallback", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68022";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-02-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:02:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:02:01.000Z",
          type: "turn_context",
          payload: {
            model: "codex-auto-review",
            collaboration_mode: {
              mode: "default",
              settings: { model: "codex-auto-review", reasoning_effort: "low" },
            },
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:02:02.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "approval review prompt" },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions.some((s) => s.sessionId === threadId)).toBe(false);
  });

  it("excludes Codex auto-rename helpers without hiding prefix-matching user sessions", async () => {
    const userThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68023";
    const renameThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68024";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-03-00-${userThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:03:00.000Z",
          type: "session_meta",
          payload: { id: userThreadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:03:01.000Z",
          type: "turn_context",
          payload: { model: "gpt-5.4-mini" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:03:02.000Z",
          type: "event_msg",
          payload: {
            type: "user_message",
            message:
              "Write a concise name for this coding-agent session.\n\nPlease implement a similar user-facing prompt.",
          },
        }),
      ].join("\n"),
    );
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-04-00-${renameThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:04:00.000Z",
          type: "session_meta",
          payload: { id: renameThreadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:04:01.000Z",
          type: "turn_context",
          payload: { model: "gpt-oss:20b-cloud" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:04:02.000Z",
          type: "event_msg",
          payload: {
            type: "user_message",
            message: buildAutoRenamePrompt({ userText: "real task" }),
          },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions.map((s) => s.sessionId)).toEqual([userThreadId]);
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

  it("groups Claude Code worktree sessions under the repository and keeps resumeCwd", async () => {
    const sessionId = "claude-code-worktree-session";
    const mainProjectPath = "/tmp/project-a";
    const worktreePath = "/tmp/project-a/.claude/worktrees/feature-x";
    const claudeDir = join(
      tempHome,
      ".claude",
      "projects",
      "-tmp-project-a--claude-worktrees-feature-x",
    );
    mkdirSync(claudeDir, { recursive: true });
    writeFileSync(
      join(claudeDir, `${sessionId}.jsonl`),
      [
        JSON.stringify({
          type: "user",
          message: { role: "user", content: "first prompt" },
          cwd: worktreePath,
          gitBranch: "claude/feature-x",
          timestamp: "2026-02-13T12:00:00.000Z",
        }),
        JSON.stringify({
          type: "assistant",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "done" }],
          },
          cwd: worktreePath,
          timestamp: "2026-02-13T12:00:01.000Z",
        }),
        JSON.stringify({
          type: "user",
          message: { role: "user", content: "follow-up prompt" },
          cwd: worktreePath,
          timestamp: "2026-02-13T12:00:02.000Z",
        }),
      ].join("\n"),
    );

    const { sessions } = await getAllRecentSessions({ limit: 200 });
    const entry = sessions.find((s) => s.sessionId === sessionId);
    expect(entry).toBeDefined();
    expect(entry?.provider).toBe("claude");
    expect(entry?.projectPath).toBe(mainProjectPath);
    expect(entry?.resumeCwd).toBe(worktreePath);
    // Regression: after regrouping, the last-prompt fill-in must still open
    // the worktree's JSONL, not `pathToSlug(repositoryRoot)`.
    expect(entry?.lastPrompt).toBe("follow-up prompt");

    const mainFilter = await getAllRecentSessions({
      projectPath: mainProjectPath,
      limit: 200,
    });
    expect(mainFilter.sessions.some((s) => s.sessionId === sessionId)).toBe(true);
  });

  it("returns only codex sessions when provider=codex", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68088";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "codex only" },
        }),
      ].join("\n"),
    );

    // Add Claude data in the same HOME to validate provider filtering.
    const claudeProjectDir = join(
      tempHome,
      ".claude",
      "projects",
      "-tmp-project-a",
    );
    mkdirSync(claudeProjectDir, { recursive: true });
    writeFileSync(
      join(claudeProjectDir, "claude-session-1.jsonl"),
      JSON.stringify({
        type: "user",
        message: { role: "user", content: "claude session" },
        cwd: "/tmp/project-a",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].provider).toBe("codex");
    expect(result.sessions[0].sessionId).toBe(threadId);
  });

  it("restores codex reasoning effort from turn_context", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68011";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "turn_context",
          payload: {
            model: "gpt-5.4",
            collaboration_mode: {
              mode: "default",
              settings: {
                model: "gpt-5.4",
                reasoning_effort: "xhigh",
              },
            },
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "codex only" },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].codexSettings?.modelReasoningEffort).toBe(
      "xhigh",
    );
  });

  it("uses the latest turn_context when restoring Codex speed", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68013";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "turn_context",
          payload: { model: "gpt-5.6-sol", service_tier: "fast" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "turn_context",
          payload: { model: "gpt-5.6-sol" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:02.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "standard again" },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].codexSettings?.serviceTier).toBe("standard");
  });

  it("normalizes the Codex priority service tier to Fast", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68015";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "event_msg",
          payload: {
            type: "thread_settings_applied",
            thread_settings: { service_tier: "priority" },
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.750Z",
          type: "turn_context",
          payload: { model: "gpt-5.6-sol" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "stay fast" },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].codexSettings?.serviceTier).toBe("fast");
  });

  it("preserves non-UI Codex service tiers from turn_context", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68014";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "turn_context",
          payload: { model: "gpt-5.6-sol", service_tier: "flex" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "keep flex" },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].codexSettings?.serviceTier).toBe("flex");
  });

  it("includes codex sessions when early turn context is large", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68012";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "turn_context",
          payload: {
            model: "gpt-5.4",
            instructions: "x".repeat(70_000),
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "after large context" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:02.000Z",
          type: "response_item",
          payload: {
            type: "message",
            role: "assistant",
            content: [{ type: "output_text", text: "assistant summary" }],
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:03.000Z",
          type: "event_msg",
          payload: { type: "token_count", details: "x".repeat(300_000) },
        }),
      ].join("\n"),
    );

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].sessionId).toBe(threadId);
    expect(result.sessions[0].firstPrompt).toBe("after large context");
  });

  it("loads codex index metadata only for requested thread ids", async () => {
    const wantedThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68101";
    const ignoredThreadId = "019c56c0-d4d8-7b22-9e3c-200664d68102";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${wantedThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: {
            id: wantedThreadId,
            cwd: "/tmp/project-a-worktrees/feature-x",
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.500Z",
          type: "turn_context",
          payload: {
            model: "gpt-5.4",
            approval_policy: "on-request",
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "wanted" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:02.000Z",
          type: "event_msg",
          payload: { type: "agent_message", message: "done: fixed the bug" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:03.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "thanks, now add a test" },
        }),
      ].join("\n"),
    );
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${ignoredThreadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: ignoredThreadId, cwd: "/tmp/project-b" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "ignored" },
        }),
      ].join("\n"),
    );

    const metadata = await getCodexSessionIndexMetadata([wantedThreadId]);

    expect([...metadata.keys()]).toEqual([wantedThreadId]);
    expect(metadata.get(wantedThreadId)?.resumeCwd).toBe(
      "/tmp/project-a-worktrees/feature-x",
    );
    expect(metadata.get(wantedThreadId)?.codexSettings?.model).toBe("gpt-5.4");
    expect(metadata.get(wantedThreadId)?.codexSettings?.approvalPolicy).toBe(
      "on-request",
    );
    expect(metadata.get(wantedThreadId)?.firstPrompt).toBe("wanted");
    expect(metadata.get(wantedThreadId)?.lastPrompt).toBe(
      "thanks, now add a test",
    );
    expect(metadata.get(wantedThreadId)?.summary).toBe("done: fixed the bug");
  });

  it("uses the newest Codex continuation rollout for recent-session last prompt", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68103";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    const oldPath = join(codexDir, `rollout-2026-02-13T10-00-00-${threadId}.jsonl`);
    const continuationPath = join(
      codexDir,
      `rollout-2026-02-13T12-00-00-${threadId}_019c56c1-0000-7000-8000-000000000001.jsonl`,
    );

    writeFileSync(
      oldPath,
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "old prompt" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "agent_message", message: "old summary" },
        }),
      ].join("\n"),
    );
    writeFileSync(
      continuationPath,
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "response_item",
          payload: {
            type: "message",
            role: "user",
            content: [{ type: "input_text", text: "initial prompt" }],
          },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "token_count", details: "x".repeat(200_000) },
        }),
        JSON.stringify({
          type: "response_item",
          payload: {
            type: "message",
            role: "user",
            content: [{ type: "input_text", text: "latest prompt" }],
          },
        }),
        JSON.stringify({
          type: "response_item",
          payload: {
            type: "message",
            role: "assistant",
            content: [{ type: "output_text", text: "latest summary".padEnd(200_000, ".") }],
          },
        }),
      ].join("\n"),
    );
    utimesSync(oldPath, new Date(1_700_000_000_000), new Date(1_700_000_000_000));
    utimesSync(
      continuationPath,
      new Date(1_700_000_100_000),
      new Date(1_700_000_100_000),
    );

    const metadata = await getCodexSessionIndexMetadata([threadId]);

    expect(metadata.get(threadId)).toMatchObject({
      firstPrompt: "initial prompt",
      lastPrompt: "latest prompt",
      summary: expect.stringMatching(/^latest summary/),
    });
  });

  it("follows reverted Codex rollout segments (thread/revert, Codex App edit)", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d680aa";
    const segmentId = "019c56c0-d4d8-7b22-9e3c-200664d680bb";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    const line = (type: string, payload: unknown) =>
      `${JSON.stringify({ timestamp: "2026-02-13T10:00:00.000Z", type, payload })}\n`;
    const user = (text: string) => line("event_msg", { type: "user_message", message: text });
    const answer = (text: string) =>
      line("response_item", {
        type: "message",
        role: "assistant",
        content: [{ type: "output_text", text }],
      });
    const meta = line("session_meta", { id: threadId, cwd: "/tmp/p" });
    const keep = meta + user("ONE") + answer("one");
    const basePath = join(codexDir, `rollout-2026-02-13T10-00-00-${threadId}.jsonl`);
    writeFileSync(basePath, keep + user("TWO") + answer("two"));
    const segmentPath = join(
      codexDir,
      `rollout-2026-02-13T10-01-00-${threadId}_${segmentId}.jsonl`,
    );
    const segmentKeep =
      line("session_meta", {
        id: threadId,
        cwd: "/tmp/p",
        history_base: {
          thread_id: threadId,
          end_byte_offset: Buffer.byteLength(keep),
        },
      }) + user("EDITED") + answer("edited");
    writeFileSync(segmentPath, segmentKeep + user("RETRACTED"));
    // A retract right after: the newest segment holds only metadata.
    const leafPath = join(
      codexDir,
      `rollout-2026-02-13T10-02-00-${threadId}_019c56c0-d4d8-7b22-9e3c-200664d680cc.jsonl`,
    );
    writeFileSync(
      leafPath,
      line("session_meta", {
        id: threadId,
        cwd: "/tmp/p",
        history_base: {
          thread_id: segmentId,
          end_byte_offset: Buffer.byteLength(segmentKeep),
        },
      }),
    );
    // Reverted segments can be written after the segment replacing them.
    utimesSync(leafPath, new Date(1_700_000_000_000), new Date(1_700_000_000_000));
    utimesSync(segmentPath, new Date(1_700_000_050_000), new Date(1_700_000_050_000));
    utimesSync(basePath, new Date(1_700_000_100_000), new Date(1_700_000_100_000));

    const metadata = await getCodexSessionIndexMetadata([threadId]);
    expect(metadata.get(threadId)).toMatchObject({
      firstPrompt: "ONE",
      lastPrompt: "EDITED",
    });

    const history = await getCodexSessionHistory(threadId);
    expect(
      history.filter((m) => m.role === "user").map((m) =>
        (m.content as Array<{ text?: string }>).map((b) => b.text).join(""),
      ),
    ).toEqual(["ONE", "EDITED"]);
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
    expect(history[0].uuid).toBe("codex:user-turn:1");
    expect(history[0].content[0].text).toBe("show me the diff");
    expect(history[1].role).toBe("assistant");
    expect(history[1].content[0].text).toBe("Here is the diff summary.");
  });

  it("trims codex history after thread_rolled_back events", async () => {
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
        payload: { type: "user_message", message: "first turn" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "first answer" }],
        },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "second turn" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "second answer" }],
        },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "thread_rolled_back", num_turns: 1 },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);
    expect(history.map((message) => message.content[0].text)).toEqual([
      "first turn",
      "first answer",
    ]);
    expect(history[0].uuid).toBe("codex:user-turn:1");
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
      uuid: "codex:user-turn:1",
      content: [{ type: "text", text: "check simulator status" }],
    });
    expect(history[1]).toEqual({
      role: "assistant",
      uuid: "call-1",
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
      uuid: "web-search-5",
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

  it("restores codex MCP tool result images from event_msg entries", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68016";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const imageData = "iVBORw0KGgo=";
    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "inspect chrome" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "function_call",
          name: "mcp__computer-use__get_app_state",
          call_id: "call-1",
          arguments: "{\"app\":\"Google Chrome\"}",
        },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T11:28:00.000Z",
        type: "event_msg",
        payload: {
          type: "mcp_tool_call_end",
          call_id: "call-1",
          invocation: {
            server: "computer-use",
            tool: "get_app_state",
            arguments: { app: "Google Chrome" },
          },
          result: {
            Ok: {
              content: [
                { type: "text", text: "Computer Use state" },
                { type: "image", data: imageData, mimeType: "image/png" },
              ],
            },
          },
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);

    expect(history).toHaveLength(3);
    expect(history[0]).toEqual({
      role: "user",
      uuid: "codex:user-turn:1",
      content: [{ type: "text", text: "inspect chrome" }],
    });
    expect(history[1].content[0].type).toBe("tool_use");
    expect(history[2]).toEqual({
      role: "tool_result",
      toolUseId: "call-1",
      toolName: "mcp:computer-use/get_app_state",
      content: "Computer Use state",
      imageBase64: [{ data: imageData, mimeType: "image/png" }],
      timestamp: "2026-02-13T11:28:00.000Z",
    });
  });

  it("skips codex skill injections and restores image generation results", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68015";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    const savedPath = "/tmp/project-a/generated.png";
    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: { type: "user_message", message: "$imagegen make a hero" },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            {
              type: "input_text",
              text: "<skill>\n<name>imagegen</name>\nsecret instructions\n</skill>",
            },
          ],
        },
      }),
      JSON.stringify({
        timestamp: "2026-02-13T11:27:00.000Z",
        type: "event_msg",
        payload: {
          type: "image_generation_end",
          call_id: "ig-1",
          status: "completed",
          revised_prompt: "polished mobile app hero",
          saved_path: savedPath,
          result: "large-base64-data",
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "image_generation_call",
          id: "ig-1",
          status: "completed",
          revised_prompt: "polished mobile app hero",
          result: "large-base64-data",
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
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "$imagegen make a hero" }],
      },
      {
        role: "tool_result",
        toolUseId: "ig-1",
        toolName: "ImageGeneration",
        content:
          "status: completed\nrevisedPrompt: polished mobile app hero\n" +
          `savedPath: ${savedPath}`,
        imagePaths: [savedPath],
        timestamp: "2026-02-13T11:27:00.000Z",
      },
    ]);
  });

  it("restores image generation base64 result without leaking it into content", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68016";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      [
        JSON.stringify({
          type: "session_meta",
          payload: { id: threadId, cwd: "/tmp/project-a" },
        }),
        JSON.stringify({
          type: "event_msg",
          payload: { type: "user_message", message: "$imagegen make a hero" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T11:27:00.000Z",
          type: "response_item",
          payload: {
            type: "image_generation_call",
            id: "ig-2",
            status: "completed",
            result: "data:image/png;base64,aGVsbG8=",
          },
        }),
      ].join("\n"),
    );

    const history = await getCodexSessionHistory(threadId);

    expect(history).toEqual([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "$imagegen make a hero" }],
      },
      {
        role: "tool_result",
        toolUseId: "ig-2",
        toolName: "ImageGeneration",
        content: "status: completed",
        imageBase64: [{ data: "aGVsbG8=", mimeType: "image/png" }],
        timestamp: "2026-02-13T11:27:00.000Z",
      },
    ]);
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
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "[Image attached x2]" }],
        imageCount: 2,
      },
    ]);
  });

  it("extracts codex user images by turn uuid", async () => {
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
        payload: { type: "user_message", message: "first" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: {
          type: "user_message",
          message: "with image",
          images: ["data:image/png;base64,aW1hZ2U="],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    await expect(
      extractMessageImages(threadId, "codex:user-turn:2"),
    ).resolves.toEqual([{ base64: "aW1hZ2U=", mimeType: "image/png" }]);
  });

  it("extracts codex user images from rollout filename without session meta", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68017";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });

    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      JSON.stringify({
        type: "event_msg",
        payload: {
          type: "user_message",
          message: "with image",
          images: ["data:image/png;base64,aW1hZ2U="],
        },
      }),
    );

    await expect(
      extractMessageImages(threadId, "codex:user-turn:1"),
    ).resolves.toEqual([{ base64: "aW1hZ2U=", mimeType: "image/png" }]);
  });

  it("extracts codex user images from local image paths", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68015";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    const imagePath = join(tempHome, "ccpocket-codex-image.png");
    mkdirSync(codexDir, { recursive: true });
    writeFileSync(imagePath, Buffer.from("local-image"));

    const lines = [
      JSON.stringify({
        type: "session_meta",
        payload: { id: threadId, cwd: "/tmp/project-a" },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: {
          type: "user_message",
          message: "with local image",
          images: [],
          local_images: [imagePath],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    await expect(getCodexSessionHistory(threadId)).resolves.toEqual([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "with local image" }],
        imageCount: 1,
      },
    ]);
    await expect(
      extractMessageImages(threadId, "codex:user-turn:1"),
    ).resolves.toEqual([
      {
        base64: Buffer.from("local-image").toString("base64"),
        mimeType: "image/png",
      },
    ]);
  });

  it("extracts codex user images from response items when local image files are gone", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-200664d68016";
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
              text: "# AGENTS.md instructions for /tmp/project-a\n\n<INSTRUCTIONS>",
            },
            {
              type: "input_text",
              text: "<environment_context><cwd>/tmp/project-a</cwd></environment_context>",
            },
          ],
        },
      }),
      JSON.stringify({
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [
            { type: "input_text", text: "with response image" },
            { type: "input_text", text: "<image name=[Image #1]>" },
            {
              type: "input_image",
              image_url: "data:image/png;base64,cmVzcG9uc2UtaW1hZ2U=",
            },
            { type: "input_text", text: "</image>" },
          ],
        },
      }),
      JSON.stringify({
        type: "event_msg",
        payload: {
          type: "user_message",
          message: "with response image",
          images: [],
          local_images: [join(tempHome, "missing-image.png")],
        },
      }),
    ];
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T11-26-43-${threadId}.jsonl`),
      lines.join("\n"),
    );

    await expect(getCodexSessionHistory(threadId)).resolves.toEqual([
      {
        role: "user",
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "with response image" }],
        imageCount: 1,
      },
    ]);
    await expect(
      extractMessageImages(threadId, "codex:user-turn:1"),
    ).resolves.toEqual([
      { base64: "cmVzcG9uc2UtaW1hZ2U=", mimeType: "image/png" },
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
        uuid: "codex:user-turn:1",
        content: [{ type: "text", text: "legacy tool schema" }],
      },
      {
        role: "assistant",
        uuid: "cmd-1",
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
        uuid: "mcp-1",
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

  it("indexes Claude user images by uuid", async () => {
    const sessionId = "claude-image-index";
    const claudeDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(claudeDir, { recursive: true });
    writeFileSync(
      join(claudeDir, `${sessionId}.jsonl`),
      [
        JSON.stringify({
          type: "user",
          uuid: "uuid-text",
          message: { role: "user", content: "text only" },
        }),
        JSON.stringify({
          type: "user",
          uuid: "uuid-image",
          message: {
            role: "user",
            content: [
              { type: "text", text: "look" },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/png",
                  data: "aW1hZ2U=",
                },
              },
            ],
          },
        }),
        JSON.stringify({
          type: "user",
          uuid: "uuid-malformed-image",
          message: {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/png",
                  data: { unexpected: true },
                },
              },
            ],
          },
        }),
      ].join("\n"),
    );

    await expect(extractMessageImages(sessionId, "uuid-image")).resolves.toEqual([
      { base64: "aW1hZ2U=", mimeType: "image/png" },
    ]);
    await expect(extractMessageImages(sessionId, "uuid-text")).resolves.toEqual(
      [],
    );
    await expect(
      extractMessageImages(sessionId, "uuid-malformed-image"),
    ).resolves.toEqual([]);
  });

  it("reuses a fresh Claude image index and invalidates it on file changes", async () => {
    const sessionId = "claude-image-cache-reuse";
    const claudeDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(claudeDir, { recursive: true });
    const jsonlPath = join(claudeDir, `${sessionId}.jsonl`);
    const entry = (data: string) =>
      JSON.stringify({
        type: "user",
        uuid: "uuid-image",
        message: {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: "image/png", data },
            },
          ],
        },
      });
    const fixedTime = new Date(1_700_000_000_000);
    writeFileSync(jsonlPath, entry("AAAA"));
    utimesSync(jsonlPath, fixedTime, fixedTime);

    await expect(extractMessageImages(sessionId, "uuid-image")).resolves.toEqual([
      { base64: "AAAA", mimeType: "image/png" },
    ]);

    const originalStat = statSync(jsonlPath);
    writeFileSync(jsonlPath, entry("BBBB"));
    utimesSync(jsonlPath, fixedTime, fixedTime);
    expect(statSync(jsonlPath).mtimeMs).toBe(originalStat.mtimeMs);
    await expect(extractMessageImages(sessionId, "uuid-image")).resolves.toEqual([
      { base64: "AAAA", mimeType: "image/png" },
    ]);

    writeFileSync(jsonlPath, entry("CCCCCC"));
    await expect(extractMessageImages(sessionId, "uuid-image")).resolves.toEqual([
      { base64: "CCCCCC", mimeType: "image/png" },
    ]);
  });
});

describe("claude namedOnly optimization", () => {
  const oldHome = process.env.HOME;
  const tempHome = mkdtempSync(join(tmpdir(), "ccpocket-test-claude-home-"));

  beforeEach(() => {
    process.env.HOME = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    rmSync(tempHome, { recursive: true, force: true });
  });

  it("returns only named Claude sessions from sessions-index", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId: "named-s1",
            fullPath: join(projectDir, "named-s1.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: "named prompt",
            customTitle: "My named session",
            messageCount: 4,
            created: "2026-02-13T11:00:00.000Z",
            modified: "2026-02-13T12:00:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
          {
            sessionId: "unnamed-s2",
            fullPath: join(projectDir, "unnamed-s2.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: "unnamed prompt",
            messageCount: 2,
            created: "2026-02-13T10:00:00.000Z",
            modified: "2026-02-13T10:10:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].sessionId).toBe("named-s1");
    expect(result.sessions[0].name).toBe("My named session");
  });

  it("finds an exact Claude session outside the first recent page", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId: "newer-s1",
            fullPath: join(projectDir, "newer-s1.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: "newer prompt",
            messageCount: 2,
            created: "2026-02-13T12:00:00.000Z",
            modified: "2026-02-13T12:00:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
          {
            sessionId: "target-s2",
            fullPath: join(projectDir, "target-s2.jsonl"),
            fileMtime: Date.now() - 1000,
            firstPrompt: "target prompt",
            messageCount: 2,
            created: "2026-02-13T10:00:00.000Z",
            modified: "2026-02-13T10:00:00.000Z",
            gitBranch: "feature",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      sessionId: "target-s2",
      limit: 1,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0]).toMatchObject({
      sessionId: "target-s2",
      projectPath: "/tmp/project-a",
      gitBranch: "feature",
    });
  });

  it("excludes indexed Claude auto-rename helper sessions", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId: "real-s1",
            fullPath: join(projectDir, "real-s1.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: "real prompt",
            messageCount: 2,
            created: "2026-02-13T11:00:00.000Z",
            modified: "2026-02-13T12:00:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
          {
            sessionId: "auto-rename-helper",
            fullPath: join(projectDir, "auto-rename-helper.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: buildAutoRenamePrompt({ userText: "real task" }),
            messageCount: 2,
            created: "2026-02-13T11:30:00.000Z",
            modified: "2026-02-13T11:30:01.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      limit: 200,
    });

    expect(result.sessions.map((s) => s.sessionId)).toEqual(["real-s1"]);
  });

  function claudeUserLine(text: string, timestamp: string): string {
    return JSON.stringify({
      type: "user",
      message: { role: "user", content: text },
      cwd: "/tmp/project-a",
      timestamp,
    });
  }

  function claudeTitleLine(sessionId: string, customTitle: string): string {
    return JSON.stringify({ type: "custom-title", customTitle, sessionId });
  }

  it("includes jsonl-only Claude sessions renamed via a custom-title line", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "renamed.jsonl"),
      [
        claudeUserLine("renamed session", "2026-02-13T12:00:00.000Z"),
        claudeTitleLine("renamed", "Renamed in ccpocket"),
      ].join("\n") + "\n",
    );
    writeFileSync(
      join(projectDir, "unnamed.jsonl"),
      claudeUserLine("unnamed session", "2026-02-13T12:30:00.000Z") + "\n",
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(result.sessions.map((s) => [s.sessionId, s.name])).toEqual([
      ["renamed", "Renamed in ccpocket"],
    ]);
  });

  it("uses the tail custom title of large jsonl-only Claude sessions", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    const filler = Array.from({ length: 40 }, (_, i) =>
      JSON.stringify({
        type: "assistant",
        message: { role: "assistant", content: [{ type: "text", text: "x".repeat(1024) }] },
        timestamp: `2026-02-13T12:${String(i).padStart(2, "0")}:00.000Z`,
      }),
    );
    writeFileSync(
      join(projectDir, "large.jsonl"),
      [
        claudeUserLine("large session", "2026-02-13T11:59:00.000Z"),
        ...filler,
        claudeTitleLine("large", "Named at the end"),
      ].join("\n") + "\n",
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(result.sessions.map((s) => [s.sessionId, s.name])).toEqual([
      ["large", "Named at the end"],
    ]);
  });

  it("excludes jsonl-only Claude sessions whose custom title was cleared", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "cleared.jsonl"),
      [
        claudeUserLine("cleared session", "2026-02-13T12:00:00.000Z"),
        claudeTitleLine("cleared", "Old name"),
        claudeTitleLine("cleared", ""),
      ].join("\n") + "\n",
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(result.sessions).toEqual([]);
  });

  it("includes indexed Claude sessions named only in their JSONL", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "indexed.jsonl"),
      [
        claudeUserLine("indexed session", "2026-02-13T12:00:00.000Z"),
        claudeTitleLine("indexed", "JSONL name"),
      ].join("\n") + "\n",
    );
    writeFileSync(
      join(projectDir, "not-indexed.jsonl"),
      [
        claudeUserLine("not indexed session", "2026-02-13T13:00:00.000Z"),
        claudeTitleLine("not-indexed", "Unindexed name"),
      ].join("\n") + "\n",
    );
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId: "indexed",
            fullPath: join(projectDir, "indexed.jsonl"),
            fileMtime: Date.now(),
            firstPrompt: "indexed session",
            messageCount: 1,
            created: "2026-02-13T12:00:00.000Z",
            modified: "2026-02-13T12:00:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(
      result.sessions.map((s) => [s.sessionId, s.name]).sort(),
    ).toEqual([
      ["indexed", "JSONL name"],
      ["not-indexed", "Unindexed name"],
    ]);
  });

  it("treats a cleared tail title as overriding an earlier head title", async () => {
    const projectDir = join(tempHome, ".claude", "projects", pathToSlug("/tmp/project-a"));
    mkdirSync(projectDir, { recursive: true });
    const filler = Array.from({ length: 40 }, (_, i) =>
      JSON.stringify({
        type: "assistant",
        message: { role: "assistant", content: [{ type: "text", text: "x".repeat(1024) }] },
        timestamp: `2026-02-13T12:${String(i).padStart(2, "0")}:00.000Z`,
      }),
    );
    writeFileSync(
      join(projectDir, "cleared-large.jsonl"),
      [
        claudeUserLine("large session", "2026-02-13T11:59:00.000Z"),
        claudeTitleLine("cleared-large", "Old name"),
        ...filler,
        claudeTitleLine("cleared-large", ""),
      ].join("\n") + "\n",
    );

    await expect(
      getClaudeSessionName("/tmp/project-a", "cleared-large"),
    ).resolves.toBeUndefined();
  });

  it("excludes unnamed jsonl-only Claude sessions when namedOnly=true", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "orphan.jsonl"),
      JSON.stringify({
        type: "user",
        message: { role: "user", content: "orphan session" },
        cwd: "/tmp/project-a",
        timestamp: "2026-02-13T12:00:00.000Z",
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      namedOnly: true,
      limit: 200,
    });

    expect(result.sessions).toEqual([]);
  });

  it("repairs indexed Claude entries with missing projectPath from JSONL", async () => {
    const projectDir = join(
      tempHome,
      ".claude",
      "projects",
      "-Users-test-big-image-project",
    );
    mkdirSync(projectDir, { recursive: true });

    const sessionId = "indexed-missing-project-path";
    const largeBase64 = "A".repeat(20 * 1024);
    writeFileSync(
      join(projectDir, `${sessionId}.jsonl`),
      JSON.stringify({
        type: "user",
        message: {
          role: "user",
          content: [
            { type: "text", text: "Please inspect this screenshot." },
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/png",
                data: largeBase64,
              },
            },
          ],
        },
        cwd: "/Users/test/big-image-project",
        gitBranch: "main",
        timestamp: "2026-01-01T00:00:00.000Z",
      }),
    );
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId,
            fullPath: join(projectDir, `${sessionId}.jsonl`),
            fileMtime: Date.now(),
            firstPrompt: "Please inspect this screenshot.",
            messageCount: 1,
            created: "2026-01-01T00:00:00.000Z",
            modified: "2026-01-01T00:00:00.000Z",
            gitBranch: "",
            projectPath: "",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      projectPath: "/Users/test/big-image-project",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].sessionId).toBe(sessionId);
    expect(result.sessions[0].projectPath).toBe("/Users/test/big-image-project");
    expect(result.sessions[0].gitBranch).toBe("main");
    expect(result.sessions[0].firstPrompt).toBe("Please inspect this screenshot.");
  });

  it("hydrates indexed Claude session names from JSONL custom-title entries", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project-a");
    mkdirSync(projectDir, { recursive: true });

    const sessionId = "indexed-jsonl-title";
    writeFileSync(
      join(projectDir, `${sessionId}.jsonl`),
      [
        JSON.stringify({
          type: "user",
          message: { role: "user", content: "hello" },
          cwd: "/tmp/project-a",
          gitBranch: "main",
          timestamp: "2026-01-01T00:00:00.000Z",
          uuid: "user-1",
        }),
        JSON.stringify({
          type: "custom-title",
          customTitle: "SDK title",
          sessionId,
        }),
      ].join("\n"),
    );
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: [
          {
            sessionId,
            fullPath: join(projectDir, `${sessionId}.jsonl`),
            fileMtime: Date.now(),
            firstPrompt: "hello",
            messageCount: 1,
            created: "2026-01-01T00:00:00.000Z",
            modified: "2026-01-01T00:00:00.000Z",
            gitBranch: "main",
            projectPath: "/tmp/project-a",
            isSidechain: false,
          },
        ],
      }),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      projectPath: "/tmp/project-a",
      limit: 200,
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].sessionId).toBe(sessionId);
    expect(result.sessions[0].name).toBe("SDK title");
  });
});

describe("recent sessions grouped by git repository", () => {
  const oldHome = process.env.HOME;
  const oldUserProfile = process.env.USERPROFILE;
  let tempHome: string;
  let work: string;
  let repo: string;

  const git = (cwd: string, args: string[]): void => {
    execFileSync("git", args, { cwd, stdio: "ignore" });
  };

  const writeCodexSession = (
    threadId: string,
    cwd: string,
    repositoryUrl?: string,
  ): void => {
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${threadId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: {
            id: threadId,
            cwd,
            ...(repositoryUrl ? { git: { repository_url: repositoryUrl } } : {}),
          },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: `prompt in ${cwd}` },
        }),
      ].join("\n"),
    );
  };

  const writeClaudeSession = (sessionId: string, cwd: string): void => {
    const dir = join(tempHome, ".claude", "projects", pathToSlug(cwd));
    mkdirSync(dir, { recursive: true });
    writeFileSync(
      join(dir, `${sessionId}.jsonl`),
      JSON.stringify({
        type: "user",
        message: { role: "user", content: `prompt in ${cwd}` },
        cwd,
        timestamp: "2026-02-13T12:00:00.000Z",
      }),
    );
  };

  beforeEach(() => {
    tempHome = realpathSync(mkdtempSync(join(tmpdir(), "ccpocket-test-git-home-")));
    work = join(tempHome, "work");
    repo = join(work, "app");
    mkdirSync(repo, { recursive: true });
    git(repo, ["init", "-q", "-b", "main"]);
    git(repo, ["config", "user.email", "test@example.com"]);
    git(repo, ["config", "user.name", "Test"]);
    writeFileSync(join(repo, "README.md"), "hello\n");
    git(repo, ["add", "."]);
    git(repo, ["commit", "-q", "-m", "init"]);
    git(repo, ["remote", "add", "origin", "git@github.com:owner/app.git"]);
    process.env.HOME = tempHome;
    process.env.USERPROFILE = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    process.env.USERPROFILE = oldUserProfile;
    rmSync(tempHome, { recursive: true, force: true });
  });

  it("groups sessions from a sibling git worktree under the main repository", async () => {
    const worktree = join(work, "app-feature-1");
    git(repo, ["worktree", "add", "-q", "-b", "feature-1", worktree]);
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000a1", worktree);
    writeClaudeSession("claude-sibling-worktree", worktree);

    const { sessions } = await getAllRecentSessions({ limit: 50 });
    for (const id of ["019c56c0-d4d8-7b22-9e3c-2006640000a1", "claude-sibling-worktree"]) {
      const entry = sessions.find((s) => s.sessionId === id);
      expect(entry?.projectPath).toBe(repo);
      expect(entry?.resumeCwd).toBe(worktree);
    }

    const filtered = await getAllRecentSessions({ projectPath: repo, limit: 50 });
    expect(filtered.sessions.map((s) => s.sessionId).sort()).toEqual([
      "019c56c0-d4d8-7b22-9e3c-2006640000a1",
      "claude-sibling-worktree",
    ]);
  });

  it("includes sibling worktrees on the first filtered request and excludes unrelated projects", async () => {
    const worktree = join(work, "feature-checkout");
    git(repo, ["worktree", "add", "-q", "-b", "feature", worktree]);
    writeClaudeSession("claude-cold-worktree", worktree);
    writeClaudeSession("claude-unrelated", join(work, "unrelated"));
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000d1", worktree);

    const filtered = await getAllRecentSessions({ projectPath: repo, limit: 50 });
    expect(filtered.sessions.map((s) => s.sessionId).sort()).toEqual([
      "019c56c0-d4d8-7b22-9e3c-2006640000d1",
      "claude-cold-worktree",
    ]);
    expect(filtered.sessions.every((s) => s.resumeCwd === worktree)).toBe(true);
  });

  it("keeps existing monorepo subdirectories separate even when Codex records the repository URL", async () => {
    const sub = join(repo, "packages", "mobile");
    mkdirSync(sub, { recursive: true });
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000e1", repo);
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000e2", sub, "https://github.com/owner/app.git");
    writeClaudeSession("claude-package", sub);

    const filtered = await getAllRecentSessions({ projectPath: sub, limit: 50 });
    expect(filtered.sessions.map((s) => s.sessionId).sort()).toEqual([
      "019c56c0-d4d8-7b22-9e3c-2006640000e2",
      "claude-package",
    ]);
    expect(filtered.sessions.every((s) => s.projectPath === sub && !s.resumeCwd)).toBe(true);
  });

  it("groups Codex sessions from deleted worktrees by repository URL", async () => {
    const deleted = join(work, "app-review-42");
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000b1", repo);
    writeCodexSession(
      "019c56c0-d4d8-7b22-9e3c-2006640000b2",
      deleted,
      "https://github.com/owner/app.git",
    );

    const { sessions } = await getAllRecentSessions({ limit: 50 });
    const entry = sessions.find(
      (s) => s.sessionId === "019c56c0-d4d8-7b22-9e3c-2006640000b2",
    );
    expect(entry?.projectPath).toBe(repo);
    expect(entry?.resumeCwd).toBe(deleted);

    const filtered = await getAllRecentSessions({ projectPath: repo, limit: 50 });
    expect(filtered.sessions.map((s) => s.sessionId)).toContain(
      "019c56c0-d4d8-7b22-9e3c-2006640000b2",
    );
  });

  it("reuses parsed Codex rollouts until the file changes", async () => {
    const threadId = "019c56c0-d4d8-7b22-9e3c-2006640000d1";
    writeCodexSession(threadId, repo);
    const find = async () =>
      (await getAllRecentSessions({ limit: 50 })).sessions.find(
        (s) => s.sessionId === threadId,
      );

    const first = await find();
    expect(first?.firstPrompt).toBe(`prompt in ${repo}`);
    // Cached results are clones: mutating one listing must not leak.
    first!.firstPrompt = "mutated";
    first!.projectPath = "/elsewhere";
    const second = await find();
    expect(second?.firstPrompt).toBe(`prompt in ${repo}`);
    expect(second?.projectPath).toBe(repo);

    // Rewriting the rollout (new size) is picked up.
    const other = join(work, "other-cwd");
    mkdirSync(other);
    writeCodexSession(threadId, other);
    const third = await find();
    expect(third?.firstPrompt).toBe(`prompt in ${other}`);
  });

  it("excludes non-interactive codex exec rollouts like thread/list", async () => {
    const execId = "019c56c0-d4d8-7b22-9e3c-2006640000e1";
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T12-00-00-${execId}.jsonl`),
      [
        JSON.stringify({
          timestamp: "2026-02-13T12:00:00.000Z",
          type: "session_meta",
          payload: { id: execId, cwd: repo, source: "exec" },
        }),
        JSON.stringify({
          timestamp: "2026-02-13T12:00:01.000Z",
          type: "event_msg",
          payload: { type: "user_message", message: "image helper" },
        }),
      ].join("\n"),
    );
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000e2", repo);

    const ids = (await getAllRecentSessions({ limit: 50 })).sessions.map(
      (s) => s.sessionId,
    );
    expect(ids).toContain("019c56c0-d4d8-7b22-9e3c-2006640000e2");
    expect(ids).not.toContain(execId);
  });

  it("keeps separate repositories that only share a name prefix", async () => {
    const other = join(work, "app-stats");
    mkdirSync(other);
    git(other, ["init", "-q"]);
    git(other, ["remote", "add", "origin", "git@github.com:owner/app-stats.git"]);
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000c1", repo);
    writeCodexSession("019c56c0-d4d8-7b22-9e3c-2006640000c2", other);

    const { sessions } = await getAllRecentSessions({ limit: 50 });
    const entry = sessions.find(
      (s) => s.sessionId === "019c56c0-d4d8-7b22-9e3c-2006640000c2",
    );
    expect(entry?.projectPath).toBe(other);
    expect(entry?.resumeCwd).toBeUndefined();
  });
});

describe("getSessionHistory non-prompt user entries", () => {
  const oldHome = process.env.HOME;
  let tempHome: string;

  beforeEach(() => {
    tempHome = mkdtempSync(join(tmpdir(), "ccpocket-history-"));
    process.env.HOME = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    rmSync(tempHome, { recursive: true, force: true });
  });

  it("marks task notifications and interrupt markers as meta", async () => {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-project");
    mkdirSync(projectDir, { recursive: true });
    const user = (content: unknown, extra: Record<string, unknown> = {}) =>
      JSON.stringify({
        type: "user",
        uuid: `u-${Math.random()}`,
        message: { role: "user", content },
        ...extra,
      });
    writeFileSync(
      join(projectDir, "session-1.jsonl"),
      [
        user([{ type: "text", text: "Investigate the bridge" }]),
        user([{ type: "text", text: "[Request interrupted by user]" }]),
        user("[Request interrupted by user for tool use]"),
        user("<task-notification>\n<task-id>a1</task-id>\n</task-notification>", {
          promptSource: "system",
        }),
        user([{ type: "text", text: "Follow up" }]),
      ].join("\n"),
    );

    const history = await getSessionHistory("session-1");
    const prompts = history
      .filter((message) => message.role === "user" && !message.isMeta)
      .map((message) => (message.content[0] as { text: string }).text);

    expect(prompts).toEqual(["Investigate the bridge", "Follow up"]);
    expect(history.filter((message) => message.isMeta)).toHaveLength(3);
  });
});

describe("selectPinnedRecentSessions", () => {
  it("keeps provider-qualified matches in listing order", () => {
    const entries = [
      { provider: "claude", sessionId: "a" },
      { provider: "codex", sessionId: "a" },
      { provider: "claude", sessionId: "b" },
    ];
    expect(
      selectPinnedRecentSessions(entries, new Set(["codex:a", "claude:b"])),
    ).toEqual([entries[1], entries[2]]);
  });
});

describe("pinned recent sessions", () => {
  const oldHome = process.env.HOME;
  const oldUserProfile = process.env.USERPROFILE;
  let tempHome: string;

  beforeEach(() => {
    tempHome = mkdtempSync(join(tmpdir(), "ccpocket-test-pinned-home-"));
    process.env.HOME = tempHome;
    process.env.USERPROFILE = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    process.env.USERPROFILE = oldUserProfile;
    rmSync(tempHome, { recursive: true, force: true });
  });

  function writeCodexRollout(
    id: string,
    timestamp: string,
    prompt: string,
    cwd = "/tmp/pinned-project",
  ): void {
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    writeFileSync(
      join(codexDir, `rollout-2026-02-13T00-00-00-${id}.jsonl`),
      [
        JSON.stringify({ timestamp, type: "session_meta", payload: { id, cwd } }),
        JSON.stringify({
          timestamp,
          type: "event_msg",
          payload: { type: "user_message", message: prompt },
        }),
      ].join("\n"),
    );
  }

  function writeCodexNames(names: Record<string, string>): void {
    mkdirSync(join(tempHome, ".codex"), { recursive: true });
    writeFileSync(
      join(tempHome, ".codex", "session_index.jsonl"),
      Object.entries(names)
        .map(([id, name]) => JSON.stringify({ id, thread_name: name }))
        .join("\n"),
    );
  }

  function writeClaudeIndex(
    entries: Array<{ sessionId: string; modified: string; customTitle?: string }>,
  ): void {
    const projectDir = join(tempHome, ".claude", "projects", "-tmp-claude-project");
    mkdirSync(projectDir, { recursive: true });
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: entries.map((entry) => ({
          sessionId: entry.sessionId,
          fullPath: join(projectDir, `${entry.sessionId}.jsonl`),
          fileMtime: Date.now(),
          firstPrompt: `${entry.sessionId} prompt`,
          ...(entry.customTitle ? { customTitle: entry.customTitle } : {}),
          messageCount: 2,
          created: entry.modified,
          modified: entry.modified,
          gitBranch: "main",
          projectPath: "/tmp/claude-project",
          isSidechain: false,
        })),
      }),
    );
  }

  it("returns a pinned Claude session beyond the first page", async () => {
    writeClaudeIndex([
      { sessionId: "newest", modified: "2026-02-13T12:00:00.000Z" },
      { sessionId: "middle", modified: "2026-02-13T11:00:00.000Z" },
      { sessionId: "oldest-pinned", modified: "2026-02-13T10:00:00.000Z" },
    ]);

    const result = await getAllRecentSessions({
      provider: "claude",
      limit: 1,
      pinnedSessionKeys: new Set(["claude:oldest-pinned"]),
    });

    expect(result.sessions.map((s) => s.sessionId)).toEqual(["newest"]);
    expect(result.hasMore).toBe(true);
    expect(result.pinnedSessions?.map((s) => s.sessionId)).toEqual([
      "oldest-pinned",
    ]);
  });

  it("omits pinnedSessions when no pins were requested", async () => {
    writeClaudeIndex([
      { sessionId: "only", modified: "2026-02-13T12:00:00.000Z" },
    ]);

    const result = await getAllRecentSessions({ provider: "claude" });

    expect(result.pinnedSessions).toBeUndefined();
  });

  it("applies provider, namedOnly and search filters to pinned sessions", async () => {
    writeClaudeIndex([
      {
        sessionId: "claude-named",
        modified: "2026-02-13T12:00:00.000Z",
        customTitle: "Deploy fix",
      },
      { sessionId: "claude-unnamed", modified: "2026-02-13T11:00:00.000Z" },
    ]);
    writeCodexRollout("codex-pin", "2026-02-13T10:00:00.000Z", "deploy codex");
    const pins = new Set([
      "claude:claude-named",
      "claude:claude-unnamed",
      "codex:codex-pin",
    ]);

    const claudeOnly = await getAllRecentSessions({
      provider: "claude",
      limit: 1,
      pinnedSessionKeys: pins,
    });
    expect(claudeOnly.pinnedSessions?.map((s) => s.sessionId)).toEqual([
      "claude-named",
      "claude-unnamed",
    ]);

    const namedOnly = await getAllRecentSessions({
      namedOnly: true,
      limit: 1,
      pinnedSessionKeys: pins,
    });
    expect(namedOnly.pinnedSessions?.map((s) => s.sessionId)).toEqual([
      "claude-named",
    ]);

    const searched = await getAllRecentSessions({
      searchQuery: "codex",
      limit: 1,
      pinnedSessionKeys: pins,
    });
    expect(searched.pinnedSessions?.map((s) => s.sessionId)).toEqual([
      "codex-pin",
    ]);
  });

  it("excludes archived pinned sessions", async () => {
    writeCodexRollout("newer", "2026-02-13T12:00:00.000Z", "newer");
    writeCodexRollout("archived-pin", "2026-02-13T10:00:00.000Z", "old");

    const result = await getAllRecentSessions({
      provider: "codex",
      limit: 1,
      archivedSessionIds: new Set(["archived-pin"]),
      pinnedSessionKeys: new Set(["codex:archived-pin"]),
    });

    expect(result.pinnedSessions).toEqual([]);
  });

  it("looks up pinned Codex threads in thread/list shape", async () => {
    const worktreeCwd = "/tmp/pinned-project-worktrees/feature";
    writeCodexRollout("wt-pin", "2026-02-13T10:00:00.000Z", "fix bug", worktreeCwd);
    writeCodexRollout("unrelated", "2026-02-13T11:00:00.000Z", "other");
    writeCodexNames({ "wt-pin": "Worktree fix" });

    const result = await getPinnedCodexSessions({ threadIds: ["wt-pin"] });

    expect(result).toEqual([
      expect.objectContaining({
        sessionId: "wt-pin",
        provider: "codex",
        name: "Worktree fix",
        projectPath: worktreeCwd,
        resumeCwd: worktreeCwd,
      }),
    ]);
  });

  it("filters pinned Codex threads like the listing", async () => {
    writeCodexRollout("named", "2026-02-13T12:00:00.000Z", "deploy it");
    writeCodexRollout("unnamed", "2026-02-13T11:00:00.000Z", "deploy too");
    writeCodexRollout("archived", "2026-02-13T10:00:00.000Z", "deploy");
    writeCodexRollout(
      "elsewhere",
      "2026-02-13T09:00:00.000Z",
      "deploy",
      "/tmp/other-project",
    );
    writeCodexNames({ named: "Named thread", archived: "Archived thread" });
    const threadIds = ["named", "unnamed", "archived", "elsewhere"];
    const archivedSessionIds = new Set(["archived"]);

    const all = await getPinnedCodexSessions({ threadIds, archivedSessionIds });
    expect(all.map((s) => s.sessionId)).toEqual([
      "named",
      "unnamed",
      "elsewhere",
    ]);

    const projectScoped = await getPinnedCodexSessions({
      threadIds,
      archivedSessionIds,
      projectPath: "/tmp/pinned-project",
      namedOnly: true,
    });
    expect(projectScoped.map((s) => s.sessionId)).toEqual(["named"]);

    const searched = await getPinnedCodexSessions({
      threadIds,
      archivedSessionIds,
      searchQuery: "TOO",
    });
    expect(searched.map((s) => s.sessionId)).toEqual(["unnamed"]);
  });
});

describe("recent session search", () => {
  const oldHome = process.env.HOME;
  const oldUserProfile = process.env.USERPROFILE;
  let tempHome: string;
  const claudeProject = "/tmp/search-project-alpha";

  beforeEach(() => {
    tempHome = mkdtempSync(join(tmpdir(), "ccpocket-test-search-home-"));
    process.env.HOME = tempHome;
    process.env.USERPROFILE = tempHome;
  });

  afterEach(() => {
    process.env.HOME = oldHome;
    process.env.USERPROFILE = oldUserProfile;
    rmSync(tempHome, { recursive: true, force: true });
  });

  interface ClaudeFixture {
    sessionId: string;
    modified: string;
    created?: string;
    firstPrompt?: string;
    customTitle?: string;
    summary?: string;
    gitBranch?: string;
    transcript?: unknown[];
  }

  function writeClaude(entries: ClaudeFixture[]): void {
    const projectDir = join(tempHome, ".claude", "projects", pathToSlug(claudeProject));
    mkdirSync(projectDir, { recursive: true });
    for (const entry of entries) {
      writeFileSync(
        join(projectDir, `${entry.sessionId}.jsonl`),
        (entry.transcript ?? []).map((line) => JSON.stringify(line)).join("\n"),
      );
    }
    writeFileSync(
      join(projectDir, "sessions-index.json"),
      JSON.stringify({
        version: 1,
        entries: entries.map((entry) => ({
          sessionId: entry.sessionId,
          fullPath: join(projectDir, `${entry.sessionId}.jsonl`),
          fileMtime: Date.now(),
          firstPrompt: entry.firstPrompt ?? `${entry.sessionId} prompt`,
          ...(entry.customTitle ? { customTitle: entry.customTitle } : {}),
          ...(entry.summary ? { summary: entry.summary } : {}),
          messageCount: 2,
          created: entry.created ?? entry.modified,
          modified: entry.modified,
          gitBranch: entry.gitBranch ?? "main",
          projectPath: claudeProject,
          isSidechain: false,
        })),
      }),
    );
  }

  function writeCodexRollout(
    id: string,
    timestamp: string,
    lines: unknown[],
    fileStamp = "2026-02-13T00-00-00",
  ): void {
    const codexDir = join(tempHome, ".codex", "sessions", "2026", "02", "13");
    mkdirSync(codexDir, { recursive: true });
    writeFileSync(
      join(codexDir, `rollout-${fileStamp}-${id}.jsonl`),
      [
        { timestamp, type: "session_meta", payload: { id, cwd: "/tmp/codex-proj" } },
        {
          timestamp,
          type: "event_msg",
          payload: { type: "user_message", message: `${id} prompt` },
        },
        ...lines.map((line) => ({ timestamp, ...(line as object) })),
      ]
        .map((line) => JSON.stringify(line))
        .join("\n"),
    );
  }

  const user = (text: string) => ({
    type: "user",
    message: { role: "user", content: text },
  });
  const assistant = (text: string) => ({
    type: "assistant",
    message: { role: "assistant", content: [{ type: "text", text }] },
  });
  const toolResult = (text: string) => ({
    type: "user",
    message: {
      role: "user",
      content: [{ type: "tool_result", tool_use_id: "t1", content: text }],
    },
  });

  it("reports the first matching metadata field in priority order", async () => {
    writeClaude([
      {
        sessionId: "by-name",
        modified: "2026-02-13T12:00:00.000Z",
        customTitle: "Kiwi title",
        firstPrompt: "kiwi prompt",
      },
      {
        sessionId: "by-prompt",
        modified: "2026-02-13T11:00:00.000Z",
        firstPrompt: "add kiwi support",
        summary: "kiwi summary",
      },
      {
        sessionId: "by-summary",
        modified: "2026-02-13T10:00:00.000Z",
        summary: "Kiwi refactor",
      },
      {
        sessionId: "by-branch",
        modified: "2026-02-13T09:00:00.000Z",
        gitBranch: "feat/kiwi",
      },
      { sessionId: "no-match", modified: "2026-02-13T08:00:00.000Z" },
    ]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "KIWI",
    });

    expect(
      result.sessions.map((s) => [s.sessionId, s.searchMatch?.field]),
    ).toEqual([
      ["by-name", "name"],
      ["by-prompt", "firstPrompt"],
      ["by-summary", "summary"],
      ["by-branch", "branch"],
    ]);
  });

  it("matches the project folder name and leaves searchMatch off without a query", async () => {
    writeClaude([{ sessionId: "s1", modified: "2026-02-13T12:00:00.000Z" }]);

    const searched = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "project-alp",
    });
    expect(searched.sessions).toEqual([
      expect.objectContaining({
        sessionId: "s1",
        searchMatch: { field: "project" },
      }),
    ]);

    const unsearched = await getAllRecentSessions({ provider: "claude" });
    expect(unsearched.sessions[0]).not.toHaveProperty("searchMatch");
  });

  it("does not match parent directories of the project path", async () => {
    writeClaude([{ sessionId: "s1", modified: "2026-02-13T12:00:00.000Z" }]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "tmp",
    });
    expect(result.sessions).toEqual([]);
  });

  it("attaches searchMatch to pinned sessions", async () => {
    writeClaude([
      { sessionId: "newest", modified: "2026-02-13T12:00:00.000Z", firstPrompt: "fig a" },
      { sessionId: "pinned", modified: "2026-02-13T10:00:00.000Z", gitBranch: "fig" },
    ]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "fig",
      limit: 1,
      pinnedSessionKeys: new Set(["claude:pinned"]),
    });
    expect(result.pinnedSessions).toEqual([
      expect.objectContaining({ sessionId: "pinned", searchMatch: { field: "branch" } }),
    ]);
  });

  it("searches transcript text only with searchContent", async () => {
    writeClaude([
      {
        sessionId: "user-hit",
        modified: "2026-02-13T12:00:00.000Z",
        transcript: [user("please migrate the Mango schema")],
      },
      {
        sessionId: "tool-only",
        modified: "2026-02-13T11:00:00.000Z",
        transcript: [user("run it"), toolResult("mango in tool output")],
      },
      {
        sessionId: "assistant-hit",
        modified: "2026-02-13T10:00:00.000Z",
        transcript: [user("hi"), assistant("The mango column is gone")],
      },
      {
        sessionId: "meta-hit",
        modified: "2026-02-13T09:00:00.000Z",
        firstPrompt: "mango title",
      },
    ]);

    const metadataOnly = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "mango",
    });
    expect(metadataOnly.sessions.map((s) => s.sessionId)).toEqual(["meta-hit"]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "mango",
      searchContent: true,
    });
    expect(
      result.sessions.map((s) => [s.sessionId, s.searchMatch]),
    ).toEqual([
      ["user-hit", { field: "content", snippet: "please migrate the Mango schema" }],
      ["assistant-hit", { field: "content", snippet: "The mango column is gone" }],
      ["meta-hit", { field: "firstPrompt" }],
    ]);
    expect(result.hasMore).toBe(false);
    expect(result.contentSearchIncomplete).toBeUndefined();
  });

  it("paginates content matches newest first", async () => {
    writeClaude(
      Array.from({ length: 5 }, (_, i) => ({
        sessionId: `s${i}`,
        modified: `2026-02-13T1${5 - i}:00:00.000Z`,
        transcript: [user(i === 2 ? "unrelated" : "needle here")],
      })),
    );

    const page = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "needle",
      searchContent: true,
      limit: 2,
      offset: 1,
    });
    expect(page.sessions.map((s) => s.sessionId)).toEqual(["s1", "s3"]);
    expect(page.hasMore).toBe(true);
  });

  it("returns hasMore when the content search file bound is hit", async () => {
    writeClaude(
      Array.from({ length: 4 }, (_, i) => ({
        sessionId: `s${i}`,
        modified: `2026-02-13T1${5 - i}:00:00.000Z`,
        transcript: [user(i === 0 || i === 3 ? "needle" : "miss")],
      })),
    );

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "needle",
      searchContent: true,
      limit: 10,
      contentSearchLimits: { maxFiles: 2 },
    });
    expect(result.sessions.map((s) => s.sessionId)).toEqual(["s0"]);
    expect(result.hasMore).toBe(true);
    expect(result.contentSearchIncomplete).toBe(true);
  });

  it("searches every Codex rollout segment of a thread", async () => {
    const assistantLine = (text: string) => ({
      type: "response_item",
      payload: {
        type: "message",
        role: "assistant",
        content: [{ type: "output_text", text }],
      },
    });
    // Whichever segment the listing keeps for a thread, the other segment's
    // transcript must still be searched: one thread has the hit in its first
    // segment, the other in its continuation.
    const first = "019c56c0-d4d8-7b22-9e3c-200664d68aaa";
    const second = "019c56c0-d4d8-7b22-9e3c-200664d68ccc";
    writeCodexRollout(first, "2026-02-13T10:00:00.000Z", [
      assistantLine("papaya in the first segment"),
      assistantLine("final words"),
    ]);
    writeCodexRollout(
      first,
      "2026-02-13T12:00:00.000Z",
      [assistantLine("later")],
      "2026-02-13T11-00-00",
    );
    writeCodexRollout(second, "2026-02-13T09:00:00.000Z", [
      assistantLine("early"),
    ]);
    writeCodexRollout(
      second,
      "2026-02-13T09:30:00.000Z",
      [assistantLine("papaya in the continuation"), assistantLine("bye")],
      "2026-02-13T09-30-00",
    );
    writeCodexRollout("019c56c0-d4d8-7b22-9e3c-200664d68bbb", "2026-02-13T08:00:00.000Z", [
      {
        type: "response_item",
        payload: { type: "function_call_output", output: "papaya from a tool" },
      },
    ]);

    const result = await getAllRecentSessions({
      provider: "codex",
      searchQuery: "papaya",
      searchContent: true,
    });
    expect(
      result.sessions
        .map((s) => [s.sessionId, s.searchMatch] as const)
        .sort((a, b) => a[0].localeCompare(b[0])),
    ).toEqual([
      [first, { field: "content", snippet: "papaya in the first segment" }],
      [second, { field: "content", snippet: "papaya in the continuation" }],
    ]);
  });

  it("content-searches pinned sessions outside the page", async () => {
    writeClaude([
      {
        sessionId: "newest",
        modified: "2026-02-13T12:00:00.000Z",
        transcript: [user("guava")],
      },
      {
        sessionId: "pinned",
        modified: "2026-02-13T10:00:00.000Z",
        transcript: [assistant("guava again")],
      },
      {
        sessionId: "pinned-miss",
        modified: "2026-02-13T09:00:00.000Z",
        transcript: [user("nothing")],
      },
    ]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "guava",
      searchContent: true,
      limit: 1,
      pinnedSessionKeys: new Set(["claude:pinned", "claude:pinned-miss"]),
    });
    expect(result.sessions.map((s) => s.sessionId)).toEqual(["newest"]);
    expect(result.pinnedSessions).toEqual([
      expect.objectContaining({
        sessionId: "pinned",
        searchMatch: { field: "content", snippet: "guava again" },
      }),
    ]);
  });

  it("applies sessionFilter (e.g. a created date range) before content search", async () => {
    writeClaude([
      {
        sessionId: "old-created",
        created: "2026-01-01T00:00:00.000Z",
        modified: "2026-02-13T12:00:00.000Z",
        transcript: [user("lime")],
      },
      {
        sessionId: "new-created",
        created: "2026-02-13T00:00:00.000Z",
        modified: "2026-02-13T11:00:00.000Z",
        transcript: [user("lime")],
      },
    ]);

    const result = await getAllRecentSessions({
      provider: "claude",
      searchQuery: "lime",
      searchContent: true,
      sessionFilter: (s) => s.created >= "2026-02-01",
    });
    expect(result.sessions.map((s) => s.sessionId)).toEqual(["new-created"]);
  });
});

describe("claudeAbandonedBranchUuids", () => {
  const entry = (
    type: "user" | "assistant" | "attachment",
    uuid: string,
    parentUuid: string | null,
    content: unknown = type === "user" ? "prompt" : [{ type: "text", text: "a" }],
  ) => JSON.stringify({ type, uuid, parentUuid, message: { role: type, content } });

  it("drops turns abandoned by an edit and keeps the new branch", () => {
    const lines = [
      entry("user", "u1", null, "ONE"),
      entry("assistant", "a1", "u1"),
      entry("attachment", "x1", "a1"),
      entry("user", "u2", "x1", "TWO"),
      entry("assistant", "a2", "u2"),
      entry("user", "u3", "a2", "THREE"),
      entry("user", "u2b", "a1", "EDITED"),
      entry("assistant", "a2b", "u2b"),
    ];
    expect(claudeAbandonedBranchUuids(lines)).toEqual(new Set(["u2", "a2", "u3"]));
  });

  it("keeps parallel tool call siblings", () => {
    const lines = [
      entry("user", "u1", null, "go"),
      entry("assistant", "t1", "u1", [{ type: "tool_use", id: "1", name: "Read", input: {} }]),
      entry("assistant", "t2", "u1", [{ type: "tool_use", id: "2", name: "Read", input: {} }]),
      entry("user", "r1", "t1", [{ type: "tool_result", tool_use_id: "1", content: "x" }]),
      entry("user", "r2", "t2", [{ type: "tool_result", tool_use_id: "2", content: "y" }]),
      entry("assistant", "a1", "r2"),
    ];
    expect(claudeAbandonedBranchUuids(lines)).toBeNull();
  });

  it("does not filter when the chain to the latest entry is broken", () => {
    const lines = [
      entry("user", "u1", null, "ONE"),
      entry("assistant", "a1", "u1"),
      entry("user", "u2", "missing", "TWO"),
    ];
    expect(claudeAbandonedBranchUuids(lines)).toBeNull();
  });
});
