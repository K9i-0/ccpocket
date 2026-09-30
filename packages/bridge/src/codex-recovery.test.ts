import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CodexRecovery, rateLimitFailure } from "./codex-recovery.js";

describe("CodexRecovery", () => {
  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-09-30T00:00:00Z")); });
  afterEach(() => vi.useRealTimers());
  const failure = { message: "You've hit your usage limit" };
  function setup(overrides = {}) {
    const hooks = { changed: vi.fn(), canResume: vi.fn(async () => true), dispatch: vi.fn(() => true), ...overrides };
    return { recovery: new CodexRecovery<{ text: string }>(hooks), hooks };
  }
  it("defaults off and ignores unrelated or upstream-owned errors", async () => {
    const { recovery, hooks } = setup();
    expect(recovery.schedule(failure, { text: "task" })).toBe(false);
    recovery.setEnabled(true);
    for (const error of [{ message: "network timeout" }, { message: "HTTP 401" }, { ...failure, willRetry: true }]) expect(recovery.schedule(error, { text: "task" })).toBe(false);
    await vi.runAllTimersAsync(); expect(hooks.dispatch).not.toHaveBeenCalled();
  });
  it("preserves payload and bounds total submissions to five until manual input", async () => {
    const { recovery, hooks } = setup(); recovery.setEnabled(true);
    const input = { text: "task", images: [{ base64: "abc", mimeType: "image/png" }] };
    for (let i = 0; i < 5; i++) {
      expect(recovery.schedule(failure, input)).toBe(true);
      expect(recovery.schedule(failure, input)).toBe(false);
      await vi.runAllTimersAsync();
    }
    expect(hooks.dispatch).toHaveBeenCalledTimes(5);
    expect(hooks.dispatch).toHaveBeenLastCalledWith(input);
    expect(recovery.schedule(failure, input)).toBe(false);
    expect(recovery.state.phase).toBe("exhausted");
    recovery.manualInput(); expect(recovery.state.attempts).toBe(0);
    expect(recovery.schedule(failure, input)).toBe(true);
    recovery.setEnabled(false);
  });
  it("honors long structured and account reset times without capping them to backoff", async () => {
    const reset = Date.now() + 2 * 60 * 60 * 1000;
    const { recovery, hooks } = setup({ resetAt: async () => reset }); recovery.setEnabled(true);
    recovery.schedule({ code: 429, data: { retryAfterSeconds: 3600 } }, { text: "task" });
    await vi.advanceTimersByTimeAsync(60 * 60 * 1000);
    expect(hooks.dispatch).not.toHaveBeenCalled(); expect(recovery.state.retryAt).toBe(reset);
    await vi.advanceTimersByTimeAsync(60 * 60 * 1000); expect(hooks.dispatch).toHaveBeenCalledTimes(1);
  });
  it.each(["cancel", "manualInput", "disable"])("invalidates an in-flight goal check with %s", async (action) => {
    let resolve!: (v: boolean) => void;
    const { recovery, hooks } = setup({ canResume: () => new Promise<boolean>((r) => { resolve = r; }) });
    recovery.setEnabled(true); recovery.schedule(failure, { text: "task" });
    await vi.advanceTimersByTimeAsync(10_000);
    if (action === "disable") recovery.setEnabled(false); else recovery[action as "cancel" | "manualInput"]();
    resolve(true); await vi.runAllTimersAsync(); expect(hooks.dispatch).not.toHaveBeenCalled();
  });
  it("invalidates a reset lookup when cancelled", async () => {
    let resolve!: (v: number) => void;
    const { recovery, hooks } = setup({ resetAt: () => new Promise<number>((r) => { resolve = r; }) });
    recovery.setEnabled(true); recovery.schedule(failure, { text: "task" }); recovery.cancel();
    resolve(Date.now()); await vi.runAllTimersAsync(); expect(hooks.dispatch).not.toHaveBeenCalled();
  });
  it.each([false, "reject"])("fails closed when session/goal checks fail: %s", async (result) => {
    const { recovery, hooks } = setup({ canResume: async () => { if (result === "reject") throw new Error("lookup failed"); return false; } });
    recovery.setEnabled(true); recovery.schedule(failure, { text: "task" }); await vi.runAllTimersAsync();
    expect(hooks.dispatch).not.toHaveBeenCalled(); expect(recovery.state.phase).toBe("blocked");
  });
  it("never overflows a long reset timer into an immediate retry", async () => {
    const reset = Date.now() + 40 * 24 * 60 * 60 * 1000;
    const { recovery, hooks } = setup(); recovery.setEnabled(true);
    recovery.schedule({ code: 429, resetsAt: reset }, { text: "task" });
    await vi.advanceTimersByTimeAsync(30 * 24 * 60 * 60 * 1000); expect(hooks.dispatch).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(10 * 24 * 60 * 60 * 1000); expect(hooks.dispatch).toHaveBeenCalledTimes(1);
  });
  it("classifies structured Codex errors without treating arbitrary numbers as HTTP status", () => {
    expect(rateLimitFailure({ data: { codexErrorInfo: { httpConnectionFailed: { httpStatusCode: 429 } } } })).not.toBeNull();
    expect(rateLimitFailure({ message: "tool exited at line 429" })).toBeNull();
    expect(rateLimitFailure(new Error("rate limit exceeded"))).not.toBeNull();
  });
});
