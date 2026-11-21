import { existsSync } from "node:fs";
import { lstat, readFile, readlink, realpath, stat } from "node:fs/promises";
import { resolve, extname } from "node:path";
import { WebSocket } from "ws";
import { textPreview } from "../../text-preview.js";
import {
  consumeFinderProof,
  verifyFinderSocketProof,
  revealInFinder,
} from "../../finder-reveal.js";
import type { ClientMessage } from "../../parser.js";
import {
  listProjectFilesAndDirectoriesForClient,
} from "../../git-operations.js";
import {
  projectRequestMetadata,
  FILE_PEEK_MEDIA_TYPES,
  FILE_PEEK_IMAGE_EXTENSIONS,
  MAX_IMAGE_SIZE,
  mimeTypeForExt,
} from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  prepareFileDownload,
  prepareFileUpload,
  finalizeFileUpload,
  isPathReadable,
  isCanonicalPathReadable,
  isPathAllowed,
  buildPathNotAllowedError,
} from "../file-access.js";

export async function handlePrepareFileDownload(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "prepare_file_download" }>,
  ws: WebSocket,
): Promise<void> {
  void prepareFileDownload(server, ws, msg);
}

export async function handlePrepareFileUpload(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "prepare_file_upload" }>,
  ws: WebSocket,
): Promise<void> {
  void prepareFileUpload(server, ws, msg);
}

export async function handleFinalizeFileUpload(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "finalize_file_upload" }>,
  ws: WebSocket,
): Promise<void> {
  void finalizeFileUpload(server, ws, msg);
}

export async function handleCancelFileUpload(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "cancel_file_upload" }>,
  ws: WebSocket,
): Promise<void> {
  if (server.uploadStore) void server.uploadStore.cancel(msg.uploadToken);
}

export async function handleRevealFileLocal(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "reveal_file_local" | "reveal_file" }>,
  ws: WebSocket,
): Promise<void> {
  void (async () => {
    const reply = (
      errorCode?: "not_local_mac" | "path_not_allowed" | "reveal_failed",
    ) => server.send(ws, {
      type: "reveal_file_result",
      requestId: msg.requestId,
      ...(errorCode ? { errorCode } : {}),
    });
    if (
      server.platform !== "darwin" ||
      !(await (msg.type === "reveal_file_local"
        ? verifyFinderSocketProof(msg.proofPort, msg.proofToken)
        : consumeFinderProof(msg.proofPath, msg.proofToken)))
    ) {
      reply("not_local_mac");
      return;
    }
    try {
      const path = resolve(msg.projectPath, msg.filePath);
      if (!isPathReadable(server, path)) {
        reply("path_not_allowed");
        return;
      }
      const canonicalPath = await realpath(path);
      if (!(await isCanonicalPathReadable(server, canonicalPath))) {
        reply("path_not_allowed");
        return;
      }
      await revealInFinder(canonicalPath);
      reply();
    } catch {
      reply("reveal_failed");
    }
  })();
}

