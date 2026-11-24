// Quint の ITF トレース (quint run --mbt --out-itf) を、SDK の query を差し替えた本物の SdkProcess に
// 1 ステップずつ流し、モデルの状態と実装の状態を突き合わせる。
// packages/ 以下には何も置かない。実行は run.sh の replay 段:
//   packages/bridge/node_modules/.bin/vitest run --config formal/permission-flow/quint/repro/vitest.config.mjs
// 環境変数 ITF_DIR に ITF の置き場 (既定は ../out/itf)。
import { readdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { mockSdkQuery } = vi.hoisted(() => ({ mockSdkQuery: vi.fn() }));

vi.mock("@anthropic-ai/claude-agent-sdk", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@anthropic-ai/claude-agent-sdk")>()),
  query: mockSdkQuery,
}));

import { SdkProcess } from "../../../../packages/bridge/src/sdk-process.js";

// ---------- ITF の読み取り ----------

const conv = (v: any): any => {
  if (v === null || typeof v !== "object") return v;
  if (Array.isArray(v)) return v.map(conv);
  if ("#bigint" in v) return Number(v["#bigint"]);
  if ("#set" in v) return v["#set"].map(conv).sort();
  if ("#map" in v) return Object.fromEntries(v["#map"].map(([k, x]: any[]) => [conv(k), conv(x)]));
  if ("#tup" in v) return v["#tup"].map(conv);
  return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, conv(x)]));
};

interface Step {
  action: string;
  picks: Record<string, any>;
  model: any;
}

function loadTrace(file: string): Step[] {
  const itf = JSON.parse(readFileSync(file, "utf8"));
  return itf.states.map((raw: any) => {
    const key = Object.keys(raw).find((k) => k === "s" || k.endsWith("::s"))!;
    const picks: Record<string, any> = {};
    for (const [name, opt] of Object.entries<any>(raw["mbt::nondetPicks"] ?? {})) {
      if (opt.tag === "Some") picks[name] = conv(opt.value);
    }
    return { action: raw["mbt::actionTaken"], picks, model: conv(raw[key]) };
  });
}

// ---------- 差し替えた SDK query ----------

interface Deferred {
  mode: string;
  resolve: () => void;
  reject: (e: Error) => void;
}

function makeQuery(args: any, modeCalls: Deferred[]) {
  const buffered: unknown[] = [];
  let wake: (() => void) | null = null;
  let ended = false;
  let error: Error | null = null;
  const kick = () => {
    const w = wake;
    wake = null;
    w?.();
  };
  return {
    promptIter: (args.prompt as AsyncIterable<unknown>)[Symbol.asyncIterator](),
    canUseTool: args.options.canUseTool as (
      toolName: string,
      input: Record<string, unknown>,
      options: { signal: AbortSignal; toolUseID: string },
    ) => Promise<unknown>,
    delivered: 0,
    push(msg: unknown) {
      buffered.push(msg);
      kick();
    },
    end() {
      ended = true;
      kick();
    },
    fail(e: Error) {
      error = e;
      kick();
    },
    api: {
      async *[Symbol.asyncIterator]() {
        for (;;) {
          if (buffered.length > 0) {
            yield buffered.shift();
            continue;
          }
          if (error) throw error;
          if (ended) return;
          await new Promise<void>((r) => (wake = r));
        }
      },
      close: () => {
        ended = true;
        kick();
      },
      interrupt: async () => {},
      stopTask: async () => {},
      supportedCommands: async () => [],
      setPermissionMode: (mode: string) =>
        new Promise<void>((resolve, reject) => {
          modeCalls.push({ mode, resolve, reject });
        }),
    },
  };
}

