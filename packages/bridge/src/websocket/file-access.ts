import { realpath, stat } from "node:fs/promises";
import { posix, win32 } from "node:path";
import { WebSocket } from "ws";
import type { ClientMessage, ServerMessage } from "../parser.js";
import { isSafeUploadFileName, UploadStoreError } from "../upload-store.js";
import {
  isPathWithinAllowedDirectory,
  resolvePlatformPathFrom,
} from "../path-utils.js";
import { downloadMimeType } from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";

/**
 * Validate that a project path is within the allowed directories.
 * Returns true if the path is allowed, false otherwise.
 */
export function isPathAllowed(
  server: BridgeWebSocketServer,
  path: string,
): boolean {
  if (server.allowedDirs.length === 0) return true;
  return server.allowedDirs.some(
    (dir) => isPathWithinAllowedDirectory(path, dir, server.platform),
  );
}

export async function isCanonicalPathAllowed(
  server: BridgeWebSocketServer,
  path: string,
): Promise<boolean> {
  if (server.allowedDirs.length === 0) return true;
  for (const dir of server.allowedDirs) {
    let canonicalDir = dir;
    try {
      canonicalDir = await realpath(dir);
    } catch {
      // Keep the configured path when the allowed root cannot be resolved.
    }
    if (isPathWithinAllowedDirectory(path, canonicalDir, server.platform)) {
      return true;
    }
  }
  return false;
}

export function isPathInReadOnlyDir(
  server: BridgeWebSocketServer,
  path: string,
): boolean {
  return server.readOnlyDirs.some(
    (dir) => isPathWithinAllowedDirectory(path, dir, server.platform),
  );
}

export async function isCanonicalPathInReadOnlyDir(
  server: BridgeWebSocketServer,
  path: string,
): Promise<boolean> {
  for (const dir of server.readOnlyDirs) {
    let canonicalDir = dir;
    try {
      canonicalDir = await realpath(dir);
    } catch {
      // Keep the configured path when the read-only root cannot be resolved.
    }
    if (isPathWithinAllowedDirectory(path, canonicalDir, server.platform)) {
      return true;
    }
  }
  return false;
}

/**
 * Read access: allowed directories plus BRIDGE_READONLY_DIRS. Use only for
 * file preview, download, and reveal — never for projects or writes.
 */
export function isPathReadable(
  server: BridgeWebSocketServer,
  path: string,
): boolean {
  return isPathAllowed(server, path) || isPathInReadOnlyDir(server, path);
}

export async function isCanonicalPathReadable(
  server: BridgeWebSocketServer,
  path: string,
): Promise<boolean> {
  return (
    (await isCanonicalPathAllowed(server, path)) ||
    (await isCanonicalPathInReadOnlyDir(server, path))
  );
}

export function sendFileDownloadError(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  request: Extract<ClientMessage, { type: "prepare_file_download" }>,
  errorCode:
    | "file_download_not_allowed"
    | "file_download_not_found"
    | "file_download_not_file"
    | "file_download_too_large"
    | "file_download_unavailable"
    | "file_download_failed",
  message: string,
): void {
  server.send(ws, {
    type: "error",
    errorCode,
    message,
    path: request.filePath,
    requestId: request.requestId,
  });
}

