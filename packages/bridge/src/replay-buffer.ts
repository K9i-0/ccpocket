import type { ServerMessage } from "./parser.js";

export interface ReplayEvent {
  seq: number;
  msg: ServerMessage;
  timestamp: number;
}

export interface ReplayBufferOptions {
  maxCount?: number; // Default 500
  maxBytes?: number; // Default 5MB
}

export interface ReplayResult {
  events: ReplayEvent[];
  gap: boolean;
}

export class ReplayBuffer {
  private events: ReplayEvent[] = [];
  private nextSeq = 1;
  private totalBytes = 0;
  private readonly maxCount: number;
  private readonly maxBytes: number;

  constructor(opts?: ReplayBufferOptions) {
    this.maxCount = opts?.maxCount ?? 500;
    this.maxBytes = opts?.maxBytes ?? 5 * 1024 * 1024;
  }

  get length(): number {
    return this.events.length;
  }

  append(msg: ServerMessage): number {
    const seq = this.nextSeq++;
    const size = JSON.stringify(msg).length;
    this.events.push({ seq, msg, timestamp: Date.now() });
    this.totalBytes += size;

    // Evict oldest while over limits
    while (
      this.events.length > this.maxCount ||
      (this.totalBytes > this.maxBytes && this.events.length > 1)
    ) {
      const evicted = this.events.shift()!;
      this.totalBytes -= JSON.stringify(evicted.msg).length;
    }

    return seq;
  }

  /** Replay all events with seq > lastSeq. */
  replayFrom(lastSeq: number): ReplayEvent[] {
    return this.events.filter((e) => e.seq > lastSeq);
  }

  /** Replay with gap detection. */
  replayWithGapInfo(lastSeq: number): ReplayResult {
    if (this.events.length === 0) {
      return { events: [], gap: false };
    }

    const oldestSeq = this.events[0].seq;
    const gap = lastSeq > 0 && lastSeq < oldestSeq;

    return {
      events: gap ? [...this.events] : this.replayFrom(lastSeq),
      gap,
    };
  }

  clear(): void {
    this.events = [];
    // nextSeq intentionally NOT reset — preserves monotonic ordering
    // so reconnecting clients can still detect gaps after a clear.
    this.totalBytes = 0;
  }
}
