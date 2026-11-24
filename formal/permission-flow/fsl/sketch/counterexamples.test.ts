/**
 * Sketch (not part of the Bridge test suite): each test replays one FSL
 * counterexample against the real SdkProcess and asserts the INTENDED property
 * from formal/permission-flow/SCOPE.md. A test that FAILS here means the
 * counterexample is reproduced on the current code.
 *
 * Run from the repo root:
 *   packages/bridge/node_modules/.bin/vitest run --root formal/permission-flow/fsl/sketch
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { SdkProcess } from "../../../../packages/bridge/src/sdk-process.js";
import type { ServerMessage } from "../../../../packages/bridge/src/parser.js";

const { mockSdkQuery } = vi.hoisted(() => ({ mockSdkQuery: vi.fn() }));

vi.mock("@anthropic-ai/claude-agent-sdk", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@anthropic-ai/claude-agent-sdk")>()),
  query: mockSdkQuery,
}));

type AnyProc = any;

function collect(proc: SdkProcess): ServerMessage[] {
  const messages: ServerMessage[] = [];
  proc.on("message", (m) => messages.push(m));
  return messages;
}

/** Client view built only from permission_request / permission_resolved (SCOPE P4). */
function clientPending(messages: ServerMessage[]): string[] {
  const set = new Set<string>();
  for (const m of messages as any[]) {
    if (m.type === "permission_request") set.add(m.toolUseId);
    if (m.type === "permission_resolved") set.delete(m.toolUseId);
  }
  return [...set];
}

function bridgePending(proc: SdkProcess): string[] {
  return proc.getPendingPermissions().map((p) => p.toolUseId);
}

function ask(proc: SdkProcess, id: string, signal = new AbortController().signal) {
  return (proc as AnyProc).waitForPermission(id, "Bash", { command: "ls" }, signal) as Promise<unknown>;
}

/** A controllable stand-in for the SDK query(): the test decides when frames arrive and when the stream ends. */
function fakeQuery() {
  const frames: any[] = [];
  let wake: (() => void) | null = null;
  let ended = false;
  const q: any = {
    prompt: null as AsyncGenerator<any> | null,
    push(frame: any) { frames.push(frame); wake?.(); },
    end() { ended = true; wake?.(); },
    async *[Symbol.asyncIterator]() {
      for (;;) {
        while (frames.length > 0) yield frames.shift();
        if (ended) return;
        await new Promise<void>((r) => { wake = r; });
        wake = null;
      }
    },
    close: vi.fn(() => { ended = true; wake?.(); }),
    interrupt: vi.fn(() => Promise.resolve()),
    stopTask: vi.fn(() => Promise.resolve()),
    setPermissionMode: vi.fn(() => Promise.resolve()),
    supportedCommands: vi.fn().mockResolvedValue([]),
    initializationResult: vi.fn().mockResolvedValue({ account: { apiKeySource: "user" }, models: [] }),
  };
  return q;
}

const tick = () => new Promise((r) => setTimeout(r, 5));

beforeEach(() => {
  mockSdkQuery.mockReset();
  vi.unstubAllEnvs();
  vi.stubEnv("ANTHROPIC_API_KEY", "sk-test");
});

