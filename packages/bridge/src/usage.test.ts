import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  findLatestTokenCount,
  isGlobalCodexRateLimit,
  mapCodexRateLimits,
} from "./usage.js";

const fiveHourWindow = {
  used_percent: 35,
  window_minutes: 300,
  resets_at: 1_800_000_000,
};

const sevenDayWindow = {
  used_percent: 80,
  window_minutes: 10_080,
  resets_at: 1_800_500_000,
};

describe("mapCodexRateLimits", () => {
  it("maps the usual primary and secondary windows by duration", () => {
    const result = mapCodexRateLimits({
      primary: fiveHourWindow,
      secondary: sevenDayWindow,
    });

    expect(result).toEqual({
      fiveHour: {
        utilization: 35,
        resetsAt: new Date(1_800_000_000 * 1000).toISOString(),
      },
      sevenDay: {
        utilization: 80,
        resetsAt: new Date(1_800_500_000 * 1000).toISOString(),
      },
    });
  });

  it("maps a weekly-only primary window to sevenDay", () => {
    const result = mapCodexRateLimits({
      primary: sevenDayWindow,
      secondary: null,
    });

    expect(result.fiveHour).toBeNull();
    expect(result.sevenDay?.utilization).toBe(80);
  });

  it("does not depend on the upstream window order", () => {
    const result = mapCodexRateLimits({
      primary: sevenDayWindow,
      secondary: fiveHourWindow,
    });

    expect(result.fiveHour?.utilization).toBe(35);
    expect(result.sevenDay?.utilization).toBe(80);
  });
});

describe("isGlobalCodexRateLimit", () => {
  it("accepts the account-wide Codex limit", () => {
    expect(isGlobalCodexRateLimit({ limit_id: "codex" })).toBe(true);
  });

  it("accepts legacy rate limits without an identifier", () => {
    expect(isGlobalCodexRateLimit({})).toBe(true);
  });

  it("rejects model-specific Codex limits", () => {
    expect(isGlobalCodexRateLimit({ limit_id: "codex_bengalfox" })).toBe(
      false,
    );
  });
});

describe("findLatestTokenCount", () => {
  it("does not read a token event outside the bounded tail", async () => {
    const directory = await mkdtemp(join(tmpdir(), "ccpocket-usage-tail-"));
    const filePath = join(directory, "rollout.jsonl");
    const event = JSON.stringify({
      timestamp: "2026-08-24T00:00:00.000Z",
      type: "event_msg",
      payload: {
        type: "token_count",
        rate_limits: { limit_id: "codex", primary: fiveHourWindow },
      },
    });

    try {
      await writeFile(filePath, `${event}\n${"x".repeat(1024)}\n`, "utf-8");
      await expect(findLatestTokenCount(filePath, 128)).resolves.toBeNull();
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });

  it("returns a complete token event inside the bounded tail", async () => {
    const directory = await mkdtemp(join(tmpdir(), "ccpocket-usage-tail-"));
    const filePath = join(directory, "rollout.jsonl");
    const event = JSON.stringify({
      timestamp: "2026-08-24T00:00:00.000Z",
      type: "event_msg",
      payload: {
        type: "token_count",
        rate_limits: { limit_id: "codex", primary: fiveHourWindow },
      },
    });

    try {
      await writeFile(filePath, `${"x".repeat(1024)}\n${event}\n`, "utf-8");
      const result = await findLatestTokenCount(filePath, event.length + 2);
      expect(result?.payload.rate_limits?.primary?.used_percent).toBe(35);
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
});
