import { homedir } from "node:os";
import { CodexProcess } from "./codex-process.js";

// ── Types ──

export interface UsageWindow {
  utilization: number;  // percentage 0-100
  resetsAt: string;     // ISO 8601
}

export interface UsageInfo {
  provider: "claude" | "codex";
  fiveHour: UsageWindow | null;
  sevenDay: UsageWindow | null;
  error?: string;
}

// ── Codex ──

export interface CodexRateLimitWindow {
  usedPercent: number;
  windowDurationMins: number | null;
  resetsAt: number | null;  // unix timestamp (seconds)
}

export interface CodexRateLimits {
  limitId?: string | null;
  primary?: CodexRateLimitWindow | null;
  secondary?: CodexRateLimitWindow | null;
}

export interface CodexRateLimitsResponse {
  rateLimits: CodexRateLimits;
  rateLimitsByLimitId?: Record<string, CodexRateLimits> | null;
}

const FIVE_HOUR_WINDOW_MINUTES = 5 * 60;
const SEVEN_DAY_WINDOW_MINUTES = 7 * 24 * 60;

/**
 * Distinguish the account-wide Codex limit from model-specific limits.
 * Older Codex versions did not include limitId, so keep accepting those
 * records for backwards compatibility.
 */
export function isGlobalCodexRateLimit(rateLimits: CodexRateLimits): boolean {
  return rateLimits.limitId == null || rateLimits.limitId === "codex";
}

/**
 * Map Codex rate-limit windows by duration rather than their primary/secondary
 * position. Codex may promote the weekly window to primary when the short-term
 * limit is temporarily disabled.
 */
export function mapCodexRateLimits(
  rateLimits: CodexRateLimits,
): Pick<UsageInfo, "fiveHour" | "sevenDay"> {
  let fiveHour: UsageWindow | null = null;
  let sevenDay: UsageWindow | null = null;

  for (const window of [rateLimits.primary, rateLimits.secondary]) {
    if (!window) continue;
    if (
      window.windowDurationMins !== FIVE_HOUR_WINDOW_MINUTES &&
      window.windowDurationMins !== SEVEN_DAY_WINDOW_MINUTES
    ) continue;
    if (
      !Number.isFinite(window.usedPercent) ||
      window.resetsAt == null ||
      !Number.isFinite(window.resetsAt)
    ) {
      throw new Error("Invalid Codex usage window returned by app-server");
    }

    const usageWindow = {
      utilization: window.usedPercent,
      resetsAt: new Date(window.resetsAt * 1000).toISOString(),
    };
    if (window.windowDurationMins === FIVE_HOUR_WINDOW_MINUTES) {
      fiveHour ??= usageWindow;
    } else if (window.windowDurationMins === SEVEN_DAY_WINDOW_MINUTES) {
      sevenDay ??= usageWindow;
    }
  }

  return { fiveHour, sevenDay };
}

// Share concurrent reads, but never cache a completed snapshot: refresh must
// query the service even when no Codex conversation has run since the last read.
let pendingUsage: Promise<UsageInfo> | null = null;
const USAGE_RPC_TIMEOUT_MS = 10_000;

export function fetchCodexUsage(): Promise<UsageInfo> {
  pendingUsage ??= readCodexUsage().finally(() => {
    pendingUsage = null;
  });
  return pendingUsage;
}

async function readCodexUsage(): Promise<UsageInfo> {
  const proc = new CodexProcess();
  try {
    // Initialize the account connection only; do not create a thread or turn.
    await proc.initializeOnly(homedir(), USAGE_RPC_TIMEOUT_MS);
    const response = await proc.readRateLimits(USAGE_RPC_TIMEOUT_MS);
    const limits = response.rateLimitsByLimitId?.codex ?? response.rateLimits;
    if (!limits || !isGlobalCodexRateLimit(limits)) {
      throw new Error("No account-wide Codex rate limits returned by app-server");
    }
    const windows = mapCodexRateLimits(limits);
    if (!windows.fiveHour && !windows.sevenDay) {
      throw new Error("No supported Codex usage windows returned by app-server");
    }
    return { provider: "codex", ...windows };
  } catch (err) {
    return {
      provider: "codex",
      fiveHour: null,
      sevenDay: null,
      error: `Failed to fetch Codex usage: ${err instanceof Error ? err.message : String(err)}`,
    };
  } finally {
    proc.stop();
  }
}

// ── Combined ──

export async function fetchAllUsage(): Promise<UsageInfo[]> {
  // Claude usage previously depended on an undocumented internal endpoint.
  // Keep this API limited to Codex so the app can link users to Claude's
  // official billing pages instead of querying that endpoint.
  const codex = await fetchCodexUsage();
  return [codex];
}
