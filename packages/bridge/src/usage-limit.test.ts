import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { claudeUsageResetAt, codexUsageResetAt, futureResetAt } from "./usage-limit.js";

describe("usage limit reset times", () => {
  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date("2026-11-03T00:00:00Z")); });
  afterEach(() => vi.useRealTimers());

  it("ignores unknown, invalid and expired reset times", () => {
    for (const value of [null, undefined, "invalid", Infinity, Date.now() - 1]) {
      expect(futureResetAt(value)).toBeUndefined();
    }
    expect(futureResetAt((Date.now() + 60000) / 1000)).toBe(Date.now() + 60000);
  });

  it("waits for both exhausted Codex windows, without waiting for a warning", () => {
    const primary = { usedPercent: 100, resetsAt: (Date.now() + 60000) / 1000 };
    const secondary = { usedPercent: 99, resetsAt: (Date.now() + 120000) / 1000 };
    expect(codexUsageResetAt({ rateLimits: { primary, secondary } })).toBe(Date.now() + 60000);
    secondary.usedPercent = 100;
    expect(codexUsageResetAt({ rateLimitsByLimitId: { codex: { primary, secondary } } })).toBe(Date.now() + 120000);
  });

  it.each([null, "invalid", "2026-11-02T00:00:00Z"])("keeps full windows with unknown or stale resets waiting: %s", (reset) => {
    expect(claudeUsageResetAt({ rate_limits: { five_hour: { utilization: 100, resets_at: reset } } })).toBe(0);
    expect(codexUsageResetAt({ rateLimits: { primary: { usedPercent: 100, resetsAt: reset } } })).toBe(0);
  });

  it("requires a valid usage response to confirm availability", () => {
    expect(() => claudeUsageResetAt({ rate_limits: {} })).toThrow();
    expect(() => codexUsageResetAt({ rateLimits: {} })).toThrow();
    expect(() => codexUsageResetAt({ rateLimits: { primary: { usedPercent: NaN } } })).toThrow();
    expect(claudeUsageResetAt({ rate_limits: { five_hour: { utilization: 0, resets_at: null } } })).toBeUndefined();
    expect(codexUsageResetAt({ rateLimits: { primary: { usedPercent: 20, resetsAt: null } } })).toBeUndefined();
  });

  it("treats numbers below 1e12 as seconds and larger ones as milliseconds", () => {
    const future = Date.now() + 60000;
    expect(futureResetAt(future)).toBe(future);
    // 1e12 is already milliseconds (2001), so it is in the past, not year 33658.
    expect(futureResetAt(1e12)).toBeUndefined();
    expect(futureResetAt(1e12 - 1)).toBe((1e12 - 1) * 1000);
    expect(futureResetAt("2026-11-03T00:01:00Z")).toBe(future);
  });

  it("does not treat the current instant or non-timestamp values as a future reset", () => {
    expect(futureResetAt(Date.now())).toBeUndefined();
    expect(futureResetAt(Date.now() + 1)).toBe(Date.now() + 1);
    expect(futureResetAt(new Date(Date.now() + 60000))).toBeUndefined();
    expect(futureResetAt(["2030-01-01T00:00:00Z"])).toBeUndefined();
  });

  it("reports why availability could not be confirmed", () => {
    expect(() => codexUsageResetAt({})).toThrow("Usage windows are unavailable");
    expect(() => codexUsageResetAt({ rateLimitsByLimitId: null })).toThrow("Usage windows are unavailable");
    expect(() => claudeUsageResetAt(null)).toThrow("Usage windows are unavailable");
    expect(() => claudeUsageResetAt({})).toThrow("Usage windows are unavailable");
    expect(() => codexUsageResetAt({ rateLimits: { primary: {} } })).toThrow("Invalid usage window");
    expect(() => claudeUsageResetAt({ rate_limits: { five_hour: { utilization: "100" } } })).toThrow("Invalid usage window");
  });

  it.each([null, "unavailable", 0])("skips a missing or malformed window next to a valid one: %s", (junk) => {
    const reset = Date.now() + 60000;
    expect(codexUsageResetAt({ rateLimits: { primary: junk, secondary: { usedPercent: 10 } } })).toBeUndefined();
    expect(codexUsageResetAt({ rateLimits: { primary: junk, secondary: { usedPercent: 100, resetsAt: reset } } })).toBe(reset);
    expect(claudeUsageResetAt({ rate_limits: { five_hour: junk, seven_day: { utilization: 10 } } })).toBeUndefined();
    expect(claudeUsageResetAt({ rate_limits: { five_hour: junk, seven_day: { utilization: 100, resets_at: reset } } })).toBe(reset);
  });

  it("reads the model-specific weekly Claude window only for that model family", () => {
    const five_hour = { utilization: 10, resets_at: null };
    const full = { utilization: 100, resets_at: "2026-11-08T00:00:00Z" };
    const reset = Date.parse(full.resets_at);
    const opusFull = { rate_limits: { five_hour, seven_day_opus: full } };
    const sonnetFull = { rate_limits: { five_hour, seven_day_sonnet: full } };
    expect(claudeUsageResetAt(opusFull, "claude-opus-4-7")).toBe(reset);
    expect(claudeUsageResetAt(opusFull)).toBeUndefined();
    expect(claudeUsageResetAt(sonnetFull, "claude-sonnet-4-6")).toBe(reset);
    expect(claudeUsageResetAt(sonnetFull, "claude-opus-4-7")).toBeUndefined();
    expect(claudeUsageResetAt(sonnetFull)).toBeUndefined();
  });

  it("reads exhausted Claude usage without selecting a non-full weekly window", () => {
    expect(claudeUsageResetAt({ rate_limits: {
      five_hour: { utilization: 100, resets_at: "2026-11-03T02:40:00Z" },
      seven_day: { utilization: 50, resets_at: "2026-11-08T00:00:00Z" },
      seven_day_opus: { utilization: 100, resets_at: "2026-11-08T00:00:00Z" },
      extra_usage: null,
    } }, "claude-sonnet-4-6")).toBe(Date.parse("2026-11-03T02:40:00Z"));
  });
});
