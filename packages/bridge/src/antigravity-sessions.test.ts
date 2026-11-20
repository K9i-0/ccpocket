import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { AcpTransport } from "./antigravity-process.js";
import {
  antigravityRecentSessions,
  fetchAntigravityCatalog,
  listAntigravitySessions,
  normalizeAntigravityCwd,
  readAntigravityTranscriptFile,
} from "./antigravity-sessions.js";
import { AntigravityStore } from "./antigravity-store.js";

type Json = Record<string, unknown>;

class ListingTransport extends AcpTransport {
  readonly written: Json[] = [];
  stopped = false;
  constructor(private readonly pages: Json[]) {
    super();
  }
  start(): void {}
  stop(): void {
    this.stopped = true;
  }
  write(message: Json): void {
    this.written.push(message);
    const result =
      message.method === "session/list" ? (this.pages.shift() ?? {}) : {};
    setImmediate(() =>
      this.emit("message", { jsonrpc: "2.0", id: message.id, result }),
    );
  }
}

describe("listAntigravitySessions", () => {
  it("follows cursors, sends no prompt and stops the helper process", async () => {
    const transport = new ListingTransport([
      {
        sessions: [
          { sessionId: "a", cwd: "/p", title: " First ", updatedAt: "2026-11-01T00:00:00Z" },
          { sessionId: "", cwd: "/p" },
        ],
        nextCursor: "next",
      },
      { sessions: [{ sessionId: "b", cwd: "/q" }] },
    ]);
    const entries = await listAntigravitySessions({
      config: { bin: "agy", apiKey: "k", requireApiKey: true },
      createTransport: () => transport,
    });

    expect(entries).toEqual([
      { sessionId: "a", projectPath: "/p", title: "First", updatedAt: "2026-11-01T00:00:00Z" },
      { sessionId: "b", projectPath: "/q" },
    ]);
    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "authenticate",
      "session/list",
      "session/list",
    ]);
    expect(transport.written[3].params).toEqual({ cursor: "next" });
    expect(transport.stopped).toBe(true);
  });

  it("leaves the login profile unauthenticated by the Bridge", async () => {
    const transport = new ListingTransport([{ sessions: [] }]);
    await listAntigravitySessions({
      config: { bin: "agy", requireApiKey: false },
      createTransport: () => transport,
    });
    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "session/list",
    ]);
  });

  it("normalizes Windows file-URI pathname cwds returned by agy acp", async () => {
    const transport = new ListingTransport([
      {
        sessions: [
          {
            sessionId: "win-utf8",
            cwd: "/D:/%E9%A1%B9%E7%9B%AE/%E8%BF%9C%E7%A8%8B%E6%8E%A7%E5%88%B6",
            title: "UTF-8 Windows cwd",
          },
          {
            sessionId: "win-ascii",
            cwd: "/C:/Projects/my%20app/",
          },
          {
            sessionId: "win-file-uri",
            cwd: "file:///D:/%E9%A1%B9%E7%9B%AE/demo/",
          },
        ],
      },
    ]);
    const entries = await listAntigravitySessions({
      config: { bin: "agy", requireApiKey: false },
      createTransport: () => transport,
      platform: "win32",
    });

    expect(entries).toEqual([
      {
        sessionId: "win-utf8",
        projectPath: "D:\\项目\\远程控制",
        title: "UTF-8 Windows cwd",
      },
      {
        sessionId: "win-ascii",
        projectPath: "C:\\Projects\\my app",
      },
      {
        sessionId: "win-file-uri",
        projectPath: "D:\\项目\\demo",
      },
    ]);
  });
});

