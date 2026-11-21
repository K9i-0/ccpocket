import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  AcpTransport,
  AntigravityProcess,
  type AntigravityConfig,
} from "./antigravity-process.js";
import {
  antigravitySwarmDir,
  readSwarmPosts,
  readSwarmRoster,
} from "./antigravity-swarm.js";
import type { ServerMessage } from "./parser.js";

type Json = Record<string, unknown>;

const COORDINATOR = "d46c4e7b-6547-4906-bcf5-692d00a1deaa";
const WRITER_A = "dc157ab2-6b3d-4356-88ab-0fe7172a3da6";
const WRITER_B = "5faad2cd-2236-4c79-9856-980776c05667";
const LOGIN: AntigravityConfig = { bin: "agy", requireApiKey: false };

const dirs: string[] = [];
afterEach(() => {
  for (const dir of dirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function appDataDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "ccpocket-agy-swarm-"));
  dirs.push(dir);
  return dir;
}

/** The roster and board as `agy` 1.5.13 wrote them for a two-worker swarm. */
function writeSwarm(
  appData: string,
  members: Record<string, Json>,
  posts: Json[] = [],
): string {
  const dir = antigravitySwarmDir(appData, COORDINATOR)!;
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    join(dir, "members.json"),
    JSON.stringify({
      title: "write a and b files",
      members: {
        coordinator: {
          conversation_id: COORDINATOR,
          role: "coordinator",
          wake_mode: "anything",
          killed: false,
        },
        ...members,
      },
    }),
  );
  writeFileSync(
    join(dir, "board.jsonl"),
    posts.map((post) => JSON.stringify(post)).join("\n") + (posts.length ? "\n" : ""),
  );
  return dir;
}

const worker = (conversationId: string, wakeMode: string, killed = false): Json => ({
  conversation_id: conversationId,
  role: "worker",
  wake_mode: wakeMode,
  killed,
});

class ScriptedTransport extends AcpTransport {
  readonly written: Json[] = [];

  constructor(private readonly results: Record<string, Json>) {
    super();
  }

  start(): void {}
  stop(): void {}

  write(message: Json): void {
    this.written.push(message);
    const result = this.results[String(message.method)];
    if (message.id === undefined || message.method === undefined || !result) return;
    setImmediate(() =>
      this.emit("message", { jsonrpc: "2.0", id: message.id, ...result }),
    );
  }
}

async function until(condition: () => boolean, label: string): Promise<void> {
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
    (message): message is Extract<ServerMessage, { type: T }> => message.type === type,
  );

const toolUses = (messages: ServerMessage[]) =>
  ofType(messages, "assistant").flatMap((m) =>
    m.message.content.filter((c) => c.type === "tool_use"),
  );

async function startSession(
  appData: string,
  options: { sessionId?: string; permissionMode?: "acceptEdits" } = {},
) {
  const session: Json = {
    result: {
      sessionId: COORDINATOR,
      models: {
        currentModelId: "gemini-3.8-flash-high",
        availableModels: [{ modelId: "gemini-3.8-flash-high", name: "Flash" }],
      },
      modes: {
        currentModeId: "default",
        availableModes: [{ id: "default" }, { id: "accept-edits" }, { id: "plan" }],
      },
    },
  };
  const transport = new ScriptedTransport({
    initialize: { result: { agentInfo: { version: "1.5.13" } } },
    "session/new": session,
    "session/load": session,
    "session/resume": { result: {} },
    "session/set_mode": { result: {} },
  });
  const messages: ServerMessage[] = [];
  const proc = new AntigravityProcess({
    config: LOGIN,
    createTransport: () => transport,
    appDataDir: appData,
  });
  proc.on("message", (message) => messages.push(message));
  proc.start("/workspace", options);
  await until(() => proc.status === "idle", "session ready");
  const send = (sessionId: string, body: Json) =>
    transport.emit("message", {
      jsonrpc: "2.0",
      method: "session/update",
      params: { sessionId, update: body },
    });
  const update = (body: Json) => send(COORDINATOR, body);
  const tool = (toolCallId: string, name: string, rawInput: Json) => {
    const call = { toolCallId, name, kind: "other", title: `Run ${name}`, rawInput };
    update({ sessionUpdate: "tool_call", status: "in_progress", ...call });
    update({ sessionUpdate: "tool_call_update", status: "completed", ...call });
  };
  const endTurn = () =>
    transport.emit("message", {
      jsonrpc: "2.0",
      id: transport.written.filter((m) => m.method === "session/prompt").at(-1)?.id,
      result: { stopReason: "end_turn" },
    });
  const requests = (method: string) =>
    transport.written.filter((m) => m.method === method).map((m) => m.params as Json);
  const sync = () => (proc as unknown as { syncSwarm(): void }).syncSwarm();
  return { proc, transport, messages, send, update, tool, endTurn, requests, sync };
}

