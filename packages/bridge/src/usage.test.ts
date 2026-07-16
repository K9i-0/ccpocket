import { describe, expect, it } from "vitest";
import { mapCodexRateLimits } from "./usage.js";

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
