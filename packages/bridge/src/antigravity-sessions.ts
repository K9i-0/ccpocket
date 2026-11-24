import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join, win32 } from "node:path";
import { fileURLToPath } from "node:url";
import {
  ACP_CLIENT_INFO,
  ANTIGRAVITY_API_KEY_PROFILE,
  AcpTransport,
  StdioAcpTransport,
  buildModelOptions,
  getAntigravityConfig,
  describeStoredToolCall,
  parseAcpSessionState,
  storedUserInputText,
  type AntigravityCatalog,
  type AntigravityConfig,
} from "./antigravity-process.js";
import type { AntigravitySessionRecord } from "./antigravity-store.js";
import type { PermissionMode } from "./parser.js";
import type { RecentSessionSearchMatch } from "./recent-session-search.js";
import {
  normalizeWorktreePath,
  type SessionHistoryContentItem,
  type SessionHistoryMessage,
} from "./sessions-index.js";

/** A conversation Antigravity keeps on this machine. */
export interface AntigravitySessionEntry {
  sessionId: string;
  projectPath: string;
  title?: string;
  updatedAt?: string;
}

const LIST_TIMEOUT_MS = 15_000;
const MAX_PAGES = 20;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Normalizes a `cwd` returned by `agy acp` `session/list`.
 * On Windows, `agy` reports workspace paths as file-URI pathnames
 * (e.g. `/D:/%E9%A1%B9%E7%9B%AE/demo`), which `path.win32.resolve` would
 * otherwise turn into `D:\D:\%E9%A1%B9%E7%9B%AE\demo`.
 */
export function normalizeAntigravityCwd(
  raw: string,
  platform: NodeJS.Platform = process.platform,
): string {
  if (!raw) return "";
  if (raw.startsWith("file://")) {
    try {
      const converted = fileURLToPath(raw, { windows: platform === "win32" });
      return platform === "win32" ? win32.resolve(converted) : converted;
    } catch {
      // Fall through to best-effort handling below.
    }
  }
  if (platform === "win32" && /^\/[A-Za-z]:[\\/]/.test(raw)) {
    const withoutLeadingSlash = raw.slice(1);
    let decoded = withoutLeadingSlash;
    try {
      decoded = decodeURIComponent(withoutLeadingSlash);
    } catch {
      // Keep the undecoded path if it contains a literal `%` sequence.
    }
    return win32.resolve(decoded);
  }
  return raw;
}

interface ShortLivedOptions {
  config?: AntigravityConfig;
  createTransport?: (config: AntigravityConfig) => AcpTransport;
  timeoutMs?: number;
  /** Working directory for the process (and for `session/new`). */
  cwd?: string;
  /** Platform override for path normalization (defaults to `process.platform`). */
  platform?: NodeJS.Platform;
}

type AcpRequest = (
  method: string,
  params: Record<string, unknown>,
) => Promise<Record<string, unknown>>;

/**
 * Runs `task` against a short-lived `agy acp` process that is initialized and
 * signed in the way sessions are. It must not send a prompt.
 */
