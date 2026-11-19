import { readFileSync } from "node:fs";
import { describe, expect, it, vi } from "vitest";
import {
  AcpTransport,
  AntigravityProcess,
  ANTIGRAVITY_API_KEY_PROFILE,
  buildAntigravitySpawnSpec,
  buildUnifiedDiff,
  cleanCommandOutput,
  describeAcpTool,
  elicitationContentFromAnswer,
  elicitationFieldsFromSchema,
  resolveAntigravityConfig,
  type AntigravityConfig,
} from "./antigravity-process.js";
import type { ServerMessage } from "./parser.js";

type Json = Record<string, unknown>;
interface TraceEntry {
  dir: "in" | "out";
  msg: Json;
}

/** Recorded `agy acp` sessions, see docs/antigravity-acp-integration.md. */
function loadTrace(name: string): TraceEntry[] {
  return readFileSync(
    new URL(`../../../docs/antigravity-acp/${name}.ndjson`, import.meta.url),
    "utf8",
  )
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .map((line) => JSON.parse(line) as TraceEntry)
    .filter((entry) => entry.dir === "in" || entry.dir === "out");
}

/**
 * Replays a recorded session: every message the process writes must match the
 * next recorded outgoing message, and the agent messages recorded after it are
 * delivered back.
 */
class ReplayTransport extends AcpTransport {
  readonly written: Json[] = [];
  private cursor = 0;
  private readonly idMap = new Map<unknown, unknown>();

  constructor(private readonly entries: TraceEntry[]) {
    super();
  }

  start(): void {}
  stop(): void {}

  write(message: Json): void {
    this.written.push(message);
    const expected = this.entries[this.cursor];
    if (!expected || expected.dir !== "out") {
      throw new Error(`unexpected write: ${JSON.stringify(message)}`);
    }
    if (expected.msg.method !== message.method) {
      throw new Error(
        `expected ${String(expected.msg.method)} but got ${String(message.method)}`,
      );
    }
    if (message.method !== undefined && message.id !== undefined) {
      this.idMap.set(expected.msg.id, message.id);
    }
    this.cursor++;
    const batch: Json[] = [];
    while (this.entries[this.cursor]?.dir === "in") {
      const incoming = { ...this.entries[this.cursor++].msg };
      if (incoming.method === undefined && this.idMap.has(incoming.id)) {
        incoming.id = this.idMap.get(incoming.id);
      }
      batch.push(incoming);
    }
    setImmediate(() => {
      for (const incoming of batch) this.emit("message", incoming);
    });
  }

  get done(): boolean {
    return this.cursor >= this.entries.length;
  }
}

/** Answers requests from a table; used where no trace exists. */
class ScriptedTransport extends AcpTransport {
  readonly written: Json[] = [];
  started = false;

  constructor(private readonly results: Record<string, Json>) {
    super();
  }

  start(): void {
    this.started = true;
  }
  stop(): void {}

  write(message: Json): void {
    this.written.push(message);
    const result = this.results[String(message.method)];
    if (message.id === undefined || !result) return;
    setImmediate(() =>
      this.emit("message", { jsonrpc: "2.0", id: message.id, ...result }),
    );
  }
}

const LOGIN: AntigravityConfig = { bin: "agy", requireApiKey: false };
const API_KEY: AntigravityConfig = {
  bin: "agy",
  apiKey: "test-key",
  requireApiKey: true,
};

function createProcess(transport: AcpTransport, config = LOGIN) {
  const messages: ServerMessage[] = [];
  const proc = new AntigravityProcess({
    config,
    createTransport: () => transport,
  });
  proc.on("message", (message) => messages.push(message));
  return { proc, messages };
}

async function until(
  condition: () => boolean,
  label: string,
): Promise<void> {
  for (let i = 0; i < 500; i++) {
    if (condition()) return;
    await new Promise((resolve) => setImmediate(resolve));
  }
  throw new Error(`timed out waiting for ${label}`);
}

const ofType = <T extends ServerMessage["type"]>(
  messages: ServerMessage[],
  type: T,
): Array<Extract<ServerMessage, { type: T }>> =>
  messages.filter(
    (message): message is Extract<ServerMessage, { type: T }> =>
      message.type === type,
  );

const results = (messages: ServerMessage[]) => ofType(messages, "result");

