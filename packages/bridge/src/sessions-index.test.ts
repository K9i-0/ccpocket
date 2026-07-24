import { describe, it, expect, beforeEach, afterEach } from "vitest";
import {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
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
  getCodexSessionIndexMetadata,
  getCodexSessionHistory,
  extractMessageImages,
  codexThreadToSessionHistory,
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

  it("skips jsonl-only Claude directories when namedOnly=true", async () => {
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
