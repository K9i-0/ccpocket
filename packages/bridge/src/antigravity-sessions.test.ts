import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { ACP_CLIENT_INFO, AcpTransport } from "./antigravity-process.js";
import {
  antigravityRecentSessions,
  fetchAntigravityCatalog,
  listAntigravitySessions,
  normalizeAntigravityCwd,
  readAntigravityTranscriptFile,
  resolveAntigravityProfileDir,
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
          { type: "tool_use", id: "tc1", name: "Read", input: { file_path: "a.ts" } },
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

describe("readAntigravityTranscriptFile with entries as agy writes them", () => {
  it("shows the user's words and names tools as a live session does", async () => {
    const profileDir = mkdtempSync(join(tmpdir(), "ccpocket-agy-transcript-"));
    try {
      const logsDir = join(profileDir, "brain", "conv-1", ".system_generated", "logs");
      mkdirSync(logsDir, { recursive: true });
      const lines = [
        {
          step_index: 0,
          type: "USER_INPUT",
          content:
            "<USER_REQUEST>\nmake a.txt\n</USER_REQUEST>\n<ADDITIONAL_METADATA>\nThe current local time is: 2026-11-24T18:19:52+09:00.\n</ADDITIONAL_METADATA>",
        },
        {
          step_index: 1,
          type: "PLANNER_RESPONSE",
          tool_calls: [
            // Plain values.
            { name: "run_command", args: { CommandLine: "ls -la", toolSummary: "List files" } },
            { name: "write_file", args: { Content: "alpha", Path: "/workspace/a.txt" } },
            // Every value kept as a JSON string.
            { name: "run_command", args: { CommandLine: '"cat a.txt"', WaitMsBeforeAsync: "5000" } },
            { name: "read_file", args: { Path: '"/workspace/a.txt"' } },
            {
              name: "call_mcp_tool",
              args: { ServerName: "dart-mcp", ToolName: "dtd", Arguments: { command: "connect" } },
            },
            { name: "swarm", args: { action: "status" } },
            // Nothing closes these in a transcript: no open question, no image "generating".
            { name: "ask_question", args: { questions: [{ question: "Color?", options: ["Red"] }] } },
            {
              name: "invoke_subagent",
              args: { TypeName: "image-generator", Prompt: "Red circle" },
            },
          ],
        },
      ];
      writeFileSync(
        join(logsDir, "transcript_full.jsonl"),
        lines.map((line) => JSON.stringify(line)).join("\n") + "\n",
      );

      const messages = await readAntigravityTranscriptFile("conv-1", {
        profileDir,
        cwd: "/workspace",
      });
      expect(messages[0]).toMatchObject({ role: "user", content: "make a.txt" });
      const uses = (messages[1]?.content as Array<Record<string, unknown>>).map(
        ({ name, input }) => ({ name, input }),
      );
      expect(uses).toEqual([
        { name: "Bash", input: { command: "ls -la", description: "List files" } },
        {
          name: "FileChange",
          input: { changes: [{ path: "a.txt", kind: "update", diff: "" }] },
        },
        { name: "Bash", input: { command: "cat a.txt" } },
        { name: "Read", input: { file_path: "a.txt" } },
        { name: "mcp__dart-mcp__dtd", input: { command: "connect" } },
        { name: "swarm", input: { action: "status" } },
        {
          name: "ask_question",
          input: { questions: [{ question: "Color?", options: ["Red"] }] },
        },
        {
          name: "ImageGeneration",
          input: { status: "completed", revisedPrompt: "Red circle" },
        },
      ]);
    } finally {
      rmSync(profileDir, { recursive: true, force: true });
    }
  });
});

describe("readAntigravityTranscriptFile step checklist", () => {
  it("reads update_steps as a todo list", async () => {
    const profileDir = mkdtempSync(join(tmpdir(), "ccpocket-agy-transcript-"));
    try {
      const logsDir = join(profileDir, "brain", "conv-1", ".system_generated", "logs");
      mkdirSync(logsDir, { recursive: true });
      // The transcript keeps arguments under `args`, the list as a JSON string.
      const line = JSON.stringify({
        step_index: 7,
        type: "PLANNER_RESPONSE",
        tool_calls: [
          {
            name: "update_steps",
            args: {
              steps: JSON.stringify([
                { status: "done", title: "Create a.txt" },
                { status: "in_progress", title: "Create b.txt" },
              ]),
            },
          },
        ],
      });
      writeFileSync(join(logsDir, "transcript_full.jsonl"), line + "\n");

      const messages = await readAntigravityTranscriptFile("conv-1", { profileDir });
      expect(messages).toHaveLength(1);
      expect(messages[0]?.content).toMatchObject([
        {
          type: "tool_use",
          name: "TodoWrite",
          input: {
            todos: [
              { content: "Create a.txt", status: "completed", activeForm: "" },
              { content: "Create b.txt", status: "in_progress", activeForm: "" },
            ],
          },
        },
      ]);
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

/**
 * In-memory stand-in for the `agy acp` process. `respond` decides what the
 * fake agent sends back for each request; nothing is spawned.
 */
class ScriptedTransport extends AcpTransport {
  readonly written: Json[] = [];
  readonly cwds: string[] = [];
  stopCount = 0;
  constructor(
    private readonly respond: (message: Json, transport: ScriptedTransport) => void = (
      message,
      transport,
    ) => transport.reply(message, {}),
  ) {
    super();
  }
  start(cwd: string): void {
    this.cwds.push(cwd);
  }
  stop(): void {
    this.stopCount++;
  }
  write(message: Json): void {
    this.written.push(message);
    if (typeof message.method === "string") this.respond(message, this);
  }
  send(message: Json): void {
    setImmediate(() => this.emit("message", message));
  }
  reply(request: Json, result: Json): void {
    this.send({ jsonrpc: "2.0", id: request.id, result });
  }
  requests(method: string): Json[] {
    return this.written.filter((m) => m.method === method);
  }
}

const LOGIN_CONFIG = { bin: "agy", requireApiKey: false };

/** Transport that answers `session/list` with the given pages in order. */
function listing(...pages: Json[]): ScriptedTransport {
  return new ScriptedTransport((message, transport) =>
    transport.reply(
      message,
      message.method === "session/list" ? (pages.shift() ?? {}) : {},
    ),
  );
}

describe("short-lived ACP requests", () => {
  it("sends well-formed JSON-RPC requests with increasing ids", async () => {
    const transport = listing({ sessions: [] });
    await listAntigravitySessions({
      config: { bin: "agy", apiKey: "secret", requireApiKey: true },
      createTransport: () => transport,
    });

    expect(transport.written).toEqual([
      {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: 1,
          clientInfo: ACP_CLIENT_INFO,
          clientCapabilities: {
            fs: { readTextFile: false, writeTextFile: false },
            terminal: false,
          },
        },
      },
      {
        jsonrpc: "2.0",
        id: 2,
        method: "authenticate",
        params: { methodId: "gemini-api-key", _meta: { apiKey: "secret" } },
      },
      { jsonrpc: "2.0", id: 3, method: "session/list", params: {} },
    ]);
  });

  it("starts the helper in the given directory, or the current one by default", async () => {
    const explicit = listing();
    await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => explicit,
      cwd: "/tmp/somewhere",
    });
    expect(explicit.cwds).toEqual(["/tmp/somewhere"]);

    const fallback = listing();
    await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => fallback,
    });
    expect(fallback.cwds).toEqual([process.cwd()]);
  });

  it("passes the configuration to the transport factory", async () => {
    const config = { bin: "custom-agy", requireApiKey: false };
    const seen: unknown[] = [];
    await listAntigravitySessions({
      config,
      createTransport: (c) => {
        seen.push(c);
        return listing();
      },
    });
    expect(seen).toEqual([config]);
  });

  it("rejects with the agent's error message and stops the helper", async () => {
    const transport = new ScriptedTransport((message, t) => {
      if (message.method === "session/list") {
        t.send({ jsonrpc: "2.0", id: message.id, error: { code: -1, message: "list broke" } });
      } else {
        t.reply(message, {});
      }
    });
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).rejects.toThrow("list broke");
    expect(transport.stopCount).toBe(1);
  });

  it("rejects with a generic message when the error carries none", async () => {
    const transport = new ScriptedTransport((message, t) =>
      t.send({ jsonrpc: "2.0", id: message.id, error: { code: -1 } }),
    );
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).rejects.toThrow("request failed");
  });

  it("treats a response whose error is not an object as a result", async () => {
    const transport = new ScriptedTransport((message, t) =>
      t.send({
        jsonrpc: "2.0",
        id: message.id,
        error: ["not an error object"],
        result: { sessions: [{ sessionId: "a", cwd: "/p" }] },
      }),
    );
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).resolves.toEqual([{ sessionId: "a", projectPath: "/p" }]);
  });

  it("treats a missing or malformed result as empty", async () => {
    const transport = new ScriptedTransport((message, t) =>
      t.send({ jsonrpc: "2.0", id: message.id, result: "nope" }),
    );
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).resolves.toEqual([]);
  });

  it("refuses requests from the agent and ignores its notifications", async () => {
    const transport = new ScriptedTransport((message, t) => {
      if (message.method === "session/list") {
        // The agent asks the client for something, reusing the pending id.
        t.send({
          jsonrpc: "2.0",
          id: message.id,
          method: "fs/read_text_file",
          params: { path: "/etc/passwd" },
        });
        t.send({ jsonrpc: "2.0", method: "session/update", params: {} });
        // Responses nobody is waiting for.
        t.send({ jsonrpc: "2.0", id: 999, result: {} });
        t.send({ jsonrpc: "2.0", id: "1", result: {} });
        t.reply(message, { sessions: [{ sessionId: "a", cwd: "/p" }] });
      } else {
        t.reply(message, {});
      }
    });
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });

    expect(entries).toEqual([{ sessionId: "a", projectPath: "/p" }]);
    expect(transport.written.filter((m) => m.method === undefined)).toEqual([
      { jsonrpc: "2.0", id: 2, error: { code: -32601, message: "Method not found" } },
    ]);
  });

  it("rejects when the helper reports an error", async () => {
    const transport = new ScriptedTransport((message, t) => {
      if (message.method === "session/list") {
        setImmediate(() => t.emit("error", new Error("spawn agy ENOENT")));
      } else {
        t.reply(message, {});
      }
    });
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).rejects.toThrow("spawn agy ENOENT");
    expect(transport.stopCount).toBe(1);
  });

  it("rejects when the helper exits before answering", async () => {
    const transport = new ScriptedTransport((_message, t) => {
      setImmediate(() => t.emit("exit", 1));
    });
    await expect(
      listAntigravitySessions({ config: LOGIN_CONFIG, createTransport: () => transport }),
    ).rejects.toThrow("Antigravity exited");
    expect(transport.stopCount).toBe(1);
  });

  it("rejects and stops the helper when it does not answer in time", async () => {
    const transport = new ScriptedTransport(() => {});
    await expect(
      listAntigravitySessions({
        config: LOGIN_CONFIG,
        createTransport: () => transport,
        timeoutMs: 20,
      }),
    ).rejects.toThrow("Antigravity did not answer in time");
    expect(transport.stopCount).toBe(1);
  });

  it("wraps a non-Error start failure", async () => {
    class FailingStart extends ScriptedTransport {
      override start(): void {
        throw "cannot start";
      }
    }
    const transport = new FailingStart();
    const failure = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    }).catch((err: unknown) => err);
    expect(failure).toBeInstanceOf(Error);
    expect((failure as Error).message).toBe("cannot start");
    expect(transport.stopCount).toBe(1);
  });

  it("settles once: a later exit neither stops the helper again nor changes the result", async () => {
    const transport = listing({ sessions: [{ sessionId: "a", cwd: "/p" }] });
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    transport.emit("exit", 0);
    transport.emit("error", new Error("late"));

    expect(entries).toEqual([{ sessionId: "a", projectPath: "/p" }]);
    expect(transport.stopCount).toBe(1);
  });
});

