import { currentGitBranch } from "../../git-project-state.js";
import { WebSocket } from "ws";
import { codexErrorMessage, CodexRpcError } from "../../codex-process.js";
import type { ClientMessage } from "../../parser.js";
import { getAllRecentSessions } from "../../sessions-index.js";
import { resolvePlatformPath } from "../../path-utils.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { recordDebugEvent } from "../debug-trace.js";
import { isPathAllowed, buildPathNotAllowedError } from "../file-access.js";
import { enrichRecentSessionWorkspace } from "../recent-sessions.js";

export async function handleListSessions(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_sessions" }>,
  ws: WebSocket,
): Promise<void> {
  server.sendSessionList(ws);
}

/** Stop a running session and tell every client. False when it is unknown. */
export function stopSessionAndNotify(
  server: BridgeWebSocketServer,
  sessionId: string,
): boolean {
  const session = server.sessionManager.get(sessionId);
  if (!session) return false;
  // Notify clients before destroying (destroy removes listeners)
  server.broadcastSessionMessage(sessionId, {
    type: "result",
    subtype: "stopped",
    sessionId: session.claudeSessionId,
  });
  server.destroySession(sessionId);
  recordDebugEvent(server, sessionId, {
    direction: "internal",
    channel: "bridge",
    type: "session_stopped",
  });
  server.debugEvents.delete(sessionId);
  server.notifiedPermissionToolUses.delete(sessionId);
  server.broadcastSessionList();
  return true;
}

export async function handleStopSession(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "stop_session" }>,
  ws: WebSocket,
): Promise<void> {
  if (!stopSessionAndNotify(server, msg.sessionId)) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Session ${msg.sessionId} not found`,
    });
  }
}

export async function handleResolveSessionLink(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "resolve_session_link" }>,
  ws: WebSocket,
): Promise<void> {
  const provider = msg.provider ?? "claude";
  const activeSession = server.sessionManager
    .list()
    .find(
      (session) =>
        session.provider === provider &&
        (session.id === msg.sessionId ||
          session.claudeSessionId === msg.sessionId),
    );
  if (activeSession) {
    server.send(ws, {
      type: "session_link_resolution",
      requestId: msg.requestId,
      sourceSessionId: msg.sessionId,
      status: "live",
      bridgeSessionId: activeSession.id,
      provider,
    });
    return;
  }

  try {
    let recentSession: Record<string, unknown> | undefined;
    if (provider === "antigravity") {
      const antigravitySessions =
        await server.listRecentAntigravitySessions({
          type: "list_recent_sessions",
        });
      const found = antigravitySessions.find(
        (session) => session.sessionId === msg.sessionId,
      );
      recentSession = found
        ? (enrichRecentSessionWorkspace(server, found) as Record<
            string,
            unknown
          >)
        : undefined;
    } else {
      const { sessions } = await getAllRecentSessions({
        limit: 1,
        provider,
        sessionId: msg.sessionId,
        archivedSessionIds: server.archiveStore.archivedIds(),
      });
      recentSession = sessions[0] as unknown as
        | Record<string, unknown>
        | undefined;
    }
    server.send(ws, {
      type: "session_link_resolution",
      requestId: msg.requestId,
      sourceSessionId: msg.sessionId,
      status: recentSession ? "recent" : "unavailable",
      provider,
      ...(recentSession ? { recentSession } : {}),
    } as Record<string, unknown>);
  } catch (err) {
    console.error("[ws] Failed to resolve session link:", err);
    server.send(ws, {
      type: "session_link_resolution",
      requestId: msg.requestId,
      sourceSessionId: msg.sessionId,
      status: "unavailable",
      provider,
    });
  }
}

export async function handleRefreshBranch(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "refresh_branch" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (session) {
    const cwd = session.worktreePath ?? session.projectPath;
    const branch = currentGitBranch(cwd);
    // Update stored branch so future session_list responses are also current
    session.gitBranch = branch;
    server.send(ws, {
      type: "branch_update",
      sessionId: msg.sessionId,
      branch,
    });
  } else {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Session ${msg.sessionId} not found`,
    });
  }
}

