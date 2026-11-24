// Replays TLC counterexample traces (out/trace-*.json) against the real
// SdkProcess class with a mocked SDK `query`, and compares the model state
// with the real object after every step.
//
// vitest globals (describe/it/expect/vi) are used because `vitest` cannot be
// imported from outside packages/bridge.
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { SdkProcess } from "../../../../packages/bridge/src/sdk-process.js";

const { mockSdkQuery } = vi.hoisted(() => ({ mockSdkQuery: vi.fn() }));
vi.mock("@anthropic-ai/claude-agent-sdk", async (importOriginal: any) => ({
  ...(await importOriginal()),
  query: mockSdkQuery,
}));

type ModelState = Record<string, any>;
interface Step { index: number; action: string; state: ModelState }

const flush = async () => {
  for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r));
};

interface Deferred { resolve: () => void; reject: (e: Error) => void }

/** A controllable stand-in for the SDK Query object. */
function makeQuery(args: any, modeCalls: Deferred[]) {
  const queue: Array<{ kind: "msg"; msg: unknown } | { kind: "end" } | { kind: "throw" }> = [];
  let wake: (() => void) | null = null;
  let closed = false;
  const instance = {
    prompt: args.prompt as AsyncGenerator<unknown>,
    canUseTool: args.options.canUseTool as (
      tool: string, input: Record<string, unknown>,
      opts: { signal: AbortSignal; toolUseID: string },
    ) => Promise<unknown>,
    push(item: (typeof queue)[number]) { queue.push(item); wake?.(); },
    async *[Symbol.asyncIterator]() {
      for (;;) {
        while (queue.length === 0) {
          if (closed) return;
          await new Promise<void>((r) => { wake = r; });
          wake = null;
        }
        const item = queue.shift()!;
        if (item.kind === "end") return;
        if (item.kind === "throw") throw new Error("iterator failed");
        yield item.msg;
      }
    },
    close: vi.fn(() => { closed = true; wake?.(); }),
    interrupt: vi.fn(async () => undefined),
    supportedCommands: vi.fn().mockResolvedValue([]),
    setPermissionMode: vi.fn(
      () => new Promise<void>((resolve, reject) => { modeCalls.push({ resolve, reject }); }),
    ),
  };
  return instance;
}

