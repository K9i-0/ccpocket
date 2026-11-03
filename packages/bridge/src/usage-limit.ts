/** Reset timestamps are milliseconds inside Bridge, seconds in provider events. */
export function futureResetAt(value: unknown): number | undefined {
  const timestamp = typeof value === "number"
    ? (value < 1e12 ? value * 1000 : value)
    : typeof value === "string" ? Date.parse(value) : NaN;
  return Number.isFinite(timestamp) && timestamp > Date.now() ? timestamp : undefined;
}

/** Undefined means confirmed available; zero means limited with an unknown reset. */
function exhaustedWindowReset(
  windows: Array<{ used: unknown; reset: unknown }>,
): number | undefined {
  if (windows.length === 0) throw new Error("Usage windows are unavailable");
  let latest: number | undefined;
  let unknownReset = false;
  for (const window of windows) {
    if (typeof window.used !== "number" || !Number.isFinite(window.used)) {
      throw new Error("Invalid usage window");
    }
    if (window.used < 100) continue;
    const reset = futureResetAt(window.reset);
    if (reset === undefined) unknownReset = true;
    else latest = Math.max(latest ?? 0, reset);
  }
  // A stale full window is not proof that usage has reset. Read again later.
  return unknownReset ? 0 : latest;
}

/** Only exhausted windows block input; the longer window wins if both are full. */
export function codexUsageResetAt(response: {
  rateLimits?: { primary?: unknown; secondary?: unknown };
  rateLimitsByLimitId?: Record<string, { primary?: unknown; secondary?: unknown }> | null;
}): number | undefined {
  const limits = response.rateLimitsByLimitId?.codex ?? response.rateLimits;
  return exhaustedWindowReset([limits?.primary, limits?.secondary].flatMap((value) => {
    if (!value || typeof value !== "object") return [];
    const window = value as { usedPercent?: unknown; resetsAt?: unknown };
    return [{ used: window.usedPercent, reset: window.resetsAt }];
  }));
}

/** Used only after a confirmed rejection, never to infer rejection from a warning. */
export function claudeUsageResetAt(response: unknown, model?: string): number | undefined {
  const limits = (response as { rate_limits?: Record<string, unknown> } | null)?.rate_limits;
  const keys = ["five_hour", "seven_day"];
  if (model?.includes("opus")) keys.push("seven_day_opus");
  if (model?.includes("sonnet")) keys.push("seven_day_sonnet");
  return exhaustedWindowReset(keys.flatMap((key) => {
    const value = limits?.[key];
    if (!value || typeof value !== "object") return [];
    const window = value as { utilization?: unknown; resets_at?: unknown };
    return [{ used: window.utilization, reset: window.resets_at }];
  }));
}
