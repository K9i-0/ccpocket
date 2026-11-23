import { format } from "node:util";

export type LogLevel = "info" | "warn" | "error";

export const OMITTED_MESSAGE = "[pairing details omitted]";

export interface LogEntry {
  /** Epoch milliseconds. */
  time: number;
  level: LogLevel;
  message: string;
}

/**
 * Keeps the most recent console output in memory so the local management UI
 * can show Bridge logs however the Bridge was started (terminal, launchd,
 * systemd). Served only through the local-only `/admin/logs` endpoint.
 */
export class LogBuffer {
  private entries: LogEntry[] = [];
  private secrets: string[] = [];

  constructor(
    private readonly capacity = 2000,
    private readonly maxMessageLength = 4000,
  ) {}

  /**
   * Messages containing [secret] are not kept. Whole messages are dropped
   * rather than masked because a pairing QR code encodes the key as well.
   */
  addSecret(secret: string): void {
    if (secret.length < 8) return;
    this.secrets.push(
      secret,
      encodeURIComponent(secret),
      // Deep links are built with URLSearchParams, which encodes differently.
      new URLSearchParams({ k: secret }).toString().slice(2),
    );
  }

  add(level: LogLevel, message: string, time = Date.now()): void {
    const sensitive = this.secrets.some((secret) => message.includes(secret));
    const kept = sensitive ? OMITTED_MESSAGE : message;
    this.entries.push({
      time,
      level,
      message:
        kept.length > this.maxMessageLength
          ? `${kept.slice(0, this.maxMessageLength)}…`
          : kept,
    });
    if (this.entries.length > this.capacity) {
      this.entries.splice(0, this.entries.length - this.capacity);
    }
  }

  /** The newest [limit] entries, oldest first. */
  tail(limit = 500): LogEntry[] {
    const count = Math.max(0, Math.min(limit, this.entries.length));
    return this.entries.slice(this.entries.length - count);
  }

  /** Mirror `console.log/info/warn/error` into the buffer. */
  install(target: Console = console): void {
    const levels: Array<[keyof Console & ("log" | "info" | "warn" | "error"), LogLevel]> = [
      ["log", "info"],
      ["info", "info"],
      ["warn", "warn"],
      ["error", "error"],
    ];
    for (const [method, level] of levels) {
      const original = target[method].bind(target);
      target[method] = (...args: unknown[]) => {
        try {
          this.add(level, format(...args));
        } catch {
          // Logging must never break the caller.
        }
        original(...args);
      };
    }
  }
}
