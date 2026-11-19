import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

/** What the Bridge remembers about an Antigravity conversation. */
export interface AntigravitySessionRecord {
  /** Name given in ccpocket. `agy` has no way to rename a conversation. */
  name?: string;
  /** ACP model id last used; `session/load` resets it to the agent default. */
  model?: string;
}

interface StoreData {
  version: 1;
  sessions: Record<string, AntigravitySessionRecord>;
}

const MAX_SESSIONS = 2000;

/**
 * Per-conversation data Antigravity does not keep itself, stored in
 * `~/.ccpocket/antigravity-sessions.json`.
 */
export class AntigravityStore {
  private readonly filePath: string;
  private sessions = new Map<string, AntigravitySessionRecord>();
  private writing: Promise<void> = Promise.resolve();

  constructor(private readonly dirPath = join(homedir(), ".ccpocket")) {
    this.filePath = join(dirPath, "antigravity-sessions.json");
  }

  async init(): Promise<void> {
    try {
      const parsed = JSON.parse(await readFile(this.filePath, "utf8")) as StoreData;
      if (parsed.version === 1 && parsed.sessions && typeof parsed.sessions === "object") {
        this.sessions = new Map(Object.entries(parsed.sessions));
      }
    } catch {
      // Missing or unreadable: start empty.
    }
  }

  get(sessionId: string): AntigravitySessionRecord | undefined {
    return this.sessions.get(sessionId);
  }

  /** Names by conversation id, for the recent-session list. */
  names(): ReadonlyMap<string, string> {
    const names = new Map<string, string>();
    for (const [id, record] of this.sessions) {
      if (record.name) names.set(id, record.name);
    }
    return names;
  }

  setName(sessionId: string, name: string | null): Promise<void> {
    return this.update(sessionId, { name: name?.trim() || undefined });
  }

  setModel(sessionId: string, model: string): Promise<void> {
    if (this.sessions.get(sessionId)?.model === model) return Promise.resolve();
    return this.update(sessionId, { model });
  }

  private update(sessionId: string, patch: AntigravitySessionRecord): Promise<void> {
    const next = { ...this.sessions.get(sessionId), ...patch };
    for (const key of Object.keys(next) as Array<keyof AntigravitySessionRecord>) {
      if (next[key] === undefined) delete next[key];
    }
    // Re-insert so the map stays ordered by last change.
    this.sessions.delete(sessionId);
    if (Object.keys(next).length > 0) this.sessions.set(sessionId, next);
    while (this.sessions.size > MAX_SESSIONS) {
      const oldest = this.sessions.keys().next();
      if (oldest.done) break;
      this.sessions.delete(oldest.value);
    }
    this.writing = this.writing.then(() => this.persist()).catch((err) => {
      console.warn("[antigravity-store] Failed to save:", err);
    });
    return this.writing;
  }

  private async persist(): Promise<void> {
    await mkdir(this.dirPath, { recursive: true });
    const data: StoreData = {
      version: 1,
      sessions: Object.fromEntries(this.sessions),
    };
    const tmp = `${this.filePath}.${randomUUID()}.tmp`;
    await writeFile(tmp, JSON.stringify(data, null, 2), "utf8");
    await rename(tmp, this.filePath);
  }
}
