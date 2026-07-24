import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { extname, isAbsolute, resolve } from "node:path";
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
  /**
   * Avoid decoding the same base64 payload again during repeated history
   * conversion. The final public id is still derived from decoded bytes so it
   * stays stable across Bridge restarts and file/base64 registration paths.
   */
  private base64Ids = new Map<string, string>();

  private cachedBase64Id(key: string): string | undefined {
    const id = this.base64Ids.get(key);
    if (!id) return undefined;
    this.base64Ids.delete(key);
    this.base64Ids.set(key, id);
    return id;
  }

  private rememberBase64Id(key: string, id: string): void {
    this.base64Ids.delete(key);
    this.base64Ids.set(key, id);
    while (this.base64Ids.size > MAX_ENTRIES) {
      const oldestKey = this.base64Ids.keys().next().value as
        | string
        | undefined;
      if (!oldestKey) break;
      this.base64Ids.delete(oldestKey);
    }
  }

  private imageId(buffer: Buffer, mimeType: string): string {
    return createHash("sha256")
      .update(mimeType.toLowerCase())
      .update("\0")
      .update(buffer)
      .digest("hex");
  }

  private imageRef(id: string, mimeType: string): ImageRef {
    return { id, url: `/images/${id}`, mimeType };
  }

  private touch(id: string): ImageRef | null {
    const existing = this.store.get(id);
    if (!existing) return null;
    existing.accessedAt = Date.now();
    return this.imageRef(id, existing.mimeType);
  }

  private storeBuffer(buffer: Buffer, mimeType: string): ImageRef {
    const id = this.imageId(buffer, mimeType);
    const existing = this.touch(id);
    if (existing) return existing;

    this.store.set(id, { id, mimeType, buffer, accessedAt: Date.now() });
    this.evictLRU();
    return this.imageRef(id, mimeType);
  }

  private async resolveReadablePath(filePath: string, projectPath?: string): Promise<string | null> {
    const candidates: string[] = [];
    if (projectPath) {
      if (isAbsolute(filePath)) {
        candidates.push(filePath);
        // Tool outputs sometimes return project-root-relative paths with a
        // leading slash (e.g. /images/foo.png). Try resolving against project.
        candidates.push(resolve(projectPath, filePath.replace(/^\/+/, "")));
      } else {
        candidates.push(resolve(projectPath, filePath));
        candidates.push(filePath);
      }
    } else {
      candidates.push(filePath);
    }

    for (const candidate of candidates) {
      try {
        const st = await stat(candidate);
        if (st.isFile() && st.size <= MAX_FILE_SIZE) return candidate;
      } catch {
        // Try next candidate.
      }
    }
    return null;
  }

  /** Evict least-recently-used entries if store exceeds MAX_ENTRIES. */
  private evictLRU(): void {
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
  }

  /** Extract local image file paths from text (ignores URLs). */
  extractImagePaths(text: unknown): string[] {
    const str = typeof text === "string" ? text : JSON.stringify(text ?? "");
    const matches = str.match(IMAGE_PATH_RE);
    if (!matches) return [];
    // Filter out URLs (paths starting with //) and deduplicate
    const localPaths = matches.filter((p) => !p.startsWith("//"));
    return [...new Set(localPaths)];
  }

  /** Register an image from raw base64 data. Returns an ImageRef with a URL for HTTP access. */
  registerFromBase64(base64Data: string, mimeType: string): ImageRef | null {
    try {
      const base64Key = createHash("sha256")
        .update(mimeType.toLowerCase())
        .update("\0")
        .update(base64Data)
        .digest("hex");
      const knownId = this.cachedBase64Id(base64Key);
      if (knownId) {
        const existing = this.touch(knownId);
        if (existing) return existing;
        this.base64Ids.delete(base64Key);
      }

      const buffer = Buffer.from(base64Data, "base64");
      if (buffer.length > MAX_FILE_SIZE) {
        console.warn(`[image-store] Skipping base64 image (>10MB)`);
        return null;
      }

      const ref = this.storeBuffer(buffer, mimeType);
      this.rememberBase64Id(base64Key, ref.id);
      return ref;
    } catch (err) {
      console.warn(`[image-store] Failed to register base64 image:`, err);
      return null;
    }
  }

  /** Read files from disk and store them using content-addressed ids. */
  async registerImages(paths: string[], projectPath?: string): Promise<ImageRef[]> {
    const refs: ImageRef[] = [];
    for (const filePath of paths) {
      try {
        const resolvedPath = await this.resolveReadablePath(filePath, projectPath);
        if (!resolvedPath) {
          console.warn(`[image-store] Skipping ${filePath} (not file or >10MB)`);
          continue;
        }
        const ext = extname(resolvedPath).toLowerCase();
        const mimeType = MIME_TYPES[ext];
        if (!mimeType) continue;

        const buffer = await readFile(resolvedPath);
        refs.push(this.storeBuffer(buffer, mimeType));
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
      "Cache-Control": "public, max-age=604800",
    });
    res.end(entry.buffer);
    return true;
  }
}
