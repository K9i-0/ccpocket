import { bootstrapProject } from "../../project-bootstrap.js";
import { execFileSync } from "node:child_process";
import { realpath } from "node:fs/promises";
import { WebSocket } from "ws";
import { CodexProcess } from "../../codex-process.js";
import type { ClientMessage } from "../../parser.js";
import {
  DirectoryListingError,
  listAllowedDirectories,
} from "../../directory-listing.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  isCanonicalPathAllowed,
  buildPathNotAllowedError,
} from "../file-access.js";
import {
  legacyProjectHistoryProjects,
  projectsMessage,
  normalizeWorkspaceRoots,
  sendWorkspaceMutationError,
} from "../workspaces.js";

export async function handleListProjectHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_project_history" }>,
  ws: WebSocket,
): Promise<void> {
  const projects = legacyProjectHistoryProjects(server);
  server.send(ws, { type: "project_history", projects });
}

export async function handleRemoveProjectHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "remove_project_history" }>,
  ws: WebSocket,
): Promise<void> {
  server.projectHistory?.removeProject(msg.projectPath);
  const projects = legacyProjectHistoryProjects(server);
  server.send(ws, { type: "project_history", projects });
}

export async function handleListProjects(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_projects" }>,
  ws: WebSocket,
): Promise<void> {
  server.send(ws, projectsMessage(server, msg.requestId));
}

export async function handleBootstrapProject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "bootstrap_project" }>,
  ws: WebSocket,
): Promise<void> {
  try {
    const result = await bootstrapProject({ ...msg,
      isAllowed: (path) => isCanonicalPathAllowed(server, path),
    });
    server.projectHistory?.addProject(result.projectPath);
    server.send(ws, { type: "project_setup_result", requestId: msg.requestId, ...result });
  } catch (error) {
    server.send(ws, { type: "project_setup_result", requestId: msg.requestId, error: (error as Error).message });
  }
}

export async function handleTrustProject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "trust_project" | "initialize_git" }>,
  ws: WebSocket,
): Promise<void> {
  try {
    const projectPath = await realpath(msg.projectPath);
    if (!await isCanonicalPathAllowed(server, projectPath)) throw new Error("Project directory is not allowed");
    if (msg.type === "trust_project") {
      if (msg.sessionId) {
        const session = server.sessionManager.get(msg.sessionId);
        if (!session || session.provider !== "codex" || session.queuedInput ||
            await realpath(session.worktreePath ?? session.projectPath) !== projectPath) {
          throw new Error("Session is unavailable or has queued input");
        }
        await (session.process as CodexProcess).trustProjectAndReload(projectPath);
      } else {
        const proc = new CodexProcess();
        try {
          await proc.initializeOnly(projectPath, 10_000);
          await proc.trustProject(projectPath);
        } finally { proc.stop(); }
      }
    } else {
      // Do not silently turn a subdirectory of another repository into a nested repo.
      let inside = false;
      try { inside = execFileSync("git", ["rev-parse", "--is-inside-work-tree"], { cwd: projectPath, encoding: "utf8", stdio: "pipe" }).trim() === "true"; } catch { /* not initialized */ }
      if (!inside) execFileSync("git", ["init", "-b", "main"], { cwd: projectPath, timeout: 10_000, stdio: "pipe" });
    }
    server.send(ws, { type: "project_setup_result", requestId: msg.requestId, projectPath });
  } catch (error) {
    server.send(ws, { type: "project_setup_result", requestId: msg.requestId, error: (error as Error).message });
  }
}

export async function handleCreateProject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "create_project" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.workspaceStore) {
    server.send(ws, {
      type: "error",
      requestId: msg.requestId,
      errorCode: "projects_unavailable",
      message: "Project storage is unavailable",
    });
    return;
  }
  const normalized = normalizeWorkspaceRoots(server, msg.rootPaths);
  if (normalized.deniedRoot || !normalized.roots) {
    server.send(
      ws,
      buildPathNotAllowedError(
        normalized.deniedRoot ?? msg.rootPaths[0],
      ),
    );
    return;
  }
  try {
    await server.workspaceStore.createProject(msg.name, normalized.roots);
    server.broadcast(projectsMessage(server, msg.requestId));
  } catch (error) {
    sendWorkspaceMutationError(server, ws, msg.requestId, "create Project", error);
  }
}

export async function handleUpdateProject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "update_project" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.workspaceStore) {
    server.send(ws, {
      type: "error",
      requestId: msg.requestId,
      errorCode: "projects_unavailable",
      message: "Project storage is unavailable",
    });
    return;
  }
  const normalized = normalizeWorkspaceRoots(server, msg.rootPaths);
  if (normalized.deniedRoot || !normalized.roots) {
    server.send(
      ws,
      buildPathNotAllowedError(
        normalized.deniedRoot ?? msg.rootPaths[0],
      ),
    );
    return;
  }
  let updated;
  try {
    updated = await server.workspaceStore.updateProject(
      msg.projectId,
      msg.name,
      normalized.roots,
    );
  } catch (error) {
    sendWorkspaceMutationError(server, ws, msg.requestId, "update Project", error);
    return;
  }
  if (!updated) {
    server.send(ws, {
      type: "error",
      requestId: msg.requestId,
      errorCode: "project_not_found",
      message: `Project not found: ${msg.projectId}`,
    });
    return;
  }
  server.broadcast(projectsMessage(server, msg.requestId));
}

export async function handleRemoveProject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "remove_project" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.workspaceStore) {
    sendWorkspaceMutationError(
      server,
      ws,
      msg.requestId,
      "remove Project",
      new Error("Project storage is unavailable"),
    );
    return;
  }
  let removed;
  try {
    removed = await server.workspaceStore.removeProject(msg.projectId);
  } catch (error) {
    sendWorkspaceMutationError(server, ws, msg.requestId, "remove Project", error);
    return;
  }
  if (!removed) {
    server.send(ws, {
      type: "error",
      requestId: msg.requestId,
      errorCode: "project_not_found",
      message: `Project not found: ${msg.projectId}`,
    });
    return;
  }
  server.broadcast(projectsMessage(server, msg.requestId));
}

export async function handleListDirectory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_directory" }>,
  ws: WebSocket,
): Promise<void> {
  try {
    const listing = await listAllowedDirectories(
      msg.path,
      server.allowedDirs,
      server.platform,
      msg.includeHidden ?? false,
      msg.includeFiles ?? false,
    );
    server.send(ws, {
      type: "directory_listing",
      path: listing.path,
      directories: listing.directories,
      ...(listing.files ? { files: listing.files } : {}),
      requestId: msg.requestId,
    });
  } catch (error) {
    const listingError =
      error instanceof DirectoryListingError
        ? error
        : new DirectoryListingError(
            "directory_read_failed",
            "Unable to read directory",
          );
    server.send(ws, {
      type: "error",
      errorCode: listingError.code,
      message: listingError.message,
      path: msg.path,
      requestId: msg.requestId,
    });
  }
}
