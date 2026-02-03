import { randomUUID } from "node:crypto";
import { readFile, writeFile, mkdir, copyFile, stat, unlink } from "node:fs/promises";
import { join, extname, basename } from "node:path";
import { homedir } from "node:os";
import type { IncomingMessage, ServerResponse } from "node:http";

export interface GalleryImageMeta {
  id: string;
  filename: string;
  mimeType: string;
  projectPath: string;
  sessionId?: string;
  sourcePath: string;
  addedAt: string;
  sizeBytes: number;
}

export interface GalleryImageInfo {
  id: string;
  url: string;
  mimeType: string;
  projectPath: string;
  projectName: string;
  sessionId?: string;
  addedAt: string;
  sizeBytes: number;
}

const GALLERY_DIR = join(homedir(), ".ccpocket", "gallery");
const IMAGES_DIR = join(GALLERY_DIR, "images");
const INDEX_FILE = join(GALLERY_DIR, "index.json");

const MIME_TYPES: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

function projectNameFromPath(projectPath: string): string {
  const parts = projectPath.split("/").filter(Boolean);
  return parts.length > 0 ? parts[parts.length - 1] : projectPath;
}

export class GalleryStore {
  private index: GalleryImageMeta[] = [];

  async init(): Promise<void> {
    await mkdir(IMAGES_DIR, { recursive: true });
    try {
      const data = await readFile(INDEX_FILE, "utf-8");
      this.index = JSON.parse(data) as GalleryImageMeta[];
    } catch {
      // File doesn't exist or is corrupt — start fresh
      this.index = [];
    }
  }

  private async saveIndex(): Promise<void> {
    await writeFile(INDEX_FILE, JSON.stringify(this.index, null, 2), "utf-8");
  }

  async addImage(
    filePath: string,
    projectPath: string,
    sessionId?: string,
  ): Promise<GalleryImageMeta | null> {
    try {
      const st = await stat(filePath);
      if (!st.isFile()) return null;

      const ext = extname(filePath).toLowerCase();
      const mimeType = MIME_TYPES[ext];
      if (!mimeType) return null;

      const id = randomUUID();
      const filename = `${id}${ext}`;
      const destPath = join(IMAGES_DIR, filename);

      await copyFile(filePath, destPath);

      const meta: GalleryImageMeta = {
        id,
        filename,
        mimeType,
        projectPath,
        sessionId,
        sourcePath: filePath,
        addedAt: new Date().toISOString(),
        sizeBytes: st.size,
      };

      this.index.push(meta);
      await this.saveIndex();

      console.log(`[gallery] Added image ${id} from ${basename(filePath)}`);
      return meta;
    } catch (err) {
      console.warn(`[gallery] Failed to add image ${filePath}:`, err);
      return null;
    }
  }

  list(options?: { projectPath?: string; sessionId?: string }): GalleryImageInfo[] {
    let items = this.index;
    if (options?.projectPath) {
      items = items.filter((m) => m.projectPath === options.projectPath);
    }
    if (options?.sessionId) {
      items = items.filter((m) => m.sessionId === options.sessionId);
    }
    // Return newest first
    return [...items]
      .sort((a, b) => new Date(b.addedAt).getTime() - new Date(a.addedAt).getTime())
      .map((m) => ({
        id: m.id,
        url: `/api/gallery/${m.id}`,
        mimeType: m.mimeType,
        projectPath: m.projectPath,
        projectName: projectNameFromPath(m.projectPath),
        sessionId: m.sessionId,
        addedAt: m.addedAt,
        sizeBytes: m.sizeBytes,
      }));
  }

  getImagePath(id: string): string | null {
    const meta = this.index.find((m) => m.id === id);
    if (!meta) return null;
    return join(IMAGES_DIR, meta.filename);
  }

  async delete(id: string): Promise<boolean> {
    const idx = this.index.findIndex((m) => m.id === id);
    if (idx === -1) return false;

    const meta = this.index[idx];
    const filePath = join(IMAGES_DIR, meta.filename);

    try {
      await unlink(filePath);
    } catch {
      // File may already be deleted
    }

    this.index.splice(idx, 1);
    await this.saveIndex();
    console.log(`[gallery] Deleted image ${id}`);
    return true;
  }