export async function prepareFileDownload(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  request: Extract<ClientMessage, { type: "prepare_file_download" }>,
): Promise<void> {
  const pathApi = server.platform === "win32" ? win32 : posix;
  const projectPath = pathApi.resolve(request.projectPath);
  const requestedPath = pathApi.resolve(projectPath, request.filePath);
  if (
    !isPathAllowed(server, projectPath) ||
    (!server.fileDownloadAllowAllPaths &&
      !isPathWithinAllowedDirectory(requestedPath, projectPath, server.platform) &&
      !isPathInReadOnlyDir(server, requestedPath))
  ) {
    sendFileDownloadError(
        server,
      ws,
      request,
      "file_download_not_allowed",
      "The requested file is outside the current project.",
    );
    return;
  }

  let canonicalProjectPath: string;
  try {
    canonicalProjectPath = await realpath(projectPath);
    const projectStat = await stat(canonicalProjectPath);
    if (
      !projectStat.isDirectory() ||
      !(await isCanonicalPathAllowed(server, canonicalProjectPath))
    ) {
      throw new Error("project not allowed");
    }
  } catch {
    sendFileDownloadError(
        server,
      ws,
      request,
      "file_download_not_allowed",
      "The current project is unavailable or not allowed.",
    );
    return;
  }

  let canonicalFilePath: string;
  try {
    canonicalFilePath = await realpath(requestedPath);
  } catch {
    sendFileDownloadError(
        server,
      ws,
      request,
      "file_download_not_found",
      "File not found.",
    );
    return;
  }

  const canonicalFileInProject =
    isPathWithinAllowedDirectory(
      canonicalFilePath,
      canonicalProjectPath,
      server.platform,
    ) && (await isCanonicalPathAllowed(server, canonicalFilePath));
  if (
    !server.fileDownloadAllowAllPaths &&
    !canonicalFileInProject &&
    !(await isCanonicalPathInReadOnlyDir(server, canonicalFilePath))
  ) {
    sendFileDownloadError(
        server,
      ws,
      request,
      "file_download_not_allowed",
      "The requested file resolves outside the current project.",
    );
    return;
  }

  try {
    const fileStat = await stat(canonicalFilePath);
    if (!fileStat.isFile()) {
      sendFileDownloadError(
          server,
        ws,
        request,
        "file_download_not_file",
        "Only regular files can be downloaded.",
      );
      return;
    }
    if (fileStat.size > server.fileDownloadMaxBytes) {
      const maxSizeMb = Math.max(
        1,
        Math.ceil(server.fileDownloadMaxBytes / 1024 / 1024),
      );
      sendFileDownloadError(
          server,
        ws,
        request,
        "file_download_too_large",
        `File is too large to download. Maximum size is ${maxSizeMb} MB.`,
      );
      return;
    }
    if (!server.mediaStore) {
      sendFileDownloadError(
          server,
        ws,
        request,
        "file_download_unavailable",
        "File downloads are unavailable on this Bridge.",
      );
      return;
    }

    const fileName = pathApi.basename(requestedPath);
    const mimeType = downloadMimeType(fileName);
    const ref = await server.mediaStore.register(
      canonicalFilePath,
      mimeType,
      fileStat.size,
      fileName,
    );
    server.send(ws, {
      type: "file_download_ready",
      requestId: request.requestId,
      filePath: request.filePath,
      fileName,
      mimeType: ref.mimeType,
      sizeBytes: ref.sizeBytes,
      downloadUrl: ref.url,
    });
  } catch {
    sendFileDownloadError(
        server,
      ws,
      request,
      "file_download_failed",
      "Unable to prepare the file download.",
    );
  }
}

export function sendFileUploadError(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  requestId: string,
  errorCode: string,
  message: string,
  path?: string,
): void {
  server.send(ws, { type: "error", errorCode, message, requestId, path });
}

