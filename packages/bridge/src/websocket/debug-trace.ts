import type { SessionInfo } from "../session.js";
import type {
  ClientMessage,
  DebugTraceEvent,
  ServerMessage,
} from "../parser.js";
import { MAX_DEBUG_EVENTS, MAX_HISTORY_SUMMARY_ITEMS } from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";
import { buildResumeSessionMessage } from "./session-state.js";

export function extractSessionIdFromClientMessage(
  msg: ClientMessage,
): string | undefined {
  return "sessionId" in msg && typeof msg.sessionId === "string"
    ? msg.sessionId
    : undefined;
}

export function extractSessionIdFromServerMessage(
  msg: ServerMessage | Record<string, unknown>,
): string | undefined {
  if ("sessionId" in msg && typeof msg.sessionId === "string")
    return msg.sessionId;
  return undefined;
}

export function recordDebugEvent(
  server: BridgeWebSocketServer,
  sessionId: string,
  event: Omit<DebugTraceEvent, "ts" | "sessionId">,
): void {
  const events = server.debugEvents.get(sessionId) ?? [];
  const fullEvent: DebugTraceEvent = {
    ts: new Date().toISOString(),
    sessionId,
    ...event,
  };
  events.push(fullEvent);
  if (events.length > MAX_DEBUG_EVENTS) {
    events.splice(0, events.length - MAX_DEBUG_EVENTS);
  }
  server.debugEvents.set(sessionId, events);
  server.debugTraceStore.record(fullEvent);
}

export function getDebugEvents(
  server: BridgeWebSocketServer,
  sessionId: string,
  limit: number,
): DebugTraceEvent[] {
  const events = server.debugEvents.get(sessionId) ?? [];
  const capped = Math.max(
    0,
    Math.min(limit, MAX_DEBUG_EVENTS),
  );
  if (capped === 0) return [];
  return events.slice(-capped);
}

export function buildHistorySummary(
  server: BridgeWebSocketServer,
  history: ServerMessage[],
): string[] {
  const lines = history.map((msg, index) => {
    const num = String(index + 1).padStart(3, "0");
    return `${num}. ${summarizeServerMessage(msg)}`;
  });
  if (lines.length <= MAX_HISTORY_SUMMARY_ITEMS) {
    return lines;
  }
  return lines.slice(-MAX_HISTORY_SUMMARY_ITEMS);
}

export function summarizeClientMessage(msg: ClientMessage): string {
  switch (msg.type) {
    case "input": {
      const textPreview = msg.text.replace(/\s+/g, " ").trim().slice(0, 80);
      const hasImage = msg.imageBase64 != null || msg.imageId != null;
      return `text=\"${textPreview}\" image=${hasImage} skills=${msg.skills?.length ?? (msg.skill ? 1 : 0)} mentions=${msg.mentions?.length ?? 0}`;
    }
    case "push_register":
      return `platform=${msg.platform} token=${msg.token.slice(0, 8)}...`;
    case "push_unregister":
      return `token=${msg.token.slice(0, 8)}...`;
    case "approve":
    case "approve_always":
    case "reject":
      return `id=${msg.id}`;
    case "answer":
      return `toolUseId=${msg.toolUseId}`;
    case "install_tool_suggestion":
      return `toolUseId=${msg.toolUseId}`;
    case "start":
      return `projectPath=${msg.projectPath} provider=${msg.provider ?? "claude"}`;
    case "resume_session":
      return `sessionId=${msg.sessionId} provider=${msg.provider ?? "claude"}`;
    case "get_debug_bundle":
      return `traceLimit=${msg.traceLimit ?? MAX_DEBUG_EVENTS} includeDiff=${msg.includeDiff ?? true}`;
    case "get_usage":
      return "get_usage";
    default:
      return msg.type;
  }
}

export function summarizeServerMessage(msg: ServerMessage): string {
  switch (msg.type) {
    case "assistant": {
      const textChunks: string[] = [];
      for (const content of msg.message.content) {
        if (content.type === "text") {
          textChunks.push(content.text);
        }
      }
      const text = textChunks
        .join(" ")
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 100);
      return text ? `assistant: ${text}` : "assistant";
    }
    case "tool_result": {
      const contentPreview = msg.content
        .replace(/\s+/g, " ")
        .trim()
        .slice(0, 100);
      return `${msg.toolName ?? "tool_result"}(${msg.toolUseId}) ${contentPreview}`;
    }
    case "permission_request":
      return `${msg.toolName}(${msg.toolUseId})`;
    case "result":
      return `${msg.subtype}${msg.error ? ` error=${msg.error}` : ""}`;
    case "status":
      return msg.status;
    case "error":
      return msg.message;
    case "stream_delta":
    case "thinking_delta":
      return `${msg.type}(${msg.text.length})`;
    default:
      return msg.type;
  }
}

export function summarizeOutboundMessage(
  msg: ServerMessage | Record<string, unknown>,
): string {
  if ("type" in msg && typeof msg.type === "string") {
    return msg.type;
  }
  return "message";
}

export function pruneDebugEvents(server: BridgeWebSocketServer): void {
  const active = new Set(server.sessionManager.list().map((s) => s.id));
  for (const sessionId of server.debugEvents.keys()) {
    if (!active.has(sessionId)) {
      server.debugEvents.delete(sessionId);
    }
  }
  for (const sessionId of server.notifiedPermissionToolUses.keys()) {
    if (!active.has(sessionId)) {
      server.notifiedPermissionToolUses.delete(sessionId);
    }
  }
}

export function buildReproRecipe(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  traceLimit: number,
  includeDiff: boolean,
): Record<string, unknown> {
  const bridgePort = process.env.BRIDGE_PORT ?? "8765";
  const wsUrlHint = `ws://localhost:${bridgePort}`;
  const notes = [
    "1) Connect with wsUrlHint and send resumeSessionMessage.",
    "2) Read session_created.sessionId from server response.",
    "3) Replace <runtime_session_id> in getHistoryMessage/getDebugBundleMessage and send them.",
    "4) Compare history/debugTrace/diff with the saved bundle snapshot.",
  ];
  if (!session.claudeSessionId) {
    notes.push(
      "claudeSessionId is not available yet. Use list_recent_sessions to pick the right session id.",
    );
  }

  return {
    wsUrlHint,
    startBridgeCommand: `BRIDGE_PORT=${bridgePort} npm run bridge`,
    resumeSessionMessage: buildResumeSessionMessage(session),
    getHistoryMessage: {
      type: "get_history",
      sessionId: "<runtime_session_id>",
    },
    getDebugBundleMessage: {
      type: "get_debug_bundle",
      sessionId: "<runtime_session_id>",
      traceLimit,
      includeDiff,
    },
    notes,
  };
}
