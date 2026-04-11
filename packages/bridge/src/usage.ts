import { execFile } from "node:child_process";
import { readdir, readFile, writeFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

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

export interface ClaudeAuthStatus {
  authenticated: boolean;
  source: "api_key" | "oauth" | "none";
  message?: string;
  errorCode?: "auth_login_required" | "auth_api_error";
}

// ── Claude Code ──

interface ClaudeOAuthPayload {
  claudeAiOauth?: {
    accessToken?: string;
    refreshToken?: string;
    expiresAt?: number;
  };
}

interface ClaudeUsageResponse {
  five_hour?: { utilization: number; resets_at: string };
  seven_day?: { utilization: number; resets_at: string };
}

interface ClaudeOAuthCredentials {
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number;
}

interface ClaudeRefreshResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  error?: string;
  error_description?: string;
}

const CLAUDE_OAUTH_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
const CLAUDE_OAUTH_TOKEN_URL = "https://platform.claude.com/v1/oauth/token";
const TOKEN_EXPIRY_SKEW_MS = 60_000;

// Mutex to prevent concurrent token refreshes from racing and invalidating
// each other's refresh tokens (OAuth servers may rotate refresh tokens).
let _refreshPromise: Promise<RefreshedClaudeToken> | null = null;

interface RefreshedClaudeToken {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
}

/**
 * Read Claude OAuth credentials from ~/.claude/.credentials.json,
 * falling back to macOS Keychain ("Claude Code-credentials" service)
 * for environments where credentials are stored there instead.
 */
export async function getClaudeOAuthCredentials(): Promise<ClaudeOAuthCredentials> {
  // 1. Try file-based credentials first
  const credPath = join(homedir(), ".claude", ".credentials.json");
  let raw: string | undefined;
  try {
    raw = await readFile(credPath, "utf-8");
  } catch {
    // File not found — will try Keychain below
  }

  // 2. Fallback to macOS Keychain
  if (!raw && process.platform === "darwin") {
    try {
      const { stdout } = await execFileAsync("security", [
        "find-generic-password",
        "-s", "Claude Code-credentials",
        "-w",
      ]);
      raw = stdout.trim();
    } catch {
      // Keychain entry not found either
    }
  }

  if (!raw) {
    throw new Error("Claude Code credentials file not found (~/.claude/.credentials.json)");
  }

  try {
    const payload: ClaudeOAuthPayload = JSON.parse(raw);
    const oauth = payload.claudeAiOauth;
    if (!oauth) {
      throw new Error("No OAuth payload in Claude Code credentials");
    }
    return {
      accessToken: oauth.accessToken,
      refreshToken: oauth.refreshToken,
      expiresAt: oauth.expiresAt,
    };
  } catch (err) {
    if (err instanceof Error && err.message.includes("OAuth")) throw err;
    throw new Error("Failed to parse Claude Code credentials");
  }
}

export function isTokenExpired(expiresAt?: number): boolean {
  if (typeof expiresAt !== "number" || !Number.isFinite(expiresAt)) {
    return false;
  }
  return Date.now() >= expiresAt - TOKEN_EXPIRY_SKEW_MS;
}

async function saveClaudeOAuthCredentials(creds: ClaudeOAuthCredentials): Promise<void> {
  const credPath = join(homedir(), ".claude", ".credentials.json");
  // Merge with existing file to preserve extra fields (scopes, subscriptionType, etc.)
  let existing: Record<string, unknown> = {};
  try {
    const raw = await readFile(credPath, "utf-8");
    existing = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    // File doesn't exist or is invalid — start fresh
  }
  const existingOauth = (typeof existing.claudeAiOauth === "object" && existing.claudeAiOauth !== null)
    ? existing.claudeAiOauth as Record<string, unknown>
    : {};
  const merged = {
    ...existing,
    claudeAiOauth: {
      ...existingOauth,
      accessToken: creds.accessToken,
      refreshToken: creds.refreshToken,
      expiresAt: creds.expiresAt,
    },
  };
  await writeFile(credPath, JSON.stringify(merged), { encoding: "utf-8", mode: 0o600 });
}

async function refreshClaudeAccessTokenRaw(refreshToken: string): Promise<RefreshedClaudeToken> {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: CLAUDE_OAUTH_CLIENT_ID,
  });
  const res = await fetch(CLAUDE_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: {
      "content-type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });
  const raw = await res.text();
  let data: ClaudeRefreshResponse;
  try {
    data = JSON.parse(raw) as ClaudeRefreshResponse;
  } catch {
    throw new Error(`OAuth token refresh failed: ${res.status} ${res.statusText}`);
  }
  if (!res.ok) {
    const detail = data.error_description ?? data.error ?? `${res.status} ${res.statusText}`;
    throw new Error(`OAuth token refresh failed: ${detail}`);
  }
  if (!data.access_token) {
    throw new Error(`OAuth token refresh failed: ${data.error ?? "missing access_token"}`);
  }
  const expiresAt = typeof data.expires_in === "number"
    ? Date.now() + data.expires_in * 1000
    : undefined;
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt,
  };
}