describe("listAntigravitySessions edge cases", () => {
  it("returns nothing and starts no helper when an API key is required but missing", async () => {
    let created = 0;
    const entries = await listAntigravitySessions({
      config: { bin: "agy", requireApiKey: true },
      createTransport: () => {
        created++;
        return listing({ sessions: [{ sessionId: "a", cwd: "/p" }] });
      },
    });
    expect(entries).toEqual([]);
    expect(created).toBe(0);
  });

  it("skips malformed session entries and optional fields of the wrong type", async () => {
    const transport = listing({
      sessions: [
        null,
        "session",
        ["a"],
        { sessionId: 5, cwd: "/p" },
        { sessionId: "no-cwd" },
        { sessionId: "bad-cwd", cwd: 7 },
        { sessionId: "blank-title", cwd: "/p", title: "   ", updatedAt: 1730000000 },
        { sessionId: "typed", cwd: "/q", title: 9 },
      ],
    });
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(entries).toEqual([
      { sessionId: "blank-title", projectPath: "/p" },
      { sessionId: "typed", projectPath: "/q" },
    ]);
  });

  it("treats a page without a session array as empty", async () => {
    const transport = listing({ sessions: "none", nextCursor: "more" }, {});
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(entries).toEqual([]);
    expect(transport.requests("session/list")).toHaveLength(2);
  });

  it.each([
    ["a number", 5],
    ["an empty string", ""],
    ["null", null],
  ])("stops paging when the next cursor is %s", async (_label, nextCursor) => {
    const transport = listing(
      { sessions: [{ sessionId: "a", cwd: "/p" }], nextCursor },
      { sessions: [{ sessionId: "b", cwd: "/q" }] },
    );
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(entries).toEqual([{ sessionId: "a", projectPath: "/p" }]);
    expect(transport.requests("session/list")).toHaveLength(1);
  });

  it("stops after 20 pages even if the agent keeps returning a cursor", async () => {
    let page = 0;
    const transport = new ScriptedTransport((message, t) => {
      if (message.method !== "session/list") return t.reply(message, {});
      page++;
      t.reply(message, {
        sessions: [{ sessionId: `s${page}`, cwd: "/p" }],
        nextCursor: `c${page}`,
      });
    });
    const entries = await listAntigravitySessions({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(entries).toHaveLength(20);
    expect(transport.requests("session/list")).toHaveLength(20);
    expect(transport.requests("session/list").at(-1)?.params).toEqual({ cursor: "c19" });
  });
});

describe("normalizeAntigravityCwd edge cases", () => {
  it("returns an empty path for an empty cwd", () => {
    expect(normalizeAntigravityCwd("", "win32")).toBe("");
    expect(normalizeAntigravityCwd("", "darwin")).toBe("");
  });

  it("only rewrites drive-letter pathnames on Windows and at the start of the path", () => {
    expect(normalizeAntigravityCwd("/D:/foo%20bar", "darwin")).toBe("/D:/foo%20bar");
    expect(normalizeAntigravityCwd("/D:/foo%20bar", "linux")).toBe("/D:/foo%20bar");
    expect(normalizeAntigravityCwd("nested/D:/foo%20bar", "win32")).toBe(
      "nested/D:/foo%20bar",
    );
    expect(normalizeAntigravityCwd("/D:\\foo%20bar", "win32")).toBe("D:\\foo bar");
  });

  it("keeps a file URI it cannot convert", () => {
    expect(normalizeAntigravityCwd("file://remote-host/share", "darwin")).toBe(
      "file://remote-host/share",
    );
  });
});

describe("fetchAntigravityCatalog edge cases", () => {
  function catalogTransport(session: Json, initialized: Json = {}): ScriptedTransport {
    return new ScriptedTransport((message, t) => {
      if (message.method === "initialize") return t.reply(message, initialized);
      if (message.method === "session/new") return t.reply(message, session);
      t.reply(message, {});
    });
  }

  it("asks for a session without MCP servers and closes exactly that session", async () => {
    const transport = catalogTransport({ sessionId: "tmp" });
    await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
      cwd: "/tmp/catalog",
    });
    expect(transport.requests("session/new")[0].params).toEqual({
      cwd: "/tmp/catalog",
      mcpServers: [],
    });
    expect(transport.requests("session/close")[0].params).toEqual({ sessionId: "tmp" });
    expect(transport.requests("session/prompt")).toEqual([]);
  });

  it("uses the temp directory when no cwd is given", async () => {
    const transport = catalogTransport({ sessionId: "tmp" });
    await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(transport.cwds).toEqual([tmpdir()]);
    expect(transport.requests("session/new")[0].params).toMatchObject({ cwd: tmpdir() });
  });

  it.each([
    ["missing", {}],
    ["not a string", { sessionId: 12 }],
    ["empty", { sessionId: "" }],
  ])("does not close a session whose id is %s", async (_label, session) => {
    const transport = catalogTransport(session);
    await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(transport.requests("session/close")).toEqual([]);
  });

  it("returns only the fixed fields for a session that reports nothing", async () => {
    const transport = catalogTransport({ sessionId: "tmp" });
    const catalog = await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(catalog).toEqual({
      models: [],
      modelOptions: [],
      permissionModes: ["bypassPermissions"],
      authMode: "login",
    });
  });

  it.each([
    ["an empty version", { agentInfo: { version: "" } }],
    ["a non-string version", { agentInfo: { version: 15 } }],
    ["agent info of the wrong type", { agentInfo: "1.5.12" }],
  ])("omits the agent version for %s", async (_label, initialized) => {
    const transport = catalogTransport({ sessionId: "tmp" }, initialized);
    const catalog = await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(catalog).not.toHaveProperty("agentVersion");
  });

  it("authenticates with the API key and reports API-key auth", async () => {
    const transport = catalogTransport({ sessionId: "tmp" });
    const catalog = await fetchAntigravityCatalog({
      config: { bin: "agy", apiKey: "secret", requireApiKey: true },
      createTransport: () => transport,
    });
    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "authenticate",
      "session/new",
      "session/close",
    ]);
    expect(catalog.authMode).toBe("api_key");
  });

  it("still returns the catalog when the session cannot be closed", async () => {
    const transport = new ScriptedTransport((message, t) => {
      if (message.method === "session/close") {
        return t.send({ jsonrpc: "2.0", id: message.id, error: { message: "unsupported" } });
      }
      t.reply(
        message,
        message.method === "session/new"
          ? { sessionId: "tmp", models: { currentModelId: "m1" } }
          : {},
      );
    });
    const catalog = await fetchAntigravityCatalog({
      config: LOGIN_CONFIG,
      createTransport: () => transport,
    });
    expect(catalog).toMatchObject({ model: "m1", authMode: "login" });
  });

  it("starts no helper when an API key is required but missing", async () => {
    let created = 0;
    await expect(
      fetchAntigravityCatalog({
        config: { bin: "agy", requireApiKey: true },
        createTransport: () => {
          created++;
          return catalogTransport({});
        },
      }),
    ).rejects.toThrow("CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY is set but no API key is configured");
    expect(created).toBe(0);
  });
});