describe("AntigravityProcess with recorded sessions", () => {
  it("runs turns, approvals and a denial from the recorded login session", async () => {
    const transport = new ReplayTransport(loadTrace("trace-turns"));
    const { proc, messages } = createProcess(transport);
    // The recording was made in default mode; a start without a mode would
    // switch this account to auto.
    proc.start("/workspace", { permissionMode: "default" });
    await until(() => proc.status === "idle", "session ready");

    const init = ofType(messages, "system").find((m) => m.subtype === "init");
    expect(init).toMatchObject({
      provider: "antigravity",
      sessionId: "00000000-0000-4000-8000-000000000001",
      model: "gemini-3.8-flash-high",
      permissionMode: "default",
    });
    expect(init?.antigravity?.authMode).toBe("login");
    expect(init?.antigravity?.permissionModes).toEqual([
      "default",
      "acceptEdits",
      "auto",
      "plan",
      "bypassPermissions",
    ]);
    // The login profile must never be switched to another auth method.
    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "session/new",
    ]);

    // Turn 1: plain answer.
    proc.sendInput("こんにちは、今のモデル名を教えて");
    await until(() => results(messages).length === 1, "turn 1");
    expect(ofType(messages, "stream_delta").length).toBeGreaterThan(0);
    const firstAnswer = ofType(messages, "assistant")[0];
    expect(firstAnswer.message.content.map((c) => c.type)).toEqual([
      "thinking",
      "text",
    ]);
    expect(results(messages)[0]).toMatchObject({
      subtype: "success",
      stopReason: "end_turn",
      inputTokens: 10723,
      outputTokens: 186,
    });
    expect(proc.status).toBe("idle");

    // Turn 2: file edit, approved.
    proc.sendInput("hello.txt を作って中に hi と書いて");
    await until(() => proc.status === "waiting_approval", "edit approval");
    const editRequest = ofType(messages, "permission_request")[0];
    expect(editRequest.toolName).toBe("FileChange");
    // "Always allow" is the Bridge's own offer; agy lists once / deny only.
    expect(editRequest.input.availableDecisions).toEqual([
      "accept",
      "acceptForSession",
      "decline",
    ]);
    expect(editRequest.input.changes).toEqual([
      {
        path: "/workspace/hello.txt",
        kind: "add",
        diff: "--- /dev/null\n+++ b/hello.txt\n@@ -0,0 +1,1 @@\n+hi",
      },
    ]);
    expect(proc.getPendingPermissions()).toHaveLength(1);
    expect(proc.approve(editRequest.toolUseId)).toBe(true);
    await until(() => results(messages).length === 2, "turn 2");
    const editResults = ofType(messages, "tool_result").filter(
      (m) => m.toolUseId === editRequest.toolUseId,
    );
    expect(editResults.map((m) => m.permissionOutcome)).toEqual([
      "approved",
      undefined,
    ]);
    expect(editResults[1]).toMatchObject({ toolName: "FileChange" });
    expect(editResults[1].content).toContain("+hi");

    // Turn 3: file edit, denied. Antigravity ends the turn without a word.
    proc.sendInput("konnitiwa.txt を作って中に hi と書いて");
    await until(() => proc.status === "waiting_approval", "second approval");
    const denied = ofType(messages, "permission_request")[1];
    expect(proc.reject(denied.toolUseId)).toBe(true);
    await until(() => results(messages).length === 3, "turn 3");
    const deniedResults = ofType(messages, "tool_result").filter(
      (m) => m.toolUseId === denied.toolUseId,
    );
    expect(deniedResults).toHaveLength(1);
    expect(deniedResults[0]).toMatchObject({
      content: "Rejected",
      permissionOutcome: "rejected",
    });
    expect(results(messages)[2].subtype).toBe("success");

    // Turn 4: command.
    proc.sendInput("ls -la");
    await until(() => proc.status === "waiting_approval", "command approval");
    const command = ofType(messages, "permission_request")[2];
    expect(command).toMatchObject({
      toolName: "Bash",
      input: { command: "ls -la", availableDecisions: ["accept", "acceptForSession", "decline"] },
    });
    proc.approve(command.toolUseId);
    await until(() => results(messages).length === 4, "turn 4");
    const output = ofType(messages, "tool_result").filter(
      (m) => m.toolUseId === command.toolUseId,
    )[1];
    expect(output.toolName).toBe("Bash");
    expect(output.content.startsWith("total 8\n")).toBe(true);
    expect(output.content).not.toContain("\r");
    expect(output.content).not.toContain("Created At");

    proc.sendInput("1から200まで1行ずつ数えて");
    await until(() => results(messages).length === 5, "turn 5");
    expect(transport.done).toBe(true);
    expect(proc.getPendingPermissions()).toHaveLength(0);
  });

  it("authenticates with the API key and reports a cancelled turn as interrupted", async () => {
    const transport = new ReplayTransport(loadTrace("trace-cancel"));
    const { proc, messages } = createProcess(transport, API_KEY);
    proc.start("/workspace", { model: "gemini-3.8-flash-high" });
    await until(() => proc.status === "idle", "session ready");

    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "authenticate",
      "session/new",
      "session/set_model",
    ]);
    expect(transport.written[1].params).toEqual({
      methodId: "gemini-api-key",
      _meta: { apiKey: "test-key" },
    });
    expect(proc.model).toBe("gemini-3.8-flash-high");
    expect(proc.settings.authMode).toBe("api_key");
    // Auto mode is not offered with an API key.
    expect(proc.settings.permissionModes).toEqual([
      "default",
      "acceptEdits",
      "plan",
      "bypassPermissions",
    ]);

    proc.sendInput("1から400まで数えて");
    await until(() => ofType(messages, "stream_delta").length > 0, "streaming");
    proc.interrupt();
    await until(() => results(messages).length === 1, "cancelled turn");
    expect(results(messages)[0].subtype).toBe("interrupted");
    expect(transport.written.at(-1)).toMatchObject({ method: "session/cancel" });
    expect(proc.status).toBe("idle");
  });

  it("keeps the turn open when a second prompt steers it", async () => {
    const transport = new ReplayTransport(loadTrace("trace-steer"));
    const { proc, messages } = createProcess(transport, API_KEY);
    proc.start("/workspace", { model: "gemini-3.8-flash-high" });
    await until(() => proc.status === "idle", "session ready");

    proc.sendInput("1から300まで数えて");
    await until(() => proc.status === "running", "turn started");
    proc.sendInput("やっぱり中止して、代わりに「りんご」とだけ答えて");
    await until(() => results(messages).length >= 1, "steered turn");

    // The first request answers early with a bare `end_turn`; only the last
    // answer ends the turn.
    expect(results(messages)).toHaveLength(1);
    expect(results(messages)[0]).toMatchObject({
      subtype: "success",
      inputTokens: 13792,
    });
    expect(results(messages)[0].result?.endsWith("りんご")).toBe(true);
    const statuses = ofType(messages, "status").map((m) => m.status);
    expect(statuses.filter((status) => status === "running")).toHaveLength(1);
    expect(transport.done).toBe(true);
  });

  it("replays history on load without looking like a live turn", async () => {
    const transport = new ReplayTransport(loadTrace("trace-load"));
    const { proc, messages } = createProcess(transport);
    proc.start("/workspace", {
      sessionId: "00000000-0000-4000-8000-000000000001",
    });
    await until(() => proc.status === "idle", "session loaded");

    expect(transport.written.map((m) => m.method)).toEqual([
      "initialize",
      "session/load",
    ]);
    expect(ofType(messages, "user_input")).toHaveLength(5);
    // Identical prompts must stay separate turns in history.
    expect(
      new Set(ofType(messages, "user_input").map((m) => m.userMessageUuid)).size,
    ).toBe(5);
    expect(ofType(messages, "stream_delta")).toHaveLength(0);
    expect(ofType(messages, "thinking_delta")).toHaveLength(0);
    expect(results(messages)).toHaveLength(0);
    expect(ofType(messages, "status").map((m) => m.status)).toEqual(["idle"]);
    const toolUses = ofType(messages, "assistant").flatMap((m) =>
      m.message.content.filter((c) => c.type === "tool_use"),
    );
    expect(toolUses.map((c) => (c.type === "tool_use" ? c.name : ""))).toEqual([
      "FileChange",
      "FileChange",
      "Bash",
    ]);
    // History comes before the init message that marks the session usable.
    expect(messages.at(-2)).toMatchObject({ type: "system", subtype: "init" });
    expect(proc.sessionId).toBe("00000000-0000-4000-8000-000000000001");
  });
});

