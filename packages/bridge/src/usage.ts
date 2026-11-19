import { execFile } from "node:child_process";
import { homedir, tmpdir } from "node:os";
import { fetchClaudeUsage, type ClaudeLiveUsageReader } from "./claude-usage.js";
import { CodexProcess } from "./codex-process.js";

// ── Types ──

export interface UsageWindow {
  utilization: number;  // percentage 0-100
  resetsAt: string;     // ISO 8601
}

/** A weekly window scoped to one model (e.g. Fable), labeled by the server. */
export interface UsageModelWindow extends UsageWindow {
  label: string;
}

export interface UsageInfo {
  provider: "claude" | "codex" | "antigravity";
  /**
   * Name of the quota group when a provider has several, each with its own
   * windows (Antigravity: "Gemini Models", "Claude and GPT models").
   */
  label?: string;
  fiveHour: UsageWindow | null;
  sevenDay: UsageWindow | null;
  /** Omitted when the account has no model-scoped weekly limit. */
  modelWindows?: UsageModelWindow[];
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

// ── Antigravity ──

function antigravityWindow(bucket: unknown): UsageWindow | null {
  if (!bucket || typeof bucket !== "object") return null;
  const { remaining_fraction: remaining, reset_time: resetTime } = bucket as {
    remaining_fraction?: unknown;
    reset_time?: unknown;
  };
  if (typeof remaining !== "number" || !Number.isFinite(remaining)) return null;
  return {
    utilization: Math.min(100, Math.max(0, (1 - remaining) * 100)),
    resetsAt: typeof resetTime === "string" ? resetTime : "",
  };
}

/**
 * Reads the report of `agy -p /usage --output-format json`: one entry per
 * quota group, each with a five-hour and a weekly window.
 */
export function parseAntigravityUsage(raw: string): UsageInfo[] {
  const report = JSON.parse(raw) as {
    command?: { data?: { groups?: unknown } };
  };
  const groups = report.command?.data?.groups;
  if (!Array.isArray(groups)) return [];
  const usage: UsageInfo[] = [];
  for (const group of groups) {
    if (!group || typeof group !== "object") continue;
    const { name, buckets } = group as { name?: unknown; buckets?: unknown };
    const list = Array.isArray(buckets) ? buckets : [];
    const find = (window: string) =>
      antigravityWindow(
        list.find(
          (bucket) =>
            bucket && typeof bucket === "object" &&
            (bucket as { window?: unknown }).window === window,
        ),
      );
    const fiveHour = find("5h");
    const sevenDay = find("weekly");
    if (!fiveHour && !sevenDay) continue;
    usage.push({
      provider: "antigravity",
      ...(typeof name === "string" && name.trim() ? { label: name.trim() } : {}),
      fiveHour,
      sevenDay,
    });
  }
  return usage;
}

/**
 * Asks the Antigravity CLI for the plan's remaining quota. `/usage` is
 * answered by the CLI itself: no model is called and no conversation is made.
 * It reads the Google login of the default profile, so it is run only when a
 * person asks for a refresh, never on a timer.
 */
export function fetchAntigravityUsage(bin = "agy"): Promise<UsageInfo[]> {
  return new Promise((resolve, reject) => {
    execFile(
      bin,
      ["-p", "/usage", "--output-format", "json"],
      {
        cwd: tmpdir(),
        timeout: 60_000,
        maxBuffer: 1024 * 1024,
        env: {
          ...process.env,
          AGY_CLI_DISABLE_AUTO_UPDATE: "true",
          // A failed silent sign-in must not open a browser on the Bridge machine.
          BROWSER: "false",
        },
      },
      (err, stdout) => {
        if (err) {
          reject(err);
          return;
        }
        try {
          resolve(parseAntigravityUsage(stdout));
        } catch (parseError) {
          reject(parseError);
        }
      },
    );
  });
}

// ── Combined ──

/**
 * Fetch usage for every provider with plan limits. Claude is omitted when its
 * plan limits do not apply; a Claude failure never blocks Codex usage.
 */
export async function fetchAllUsage(options: {
  readClaudeLive?: ClaudeLiveUsageReader;
} = {}): Promise<UsageInfo[]> {
  const [claude, codex] = await Promise.all([
    fetchClaudeUsage(options.readClaudeLive).catch(() => null),
    fetchCodexUsage(),
  ]);
  return claude ? [claude, codex] : [codex];
}