export async function prepareFileUpload(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  request: Extract<ClientMessage, { type: "prepare_file_upload" }>,
): Promise<void> {
  const pathApi = server.platform === "win32" ? win32 : posix;
  const projectPath = pathApi.resolve(request.projectPath);
  if (
    !server.uploadStore ||
    pathApi.isAbsolute(request.directoryPath) ||
    !isSafeUploadFileName(request.fileName)
  ) {
    sendFileUploadError(
        server,
      ws,
      request.requestId,
      !server.uploadStore ? "file_upload_unavailable" : "file_upload_not_allowed",
      !server.uploadStore
        ? "File uploads are unavailable on this Bridge."
        : "The upload destination or file name is not allowed.",
      request.directoryPath,
    );
    return;
  }
  if (request.sizeBytes > server.fileUploadMaxBytes) {
    sendFileUploadError(
        server,
      ws,
      request.requestId,
      "file_upload_too_large",
      `File is too large to upload. Maximum size is ${Math.ceil(server.fileUploadMaxBytes / 1024 / 1024)} MB.`,
      request.fileName,
    );
    return;
  }

  const requestedDirectory = pathApi.resolve(projectPath, request.directoryPath || ".");
  if (
    !isPathAllowed(server, projectPath) ||
    !isPathWithinAllowedDirectory(requestedDirectory, projectPath, server.platform)
  ) {
    sendFileUploadError(server, ws, request.requestId, "file_upload_not_allowed", "The upload destination is outside the current project.", request.directoryPath);
    return;
  }

  try {
    const canonicalProject = await realpath(projectPath);
    const canonicalDirectory = await realpath(requestedDirectory);
    const directoryStat = await stat(canonicalDirectory);
    if (
      !directoryStat.isDirectory() ||
      !isPathWithinAllowedDirectory(canonicalDirectory, canonicalProject, server.platform) ||
      !(await isCanonicalPathAllowed(server, canonicalDirectory))
    ) {
      throw new UploadStoreError("file_upload_directory_changed", "The upload destination is not allowed.");
    }
    const ref = await server.uploadStore.register({
      directoryPath: canonicalDirectory,
      relativeDirectoryPath: pathApi
        .relative(projectPath, requestedDirectory)
        .split(pathApi.sep)
        .join("/"),
      fileName: request.fileName,
      sizeBytes: request.sizeBytes,
      conflictPolicy: request.conflictPolicy,
    });
    server.send(ws, {
      type: "file_upload_ready",
      requestId: request.requestId,
      fileName: request.fileName,
      sizeBytes: request.sizeBytes,
      uploadUrl: ref.url,
      uploadToken: ref.token,
    });
  } catch (error) {
    const known = error instanceof UploadStoreError ? error : null;
    sendFileUploadError(
        server,
      ws,
      request.requestId,
      known?.code ?? "file_upload_directory_not_found",
      known?.message ?? "The upload destination was not found or is not allowed.",
      request.directoryPath,
    );
  }
}

export async function finalizeFileUpload(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  request: Extract<ClientMessage, { type: "finalize_file_upload" }>,
): Promise<void> {
  if (!server.uploadStore) {
    sendFileUploadError(server, ws, request.requestId, "file_upload_unavailable", "File uploads are unavailable on this Bridge.");
    return;
  }
  try {
    const result = await server.uploadStore.finalize(request.uploadToken, request.sha256);
    server.send(ws, { type: "file_upload_complete", requestId: request.requestId, ...result });
  } catch (error) {
    const known = error instanceof UploadStoreError ? error : null;
    sendFileUploadError(server, ws, request.requestId, known?.code ?? "file_upload_failed", known?.message ?? "Unable to finish the file upload.");
  }
}

/** Build a user-friendly error for disallowed project paths. */
export function buildPathNotAllowedError(
  projectPath: string,
  requestId?: string,
): Extract<ServerMessage, { type: "error" }> {
  return {
    type: "error",
    message: `⚠ Project path not allowed\n\n"${projectPath}" is not in the allowed directories.\n\nFix: Update BRIDGE_ALLOWED_DIRS on the Bridge server to include this path.`,
    errorCode: "path_not_allowed",
    path: projectPath,
    requestId,
  };
}

export function sendToolActionError(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  message: { sessionId?: string; id?: string; toolUseId?: string },
  error: string,
): void {
  server.send(ws, {
    type: "error",
    message: error,
    sessionId: message.sessionId,
    toolUseId: message.toolUseId ?? message.id,
  });
}

export function normalizeAdditionalWritableRoots(
  server: BridgeWebSocketServer,
  roots: string[] | undefined,
  projectPath: string,
): { roots?: string[]; deniedRoot?: string } {
  if (!roots || roots.length === 0) return {};
  const normalized = new Map<string, string>();
  for (const root of roots) {
    const trimmed = root.trim();
    if (!trimmed) continue;
    const resolved = resolvePlatformPathFrom(
      projectPath,
      trimmed,
      server.platform,
    );
    if (!isPathAllowed(server, resolved)) {
      return { deniedRoot: root };
    }
    const key = server.platform === "win32" ? resolved.toLowerCase() : resolved;
    if (!normalized.has(key)) {
      normalized.set(key, resolved);
    }
  }
  return { roots: [...normalized.values()] };
}