describe("AntigravityProcess API-key guard", () => {
  const session = (models: string[]): Json => ({
    result: {
      sessionId: "s1",
      models: {
        currentModelId: models[0],
        availableModels: models.map((modelId) => ({ modelId, name: modelId })),
      },
      modes: { currentModeId: "default", availableModes: [{ id: "default" }] },
    },
  });

  it("refuses to start the login profile when an API key is required", async () => {
    let created = false;
    const messages: ServerMessage[] = [];
    const proc = new AntigravityProcess({
      config: { bin: "agy", requireApiKey: true },
      createTransport: () => {
        created = true;
        return new ScriptedTransport({});
      },
    });
    proc.on("message", (message) => messages.push(message));
    let exited = false;
    proc.on("exit", () => (exited = true));
    proc.start("/workspace");
    await until(() => exited, "exit");

    expect(created).toBe(false);
    expect(ofType(messages, "error")[0]).toMatchObject({
      errorCode: "antigravity_api_key_required",
    });
    expect(proc.sendInput("hi")).toBe(false);
  });

  it("sends no prompt when the model list shows the Google login is active", async () => {
    const transport = new ScriptedTransport({
      initialize: { result: {} },
      authenticate: { result: {} },
      "session/new": session(["gemini-3.8-flash-high", "claude-sonnet-4-6"]),
    });
    const { proc, messages } = createProcess(transport, API_KEY);
    proc.sendInput("queued before ready");
    proc.start("/workspace");
    proc.sendInput("queued while starting");
    await until(() => ofType(messages, "error").length > 0, "guard error");

    expect(ofType(messages, "error")[0].message).toContain("No prompt was sent");
    expect(transport.written.map((m) => m.method)).not.toContain(
      "session/prompt",
    );
    expect(ofType(messages, "system")).toHaveLength(0);
  });

  it("explains how to sign in when Antigravity is not authenticated", async () => {
    const transport = new ScriptedTransport({
      initialize: { result: {} },
      "session/new": {
        error: { code: -32000, message: "Authentication required" },
      },
    });
    const { proc, messages } = createProcess(transport);
    proc.start("/workspace");
    await until(() => ofType(messages, "error").length > 0, "auth error");
    expect(ofType(messages, "error")[0]).toMatchObject({
      errorCode: "antigravity_auth_required",
    });
  });

  it("reports a rejected mode change and keeps the current mode", async () => {
    const transport = new ScriptedTransport({
      initialize: { result: {} },
      "session/new": session(["gemini-3.8-flash-high"]),
      "session/set_mode": {
        error: { code: -32602, message: "Auto mode is not available" },
      },
    });
    const { proc } = createProcess(transport);
    proc.start("/workspace");
    await until(() => proc.status === "idle", "session ready");
    await expect(proc.setPermissionMode("auto")).rejects.toThrow(
      "Auto mode is not available",
    );
    expect(proc.permissionMode).toBe("default");
  });
});

describe("AntigravityProcess failure handling", () => {
  it("says the project folder is missing instead of blaming the CLI", async () => {
    const transport = new ScriptedTransport({});
    const { proc, messages } = createProcess(transport);
    proc.start("/no/such/ccpocket-folder");
    // Node reports a missing working directory as ENOENT, like a missing binary.
    transport.emit("error", Object.assign(new Error("spawn agy ENOENT"), { code: "ENOENT" }));
    expect(ofType(messages, "error")[0].message).toBe(
      "Project folder not found: /no/such/ccpocket-folder",
    );
    expect(ofType(messages, "error")[0].errorCode).toBeUndefined();
  });

  it("reports an exit during startup instead of leaving callers waiting", async () => {
    const transport = new ScriptedTransport({});
    const { proc, messages } = createProcess(transport);
    proc.start("/workspace");
    proc.sendInput("queued while starting");
    transport.emit("exit", 1);

    await expect(proc.waitUntilReady()).rejects.toThrow(
      "exited before the session was ready",
    );
    expect(ofType(messages, "error")).toHaveLength(1);
    expect(transport.written.map((m) => m.method)).toEqual(["initialize"]);
    expect(proc.sendInput("after exit")).toBe(false);
  });

  it("hands the real start failure and its code to resume callers", async () => {
    const transport = new ScriptedTransport({
      initialize: { result: {} },
      "session/load": {
        error: { code: -32000, message: "Authentication required" },
      },
    });
    const { proc } = createProcess(transport);
    proc.start("/workspace", { sessionId: "s1" });
    await expect(proc.waitUntilReady()).rejects.toMatchObject({
      errorCode: "antigravity_auth_required",
    });
  });

  it("never shows the API key in a start error", async () => {
    const transport = new ScriptedTransport({
      initialize: { result: {} },
      authenticate: { error: { code: -32602, message: "bad key test-key" } },
    });
    const { proc, messages } = createProcess(transport, API_KEY);
    proc.start("/workspace");
    await until(() => ofType(messages, "error").length > 0, "error");
    expect(ofType(messages, "error")[0].message).toBe("bad key <redacted>");
  });

  it("drops pending approvals when the process dies mid-turn", async () => {
    const transport = new ReplayTransport(loadTrace("trace-turns").slice(0, 26));
    const { proc, messages } = createProcess(transport);
    proc.start("/workspace");
    await until(() => proc.status === "idle", "session ready");
    proc.sendInput("first");
    await until(() => results(messages).length === 1, "turn 1");
    proc.sendInput("edit");
    await until(() => proc.status === "waiting_approval", "approval");
    transport.emit("exit", 1);

    expect(proc.getPendingPermissions()).toHaveLength(0);
    expect(results(messages).at(-1)).toMatchObject({ subtype: "error" });
    expect(proc.status).toBe("idle");
  });

  it("lets a prompt sent after a cancel finish normally", async () => {
    const answers: Json[] = [];
    const transport = new (class extends AcpTransport {
      start(): void {}
      stop(): void {}
      write(message: Json): void {
        answers.push(message);
        if (message.method === "initialize" || message.method === "session/new") {
          const result =
            message.method === "initialize"
              ? {}
              : {
                  sessionId: "s1",
                  models: { currentModelId: "gemini-x", availableModels: [] },
                  modes: { currentModeId: "default", availableModes: [] },
                };
          setImmediate(() =>
            this.emit("message", { jsonrpc: "2.0", id: message.id, result }),
          );
        }
      }
    })();
    const { proc, messages } = createProcess(transport);
    proc.start("/workspace");
    await until(() => proc.status === "idle", "session ready");

    proc.sendInput("first");
    proc.interrupt();
    proc.sendInput("second");
    const [first, second] = answers.filter((m) => m.method === "session/prompt");
    transport.emit("message", { id: first.id, result: { stopReason: "cancelled" } });
    await new Promise((resolve) => setImmediate(resolve));
    expect(results(messages)).toHaveLength(0);
    transport.emit("message", { id: second.id, result: { stopReason: "end_turn" } });
    await until(() => results(messages).length === 1, "second prompt");
    expect(results(messages)[0].subtype).toBe("success");
  });
});

