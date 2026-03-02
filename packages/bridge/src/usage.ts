import { execFile } from "node:child_process";
import { readdir, readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Path to the login keychain. By specifying this explicitly in all
 * `security find-generic-password` / `add-generic-password` calls we
 * avoid searching iCloud Keychains which can trigger the macOS
 * "iCloudHelper wants to access keychain" GUI dialog — especially
 * problematic when running as a launchd service.
 */
const LOGIN_KEYCHAIN = join(homedir(), "Library/Keychains/login.keychain-db");

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

interface RefreshedClaudeToken {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
}

function getClaudeOAuthCredentials(): Promise<ClaudeOAuthCredentials> {
  return new Promise((resolve, reject) => {
    execFile(
      "security",
      ["find-generic-password", "-s", "Claude Code-credentials", "-w", LOGIN_KEYCHAIN],
      { timeout: 5000 },
      (err, stdout) => {
        if (err) {
          reject(new Error("Claude Code credentials not found in Keychain"));
          return;
        }
        try {
          const payload: ClaudeOAuthPayload = JSON.parse(stdout.trim());
          const oauth = payload.claudeAiOauth;
          if (!oauth) {
            reject(new Error("No OAuth payload in Claude Code credentials"));
            return;
          }
          resolve({
            accessToken: oauth.accessToken,
            refreshToken: oauth.refreshToken,
            expiresAt: oauth.expiresAt,
          });
        } catch {
          reject(new Error("Failed to parse Claude Code credentials"));
        }
      },
    );
  });
}

function isTokenExpired(expiresAt?: number): boolean {
  if (typeof expiresAt !== "number" || !Number.isFinite(expiresAt)) {
    return false;
  }
  return Date.now() >= expiresAt - TOKEN_EXPIRY_SKEW_MS;
}

function saveClaudeOAuthCredentials(creds: ClaudeOAuthCredentials): Promise<void> {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({ claudeAiOauth: creds });
    execFile(
      "security",
      ["add-generic-password", "-U", "-s", "Claude Code-credentials", "-w", payload, LOGIN_KEYCHAIN],
      { timeout: 5000 },
      (err) => {
        if (err) {
          reject(new Error("Failed to update Claude Code credentials in Keychain"));
          return;
        }
        resolve();
      },
    );
  });
}

async function refreshClaudeAccessToken(refreshToken: string): Promise<RefreshedClaudeToken> {
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

async function getValidClaudeAccessToken(): Promise<{ accessToken: string; refreshToken?: string }> {
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

export async function fetchClaudeUsage(): Promise<UsageInfo> {
  try {
    const auth = await getValidClaudeAccessToken();
    let token = auth.accessToken;
    let res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      headers: {
        Authorization: `Bearer ${token}`,
        "anthropic-beta": "oauth-2025-04-20",
      },
    });

    if (res.status === 401 && auth.refreshToken) {
      const refreshed = await refreshClaudeAccessToken(auth.refreshToken);
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
  const [claude, codex] = await Promise.all([
    fetchClaudeUsage(),
    fetchCodexUsage(),
  ]);
  return [claude, codex];
}