function withShortLivedAcp<T>(
  options: ShortLivedOptions | undefined,
  task: (request: AcpRequest, initialized: Record<string, unknown>) => Promise<T>,
): Promise<T> {
  const config = options?.config ?? getAntigravityConfig();
  const transport = (
    options?.createTransport ?? ((c) => new StdioAcpTransport(c))
  )(config);

  return new Promise<T>((resolve, reject) => {
    let nextId = 0;
    let settled = false;
    const pending = new Map<
      number,
      { resolve: (v: Record<string, unknown>) => void; reject: (e: Error) => void }
    >();
    const finish = (err: Error | null, value?: T) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      transport.stop();
      if (err) reject(err);
      else resolve(value as T);
    };
    const timer = setTimeout(
      () => finish(new Error("Antigravity did not answer in time")),
      options?.timeoutMs ?? LIST_TIMEOUT_MS,
    );
    timer.unref?.();

    const request: AcpRequest = (method, params) =>
      new Promise<Record<string, unknown>>((res, rej) => {
        const id = ++nextId;
        pending.set(id, { resolve: res, reject: rej });
        transport.write({ jsonrpc: "2.0", id, method, params });
      });

    transport.on("message", (message) => {
      if (typeof message.method === "string") {
        // Nothing may be asked of this client.
        if (message.id !== undefined) {
          transport.write({
            jsonrpc: "2.0",
            id: message.id,
            error: { code: -32601, message: "Method not found" },
          });
        }
        return;
      }
      const waiter = typeof message.id === "number" ? pending.get(message.id) : undefined;
      if (!waiter) return;
      pending.delete(message.id as number);
      if (isRecord(message.error)) {
        waiter.reject(new Error(String(message.error.message ?? "request failed")));
      } else {
        waiter.resolve(isRecord(message.result) ? message.result : {});
      }
    });
    transport.on("error", (err) => finish(err));
    transport.on("exit", () => finish(new Error("Antigravity exited")));

    void (async () => {
      transport.start(options?.cwd ?? process.cwd());
      const initialized = await request("initialize", {
        protocolVersion: 1,
        clientInfo: ACP_CLIENT_INFO,
        clientCapabilities: {
          fs: { readTextFile: false, writeTextFile: false },
          terminal: false,
        },
      });
      if (config.apiKey) {
        await request("authenticate", {
          methodId: "gemini-api-key",
          _meta: { apiKey: config.apiKey },
        });
      }
      finish(null, await task(request, initialized));
    })().catch((err: unknown) =>
      finish(err instanceof Error ? err : new Error(String(err))),
    );
  });
}

/**
 * Lists stored conversations through a short-lived `agy acp` process. It
 * sends no prompt, so it is safe with either authentication.
 */
export function listAntigravitySessions(
  options?: ShortLivedOptions,
): Promise<AntigravitySessionEntry[]> {
  const config = options?.config ?? getAntigravityConfig();
  // Agent-driven Bridges never touch the Google login profile.
  if (config.requireApiKey && !config.apiKey) return Promise.resolve([]);
  return withShortLivedAcp(options, async (request) => {
    const entries: AntigravitySessionEntry[] = [];
    let cursor: string | undefined;
    for (let page = 0; page < MAX_PAGES; page++) {
      const result = await request("session/list", cursor ? { cursor } : {});
      for (const item of Array.isArray(result.sessions) ? result.sessions : []) {
        if (!isRecord(item)) continue;
        const sessionId = typeof item.sessionId === "string" ? item.sessionId : "";
        const rawCwd = typeof item.cwd === "string" ? item.cwd : "";
        const projectPath = normalizeAntigravityCwd(rawCwd, options?.platform);
        if (!sessionId || !projectPath) continue;
        entries.push({
          sessionId,
          projectPath,
          ...(typeof item.title === "string" && item.title.trim()
            ? { title: item.title.trim() }
            : {}),
          ...(typeof item.updatedAt === "string"
            ? { updatedAt: item.updatedAt }
            : {}),
        });
      }
      cursor = typeof result.nextCursor === "string" ? result.nextCursor : undefined;
      if (!cursor) break;
    }
    return entries;
  });
}

/**
 * Reads the models, thinking levels, modes and plan a new session would get.
 * It opens a session and closes it again without a prompt; Antigravity does
 * not keep such an empty session in its list.
 */
export function fetchAntigravityCatalog(
  options?: ShortLivedOptions,
): Promise<AntigravityCatalog> {
  const config = options?.config ?? getAntigravityConfig();
  if (config.requireApiKey && !config.apiKey) {
    return Promise.reject(
      new Error("CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY is set but no API key is configured"),
    );
  }
  const cwd = options?.cwd ?? tmpdir();
  return withShortLivedAcp({ ...options, cwd }, async (request, initialized) => {
    const session = await request("session/new", { cwd, mcpServers: [] });
    const sessionId = typeof session.sessionId === "string" ? session.sessionId : "";
    if (sessionId) {
      await request("session/close", { sessionId }).catch(() => {
        // Older versions cannot close; the empty session is not listed anyway.
      });
    }
    const state = parseAcpSessionState(session);
    const agentInfo = isRecord(initialized.agentInfo) ? initialized.agentInfo : {};
    return {
      ...(state.model ? { model: state.model } : {}),
      models: state.models,
      ...(state.config?.baseModel ? { baseModel: state.config.baseModel } : {}),
      modelOptions: buildModelOptions(state.config?.baseModels ?? [], state.models),
      ...(state.config?.thoughtLevel ? { thoughtLevel: state.config.thoughtLevel } : {}),
      permissionModes: [...state.permissionModes, "bypassPermissions"],
      authMode: config.apiKey ? "api_key" : "login",
      ...(state.tier ? { tier: state.tier } : {}),
      ...(typeof agentInfo.version === "string" && agentInfo.version
        ? { agentVersion: agentInfo.version }
        : {}),
    };
  });
}

