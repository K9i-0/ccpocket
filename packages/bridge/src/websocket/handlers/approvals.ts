import { WebSocket } from "ws";
import { SdkProcess } from "../../sdk-process.js";
import { CodexProcess } from "../../codex-process.js";
import { AntigravityProcess } from "../../antigravity-process.js";
import type { ClientMessage } from "../../parser.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { sendToolActionError } from "../file-access.js";
import {
  workspaceForRuntimeSession,
  attachWorkspaceToRuntimeSession,
} from "../workspaces.js";

export async function handleApprove(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "approve" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    sendToolActionError(server, ws, msg, "No active session.");
    return;
  }
  if (session.provider !== "claude") {
    const handled = (
      session.process as CodexProcess | AntigravityProcess
    ).approve(msg.id);
    if (handled === false) {
      sendToolActionError(
        server,
        ws,
        msg,
        "No matching pending tool action.",
      );
    }
    return;
  }
  const sdkProc = session.process as SdkProcess;
  if (msg.clearContext) {
    // Clear & Accept: immediately destroy this runtime session and
    // create a fresh one that continues the same Claude conversation.
    // This guarantees chat history is cleared in the mobile UI without
    // waiting for additional in-turn tool approvals.
    const pending = sdkProc.getPendingPermission(msg.id);
    const planText =
      typeof pending?.input.plan === "string" ? pending.input.plan : "";

    // Use session.id (always present) instead of msg.sessionId.
    const sessionId = session.id;

    // Capture session properties before destroy.
    const claudeSessionId = session.claudeSessionId;
    const projectPath = session.projectPath;
    const permissionMode = sdkProc.permissionMode;
    const settings = sdkProc.settings ?? {};
    const sandboxEnabled = session.sandboxEnabled;
    const worktreePath = session.worktreePath;
    const worktreeBranch = session.worktreeBranch;
    const workspace = workspaceForRuntimeSession(server, session);

    server.destroySession(sessionId);
    console.log(`[ws] Clear context: destroyed session ${sessionId}`);

    const newId = server.sessionManager.create(
      projectPath,
      {
        ...(claudeSessionId
          ? {
              sessionId: claudeSessionId,
              continueMode: true,
            }
          : {}),
        permissionMode,
        ...(settings.model ? { model: settings.model } : {}),
        ...(settings.effort ? { effort: settings.effort } : {}),
        ...(settings.fastMode ? { fastMode: true } : {}),
        ...(settings.ultracode ? { ultracode: true } : {}),
        ...(sandboxEnabled !== undefined ? { sandboxEnabled } : {}),
        initialInput: planText || undefined,
        additionalDirectories: workspace?.rootPaths.slice(1),
      },
      undefined,
      worktreePath
        ? { existingWorktreePath: worktreePath, worktreeBranch }
      : undefined,
    );
    attachWorkspaceToRuntimeSession(server, newId, workspace);
    console.log(
      `[ws] Clear context: created new session ${newId} (CLI session: ${claudeSessionId ?? "new"})`,
    );

    // Notify all clients. Broadcast is used so reconnecting clients also receive it.
    const newSession = server.sessionManager.get(newId);
    const createdMsg = server.buildSessionCreatedMessage({
      sessionId: newId,
      provider: newSession?.provider ?? "claude",
      projectPath,
      session: newSession,
      permissionMode,
      sourceSessionId: sessionId,
    });
    server.broadcast({ ...createdMsg, clearContext: true });
    server.broadcastSessionList();
  } else {
    const handled = sdkProc.approve(msg.id);
    if (handled === false) {
      sendToolActionError(
        server,
        ws,
        msg,
        "No matching pending tool action.",
      );
    }
  }
}

export async function handleApproveAlways(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "approve_always" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    sendToolActionError(server, ws, msg, "No active session.");
    return;
  }
  if (session.provider !== "claude") {
    const handled = (
      session.process as CodexProcess | AntigravityProcess
    ).approveAlways(
      msg.id,
    );
    if (handled === false) {
      sendToolActionError(
        server,
        ws,
        msg,
        "No matching pending tool action.",
      );
    }
    return;
  }
  const handled = (session.process as SdkProcess).approveAlways(msg.id);
  if (handled === false) {
    sendToolActionError(
      server,
      ws,
      msg,
      "No matching pending tool action.",
    );
  }
}

export async function handleReject(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "reject" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    sendToolActionError(server, ws, msg, "No active session.");
    return;
  }
  if (session.provider !== "claude") {
    const handled = (
      session.process as CodexProcess | AntigravityProcess
    ).reject(
      msg.id,
      msg.message,
    );
    if (handled === false) {
      sendToolActionError(
        server,
        ws,
        msg,
        "No matching pending tool action.",
      );
    }
    return;
  }
  const handled = (session.process as SdkProcess).reject(
    msg.id,
    msg.message,
  );
  if (handled === false) {
    sendToolActionError(
      server,
      ws,
      msg,
      "No matching pending tool action.",
    );
  }
}

export async function handleAnswer(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "answer" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    sendToolActionError(server, ws, msg, "No active session.");
    return;
  }
  if (session.provider !== "claude") {
    const handled = (
      session.process as CodexProcess | AntigravityProcess
    ).answer(
      msg.toolUseId,
      msg.result,
    );
    if (handled === false) {
      sendToolActionError(
        server,
        ws,
        msg,
        "No matching pending tool action.",
      );
    }
    return;
  }
  const handled = (session.process as SdkProcess).answer(
    msg.toolUseId,
    msg.result,
  );
  if (handled === false) {
    sendToolActionError(
      server,
      ws,
      msg,
      "No matching pending tool action.",
    );
  }
}

export async function handleInstallToolSuggestion(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "install_tool_suggestion" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    sendToolActionError(server, ws, msg, "No active session.");
    return;
  }
  if (session.provider !== "codex") {
    sendToolActionError(
      server,
      ws,
      msg,
      "Tool suggestions are only supported for Codex sessions.",
    );
    return;
  }
  try {
    await (session.process as CodexProcess).installToolSuggestion(
      msg.toolUseId,
    );
  } catch (err) {
    sendToolActionError(
      server,
      ws,
      msg,
      err instanceof Error ? err.message : String(err),
    );
  }
}
