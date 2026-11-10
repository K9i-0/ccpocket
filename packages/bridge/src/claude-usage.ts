import { homedir } from "node:os";
import { query, type SDKUserMessage } from "@anthropic-ai/claude-agent-sdk";
import {
  canStartClaudeSdk,
  isClaudeOAuthOptInEnabled,
} from "./sdk-process.js";
import type { UsageInfo, UsageModelWindow, UsageWindow } from "./usage.js";

// Claude plan usage is read only through the Claude Agent SDK's experimental
// `/usage` API. This adapter isolates the unstable method name and response
// shape so upstream changes stay contained here. It must never read
// credentials or call claude.ai endpoints directly; the SDK resolves auth.

const CLAUDE_USAGE_TIMEOUT_MS = 15_000;
// A live session answers the control request in well under a second even
// mid-turn; fall back to a standalone query quickly when it does not.
const CLAUDE_LIVE_USAGE_TIMEOUT_MS = 5_000;
// After a failed refresh, keep showing the last successful windows (with the
// error attached) for this long, dropping any window whose reset has passed.
const CLAUDE_USAGE_RETAIN_MS = 60 * 60 * 1000;

/**
 * Reads the raw experimental usage response through an already running Claude
 * session. Resolves to undefined when no session can answer.
 */
export type ClaudeLiveUsageReader = () => Promise<unknown>;

/**
 * Minimal structural view of the experimental Query method. Kept local so a
 * renamed or removed SDK method degrades to "unavailable" instead of a
 * compile-time dependency spread across the Bridge.
 */
type ExperimentalUsageQuery = {
  usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET?: (opts?: {
    skipBehaviors?: boolean;
  }) => Promise<unknown>;
};

async function* createIdleUserMessageStream(): AsyncGenerator<SDKUserMessage> {
  await new Promise<never>(() => {});
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function mapClaudeWindow(value: unknown): UsageWindow | null {
  if (!isRecord(value)) return null;
  const { utilization, resets_at: resetsAt } = value;
  if (typeof utilization !== "number" || !Number.isFinite(utilization)) {
    return null;
  }
  if (typeof resetsAt !== "string" || Number.isNaN(Date.parse(resetsAt))) {
    return null;
  }
  return {
    utilization: Math.min(100, Math.max(0, utilization)),
    resetsAt: new Date(resetsAt).toISOString(),
  };
}

/** Per-model weekly windows (e.g. Fable); only listed for accounts they apply to. */
function mapClaudeModelWindows(value: unknown): UsageModelWindow[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const label = entry.display_name;
    if (typeof label !== "string" || label.trim() === "") return [];
    const window = mapClaudeWindow(entry);
    return window ? [{ label: label.trim(), ...window }] : [];
  });
}

/**
 * Map the experimental SDK usage response to UsageInfo.
 * Returns null when plan limits do not apply or no supported window exists,
 * so callers can omit Claude instead of showing an empty card.
 */
export function mapClaudeUsageResponse(response: unknown): UsageInfo | null {
  if (!isRecord(response)) return null;
  if (response.rate_limits_available !== true) return null;
  const rateLimits = response.rate_limits;
  if (!isRecord(rateLimits)) return null;

  const fiveHour = mapClaudeWindow(rateLimits.five_hour);
  const sevenDay = mapClaudeWindow(rateLimits.seven_day);
  if (!fiveHour && !sevenDay) return null;
  const modelWindows = mapClaudeModelWindows(rateLimits.model_scoped);
  return {
    provider: "claude",
    fiveHour,
    sevenDay,
    ...(modelWindows.length > 0 ? { modelWindows } : {}),
  };
}

