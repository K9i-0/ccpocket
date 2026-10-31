import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { fetchClaudeUsage, mapClaudeUsageResponse } from "./claude-usage.js";

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