describe("Antigravity helpers", () => {
  it("captures the key once and removes it from the Bridge environment", async () => {
    const { getAntigravityConfig } = await import("./antigravity-process.js");
    const previous = process.env.CCPOCKET_ANTIGRAVITY_API_KEY;
    process.env.CCPOCKET_ANTIGRAVITY_API_KEY = "captured-key";
    try {
      expect(getAntigravityConfig().apiKey).toBe("captured-key");
      expect(process.env.CCPOCKET_ANTIGRAVITY_API_KEY).toBeUndefined();
      expect(getAntigravityConfig().apiKey).toBe("captured-key");
    } finally {
      if (previous !== undefined) process.env.CCPOCKET_ANTIGRAVITY_API_KEY = previous;
    }
  });

  it("keeps API keys out of the agent environment and picks the profile", () => {
    const env = { PATH: "/bin", GEMINI_API_KEY: "g", CCPOCKET_ANTIGRAVITY_API_KEY: "k" };
    const login = buildAntigravitySpawnSpec("/p", LOGIN, env);
    expect(login.args).toEqual(["acp"]);
    expect(login.env).toEqual({ PATH: "/bin" });
    const keyed = buildAntigravitySpawnSpec("/p", API_KEY, env);
    expect(keyed.args).toEqual(["acp", "--app-data-dir", ANTIGRAVITY_API_KEY_PROFILE]);
    expect(keyed.env).toEqual({ PATH: "/bin" });
  });

  it("reads the configuration from the environment", () => {
    expect(resolveAntigravityConfig({})).toEqual({ bin: "agy", requireApiKey: false });
    expect(
      resolveAntigravityConfig({
        CCPOCKET_ANTIGRAVITY_API_KEY: " k ",
        CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY: "1",
        CCPOCKET_ANTIGRAVITY_BIN: "/opt/agy",
        // A globally exported key must not switch a login session to billing.
        GEMINI_API_KEY: "ignored",
      }),
    ).toEqual({ bin: "/opt/agy", apiKey: "k", requireApiKey: true });
  });

  it("strips the timing header from command output", () => {
    expect(
      cleanCommandOutput(
        "Created At: x\nCompleted At: y\nCommand exited with code 0.\n\nCommand output:\na\r\nb\r\n",
      ),
    ).toBe("a\nb");
    expect(cleanCommandOutput("plain\n")).toBe("plain");
  });

  it("builds a unified diff with context", () => {
    const before = ["a", "b", "c", "d", "e", "f", "g", "h"].join("\n") + "\n";
    const after = ["a", "b", "c", "d", "X", "f", "g", "h", "i"].join("\n") + "\n";
    expect(buildUnifiedDiff("f.txt", before, after)).toBe(
      [
        "--- a/f.txt",
        "+++ b/f.txt",
        "@@ -2,7 +2,8 @@",
        " b",
        " c",
        " d",
        "-e",
        "+X",
        " f",
        " g",
        " h",
        "+i",
      ].join("\n"),
    );
    expect(buildUnifiedDiff("n.txt", null, "x\ny\n")).toBe(
      "--- /dev/null\n+++ b/n.txt\n@@ -0,0 +1,2 @@\n+x\n+y",
    );
  });
});

/** A session as `agy` 1.5.12 reports it with an API key. */
const SESSION: Json = {
  result: {
    sessionId: "s1",
    models: {
      currentModelId: "gemini-3.1-pro-low",
      availableModels: [
        "gemini-3.8-flash-high",
        "gemini-3.8-flash-medium",
        "gemini-3.8-flash-low",
        "gemini-3.1-pro-high",
        "gemini-3.1-pro-low",
      ].map((modelId) => ({ modelId, name: modelId })),
    },
    modes: {
      currentModeId: "default",
      availableModes: [{ id: "default" }, { id: "accept-edits" }, { id: "plan" }],
    },
    configOptions: [
      {
        id: "model",
        currentValue: "gemini-3.1-pro",
        options: [
          { value: "gemini-3.8-flash", name: "Gemini 3.8 Flash" },
          { value: "gemini-3.1-pro", name: "Gemini 3.1 Pro" },
        ],
      },
      {
        id: "thought_level",
        currentValue: "low",
        options: [{ value: "low" }, { value: "high" }],
      },
    ],
    _meta: { antigravity: { tier: { id: "g1-ultra", name: "Google AI Ultra" } } },
  },
};

const configOptions = (model: string, level: string, levels: string[]): Json[] => [
  {
    id: "model",
    currentValue: model,
    options: [{ value: "gemini-3.8-flash" }, { value: "gemini-3.1-pro" }],
  },
  {
    id: "thought_level",
    currentValue: level,
    options: levels.map((value) => ({ value })),
  },
];

async function startSession(extra: Record<string, Json> = {}, options = {}) {
  const transport = new ScriptedTransport({
    initialize: {
      result: {
        agentInfo: { version: "1.5.12" },
        agentCapabilities: { sessionCapabilities: { additionalDirectories: {} } },
      },
    },
    "session/new": SESSION,
    "session/set_mode": { result: {} },
    ...extra,
  });
  const created = createProcess(transport);
  created.proc.start("/workspace", options);
  await until(() => created.proc.status === "idle", "session ready");
  const update = (body: Json) =>
    transport.emit("message", {
      jsonrpc: "2.0",
      method: "session/update",
      params: { sessionId: "s1", update: body },
    });
  const promptId = () =>
    transport.written.filter((m) => m.method === "session/prompt").at(-1)?.id;
  const endTurn = () =>
    transport.emit("message", {
      jsonrpc: "2.0",
      id: promptId(),
      result: { stopReason: "end_turn", usage: { inputTokens: 5, outputTokens: 2, thoughtTokens: 1 } },
    });
  return { ...created, transport, update, endTurn };
}

const settingsOf = (messages: ServerMessage[]) =>
  ofType(messages, "system").at(-1)?.antigravity;

describe("AntigravityProcess settings", () => {
  it("reports model families, thinking levels, the plan and the version", async () => {
    const { proc } = await startSession();
    expect(proc.settings).toMatchObject({
      model: "gemini-3.1-pro-low",
      baseModel: "gemini-3.1-pro",
      thoughtLevel: "low",
      thoughtLevels: ["low", "high"],
      tier: { id: "g1-ultra", name: "Google AI Ultra" },
      agentVersion: "1.5.12",
    });
    expect(proc.settings.modelOptions).toEqual([
      { id: "gemini-3.8-flash", name: "Gemini 3.8 Flash", thoughtLevels: ["low", "medium", "high"] },
      { id: "gemini-3.1-pro", name: "Gemini 3.1 Pro", thoughtLevels: ["low", "high"] },
    ]);
  });

  it("switches the model family and the thinking level through config options", async () => {
    const { proc, transport, messages } = await startSession({
      "session/set_config_option": {
        result: {
          configOptions: configOptions("gemini-3.8-flash", "high", ["low", "medium", "high"]),
        },
      },
    });
    await proc.setModel("gemini-3.8-flash");
    expect(transport.written.at(-1)).toMatchObject({
      method: "session/set_config_option",
      params: { configId: "model", value: "gemini-3.8-flash" },
    });
    expect(settingsOf(messages)).toMatchObject({
      model: "gemini-3.8-flash-high",
      baseModel: "gemini-3.8-flash",
      thoughtLevel: "high",
      thoughtLevels: ["low", "medium", "high"],
    });
    await expect(proc.setThoughtLevel("xhigh")).rejects.toThrow("no xhigh");
    await proc.setThoughtLevel("medium");
    expect(transport.written.at(-1)).toMatchObject({
      params: { configId: "thought_level", value: "medium" },
    });
  });

  it("follows config changes the agent reports and passes the start options", async () => {
    const { proc, transport, update, messages } = await startSession(
      {
        "session/set_model": { result: {} },
        "session/set_config_option": {
          result: { configOptions: configOptions("gemini-3.8-flash", "low", ["low", "medium", "high"]) },
        },
      },
      {
        model: "gemini-3.8-flash-high",
        thoughtLevel: "low",
        additionalDirectories: ["/extra"],
      },
    );
    const sent = (method: string) => transport.written.find((m) => m.method === method);
    expect(sent("session/new")?.params).toMatchObject({ additionalDirectories: ["/extra"] });
    expect(sent("session/set_model")?.params).toMatchObject({ modelId: "gemini-3.8-flash-high" });
    expect(proc.settings.model).toBe("gemini-3.8-flash-low");

    update({
      sessionUpdate: "config_option_update",
      configOptions: configOptions("gemini-3.1-pro", "high", ["low", "high"]),
    });
    expect(settingsOf(messages)).toMatchObject({ model: "gemini-3.1-pro-high" });
  });

  it("reports context usage and turn statistics", async () => {
    const { proc, update, endTurn, messages } = await startSession();
    proc.sendInput("hi");
    update({ sessionUpdate: "usage_update", used: 900, size: 1000000 });
    update({ sessionUpdate: "usage_update", used: 1200, size: 1000000 });
    // Held back until the turn ends.
    expect(settingsOf(messages)?.contextUsage).toBeUndefined();
    update({
      sessionUpdate: "tool_call",
      toolCallId: "t1",
      kind: "read",
      name: "read_file",
      status: "in_progress",
      rawInput: { Path: "/workspace/a.txt" },
    });
    endTurn();
    await until(() => results(messages).length > 0, "result");
    expect(results(messages)[0]).toMatchObject({
      subtype: "success",
      inputTokens: 5,
      outputTokens: 2,
      thoughtTokens: 1,
      toolCalls: 1,
      fileEdits: 0,
    });
    expect(results(messages)[0].duration).toBeGreaterThanOrEqual(0);
    expect(settingsOf(messages)?.contextUsage).toEqual({ used: 1200, size: 1000000 });
    expect(
      ofType(messages, "system").filter((m) => m.subtype === "antigravity_settings"),
    ).toHaveLength(1);
  });
});