describe("normalizeAntigravityCwd", () => {
  it("decodes Windows file-URI pathnames and preserves literal percent signs in native paths", () => {
    expect(
      normalizeAntigravityCwd("/D:/%E9%A1%B9%E7%9B%AE/demo", "win32"),
    ).toBe("D:\\项目\\demo");
    expect(normalizeAntigravityCwd("/D:/", "win32")).toBe("D:\\");
    expect(
      normalizeAntigravityCwd("/D:/foo#1/bar%20baz", "win32"),
    ).toBe("D:\\foo#1\\bar baz");
    expect(
      normalizeAntigravityCwd("/D:/foo/100%_done", "win32"),
    ).toBe("D:\\foo\\100%_done");
    expect(
      normalizeAntigravityCwd("D:\\Projects\\100%20_literal", "win32"),
    ).toBe("D:\\Projects\\100%20_literal");
  });

  it("leaves POSIX paths unchanged on macOS and Linux", () => {
    expect(normalizeAntigravityCwd("/Users/alice/project", "darwin")).toBe(
      "/Users/alice/project",
    );
    expect(
      normalizeAntigravityCwd("/Users/alice/100%20done", "linux"),
    ).toBe("/Users/alice/100%20done");
    expect(
      normalizeAntigravityCwd("file:///Users/alice/my%20app", "darwin"),
    ).toBe("/Users/alice/my app");
  });
});

describe("antigravityRecentSessions", () => {
  const entries = [
    { sessionId: "old", projectPath: "/p", title: "Fix login", updatedAt: "2026-11-01T00:00:00Z" },
    { sessionId: "new", projectPath: "/q", title: "Add tests", updatedAt: "2026-11-02T00:00:00Z" },
    { sessionId: "gone", projectPath: "/p", title: "Archived", updatedAt: "2026-11-03T00:00:00Z" },
  ];

  it("sorts newest first and drops archived sessions", () => {
    const rows = antigravityRecentSessions(entries, {
      archivedSessionIds: new Set(["gone"]),
    });
    expect(rows.map((row) => row.sessionId)).toEqual(["new", "old"]);
    expect(rows[0]).toMatchObject({
      provider: "antigravity",
      name: "Add tests",
      projectPath: "/q",
      modified: "2026-11-02T00:00:00Z",
    });
  });

  it("filters by project and by search text", () => {
    expect(
      antigravityRecentSessions(entries, { projectPath: "/p" }).map((r) => r.sessionId),
    ).toEqual(["gone", "old"]);
    expect(
      antigravityRecentSessions(entries, { searchQuery: "LOGIN" }).map((r) => r.sessionId),
    ).toEqual(["old"]);
  });
});

describe("fetchAntigravityCatalog", () => {
  class CatalogTransport extends AcpTransport {
    readonly written: Json[] = [];
    cwd = "";
    start(cwd: string): void {
      this.cwd = cwd;
    }
    stop(): void {}
    write(message: Json): void {
      this.written.push(message);
      const result =
        message.method === "initialize"
          ? { agentInfo: { version: "1.5.12" } }
          : message.method === "session/new"
            ? {
                sessionId: "tmp",
                models: {
                  currentModelId: "gemini-3.8-flash-high",
                  availableModels: [
                    { modelId: "gemini-3.8-flash-high", name: "Flash (High)" },
                    { modelId: "gemini-3.8-flash-low", name: "Flash (Low)" },
                  ],
                },
                modes: {
                  currentModeId: "default",
                  availableModes: [{ id: "default" }, { id: "auto" }],
                },
                configOptions: [
                  {
                    id: "model",
                    currentValue: "gemini-3.8-flash",
                    options: [{ value: "gemini-3.8-flash", name: "Flash" }],
                  },
                  { id: "thought_level", currentValue: "high", options: [] },
                ],
                _meta: { antigravity: { tier: { name: "Google AI Ultra" } } },
              }
            : {};
      setImmediate(() =>
        this.emit("message", { jsonrpc: "2.0", id: message.id, result }),
      );
    }
  }

  it("opens and closes an empty session and never sends a prompt", async () => {
    const transport = new CatalogTransport();
    const catalog = await fetchAntigravityCatalog({
      config: { bin: "agy", requireApiKey: false },
      createTransport: () => transport,
      cwd: "/tmp/catalog",
    });
    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "session/new",
      "session/close",
    ]);
    expect(transport.cwd).toBe("/tmp/catalog");
    expect(catalog).toEqual({
      model: "gemini-3.8-flash-high",
      models: [
        { id: "gemini-3.8-flash-high", name: "Flash (High)" },
        { id: "gemini-3.8-flash-low", name: "Flash (Low)" },
      ],
      baseModel: "gemini-3.8-flash",
      modelOptions: [
        { id: "gemini-3.8-flash", name: "Flash", thoughtLevels: ["low", "high"] },
      ],
      thoughtLevel: "high",
      permissionModes: ["default", "auto", "bypassPermissions"],
      authMode: "login",
      tier: { name: "Google AI Ultra" },
      agentVersion: "1.5.12",
    });
  });

  it("refuses the login profile when an API key is required", async () => {
    await expect(
      fetchAntigravityCatalog({ config: { bin: "agy", requireApiKey: true } }),
    ).rejects.toThrow("no API key");
  });
});

