import {
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
  codexSettings?: SessionInfo["codexSettings"];
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

/**
 * Persists the provider sessions that the user still considers active.
 * Bridge-local process IDs are intentionally omitted because they change
 * whenever the Bridge restarts.
 */
export class ActiveSessionStore {
  private data: ActiveSessionStoreData;

  constructor(private readonly storeFile: string = DEFAULT_STORE_FILE) {
    this.data = this.load();
  }

  list(): PersistedActiveSession[] {
    return this.data.sessions.map((session) => ({
      ...session,
      codexSettings: session.codexSettings
        ? { ...session.codexSettings }
        : undefined,
    }));
  }

  replace(sessions: PersistedActiveSession[]): void {
    const deduped = new Map<string, PersistedActiveSession>();
    for (const session of sessions) {
      deduped.set(
        `${session.provider}:${session.providerSessionId}`,
        session,
      );
    }
    const next = { version: 1 as const, sessions: [...deduped.values()] };
    if (JSON.stringify(next) === JSON.stringify(this.data)) return;
    this.data = next;
    this.save();
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

  private save(): void {
    const storeDir = dirname(this.storeFile);
    mkdirSync(storeDir, { recursive: true });
    const temporaryFile = join(
      storeDir,
      `active-sessions.${randomUUID()}.tmp`,
    );
    writeFileSync(temporaryFile, JSON.stringify(this.data, null, 2), "utf-8");
    renameSync(temporaryFile, this.storeFile);
  }
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