describe("AntigravityProcess start mode", () => {
  const withAuto: Json = {
    result: {
      ...(SESSION.result as Json),
      modes: {
        currentModeId: "default",
        availableModes: [{ id: "default" }, { id: "auto" }, { id: "plan" }],
      },
    },
  };

  it("starts a new session in auto, like the agy CLI, when the account has it", async () => {
    const { proc, transport } = await startSession({ "session/new": withAuto });
    expect(proc.permissionMode).toBe("auto");
    expect(transport.written.find((m) => m.method === "session/set_mode")?.params)
      .toMatchObject({ modeId: "auto" });
  });

  it("keeps the mode that was asked for, and default where auto is missing", async () => {
    const asked = await startSession(
      { "session/new": withAuto },
      { permissionMode: "default" },
    );
    expect(asked.proc.permissionMode).toBe("default");
    const without = await startSession();
    expect(without.proc.permissionMode).toBe("default");
    expect(without.transport.written.map((m) => m.method)).not.toContain("session/set_mode");
  });
});

describe("AntigravityProcess bypass mode", () => {
  it("allows every request itself while the agent stays in default", async () => {
    const { proc, transport, update, messages } = await startSession();
    await proc.setPermissionMode("acceptEdits");
    await proc.setPermissionMode("bypassPermissions");
    expect(transport.written.at(-1)).toMatchObject({
      method: "session/set_mode",
      params: { modeId: "default" },
    });
    // The agent's own report of `default` is not the end of bypass.
    update({ sessionUpdate: "current_mode_update", currentModeId: "default" });
    expect(proc.permissionMode).toBe("bypassPermissions");

    proc.sendInput("run it");
    transport.emit("message", {
      jsonrpc: "2.0",
      id: "1",
      method: "session/request_permission",
      params: {
        toolCall: { toolCallId: "t1", kind: "execute", rawInput: { CommandLine: "ls" } },
        options: [
          { optionId: "allow", kind: "allow_once" },
          { optionId: "deny", kind: "reject_once" },
        ],
      },
    });
    expect(transport.written.at(-1)).toEqual({
      jsonrpc: "2.0",
      id: "1",
      result: { outcome: { outcome: "selected", optionId: "allow" } },
    });
    expect(ofType(messages, "permission_request")).toHaveLength(0);

    update({ sessionUpdate: "current_mode_update", currentModeId: "plan" });
    expect(proc.permissionMode).toBe("plan");
  });

  it("does not report an approval the agent offers no option for", async () => {
    const { proc, transport } = await startSession();
    proc.sendInput("run it");
    transport.emit("message", {
      jsonrpc: "2.0",
      id: "1",
      method: "session/request_permission",
      params: {
        toolCall: { toolCallId: "t1", kind: "execute" },
        options: [{ optionId: "deny", kind: "reject_once" }],
      },
    });
    expect(proc.approve("t1")).toBe(false);
    expect(proc.getPendingPermissions()).toHaveLength(1);
  });
});

describe("AntigravityProcess always allow", () => {
  const options = [
    { optionId: "allow", kind: "allow_once" },
    { optionId: "deny", kind: "reject_once" },
  ];
  const ask = (
    transport: ScriptedTransport,
    id: string,
    toolCall: Json,
  ) =>
    transport.emit("message", {
      jsonrpc: "2.0",
      id,
      method: "session/request_permission",
      params: { toolCall, options },
    });
  const run = (toolCallId: string, CommandLine: string): Json => ({
    toolCallId,
    kind: "execute",
    rawInput: { CommandLine },
  });

  it("remembers a command for the session and answers its repeats itself", async () => {
    const { proc, transport, messages } = await startSession();
    proc.sendInput("go");
    ask(transport, "1", run("t1", "npm test"));
    const request = ofType(messages, "permission_request")[0];
    expect(request.input.availableDecisions).toEqual([
      "accept",
      "acceptForSession",
      "decline",
    ]);
    expect(proc.approveAlways("t1")).toBe(true);
    // Antigravity only knows "once"; the session grant lives in the Bridge.
    expect(transport.written.at(-1)).toMatchObject({
      id: "1",
      result: { outcome: { optionId: "allow" } },
    });
    expect(ofType(messages, "tool_result").at(-1)).toMatchObject({
      permissionOutcome: "approved_for_session",
    });

    ask(transport, "2", run("t2", "npm test"));
    expect(transport.written.at(-1)).toMatchObject({
      id: "2",
      result: { outcome: { optionId: "allow" } },
    });
    // Another command still asks.
    ask(transport, "3", run("t3", "rm -rf build"));
    expect(ofType(messages, "permission_request")).toHaveLength(2);
  });

  it("allows every later file edit once edits were allowed for the session", async () => {
    const { proc, transport, messages } = await startSession();
    proc.sendInput("go");
    ask(transport, "1", { toolCallId: "e1", kind: "edit" });
    ask(transport, "2", { toolCallId: "e2", kind: "edit" });
    expect(proc.approveAlways("e1")).toBe(true);
    // The edit that was already waiting is settled with it.
    expect(proc.getPendingPermissions()).toHaveLength(0);
    ask(transport, "3", { toolCallId: "e3", kind: "edit" });
    expect(ofType(messages, "permission_request")).toHaveLength(2);
    // Commands are a separate grant.
    ask(transport, "4", run("t1", "ls"));
    expect(ofType(messages, "permission_request")).toHaveLength(3);
  });
});