async function replay(steps: Step[]) {
  vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
  const proc = new SdkProcess();
  const internal = proc as any;
  const events: Array<[string, string]> = [];
  let reentrantId: string | null = null;
  proc.on("message", (m: any) => {
    if (m.type === "permission_request") {
      events.push(["req", m.toolUseId]);
      if (reentrantId === m.toolUseId) { reentrantId = null; proc.approve(m.toolUseId); }
    }
    if (m.type === "permission_resolved") events.push(["res", m.toolUseId]);
  });
  proc.on("exit", () => {});

  let query: ReturnType<typeof makeQuery> | null = null;
  let curModeCalls: Deferred[] = [];
  let oldModeCalls: Deferred[] = [];
  mockSdkQuery.mockImplementation((args: any) => {
    query = makeQuery(args, curModeCalls);
    return query;
  });
  const controllers = new Map<string, AbortController>();
  const settled = new Set<string>();
  const dir = process.cwd();

  const check = (step: Step) => {
    const s = step.state;
    const where = `after state ${step.index} (${step.action})`;
    expect(proc.status, `status ${where}`).toBe(s.status);
    expect(proc.getPendingPermissions().map((p) => p.toolUseId).sort(), `pending ${where}`)
      .toEqual([...s.pending].sort());
    expect(internal.pendingInputQueue.length, `qlen ${where}`).toBe(s.qlen);
    expect(internal.stopped, `stopped ${where}`).toBe(s.stopped);
    expect(proc.isRunning, `query ${where}`).toBe(s.query === "live");
    expect(proc.isWaitingForInput, `resolver ${where}`).toBe(s.resolver !== "none");
    expect(proc.permissionMode ?? "default", `mode ${where}`).toBe(s.mode);
    for (const [id, p] of Object.entries(s.prom)) {
      expect(settled.has(id), `promise ${id} ${where}`).toBe(p === "settled");
    }
    // Events emitted so far = events the model client received + events still in flight.
    const view = new Set<string>();
    for (const [kind, id] of events) kind === "req" ? view.add(id) : view.delete(id);
    const modelView = new Set<string>(s.cview);
    for (const [kind, id] of s.chan) kind === "req" ? modelView.add(id) : modelView.delete(id);
    if (s.announcing === "NONE") {
      expect([...view].sort(), `client view ${where}`).toEqual([...modelView].sort());
    }
  };

  for (let i = 0; i < steps.length; i++) {
    const step = steps[i];
    const prev = i > 0 ? steps[i - 1].state : null;
    const s = step.state;
    switch (step.action) {
      case "Initial predicate":
        proc.start(dir, { permissionMode: s.mode });
        break;
      case "Input": {
        // websocket/handlers/session-input.ts:423-451
        const r = proc.dispatchInput("hello");
        if (r.shouldInterrupt) proc.interrupt();
        break;
      }
      case "Interrupt": proc.interrupt(); break;
      case "DecideSeen":
      case "DecideBlind": {
        const id = prev!.pending.find((p: string) => !s.pending.includes(p));
        expect(proc.approve(id)).toBe(true);
        break;
      }
      case "CanUseBegin": {
        const id = s.announcing as string;
        const ctrl = new AbortController();
        controllers.set(id, ctrl);
        if (s.annAborted) ctrl.abort();
        // The rest of waitForPermission is synchronous: find out now whether a
        // listener answers during the emit.
        let j = i + 1;
        while (steps[j] && steps[j].action === "ClientRecv") j++;
        if (steps[j]?.action === "ReentrantDecide") reentrantId = id;
        void query!.canUseTool("Bash", { command: "ls" }, { signal: ctrl.signal, toolUseID: id })
          .then(() => settled.add(id));
        break;
      }
      case "ReentrantDecide":
      case "CanUseEnd":
      case "ClientRecv":
      case "Terminated":
        break;                                   // already done / nothing to do
      case "Abort": {
        const id = prev!.pending.find((p: string) => !s.pending.includes(p));
        controllers.get(id)!.abort();
        break;
      }
      case "SdkPull": void query!.prompt.next(); break;
      case "InitDone":
        query!.push({ kind: "msg", msg: { type: "system", subtype: "init", session_id: "s", model: "m", apiKeySource: "user" } });
        break;
      case "Frame":
        query!.push({ kind: "msg", msg: { type: "assistant", parent_tool_use_id: null, message: { role: "assistant", content: [{ type: "text", text: "hi" }] } } });
        break;
      case "SysStatus":
        query!.push({ kind: "msg", msg: { type: "system", subtype: "status", status: s.status === "compacting" ? "compacting" : "requesting" } });
        break;
      case "SdkMode":
        query!.push({ kind: "msg", msg: { type: "system", subtype: "status", permissionMode: s.mode } });
        break;
      case "Result":
        query!.push({ kind: "msg", msg: { type: "result", subtype: "success", result: "Done", total_cost_usd: 0, duration_ms: 1, session_id: "s" } });
        break;
      case "NaturalEnd": query!.push({ kind: "end" }); break;
      case "Crash": query!.push({ kind: "throw" }); break;
      case "SetMode": {
        const m = s.chain.length > prev!.chain.length ? s.chain[s.chain.length - 1].mode : s.mode;
        proc.setPermissionMode(m).catch(() => {});
        break;
      }
      case "ModeReturn": {
        const isOld = s.old.length < prev!.old.length || JSON.stringify(s.old) !== JSON.stringify(prev!.old);
        const calls = isOld ? oldModeCalls : curModeCalls;
        const head = (isOld ? prev!.old : prev!.chain)[0];
        const d = calls.shift()!;
        if (s.mode === head.mode) d.resolve(); else d.reject(new Error("rejected"));
        break;
      }
      case "Start": {
        oldModeCalls = curModeCalls;
        curModeCalls = [];
        proc.start(dir, s.mode !== prev!.mode ? { permissionMode: s.mode } : {});
        break;
      }
      case "ClientStop": proc.stop(); break;
      default: throw new Error(`no mapping for action ${step.action}`);
    }
    await flush();
    if (s.announcing === "NONE") check(step);
  }
  proc.stop();
  vi.unstubAllEnvs();
}

const outDir = join(dirname(fileURLToPath(import.meta.url)), "..", "out");
const traces = readdirSync(outDir).filter((f) => /^trace-.*\.json$/.test(f)).sort();

// Random behaviours of the model (TLC -simulate): conformance of the model
// with the code beyond the counterexamples.
describe("random model behaviours replayed on the real SdkProcess", () => {
  const files = readdirSync(outDir).filter((f) => /^sim.*traces\.json$/.test(f)).sort();
  it.each(files)("%s", async (file) => {
    const sims: Step[][] = JSON.parse(readFileSync(join(outDir, file), "utf8"));
    const failures: string[] = [];
    let stepCount = 0;
    for (let n = 0; n < sims.length; n++) {
      stepCount += sims[n].length;
      try { await replay(sims[n]); }
      catch (e) { failures.push(`trace ${n}: ${(e as Error).message.split("\n")[0]}`); }
    }
    console.log(`replayed ${file}: ${sims.length} traces, ${stepCount} states, ${failures.length} mismatches`);
    expect(failures).toEqual([]);
  }, 300_000);
});

describe("TLC counterexamples replayed on the real SdkProcess", () => {
  it.each(traces)("%s", async (file) => {
    const trace = JSON.parse(readFileSync(join(outDir, file), "utf8"));
    await replay(trace.steps);
  });
});