export async function handleListRecentSessions(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ws: WebSocket,
): Promise<void> {
  // Load the Codex thread snapshot ahead of the first search / filter.
  if (msg.provider !== "claude") server.codexThreadSnapshot.warm();
  const isProjectScopedRequest = msg.requestScope === "project";
  const currentRequestId = server.recentSessionsRequestIds.get(ws) ?? 0;
  const requestId = isProjectScopedRequest
    ? currentRequestId
    : currentRequestId + 1;
  if (!isProjectScopedRequest) {
    server.recentSessionsRequestIds.set(ws, requestId);
  }
  server.listRecentSessionsCoalesced(msg)
    .then(({ sessions, hasMore, pinnedSessions }) => {
      // List refreshes supersede older list responses. Project responses
      // are correlated independently by requestId on the client.
      if (
        !isProjectScopedRequest &&
        requestId !== (server.recentSessionsRequestIds.get(ws) ?? 0)
      ) {
        return;
      }
      server.send(ws, {
        type: "recent_sessions",
        sessions,
        hasMore,
        ...(pinnedSessions ? { pinnedSessions } : {}),
        limit: msg.limit,
        offset: msg.offset,
        projectPath: msg.projectPath,
        projectId: msg.projectId,
        workspaceKind: msg.workspaceKind,
        requestScope: msg.requestScope,
        requestId: msg.requestId,
      } as Record<string, unknown>);
    })
    .catch((err) => {
      if (
        !isProjectScopedRequest &&
        requestId !== (server.recentSessionsRequestIds.get(ws) ?? 0)
      ) {
        return;
      }
      server.send(ws, {
        type: "error",
        message: `Failed to list recent sessions: ${err}`,
        errorCode: "recent_sessions_failed",
        path: msg.projectPath,
        projectId: msg.projectId,
        workspaceKind: msg.workspaceKind,
        requestId: msg.requestId,
        requestScope: msg.requestScope,
        offset: msg.offset,
      });
    });
}

export async function handleArchiveSession(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "archive_session" }>,
  ws: WebSocket,
): Promise<void> {
  const { sessionId, provider, projectPath } = msg;
  const archiveProjectPath = resolvePlatformPath(
    projectPath,
    server.platform,
  );
  if (!isPathAllowed(server, archiveProjectPath)) {
    const pathError = buildPathNotAllowedError(projectPath);
    server.send(ws, {
      type: "archive_result",
      sessionId,
      success: false,
      error: pathError.message,
    });
    return;
  }
  void (async () => {
    if (provider === "codex") {
      const activeProcess = server.getActiveCodexProcess();
      const codexProcess =
        activeProcess ??
        (await server.createStandaloneCodexProcess(archiveProjectPath));
      try {
        await codexProcess.archiveThread(sessionId);
      } catch (err) {
        if (!(err instanceof CodexRpcError && err.code === -32601)) {
          throw err;
        }
        console.warn(
          "[ws] thread/archive unsupported; using local archive marker",
        );
      } finally {
        if (!activeProcess) codexProcess.stop();
      }
    }
    await server.archiveStore.archive(
      sessionId,
      provider,
      archiveProjectPath,
    );
  })()
    .then(() => {
      server.send(ws, {
        type: "archive_result",
        sessionId,
        success: true,
      });
    })
    .catch((err) => {
      server.send(ws, {
        type: "archive_result",
        sessionId,
        success: false,
        error: codexErrorMessage(err),
      });
    });
}

export async function handleRenameSession(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "rename_session" }>,
  ws: WebSocket,
): Promise<void> {
  const name = (msg.name as string | null) || null;
  await server.handleRenameSession(ws, msg.sessionId, name, msg);
}