describe("AntigravityProcess MCP tools", () => {
  const options = [
    { optionId: "allow", kind: "allow_once" },
    { optionId: "deny", kind: "reject_once" },
  ];
  // As recorded from agy 1.5.12: an MCP call is `call_mcp_tool`, kind execute.
  const mcpCall = (toolCallId: string, ToolName: string): Json => ({
    toolCallId,
    name: "call_mcp_tool",
    kind: "execute",
    title: `MCP Tool ${ToolName}`,
    rawInput: { ServerName: "dart-mcp", ToolName, Arguments: { command: "listDtdUris" } },
  });
  const ask = (transport: ScriptedTransport, id: string, toolCall: Json) =>
    transport.emit("message", {
      jsonrpc: "2.0",
      id,
      method: "session/request_permission",
      params: { toolCall, options },
    });

  it("shows an MCP call under its server and tool, not as a shell command", async () => {
    const { proc, messages, update } = await startSession();
    proc.sendInput("go");
    update({ sessionUpdate: "tool_call", status: "in_progress", ...mcpCall("m1", "dtd") });
    expect(ofType(messages, "assistant").at(-1)?.message.content).toEqual([
      {
        type: "tool_use",
        id: "m1",
        name: "mcp__dart-mcp__dtd",
        input: { command: "listDtdUris" },
      },
    ]);
    // Arguments also arrive as a JSON string.
    expect(
      describeAcpTool({
        name: "call_mcp_tool",
        kind: "execute",
        rawInput: { ServerName: "marionette", ToolName: "connect", Arguments: '{"uri":"ws://x"}' },
      }),
    ).toEqual({ toolName: "mcp__marionette__connect", input: { uri: "ws://x" } });
  });

  it("remembers an MCP tool for the session whatever its arguments", async () => {
    const { proc, transport, messages } = await startSession();
    proc.sendInput("go");
    ask(transport, "1", mcpCall("m1", "dtd"));
    const request = ofType(messages, "permission_request")[0];
    expect(request.toolName).toBe("mcp__dart-mcp__dtd");
    expect(request.input).toEqual({
      command: "listDtdUris",
      availableDecisions: ["accept", "acceptForSession", "decline"],
    });
    expect(proc.approveAlways("m1")).toBe(true);

    ask(transport, "2", {
      ...mcpCall("m2", "dtd"),
      rawInput: { ServerName: "dart-mcp", ToolName: "dtd", Arguments: { command: "connect" } },
    });
    expect(transport.written.at(-1)).toMatchObject({
      id: "2",
      result: { outcome: { optionId: "allow" } },
    });
    // Another tool of the same server still asks.
    ask(transport, "3", mcpCall("m3", "hot_reload"));
    expect(ofType(messages, "permission_request")).toHaveLength(2);
  });
});

