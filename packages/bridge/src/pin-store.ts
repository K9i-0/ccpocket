import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

export type PinProvider = "claude" | "codex" | "antigravity";

export interface PinnedSession {
  provider: PinProvider;
  sessionId: string;
  /** Project path the client listed the session under when it was pinned. */
  projectPath: string;
}

export interface PinState {
  sessions: PinnedSession[];
  projects: string[];
}

interface PinStoreData extends PinState {
  version: 1;
}

export const PIN_STORE_MAX_SESSIONS = 1000;
export const PIN_STORE_MAX_PROJECTS = 1000;

const PROVIDERS: readonly string[] = ["claude", "codex", "antigravity"];

function identity(pin: { provider: string; sessionId: string }): string {
  return `${pin.provider}:${pin.sessionId}`;
}

function sanitizeSessions(value: unknown): PinnedSession[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const sessions: PinnedSession[] = [];
  for (const item of value) {
    if (!item || typeof item !== "object") continue;
    const { provider, sessionId, projectPath } = item as Record<string, unknown>;
    if (typeof provider !== "string" || !PROVIDERS.includes(provider)) continue;
    if (typeof sessionId !== "string" || sessionId.length === 0) continue;
    const pin: PinnedSession = {
      provider: provider as PinProvider,
      sessionId,
      projectPath: typeof projectPath === "string" ? projectPath : "",
    };
    if (seen.has(identity(pin))) continue;
    seen.add(identity(pin));
    sessions.push(pin);
    if (sessions.length >= PIN_STORE_MAX_SESSIONS) break;
  }
  return sessions;
}

function sanitizeProjects(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const projects = new Set<string>();
  for (const item of value) {
    if (typeof item !== "string" || item.length === 0) continue;
    projects.add(item);
    if (projects.size >= PIN_STORE_MAX_PROJECTS) break;
  }
  return [...projects];
}

/**
 * Pinned sessions and projects shared by every client of this Bridge.
 * Stored in `~/.ccpocket/pins.json` (`CCPOCKET_PINS_FILE` overrides the path).
 *
 * The store is "seeded" once the file exists. Until then the first client
 * that offers its own pins defines the content (see `docs/pin-sync.md`).
 */
export class PinStore {
  private readonly filePath: string;
  private sessions: PinnedSession[] = [];
  private projects: string[] = [];
  private seeded = false;
  private ready: Promise<void> | null = null;
  private writes: Promise<void> = Promise.resolve();

  constructor(filePath?: string) {
    this.filePath =
      filePath ??
      (process.env.CCPOCKET_PINS_FILE ||
        join(homedir(), ".ccpocket", "pins.json"));
  }

  /** Load the file once. Safe to call repeatedly. */
  init(): Promise<void> {
    this.ready ??= this.load();
    return this.ready;
  }

  private async load(): Promise<void> {
    try {
      const parsed = JSON.parse(
        await readFile(this.filePath, "utf-8"),
      ) as Partial<PinStoreData>;
      if (parsed.version !== 1) return;
      this.sessions = sanitizeSessions(parsed.sessions);
      this.projects = sanitizeProjects(parsed.projects);
      this.seeded = true;
    } catch {
      // Missing or corrupted file: stay unseeded.
    }
  }

  get isSeeded(): boolean {
    return this.seeded;
  }

  snapshot(): PinState {
    return {
      sessions: this.sessions.map((pin) => ({ ...pin })),
      projects: [...this.projects],
    };
  }

  /**
   * Adopt a client's pins when nothing was stored yet. An empty seed leaves
   * the store unseeded so that a later client can still bring its pins.
   * Returns whether the seed was adopted.
   */
  async seed(seed: { sessions?: unknown; projects?: unknown }): Promise<boolean> {
    await this.init();
    if (this.seeded) return false;
    const sessions = sanitizeSessions(seed.sessions);
    const projects = sanitizeProjects(seed.projects);
    if (sessions.length === 0 && projects.length === 0) return false;
    this.sessions = sessions;
    this.projects = projects;
    await this.save();
    return true;
  }

  /** Pin or unpin a session. Returns whether the stored state changed. */
  async setSessionPin(pin: PinnedSession, pinned: boolean): Promise<boolean> {
    await this.init();
    const key = identity(pin);
    const without = this.sessions.filter((item) => identity(item) !== key);
    const wasPinned = without.length !== this.sessions.length;
    if (pinned === wasPinned) {
      if (!this.seeded) await this.save();
      return false;
    }
    if (pinned && without.length >= PIN_STORE_MAX_SESSIONS) return false;
    this.sessions = pinned ? [...without, { ...pin }] : without;
    await this.save();
    return true;
  }

  /** Pin or unpin a project. Returns whether the stored state changed. */
  async setProjectPin(projectPath: string, pinned: boolean): Promise<boolean> {
    await this.init();
    const without = this.projects.filter((item) => item !== projectPath);
    const wasPinned = without.length !== this.projects.length;
    if (pinned === wasPinned) {
      if (!this.seeded) await this.save();
      return false;
    }
    if (pinned && without.length >= PIN_STORE_MAX_PROJECTS) return false;
    this.projects = pinned ? [...without, projectPath] : without;
    await this.save();
    return true;
  }

  /** Atomic write (temp file, then rename), serialized across callers. */
  private save(): Promise<void> {
    this.seeded = true;
    const data: PinStoreData = {
      version: 1,
      sessions: this.sessions,
      projects: this.projects,
    };
    const json = JSON.stringify(data, null, 2);
    const write = this.writes.then(async () => {
      const dir = dirname(this.filePath);
      await mkdir(dir, { recursive: true });
      const tmp = join(dir, `pins.${randomUUID()}.tmp`);
      await writeFile(tmp, json, "utf-8");
      await rename(tmp, this.filePath);
    });
    this.writes = write.catch(() => {});
    return write;
  }
}
