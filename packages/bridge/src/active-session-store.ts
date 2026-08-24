import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  writeFileSync,
} from "node:fs";
import { randomUUID } from "node:crypto";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import type { SessionInfo } from "./session.js";

export interface PersistedActiveSession {
  bridgeSessionId: string;
  providerSessionId: string;
  provider: "claude" | "codex";
  projectPath: string;
  name?: string;
  createdAt: string;
  lastActivityAt: string;
  lastMessage: string;
  worktreePath?: string;
  worktreeBranch?: string;
  permissionMode?: string;
  model?: string;
  sandboxEnabled?: boolean;
  planMode?: boolean;
  claudeSettings?: SessionInfo["claudeSettings"];
  codexSettings?: SessionInfo["codexSettings"];
  codexQueuedInput?: SessionInfo["codexQueuedInput"];
}

interface ActiveSessionStoreData {
  version: 1;
  sessions: PersistedActiveSession[];
}

const DEFAULT_STORE_FILE = join(
  homedir(),
  ".ccpocket",
  "active-sessions.json",
);
const DEFAULT_BRIDGE_PORT = 8765;

export function activeSessionStoreFileForPort(
  port: number | string | undefined,
  explicitFile?: string,
): string {
  if (explicitFile?.trim()) return explicitFile.trim();
  const parsedPort =
    typeof port === "number" ? port : Number.parseInt(port ?? "", 10);
  if (!Number.isInteger(parsedPort) || parsedPort === DEFAULT_BRIDGE_PORT) {
    return DEFAULT_STORE_FILE;
  }
  return join(homedir(), ".ccpocket", `active-sessions-${parsedPort}.json`);
}

/**
 * Persists the provider sessions that the user still considers active.
 * Bridge-local process IDs are intentionally omitted because they change
 * whenever the Bridge restarts.
 */
export class ActiveSessionStore {
  private data: ActiveSessionStoreData;

  constructor(
    private readonly storeFile: string = activeSessionStoreFileForPort(
      process.env.BRIDGE_PORT,
      process.env.BRIDGE_ACTIVE_SESSIONS_FILE,
    ),
  ) {
    this.data = this.load();
  }

  list(): PersistedActiveSession[] {
    return this.data.sessions.map(clonePersistedActiveSession);
  }

  replace(sessions: PersistedActiveSession[]): void {
    const deduped = new Map<string, PersistedActiveSession>();
    for (const session of sessions) {
      deduped.set(
        `${session.provider}:${session.providerSessionId}`,
        clonePersistedActiveSession(session),
      );
    }
    const next = { version: 1 as const, sessions: [...deduped.values()] };
    if (JSON.stringify(next) === JSON.stringify(this.data)) return;
    // Commit the in-memory state only after the atomic disk write succeeds so
    // a transient I/O failure remains retryable on the next update.
    this.save(next);
    this.data = next;
  }

  private load(): ActiveSessionStoreData {
    if (!existsSync(this.storeFile)) return { version: 1, sessions: [] };
    try {
      const parsed = JSON.parse(
        readFileSync(this.storeFile, "utf-8"),
      ) as Partial<ActiveSessionStoreData>;
      if (parsed.version !== 1 || !Array.isArray(parsed.sessions)) {
        return { version: 1, sessions: [] };
      }
      return {
        version: 1,
        sessions: parsed.sessions.filter(isPersistedActiveSession),
      };
    } catch {
      return { version: 1, sessions: [] };
    }
  }

  private save(data: ActiveSessionStoreData): void {
    const storeDir = dirname(this.storeFile);
    const createdDir = mkdirSync(storeDir, { recursive: true, mode: 0o700 });
    // ~/.ccpocket is Bridge-owned and may always be hardened. For an explicit
    // store path, preserve permissions on an existing shared parent directory.
    if (createdDir !== undefined || storeDir === dirname(DEFAULT_STORE_FILE)) {
      chmodSync(storeDir, 0o700);
    }
    const temporaryFile = join(
      storeDir,
      `active-sessions.${randomUUID()}.tmp`,
    );
    writeFileSync(temporaryFile, JSON.stringify(data, null, 2), {
      encoding: "utf-8",
      mode: 0o600,
    });
    renameSync(temporaryFile, this.storeFile);
    chmodSync(this.storeFile, 0o600);
  }
}

function clonePersistedActiveSession(
  session: PersistedActiveSession,
): PersistedActiveSession {
  return {
    ...session,
    claudeSettings: session.claudeSettings
      ? { ...session.claudeSettings }
      : undefined,
    codexSettings: session.codexSettings
      ? {
          ...session.codexSettings,
          additionalWritableRoots:
            session.codexSettings.additionalWritableRoots == null
              ? undefined
              : [...session.codexSettings.additionalWritableRoots],
        }
      : undefined,
    codexQueuedInput: session.codexQueuedInput
      ? {
          ...session.codexQueuedInput,
          images: session.codexQueuedInput.images?.map((image) => ({
            ...image,
          })),
          imageRefs: session.codexQueuedInput.imageRefs?.map((image) => ({
            ...image,
          })),
          skills: session.codexQueuedInput.skills?.map((skill) => ({
            ...skill,
          })),
          mentions: session.codexQueuedInput.mentions?.map((mention) => ({
            ...mention,
          })),
        }
      : undefined,
  };
}

function isPersistedActiveSession(
  value: unknown,
): value is PersistedActiveSession {
  if (!value || typeof value !== "object") return false;
  const session = value as Partial<PersistedActiveSession>;
  return (
    (session.provider === "claude" || session.provider === "codex") &&
    typeof session.bridgeSessionId === "string" &&
    session.bridgeSessionId.length > 0 &&
    typeof session.providerSessionId === "string" &&
    session.providerSessionId.length > 0 &&
    typeof session.projectPath === "string" &&
    session.projectPath.length > 0 &&
    typeof session.createdAt === "string" &&
    typeof session.lastActivityAt === "string" &&
    typeof session.lastMessage === "string"
  );
}