describe("AntigravityProcess turns the agent starts itself", () => {
  const timer = {
    toolCallId: "sched",
    name: "schedule",
    kind: "other",
    title: "Run schedule",
    rawInput: { DurationSeconds: 10, Prompt: "check the build" },
  };
  /** A turn that sets a timer and ends, as recorded from agy 1.5.12. */
  const turnWithTimer = async () => {
    const session = await startSession();
    session.proc.sendInput("go");
    session.update({ sessionUpdate: "tool_call", status: "in_progress", ...timer });
    session.update({ sessionUpdate: "agent_message_chunk", content: { text: "waiting" } });
    session.endTurn();
    await until(() => session.proc.status === "idle", "first turn done");
    return session;
  };
  const statuses = (messages: ServerMessage[]) =>
    ofType(messages, "status").map((m) => m.status);

  it("runs again when a timer wakes the agent and ends on the last usage report", async () => {
    const { proc, transport, messages, update } = await turnWithTimer();
    vi.useFakeTimers();
    try {
      expect(proc.expectsFollowUp).toBe(true);
      expect(ofType(messages, "background_tasks").at(-1)?.tasks).toEqual([
        { taskId: "sched", taskType: "antigravity_timer", description: "Timer: check the build" },
      ]);
      // The timer fires: the agent answers seconds later, so run from now.
      update({ sessionUpdate: "tool_call_update", status: "completed", ...timer });
      expect(proc.status).toBe("running");
      expect(proc.expectsFollowUp).toBe(false);
      expect(ofType(messages, "background_tasks").at(-1)?.tasks).toEqual([]);
      expect(ofType(messages, "tool_result").at(-1)).toMatchObject({ toolUseId: "sched" });
      // The call is not announced a second time.
      const toolUses = () =>
        ofType(messages, "assistant").filter((m) =>
          m.message.content.some((c) => c.type === "tool_use"),
        );
      expect(toolUses()).toHaveLength(1);

      update({ sessionUpdate: "usage_update", used: 10, size: 100 });
      update({
        sessionUpdate: "tool_call",
        status: "in_progress",
        toolCallId: "c1",
        name: "run_command",
        kind: "execute",
        rawInput: { CommandLine: "echo woke" },
      });
      expect(proc.status).toBe("running");
      expect(proc.isTurnActive).toBe(true);
      expect(proc.isWaitingForInput).toBe(false);

      transport.emit("message", {
        jsonrpc: "2.0",
        id: "p1",
        method: "session/request_permission",
        params: {
          toolCall: { toolCallId: "c1", kind: "execute", rawInput: { CommandLine: "echo woke" } },
          options: [
            { optionId: "allow", kind: "allow_once" },
            { optionId: "deny", kind: "reject_once" },
          ],
        },
      });
      expect(proc.status).toBe("waiting_approval");
      // Waiting for the user is not the end of the turn.
      vi.advanceTimersByTime(60_000);
      expect(proc.status).toBe("waiting_approval");
      expect(proc.approve("c1")).toBe(true);
      expect(proc.status).toBe("running");

      update({ sessionUpdate: "tool_call_update", status: "completed", toolCallId: "c1" });
      // A usage report followed at once by more work does not end the turn.
      update({ sessionUpdate: "usage_update", used: 20, size: 100 });
      update({ sessionUpdate: "agent_message_chunk", content: { text: "finished" } });
      vi.advanceTimersByTime(60_000);
      expect(proc.status).toBe("running");
      expect(results(messages)).toHaveLength(1);

      update({ sessionUpdate: "usage_update", used: 30, size: 100 });
      vi.advanceTimersByTime(5_000);
      expect(proc.status).toBe("idle");
      expect(results(messages)).toHaveLength(2);
      expect(results(messages)[1]).toMatchObject({
        subtype: "success",
        result: "finished",
        toolCalls: 1,
      });
      expect(statuses(messages).slice(-4)).toEqual([
        "running",
        "waiting_approval",
        "running",
        "idle",
      ]);
    } finally {
      vi.useRealTimers();
    }
  });

  it("ends the turn after a denial, which the agent follows with silence", async () => {
    const { proc, transport, messages, update } = await turnWithTimer();
    vi.useFakeTimers();
    try {
      const call = { toolCallId: "c1", kind: "execute", rawInput: { CommandLine: "echo woke" } };
      update({ sessionUpdate: "tool_call", status: "in_progress", ...call });
      transport.emit("message", {
        jsonrpc: "2.0",
        id: "p1",
        method: "session/request_permission",
        params: {
          toolCall: call,
          options: [
            { optionId: "allow", kind: "allow_once" },
            { optionId: "deny", kind: "reject_once" },
          ],
        },
      });
      expect(proc.reject("c1")).toBe(true);
      // As recorded: the call goes in progress, fails, and nothing follows.
      update({ sessionUpdate: "tool_call_update", status: "in_progress", ...call });
      update({ sessionUpdate: "tool_call_update", status: "failed", ...call });
      expect(proc.status).toBe("running");
      vi.advanceTimersByTime(5_000);
      expect(proc.status).toBe("idle");
      expect(results(messages)).toHaveLength(2);
    } finally {
      vi.useRealTimers();
    }
  });

  it("goes back to idle without a result when the agent never answers", async () => {
    const { proc, messages, update } = await turnWithTimer();
    vi.useFakeTimers();
    try {
      update({ sessionUpdate: "tool_call_update", status: "completed", ...timer });
      expect(proc.status).toBe("running");
      // A usage report alone is not the agent's answer.
      update({ sessionUpdate: "usage_update", used: 10, size: 100 });
      vi.advanceTimersByTime(10_000);
      expect(proc.status).toBe("running");
      vi.advanceTimersByTime(20_000);
      expect(proc.status).toBe("idle");
      expect(results(messages)).toHaveLength(1);
    } finally {
      vi.useRealTimers();
    }
  });

  it("expects a follow-up from a background command only for a while", async () => {
    const session = await startSession();
    const { proc, messages, update, endTurn } = session;
    vi.useFakeTimers();
    try {
      proc.sendInput("go");
      const server = {
        toolCallId: "srv",
        name: "run_command",
        kind: "execute",
        rawInput: { CommandLine: "npm run dev" },
      };
      update({ sessionUpdate: "tool_call", status: "in_progress", ...server });
      // A call that finished within the turn is not background work.
      update({ sessionUpdate: "tool_call", status: "in_progress", toolCallId: "ls", kind: "execute", rawInput: { CommandLine: "ls" } });
      update({ sessionUpdate: "tool_call_update", status: "completed", toolCallId: "ls" });
      endTurn();
      await vi.advanceTimersByTimeAsync(0);
      expect(proc.status).toBe("idle");
      expect(ofType(messages, "background_tasks").at(-1)?.tasks).toEqual([
        { taskId: "srv", taskType: "antigravity_terminal", description: "npm run dev" },
      ]);
      expect(proc.expectsFollowUp).toBe(true);
      const reports = ofType(messages, "background_tasks").length;
      // Still running after five minutes: taken for one that never ends.
      vi.advanceTimersByTime(5 * 60_000);
      expect(proc.expectsFollowUp).toBe(false);
      // Reported again so a held completion is looked at once more.
      expect(ofType(messages, "background_tasks")).toHaveLength(reports + 1);
      expect(ofType(messages, "background_tasks").at(-1)?.tasks).toHaveLength(1);
    } finally {
      vi.useRealTimers();
    }
  });

  it("interrupts a turn no prompt is open for", async () => {
    const { proc, transport, messages, update } = await turnWithTimer();
    update({ sessionUpdate: "agent_thought_chunk", content: { text: "checking" } });
    expect(proc.status).toBe("running");
    proc.interrupt();
    expect(transport.written.at(-1)).toMatchObject({ method: "session/cancel" });
    expect(results(messages).at(-1)).toMatchObject({ subtype: "interrupted" });
    expect(proc.status).toBe("idle");
    expect(proc.isTurnActive).toBe(false);
  });

  it("lets a prompt take over the turn and end it with its answer", async () => {
    const { proc, messages, update, endTurn } = await turnWithTimer();
    vi.useFakeTimers();
    try {
      update({ sessionUpdate: "agent_message_chunk", content: { text: "building" } });
      update({ sessionUpdate: "usage_update", used: 10, size: 100 });
      proc.sendInput("also run the tests");
      vi.advanceTimersByTime(60_000);
      expect(proc.status).toBe("running");
      expect(results(messages)).toHaveLength(1);
    } finally {
      vi.useRealTimers();
    }
    endTurn();
    await until(() => results(messages).length === 2, "prompt answered");
    expect(proc.status).toBe("idle");
  });

  it("ignores the late result of a call it no longer tracks", async () => {
    const { proc, messages, update } = await turnWithTimer();
    // Such as a background command of a turn that was cancelled.
    update({ sessionUpdate: "tool_call_update", status: "completed", toolCallId: "gone" });
    expect(proc.status).toBe("idle");
    expect(ofType(messages, "tool_result").some((m) => m.toolUseId === "gone")).toBe(false);
  });
});