/** The turn that starts the swarm, ending with both workers added. */
async function startSwarm(appData: string, options = {}) {
  const session = await startSession(appData, options);
  session.proc.sendInput("/swarm write a and b");
  writeSwarm(appData, {
    writer_a: worker(WRITER_A, "working"),
    writer_b: worker(WRITER_B, "working"),
  });
  session.tool("call_1", "swarm", { action: "add", name: "writer_a", brief: "write a" });
  await until(
    () => session.requests("session/resume").length === 2,
    "both workers opened",
  );
  return session;
}

describe("swarm files", () => {
  it("reads the roster, leaving out members it cannot address", () => {
    const appData = appDataDir();
    const dir = writeSwarm(appData, {
      writer_a: worker(WRITER_A, "working"),
      writer_b: worker(WRITER_B, "mentions"),
      gone: worker("0110c18b-836c-487f-abdd-ed0e291472cf", "working", true),
      broken: { conversation_id: "../../etc" },
    });
    expect(readSwarmRoster(dir)).toEqual({
      title: "write a and b files",
      members: [
        { name: "coordinator", conversationId: COORDINATOR, role: "coordinator", killed: false, working: false },
        { name: "writer_a", conversationId: WRITER_A, role: "worker", killed: false, working: true },
        { name: "writer_b", conversationId: WRITER_B, role: "worker", killed: false, working: false },
        {
          name: "gone",
          conversationId: "0110c18b-836c-487f-abdd-ed0e291472cf",
          role: "worker",
          killed: true,
          working: false,
        },
      ],
    });
  });

  it("reads the posts after a sequence number and skips a half-written line", () => {
    const appData = appDataDir();
    const dir = writeSwarm(appData, {}, [
      { seq: 1, agent: "coordinator", text: "@writer_a write a", kind: "brief" },
      { seq: 2, agent: "writer_a", text: "@coordinator [done]", time: "2026-11-21 20:51:41" },
    ]);
    writeFileSync(join(dir, "board.jsonl"), '{"seq":3,"agent":"wri', { flag: "a" });
    expect(readSwarmPosts(dir, 1)).toEqual([
      { seq: 2, agent: "writer_a", text: "@coordinator [done]", time: "2026-11-21 20:51:41" },
    ]);
    expect(readSwarmRoster(join(dir, "missing"))).toBeUndefined();
    expect(antigravitySwarmDir(appData, "../escape")).toBeUndefined();
  });
});