class ClaudeUsageUnavailable extends Error {}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`timed out after ${ms}ms`)),
      ms,
    );
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function readClaudeUsage(
  readLive?: ClaudeLiveUsageReader,
): Promise<UsageInfo | null> {
  // Same preflight as Claude sessions: without an explicit credential,
  // Bedrock, or the OAuth opt-in, Claude is simply not configured here.
  if (!canStartClaudeSdk()) return null;

  // Prefer a running session: it avoids spawning a Claude Code process just
  // to read usage. Sessions already enforce the OAuth opt-in at startup.
  if (readLive) {
    try {
      const live = await withTimeout(readLive(), CLAUDE_LIVE_USAGE_TIMEOUT_MS);
      const mapped = live === undefined ? null : mapClaudeUsageResponse(live);
      if (mapped) return mapped;
    } catch (err) {
      console.warn(
        `[claude-usage] Live session usage failed, using a standalone query: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }
  return readStandaloneClaudeUsage();
}

async function readStandaloneClaudeUsage(): Promise<UsageInfo | null> {
  const queryInstance = query({
    prompt: createIdleUserMessageStream(),
    options: {
      cwd: homedir(),
      permissionMode: "default",
      settingSources: ["user"],
      stderr: (data: string) => {
        const trimmed = data.trim();
        if (trimmed) console.error(`[claude-usage:stderr] ${trimmed}`);
      },
    },
  });
  const drain = (async () => {
    try {
      for await (const _message of queryInstance) {
        // Drain initialization/status messages so control requests resolve.
      }
    } catch {
      // close() can reject the iterator; the usage result is handled below.
    }
  })();

  try {
    const response = await withTimeout(
      (async () => {
        const initialization = await queryInstance.initializationResult();
        if (
          initialization.account.apiKeySource === "oauth" &&
          !isClaudeOAuthOptInEnabled()
        ) {
          throw new ClaudeUsageUnavailable();
        }
        const getUsage = (queryInstance as ExperimentalUsageQuery)
          .usage_EXPERIMENTAL_MAY_CHANGE_DO_NOT_RELY_ON_THIS_API_YET;
        if (typeof getUsage !== "function") {
          throw new ClaudeUsageUnavailable();
        }
        // skipBehaviors avoids scanning every transcript from the last week.
        return getUsage.call(queryInstance, { skipBehaviors: true });
      })(),
      CLAUDE_USAGE_TIMEOUT_MS,
    );
    return mapClaudeUsageResponse(response);
  } catch (err) {
    if (err instanceof ClaudeUsageUnavailable) return null;
    return {
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: `Failed to fetch Claude usage: ${err instanceof Error ? err.message : String(err)}`,
    };
  } finally {
    queryInstance.close();
    void drain;
  }
}

// Share concurrent reads (launch/resume/refresh can overlap), but never cache
// a completed snapshot so a manual refresh always queries fresh data.
let pendingClaudeUsage: Promise<UsageInfo | null> | null = null;
let lastClaudeUsage: { usage: UsageInfo; fetchedAt: number } | null = null;

/** Attach a failure to the last good windows that are still current. */
function retainLastClaudeUsage(failed: UsageInfo): UsageInfo {
  const now = Date.now();
  if (!lastClaudeUsage || now - lastClaudeUsage.fetchedAt > CLAUDE_USAGE_RETAIN_MS) {
    return failed;
  }
  const current = (window: UsageWindow | null | undefined) =>
    window && Date.parse(window.resetsAt) > now ? window : null;
  const fiveHour = current(lastClaudeUsage.usage.fiveHour);
  const sevenDay = current(lastClaudeUsage.usage.sevenDay);
  if (!fiveHour && !sevenDay) return failed;
  const modelWindows = (lastClaudeUsage.usage.modelWindows ?? []).filter(
    (window) => current(window) !== null,
  );
  // Clients render windows when present, so the error does not hide them.
  return {
    ...failed,
    fiveHour,
    sevenDay,
    ...(modelWindows.length > 0 ? { modelWindows } : {}),
  };
}

function recordClaudeUsage(result: UsageInfo | null): UsageInfo | null {
  if (!result) {
    lastClaudeUsage = null;
    return null;
  }
  if (result.error) return retainLastClaudeUsage(result);
  lastClaudeUsage = { usage: result, fetchedAt: Date.now() };
  return result;
}

/**
 * Fetch Claude plan usage. Resolves to null when Claude plan limits are not
 * applicable (not configured, API key/Bedrock/Vertex auth, OAuth not opted in,
 * or an SDK without the experimental API). Never rejects.
 *
 * `readLive` lets the caller answer from a running Claude session first; a
 * standalone SDK query is used when it is absent, empty, or fails.
 */
export function fetchClaudeUsage(
  readLive?: ClaudeLiveUsageReader,
): Promise<UsageInfo | null> {
  pendingClaudeUsage ??= readClaudeUsage(readLive)
    .catch((err: unknown): UsageInfo => ({
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: `Failed to fetch Claude usage: ${err instanceof Error ? err.message : String(err)}`,
    }))
    .then(recordClaudeUsage)
    .finally(() => {
      pendingClaudeUsage = null;
    });
  return pendingClaudeUsage;
}

/** Test-only: forget the retained last successful usage. */
export function resetClaudeUsageCacheForTest(): void {
  lastClaudeUsage = null;
}