  /**
   * Handle HTTP requests for gallery image serving.
   * Returns true if the request was handled.
   */
  handleRequest(req: IncomingMessage, res: ServerResponse): boolean {
    const url = req.url ?? "";

    // Match /api/gallery/:id (alphanumeric, hyphens, underscores)
    const imageMatch = url.match(/^\/api\/gallery\/([a-zA-Z0-9_-]+)$/);

    // GET /api/gallery/:id — serve image file
    if (imageMatch && req.method === "GET") {
      const id = imageMatch[1];
      return this.serveImage(id, res);
    }

    // DELETE /api/gallery/:id
    if (imageMatch && req.method === "DELETE") {
      const id = imageMatch[1];
      this.delete(id).then((ok) => {
        if (ok) {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ deleted: true }));
        } else {
          res.writeHead(404, { "Content-Type": "text/plain" });
          res.end("Not Found");
        }
      }).catch(() => {
        res.writeHead(500, { "Content-Type": "text/plain" });
        res.end("Internal Server Error");
      });
      return true;
    }

    // GET /api/gallery — list images (exact path or with query string)
    if ((url === "/api/gallery" || url.startsWith("/api/gallery?")) && req.method === "GET") {
      const parsedUrl = new URL(url, `http://${req.headers.host ?? "localhost"}`);
      const project = parsedUrl.searchParams.get("project") ?? undefined;
      const images = this.list({ projectPath: project });
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ images }));
      return true;
    }

    return false;
  }

  private serveImage(id: string, res: ServerResponse): boolean {
    const meta = this.index.find((m) => m.id === id);
    if (!meta) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not Found");
      return true;
    }

    const filePath = join(IMAGES_DIR, meta.filename);
    readFile(filePath)
      .then((buffer) => {
        res.writeHead(200, {
          "Content-Type": meta.mimeType,
          "Content-Length": buffer.length,
          "Cache-Control": "public, max-age=3600",
        });
        res.end(buffer);
      })
      .catch(() => {
        res.writeHead(404, { "Content-Type": "text/plain" });
        res.end("Not Found");
      });

    return true;
  }

  /**
   * Handle POST /api/gallery/upload.
   * Accepts JSON body: { filePath: string, projectPath: string, sessionId?: string }
   * Returns true if the request was handled.
   */
  handleUploadRequest(
    req: IncomingMessage,
    res: ServerResponse,
    onNewImage?: (meta: GalleryImageMeta) => void,
  ): boolean {
    const url = req.url ?? "";
    if (url !== "/api/gallery/upload" || req.method !== "POST") return false;

    let body = "";
    req.on("data", (chunk: Buffer) => { body += chunk.toString(); });
    req.on("end", async () => {
      try {
        const parsed = JSON.parse(body) as {
          filePath?: string;
          projectPath?: string;
          sessionId?: string;
        };
        if (!parsed.filePath || !parsed.projectPath) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "filePath and projectPath are required" }));
          return;
        }
        const meta = await this.addImage(
          parsed.filePath,
          parsed.projectPath,
          parsed.sessionId,
        );
        if (!meta) {
          res.writeHead(400, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Failed to add image (unsupported format or file not found)" }));
          return;
        }
        const info = this.metaToInfo(meta);
        if (onNewImage) onNewImage(meta);
        res.writeHead(201, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ image: info }));
      } catch {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Invalid JSON body" }));
      }
    });
    return true;
  }

  /** Convert GalleryImageMeta to GalleryImageInfo for WS broadcast. */
  metaToInfo(meta: GalleryImageMeta): GalleryImageInfo {
    return {
      id: meta.id,
      url: `/api/gallery/${meta.id}`,
      mimeType: meta.mimeType,
      projectPath: meta.projectPath,
      projectName: projectNameFromPath(meta.projectPath),
      sessionId: meta.sessionId,
      addedAt: meta.addedAt,
      sizeBytes: meta.sizeBytes,
    };
  }
}
