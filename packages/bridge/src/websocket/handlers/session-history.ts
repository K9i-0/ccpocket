import { transcriptPageRange } from "../../context-compaction.js";
import { WebSocket } from "ws";
import type { ClientMessage, ServerMessage } from "../../parser.js";
import { extractMessageImages } from "../../sessions-index.js";
import { TRANSCRIPT_PAGE_DEFAULT, TRANSCRIPT_PAGE_MAX } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  sendCodexCanonicalLegacyHistory,
  splitPastHistoryMessages,
  sessionTranscriptMessages,
  shouldResetCodexHistoryDelta,
  sendCodexCanonicalHistorySnapshot,
} from "../session-history.js";
import {
  sendCodexCurrentSettings,
  sendClaudeCurrentSettings,
  sendAntigravityCurrentSettings,
  sendBackgroundTasksState,
  sendCodexGoalState,
} from "../session-state.js";
import { runtimeSessionWithWorkspace } from "../workspaces.js";

export async function handleGetHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_history" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (session) {
    if (session.provider === "codex") {
      const handled = await sendCodexCanonicalLegacyHistory(
        server,
        ws,
        msg.sessionId,
        session,
      );
      if (handled) {
        return;
      }
    }

    const splitPastHistory =
      session.pastMessages && session.pastMessages.length > 0
        ? await splitPastHistoryMessages(server, session)
        : { pastMessages: [], historyMessages: [] };
    // Send past conversation from disk (resume) before in-memory history
    if (splitPastHistory.pastMessages.length > 0) {
      server.send(ws, {
        type: "past_history",
        claudeSessionId: session.claudeSessionId ?? msg.sessionId,
        sessionId: msg.sessionId,
        messages: splitPastHistory.pastMessages,
      } as Record<string, unknown>);
    }
    server.send(ws, {
      type: "history",
      messages: [...splitPastHistory.historyMessages, ...session.history],
      sessionId: msg.sessionId,
      ...(session.olderHistoryDropped
        ? { olderHistoryAvailable: true }
        : {}),
    } as Record<string, unknown>);
    if (session.provider === "codex") {
      sendCodexCurrentSettings(server, ws, msg.sessionId, session);
    } else {
      sendClaudeCurrentSettings(server, ws, msg.sessionId, session);
      sendAntigravityCurrentSettings(server, ws, msg.sessionId, session);
    }
    server.send(ws, {
      type: "status",
      status: session.status,
      sessionId: msg.sessionId,
    } as Record<string, unknown>);
    server.sendQueueState(ws, msg.sessionId, session);
    sendBackgroundTasksState(server, ws, msg.sessionId, session);
    if (session.provider === "codex") {
      sendCodexGoalState(server, ws, msg.sessionId, session);
    }

    server.sendCachedCommands(ws, msg.sessionId, session);
  } else {
    server.send(ws, {
      type: "error",
      message: `Session ${msg.sessionId} not found`,
      errorCode: "session_not_found",
      sessionId: msg.sessionId,
    });
  }
}

export async function handleGetSessionTranscript(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_session_transcript" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      message: `Session ${msg.sessionId} not found`,
      errorCode: "session_not_found",
      sessionId: msg.sessionId,
      requestId: msg.requestId,
    });
    return;
  }
  try {
    const transcript = await sessionTranscriptMessages(server, session);
    const { start, end } = transcriptPageRange(
      transcript.map((message) => message.role),
      msg,
      TRANSCRIPT_PAGE_DEFAULT,
      TRANSCRIPT_PAGE_MAX,
    );
    const { pastMessages } = await server.preparePastHistoryMessages(
      session,
      transcript.slice(start, end),
    );
    server.send(ws, {
      type: "session_transcript",
      sessionId: msg.sessionId,
      requestId: msg.requestId,
      provider: session.provider,
      startIndex: start,
      endIndex: end,
      total: transcript.length,
      messages: pastMessages,
    });
  } catch (err) {
    server.send(ws, {
      type: "error",
      message: `Failed to read session transcript: ${
        err instanceof Error ? err.message : String(err)
      }`,
      errorCode: "session_transcript_failed",
      sessionId: msg.sessionId,
      requestId: msg.requestId,
    });
  }
}

export async function handleGetSessionContext(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_session_context" }>,
  ws: WebSocket,
): Promise<void> {
  const context = server.sessionManager.summary(msg.sessionId);
  if (context) {
    server.send(ws, {
      type: "session_context",
      sessionId: msg.sessionId,
      context: { ...runtimeSessionWithWorkspace(server, context) },
    });
  } else {
    server.send(ws, {
      type: "error",
      message: `Session ${msg.sessionId} not found`,
      errorCode: "session_not_found",
      sessionId: msg.sessionId,
    });
  }
}