describe("AntigravityProcess questions", () => {
  const schema = {
    type: "object",
    properties: {
      q1: {
        type: "string",
        title: "好きな色は？",
        oneOf: [
          { const: "1", title: "赤" },
          { const: "2", title: "青" },
        ],
      },
      q1_other: { type: "string", title: "Other" },
      q2: {
        type: "array",
        title: "使う道具は？",
        items: { anyOf: [{ const: "a", title: "筆" }, { const: "b", title: "ペン" }] },
      },
    },
  };

  it("maps a form schema to questions and answers back to its values", () => {
    const fields = elicitationFieldsFromSchema(schema);
    expect(fields.map((f) => [f.id, f.type, f.otherId])).toEqual([
      ["q1", "choice", "q1_other"],
      ["q2", "multi", undefined],
    ]);
    expect(
      elicitationContentFromAnswer(
        fields,
        JSON.stringify({ answers: { q1: "青", "使う道具は？": ["筆", "ペン"] } }),
      ),
    ).toEqual({ q1: "2", q2: ["a", "b"] });
    expect(elicitationContentFromAnswer(fields, "紫")).toEqual({ q1_other: "紫" });
  });

  it("shows ask_question as a question form and answers the elicitation", async () => {
    const { proc, transport, update, messages } = await startSession();
    expect(
      transport.written.find((m) => m.method === "initialize")?.params,
    ).toMatchObject({ clientCapabilities: { elicitation: { form: {} } } });
    proc.sendInput("ask me");
    update({
      sessionUpdate: "tool_call",
      toolCallId: "t1",
      kind: "other",
      name: "ask_question",
      status: "in_progress",
      rawInput: {
        questions: [{ question: "好きな色は？", options: ["赤", "青"], is_multi_select: false }],
      },
    });
    transport.emit("message", {
      jsonrpc: "2.0",
      id: "1",
      method: "elicitation/create",
      params: { sessionId: "s1", toolCallId: "t1", mode: "form", requestedSchema: schema },
    });
    expect(proc.status).toBe("waiting_approval");
    const request = ofType(messages, "permission_request")[0];
    expect(request).toMatchObject({ toolUseId: "t1", toolName: "AskUserQuestion" });
    expect((request.input.questions as Json[])[0]).toMatchObject({
      id: "q1",
      question: "好きな色は？",
      options: [{ label: "赤" }, { label: "青" }],
      multiSelect: false,
      isOther: true,
    });
    expect(proc.getPendingPermission()?.toolName).toBe("AskUserQuestion");

    expect(proc.answer("t1", JSON.stringify({ answers: { q1: "赤" } }))).toBe(true);
    expect(transport.written.at(-1)).toEqual({
      jsonrpc: "2.0",
      id: "1",
      result: { action: "accept", content: { q1: "1" } },
    });
    expect(proc.status).toBe("running");
    expect(ofType(messages, "tool_result").at(-1)).toMatchObject({
      toolUseId: "t1",
      permissionOutcome: "answered",
    });
    // The tool's own completion adds no second result.
    update({ sessionUpdate: "tool_call_update", toolCallId: "t1", status: "completed" });
    expect(ofType(messages, "tool_result")).toHaveLength(1);
  });

  it("declines a question on reject and cancels it on interrupt", async () => {
    const { proc, transport } = await startSession();
    proc.sendInput("ask me");
    const ask = (id: string) =>
      transport.emit("message", {
        jsonrpc: "2.0",
        id,
        method: "elicitation/create",
        params: { mode: "form", requestedSchema: schema },
      });
    ask("1");
    expect(proc.reject()).toBe(true);
    expect(transport.written.at(-1)).toMatchObject({ id: "1", result: { action: "decline" } });
    ask("2");
    proc.interrupt();
    expect(transport.written.at(-2)).toMatchObject({ id: "2", result: { action: "cancel" } });
    expect(transport.written.at(-1)).toMatchObject({ method: "session/cancel" });
  });
});

describe("AntigravityProcess plan review", () => {
  const planPath = "/home/u/.gemini/antigravity-cli/brain/s1/plan_add_subtract.md";
  const writePlan = (update: (body: Json) => void) => {
    const call = {
      toolCallId: "p1",
      kind: "edit",
      name: "write_file",
      rawInput: {
        Path: planPath,
        Content: "# Plan\n1. do it",
        ArtifactMetadata: { RequestFeedback: true, UserFacing: true },
      },
      content: [{ type: "diff", path: planPath, newText: "# Plan\n1. do it" }],
    };
    update({ sessionUpdate: "tool_call", status: "in_progress", ...call });
    update({ sessionUpdate: "tool_call_update", status: "completed", ...call });
  };
  const planTurn = async () => {
    const session = await startSession();
    await session.proc.setPermissionMode("acceptEdits");
    await session.proc.setPermissionMode("plan");
    session.proc.sendInput("plan it");
    writePlan(session.update);
    session.endTurn();
    // The plan is read from disk, which takes longer than `until` spins.
    await vi.waitFor(() =>
      expect(ofType(session.messages, "permission_request")).toHaveLength(1),
    );
    return session;
  };

  it("offers the plan for approval, then returns to the earlier mode and proceeds", async () => {
    const { proc, transport, messages } = await planTurn();
    expect(ofType(messages, "permission_request")[0]).toMatchObject({
      toolName: "ExitPlanMode",
      input: { plan: "# Plan\n1. do it" },
    });
    expect(proc.status).toBe("waiting_approval");
    expect(proc.isWaitingForInput).toBe(false);
    // The document shows under its name, not its path in the agy profile.
    const written = ofType(messages, "assistant")
      .flatMap((m) => m.message.content)
      .find((c) => c.type === "tool_use" && c.name === "FileChange");
    expect(written).toMatchObject({
      input: { changes: [{ path: "plan_add_subtract.md" }] },
    });

    expect(proc.approve()).toBe(true);
    await until(
      () => transport.written.filter((m) => m.method === "session/prompt").length === 2,
      "approval prompt",
    );
    expect(proc.permissionMode).toBe("acceptEdits");
    // The message sent on the user's behalf is shown as theirs.
    expect(ofType(messages, "user_input").at(-1)?.text).toBe(
      "Approved. Proceed with the implementation plan.",
    );
    expect(transport.written.at(-1)?.params).toMatchObject({
      prompt: [{ type: "text", text: "Approved. Proceed with the implementation plan." }],
    });
  });

  it("sends feedback as the next message and stays in plan mode", async () => {
    const { proc, transport, messages } = await planTurn();
    expect(proc.reject(undefined, "テストも書いて")).toBe(true);
    expect(proc.permissionMode).toBe("plan");
    expect(transport.written.at(-1)?.params).toMatchObject({
      prompt: [{ type: "text", text: "テストも書いて" }],
    });
    expect(ofType(messages, "tool_result").at(-1)).toMatchObject({
      permissionOutcome: "rejected",
    });
  });

  it("goes idle when the plan is rejected without feedback", async () => {
    const { proc, transport } = await planTurn();
    expect(proc.reject()).toBe(true);
    expect(proc.status).toBe("idle");
    expect(transport.written.filter((m) => m.method === "session/prompt")).toHaveLength(1);
  });

  it("asks for no review outside plan mode", async () => {
    const { proc, update, endTurn, messages } = await startSession();
    proc.sendInput("write it");
    writePlan(update);
    endTurn();
    await until(() => proc.status === "idle", "idle");
    expect(ofType(messages, "permission_request")).toHaveLength(0);
  });
});

describe("describeAcpTool", () => {
  it("names Antigravity tools the way clients render them", () => {
    expect(
      describeAcpTool({ kind: "read", name: "read_file", rawInput: { Path: "/a/b.txt" } }),
    ).toEqual({ toolName: "Read", input: { file_path: "/a/b.txt" } });
    expect(
      describeAcpTool({ kind: "search", name: "search_web", rawInput: { query: "acp" } }),
    ).toEqual({ toolName: "WebSearch", input: { query: "acp" } });
    expect(
      describeAcpTool({
        kind: "search",
        name: "grep_search",
        rawInput: { Query: "add", SearchPath: "/a" },
      }),
    ).toEqual({ toolName: "Grep", input: { pattern: "add", path: "/a" } });
    // Only a web tool is a web search, with or without a path.
    expect(
      describeAcpTool({ kind: "search", name: "find_by_name", rawInput: { Pattern: "*.ts" } }),
    ).toEqual({ toolName: "Grep", input: { pattern: "*.ts" } });
    expect(describeAcpTool({ kind: "other", name: "browser" })).toBeUndefined();
  });
});
