import { randomBytes } from "node:crypto";
import { constants } from "node:fs";
import { open, realpath } from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";

export interface MediaRef {
  url: string;
  mimeType: string;
  sizeBytes: number;
}

interface StoredMedia {
  filePath: string;
  mimeType: string;
  expiresAt: number;
  accessedAt: number;
}

export interface ByteRange {
  start: number;
  end: number;
}

interface MediaStoreOptions {
  ttlMs?: number;
  maxEntries?: number;
  now?: () => number;
}

const DEFAULT_TTL_MS = 60 * 60 * 1000;
const DEFAULT_MAX_ENTRIES = 100;
const MEDIA_PATH_PATTERN = /^\/api\/media\/([a-f0-9]{48})$/;

/** Parse a single RFC 7233 byte range. Multiple ranges are intentionally unsupported. */
export function parseByteRange(
  header: string | undefined,
  size: number,
): ByteRange | null | undefined {
  if (header === undefined) return undefined;
  if (!Number.isSafeInteger(size) || size <= 0) return null;

  const match = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!match || (!match[1] && !match[2])) return null;

  if (!match[1]) {
    const suffixLength = Number(match[2]);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0) return null;
    return {
      start: Math.max(0, size - suffixLength),
      end: size - 1,
    };
  }

  const start = Number(match[1]);
  const requestedEnd = match[2] ? Number(match[2]) : size - 1;
  if (
    !Number.isSafeInteger(start) ||
    !Number.isSafeInteger(requestedEnd) ||
    start < 0 ||
    start >= size ||
    requestedEnd < start
  ) {
    return null;
  }

  return { start, end: Math.min(requestedEnd, size - 1) };
}

/**
 * Registers validated local media files and serves them using short-lived,
 * unguessable capability URLs with HTTP byte-range support.
 */
export class MediaStore {
  private readonly entries = new Map<string, StoredMedia>();
  private readonly ttlMs: number;
  private readonly maxEntries: number;
  private readonly now: () => number;

  constructor(options: MediaStoreOptions = {}) {
    this.ttlMs = options.ttlMs ?? DEFAULT_TTL_MS;
    this.maxEntries = options.maxEntries ?? DEFAULT_MAX_ENTRIES;
    this.now = options.now ?? Date.now;
  }

  async register(
    filePath: string,
    mimeType: string,
    sizeBytes: number,
  ): Promise<MediaRef> {
    this.removeExpired();
    const id = randomBytes(24).toString("hex");
    const now = this.now();
    this.entries.set(id, {
      // The caller has already canonicalized and allowlist-checked this path.
      // Resolving it again here would introduce a symlink-swap race between
      // validation and registration.
      filePath,
      mimeType,
      expiresAt: now + this.ttlMs,
      accessedAt: now,
    });
    this.evictLeastRecentlyUsed();
    return { url: `/api/media/${id}`, mimeType, sizeBytes };
  }

  handleRequest(req: IncomingMessage, res: ServerResponse): boolean {
    const url = new URL(req.url ?? "", "http://localhost");
    const match = MEDIA_PATH_PATTERN.exec(url.pathname);
    if (!match) return false;

    if (req.method !== "GET" && req.method !== "HEAD") {
      res.writeHead(405, {
        Allow: "GET, HEAD",
        "Content-Type": "text/plain",
      });
      res.end("Method Not Allowed");
      return true;
    }

    const entry = this.getActiveEntry(match[1]);
    if (!entry) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not Found");
      return true;
    }

    void this.serveEntry(req, res, entry);
    return true;
  }

  private getActiveEntry(id: string): StoredMedia | null {
    const entry = this.entries.get(id);
    if (!entry) return null;
    const now = this.now();
    if (entry.expiresAt <= now) {
      this.entries.delete(id);
      return null;
    }
    entry.accessedAt = now;
    entry.expiresAt = now + this.ttlMs;
    return entry;
  }

  private async serveEntry(
    req: IncomingMessage,
    res: ServerResponse,
    entry: StoredMedia,
  ): Promise<void> {
    let fileHandle: Awaited<ReturnType<typeof open>> | null = null;
    let streamOwnsHandle = false;
    try {
      if ((await realpath(entry.filePath)) !== entry.filePath) {
        this.sendNotFound(res);
        return;
      }
      const noFollow = process.platform === "win32" ? 0 : constants.O_NOFOLLOW;
      fileHandle = await open(entry.filePath, constants.O_RDONLY | noFollow);
      const fileStat = await fileHandle.stat();
      if (!fileStat.isFile()) {
        this.sendNotFound(res);
        return;
      }

      const rangeHeader = Array.isArray(req.headers.range)
        ? req.headers.range[0]
        : req.headers.range;
      const range = parseByteRange(rangeHeader, fileStat.size);
      if (range === null) {
        res.writeHead(416, {
          "Content-Range": `bytes */${fileStat.size}`,
          "Accept-Ranges": "bytes",
          "Cache-Control": "private, no-store",
          "X-Content-Type-Options": "nosniff",
        });
        res.end();
        return;
      }

      const start = range?.start ?? 0;
      const end = range?.end ?? fileStat.size - 1;
      const contentLength = Math.max(0, end - start + 1);
      const headers: Record<string, string | number> = {
        "Content-Type": entry.mimeType,
        "Content-Length": contentLength,
        "Accept-Ranges": "bytes",
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
      };
      if (range) headers["Content-Range"] = `bytes ${start}-${end}/${fileStat.size}`;

      res.writeHead(range ? 206 : 200, headers);
      if (req.method === "HEAD" || contentLength === 0) {
        res.end();
        return;
      }

      const stream = fileHandle.createReadStream({ start, end, autoClose: true });
      streamOwnsHandle = true;
      const destroyStream = () => stream.destroy();
      const removeResponseCloseListener = () =>
        res.off("close", destroyStream);
      res.once("close", destroyStream);
      stream.once("close", removeResponseCloseListener);
      stream.on("error", (error) => res.destroy(error));
      stream.pipe(res);
    } catch {
      this.sendNotFound(res);
    } finally {
      if (fileHandle && !streamOwnsHandle) await fileHandle.close();
    }
  }

  private sendNotFound(res: ServerResponse): void {
    if (res.headersSent) {
      res.destroy();
      return;
    }
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not Found");
  }

  private removeExpired(): void {
    const now = this.now();
    for (const [id, entry] of this.entries) {
      if (entry.expiresAt <= now) this.entries.delete(id);
    }
  }

  private evictLeastRecentlyUsed(): void {
    while (this.entries.size > this.maxEntries) {
      let oldestId: string | undefined;
      let oldestAccess = Infinity;
      for (const [id, entry] of this.entries) {
        if (entry.accessedAt < oldestAccess) {
          oldestId = id;
          oldestAccess = entry.accessedAt;
        }
      }
      if (!oldestId) return;
      this.entries.delete(oldestId);
    }
  }
}
