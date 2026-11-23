import { format } from "node:util";

export type LogLevel = "info" | "warn" | "error";

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

  constructor(
    private readonly capacity = 2000,
    private readonly maxMessageLength = 4000,
  ) {}

  add(level: LogLevel, message: string, time = Date.now()): void {
    this.entries.push({
      time,
      level,
      message:
        message.length > this.maxMessageLength
          ? `${message.slice(0, this.maxMessageLength)}…`
          : message,
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