/**
 * Serialised wrapper around refreshClaudeAccessTokenRaw.
 * If a refresh is already in-flight, callers share the same Promise so
 * only ONE refresh request hits the OAuth server.  This prevents
 * concurrent callers from consuming a single-use refresh token twice.
 */
async function refreshClaudeAccessToken(refreshToken: string): Promise<RefreshedClaudeToken> {
  if (_refreshPromise) {
    return _refreshPromise;
  }
  _refreshPromise = refreshClaudeAccessTokenRaw(refreshToken).finally(() => {
    _refreshPromise = null;
  });
  return _refreshPromise;
}

export async function getValidClaudeAccessToken(): Promise<{ accessToken: string; refreshToken?: string }> {
  const creds = await getClaudeOAuthCredentials();
  if (creds.accessToken && !isTokenExpired(creds.expiresAt)) {
    return { accessToken: creds.accessToken, refreshToken: creds.refreshToken };
  }
  if (!creds.refreshToken) {
    throw new Error("No OAuth refresh token in Claude Code credentials");
  }
  const refreshed = await refreshClaudeAccessToken(creds.refreshToken);
  const updatedCreds: ClaudeOAuthCredentials = {
    accessToken: refreshed.accessToken,
    refreshToken: refreshed.refreshToken ?? creds.refreshToken,
    expiresAt: refreshed.expiresAt ?? creds.expiresAt,
  };
  try {
    await saveClaudeOAuthCredentials(updatedCreds);
  } catch {
    // If Keychain update fails, continue with in-memory token for this request.
  }
  return { accessToken: refreshed.accessToken, refreshToken: updatedCreds.refreshToken };
}

interface ClaudeAuthProbeResult {
  ok: boolean;
  status?: number;
  detail?: string;
}

async function probeClaudeAccessToken(token: string): Promise<ClaudeAuthProbeResult> {
  const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
    headers: {
      Authorization: `Bearer ${token}`,
      "anthropic-beta": "oauth-2025-04-20",
    },
  });

  if (res.ok) {
    return { ok: true };
  }

  return {
    ok: false,
    status: res.status,
    detail: `API Error: ${res.status} ${res.statusText}`,
  };
}

/**
 * Verify that the stored Claude OAuth access token is still accepted upstream.
 * This catches revoked/invalid sessions that have not yet reached expiresAt.
 *
 * Returns ok=false only for confirmed auth failures (401/403) or refresh errors.
 * Transient upstream/network failures are tolerated so normal query startup can
 * decide how to surface them.
 */
export async function validateClaudeAccessToken(): Promise<ClaudeAuthProbeResult> {
  const creds = await getClaudeOAuthCredentials();
  if (!creds.accessToken) {
    return { ok: false, detail: "No OAuth access token in Claude Code credentials" };
  }

  const initial = await probeClaudeAccessToken(creds.accessToken);
  if (initial.ok) {
    return initial;
  }

  if (initial.status !== 401 && initial.status !== 403) {
    return { ok: true };
  }

  if (!creds.refreshToken) {
    return initial;
  }

  const refreshed = await refreshClaudeAccessToken(creds.refreshToken);
  const updatedCreds: ClaudeOAuthCredentials = {
    accessToken: refreshed.accessToken,
    refreshToken: refreshed.refreshToken ?? creds.refreshToken,
    expiresAt: refreshed.expiresAt ?? creds.expiresAt,
  };

  try {
    await saveClaudeOAuthCredentials(updatedCreds);
  } catch {
    // Continue even if we cannot persist; the refreshed token is still valid
    // for this process.
  }

  return probeClaudeAccessToken(refreshed.accessToken);
}

/**
 * Check Claude authentication status using **local credentials only**.
 *
 * This intentionally does NOT probe the upstream API to avoid redundant
 * requests — the usage endpoint (`fetchClaudeUsage`) already contacts the
 * same API, and firing both simultaneously causes 429 rate-limit errors.
 *
 * For OAuth credentials we verify:
 *   1. An access token exists.
 *   2. The token has not yet expired (with a small skew margin).
 *
 * Actual API reachability is implicitly validated by the usage fetch that
 * runs in parallel on the Flutter settings screen.
 */
