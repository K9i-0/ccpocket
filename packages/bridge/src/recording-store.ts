import { appendFile, mkdir, readdir, readFile, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ClientMessage, ServerMessage } from "./parser.js";

const DEFAULT_ROOT_DIR = join(homedir(), ".ccpocket", "debug");
const RECORDING_DIRNAME = "recordings";

export interface RecordingFileInfo {
  name: string;
  path: string;
  modified: string;
  sizeBytes: number;
}

export interface RecordedEvent {
  ts: string;
  direction: "outgoing" | "incoming";
  message: ServerMessage | ClientMessage;
}

export class RecordingStore {
  private recordingDir: string;
  private writeChains = new Map<string, Promise<void>>();

  constructor(rootDir: string = DEFAULT_ROOT_DIR) {
    this.recordingDir = join(rootDir, RECORDING_DIRNAME);
  }

  async init(): Promise<void> {
    await mkdir(this.recordingDir, { recursive: true });
  }

  getFilePath(sessionId: string): string {
    return join(this.recordingDir, `${sanitizeSegment(sessionId)}.jsonl`);
  }

  record(
    sessionId: string,
    direction: "outgoing" | "incoming",
    message: ServerMessage | ClientMessage,
  ): void {
    const path = this.getFilePath(sessionId);
    const event: RecordedEvent = {
      ts: new Date().toISOString(),
      direction,
      message,
    };
    const line = `${JSON.stringify(event)}\n`;
    this.enqueue(path, async () => {
      await appendFile(path, line, "utf-8");
    });
  }

  /** List all recording files, newest first. */
  async listRecordings(): Promise<RecordingFileInfo[]> {
    try {
      const entries = await readdir(this.recordingDir);
      const results: RecordingFileInfo[] = [];
      for (const entry of entries) {
        if (!entry.endsWith(".jsonl")) continue;
        const filePath = join(this.recordingDir, entry);
        const s = await stat(filePath);
        results.push({
          name: entry.replace(/\.jsonl$/, ""),
          path: filePath,
          modified: s.mtime.toISOString(),
          sizeBytes: s.size,
        });
      }
      results.sort((a, b) => b.modified.localeCompare(a.modified));
      return results;
    } catch {
      return [];
    }
  }

  /** Read recording content as string. */
  async getRecordingContent(sessionId: string): Promise<string | null> {
    try {
      const filePath = this.getFilePath(sessionId);
      return await readFile(filePath, "utf-8");
    } catch {
      return null;
    }
  }

  async flush(): Promise<void> {
    const pendingWrites = [...this.writeChains.values()];
    await Promise.all(pendingWrites.map((p) => p.catch(() => {})));
  }

  private enqueue(path: string, task: () => Promise<void>): void {
    const previous = this.writeChains.get(path) ?? Promise.resolve();
    const next = previous
      .catch(() => {})
      .then(async () => {
        await mkdir(dirname(path), { recursive: true });
        await task();
      })
      .finally(() => {
        if (this.writeChains.get(path) === next) {
          this.writeChains.delete(path);
        }
      });

    this.writeChains.set(path, next);
    void next.catch((err) => {
      console.warn(`[recording-store] Failed to write ${path}:`, err);
    });
  }
}

function sanitizeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}
