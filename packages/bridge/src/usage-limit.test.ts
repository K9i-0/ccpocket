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

  it("reads exhausted Claude usage without selecting a non-full weekly window", () => {
    expect(claudeUsageResetAt({ rate_limits: {
      five_hour: { utilization: 100, resets_at: "2026-11-03T02:40:00Z" },
      seven_day: { utilization: 50, resets_at: "2026-11-08T00:00:00Z" },
      seven_day_opus: { utilization: 100, resets_at: "2026-11-08T00:00:00Z" },
      extra_usage: null,
    } }, "claude-sonnet-4-6")).toBe(Date.parse("2026-11-03T02:40:00Z"));
  });
});