export async function handleReadFile(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "read_file" | "read_media_file" | "read_model_file" }>,
  ws: WebSocket,
): Promise<void> {
  const responseMetadata = {
    ...projectRequestMetadata(msg),
    filePath: msg.filePath,
  };
  const absPath = resolve(msg.projectPath, msg.filePath);
  if (!isPathReadable(server, absPath)) {
    server.send(ws, {
      type: "file_content",
      ...responseMetadata,
      content: "",
      error: "Path not allowed",
    });
    return;
  }
  void (async () => {
    try {
      if (!existsSync(absPath)) {
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          content: "",
          error: "File not found",
        });
        return;
      }
      const fileStat = await lstat(absPath);
      if (fileStat.isSymbolicLink()) {
        let targetPath = "";
        try {
          targetPath = await readlink(absPath);
        } catch {
          // Best effort only; the user-facing error still works without it.
        }
        let resolvedTargetStat;
        try {
          resolvedTargetStat = await stat(absPath);
        } catch {
          server.send(ws, {
            type: "file_content",
            ...responseMetadata,
            content: "",
            error:
              targetPath.length > 0
                ? `This symbolic link points to a missing target: ${targetPath}`
                : "This symbolic link points to a missing target.",
          });
          return;
        }
        if (resolvedTargetStat.isDirectory()) {
          server.send(ws, {
            type: "file_content",
            ...responseMetadata,
            content: "",
            error:
              targetPath.length > 0
                ? `This symbolic link points to a directory (${targetPath}). Open the target directory instead.`
                : "This symbolic link points to a directory. Open the target directory instead.",
          });
          return;
        }
      } else if (fileStat.isDirectory()) {
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          content: "",
          error: "This path is a directory. Open a file instead.",
        });
        return;
      }
      const resolvedFileStat = fileStat.isSymbolicLink()
        ? await stat(absPath)
        : fileStat;
      const canonicalPath = await realpath(absPath);
      if (!(await isCanonicalPathReadable(server, canonicalPath))) {
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          content: "",
          error: "Path not allowed",
        });
        return;
      }
      const ext = extname(absPath).toLowerCase();
      if (msg.type === "read_model_file") {
        const error =
          ext !== ".glb"
            ? "Unsupported 3D file type. Use a GLB file."
            : resolvedFileStat.size > 50 * 1024 * 1024
              ? "model_too_large"
              : !server.mediaStore
                ? "3D preview is unavailable on this Bridge."
                : undefined;
        if (error) {
          server.send(ws, {
            type: "file_content",
            ...responseMetadata,
            kind: "model",
            content: "",
            error,
          });
          return;
        }
        const ref = await server.mediaStore!.register(
          canonicalPath,
          "model/gltf-binary",
          resolvedFileStat.size,
        );
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          kind: "model",
          content: "",
          mimeType: ref.mimeType,
          sizeBytes: ref.sizeBytes,
          mediaUrl: ref.url,
        });
        return;
      }
      const mediaType =
        ext === ".pdf"
          ? { kind: "pdf" as const, mimeType: "application/pdf" }
          : FILE_PEEK_MEDIA_TYPES[ext];
      if (mediaType) {
        if (!server.mediaStore) {
          server.send(ws, {
            type: "file_content",
            ...responseMetadata,
            kind: mediaType.kind,
            content: "",
            mimeType: mediaType.mimeType,
            sizeBytes: resolvedFileStat.size,
            error: "Media preview is unavailable on this Bridge.",
          });
          return;
        }
        const ref = await server.mediaStore.register(
          canonicalPath,
          mediaType.mimeType,
          resolvedFileStat.size,
        );
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          kind: mediaType.kind,
          content: "",
          mimeType: ref.mimeType,
          sizeBytes: ref.sizeBytes,
          mediaUrl: ref.url,
        });
        return;
      }
      if (msg.type === "read_media_file") {
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          content: "",
          error: "Unsupported media file type.",
        });
        return;
      }
      if (FILE_PEEK_IMAGE_EXTENSIONS.has(ext)) {
        const mimeType = mimeTypeForExt(ext);
        if (resolvedFileStat.size > MAX_IMAGE_SIZE) {
          server.send(ws, {
            type: "file_content",
            ...responseMetadata,
            kind: "image",
            content: "",
            mimeType,
            sizeBytes: resolvedFileStat.size,
            error: "Image too large to preview. Maximum size is 5 MB.",
          });
          return;
        }
        const buf = await readFile(absPath);
        server.send(ws, {
          type: "file_content",
          ...responseMetadata,
          kind: "image",
          content: "",
          base64: buf.toString("base64"),
          mimeType,
          sizeBytes: buf.length,
        });
        return;
      }
      const maxLines =
        typeof msg.maxLines === "number" && msg.maxLines > 0
          ? msg.maxLines
          : 5000;
      const raw = await readFile(absPath, "utf-8");
      const textExt = ext.replace(/^\./, "").toLowerCase();
      const languageMap: Record<string, string> = {
        ts: "typescript",
        tsx: "typescript",
        js: "javascript",
        jsx: "javascript",
        py: "python",
        rb: "ruby",
        rs: "rust",
        go: "go",
        java: "java",
        kt: "kotlin",
        swift: "swift",
        dart: "dart",
        c: "c",
        cpp: "cpp",
        h: "c",
        hpp: "cpp",
        cs: "csharp",
        sh: "bash",
        zsh: "bash",
        yml: "yaml",
        yaml: "yaml",
        json: "json",
        toml: "toml",
        md: "markdown",
        html: "html",
        css: "css",
        scss: "css",
        sql: "sql",
        xml: "xml",
        dockerfile: "dockerfile",
        makefile: "makefile",
        gradle: "groovy",
      };
      const language = languageMap[textExt] ?? (textExt || undefined);
      const preview = textPreview(raw, maxLines);
      server.send(ws, {
        type: "file_content",
        ...responseMetadata,
        kind: "text",
        content: preview.content,
        language,
        totalLines: preview.totalLines,
        truncated: preview.truncated,
      });
    } catch (err) {
      server.send(ws, {
        type: "file_content",
        ...responseMetadata,
        content: "",
        error: `Failed to read file: ${err}`,
      });
    }
  })();
}

export async function handleListFiles(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_files" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "file_list",
      ...projectRequestMetadata(msg),
      files: [],
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  void (async () => {
    try {
      const result = await listProjectFilesAndDirectoriesForClient(
        msg.projectPath,
        {
          maxEntries: server.fileListMaxEntries,
          maxBytes: server.fileListMaxBytes,
        },
      );
      server.send(ws, {
        type: "file_list",
        ...projectRequestMetadata(msg),
        files: result.files,
        ignored: result.ignored,
        modifiedAt: result.modifiedAt,
        totalFiles: result.totalFiles,
        truncated: result.truncated,
      } as Record<string, unknown>);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      server.send(ws, {
        type: "file_list",
        ...projectRequestMetadata(msg),
        files: [],
        error: `Failed to list files: ${message}`,
      });
    }
  })();
}