describe("FSL counterexamples replayed on SdkProcess", () => {
  it("CE-1 (P1a): system/status requesting must not leave waiting_approval while a request is pending", () => {
    const proc = new SdkProcess();
    void ask(proc, "tool-1");
    expect(proc.status).toBe("waiting_approval");
    (proc as AnyProc).updateStatusFromMessage({ type: "system", subtype: "status", status: "requesting" });
    expect(bridgePending(proc)).toEqual(["tool-1"]);
    expect(proc.status).toBe("waiting_approval"); // intended (P1a)
  });

  it("CE-1b (P1a): system/status compacting must not leave waiting_approval while a request is pending", () => {
    const proc = new SdkProcess();
    void ask(proc, "tool-1");
    (proc as AnyProc).updateStatusFromMessage({ type: "system", subtype: "status", status: "compacting" });
    expect(proc.status).toBe("waiting_approval"); // intended (P1a)
  });

  it("CE-2 (P1b, P4): an aborted request leaves waiting_approval and is resolved for the client", async () => {
    const proc = new SdkProcess();
    const messages = collect(proc);
    const ac = new AbortController();
    const p = ask(proc, "tool-1", ac.signal);
    ac.abort();
    await expect(p).resolves.toMatchObject({ behavior: "deny" });
    expect(bridgePending(proc)).toEqual([]);
    expect.soft(clientPending(messages)).toEqual([]);     // intended (P4)
    expect.soft(proc.status).not.toBe("waiting_approval"); // intended (P1b)
  });

  it("CE-3 (P1b, P4): a request whose signal is already aborted is not left visible to the client", async () => {
    const proc = new SdkProcess();
    const messages = collect(proc);
    const ac = new AbortController();
    ac.abort();
    const p = ask(proc, "tool-1", ac.signal);
    await expect(p).resolves.toMatchObject({ behavior: "deny" });
    expect(bridgePending(proc)).toEqual([]);
    expect.soft(clientPending(messages)).toEqual([]);     // intended (P4)
    expect.soft(proc.status).not.toBe("waiting_approval"); // intended (P1b)
  });

  it("CE-4 (P3): the SDK promise is resolved at most once (pre-aborted + synchronous listener answer)", async () => {
    const proc = new SdkProcess();
    proc.on("message", (m: any) => {
      if (m.type === "permission_request") proc.approve(m.toolUseId);
    });
    const ac = new AbortController();
    ac.abort();
    // Count calls of the resolve function of the promise created in waitForPermission.
    const Native = globalThis.Promise;
    let resolveCalls = 0;
    class Counting<T> extends Native<T> {
      constructor(executor: (res: (v: T | PromiseLike<T>) => void, rej: (e?: unknown) => void) => void) {
        super((res, rej) => executor((v) => { resolveCalls += 1; res(v); }, rej));
      }
      static get [Symbol.species]() { return Native; }
    }
    (globalThis as any).Promise = Counting;
    let p: Promise<unknown>;
    try {
      p = ask(proc, "tool-1", ac.signal);
    } finally {
      (globalThis as any).Promise = Native;
    }
    await p;
    expect(resolveCalls).toBe(1); // intended (P3)
  });

  it("CE-5 (P1b, P4): interrupt() leaves waiting_approval and resolves the request for the client", () => {
    const proc = new SdkProcess();
    const messages = collect(proc);
    (proc as AnyProc).queryInstance = { interrupt: vi.fn(() => Promise.resolve()), stopTask: vi.fn(() => Promise.resolve()) };
    void ask(proc, "tool-1");
    proc.interrupt();
    expect(bridgePending(proc)).toEqual([]);
    expect.soft(clientPending(messages)).toEqual([]);     // intended (P4)
    expect.soft(proc.status).not.toBe("waiting_approval"); // intended (P1b)
  });

  it("CE-6 (P4): a turn result resolves a still-pending request for the client", () => {
    const proc = new SdkProcess();
    const messages = collect(proc);
    void ask(proc, "tool-1");
    (proc as AnyProc).updateStatusFromMessage({ type: "result", subtype: "success" });
    expect(bridgePending(proc)).toEqual([]);
    expect.soft(clientPending(messages)).toEqual([]);     // intended (P4)
  });

  it("CE-7 (P5): input sent after stop() is not queued", () => {
    const proc = new SdkProcess();
    proc.stop();
    proc.sendInput("late");
    expect(proc.hasInputQueue).toBe(false);               // intended (P5)
  });

  it("CE-8 (P1a): when the SDK stream ends by itself, a pending request does not stay in the table", async () => {
    const proc = new SdkProcess();
    const exits: Array<number | null> = [];
    proc.on("exit", (c) => exits.push(c));
    const q = fakeQuery();
    mockSdkQuery.mockImplementationOnce((args: any) => { q.prompt = args.prompt; return q; });
    proc.start(process.cwd());
    await tick();
    void ask(proc, "tool-1");
    q.end();
    await vi.waitFor(() => expect(exits).toEqual([0]));
    expect(proc.status).toBe("idle");
    expect(bridgePending(proc)).toEqual([]);              // intended (P1a)
  });

  it("CE-9 (P8): after a natural stream end and a restart, input is delivered to the new query", async () => {
    const proc = new SdkProcess();
    const exits: Array<number | null> = [];
    proc.on("exit", (c) => exits.push(c));
    const q1 = fakeQuery();
    mockSdkQuery.mockImplementationOnce((args: any) => { q1.prompt = args.prompt; return q1; });
    proc.start(process.cwd());
    await tick();
    void q1.prompt!.next();            // SDK pulls: the generator parks (userMessageResolve set)
    await tick();
    expect(proc.isWaitingForInput).toBe(true);
    q1.end();                          // natural end: resolver is kept
    await vi.waitFor(() => expect(exits).toEqual([0]));

    const q2 = fakeQuery();
    mockSdkQuery.mockImplementationOnce((args: any) => { q2.prompt = args.prompt; return q2; });
    proc.start(process.cwd());         // restart on the same object (session.ts:2387 does this)
    proc.sendInput("hello");           // before the new SDK pulled
    const pulled = q2.prompt!.next();  // the new SDK asks for input
    const got = await Promise.race([pulled, tick().then(() => "nothing")]);
    expect(got).not.toBe("nothing");   // intended (P8): the new query receives "hello"
    proc.stop();
  });
});