export async function handleGetHistoryDelta(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_history_delta" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (session?.provider === "codex") {
    const result = server.sessionManager.getHistorySince(
      msg.sessionId,
      msg.sinceSeq,
    );
    if (!result) {
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        message: `Session ${msg.sessionId} not found`,
      });
      return;
    }

    if (
      shouldResetCodexHistoryDelta(
        server,
        session,
        msg.sinceSeq,
        result.kind,
      )
    ) {
      await sendCodexCanonicalHistorySnapshot(
        server,
        ws,
        msg.sessionId,
        session,
      );
      return;
    }

    server.send(ws, {
      type:
        result.kind === "snapshot" ? "history_snapshot" : "history_delta",
      sessionId: msg.sessionId,
      fromSeq: result.fromSeq,
      toSeq: result.toSeq,
      messages: result.entries,
      status: session.status,
      ...(result.kind === "snapshot" ? { reason: result.reason } : {}),
    } as ServerMessage);
    sendCodexCurrentSettings(server, ws, msg.sessionId, session);
    server.sendQueueState(ws, msg.sessionId, session);
    sendBackgroundTasksState(server, ws, msg.sessionId, session);
    sendCodexGoalState(server, ws, msg.sessionId, session);
    server.sendCachedCommands(ws, msg.sessionId, session);
    return;
  }

  if (session) {
    const result = server.sessionManager.getHistorySince(
      msg.sessionId,
      msg.sinceSeq,
    );
    if (!result) {
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        message: `Session ${msg.sessionId} not found`,
      });
      return;
    }
    if (session.pastMessages && session.pastMessages.length > 0) {
      const splitPastHistory =
        await splitPastHistoryMessages(server, session);
      if (splitPastHistory.pastMessages.length > 0) {
        server.send(ws, {
          type: "past_history",
          claudeSessionId: session.claudeSessionId ?? msg.sessionId,
          sessionId: msg.sessionId,
          messages: splitPastHistory.pastMessages,
        } as Record<string, unknown>);
      }
    }
    server.send(ws, {
      type:
        result.kind === "snapshot"
          ? "history_snapshot"
          : "history_delta",
      sessionId: msg.sessionId,
      fromSeq: result.fromSeq,
      toSeq: result.toSeq,
      messages: result.entries,
      status: session.status,
      ...(result.kind === "snapshot" ? { reason: result.reason } : {}),
      ...(result.kind === "snapshot" && session.olderHistoryDropped
        ? { olderHistoryAvailable: true }
        : {}),
    } as ServerMessage);
    sendClaudeCurrentSettings(server, ws, msg.sessionId, session);
    sendAntigravityCurrentSettings(server, ws, msg.sessionId, session);
    server.sendQueueState(ws, msg.sessionId, session);
    sendBackgroundTasksState(server, ws, msg.sessionId, session);
    // The client rebuilds completion from the history it holds, and the
    // init / supported_commands entries fall out of the bounded history.
    server.sendCachedCommands(ws, msg.sessionId, session);
  } else {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Session ${msg.sessionId} not found`,
    });
  }
}

export async function handleListGallery(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_gallery" }>,
  ws: WebSocket,
): Promise<void> {
  const projectPath = msg.projectPath ?? msg.project;
  if (server.galleryStore) {
    const images = server.galleryStore.list({
      projectPath,
      sessionId: msg.sessionId,
    });
    server.send(ws, {
      type: "gallery_list",
      images,
      projectPath,
      sessionId: msg.sessionId,
      requestId: msg.requestId,
    });
  } else {
    server.send(ws, {
      type: "gallery_list",
      images: [],
      projectPath,
      sessionId: msg.sessionId,
      requestId: msg.requestId,
    });
  }
}

export async function handleGetMessageImages(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_message_images" }>,
  ws: WebSocket,
): Promise<void> {
  void extractMessageImages(msg.claudeSessionId, msg.messageUuid)
    .then((images) => {
      const refs: Array<{ id: string; url: string; mimeType: string }> =
        [];
      if (server.imageStore) {
        for (const img of images) {
          const ref = server.imageStore.registerFromBase64(
            img.base64,
            img.mimeType,
          );
          if (ref) refs.push(ref);
        }
      }
      server.send(ws, {
        type: "message_images_result",
        messageUuid: msg.messageUuid,
        images: refs,
      });
    })
    .catch((err) => {
      console.error("[ws] Failed to extract message images:", err);
      server.send(ws, {
        type: "message_images_result",
        messageUuid: msg.messageUuid,
        images: [],
      });
    });
}