describe("antigravityRecentSessions names", () => {
  it("prefers the name given in ccpocket and searches by it", () => {
    const rows = antigravityRecentSessions(
      [{ sessionId: "a", projectPath: "/p", title: "agy title" }],
      { names: new Map([["a", "Mine"]]), searchQuery: "mine" },
    );
    expect(rows).toMatchObject([
      {
        sessionId: "a",
        name: "Mine",
        summary: "agy title",
        searchMatch: { field: "name" },
      },
    ]);
  });

  it("populates model/permissionMode from records, enforces namedOnly, and sets searchMatch fields", () => {
    const entries = [
      { sessionId: "a", projectPath: "/work/alpha", title: "Alpha summary", updatedAt: "2026-11-02T00:00:00Z" },
      { sessionId: "b", projectPath: "/work/beta", title: "Beta summary", updatedAt: "2026-11-01T00:00:00Z" },
    ];
    const records = new Map([
      ["a", { name: "Custom A", model: "gemini-3.8-flash-high", permissionMode: "plan" as const }],
      ["b", { model: "gemini-3.1-pro-low", permissionMode: "auto" as const }],
    ]);

    const named = antigravityRecentSessions(entries, { records, namedOnly: true });
    expect(named).toHaveLength(1);
    expect(named[0]).toMatchObject({
      sessionId: "a",
      name: "Custom A",
      model: "gemini-3.8-flash-high",
      permissionMode: "plan",
    });

    const summaryMatch = antigravityRecentSessions(entries, {
      records,
      searchQuery: "beta summary",
    });
    expect(summaryMatch).toMatchObject([
      { sessionId: "b", model: "gemini-3.1-pro-low", permissionMode: "auto", searchMatch: { field: "summary" } },
    ]);

    const projectMatch = antigravityRecentSessions(entries, {
      records,
      searchQuery: "/work/alpha",
    });
    expect(projectMatch).toMatchObject([
      { sessionId: "a", searchMatch: { field: "project" } },
    ]);
  });
});

