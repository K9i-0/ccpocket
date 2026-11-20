import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { AntigravityCatalog } from "./antigravity-process.js";
import type { PermissionMode } from "./parser.js";

/** Recorded context compaction boundary within an Antigravity conversation. */
export interface AntigravityCompactionRecord {
  afterUserTurns: number;
  id: string;
  timestamp: string;
  trigger?: "manual" | "auto";
  preTokens?: number;
  postTokens?: number;
  summary?: string;
}

/** Session-scoped "always allow" grants remembered by the Bridge. */
export interface AntigravityPermissionGrants {
  allowEdits?: boolean;
  commands?: string[];
  mcpTools?: string[];
}

/** What the Bridge remembers about an Antigravity conversation. */
export interface AntigravitySessionRecord {
  /** Name given in ccpocket. `agy` has no way to rename a conversation. */
  name?: string;
  /** ACP model id last used; `session/load` resets it to the agent default. */
  model?: string;
  /** Permission mode last active in this conversation. */
  permissionMode?: PermissionMode;
  /** Mode to restore when exiting plan mode. */
  modeBeforePlan?: PermissionMode;
  /** Recorded compaction boundaries for replay across restarts/resumes. */
  compactions?: AntigravityCompactionRecord[];
  /** Session-scoped "always allow" grants to restore when resuming this conversation. */
  permissionGrants?: AntigravityPermissionGrants;
}

/** The catalog as last read, per sign-in method. */
interface StoredCatalog {
  at: number;
  catalog: AntigravityCatalog;
}

interface StoreData {
  version: 1;
  sessions: Record<string, AntigravitySessionRecord>;
  catalogs?: Record<string, StoredCatalog>;
}

const MAX_SESSIONS = 2000;

/**
 * Per-conversation data Antigravity does not keep itself, stored in
 * `~/.ccpocket/antigravity-sessions.json`.
 */
export class AntigravityStore {
  private readonly filePath: string;
  private sessions = new Map<string, AntigravitySessionRecord>();
  private catalogs: Record<string, StoredCatalog> = {};
  private writing: Promise<void> = Promise.resolve();

  constructor(private readonly dirPath = join(homedir(), ".ccpocket")) {
    this.filePath = join(dirPath, "antigravity-sessions.json");
  }

  async init(): Promise<void> {
    try {
      const parsed = JSON.parse(await readFile(this.filePath, "utf8")) as StoreData;
      if (parsed.version === 1 && parsed.sessions && typeof parsed.sessions === "object") {
        const loaded = new Map(Object.entries(parsed.sessions));
        for (const [id, record] of this.sessions) {
          loaded.set(id, { ...loaded.get(id), ...record });
        }
        this.sessions = loaded;
        this.catalogs = { ...(parsed.catalogs ?? {}), ...this.catalogs };
      }
    } catch {
      // Missing or unreadable: start empty.
    }
  }

  get(sessionId: string): AntigravitySessionRecord | undefined {
    return this.sessions.get(sessionId);
  }

  /** All remembered records by conversation id. */
  records(): ReadonlyMap<string, AntigravitySessionRecord> {
    return this.sessions;
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

  setPermissionMode(
    sessionId: string,
    permissionMode: PermissionMode,
    modeBeforePlan?: PermissionMode,
  ): Promise<void> {
    const existing = this.sessions.get(sessionId);
    const nextBeforePlan =
      modeBeforePlan && modeBeforePlan !== "plan"
        ? modeBeforePlan
        : permissionMode !== "plan"
          ? permissionMode
          : existing?.modeBeforePlan;
    if (
      existing?.permissionMode === permissionMode &&
      existing?.modeBeforePlan === nextBeforePlan
    ) {
      return Promise.resolve();
    }
    return this.update(sessionId, {
      permissionMode,
      ...(nextBeforePlan ? { modeBeforePlan: nextBeforePlan } : {}),
    });
  }

  addCompaction(
    sessionId: string,
    record: AntigravityCompactionRecord,
  ): Promise<void> {
    const existing = this.sessions.get(sessionId)?.compactions ?? [];
    if (existing.some((item) => item.id === record.id)) {
      return Promise.resolve();
    }
    const next = [...existing, record];
    const capped = next.length > 500 ? next.slice(next.length - 500) : next;
    return this.update(sessionId, { compactions: capped });
  }

  setPermissionGrants(
    sessionId: string,
    grants: AntigravityPermissionGrants,
  ): Promise<void> {
    const commands = grants.commands?.length
      ? Array.from(new Set(grants.commands)).slice(-200)
      : undefined;
    const mcpTools = grants.mcpTools?.length
      ? Array.from(new Set(grants.mcpTools)).slice(-200)
      : undefined;
    const normalized: AntigravityPermissionGrants | undefined =
      grants.allowEdits || commands || mcpTools
        ? {
            ...(grants.allowEdits ? { allowEdits: true } : {}),
            ...(commands ? { commands } : {}),
            ...(mcpTools ? { mcpTools } : {}),
          }
        : undefined;
    const existing = this.sessions.get(sessionId)?.permissionGrants;
    if (JSON.stringify(existing) === JSON.stringify(normalized)) {
      return Promise.resolve();
    }
    return this.update(sessionId, { permissionGrants: normalized });
  }

  /**
   * The catalog for [authMode] if it was read within [maxAgeMs]. Reading it
   * anew costs an empty conversation in the user's `agy` profile, so the
   * Bridge keeps it across restarts.
   */
  catalog(authMode: string, maxAgeMs: number): AntigravityCatalog | undefined {
    const stored = this.catalogs[authMode];
    return stored && Date.now() - stored.at <= maxAgeMs ? stored.catalog : undefined;
  }

  setCatalog(catalog: AntigravityCatalog): Promise<void> {
    const previous = this.catalogs[catalog.authMode];
    this.catalogs[catalog.authMode] = { at: Date.now(), catalog };
    // A session reports the same catalog again and again; skip the write.
    if (
      previous &&
      Date.now() - previous.at < 60_000 &&
      JSON.stringify(previous.catalog) === JSON.stringify(catalog)
    ) {
      return Promise.resolve();
    }
    return this.save();
  }

  private save(): Promise<void> {
    this.writing = this.writing.then(() => this.persist()).catch((err) => {
      console.warn("[antigravity-store] Failed to save:", err);
    });
    return this.writing;
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
    return this.save();
  }

  private async persist(): Promise<void> {
    await mkdir(this.dirPath, { recursive: true });
    const data: StoreData = {
      version: 1,
      sessions: Object.fromEntries(this.sessions),
      catalogs: this.catalogs,
    };
    const tmp = `${this.filePath}.${randomUUID()}.tmp`;
    await writeFile(tmp, JSON.stringify(data, null, 2), "utf8");
    await rename(tmp, this.filePath);
  }
}
