import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";
import { randomUUID } from "node:crypto";

/** A JSON value the Bridge stores without interpreting it. */
export type SharedStateValue =
  | string
  | number
  | boolean
  | SharedStateValue[]
  | { [key: string]: SharedStateValue | null };

interface Entry {
  value: SharedStateValue;
  updatedAt: number;
}

interface SharedStateData {
  version: 1;
  storeId: string;
  entries: Record<string, Entry>;
}

export const SHARED_STATE_MAX_KEY_LENGTH = 512;
export const SHARED_STATE_MAX_VALUE_BYTES = 32 * 1024;
/** Entries per `namespace/…`; the oldest is evicted beyond it. */
export const SHARED_STATE_MAX_PER_NAMESPACE = 500;
/** Keys without a namespace are never evicted, only refused beyond this. */
export const SHARED_STATE_MAX_PLAIN_KEYS = 200;
export const SHARED_STATE_MAX_SEED_ENTRIES = 5000;

const WRITE_DELAY_MS = 200;

export function isValidSharedStateKey(key: unknown): key is string {
  return (
    typeof key === "string" &&
    key.length > 0 &&
    key.length <= SHARED_STATE_MAX_KEY_LENGTH
  );
}

/** A storable value: JSON, not null, within the size limit. */
export function isValidSharedStateValue(
  value: unknown,
): value is SharedStateValue {
  if (value === null || value === undefined) return false;
  try {
    const json = JSON.stringify(value);
    return (
      typeof json === "string" &&
      Buffer.byteLength(json, "utf-8") <= SHARED_STATE_MAX_VALUE_BYTES
    );
  } catch {
    return false;
  }
}

function namespaceOf(key: string): string | null {
  const slash = key.indexOf("/");
  return slash > 0 ? key.slice(0, slash) : null;
}

/**
 * Settings and per-project / per-session data shared by every client of this
 * Bridge (`docs/shared-state.md`). Stored in `~/.ccpocket/shared-state.json`;
 * `CCPOCKET_SHARED_STATE_FILE` overrides the path.
 */
export class SharedStateStore {
  private readonly filePath: string;
  private storeIdValue: string = randomUUID();
  private entries = new Map<string, Entry>();
  private ready: Promise<void> | null = null;
  private writeTimer: ReturnType<typeof setTimeout> | null = null;
  private writes: Promise<void> = Promise.resolve();
  private clock = 0;

