import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CodexProcess, CodexRpcError } from "./codex-process.js";

// Real input loop/controller, deterministic RPC responses, no model calls.
describe("CodexProcess recovery integration", () => {
  const processes: CodexProcess[] = [];
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => { processes.forEach((p) => p.stop()); processes.length = 0; vi.useRealTimers(); });
  async function flush() { for (let i = 0; i < 30; i++) await Promise.resolve(); }
  function setup() {
    const proc = new CodexProcess("linux"); processes.push(proc);
    const internal = proc as any; internal._threadId = "thread-test";
    const messages: any[] = []; proc.on("message", (m) => messages.push(m));
    vi.spyOn(proc, "readRateLimits").mockResolvedValue({ rateLimits: {} });
    vi.spyOn(proc, "getGoal").mockResolvedValue(null);
    const input = vi.spyOn(internal, "toRpcInput").mockImplementation(async (value: any) => ({ input: [{ type: "text", text: value.text }], tempPaths: [] }));
    const request = vi.spyOn(internal, "request").mockResolvedValue({ turn: { id: "turn-test" } });
    proc.setRecoveryEnabled(true); void internal.runInputLoop();
    return { proc, internal, messages, request, input };
  }
  it("retries a pre-start 429 with all original structured input", async () => {
    const { proc, request, input } = setup();
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429, message: "HTTP 429" }));
    const options = { images: [{ base64: "aW1hZ2U=", mimeType: "image/png" }], skills: [{ name: "skill", path: "/skill" }], mentions: [{ name: "app", path: "app://test" }] };
    proc.sendInputStructured("task", options); await flush();
    expect(proc.getRecoveryState().phase).toBe("waiting");
    await vi.advanceTimersByTimeAsync(10_000);
    expect(request).toHaveBeenCalledTimes(2);
    expect(input).toHaveBeenLastCalledWith(expect.objectContaining({ text: "task", ...options }));
    expect(proc.getRecoveryState().attempts).toBe(1);
  });
  it("continues a failed started turn once with a visible continuation", async () => {
    const { proc, internal, request, messages } = setup();
    proc.sendInput("original task"); await flush();
    const turn = { id: "turn-test", status: "failed", error: { message: "usage limit" } };
    internal.handleTurnCompleted(turn); internal.handleTurnCompleted(turn); await flush();
    await vi.advanceTimersByTimeAsync(10_000);
    expect(request).toHaveBeenCalledTimes(2);
    expect((request.mock.calls[1][1] as any).input[0].text).toContain("Do not repeat completed work");
    expect(messages.filter((m) => m.type === "user_input" && m.text.startsWith("Automatic recovery:"))).toHaveLength(1);
  });
  it.each(["interrupt", "manual", "queue", "goal"])("cancels waiting recovery via %s", async (action) => {
    const { proc, internal, request } = setup();
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    proc.sendInput("task"); await flush();
    if (action === "interrupt") proc.interrupt();
    if (action === "queue") proc.noteManualInput();
    if (action === "manual") proc.sendInput("manual replacement");
    if (action === "goal") internal.handleNotification("thread/goal/updated", { goal: { threadId: "thread-test", objective: "task", status: "paused", tokensUsed: 0, timeUsedSeconds: 0, createdAt: 0, updatedAt: 0, tokenBudget: null } });
    await vi.advanceTimersByTimeAsync(60_000);
    expect(request).toHaveBeenCalledTimes(action === "manual" ? 2 : 1);
    expect(proc.getRecoveryState().attempts).toBe(0);
  });
  it.each(["paused", "blocked", "budgetLimited", "complete"])("does not resume a %s goal", async (status) => {
    const { proc, request } = setup(); vi.mocked(proc.getGoal).mockResolvedValue({ status } as any);
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    proc.sendInput("task"); await flush(); await vi.advanceTimersByTimeAsync(10_000);
    expect(request).toHaveBeenCalledTimes(1); expect(proc.getRecoveryState().phase).toBe("blocked");
  });
  it.each(["approval", "plan", "question"])("does not resume during %s", async (pending) => {
    const { proc, internal, request } = setup();
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    proc.sendInput("task"); await flush();
    if (pending === "approval") internal.pendingApprovals.set("a", {});
    if (pending === "plan") internal.pendingPlanCompletion = {};
    if (pending === "question") vi.spyOn(internal, "hasBlockingUserInput").mockReturnValue(true);
    await vi.advanceTimersByTimeAsync(10_000); expect(request).toHaveBeenCalledTimes(1);
  });
  it("does not retry ambiguous transport failures or interrupted turns", async () => {
    const { proc, internal, request } = setup(); request.mockRejectedValueOnce(new Error("connection lost"));
    proc.sendInput("task"); await flush(); await vi.advanceTimersByTimeAsync(60_000); expect(request).toHaveBeenCalledTimes(1);
    proc.sendInput("task2"); await flush(); internal.handleTurnCompleted({ id: "turn-test", status: "interrupted" });
    await flush(); await vi.advanceTimersByTimeAsync(60_000); expect(request).toHaveBeenCalledTimes(2);
  });
  it("defers to upstream willRetry and drops wait state on stop", async () => {
    const { proc, internal, request } = setup(); proc.sendInput("task"); await flush();
    internal.handleNotification("error", { error: { message: "usage limit" }, willRetry: true });
    await flush(); await vi.advanceTimersByTimeAsync(60_000); expect(request).toHaveBeenCalledTimes(1);
    proc.stop(); expect(proc.getRecoveryState().enabled).toBe(false);
  });
  it("cancels automatic input while attachment preparation is pending", async () => {
    const { proc, request, input } = setup();
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    proc.sendInput("task"); await flush();
    let finish!: (v: unknown) => void;
    input.mockImplementationOnce(() => new Promise((resolve) => { finish = resolve; }));
    await vi.advanceTimersByTimeAsync(10_000); proc.setRecoveryEnabled(false);
    finish({ input: [{ type: "text", text: "task" }], tempPaths: [] }); await flush();
    expect(request).toHaveBeenCalledTimes(1);
  });
  it("does not exceed a token budget even if goal status has not caught up", async () => {
    const { proc, request } = setup();
    vi.mocked(proc.getGoal).mockResolvedValue({ status: "active", tokenBudget: 100, tokensUsed: 100 } as any);
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    proc.sendInput("task"); await flush(); await vi.advanceTimersByTimeAsync(10_000);
    expect(request).toHaveBeenCalledTimes(1);
  });
  it("recovers terminal failures after upstream retry ends without repeating the continuation bubble", async () => {
    const { proc, internal, request, messages } = setup();
    proc.sendInput("task"); await flush();
    internal.handleNotification("error", { error: { message: "usage limit" }, willRetry: true });
    internal.handleNotification("error", { error: { message: "usage limit" }, willRetry: false });
    internal.handleTurnCompleted({ id: "turn-test", status: "failed", error: { message: "usage limit" } });
    await flush();
    request.mockRejectedValueOnce(new CodexRpcError("turn/start", { code: 429 }));
    await vi.advanceTimersByTimeAsync(10_000);
    await vi.advanceTimersByTimeAsync(20_000);
    expect(request).toHaveBeenCalledTimes(3);
    expect(messages.filter((m) => m.type === "user_input" && m.text.startsWith("Automatic recovery:"))).toHaveLength(1);
  });

});
