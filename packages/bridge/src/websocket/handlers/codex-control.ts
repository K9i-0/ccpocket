import { WebSocket } from "ws";
import { CodexProcess } from "../../codex-process.js";
import type { ClientMessage } from "../../parser.js";
import { errorMessageOf } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";

export async function handleSetCodexRecovery(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_codex_recovery" | "cancel_codex_recovery" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "codex") {
    server.send(ws, { type: "error", sessionId: msg.sessionId, errorCode: "codex_recovery_unsupported", message: "Automatic recovery requires an active Codex session." });
    return;
  }
  const process = session.process as CodexProcess;
  if (msg.type === "set_codex_recovery") process.setRecoveryEnabled(msg.enabled);
  else process.cancelRecovery();
  server.send(ws, { type: "codex_recovery_state", sessionId: session.id, recovery: process.getRecoveryState() });
}

export async function handleGetGoal(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_goal" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "codex") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Goal lookup is only supported for active Codex sessions.",
      errorCode: "goal_get_unsupported",
    });
    return;
  }
  try {
    const goal = await (session.process as CodexProcess).getGoal();
    session.codexGoal = goal;
    server.send(ws, { type: "goal_state", sessionId: session.id, goal });
  } catch (err) {
    // An optional background refresh must not pollute the conversation or
    // replace a known goal with null when its current state is unknown.
    if (msg.background) {
      console.warn(`[ws] Background goal lookup failed: ${errorMessageOf(err)}`);
      return;
    }
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Failed to get goal: ${errorMessageOf(err)}`,
      errorCode: "goal_get_failed",
    });
  }
}

export async function handleSetGoal(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_goal" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "codex") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Goal updates are only supported for active Codex sessions.",
      errorCode: "goal_set_unsupported",
    });
    return;
  }
  try {
    const goal = await (session.process as CodexProcess).setGoal({
      ...(msg.objective !== undefined
        ? { objective: msg.objective }
        : {}),
      ...(msg.status !== undefined ? { status: msg.status } : {}),
    });
    session.codexGoal = goal;
    server.broadcastSessionMessage(session.id, {
      type: "goal_state",
      goal,
    });
  } catch (err) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Failed to set goal: ${errorMessageOf(err)}`,
      errorCode: "goal_set_failed",
    });
  }
}

export async function handleClearGoal(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "clear_goal" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "codex") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Goal clearing is only supported for active Codex sessions.",
      errorCode: "goal_clear_unsupported",
    });
    return;
  }
  try {
    await (session.process as CodexProcess).clearGoal();
    session.codexGoal = null;
    server.broadcastSessionMessage(session.id, {
      type: "goal_state",
      goal: null,
    });
  } catch (err) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Failed to clear goal: ${errorMessageOf(err)}`,
      errorCode: "goal_clear_failed",
    });
  }
}
