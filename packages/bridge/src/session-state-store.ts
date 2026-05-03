import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

/**
 * Persisted metadata for an active session.
 * Enough to show the session in the list and allow resume after bridge restart.
 */
export interface PersistedSessionState {
  bridgeSessionId: string;
  provider: "claude" | "codex";
  claudeSessionId?: string;
  projectPath: string;
  name?: string;
  gitBranch: string;
  createdAt: string;
  lastActivityAt: string;
  worktreePath?: string;
  worktreeBranch?: string;
  permissionMode?: string;
  sandboxEnabled?: boolean;
  codexSettings?: {
    profile?: string;
    approvalPolicy?: string;
    approvalsReviewer?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
    additionalWritableRoots?: string[];
  };
  /** Last known status before persistence (always restored as "idle"). */
  lastStatus: string;
}

interface SessionStateFile {
  version: 1;
  sessions: PersistedSessionState[];
}

/**
 * Persists active session metadata to disk so that after a bridge restart,
 * previously-active sessions appear in the session list as resumable (idle).
 *
 * Data is stored in `~/.ccpocket/session-state.json`.
 */
export class SessionStateStore {
  private readonly dirPath: string;
  private readonly filePath: string;
  private sessions = new Map<string, PersistedSessionState>();
  private writeChain: Promise<void> = Promise.resolve();

  constructor() {
    this.dirPath = join(homedir(), ".ccpocket");
    this.filePath = join(this.dirPath, "session-state.json");
  }

  /** Load persisted state from disk. Returns stale sessions (from previous run). */
  async init(): Promise<PersistedSessionState[]> {
    await mkdir(this.dirPath, { recursive: true });
    try {
      const raw = await readFile(this.filePath, "utf-8");
      const parsed = JSON.parse(raw) as SessionStateFile;
      if (parsed.version === 1 && Array.isArray(parsed.sessions)) {
        // Return stale sessions for the caller to inject, but don't load
        // them into our in-memory map (that's for the current run's sessions).
        const stale = parsed.sessions;
        // Clear the file — stale sessions are consumed once on startup.
        await this.save();
        console.log(
          `[session-state] Loaded ${stale.length} stale session(s) from previous run`,
        );
        return stale;
      }
    } catch {
      // File doesn't exist or is corrupted — start fresh.
    }
    return [];
  }

  /** Track a new or updated session. */
  set(state: PersistedSessionState): void {
    this.sessions.set(state.bridgeSessionId, state);
    this.scheduleSave();
  }

  /** Update specific fields of an existing session. */
  update(
    bridgeSessionId: string,
    patch: Partial<PersistedSessionState>,
  ): void {
    const existing = this.sessions.get(bridgeSessionId);
    if (!existing) return;
    Object.assign(existing, patch);
    this.scheduleSave();
  }

  /** Remove a session (e.g. when explicitly stopped/destroyed). */
  remove(bridgeSessionId: string): void {
    if (!this.sessions.delete(bridgeSessionId)) return;
    this.scheduleSave();
  }

  /** Flush pending writes. */
  async flush(): Promise<void> {
    await this.writeChain;
  }

  // ---- internal ----

  private scheduleSave(): void {
    this.writeChain = this.writeChain
      .catch(() => {})
      .then(() => this.save());
  }

  /** Atomic write: write to temp file, then rename. */
  private async save(): Promise<void> {
    const data: SessionStateFile = {
      version: 1,
      sessions: Array.from(this.sessions.values()),
    };
    const tmp = join(this.dirPath, `session-state.${randomUUID()}.tmp`);
    await writeFile(tmp, JSON.stringify(data, null, 2), "utf-8");
    await rename(tmp, this.filePath);
  }
}