const SESSION = "replay-session";
const sdkMessage = {
  assistant: () => ({
    type: "assistant",
    session_id: SESSION,
    parent_tool_use_id: null,
    message: { role: "assistant", content: [{ type: "text", text: "ok" }] },
  }),
  user: () => ({
    type: "user",
    session_id: SESSION,
    parent_tool_use_id: null,
    message: {
      role: "user",
      content: [{ type: "tool_result", tool_use_id: "other-tool", content: "done" }],
    },
  }),
  system: (status: string | null) => ({
    type: "system",
    subtype: "status",
    status,
    session_id: SESSION,
  }),
  result: () => ({
    type: "result",
    subtype: "success",
    result: "Done",
    duration_ms: 1,
    session_id: SESSION,
  }),
};

const flush = async () => {
  for (let i = 0; i < 6; i++) await new Promise<void>((r) => setImmediate(r));
};

// ---------- 再生 ----------

async function replay(steps: Step[]): Promise<string[]> {
  const proc = new SdkProcess();
  const internal = proc as any;
  const modeCalls: Deferred[] = [];
  const queries: ReturnType<typeof makeQuery>[] = [];
  mockSdkQuery.mockImplementation((args: any) => {
    const q = makeQuery(args, modeCalls);
    queries.push(q);
    return q.api;
  });

  // クライアントの見え方を、届いたメッセージから組み立てる
  const clientStrict = new Set<string>();
  const clientApp = new Set<string>();
  let reentrantId: string | null = null;
  proc.on("message", (msg: any) => {
    if (msg.type === "permission_request") {
      clientStrict.add(msg.toolUseId);
      clientApp.add(msg.toolUseId);
      if (reentrantId === msg.toolUseId) {
        reentrantId = null;
        proc.approve(msg.toolUseId);
      }
    } else if (msg.type === "permission_resolved") {
      clientStrict.delete(msg.toolUseId);
      clientApp.delete(msg.toolUseId);
    } else if (msg.type === "status" && (msg.status === "idle" || msg.status === "starting")) {
      clientApp.clear();
    }
  });

  const aborts = new Map<string, AbortController>();
  const promise = new Map<string, "waiting" | "settled">();
  const cwd = tmpdir();
  const current = () => queries[queries.length - 1];
  const mismatches: string[] = [];
  let lostInput = false;

  proc.start(cwd);
  const genBase = internal.permissionModeGeneration as number;
  await flush();

  for (let n = 1; n < steps.length; n++) {
    const { action, picks, model } = steps[n];
    const before = steps[n - 1].model;
    switch (action) {
      case "InitDone":
        vi.advanceTimersByTime(3000); // init メッセージ待ちのタイマー (sdk-process.ts:1256)
        break;
      case "SdkPull": {
        const q = current();
        void q.promptIter.next().then((r) => {
          if (r.done) return;
          q.delivered += 1;
          // もう使われていない query のストリームに入力が出てきた = 誰にも読まれない
          if (q !== current() || !proc.isRunning) lostInput = true;
        });
        break;
      }
      case "SdkCanUseTool": {
        const id = picks.id as string;
        const ac = new AbortController();
        aborts.set(id, ac);
        if (picks.preAborted) ac.abort();
        if (picks.reentrant) reentrantId = id;
        const ask = id === "q";
        promise.set(id, "waiting");
        void current()
          .canUseTool(
            ask ? "AskUserQuestion" : "Bash",
            ask ? { questions: [{ question: "Which?", options: [] }] } : { command: "ls" },
            { signal: ac.signal, toolUseID: id },
          )
          .then(() => promise.set(id, "settled"));
        reentrantId = null;
        break;
      }
      case "SdkAbort":
        aborts.get(picks.id)!.abort();
        break;
      case "SdkAssistant":
        current().push(sdkMessage.assistant());
        break;
      case "SdkUser":
        current().push(sdkMessage.user());
        break;
      case "SdkSystem":
        current().push(sdkMessage.system(picks.kind === "null" ? null : picks.kind));
        break;
      case "SdkResult":
        current().push(sdkMessage.result());
        break;
      case "SdkError":
        current().fail(new Error("stream failed"));
        break;
      case "SdkNaturalEnd":
        current().end();
        break;
      case "ModeReturn": {
        // モデルの ops[i] (await 中) に対応する、まだ返っていない SDK 呼び出しを呼び出し順で選ぶ
        const awaitingBefore = before.ops
          .slice(0, picks.i)
          .filter((op: any) => op.q >= 0).length;
        const [call] = modeCalls.splice(awaitingBefore, 1);
        if (picks.ok) call.resolve();
        else call.reject(new Error("setPermissionMode failed"));
        break;
      }
      case "ClientInput": {
        // handleInput の旧来の経路 (websocket/handlers/session-input.ts:426, 446-450)
        const r = proc.dispatchInput("hello");
        if (r.shouldInterrupt) proc.interrupt();
        break;
      }
      case "ClientApprove":
        proc.approve(picks.id);
        break;
      case "ClientReject":
        proc.reject(picks.id);
        break;
      case "ClientApproveAlways":
        proc.approveAlways(picks.id);
        break;
      case "ClientAnswer":
        proc.answer(picks.id, "answer");
        break;
      case "ClientSetMode":
        proc.setPermissionMode(picks.m).catch(() => {});
        break;
      case "ClientInterrupt":
        proc.interrupt();
        break;
      case "ClientStop":
        proc.stop();
        break;
      case "Restart":
        proc.start(cwd, {
          permissionMode: picks.m,
          ...(picks.withInit ? { initialInput: "initial" } : {}),
        });
        break;
      case "Stutter":
        break;
      default:
        throw new Error(`unknown action ${action}`);
    }
    await flush();

    const real = {
      status: proc.status,
      pending: proc.getPendingPermissions().map((p) => p.toolUseId).sort(),
      queueLen: internal.pendingInputQueue.length,
      waiterSet: internal.userMessageResolve !== null,
      stopped: internal.stopped,
      queryAlive: proc.isRunning,
      mode: proc.permissionMode ?? "default",
      gen: internal.permissionModeGeneration - genBase,
      sdkPromise: Object.fromEntries(
        Object.keys(model.sdkPromise).map((id) => [id, promise.get(id) ?? "unused"]),
      ),
      clientStrict: [...clientStrict].sort(),
      clientApp: [...clientApp].sort(),
      modeCallsOutstanding: modeCalls.length,
      lostInput,
    };
    const expected = {
      status: model.status,
      pending: model.pending,
      queueLen: model.queueLen,
      waiterSet: model.waiter !== -1,
      stopped: model.stopped,
      queryAlive: model.queryAlive,
      mode: model.mode,
      gen: model.gen,
      sdkPromise: model.sdkPromise,
      clientStrict: model.clientStrict,
      clientApp: model.clientApp,
      modeCallsOutstanding: model.ops.filter((op: any) => op.q >= 0).length,
      lostInput: model.lostInput,
    };
    for (const key of Object.keys(expected) as (keyof typeof expected)[]) {
      const a = JSON.stringify(real[key]);
      const b = JSON.stringify(expected[key]);
      if (a !== b) {
        mismatches.push(
          `step ${n} ${action}(${JSON.stringify(picks)}): ${key} 実装=${a} モデル=${b}`,
        );
      }
    }
    if (mismatches.length > 0) break; // 以後はずれたままなので最初の食い違いで止める
  }

  proc.stop();
  await flush();
  return mismatches;
}

const dir = process.env.ITF_DIR ?? join(import.meta.dirname, "..", "out", "itf");
const files = readdirSync(dir)
  .filter((f) => f.endsWith(".itf.json"))
  .sort();

describe("Quint のトレースを SdkProcess で再生する", () => {
  beforeEach(() => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    vi.spyOn(console, "log").mockImplementation(() => {});
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllEnvs();
    vi.restoreAllMocks();
    mockSdkQuery.mockReset();
  });

  it.each(files)("%s", async (file) => {
    const steps = loadTrace(join(dir, file));
    const mismatches = await replay(steps);
    expect(mismatches).toEqual([]);
  });
});
