import { homedir } from "node:os";
import { query, type SDKUserMessage } from "@anthropic-ai/claude-agent-sdk";
import {
  canStartClaudeSdk,
  isClaudeOAuthOptInEnabled,
} from "./sdk-process.js";
import type { UsageInfo, UsageWindow } from "./usage.js";

// Claude plan usage is read only through the Claude Agent SDK's experimental
// `/usage` API. This adapter isolates the unstable method name and response
// shape so upstream changes stay contained here. It must never read
// credentials or call claude.ai endpoints directly; the SDK resolves auth.

const CLAUDE_USAGE_TIMEOUT_MS = 15_000;

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
  return { provider: "claude", fiveHour, sevenDay };
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

async function readClaudeUsage(): Promise<UsageInfo | null> {
  // Same preflight as Claude sessions: without an explicit credential,
  // Bedrock, or the OAuth opt-in, Claude is simply not configured here.
  if (!canStartClaudeSdk()) return null;

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

/**
 * Fetch Claude plan usage. Resolves to null when Claude plan limits are not
 * applicable (not configured, API key/Bedrock/Vertex auth, OAuth not opted in,
 * or an SDK without the experimental API). Never rejects.
 */
export function fetchClaudeUsage(): Promise<UsageInfo | null> {
  pendingClaudeUsage ??= readClaudeUsage()
    .catch((err: unknown): UsageInfo => ({
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: `Failed to fetch Claude usage: ${err instanceof Error ? err.message : String(err)}`,
    }))
    .finally(() => {
      pendingClaudeUsage = null;
    });
  return pendingClaudeUsage;
}