  constructor(filePath?: string) {
    this.filePath =
      filePath ??
      (process.env.CCPOCKET_SHARED_STATE_FILE ||
        join(homedir(), ".ccpocket", "shared-state.json"));
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
      ) as Partial<SharedStateData>;
      if (parsed.version !== 1 || typeof parsed.storeId !== "string") return;
      this.storeIdValue = parsed.storeId;
      for (const [key, entry] of Object.entries(parsed.entries ?? {})) {
        if (!isValidSharedStateKey(key) || !entry) continue;
        if (!isValidSharedStateValue(entry.value)) continue;
        const updatedAt =
          typeof entry.updatedAt === "number" ? entry.updatedAt : 0;
        this.entries.set(key, { value: entry.value, updatedAt });
        this.clock = Math.max(this.clock, updatedAt);
      }
    } catch {
      // Missing or corrupted file: start empty with a new store id, so
      // clients offer their own copies again.
    }
  }

  /** Identifies this store's content lineage; changes when the file is lost. */
  get storeId(): string {
    return this.storeIdValue;
  }

  snapshot(): Record<string, SharedStateValue> {
    const result: Record<string, SharedStateValue> = {};
    for (const [key, entry] of this.entries) result[key] = entry.value;
    return result;
  }

  get(key: string): SharedStateValue | null {
    return this.entries.get(key)?.value ?? null;
  }

  /**
   * Store [value] under [key], or delete the key when it is null. With
   * `max`, a string value only replaces a smaller stored string. Returns the
   * value now stored (null when absent), which is what clients must show.
   */
  async set(
    key: string,
    value: SharedStateValue | null,
    options: { max?: boolean } = {},
  ): Promise<SharedStateValue | null> {
    await this.init();
    const existing = this.entries.get(key);
    if (value === null) {
      if (this.entries.delete(key)) this.scheduleWrite();
      return null;
    }
    if (
      options.max &&
      existing &&
      typeof existing.value === "string" &&
      typeof value === "string" &&
      existing.value >= value
    ) {
      return existing.value;
    }
    if (!existing && !this.makeRoomFor(key)) return null;
    this.entries.set(key, { value, updatedAt: this.tick() });
    this.scheduleWrite();
    return value;
  }

  /**
   * Adopt the entries whose keys are not stored yet. Never evicts: entries
   * beyond a limit are skipped. Returns the adopted keys.
   */
  async seed(seed: Record<string, unknown>): Promise<string[]> {
    await this.init();
    const adopted: string[] = [];
    for (const [key, value] of Object.entries(seed)) {
      if (!isValidSharedStateKey(key) || !isValidSharedStateValue(value)) {
        continue;
      }
      if (this.entries.has(key) || this.isFull(key)) continue;
      this.entries.set(key, { value, updatedAt: this.tick() });
      adopted.push(key);
    }
    if (adopted.length > 0) this.scheduleWrite();
    return adopted;
  }

  private tick(): number {
    this.clock = Math.max(this.clock + 1, Date.now());
    return this.clock;
  }

  private countIn(namespace: string | null): number {
    let count = 0;
    for (const key of this.entries.keys()) {
      if (namespaceOf(key) === namespace) count++;
    }
    return count;
  }

  private isFull(key: string): boolean {
    const namespace = namespaceOf(key);
    return (
      this.countIn(namespace) >=
      (namespace === null
        ? SHARED_STATE_MAX_PLAIN_KEYS
        : SHARED_STATE_MAX_PER_NAMESPACE)
    );
  }

  /** Evict the oldest entry of a full namespace; plain keys are refused. */
  private makeRoomFor(key: string): boolean {
    if (!this.isFull(key)) return true;
    const namespace = namespaceOf(key);
    if (namespace === null) return false;
    let oldest: string | null = null;
    let oldestAt = Infinity;
    for (const [candidate, entry] of this.entries) {
      if (namespaceOf(candidate) !== namespace) continue;
      if (entry.updatedAt < oldestAt) {
        oldest = candidate;
        oldestAt = entry.updatedAt;
      }
    }
    if (oldest === null) return false;
    this.entries.delete(oldest);
    return true;
  }

  /** Changes arrive in bursts (a seed, read marks); write once per burst. */
  private scheduleWrite(): void {
    if (this.writeTimer) return;
    this.writeTimer = setTimeout(() => {
      this.writeTimer = null;
      void this.write();
    }, WRITE_DELAY_MS);
    this.writeTimer.unref?.();
  }

  /** Write pending changes now and wait for the file. */
  async flush(): Promise<void> {
    if (this.writeTimer) {
      clearTimeout(this.writeTimer);
      this.writeTimer = null;
      void this.write();
    }
    await this.writes;
  }

  /** Atomic write (temp file, then rename), serialized across callers. */
  private write(): Promise<void> {
    const data: SharedStateData = {
      version: 1,
      storeId: this.storeIdValue,
      entries: Object.fromEntries(this.entries),
    };
    const json = JSON.stringify(data, null, 2);
    this.writes = this.writes
      .then(async () => {
        const dir = dirname(this.filePath);
        await mkdir(dir, { recursive: true });
        const tmp = join(dir, `shared-state.${randomUUID()}.tmp`);
        await writeFile(tmp, json, "utf-8");
        await rename(tmp, this.filePath);
      })
      .catch((err) => {
        console.error("[shared-state] Failed to write:", err);
      });
    return this.writes;
  }
}
