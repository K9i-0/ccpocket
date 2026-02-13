import { appendFile, mkdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import type { DebugTraceEvent } from "./parser.js";

const DEFAULT_ROOT_DIR = join(homedir(), ".ccpocket", "debug");
const TRACE_DIRNAME = "traces";
const BUNDLE_DIRNAME = "bundles";

export class DebugTraceStore {
  private traceDir: string;
  private bundleDir: string;
  private writeChains = new Map<string, Promise<void>>();

  constructor(rootDir: string = DEFAULT_ROOT_DIR) {
    this.traceDir = join(rootDir, TRACE_DIRNAME);
    this.bundleDir = join(rootDir, BUNDLE_DIRNAME);
  }

  async init(): Promise<void> {
    await mkdir(this.traceDir, { recursive: true });
    await mkdir(this.bundleDir, { recursive: true });
  }

  getTraceFilePath(sessionId: string): string {
    return join(this.traceDir, `${sanitizeSegment(sessionId)}.jsonl`);
  }

  getBundleFilePath(sessionId: string, generatedAt: string): string {
    return join(
      this.bundleDir,
      `${sanitizeSegment(sessionId)}-${timestampToken(generatedAt)}.json`,
    );
  }

  saveBundleAtPath(path: string, bundle: Record<string, unknown>): void {
    const body = JSON.stringify(bundle, null, 2);
    this.enqueue(path, async () => {
      await writeFile(path, body, "utf-8");
    });
  }

  saveBundle(
    sessionId: string,
    generatedAt: string,
    bundle: Record<string, unknown>,
  ): string {
    const path = this.getBundleFilePath(sessionId, generatedAt);
    this.saveBundleAtPath(path, bundle);
    return path;
  }

  record(event: DebugTraceEvent): void {
    const path = this.getTraceFilePath(event.sessionId);
    const line = `${JSON.stringify(event)}\n`;
    this.enqueue(path, async () => {
      await appendFile(path, line, "utf-8");
    });
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
        // Avoid unbounded growth: clear settled chain if no newer chain replaced it.
        if (this.writeChains.get(path) === next) {
          this.writeChains.delete(path);
        }
      });

    this.writeChains.set(path, next);
    void next.catch((err) => {
      console.warn(`[debug-trace-store] Failed to write ${path}:`, err);
    });
  }
}

function sanitizeSegment(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function timestampToken(iso: string): string {
  const token = iso.replace(/[^0-9]/g, "");
  if (token.length >= 17) return token.slice(0, 17);
  if (token.length >= 14) return token.slice(0, 14);
  return Date.now().toString();
}
