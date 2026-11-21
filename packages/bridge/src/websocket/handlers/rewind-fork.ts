import { WebSocket } from "ws";
import { SdkProcess } from "../../sdk-process.js";
import type { ClientMessage } from "../../parser.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  rewindCodexConversation,
  forkClaudeSession,
  forkCodexSession,
} from "../rewind-fork.js";

export async function handleRewindDryRun(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "rewind_dry_run" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "rewind_preview",
      sessionId: msg.sessionId,
      canRewind: false,
      error: `Session ${msg.sessionId} not found`,
    });
    return;
  }
  if (session.provider === "codex") {
    server.send(ws, {
      type: "rewind_preview",
      sessionId: msg.sessionId,
      canRewind: false,
      error: "Codex rewind does not restore files",
    });
    return;
  }
  server.sessionManager
    .rewindFiles(msg.sessionId, msg.targetUuid, true)
    .then((result) => {
      server.send(ws, {
        type: "rewind_preview",
        sessionId: msg.sessionId,
        canRewind: result.canRewind,
        filesChanged: result.filesChanged,
        insertions: result.insertions,
        deletions: result.deletions,
        error: result.error,
      });
    })
    .catch((err) => {
      server.send(ws, {
        type: "rewind_preview",
        sessionId: msg.sessionId,
        canRewind: false,
        error: `Dry run failed: ${err}`,
      });
    });
}

export async function handleRewind(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "rewind" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "rewind_result",
      sessionId: msg.sessionId,
      success: false,
      mode: msg.mode,
      error: `Session ${msg.sessionId} not found`,
    });
    return;
  }

  const handleError = (err: unknown) => {
    const errMsg = err instanceof Error ? err.message : String(err);
    server.send(ws, {
      type: "rewind_result",
      sessionId: msg.sessionId,
      success: false,
      mode: msg.mode,
      error: errMsg,
    });
  };

  if (session.provider === "antigravity") {
    handleError(new Error("Rewind is not supported for Antigravity sessions"));
    return;
  }
  if (session.provider === "codex") {
    rewindCodexConversation(server, ws, msg.sessionId, msg.targetUuid, msg.mode)
      .catch(handleError);
    return;
  }

  if (msg.mode === "code") {
    // Code-only rewind: rewind files without restarting the conversation
    server.sessionManager
      .rewindFiles(msg.sessionId, msg.targetUuid)
      .then((result) => {
        if (result.canRewind) {
          server.send(ws, {
            type: "rewind_result",
            sessionId: msg.sessionId,
            success: true,
            mode: "code",
          });
        } else {
          server.send(ws, {
            type: "rewind_result",
            sessionId: msg.sessionId,
            success: false,
            mode: "code",
            error: result.error ?? "Cannot rewind files",
          });
        }
      })
      .catch(handleError);
  } else if (msg.mode === "conversation") {
    // Conversation-only rewind: restart session at the target UUID
    try {
      server.flushSessionDeltaBatches(msg.sessionId);
      server.sessionManager.rewindConversation(
        msg.sessionId,
        msg.targetUuid,
        (newSessionId) => {
          server.send(ws, {
            type: "rewind_result",
            sessionId: msg.sessionId,
            success: true,
            mode: "conversation",
          });
          // Notify the new session ID
          const newSession = server.sessionManager.get(newSessionId);
          const rewindPermMode =
            newSession?.process instanceof SdkProcess
              ? newSession.process.permissionMode
              : undefined;
          server.send(
            ws,
            server.buildSessionCreatedMessage({
              sessionId: newSessionId,
              provider: newSession?.provider ?? "claude",
              projectPath: newSession?.projectPath ?? "",
              session: newSession,
              permissionMode: rewindPermMode,
              sourceSessionId: msg.sessionId,
            }),
          );
          server.sendSessionList(ws);
        },
      );
    } catch (err) {
      handleError(err);
    }
  } else {
    // Both: rewind files first, then rewind conversation
    server.sessionManager
      .rewindFiles(msg.sessionId, msg.targetUuid)
      .then((result) => {
        if (!result.canRewind) {
          server.send(ws, {
            type: "rewind_result",
            sessionId: msg.sessionId,
            success: false,
            mode: "both",
            error: result.error ?? "Cannot rewind files",
          });
          return;
        }
        try {
          server.flushSessionDeltaBatches(msg.sessionId);
          server.sessionManager.rewindConversation(
            msg.sessionId,
            msg.targetUuid,
            (newSessionId) => {
              server.send(ws, {
                type: "rewind_result",
                sessionId: msg.sessionId,
                success: true,
                mode: "both",
              });
              const newSession = server.sessionManager.get(newSessionId);
              const rewindPermMode2 =
                newSession?.process instanceof SdkProcess
                  ? newSession.process.permissionMode
                  : undefined;
              server.send(
                ws,
                server.buildSessionCreatedMessage({
                  sessionId: newSessionId,
                  provider: newSession?.provider ?? "claude",
                  projectPath: newSession?.projectPath ?? "",
                  session: newSession,
                  permissionMode: rewindPermMode2,
                  sourceSessionId: msg.sessionId,
                }),
              );
              server.sendSessionList(ws);
            },
          );
        } catch (err) {
          handleError(err);
        }
      })
      .catch(handleError);
  }
}

export async function handleFork(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "fork" }>,
  ws: WebSocket,
): Promise<void> {
  const forkSource = server.sessionManager.get(msg.sessionId);
  const fork =
    forkSource?.provider === "antigravity"
      ? Promise.reject(
          new Error("Fork is not supported for Antigravity sessions"),
        )
      : forkSource?.provider === "claude"
        ? forkClaudeSession(server, ws, msg.sessionId, msg.targetUuid)
        : forkCodexSession(server, ws, msg.sessionId, msg.targetUuid);
  fork.catch((err) => {
    const errMsg = err instanceof Error ? err.message : String(err);
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: errMsg,
      errorCode: "fork_failed",
    });
  });
}
