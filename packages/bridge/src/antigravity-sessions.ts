import {
  AcpTransport,
  StdioAcpTransport,
  resolveAntigravityConfig,
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

/**
 * Lists stored conversations through a short-lived `agy acp` process. It
 * sends no prompt, so it is safe with either authentication.
 */
export function listAntigravitySessions(options?: {
  config?: AntigravityConfig;
  createTransport?: (config: AntigravityConfig) => AcpTransport;
  timeoutMs?: number;
}): Promise<AntigravitySessionEntry[]> {
  const config = options?.config ?? resolveAntigravityConfig();
  const transport = (
    options?.createTransport ?? ((c) => new StdioAcpTransport(c))
  )(config);

  return new Promise((resolve, reject) => {
    let nextId = 0;
    let settled = false;
    const pending = new Map<
      number,
      { resolve: (v: Record<string, unknown>) => void; reject: (e: Error) => void }
    >();
    const finish = (err: Error | null, entries: AntigravitySessionEntry[] = []) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      transport.stop();
      if (err) reject(err);
      else resolve(entries);
    };
    const timer = setTimeout(
      () => finish(new Error("Antigravity did not answer in time")),
      options?.timeoutMs ?? LIST_TIMEOUT_MS,
    );
    timer.unref?.();

    const request = (method: string, params: Record<string, unknown>) =>
      new Promise<Record<string, unknown>>((res, rej) => {
        const id = ++nextId;
        pending.set(id, { resolve: res, reject: rej });
        transport.write({ jsonrpc: "2.0", id, method, params });
      });

    transport.on("message", (message) => {
      if (typeof message.method === "string") {
        // Nothing may be asked of this listing client.
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
      transport.start(process.cwd());
      await request("initialize", {
        protocolVersion: 1,
        clientInfo: { name: "ccpocket-bridge", version: "1" },
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
      finish(null, entries);
    })().catch((err: unknown) =>
      finish(err instanceof Error ? err : new Error(String(err))),
    );
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
  } = {},
): AntigravityRecentSession[] {
  const query = filter.searchQuery?.trim().toLowerCase();
  return entries
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