/** Recent-session row in the shape the session list sends to clients. */
export interface AntigravityRecentSession {
  sessionId: string;
  provider: "antigravity";
  name?: string;
  summary?: string;
  firstPrompt: string;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  resumeCwd?: string;
  model?: string;
  permissionMode?: PermissionMode;
  isSidechain: false;
  searchMatch?: RecentSessionSearchMatch;
}

export function antigravityRecentSessions(
  entries: AntigravitySessionEntry[],
  filter: {
    projectPath?: string;
    searchQuery?: string;
    namedOnly?: boolean;
    archivedSessionIds?: ReadonlySet<string>;
    /** Names given in ccpocket; they win over Antigravity's own titles. */
    names?: ReadonlyMap<string, string>;
    /** Remembered metadata from AntigravityStore (name, model, permissionMode). */
    records?: ReadonlyMap<string, AntigravitySessionRecord>;
    /** Known active worktrees from WorktreeStore. */
    worktrees?: ReadonlyMap<string, { projectPath: string; worktreePath: string; worktreeBranch: string }>;
  } = {},
): AntigravityRecentSession[] {
  const query = filter.searchQuery?.trim().toLowerCase();
  const rows: AntigravityRecentSession[] = [];
  for (const entry of entries) {
    if (filter.archivedSessionIds?.has(entry.sessionId)) continue;

    const wt = filter.worktrees?.get(entry.sessionId);
    const mainProjectPath = wt?.projectPath ?? normalizeWorktreePath(entry.projectPath);
    const resolvedProjectPath = mainProjectPath;

    if (filter.projectPath && resolvedProjectPath !== filter.projectPath) continue;

    const record = filter.records?.get(entry.sessionId);
    const storedName = record?.name?.trim() || filter.names?.get(entry.sessionId)?.trim() || undefined;
    if (filter.namedOnly && !storedName) continue;

    const agyTitle = entry.title?.trim() || undefined;
    let searchMatch: RecentSessionSearchMatch | undefined;
    if (query) {
      if (storedName && storedName.toLowerCase().includes(query)) {
        searchMatch = { field: "name" };
      } else if (agyTitle && agyTitle.toLowerCase().includes(query)) {
        searchMatch = { field: "summary" };
      } else if (resolvedProjectPath.toLowerCase().includes(query)) {
        searchMatch = { field: "project" };
      } else {
        continue;
      }
    }

    let resumeCwd: string | undefined;
    // The branch comes from the worktree mapping alone: Antigravity may record
    // the main checkout as the session's directory even for a worktree session.
    const gitBranch = wt?.worktreeBranch ?? "";
    if (mainProjectPath !== entry.projectPath && existsSync(entry.projectPath)) {
      resumeCwd = entry.projectPath;
    }

    const displayName = storedName ?? agyTitle;
    const modified = entry.updatedAt ?? new Date(0).toISOString();
    rows.push({
      sessionId: entry.sessionId,
      provider: "antigravity" as const,
      ...(displayName ? { name: displayName } : {}),
      ...(storedName && agyTitle && agyTitle !== storedName
        ? { summary: agyTitle }
        : {}),
      firstPrompt: displayName ?? "",
      created: modified,
      modified,
      gitBranch,
      projectPath: resolvedProjectPath,
      ...(resumeCwd ? { resumeCwd } : {}),
      ...(record?.model ? { model: record.model } : {}),
      ...(record?.permissionMode ? { permissionMode: record.permissionMode } : {}),
      isSidechain: false as const,
      ...(searchMatch ? { searchMatch } : {}),
    });
  }
  return rows.sort((a, b) => b.modified.localeCompare(a.modified));
}

/**
 * Resolves the Antigravity profile directory (`~/.gemini/<profile>`).
 */
