import { readdir, readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

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
  used_percent: number;
  window_minutes: number;
  resets_at: number;  // unix timestamp (seconds)
}

export interface CodexRateLimits {
  primary?: CodexRateLimitWindow | null;
  secondary?: CodexRateLimitWindow | null;
}

interface CodexTokenCountEvent {
  timestamp: string;
  type: "event_msg";
  payload: {
    type: "token_count";
    rate_limits?: CodexRateLimits;
  };
}

const FIVE_HOUR_WINDOW_MINUTES = 5 * 60;
const SEVEN_DAY_WINDOW_MINUTES = 7 * 24 * 60;

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

    const usageWindow = {
      utilization: window.used_percent,
      resetsAt: new Date(window.resets_at * 1000).toISOString(),
    };
    if (window.window_minutes === FIVE_HOUR_WINDOW_MINUTES) {
      fiveHour ??= usageWindow;
    } else if (window.window_minutes === SEVEN_DAY_WINDOW_MINUTES) {
      sevenDay ??= usageWindow;
    }
  }

  return { fiveHour, sevenDay };
}

/**
 * Find the latest token_count event from Codex session files.
 * Scans the most recent session directories (last 7 days).
 */
export async function fetchCodexUsage(): Promise<UsageInfo> {
  try {
    const sessionsDir = join(homedir(), ".codex", "sessions");

    // Check if sessions directory exists
    try {
      await stat(sessionsDir);
    } catch {
      return {
        provider: "codex",
        fiveHour: null,
        sevenDay: null,
        error: "Codex sessions directory not found",
      };
    }

    // Find recent session files (last 7 days)
    const sessionFiles = await findRecentSessionFiles(sessionsDir, 7);
    if (sessionFiles.length === 0) {
      return {
        provider: "codex",
        fiveHour: null,
        sevenDay: null,
        error: "No recent Codex sessions found",
      };
    }

    // Search from newest file for the latest token_count event
    for (const filePath of sessionFiles) {
      const event = await findLatestTokenCount(filePath);
      if (event?.payload.rate_limits) {
        return {
          provider: "codex",
          ...mapCodexRateLimits(event.payload.rate_limits),
        };
      }
    }

    return {
      provider: "codex",
      fiveHour: null,
      sevenDay: null,
      error: "No rate limit data found in recent Codex sessions",
    };
  } catch (err) {
    return {
      provider: "codex",
      fiveHour: null,
      sevenDay: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

/**
 * Walk the sessions directory to find .jsonl files, sorted newest first.
 */
async function findRecentSessionFiles(sessionsDir: string, maxDays: number): Promise<string[]> {
  const files: { path: string; mtime: number }[] = [];
  const cutoff = Date.now() - maxDays * 24 * 60 * 60 * 1000;

  // Walk year/month/day directories
  try {
    const years = await readdir(sessionsDir);
    for (const year of years) {
      if (!year.match(/^\d{4}$/)) continue;
      const yearDir = join(sessionsDir, year);

      let months: string[];
      try {
        months = await readdir(yearDir);
      } catch {
        continue;
      }

      for (const month of months) {
        if (!month.match(/^\d{2}$/)) continue;
        const monthDir = join(yearDir, month);

        let days: string[];
        try {
          days = await readdir(monthDir);
        } catch {
          continue;
        }

        for (const day of days) {
          if (!day.match(/^\d{2}$/)) continue;
          const dayDir = join(monthDir, day);

          let entries: string[];
          try {
            entries = await readdir(dayDir);
          } catch {
            continue;
          }

          for (const entry of entries) {
            if (!entry.endsWith(".jsonl")) continue;
            const filePath = join(dayDir, entry);
            try {
              const s = await stat(filePath);
              if (s.mtimeMs >= cutoff) {
                files.push({ path: filePath, mtime: s.mtimeMs });
              }
            } catch {
              continue;
            }
          }
        }
      }
    }
  } catch {
    // Sessions directory not readable
  }

  // Sort newest first
  files.sort((a, b) => b.mtime - a.mtime);
  return files.map((f) => f.path);
}

/**
 * Read a JSONL file from the end and find the latest token_count event.
 */
async function findLatestTokenCount(filePath: string): Promise<CodexTokenCountEvent | null> {
  try {
    const content = await readFile(filePath, "utf-8");
    const lines = content.trim().split("\n");

    // Search from the end for the most recent token_count
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i].trim();
      if (!line || !line.includes("token_count")) continue;
      try {
        const event = JSON.parse(line) as CodexTokenCountEvent;
        if (
          event.type === "event_msg" &&
          event.payload?.type === "token_count" &&
          event.payload?.rate_limits
        ) {
          return event;
        }
      } catch {
        continue;
      }
    }
  } catch {
    // File not readable
  }
  return null;
}

// ── Combined ──

export async function fetchAllUsage(): Promise<UsageInfo[]> {
  // Claude usage previously depended on an undocumented internal endpoint.
  // Keep this API limited to Codex so the app can link users to Claude's
  // official billing pages instead of querying that endpoint.
  const codex = await fetchCodexUsage();
  return [codex];
}
