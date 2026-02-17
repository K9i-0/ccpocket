import { appendFile, mkdir, readdir, readFile, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { ClientMessage, ServerMessage } from "./parser.js";

const DEFAULT_ROOT_DIR = join(homedir(), ".ccpocket", "debug");
const RECORDING_DIRNAME = "recordings";

export interface RecordingMeta {
  bridgeSessionId: string;
  claudeSessionId?: string;
  projectPath: string;
  createdAt: string;
}

export interface RecordingFileInfo {
  name: string;
  path: string;
  modified: string;
  sizeBytes: number;
  meta?: RecordingMeta;
  // Enriched from sessions-index (populated by websocket layer)
  summary?: string;
  firstPrompt?: string;
  lastPrompt?: string;
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

  private getMetaPath(sessionId: string): string {
    return join(this.recordingDir, `${sanitizeSegment(sessionId)}.meta.json`);
  }

  /** Save or update session metadata alongside the recording. */
  saveMeta(sessionId: string, meta: RecordingMeta): void {
    const path = this.getMetaPath(sessionId);
    this.enqueue(path, async () => {
      await writeFile(path, JSON.stringify(meta, null, 2), "utf-8");
    });
  }

  /** Read session metadata. */
  async getMeta(sessionId: string): Promise<RecordingMeta | null> {
    try {
      const raw = await readFile(this.getMetaPath(sessionId), "utf-8");
      return JSON.parse(raw) as RecordingMeta;
    } catch {
      return null;
    }
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

  /** List all recording files, newest first, with metadata if available. */
  async listRecordings(): Promise<RecordingFileInfo[]> {
    try {
      const entries = await readdir(this.recordingDir);
      const results: RecordingFileInfo[] = [];
      for (const entry of entries) {
        if (!entry.endsWith(".jsonl")) continue;
        const name = entry.replace(/\.jsonl$/, "");
        const filePath = join(this.recordingDir, entry);
        const s = await stat(filePath);
        const meta = await this.getMeta(name);
        results.push({
          name,
          path: filePath,
          modified: s.mtime.toISOString(),
          sizeBytes: s.size,
          ...(meta ? { meta } : {}),
        });
      }
      results.sort((a, b) => b.modified.localeCompare(a.modified));
      return results;
    } catch {
      return [];
    }
  }

  /**
   * Extract key info directly from JSONL content without requiring meta or sessions-index.
   * Scans for first/last user input messages and claudeSessionId from system messages.
   */
  async extractInfoFromJsonl(sessionId: string): Promise<{
    firstPrompt?: string;
    lastPrompt?: string;
    claudeSessionId?: string;
    projectPath?: string;
  }> {
    try {
      const content = await readFile(this.getFilePath(sessionId), "utf-8");
      const lines = content.trim().split("\n");
      let firstPrompt: string | undefined;
      let lastPrompt: string | undefined;
      let claudeSessionId: string | undefined;
      let projectPath: string | undefined;

      for (const line of lines) {
        try {
          const event = JSON.parse(line) as RecordedEvent;
          const msg = event.message as Record<string, unknown>;

          // Extract user input messages (incoming "input" type)
          if (event.direction === "incoming" && msg.type === "input" && typeof msg.text === "string") {
            if (!firstPrompt) firstPrompt = msg.text;
            lastPrompt = msg.text;
          }

          // Extract claudeSessionId from system messages
          if (event.direction === "outgoing" && msg.type === "system" && typeof msg.sessionId === "string") {
            // Claude CLI session IDs are full UUIDs (36 chars)
            const sid = msg.sessionId as string;
            if (sid.length > 8 && !claudeSessionId) {
              claudeSessionId = sid;
            }
          }

          // Extract projectPath from start messages
          if (event.direction === "incoming" && msg.type === "start" && typeof msg.projectPath === "string") {
            projectPath = msg.projectPath as string;
          }
        } catch {
          // skip malformed lines
        }
      }

      return { firstPrompt, lastPrompt, claudeSessionId, projectPath };
    } catch {
      return {};
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
