import { WebSocket } from "ws";
import type { SessionInfo, SessionSummary } from "../session.js";
import type { ServerMessage } from "../parser.js";
import type { ResolvedWorkspace } from "../workspace-store.js";
import { resolvePlatformPath } from "../path-utils.js";
import { isPathAllowed } from "./file-access.js";
import type { BridgeWebSocketServer } from "../websocket.js";

export function runtimeSessionsWithWorkspaces(server: BridgeWebSocketServer): Array<
  SessionSummary & { workspace?: ResolvedWorkspace }
> {
  return server.sessionManager
    .list()
    .map((summary) => runtimeSessionWithWorkspace(server, summary));
}

export function runtimeSessionWithWorkspace(
  server: BridgeWebSocketServer,
  summary: SessionSummary,
): SessionSummary & { workspace?: ResolvedWorkspace } {
  const session = server.sessionManager.get(summary.id);
  const workspace = session
    ? workspaceForRuntimeSession(server, session)
    : undefined;
  return workspace ? { ...summary, workspace } : summary;
}

export function normalizeWorkspaceRoots(
  server: BridgeWebSocketServer,
  rootPaths: string[],
): {
  roots?: string[];
  deniedRoot?: string;
} {
  const roots: string[] = [];
  const seen = new Set<string>();
  for (const rawPath of rootPaths) {
    const path = resolvePlatformPath(rawPath, server.platform);
    if (!isPathAllowed(server, path)) return { deniedRoot: rawPath };
    if (!seen.has(path)) {
      seen.add(path);
      roots.push(path);
    }
  }
  return roots.length > 0 ? { roots } : {};
}

export async function persistPendingSessionWorkspace(
  server: BridgeWebSocketServer,
  sessionId: string,
): Promise<void> {
  const workspace = server.pendingSessionWorkspaces.get(sessionId);
  const session = server.sessionManager.get(sessionId);
  if (!workspace || !session?.claudeSessionId || !server.workspaceStore) return;
  try {
    await server.workspaceStore.assignSession(
      session.provider,
      session.claudeSessionId,
      workspace,
    );
    server.pendingSessionWorkspaces.delete(sessionId);
  } catch (error) {
    console.error("[workspace] Failed to persist session assignment:", error);
  }
}

export function workspaceForRuntimeSession(
  server: BridgeWebSocketServer,
  session: SessionInfo,
): ResolvedWorkspace | undefined {
  const pending = server.pendingSessionWorkspaces.get(session.id);
  if (pending) {
    return { ...pending, rootPaths: [...pending.rootPaths] };
  }
  if (!session.claudeSessionId || !server.workspaceStore) return undefined;
  const assignment = server.workspaceStore.getAssignment(
    session.provider,
    session.claudeSessionId,
  );
  if (!assignment) return undefined;
  const project = assignment.projectId
    ? server.workspaceStore.getProject(assignment.projectId)
    : undefined;
  const projectName = project?.name ?? assignment.projectName;
  return {
    kind: assignment.kind,
    ...(assignment.projectId ? { projectId: assignment.projectId } : {}),
    ...(projectName ? { projectName } : {}),
    rootPaths: [...assignment.rootPaths],
  };
}

export function attachWorkspaceToRuntimeSession(
  server: BridgeWebSocketServer,
  sessionId: string,
  workspace: ResolvedWorkspace | undefined,
): void {
  if (!workspace) return;
  server.pendingSessionWorkspaces.set(sessionId, workspace);
  void persistPendingSessionWorkspace(server, sessionId);
}

export function projectsMessage(
  server: BridgeWebSocketServer,
  requestId?: string,
): ServerMessage {
  return {
    type: "projects",
    projects: server.workspaceStore?.listProjects() ?? [],
    ...(requestId ? { requestId } : {}),
  };
}

export function sendWorkspaceMutationError(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  requestId: string | undefined,
  action: string,
  error: unknown,
): void {
  server.send(ws, {
    type: "error",
    requestId,
    errorCode: "workspace_write_failed",
    message: `Failed to ${action}: ${error instanceof Error ? error.message : String(error)}`,
  });
}

export function legacyProjectHistoryProjects(server: BridgeWebSocketServer): string[] {
  return server.projectHistory?.getProjects() ?? [];
}
