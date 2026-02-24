import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

export interface ArchivedSession {
  sessionId: string;
  provider: "claude" | "codex";
  projectPath: string;
  archivedAt: string;
}

interface ArchiveStoreData {
  version: 1;
  archivedSessions: ArchivedSession[];
}

/**
 * Manages a persistent set of archived session IDs.
 * Data is stored in `~/.ccpocket/archived-sessions.json`.
 */
export class ArchiveStore {
  private readonly dirPath: string;
  private readonly filePath: string;
  /** In-memory cache of archived session IDs for O(1) lookup. */
  private cache = new Set<string>();
  private data: ArchiveStoreData = { version: 1, archivedSessions: [] };

  constructor() {
    this.dirPath = join(homedir(), ".ccpocket");
    this.filePath = join(this.dirPath, "archived-sessions.json");
  }

  /** Initialise the store: create directory if needed and load existing data. */
  async init(): Promise<void> {
    await mkdir(this.dirPath, { recursive: true });
    try {
      const raw = await readFile(this.filePath, "utf-8");
      const parsed = JSON.parse(raw) as ArchiveStoreData;
      if (parsed.version === 1 && Array.isArray(parsed.archivedSessions)) {
        this.data = parsed;
        this.cache = new Set(parsed.archivedSessions.map((s) => s.sessionId));
      }
    } catch {
      // File doesn't exist or is corrupted – start fresh.
      this.data = { version: 1, archivedSessions: [] };
      this.cache = new Set();
    }
    console.log(
      `[archive-store] Loaded ${this.cache.size} archived session(s)`,
    );
  }

  /** Archive a session. Idempotent – archiving an already-archived session is a no-op. */
  async archive(
    sessionId: string,
    provider: "claude" | "codex",
    projectPath: string,
  ): Promise<void> {
    if (this.cache.has(sessionId)) return;
    const entry: ArchivedSession = {
      sessionId,
      provider,
      projectPath,
      archivedAt: new Date().toISOString(),
    };
    this.data.archivedSessions.push(entry);
    this.cache.add(sessionId);
    await this.save();
    console.log(`[archive-store] Archived session ${sessionId}`);
  }

  /** Check whether a session is archived. */
  isArchived(sessionId: string): boolean {
    return this.cache.has(sessionId);
  }

  /** Return the full set of archived session IDs (for bulk filtering). */
  archivedIds(): ReadonlySet<string> {
    return this.cache;
  }

  // ---- internal ----

  /** Atomic write: write to temp file, then rename. */
  private async save(): Promise<void> {
    const tmp = join(this.dirPath, `archived-sessions.${randomUUID()}.tmp`);
    await writeFile(tmp, JSON.stringify(this.data, null, 2), "utf-8");
    await rename(tmp, this.filePath);
  }
}
