import { randomUUID } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { extname } from "node:path";
import type { IncomingMessage, ServerResponse } from "node:http";

export interface ImageRef {
  id: string;
  url: string;
  mimeType: string;
}

interface StoredImage {
  id: string;
  mimeType: string;
  buffer: Buffer;
  accessedAt: number;
}

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_ENTRIES = 100;

const MIME_TYPES: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

// Matches absolute paths ending with image extensions
const IMAGE_PATH_RE =
  /(\/[\w./_-]+\.(?:png|jpe?g|gif|webp))/gi;

export class ImageStore {
  private store = new Map<string, StoredImage>();

  /** Extract local image file paths from text (ignores URLs). */
  extractImagePaths(text: unknown): string[] {
    const str = typeof text === "string" ? text : JSON.stringify(text ?? "");
    const matches = str.match(IMAGE_PATH_RE);
    if (!matches) return [];
    // Filter out URLs (paths starting with //) and deduplicate
    const localPaths = matches.filter((p) => !p.startsWith("//"));
    return [...new Set(localPaths)];
  }

  /** Read files from disk, assign UUIDs, store in memory. */
  async registerImages(paths: string[]): Promise<ImageRef[]> {
    const refs: ImageRef[] = [];
    for (const filePath of paths) {
      try {
        const st = await stat(filePath);
        if (!st.isFile() || st.size > MAX_FILE_SIZE) {
          console.warn(`[image-store] Skipping ${filePath} (not file or >10MB)`);
          continue;
        }
        const ext = extname(filePath).toLowerCase();
        const mimeType = MIME_TYPES[ext];
        if (!mimeType) continue;

        const buffer = await readFile(filePath);
        const id = randomUUID();
        this.store.set(id, { id, mimeType, buffer, accessedAt: Date.now() });
        const ref: ImageRef = { id, url: `/images/${id}`, mimeType };
        refs.push(ref);

        // Evict LRU if over limit
        while (this.store.size > MAX_ENTRIES) {
          let oldestId: string | null = null;
          let oldestTime = Infinity;
          for (const [key, val] of this.store) {
            if (val.accessedAt < oldestTime) {
              oldestTime = val.accessedAt;
              oldestId = key;
            }
          }
          if (oldestId) this.store.delete(oldestId);
        }
      } catch (err) {
        console.warn(`[image-store] Failed to read ${filePath}:`, err);
      }
    }
    return refs;
  }

  /**
   * Handle HTTP request for image serving.
   * Returns true if the request was handled, false otherwise.
   */
  handleRequest(req: IncomingMessage, res: ServerResponse): boolean {
    const url = req.url ?? "";
    const match = url.match(/^\/images\/([a-f0-9-]+)$/);
    if (!match) return false;

    const id = match[1];
    const entry = this.store.get(id);
    if (!entry) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not Found");
      return true;
    }

    entry.accessedAt = Date.now();
    res.writeHead(200, {
      "Content-Type": entry.mimeType,
      "Content-Length": entry.buffer.length,
      "Cache-Control": "public, max-age=3600",
    });
    res.end(entry.buffer);
    return true;
  }
}
