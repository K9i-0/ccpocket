import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  fetchClaudeUsage,
  mapClaudeUsageResponse,
  resetClaudeUsageCacheForTest,
} from "./claude-usage.js";

const { mockSdkQuery } = vi.hoisted(() => ({
  mockSdkQuery: vi.fn(),
}));

vi.mock("@anthropic-ai/claude-agent-sdk", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@anthropic-ai/claude-agent-sdk")>()),
  query: mockSdkQuery,
}));

const subscriptionUsage = {
  subscription_type: "max",
  rate_limits_available: true,
  rate_limits: {
    five_hour: { utilization: 42, resets_at: "2026-11-01T03:00:00Z" },
    seven_day: { utilization: 53.5, resets_at: "2026-11-04T07:16:00.000Z" },
  },
};

function mockQuery({
  apiKeySource = "oauth",
  usage = vi.fn().mockResolvedValue(subscriptionUsage),
  initializationResult,
}: {
  apiKeySource?: string;
  usage?: ReturnType<typeof vi.fn> | null;
  initializationResult?: ReturnType<typeof vi.fn>;
} = {}) {
  const close = vi.fn();
  mockSdkQuery.mockReturnValueOnce({
    async *[Symbol.asyncIterator]() {
      yield { type: "system", subtype: "init" };
    },
    close,
    initializationResult:
      initializationResult ??
      vi.fn().mockResolvedValue({ account: { apiKeySource }, models: [] }),
    ...(usage ? { usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET: usage } : {}),
  });
  return { close, usage };
}

describe("mapClaudeUsageResponse", () => {
  it("maps both plan windows", () => {
    expect(mapClaudeUsageResponse(subscriptionUsage)).toEqual({
      provider: "claude",
      fiveHour: { utilization: 42, resetsAt: "2026-11-01T03:00:00.000Z" },
      sevenDay: { utilization: 53.5, resetsAt: "2026-11-04T07:16:00.000Z" },
    });
  });

  it("maps a response with only one window", () => {
    expect(
      mapClaudeUsageResponse({
        rate_limits_available: true,
        rate_limits: {
          seven_day: { utilization: 10, resets_at: "2026-11-04T07:16:00Z" },
        },
      }),
    ).toEqual({
      provider: "claude",
      fiveHour: null,
      sevenDay: { utilization: 10, resetsAt: "2026-11-04T07:16:00.000Z" },
    });
  });

  it("drops windows with null or missing fields", () => {
    expect(
      mapClaudeUsageResponse({
        rate_limits_available: true,
        rate_limits: {
          five_hour: { utilization: null, resets_at: "2026-11-01T03:00:00Z" },
          seven_day: { utilization: 20, resets_at: null },
        },
      }),
    ).toBeNull();
    expect(
      mapClaudeUsageResponse({
        rate_limits_available: true,
        rate_limits: {
          five_hour: { resets_at: "2026-11-01T03:00:00Z" },
          seven_day: { utilization: 20, resets_at: "not a date" },
        },
      }),
    ).toBeNull();
  });

  it("clamps utilization to 0-100", () => {
    expect(
      mapClaudeUsageResponse({
        rate_limits_available: true,
        rate_limits: {
          five_hour: { utilization: 120, resets_at: "2026-11-01T03:00:00Z" },
        },
      })?.fiveHour?.utilization,
    ).toBe(100);
  });

  it.each([
    { rate_limits_available: false, rate_limits: null },
    { rate_limits_available: true, rate_limits: null },
    { rate_limits_available: true },
    null,
    "unexpected",
  ])("returns null when plan limits are unavailable: %j", (response) => {
    expect(mapClaudeUsageResponse(response)).toBeNull();
  });
});

