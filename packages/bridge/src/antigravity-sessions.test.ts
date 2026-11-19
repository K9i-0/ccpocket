import { describe, expect, it } from "vitest";
import { AcpTransport } from "./antigravity-process.js";
import {
  antigravityRecentSessions,
  fetchAntigravityCatalog,
  listAntigravitySessions,
} from "./antigravity-sessions.js";

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
        { id: "gemini-3.8-flash", name: "Flash", thoughtLevels: ["high", "low"] },
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
    expect(rows).toMatchObject([{ sessionId: "a", name: "Mine" }]);
  });
});
