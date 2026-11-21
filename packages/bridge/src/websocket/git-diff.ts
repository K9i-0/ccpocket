import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { resolve, extname } from "node:path";
import { promisify } from "node:util";
import type { ImageChange } from "../parser.js";
import { isPathWithinAllowedDirectory } from "../path-utils.js";
import {
  IMAGE_EXTENSIONS,
  AUTO_DISPLAY_THRESHOLD,
  MAX_IMAGE_SIZE,
  mimeTypeForExt,
} from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";

/**
 * Scan diff text for image file changes and extract base64 data where appropriate.
 *
 * Detection strategy:
 * 1. Binary markers: "Binary files a/<path> and b/<path> differ"
 * 2. diff --git headers where the file extension is an image type
 *
 * For each detected image file:
 * - Old version: `git show HEAD:<path>` (committed version)
 * - New version: read from working tree
 * - Apply size thresholds for auto-display / on-demand / text-only
 */
export async function collectImageChanges(
  cwd: string,
  diffText: string,
): Promise<ImageChange[]> {
  // Phase 1: Extract image file entries from diff text (synchronous, CPU only)
  interface ImageEntry {
    filePath: string;
    isNew: boolean;
    isDeleted: boolean;
    isSvg: boolean;
    mimeType: string;
    ext: string;
  }
  const entries: ImageEntry[] = [];
  const processedPaths = new Set<string>();

  const lines = diffText.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    const gitMatch = line.match(/^diff --git a\/(.+?) b\/(.+)$/);
    if (!gitMatch) continue;

    const filePath = gitMatch[2];
    const ext = extname(filePath).toLowerCase();
    if (!IMAGE_EXTENSIONS.has(ext)) continue;
    if (processedPaths.has(filePath)) continue;
    processedPaths.add(filePath);

    let isNew = false;
    let isDeleted = false;
    for (let j = i + 1; j < Math.min(i + 6, lines.length); j++) {
      if (lines[j].startsWith("diff --git ")) break;
      if (lines[j].startsWith("new file mode")) isNew = true;
      if (lines[j].startsWith("deleted file mode")) isDeleted = true;
    }

    entries.push({
      filePath,
      isNew,
      isDeleted,
      isSvg: ext === ".svg",
      mimeType: mimeTypeForExt(ext),
      ext,
    });
  }

  if (entries.length === 0) return [];

  // Phase 2: Read image data asynchronously
  const execFileAsync = promisify(execFile);

  const changes: ImageChange[] = [];
  for (const entry of entries) {
    let oldBuf: Buffer | undefined;
    let newBuf: Buffer | undefined;

    // Read old image (committed version)
    if (!entry.isNew) {
      try {
        const result = await execFileAsync(
          "git",
          ["show", `HEAD:${entry.filePath}`],
          {
            cwd,
            maxBuffer: MAX_IMAGE_SIZE + 1024,
            encoding: "buffer",
          },
        );
        oldBuf = result.stdout as unknown as Buffer;
      } catch {
        // File may not exist in HEAD (e.g. untracked)
      }
    }

    // Read new image (working tree)
    if (!entry.isDeleted) {
      try {
        const absPath = resolve(cwd, entry.filePath);
        if (existsSync(absPath)) {
          newBuf = await readFile(absPath);
        }
      } catch {
        // Ignore read errors
      }
    }

    const oldSize = oldBuf?.length;
    const newSize = newBuf?.length;
    const maxSize = Math.max(oldSize ?? 0, newSize ?? 0);

    const autoDisplay =
      maxSize <= AUTO_DISPLAY_THRESHOLD;
    const loadable =
      autoDisplay || maxSize <= MAX_IMAGE_SIZE;

    const change: ImageChange = {
      filePath: entry.filePath,
      isNew: entry.isNew,
      isDeleted: entry.isDeleted,
      isSvg: entry.isSvg,
      mimeType: entry.mimeType,
      loadable,
      autoDisplay: autoDisplay || undefined,
    };

    if (oldSize !== undefined) change.oldSize = oldSize;
    if (newSize !== undefined) change.newSize = newSize;

    // Auto-display images are no longer embedded in the initial response.
    // They are loaded on-demand when the Flutter widget becomes visible.

    changes.push(change);
  }

  return changes;
}

/**
 * Load a single diff image on demand (async I/O for better throughput).
 */
export async function loadDiffImageAsync(
  server: BridgeWebSocketServer,
  cwd: string,
  filePath: string,
  version: "old" | "new",
): Promise<{ base64?: string; mimeType?: string; error?: string }> {
  // Path traversal guard: reject paths containing '..' or absolute paths
  if (filePath.includes("..") || filePath.startsWith("/")) {
    return { error: "Invalid file path" };
  }

  const ext = extname(filePath).toLowerCase();
  if (!IMAGE_EXTENSIONS.has(ext)) {
    return { error: "Not an image file" };
  }
  const mimeType = mimeTypeForExt(ext);

  try {
    const execFileAsync = promisify(execFile);

    let buf: Buffer;
    if (version === "old") {
      const result = await execFileAsync(
        "git",
        ["show", `HEAD:${filePath}`],
        {
          cwd,
          maxBuffer: MAX_IMAGE_SIZE + 1024,
          encoding: "buffer",
        },
      );
      buf = result.stdout as unknown as Buffer;
    } else {
      const absPath = resolve(cwd, filePath);
      // Verify resolved path stays within cwd
      if (!isPathWithinAllowedDirectory(absPath, cwd, server.platform)) {
        return { error: "Invalid file path" };
      }
      buf = await readFile(absPath);
    }

    if (buf.length > MAX_IMAGE_SIZE) {
      return { error: "Image too large" };
    }

    return { base64: buf.toString("base64"), mimeType };
  } catch (err) {
    return { error: err instanceof Error ? err.message : String(err) };
  }
}