export async function getClaudeAuthStatus(): Promise<ClaudeAuthStatus> {
  if (process.env.ANTHROPIC_API_KEY) {
    return {
      authenticated: true,
      source: "api_key",
      message: "Authenticated with ANTHROPIC_API_KEY.",
    };
  }

  if (process.env.ANTHROPIC_AUTH_TOKEN) {
    return {
      authenticated: true,
      source: "api_key",
      message: "Authenticated with ANTHROPIC_AUTH_TOKEN.",
    };
  }

  try {
    const creds = await getClaudeOAuthCredentials();
    if (!creds.accessToken) {
      return {
        authenticated: false,
        source: "none",
        message: "Claude Code credentials exist, but no access token was found.",
        errorCode: "auth_login_required",
      };
    }

    // Local expiry check — avoids an API round-trip.
    if (creds.expiresAt && Date.now() > creds.expiresAt - TOKEN_EXPIRY_SKEW_MS) {
      // Token expired or about to expire. If we have a refresh token the
      // usage fetch will attempt a refresh anyway, so just flag it here.
      if (creds.refreshToken) {
        return {
          authenticated: true,
          source: "oauth",
          message: "Claude Code is authenticated (token will be refreshed).",
        };
      }
      return {
        authenticated: false,
        source: "none",
        message: "Claude Code access token has expired.",
        errorCode: "auth_login_required",
      };
    }

    return {
      authenticated: true,
      source: "oauth",
      message: "Claude Code is authenticated.",
    };
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err);
    if (detail.includes("not found")) {
      return {
        authenticated: false,
        source: "none",
        message: "Claude Code is not logged in on this machine.",
        errorCode: "auth_login_required",
      };
    }

    return {
      authenticated: false,
      source: "none",
      message: detail,
      errorCode: "auth_api_error",
    };
  }
}

export async function fetchClaudeUsage(): Promise<UsageInfo> {
  if (!process.env.BRIDGE_ENABLE_USAGE) {
    return {
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: "Usage fetch disabled (set BRIDGE_ENABLE_USAGE=1 to enable)",
    };
  }
  try {
    const auth = await getValidClaudeAccessToken();
    let token = auth.accessToken;
    let res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      headers: {
        Authorization: `Bearer ${token}`,
        "anthropic-beta": "oauth-2025-04-20",
      },
    });

    // 401 = expired/invalid token, 429 = token-level rate limit.
    // In both cases a fresh token resolves the issue.
    if ((res.status === 401 || res.status === 429) && auth.refreshToken) {
      const refreshed = await refreshClaudeAccessToken(auth.refreshToken);
      // Persist the refreshed token so subsequent callers (and the SDK)
      // pick up the new access & refresh tokens.
      try {
        await saveClaudeOAuthCredentials({
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken ?? auth.refreshToken,
          expiresAt: refreshed.expiresAt,
        });
      } catch {
        // Best-effort save — continue with in-memory token.
      }
      token = refreshed.accessToken;
      res = await fetch("https://api.anthropic.com/api/oauth/usage", {
        headers: {
          Authorization: `Bearer ${token}`,
          "anthropic-beta": "oauth-2025-04-20",
        },
      });
    }

    if (!res.ok) {
      return {
        provider: "claude",
        fiveHour: null,
        sevenDay: null,
        error: `API error: ${res.status} ${res.statusText}`,
      };
    }

    const data = (await res.json()) as ClaudeUsageResponse;

    return {
      provider: "claude",
      fiveHour: data.five_hour
        ? { utilization: data.five_hour.utilization, resetsAt: data.five_hour.resets_at }
        : null,
      sevenDay: data.seven_day
        ? { utilization: data.seven_day.utilization, resetsAt: data.seven_day.resets_at }
        : null,
    };
  } catch (err) {
    return {
      provider: "claude",
      fiveHour: null,
      sevenDay: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

// ── Codex ──

interface CodexRateLimitWindow {
  used_percent: number;
  window_minutes: number;
  resets_at: number;  // unix timestamp (seconds)
}

interface CodexTokenCountEvent {
  timestamp: string;
  type: "event_msg";
  payload: {
    type: "token_count";
    rate_limits?: {
      primary?: CodexRateLimitWindow;
      secondary?: CodexRateLimitWindow;
    };
  };
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
        const rl = event.payload.rate_limits;
        return {
          provider: "codex",
          fiveHour: rl.primary
            ? {
                utilization: rl.primary.used_percent,
                resetsAt: new Date(rl.primary.resets_at * 1000).toISOString(),
              }
            : null,
          sevenDay: rl.secondary
            ? {
                utilization: rl.secondary.used_percent,
                resetsAt: new Date(rl.secondary.resets_at * 1000).toISOString(),
              }
            : null,
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