describe("fetchClaudeUsage", () => {
  beforeEach(() => {
    mockSdkQuery.mockReset();
    resetClaudeUsageCacheForTest();
    vi.stubEnv("ANTHROPIC_API_KEY", "");
    vi.stubEnv("ANTHROPIC_AUTH_TOKEN", "");
    vi.stubEnv("CLAUDE_CODE_USE_BEDROCK", "");
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  it("reads plan usage through the SDK and closes the query", async () => {
    const { close, usage } = mockQuery();
    await expect(fetchClaudeUsage()).resolves.toMatchObject({
      provider: "claude",
      fiveHour: { utilization: 42 },
      sevenDay: { utilization: 53.5 },
    });
    expect(usage).toHaveBeenCalledWith({ skipBehaviors: true });
    expect(close).toHaveBeenCalledOnce();
  });

  it("does not start the SDK when Claude is not configured", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "");
    await expect(fetchClaudeUsage()).resolves.toBeNull();
    expect(mockSdkQuery).not.toHaveBeenCalled();
  });

  it("omits usage for subscription auth without the OAuth opt-in", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "");
    vi.stubEnv("ANTHROPIC_AUTH_TOKEN", "token");
    const { close, usage } = mockQuery({ apiKeySource: "oauth" });
    await expect(fetchClaudeUsage()).resolves.toBeNull();
    expect(usage).not.toHaveBeenCalled();
    expect(close).toHaveBeenCalledOnce();
  });

  it("omits usage when plan limits do not apply", async () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-test");
    const { close } = mockQuery({
      apiKeySource: "ANTHROPIC_API_KEY",
      usage: vi.fn().mockResolvedValue({
        subscription_type: null,
        rate_limits_available: false,
        rate_limits: null,
      }),
    });
    await expect(fetchClaudeUsage()).resolves.toBeNull();
    expect(close).toHaveBeenCalledOnce();
  });

  it("omits usage when the SDK no longer exposes the experimental API", async () => {
    const { close } = mockQuery({ usage: null });
    await expect(fetchClaudeUsage()).resolves.toBeNull();
    expect(close).toHaveBeenCalledOnce();
  });

  it("returns an error and closes the query when usage retrieval fails", async () => {
    const { close } = mockQuery({
      usage: vi.fn().mockRejectedValue(new Error("network down")),
    });
    await expect(fetchClaudeUsage()).resolves.toEqual({
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: "Failed to fetch Claude usage: network down",
    });
    expect(close).toHaveBeenCalledOnce();
  });

  it("returns an error and closes the query when initialization fails", async () => {
    const { close, usage } = mockQuery({
      initializationResult: vi.fn().mockRejectedValue(new Error("spawn failed")),
    });
    expect((await fetchClaudeUsage())?.error).toContain("spawn failed");
    expect(usage).not.toHaveBeenCalled();
    expect(close).toHaveBeenCalledOnce();
  });

  it("returns an error when query creation throws", async () => {
    mockSdkQuery.mockImplementationOnce(() => {
      throw new Error("missing executable");
    });
    expect((await fetchClaudeUsage())?.error).toContain("missing executable");
  });

  it("times out a hung usage request and closes the query", async () => {
    vi.useFakeTimers();
    const { close } = mockQuery({
      usage: vi.fn().mockReturnValue(new Promise(() => {})),
    });
    const result = fetchClaudeUsage();
    await vi.advanceTimersByTimeAsync(15_000);
    expect((await result)?.error).toContain("timed out");
    expect(close).toHaveBeenCalledOnce();
  });

  it("shares concurrent requests without caching later reads", async () => {
    mockQuery();
    const first = fetchClaudeUsage();
    const second = fetchClaudeUsage();
    expect(first).toBe(second);
    await first;
    mockQuery();
    await fetchClaudeUsage();
    expect(mockSdkQuery).toHaveBeenCalledTimes(2);
  });
});