describe("antigravityRecentSessions row details", () => {
  it("builds a plain row from an entry with nothing but an id and a path", () => {
    expect(antigravityRecentSessions([{ sessionId: "a", projectPath: "/p" }])).toEqual([
      {
        sessionId: "a",
        provider: "antigravity",
        firstPrompt: "",
        created: "1970-01-01T00:00:00.000Z",
        modified: "1970-01-01T00:00:00.000Z",
        gitBranch: "",
        projectPath: "/p",
        isSidechain: false,
      },
    ]);
  });

  it("uses the trimmed Antigravity title as the name and first prompt, without a summary", () => {
    const rows = antigravityRecentSessions([
      { sessionId: "a", projectPath: "/p", title: "  Padded title  ", updatedAt: "2026-11-02T00:00:00Z" },
    ]);
    expect(rows).toEqual([
      {
        sessionId: "a",
        provider: "antigravity",
        name: "Padded title",
        firstPrompt: "Padded title",
        created: "2026-11-02T00:00:00Z",
        modified: "2026-11-02T00:00:00Z",
        gitBranch: "",
        projectPath: "/p",
        isSidechain: false,
      },
    ]);
  });

  it("ignores a blank title", () => {
    const [row] = antigravityRecentSessions([
      { sessionId: "a", projectPath: "/p", title: "   " },
    ]);
    expect(row).not.toHaveProperty("name");
    expect(row.firstPrompt).toBe("");
  });

  it.each([
    ["the record name, trimmed", { records: new Map([["a", { name: "  Record  " }]]), names: new Map([["a", "Map"]]) }, "Record"],
    ["the names map when the record name is blank", { records: new Map([["a", { name: "   " }]]), names: new Map([["a", "  Map  "]]) }, "Map"],
    ["the names map when there is no record", { names: new Map([["a", "Map"]]) }, "Map"],
    ["the title when the names map has no entry", { names: new Map([["other", "Map"]]) }, "agy title"],
    ["the title when the stored name is blank", { names: new Map([["a", "   "]]) }, "agy title"],
  ])("names the session by %s", (_label, filter, expected) => {
    const [row] = antigravityRecentSessions(
      [{ sessionId: "a", projectPath: "/p", title: "agy title" }],
      filter,
    );
    expect(row.name).toBe(expected);
    expect(row.firstPrompt).toBe(expected);
  });

  it("adds the Antigravity title as summary only next to a different stored name", () => {
    const summaryOf = (title: string | undefined, name: string | undefined) =>
      antigravityRecentSessions(
        [{ sessionId: "a", projectPath: "/p", ...(title ? { title } : {}) }],
        name ? { names: new Map([["a", name]]) } : {},
      )[0];

    expect(summaryOf("agy title", "Mine").summary).toBe("agy title");
    expect(summaryOf(" Same ", "Same")).not.toHaveProperty("summary");
    expect(summaryOf("agy title", undefined)).not.toHaveProperty("summary");
    expect(summaryOf(undefined, "Mine")).not.toHaveProperty("summary");
    expect(summaryOf(undefined, undefined)).not.toHaveProperty("summary");
  });

  it("excludes blank-named sessions from namedOnly", () => {
    const rows = antigravityRecentSessions(
      [
        { sessionId: "a", projectPath: "/p", title: "agy title" },
        { sessionId: "b", projectPath: "/p", title: "other" },
      ],
      { namedOnly: true, names: new Map([["a", "  "], ["b", "Kept"]]) },
    );
    expect(rows.map((row) => row.sessionId)).toEqual(["b"]);
  });

  it("drops sessions that match the search nowhere and ignores a blank query", () => {
    const entries = [
      { sessionId: "a", projectPath: "/work/alpha", title: "Alpha" },
      { sessionId: "b", projectPath: "/work/beta", title: "Beta" },
    ];
    expect(antigravityRecentSessions(entries, { searchQuery: "gamma" })).toEqual([]);
    expect(
      antigravityRecentSessions(entries, { searchQuery: "  ALPHA  " }).map((r) => r.sessionId),
    ).toEqual(["a"]);

    const unfiltered = antigravityRecentSessions(entries, { searchQuery: "   " });
    expect(unfiltered).toHaveLength(2);
    expect(unfiltered[0]).not.toHaveProperty("searchMatch");
  });

  it("reports the first matching field: name, then title, then project", () => {
    const match = (searchQuery: string) =>
      antigravityRecentSessions(
        [{ sessionId: "a", projectPath: "/work/shared-project", title: "shared title" }],
        { names: new Map([["a", "shared name"]]), searchQuery },
      )[0]?.searchMatch;

    expect(match("shared")).toEqual({ field: "name" });
    expect(match("title")).toEqual({ field: "summary" });
    expect(match("project")).toEqual({ field: "project" });
  });
});

