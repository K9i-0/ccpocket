import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  AcpTransport,
  AntigravityProcess,
  ANTIGRAVITY_API_KEY_PROFILE,
  buildAntigravitySpawnSpec,
  buildUnifiedDiff,
  cleanCommandOutput,
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
    proc.start("/workspace");
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
    expect(editRequest.input.availableDecisions).toEqual(["accept", "decline"]);
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
      input: { command: "ls -la", availableDecisions: ["accept", "decline"] },
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
    await expect(proc.setPermissionMode("bypassPermissions")).rejects.toThrow();
    expect(proc.permissionMode).toBe("default");
  });
});

describe("AntigravityProcess failure handling", () => {
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
