import { tmpdir } from "node:os";
import {
  ACP_CLIENT_INFO,
  AcpTransport,
  StdioAcpTransport,
  buildModelOptions,
  getAntigravityConfig,
  parseAcpSessionState,
  type AntigravityCatalog,
  type AntigravityConfig,
} from "./antigravity-process.js";

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

interface ShortLivedOptions {
  config?: AntigravityConfig;
  createTransport?: (config: AntigravityConfig) => AcpTransport;
  timeoutMs?: number;
  /** Working directory for the process (and for `session/new`). */
  cwd?: string;
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
        const projectPath = typeof item.cwd === "string" ? item.cwd : "";
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
  firstPrompt: string;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  isSidechain: false;
}

export function antigravityRecentSessions(
  entries: AntigravitySessionEntry[],
  filter: {
    projectPath?: string;
    searchQuery?: string;
    archivedSessionIds?: ReadonlySet<string>;
    /** Names given in ccpocket; they win over Antigravity's own titles. */
    names?: ReadonlyMap<string, string>;
  } = {},
): AntigravityRecentSession[] {
  const query = filter.searchQuery?.trim().toLowerCase();
  return entries
    .map((entry) => {
      const name = filter.names?.get(entry.sessionId);
      return name ? { ...entry, title: name } : entry;
    })
    .filter((entry) => !filter.archivedSessionIds?.has(entry.sessionId))
    .filter((entry) => !filter.projectPath || entry.projectPath === filter.projectPath)
    .filter(
      (entry) =>
        !query ||
        (entry.title ?? "").toLowerCase().includes(query) ||
        entry.projectPath.toLowerCase().includes(query),
    )
    .map((entry) => {
      const modified = entry.updatedAt ?? new Date(0).toISOString();
      return {
        sessionId: entry.sessionId,
        provider: "antigravity" as const,
        ...(entry.title ? { name: entry.title } : {}),
        firstPrompt: entry.title ?? "",
        created: modified,
        modified,
        gitBranch: "",
        projectPath: entry.projectPath,
        isSidechain: false as const,
      };
    })
    .sort((a, b) => b.modified.localeCompare(a.modified));
}
