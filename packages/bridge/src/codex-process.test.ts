import { EventEmitter } from "node:events";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { spawnMock, fakeChildren } = vi.hoisted(() => ({
  spawnMock: vi.fn(),
  fakeChildren: [] as FakeChildProcess[],
}));

class FakeWritable extends EventEmitter {
  public writes: string[] = [];
  write(chunk: string): boolean {
    this.writes.push(chunk);
    this.emit("write", chunk);
    return true;
  }
}

class FakeReadable extends EventEmitter {
  setEncoding(_encoding: string): void {}
}

class FakeChildProcess extends EventEmitter {
  public stdout = new FakeReadable();
  public stderr = new FakeReadable();
  public stdin = new FakeWritable();
  public killed = false;

  kill(_signal?: NodeJS.Signals): boolean {
    this.killed = true;
    this.emit("exit", 0);
    return true;
  }
}

vi.mock("node:child_process", () => ({
  spawn: spawnMock,
}));

import { CodexProcess } from "./codex-process.js";

describe("CodexProcess (app-server)", () => {
  beforeEach(() => {
    spawnMock.mockReset();
    fakeChildren.length = 0;
    spawnMock.mockImplementation(() => {
      const child = new FakeChildProcess();
      fakeChildren.push(child);
      return child;
    });
  });

  afterEach(() => {
    for (const child of fakeChildren) {
      if (!child.killed) {
        child.kill();
      }
    }
  });

  it("starts codex app-server and sends initialize + thread/start", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-a", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "gpt-5.3-codex",
    });

    expect(spawnMock).toHaveBeenCalledTimes(1);
    expect(spawnMock).toHaveBeenCalledWith(
      "codex",
      ["app-server", "--listen", "stdio://"],
      expect.objectContaining({ cwd: "/tmp/project-a" }),
    );

    const child = fakeChildren[0];
    await tick();

    const initReq = nextOutgoingRequest(child);
    expect(initReq.method).toBe("initialize");
    child.stdout.emit("data", `${JSON.stringify({ id: initReq.id, result: {} })}\n`);

    await tick();
    const initialized = nextOutgoingNotification(child);
    expect(initialized.method).toBe("initialized");

    const startReq = nextOutgoingRequest(child);
    expect(startReq.method).toBe("thread/start");
    expect(startReq.params).toMatchObject({
      cwd: "/tmp/project-a",
      approvalPolicy: "on-request",
      sandbox: "workspace-write",
      model: "gpt-5.3-codex",
    });

    child.stdout.emit("data", `${JSON.stringify({ id: startReq.id, result: { thread: { id: "thr_1" } } })}\n`);
    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({ type: "system", subtype: "init", sessionId: "thr_1" }),
    );

    proc.stop();
  });

  it("emits permission_request and responds on approve", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-b");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: initReq.id, result: {} })}\n`);
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_2" } } })}\n`);

    await tick();
    drainSkillsList(child);
    proc.sendInput("run ls");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    expect(turnReq.method).toBe("turn/start");

    child.stdout.emit("data", `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_1" } } })}\n`);
    child.stdout.emit("data", `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_1" } } })}\n`);
    child.stdout.emit(
      "data",
      `${JSON.stringify({
        id: "req-approval-1",
        method: "item/commandExecution/requestApproval",
        params: {
          itemId: "item_cmd_1",
          command: "ls -la",
          cwd: "/tmp/project-b",
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "item_cmd_1",
        toolName: "Bash",
      }),
    );

    proc.approve("item_cmd_1");
    await tick();
    const approvalResponse = nextOutgoingResponse(child);
    expect(approvalResponse).toMatchObject({
      id: "req-approval-1",
      result: { decision: "accept" },
    });

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        method: "turn/completed",
        params: { turn: { id: "turn_1", status: "completed" } },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({ type: "result", subtype: "success", sessionId: "thr_2" }),
    );

    proc.stop();
  });

  it("emits AskUserQuestion and responds on answer", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-c");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: initReq.id, result: {} })}\n`);
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_3" } } })}\n`);

    await tick();
    drainSkillsList(child);
    proc.sendInput("ask me a question");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    expect(turnReq.method).toBe("turn/start");
    child.stdout.emit("data", `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_2" } } })}\n`);
    child.stdout.emit("data", `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_2" } } })}\n`);

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        id: "req-user-input-1",
        method: "item/tool/requestUserInput",
        params: {
          itemId: "item_user_input_1",
          questions: [
            {
              id: "q1",
              header: "Runtime",
              question: "Pick one option",
              options: [
                { label: "A", description: "Option A" },
                { label: "B", description: "Option B" },
              ],
            },
          ],
          threadId: "thr_3",
          turnId: "turn_2",
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "permission_request",
        toolUseId: "item_user_input_1",
        toolName: "AskUserQuestion",
      }),
    );

    proc.answer("item_user_input_1", "A");
    await tick();
    const answerResponse = nextOutgoingResponse(child);
    expect(answerResponse).toMatchObject({
      id: "req-user-input-1",
      result: {
        answers: {
          q1: { answers: ["A"] },
        },
      },
    });

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        method: "turn/completed",
        params: { turn: { id: "turn_2", status: "completed" } },
      })}\n`,
    );
    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({ type: "result", subtype: "success", sessionId: "thr_3" }),
    );

    proc.stop();
  });

  it("emits plan notifications as regular stream messages", async () => {
    const proc = new CodexProcess();
    const messages: unknown[] = [];
    proc.on("message", (msg) => messages.push(msg));

    proc.start("/tmp/project-d");
    const child = fakeChildren[0];

    await tick();
    const initReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: initReq.id, result: {} })}\n`);
    await tick();
    nextOutgoingNotification(child); // initialized
    const threadReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: threadReq.id, result: { thread: { id: "thr_4" } } })}\n`);

    await tick();
    drainSkillsList(child);
    proc.sendInput("make a plan");
    await tick();
    const turnReq = nextOutgoingRequest(child);
    child.stdout.emit("data", `${JSON.stringify({ id: turnReq.id, result: { turn: { id: "turn_3" } } })}\n`);
    child.stdout.emit("data", `${JSON.stringify({ method: "turn/started", params: { turn: { id: "turn_3" } } })}\n`);

    child.stdout.emit(
      "data",
      `${JSON.stringify({
        method: "item/plan/delta",
        params: { delta: "1. gather requirements" },
      })}\n`,
    );
    child.stdout.emit(
      "data",
      `${JSON.stringify({
        method: "turn/plan/updated",
        params: {
          explanation: "Initial plan drafted",
          plan: [{ step: "Gather requirements", status: "inProgress" }],
        },
      })}\n`,
    );

    await tick();

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "thinking_delta",
        text: "1. gather requirements",
      }),
    );
    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "assistant",
        message: expect.objectContaining({
          role: "assistant",
          content: expect.arrayContaining([
            expect.objectContaining({
              type: "text",
              text: expect.stringContaining("Plan update: Initial plan drafted"),
            }),
          ]),
        }),
      }),
    );

    proc.stop();
  });
});

function consumeOutgoing(
  child: FakeChildProcess,
  predicate: (value: Record<string, unknown>) => boolean,
): Record<string, unknown> {
  const lines = child.stdin.writes
    .flatMap((chunk) => chunk.split("\n"))
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const parsed = lines.map((line) => JSON.parse(line) as Record<string, unknown>);
  const index = parsed.findIndex(predicate);
  if (index < 0) {
    throw new Error("Expected outgoing JSON-RPC message was not found");
  }
  const remaining = lines.filter((_, lineIndex) => lineIndex !== index);
  child.stdin.writes = remaining.length > 0 ? [`${remaining.join("\n")}\n`] : [];

  return parsed[index];
}

function nextOutgoingRequest(child: FakeChildProcess): Record<string, unknown> {
  return consumeOutgoing(child, (value) => typeof value.method === "string" && value.id !== undefined);
}

/** Consume and reply to the background skills/list request that fires after thread/start. */
function drainSkillsList(child: FakeChildProcess): void {
  try {
    const req = consumeOutgoing(child, (value) => value.method === "skills/list" && value.id !== undefined);
    child.stdout.emit("data", `${JSON.stringify({ id: req.id, result: { data: [] } })}\n`);
  } catch {
    // skills/list may not have been emitted yet — safe to ignore
  }
}

function nextOutgoingNotification(child: FakeChildProcess): Record<string, unknown> {
  return consumeOutgoing(child, (value) => typeof value.method === "string" && value.id === undefined);
}

function nextOutgoingResponse(child: FakeChildProcess): Record<string, unknown> {
  return consumeOutgoing(child, (value) => value.id !== undefined && value.result !== undefined && value.method === undefined);
}

async function tick(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}