describe("outside SCOPE (background agents) and conditional on SDK behaviour", () => {
  it("OUT-1 (P8 under E_PROMPT_OUT_OF_TURN): a canUseTool arriving after the turn's result does not strand later input", async () => {
    const proc = new SdkProcess();
    const q = fakeQuery();
    let canUseTool: any;
    mockSdkQuery.mockImplementationOnce((args: any) => { q.prompt = args.prompt; canUseTool = args.options.canUseTool; return q; });
    proc.start(process.cwd());
    await tick();
    void q.prompt!.next();                 // SDK waits for input
    await tick();
    proc.sendInput("first");               // turn starts
    void q.prompt!.next();                 // SDK asks again; generator parks (turn in progress)
    await tick();
    q.push({ type: "result", subtype: "success", result: "ok", duration_ms: 1, session_id: "s" });
    await vi.waitFor(() => expect(proc.status).toBe("idle"));

    // a background agent asks for permission although no main turn is active
    const p = canUseTool("Bash", { command: "ls" }, { signal: new AbortController().signal, toolUseID: "bg-1" });
    expect(proc.status).toBe("waiting_approval");
    proc.approve("bg-1");
    await p;
    const statusAfterApprove = proc.status; // "running" (sdk-process.ts:2254-2256) although no turn runs

    proc.sendInput("second");              // queued because status says a turn is active
    await tick();
    expect.soft(statusAfterApprove).toBe("idle");
    expect.soft(proc.hasInputQueue).toBe(false); // intended (P8): "second" reaches the SDK
    proc.stop();
  });
});

describe("controls (must pass: they show the harness itself works)", () => {
  it("approve() resolves the request for the client and leaves waiting_approval", async () => {
    const proc = new SdkProcess();
    const messages = collect(proc);
    const p = ask(proc, "tool-1");
    expect(proc.status).toBe("waiting_approval");
    expect(clientPending(messages)).toEqual(["tool-1"]);
    expect(proc.approve("tool-1")).toBe(true);
    await expect(p).resolves.toMatchObject({ behavior: "allow" });
    expect(clientPending(messages)).toEqual([]);
    expect(bridgePending(proc)).toEqual([]);
    expect(proc.status).toBe("running");
  });

  it("without a natural stream end, input sent before the first pull reaches the query", async () => {
    const proc = new SdkProcess();
    const q = fakeQuery();
    mockSdkQuery.mockImplementationOnce((args: any) => { q.prompt = args.prompt; return q; });
    proc.start(process.cwd());
    proc.sendInput("hello");
    const got: any = await Promise.race([q.prompt!.next(), tick().then(() => "nothing")]);
    expect(got).not.toBe("nothing");
    expect(got.value.message.content[0].text).toBe("hello");
    proc.stop();
  });

  it("a stopped process ignores a late approve()", () => {
    const proc = new SdkProcess();
    void ask(proc, "tool-1");
    proc.stop();
    expect(proc.approve("tool-1")).toBe(false);
    expect(proc.status).toBe("idle");
    expect(bridgePending(proc)).toEqual([]);
  });
});
