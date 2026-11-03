import type { CodexThreadSummary } from "./codex-process.js";

/** One `thread/list` page. */
export interface CodexThreadPage {
  data: CodexThreadSummary[];
  nextCursor: string | null;
}

/**
 * Pages through every thread. Receives a callback per page so the caller can
 * own the app-server process lifetime around the whole walk.
 */
export type CodexThreadLoader = (
  onPage: (page: CodexThreadPage) => void,
) => Promise<void>;

export interface CodexThreadSnapshotOptions {
  /** Reload in the background once the snapshot is older than this. */
  ttlMs?: number;
  /**
   * After a failed load (e.g. Codex not installed), callers get an empty
   * list and no new load starts for this long.
   */
  failureBackoffMs?: number;
  now?: () => number;
}

const DEFAULT_TTL_MS = 10 * 60_000;
const DEFAULT_FAILURE_BACKOFF_MS = 60_000;

/**
 * In-memory copy of every Codex app-server thread (`thread/list`).
 *
 * Index-backed recent session listings (search, date ranges, multi-project,
 * pinned only) read Codex rollouts from disk, but Codex compresses older
 * rollouts to `.jsonl.zst`, which the index does not parse. Those threads are
 * only reachable through app-server, and paging `thread/list` per request took
 * seconds. This snapshot is loaded once (in the background after the first
 * listing), served immediately afterwards, and refreshed in the background
 * when stale. Recent threads are also in the index as plain `.jsonl`, so a
 * slightly stale snapshot does not hide new sessions.
 */
export class CodexThreadSnapshot {
  private threads: CodexThreadSummary[] | null = null;
  private loadedAt = 0;
  private inFlight: Promise<CodexThreadSummary[]> | null = null;
  private failedAt: number | null = null;
  private readonly ttlMs: number;
  private readonly failureBackoffMs: number;
  private readonly now: () => number;

  constructor(
    private readonly loader: CodexThreadLoader,
    options: CodexThreadSnapshotOptions = {},
  ) {
    this.ttlMs = options.ttlMs ?? DEFAULT_TTL_MS;
    this.failureBackoffMs =
      options.failureBackoffMs ?? DEFAULT_FAILURE_BACKOFF_MS;
    this.now = options.now ?? Date.now;
  }

  get isReady(): boolean {
    return this.threads !== null;
  }

  /** Start loading in the background when missing or stale. */
  warm(): void {
    if (this.inFlight || this.inFailureBackoff()) return;
    if (this.threads && this.now() - this.loadedAt < this.ttlMs) return;
    void this.load().catch(() => undefined);
  }

  /**
   * Threads sorted by `updatedAt` descending. Waits only for the first load;
   * a stale snapshot is returned immediately while it refreshes.
   */
  async get(): Promise<CodexThreadSummary[]> {
    if (this.threads) {
      this.warm();
      return this.threads;
    }
    if (this.inFailureBackoff()) return [];
    try {
      return await this.load();
    } catch {
      return [];
    }
  }

  private inFailureBackoff(): boolean {
    return (
      this.failedAt !== null && this.now() - this.failedAt < this.failureBackoffMs
    );
  }

  private load(): Promise<CodexThreadSummary[]> {
    if (this.inFlight) return this.inFlight;
    const collected = new Map<string, CodexThreadSummary>();
    const request = this.loader((page) => {
      for (const thread of page.data) collected.set(thread.id, thread);
    }).then(
      () => {
        const threads = [...collected.values()].sort(
          (a, b) => b.updatedAt - a.updatedAt,
        );
        this.threads = threads;
        this.loadedAt = this.now();
        this.failedAt = null;
        return threads;
      },
      (err: unknown) => {
        this.failedAt = this.now();
        throw err;
      },
    );
    this.inFlight = request;
    const clear = (): void => {
      if (this.inFlight === request) this.inFlight = null;
    };
    request.then(clear, clear);
    return request;
  }
}