describe("AntigravityProcess with a swarm", () => {
  it("opens each worker's conversation so its requests arrive here", async () => {
    const { proc, requests } = await startSwarm(appDataDir());
    expect(requests("session/resume")).toEqual([
      { sessionId: WRITER_A, cwd: "/workspace", mcpServers: [] },
      { sessionId: WRITER_B, cwd: "/workspace", mcpServers: [] },
    ]);
    // Opened once, however often the roster is read again.
    (proc as unknown as { syncSwarm(): void }).syncSwarm();
    await new Promise((resolve) => setImmediate(resolve));
    expect(requests("session/resume")).toHaveLength(2);
    proc.stop();
  });

  it("puts workers in the coordinator's mode, now and when it changes", async () => {
    const { proc, requests } = await startSwarm(appDataDir(), {
      permissionMode: "acceptEdits",
    });
    const workerModes = () =>
      requests("session/set_mode").filter((p) => p.sessionId !== COORDINATOR);
    await until(() => workerModes().length === 2, "modes mirrored");
    expect(workerModes()).toEqual([
      { sessionId: WRITER_A, modeId: "accept-edits" },
      { sessionId: WRITER_B, modeId: "accept-edits" },
    ]);
    // Bypass answers every request in the Bridge; the workers go back to asking.
    await proc.setPermissionMode("bypassPermissions");
    await until(() => workerModes().length === 4, "modes mirrored again");
    expect(workerModes().slice(2).map((p) => p.modeId)).toEqual(["default", "default"]);
    proc.stop();
  });

  it("relays a worker's approval request and goes back to idle once answered", async () => {
    const { proc, transport, messages, endTurn } = await startSwarm(appDataDir());
    endTurn();
    await until(() => proc.status === "idle", "coordinator turn done");
    transport.emit("message", {
      jsonrpc: "2.0",
      id: 77,
      method: "session/request_permission",
      params: {
        sessionId: WRITER_A,
        toolCall: {
          toolCallId: "worker_call_1",
          kind: "execute",
          title: "echo a > a.txt",
          rawInput: { CommandLine: "echo a > a.txt" },
        },
        options: [
          { optionId: "allow", kind: "allow_once" },
          { optionId: "reject", kind: "reject_once" },
        ],
      },
    });
    expect(proc.status).toBe("waiting_approval");
    expect(toolUses(messages).at(-1)).toMatchObject({
      id: "worker_call_1",
      name: "Bash",
      input: { command: "echo a > a.txt", swarmWorker: "writer_a" },
    });
    expect(ofType(messages, "permission_request").at(-1)).toMatchObject({
      toolUseId: "worker_call_1",
      toolName: "Bash",
      input: { command: "echo a > a.txt", swarmWorker: "writer_a" },
    });
    // No turn of the coordinator's began with it.
    expect(proc.isTurnActive).toBe(false);

    expect(proc.approve("worker_call_1")).toBe(true);
    expect(transport.written.at(-1)).toEqual({
      jsonrpc: "2.0",
      id: 77,
      result: { outcome: { outcome: "selected", optionId: "allow" } },
    });
    expect(proc.status).toBe("idle");
    proc.stop();
  });

  it("keeps a worker's request when the coordinator's turn ends or is interrupted", async () => {
    const { proc, transport, endTurn } = await startSwarm(appDataDir());
    transport.emit("message", {
      jsonrpc: "2.0",
      id: 78,
      method: "session/request_permission",
      params: {
        sessionId: WRITER_B,
        toolCall: { toolCallId: "worker_call_2", kind: "edit", title: "File b.txt" },
        options: [{ optionId: "allow", kind: "allow_once" }],
      },
    });
    proc.interrupt();
    expect(
      transport.written.some((m) => m.id === 78 && m.method === undefined),
    ).toBe(false);
    endTurn();
    await until(() => !proc.isTurnActive, "coordinator turn done");
    expect(proc.status).toBe("waiting_approval");
    expect(proc.getPendingPermission("worker_call_2")).toBeDefined();
    proc.stop();
  });

  it("answers a worker's request itself in bypass and under a session grant", async () => {
    const { proc, transport } = await startSwarm(appDataDir());
    await proc.setPermissionMode("bypassPermissions");
    transport.emit("message", {
      jsonrpc: "2.0",
      id: 79,
      method: "session/request_permission",
      params: {
        sessionId: WRITER_A,
        toolCall: { toolCallId: "worker_call_3", kind: "edit", title: "File a.txt" },
        options: [{ optionId: "allow", kind: "allow_once" }],
      },
    });
    expect(transport.written.at(-1)).toMatchObject({
      id: 79,
      result: { outcome: { outcome: "selected", optionId: "allow" } },
    });
    expect(proc.getPendingPermissions()).toEqual([]);
    proc.stop();
  });

  it("keeps what a worker does out of the coordinator's conversation", async () => {
    const { proc, messages, send, endTurn } = await startSwarm(appDataDir());
    endTurn();
    await until(() => proc.status === "idle", "coordinator turn done");
    const before = messages.length;
    send(WRITER_A, { sessionUpdate: "agent_message_chunk", content: { text: "worker talk" } });
    send(WRITER_A, { sessionUpdate: "current_mode_update", currentModeId: "plan" });
    send(WRITER_A, {
      sessionUpdate: "available_commands_update",
      availableCommands: [{ name: "only-for-workers" }],
    });
    send(WRITER_A, { sessionUpdate: "session_info_update", title: "worker title" });
    // Only the worker's current tool is reported, as its progress.
    send(WRITER_A, {
      sessionUpdate: "tool_call",
      toolCallId: "worker_call_4",
      kind: "read",
      title: "File a.txt",
      status: "in_progress",
    });
    expect(messages.slice(before).map((m) => m.type)).toEqual(["background_tasks"]);
    expect(proc.status).toBe("idle");
    expect(proc.permissionMode).toBe("default");
    expect(ofType(messages, "background_tasks").at(-1)?.tasks).toContainEqual({
      taskId: "swarm:writer_a",
      taskType: "antigravity_agent",
      subagentType: "swarm",
      description: "Swarm: writer_a",
      summary: "File a.txt",
    });
    proc.stop();
  });

  it("does not cut the coordinator's reply in pieces when a worker acts meanwhile", async () => {
    const appData = appDataDir();
    const { proc, transport, messages, update, endTurn, sync } = await startSwarm(appData);
    update({ sessionUpdate: "agent_message_chunk", content: { text: "Started writer_a " } });
    transport.emit("message", {
      jsonrpc: "2.0",
      id: 81,
      method: "session/request_permission",
      params: {
        sessionId: WRITER_A,
        toolCall: { toolCallId: "worker_call_6", kind: "edit", title: "File a.txt" },
        options: [{ optionId: "allow", kind: "allow_once" }],
      },
    });
    writeSwarm(
      appData,
      { writer_a: worker(WRITER_A, "working"), writer_b: worker(WRITER_B, "working") },
      [{ seq: 1, agent: "writer_b", text: "@coordinator [done]" }],
    );
    sync();
    // Held back while the sentence is still being written.
    expect(ofType(messages, "permission_request")).toEqual([]);
    expect(toolUses(messages).map((c) => c.name)).toEqual(["swarm"]);
    update({ sessionUpdate: "agent_message_chunk", content: { text: "and writer_b." } });
    endTurn();
    await until(() => !proc.isTurnActive, "coordinator turn done");
    const shown = ofType(messages, "assistant").flatMap((m) =>
      m.message.content.map((c) =>
        c.type === "text" ? c.text : c.type === "tool_use" ? c.name : c.type,
      ),
    );
    expect(shown).toEqual(["swarm", "Started writer_a and writer_b.", "FileChange", "SwarmPost"]);
    expect(ofType(messages, "permission_request")).toHaveLength(1);
    expect(proc.status).toBe("waiting_approval");
    proc.stop();
  });

  it("shows a worker's request after a few seconds even if the reply has not ended", async () => {
    const { proc, transport, messages, update } = await startSwarm(appDataDir());
    vi.useFakeTimers();
    try {
      update({ sessionUpdate: "agent_thought_chunk", content: { text: "thinking for long" } });
      transport.emit("message", {
        jsonrpc: "2.0",
        id: 82,
        method: "session/request_permission",
        params: {
          sessionId: WRITER_A,
          toolCall: { toolCallId: "worker_call_7", kind: "edit", title: "File a.txt" },
          options: [{ optionId: "allow", kind: "allow_once" }],
        },
      });
      expect(ofType(messages, "permission_request")).toEqual([]);
      vi.advanceTimersByTime(5_000);
      expect(ofType(messages, "permission_request")).toHaveLength(1);
      expect(proc.status).toBe("waiting_approval");
    } finally {
      vi.useRealTimers();
      proc.stop();
    }
  });

  it("declines a question from a worker instead of leaving it waiting", async () => {
    const { proc, transport } = await startSwarm(appDataDir());
    transport.emit("message", {
      jsonrpc: "2.0",
      id: 80,
      method: "elicitation/create",
      params: {
        sessionId: WRITER_A,
        mode: "form",
        requestedSchema: { properties: { q1: { type: "string", title: "Which?" } } },
      },
    });
    expect(transport.written.at(-1)).toEqual({
      jsonrpc: "2.0",
      id: 80,
      result: { action: "decline" },
    });
    proc.stop();
  });

  it("counts as still working while a worker is in a turn", async () => {
    const appData = appDataDir();
    const { proc, messages, endTurn, sync } = await startSwarm(appData);
    endTurn();
    await until(() => proc.status === "idle", "coordinator turn done");
    expect(proc.expectsFollowUp).toBe(true);
    expect(ofType(messages, "background_tasks").at(-1)?.tasks).toEqual([
      { taskId: "swarm:writer_a", taskType: "antigravity_agent", subagentType: "swarm", description: "Swarm: writer_a" },
      { taskId: "swarm:writer_b", taskType: "antigravity_agent", subagentType: "swarm", description: "Swarm: writer_b" },
    ]);

    writeSwarm(appData, {
      writer_a: worker(WRITER_A, "mentions"),
      writer_b: worker(WRITER_B, "working", true),
    });
    sync();
    expect(proc.expectsFollowUp).toBe(false);
    expect(ofType(messages, "background_tasks").at(-1)?.tasks).toEqual([]);
    proc.stop();
  });

  it("shows board posts in order and the coordinator's own posts once", async () => {
    const appData = appDataDir();
    const { proc, messages, tool, sync } = await startSwarm(appData);
    const before = toolUses(messages).length;
    writeSwarm(
      appData,
      { writer_a: worker(WRITER_A, "mentions"), writer_b: worker(WRITER_B, "working") },
      [
        { seq: 1, agent: "coordinator", text: "@writer_a write a", kind: "brief" },
        { seq: 2, agent: "writer_a", text: "@coordinator [done] wrote a", time: "2026-11-21 20:51:41" },
        { seq: 3, agent: "coordinator", text: "@writer_b status?" },
      ],
    );
    // The coordinator's post arrives as a tool call and as a board line.
    tool("call_2", "post_message", { text: "@writer_b status?" });
    sync();
    expect(toolUses(messages).slice(before)).toEqual([
      {
        type: "tool_use",
        id: `swarm-post:${COORDINATOR}:2`,
        name: "SwarmPost",
        input: {
          seq: 2,
          agent: "writer_a",
          text: "@coordinator [done] wrote a",
          time: "2026-11-21 20:51:41",
        },
      },
      {
        type: "tool_use",
        id: `swarm-post:${COORDINATOR}:3`,
        name: "SwarmPost",
        input: { seq: 3, agent: "coordinator", text: "@writer_b status?" },
      },
    ]);
    expect(ofType(messages, "tool_result").map((m) => m.toolUseId)).not.toContain("call_2");
    expect(ofType(messages, "tool_result").at(-1)).toMatchObject({
      toolUseId: `swarm-post:${COORDINATOR}:3`,
      toolName: "SwarmPost",
      content: "@writer_b status?",
    });
    proc.stop();
  });

  it("drops the terminal-only board hint from the reply", async () => {
    const { proc, messages, update, endTurn } = await startSwarm(appDataDir());
    update({
      sessionUpdate: "agent_message_chunk",
      content: {
        text: "Started two workers.\n\nRun /swarm board (default shortcut alt+s) to open the live board.",
      },
    });
    endTurn();
    await until(() => proc.status === "idle", "coordinator turn done");
    const texts = ofType(messages, "assistant").flatMap((m) =>
      m.message.content.flatMap((c) => (c.type === "text" ? [c.text] : [])),
    );
    expect(texts).toEqual(["Started two workers."]);
    expect(ofType(messages, "result").at(-1)?.result).toBe("Started two workers.");
    proc.stop();
  });

  it("picks a swarm up again on resume without replaying its board", async () => {
    const appData = appDataDir();
    writeSwarm(
      appData,
      { writer_a: worker(WRITER_A, "working"), writer_b: worker(WRITER_B, "mentions", true) },
      [{ seq: 1, agent: "writer_a", text: "@coordinator old news" }],
    );
    const { proc, messages, requests, send, sync } = await startSession(appData, {
      sessionId: COORDINATOR,
    });
    await until(() => requests("session/resume").length === 1, "live worker opened");
    expect(requests("session/resume")[0]).toMatchObject({ sessionId: WRITER_A });
    expect(toolUses(messages)).toEqual([]);
    // The roster still says "working" from the run that ended.
    expect(proc.expectsFollowUp).toBe(false);
    // Revived by a post, it is heard from again.
    send(WRITER_A, {
      sessionUpdate: "tool_call",
      toolCallId: "worker_call_5",
      kind: "read",
      title: "File a.txt",
      status: "in_progress",
    });
    expect(proc.expectsFollowUp).toBe(true);
    writeSwarm(
      appData,
      { writer_a: worker(WRITER_A, "working"), writer_b: worker(WRITER_B, "mentions", true) },
      [
        { seq: 1, agent: "writer_a", text: "@coordinator old news" },
        { seq: 2, agent: "writer_a", text: "@coordinator fresh" },
      ],
    );
    sync();
    expect(toolUses(messages).map((c) => (c.type === "tool_use" ? c.input.text : ""))).toEqual([
      "@coordinator fresh",
    ]);
    proc.stop();
  });

  it("leaves a session without a swarm alone", async () => {
    const { proc, requests } = await startSession(appDataDir());
    proc.sendInput("hello");
    expect(requests("session/resume")).toEqual([]);
    expect(proc.expectsFollowUp).toBe(false);
    proc.stop();
  });
});