describe("AntigravityStore", () => {
  it("persists permissionMode, modeBeforePlan, and compactions across reloads", async () => {
    const dir = mkdtempSync(join(tmpdir(), "ccpocket-agy-store-"));
    try {
      const store = new AntigravityStore(dir);
      await store.setPermissionMode("s1", "acceptEdits");
      await store.setPermissionMode("s1", "plan");
      await store.addCompaction("s1", {
        afterUserTurns: 3,
        id: "cmp-1",
        timestamp: "2026-11-20T00:00:00Z",
        trigger: "manual",
        preTokens: 40_000,
        postTokens: 12_000,
        summary: "Compact summary",
      });
      // Duplicate id is ignored
      await store.addCompaction("s1", {
        afterUserTurns: 3,
        id: "cmp-1",
        timestamp: "2026-11-20T00:00:00Z",
      });

      const reloaded = new AntigravityStore(dir);
      await reloaded.init();
      expect(reloaded.get("s1")).toMatchObject({
        permissionMode: "plan",
        modeBeforePlan: "acceptEdits",
        compactions: [
          {
            afterUserTurns: 3,
            id: "cmp-1",
            trigger: "manual",
            preTokens: 40_000,
            postTokens: 12_000,
            summary: "Compact summary",
          },
        ],
      });
      expect(reloaded.records().get("s1")?.permissionMode).toBe("plan");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("readAntigravityTranscriptFile", () => {
  it("parses transcript_full.jsonl and falls back to transcript.jsonl", async () => {
    const profileDir = mkdtempSync(join(tmpdir(), "ccpocket-agy-transcript-"));
    try {
      const logsDir = join(profileDir, "brain", "conv-1", ".system_generated", "logs");
      mkdirSync(logsDir, { recursive: true });
      const lines = [
        JSON.stringify({
          step_index: 1,
          type: "USER_INPUT",
          content: "Hello agent",
          created_at: "2026-11-20T01:00:00Z",
        }),
        JSON.stringify({
          step_index: 2,
          type: "PLANNER_RESPONSE",
          thinking: "Let me check",
          content: "Done!",
          tool_calls: [{ id: "tc1", name: "read_file", arguments: { Path: "a.ts" } }],
          created_at: "2026-11-20T01:00:05Z",
        }),
        JSON.stringify({
          step_index: 3,
          type: "CHECKPOINT",
          content: "Compacted history",
          created_at: "2026-11-20T01:01:00Z",
        }),
      ];
      writeFileSync(join(logsDir, "transcript_full.jsonl"), lines.join("\n") + "\n");

      const full = await readAntigravityTranscriptFile("conv-1", { profileDir });
      expect(full).toHaveLength(3);
      expect(full[0]).toMatchObject({ role: "user", content: "Hello agent" });
      expect(full[1]).toMatchObject({
        role: "assistant",
        content: [
          { type: "thinking", thinking: "Let me check" },
          { type: "text", text: "Done!" },
          { type: "tool_use", id: "tc1", name: "read_file", input: { Path: "a.ts" } },
        ],
      });
      expect(full[2]).toMatchObject({
        role: "compaction",
        uuid: "antigravity:log:3",
        compaction: { trigger: "auto", summary: "Compacted history" },
      });

      // Fallback to transcript.jsonl when transcript_full.jsonl is absent
      const logsDir2 = join(profileDir, "brain", "conv-2", ".system_generated", "logs");
      mkdirSync(logsDir2, { recursive: true });
      writeFileSync(
        join(logsDir2, "transcript.jsonl"),
        JSON.stringify({ step_index: 1, type: "USER_INPUT", content: "Compact log" }) + "\n",
      );
      const compact = await readAntigravityTranscriptFile("conv-2", { profileDir });
      expect(compact).toHaveLength(1);
      expect(compact[0]).toMatchObject({ role: "user", content: "Compact log" });
    } finally {
      rmSync(profileDir, { recursive: true, force: true });
    }
  });
});

describe("antigravityRecentSessions worktree normalization", () => {
  it("normalizes worktree path and populates gitBranch", () => {
    const entries = [
      {
        sessionId: "s1",
        projectPath: "/project/.claude/worktrees/feat1",
        updatedAt: "2026-11-20T00:00:00Z",
      },
    ];
    // In unit test, normalizeWorktreePath will just strip `.claude/worktrees/feat1` 
    // to `/project`. Since `/project/.claude/worktrees/feat1` doesn't exist on disk, 
    // resumeCwd might be omitted unless mocked, but projectPath should be normalized.
    
    const worktrees = new Map([
      ["s1", { projectPath: "/project", worktreePath: "/project/.claude/worktrees/feat1", worktreeBranch: "feat-branch" }]
    ]);

    const result = antigravityRecentSessions(entries, { worktrees });
    expect(result).toHaveLength(1);
    expect(result[0].projectPath).toBe("/project");
    expect(result[0].gitBranch).toBe("feat-branch");
  });
});