describe("antigravityRecentSessions worktrees on disk", () => {
  it("resumes in a worktree directory that still exists", () => {
    const root = mkdtempSync(join(tmpdir(), "ccpocket-agy-wt-"));
    try {
      const worktreePath = join(root, "proj-worktrees", "feat");
      mkdirSync(worktreePath, { recursive: true });
      const [row] = antigravityRecentSessions([
        { sessionId: "s1", projectPath: worktreePath },
      ]);
      expect(row).toMatchObject({
        projectPath: join(root, "proj"),
        resumeCwd: worktreePath,
        gitBranch: "",
      });
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("leaves out resumeCwd for a worktree that was removed", () => {
    const [row] = antigravityRecentSessions([
      { sessionId: "s1", projectPath: "/nonexistent-ccpocket/proj-worktrees/feat" },
    ]);
    expect(row.projectPath).toBe("/nonexistent-ccpocket/proj");
    expect(row).not.toHaveProperty("resumeCwd");
  });

  it("reports the mapped worktree branch even when the session was recorded in the main checkout", () => {
    const root = mkdtempSync(join(tmpdir(), "ccpocket-agy-main-"));
    try {
      const [row] = antigravityRecentSessions(
        [{ sessionId: "s1", projectPath: root }],
        {
          worktrees: new Map([
            ["s1", { projectPath: root, worktreePath: root, worktreeBranch: "feat" }],
          ]),
        },
      );
      expect(row.projectPath).toBe(root);
      expect(row.gitBranch).toBe("feat");
      expect(row).not.toHaveProperty("resumeCwd");
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });

  it("filters by the main project path of a worktree session", () => {
    const entries = [
      { sessionId: "s1", projectPath: "/nonexistent-ccpocket/proj-worktrees/feat" },
    ];
    expect(
      antigravityRecentSessions(entries, { projectPath: "/nonexistent-ccpocket/proj" }),
    ).toHaveLength(1);
    expect(
      antigravityRecentSessions(entries, {
        projectPath: "/nonexistent-ccpocket/proj-worktrees/feat",
      }),
    ).toEqual([]);
  });
});

describe("resolveAntigravityProfileDir", () => {
  it("uses the login profile without an API key and the dedicated one with it", () => {
    expect(resolveAntigravityProfileDir({ bin: "agy", requireApiKey: false })).toBe(
      join(homedir(), ".gemini", "antigravity-cli"),
    );
    expect(
      resolveAntigravityProfileDir({ bin: "agy", apiKey: "k", requireApiKey: true }),
    ).toBe(join(homedir(), ".gemini", "antigravity-cli-ccpocket-apikey"));
  });
});

describe("readAntigravityTranscriptFile parsing", () => {
  function withProfile<T>(run: (profileDir: string) => Promise<T>): Promise<T> {
    const profileDir = mkdtempSync(join(tmpdir(), "ccpocket-agy-transcript-"));
    return run(profileDir).finally(() =>
      rmSync(profileDir, { recursive: true, force: true }),
    );
  }

  function logsDirOf(profileDir: string, ...sessionPath: string[]): string {
    const dir = join(profileDir, "brain", ...sessionPath, ".system_generated", "logs");
    mkdirSync(dir, { recursive: true });
    return dir;
  }

  function writeTranscript(
    profileDir: string,
    sessionId: string,
    entries: unknown[],
    file = "transcript_full.jsonl",
  ): void {
    writeFileSync(
      join(logsDirOf(profileDir, sessionId), file),
      entries.map((entry) => (typeof entry === "string" ? entry : JSON.stringify(entry))).join("\n"),
    );
  }

  it("refuses session ids that are empty or contain path separators", () =>
    withProfile(async (profileDir) => {
      const entry = { type: "USER_INPUT", content: "secret" };
      writeTranscript(profileDir, "conv-1", [entry]);
      // Where an empty id would resolve to.
      writeFileSync(
        join(logsDirOf(profileDir), "transcript_full.jsonl"),
        JSON.stringify(entry),
      );

      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toHaveLength(1);
      expect(await readAntigravityTranscriptFile("", { profileDir })).toEqual([]);
      expect(await readAntigravityTranscriptFile("x/../conv-1", { profileDir })).toEqual([]);
      expect(await readAntigravityTranscriptFile("x\\..\\conv-1", { profileDir })).toEqual([]);
    }));

  it("returns nothing for an unknown session or an unreadable transcript", () =>
    withProfile(async (profileDir) => {
      expect(await readAntigravityTranscriptFile("missing", { profileDir })).toEqual([]);

      // A directory where the transcript file should be cannot be read.
      mkdirSync(join(logsDirOf(profileDir, "broken"), "transcript_full.jsonl"));
      expect(await readAntigravityTranscriptFile("broken", { profileDir })).toEqual([]);
    }));

  it("prefers the full transcript over the compact one", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [{ type: "USER_INPUT", content: "full" }]);
      writeTranscript(
        profileDir,
        "conv-1",
        [{ type: "USER_INPUT", content: "compact" }],
        "transcript.jsonl",
      );
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "user", content: "full" },
      ]);
    }));

  it("skips blank lines, invalid JSON, non-object lines and unknown entry types", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [
        "",
        "   ",
        "{not json",
        "null",
        "42",
        '"USER_INPUT"',
        { type: "TOOL_RESULT", content: "ignored" },
        { type: 7, content: "ignored" },
        { content: "no type" },
        `  ${JSON.stringify({ type: "USER_INPUT", content: "kept" })}  \r`,
      ]);
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "user", content: "kept" },
      ]);
    }));

  it("adds uuid and timestamp only when the entry carries valid ones", () =>
    withProfile(async (profileDir) => {
      const stamped = { step_index: 0, created_at: "2026-11-20T01:00:00Z" };
      const unstamped = { step_index: "4", created_at: 1763600000 };
      writeTranscript(profileDir, "conv-1", [
        { ...stamped, type: "USER_INPUT", content: "hi" },
        { ...stamped, type: "PLANNER_RESPONSE", content: "hello" },
        { ...stamped, type: "CHECKPOINT" },
        { ...unstamped, type: "USER_INPUT", content: "hi" },
        { ...unstamped, type: "PLANNER_RESPONSE", content: "hello" },
        { ...unstamped, type: "CHECKPOINT" },
      ]);
      const ids = { uuid: "antigravity:log:0", timestamp: "2026-11-20T01:00:00Z" };
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "user", ...ids, content: "hi" },
        { role: "assistant", ...ids, content: [{ type: "text", text: "hello" }] },
        { role: "compaction", ...ids, compaction: { trigger: "auto" }, content: "" },
        { role: "user", content: "hi" },
        { role: "assistant", content: [{ type: "text", text: "hello" }] },
        { role: "compaction", compaction: { trigger: "auto" }, content: "" },
      ]);
    }));

  it("skips user input without text and keeps the text as written", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [
        { type: "USER_INPUT" },
        { type: "USER_INPUT", content: 12 },
        { type: "USER_INPUT", content: "  \n " },
        { type: "USER_INPUT", content: "  indented\n" },
      ]);
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "user", content: "  indented\n" },
      ]);
    }));

  it("builds assistant blocks only from non-blank thinking, text and named tool calls", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [
        { type: "PLANNER_RESPONSE", thinking: "  ", content: " \n" },
        { type: "PLANNER_RESPONSE", thinking: 1, content: 2, tool_calls: 3 },
        { type: "PLANNER_RESPONSE", tool_calls: { name: "not-a-list" } },
        { type: "PLANNER_RESPONSE", tool_calls: [null, "call", ["x"], {}, { name: 7 }, { name: "" }] },
        { type: "PLANNER_RESPONSE", thinking: " hmm ", content: "   " },
        { type: "PLANNER_RESPONSE", thinking: "", content: " answer " },
      ]);
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "assistant", content: [{ type: "thinking", thinking: " hmm " }] },
        { role: "assistant", content: [{ type: "text", text: " answer " }] },
      ]);
    }));

  it("fills in tool call ids and inputs", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [
        { type: "USER_INPUT", content: "go" },
        {
          type: "PLANNER_RESPONSE",
          thinking: "plan",
          tool_calls: [
            { name: "no_id", arguments: { a: 1 }, input: { ignored: true } },
            { id: "", name: "empty_id", input: { b: 2 } },
            { id: 9, name: "numeric_id", arguments: ["not", "a", "record"], input: { c: 3 } },
            { id: "tc-4", name: "no_input", arguments: "text", input: [1] },
          ],
        },
      ]);
      const messages = await readAntigravityTranscriptFile("conv-1", { profileDir });
      expect(messages[1]).toEqual({
        role: "assistant",
        content: [
          { type: "thinking", thinking: "plan" },
          { type: "tool_use", id: "agy-call-1-1", name: "no_id", input: { a: 1 } },
          { type: "tool_use", id: "agy-call-1-2", name: "empty_id", input: { b: 2 } },
          { type: "tool_use", id: "agy-call-1-3", name: "numeric_id", input: { c: 3 } },
          { type: "tool_use", id: "tc-4", name: "no_input", input: {} },
        ],
      });
    }));

  it("trims checkpoint summaries and omits blank ones", () =>
    withProfile(async (profileDir) => {
      writeTranscript(profileDir, "conv-1", [
        { type: "CHECKPOINT", content: "  Summary of work \n" },
        { type: "CHECKPOINT", content: "   " },
        { type: "CHECKPOINT", content: 5 },
      ]);
      expect(await readAntigravityTranscriptFile("conv-1", { profileDir })).toEqual([
        { role: "compaction", compaction: { trigger: "auto", summary: "Summary of work" }, content: "" },
        { role: "compaction", compaction: { trigger: "auto" }, content: "" },
        { role: "compaction", compaction: { trigger: "auto" }, content: "" },
      ]);
    }));
});