export function resolveAntigravityProfileDir(
  config: AntigravityConfig = getAntigravityConfig(),
): string {
  return join(
    homedir(),
    ".gemini",
    config.apiKey ? ANTIGRAVITY_API_KEY_PROFILE : "antigravity-cli",
  );
}

/**
 * Fallback reader for Antigravity conversation transcripts on disk:
 * `<profileDir>/brain/<sessionId>/.system_generated/logs/transcript_full.jsonl`
 * (or `transcript.jsonl`). Maps `USER_INPUT`, `PLANNER_RESPONSE`, and
 * `CHECKPOINT` entries to `SessionHistoryMessage[]`.
 */
export async function readAntigravityTranscriptFile(
  sessionId: string,
  options?: { profileDir?: string; config?: AntigravityConfig; cwd?: string },
): Promise<SessionHistoryMessage[]> {
  if (!sessionId || /[\\/]/.test(sessionId)) return [];
  const profileDir =
    options?.profileDir ?? resolveAntigravityProfileDir(options?.config);
  const logsDir = join(profileDir, "brain", sessionId, ".system_generated", "logs");
  const fullPath = join(logsDir, "transcript_full.jsonl");
  const compactPath = join(logsDir, "transcript.jsonl");
  const filePath = existsSync(fullPath)
    ? fullPath
    : existsSync(compactPath)
      ? compactPath
      : null;
  if (!filePath) return [];

  let raw: string;
  try {
    raw = await readFile(filePath, "utf8");
  } catch {
    return [];
  }

  const messages: SessionHistoryMessage[] = [];
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(trimmed);
    } catch {
      continue;
    }
    if (!isRecord(parsed)) continue;
    const type = typeof parsed.type === "string" ? parsed.type : "";
    const timestamp =
      typeof parsed.created_at === "string" ? parsed.created_at : undefined;
    const stepIndex =
      typeof parsed.step_index === "number" ? parsed.step_index : undefined;
    const uuid =
      stepIndex !== undefined ? `antigravity:log:${stepIndex}` : undefined;

    if (type === "USER_INPUT") {
      const content =
        typeof parsed.content === "string" ? storedUserInputText(parsed.content) : "";
      if (!content.trim()) continue;
      messages.push({
        role: "user",
        ...(uuid ? { uuid } : {}),
        ...(timestamp ? { timestamp } : {}),
        content,
      });
      continue;
    }

    if (type === "PLANNER_RESPONSE") {
      const blocks: SessionHistoryContentItem[] = [];
      if (typeof parsed.thinking === "string" && parsed.thinking.trim()) {
        blocks.push({ type: "thinking", thinking: parsed.thinking });
      }
      if (typeof parsed.content === "string" && parsed.content.trim()) {
        blocks.push({ type: "text", text: parsed.content });
      }
      if (Array.isArray(parsed.tool_calls)) {
        for (const call of parsed.tool_calls) {
          if (!isRecord(call)) continue;
          const name = typeof call.name === "string" ? call.name : "";
          if (!name) continue;
          const id =
            typeof call.id === "string" && call.id
              ? call.id
              : `agy-call-${messages.length}-${blocks.length}`;
          // agy writes `args`; the other keys are older guesses kept for safety.
          const args = isRecord(call.args)
            ? call.args
            : isRecord(call.arguments)
              ? call.arguments
              : isRecord(call.input)
                ? call.input
                : {};
          // Named and shaped as in a live session (Bash, Read, TodoWrite, ...).
          const described = describeStoredToolCall(name, args, options?.cwd);
          blocks.push({
            type: "tool_use",
            id,
            name: described.toolName,
            input: described.input,
          });
        }
      }
      if (blocks.length === 0) continue;
      messages.push({
        role: "assistant",
        ...(uuid ? { uuid } : {}),
        ...(timestamp ? { timestamp } : {}),
        content: blocks,
      });
      continue;
    }

    if (type === "CHECKPOINT") {
      const summary =
        typeof parsed.content === "string" && parsed.content.trim()
          ? parsed.content.trim()
          : undefined;
      messages.push({
        role: "compaction",
        ...(uuid ? { uuid } : {}),
        ...(timestamp ? { timestamp } : {}),
        compaction: {
          trigger: "auto",
          ...(summary ? { summary } : {}),
        },
        content: "",
      });
    }
  }
  return messages;
}