describe("fetchClaudeUsage with a running session", () => {
  beforeEach(() => {
    mockSdkQuery.mockReset();
    resetClaudeUsageCacheForTest();
    vi.stubEnv("ANTHROPIC_API_KEY", "");
    vi.stubEnv("ANTHROPIC_AUTH_TOKEN", "");
    vi.stubEnv("CLAUDE_CODE_USE_BEDROCK", "");
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  it("answers from the session without spawning a query", async () => {
    const readLive = vi.fn().mockResolvedValue(subscriptionUsage);
    await expect(fetchClaudeUsage(readLive)).resolves.toMatchObject({
      fiveHour: { utilization: 42 },
    });
    expect(readLive).toHaveBeenCalledOnce();
    expect(mockSdkQuery).not.toHaveBeenCalled();
  });

  it("still respects the Claude preflight", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "");
    const readLive = vi.fn().mockResolvedValue(subscriptionUsage);
    await expect(fetchClaudeUsage(readLive)).resolves.toBeNull();
    expect(readLive).not.toHaveBeenCalled();
  });

  it.each([
    ["no session can answer", vi.fn().mockResolvedValue(undefined)],
    ["the session fails", vi.fn().mockRejectedValue(new Error("closed"))],
    [
      "the session has no plan limits",
      vi.fn().mockResolvedValue({ rate_limits_available: false }),
    ],
  ])("falls back to a standalone query when %s", async (_, readLive) => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const { usage } = mockQuery();
    await expect(fetchClaudeUsage(readLive)).resolves.toMatchObject({
      sevenDay: { utilization: 53.5 },
    });
    expect(usage).toHaveBeenCalledOnce();
    warn.mockRestore();
  });

  it("falls back when the session does not answer in time", async () => {
    vi.useFakeTimers();
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const { usage } = mockQuery();
    const result = fetchClaudeUsage(() => new Promise(() => {}));
    await vi.advanceTimersByTimeAsync(5_000);
    await expect(result).resolves.toMatchObject({ fiveHour: { utilization: 42 } });
    expect(usage).toHaveBeenCalledOnce();
    warn.mockRestore();
  });
});

describe("fetchClaudeUsage retention", () => {
  const future = {
    rate_limits_available: true,
    rate_limits: {
      five_hour: { utilization: 42, resets_at: "2026-11-06T07:30:00Z" },
      seven_day: { utilization: 60, resets_at: "2026-11-10T00:00:00Z" },
    },
  };

  beforeEach(() => {
    mockSdkQuery.mockReset();
    resetClaudeUsageCacheForTest();
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2026-11-06T07:00:00Z"));
    vi.stubEnv("ANTHROPIC_API_KEY", "");
    vi.stubEnv("ANTHROPIC_AUTH_TOKEN", "");
    vi.stubEnv("CLAUDE_CODE_USE_BEDROCK", "");
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  const fail = () =>
    fetchClaudeUsage(vi.fn().mockRejectedValue(new Error("live down")));

  async function succeed() {
    await fetchClaudeUsage(vi.fn().mockResolvedValue(future));
  }

  function failStandalone() {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    mockQuery({ usage: vi.fn().mockRejectedValue(new Error("timed out")) });
  }

  it("keeps the last good windows with the error after a failure", async () => {
    await succeed();
    failStandalone();
    await expect(fail()).resolves.toEqual({
      provider: "claude",
      fiveHour: { utilization: 42, resetsAt: "2026-11-06T07:30:00.000Z" },
      sevenDay: { utilization: 60, resetsAt: "2026-11-10T00:00:00.000Z" },
      error: "Failed to fetch Claude usage: timed out",
    });
  });

  it("drops windows whose reset has passed", async () => {
    await succeed();
    vi.setSystemTime(new Date("2026-11-06T07:45:00Z"));
    failStandalone();
    const result = await fail();
    expect(result?.fiveHour).toBeNull();
    expect(result?.sevenDay?.utilization).toBe(60);
  });

  it("stops retaining after an hour", async () => {
    await succeed();
    vi.setSystemTime(new Date("2026-11-06T08:00:01Z"));
    failStandalone();
    const result = await fail();
    expect(result).toMatchObject({ fiveHour: null, sevenDay: null });
    expect(result?.error).toContain("timed out");
  });
});
