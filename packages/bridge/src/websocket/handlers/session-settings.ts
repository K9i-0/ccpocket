import { WebSocket } from "ws";
import { SdkProcess } from "../../sdk-process.js";
import {
  normalizeCodexReasoningEffortForModel,
  CodexProcess,
  type CodexStartOptions,
} from "../../codex-process.js";
import { AntigravityProcess } from "../../antigravity-process.js";
import {
  normalizeCodexServiceTierForClient,
} from "../../codex-service-tier.js";
import type { ClientMessage } from "../../parser.js";
import { sanitizeCodexModel, errorMessageOf } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { recordDebugEvent } from "../debug-trace.js";
import {
  sendAntigravityCurrentSettings,
  sendClaudeCurrentSettings,
  claudeSettingsMessage,
} from "../session-state.js";
import { codexServiceTierError } from "../models.js";

export async function handleSetAntigravityModel(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_antigravity_model" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!(session?.process instanceof AntigravityProcess)) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Model switching here is only supported for Antigravity sessions.",
      errorCode: "set_antigravity_model_unsupported",
    });
    return;
  }
  session.process
    .setModel(msg.model.trim())
    .then(() => server.broadcastSessionList())
    .catch((err) => {
      server.send(ws, {
        type: "error",
        sessionId: session.id,
        message: `Failed to switch model: ${errorMessageOf(err)}`,
        errorCode: "set_antigravity_model_rejected",
      });
      sendAntigravityCurrentSettings(server, ws, session.id, session);
    });
}

export async function handleSetAntigravitySettings(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_antigravity_settings" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  const proc = session?.process;
  if (!session || !(proc instanceof AntigravityProcess)) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "These settings are only supported for Antigravity sessions.",
      errorCode: "set_antigravity_settings_unsupported",
    });
    return;
  }
  void (async () => {
    if (msg.model) await proc.setModel(msg.model.trim());
    if (msg.thoughtLevel) await proc.setThoughtLevel(msg.thoughtLevel.trim());
  })()
    .then(() => server.broadcastSessionList())
    .catch((err) => {
      server.send(ws, {
        type: "error",
        sessionId: session.id,
        message: `Failed to change Antigravity settings: ${errorMessageOf(err)}`,
        errorCode: "set_antigravity_settings_rejected",
      });
      sendAntigravityCurrentSettings(server, ws, session.id, session);
    });
}

export async function handleGetAntigravityCatalog(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_antigravity_catalog" }>,
  ws: WebSocket,
): Promise<void> {
  server.antigravityCatalog()
    .then((catalog) =>
      server.send(ws, {
        type: "antigravity_catalog",
        requestId: msg.requestId,
        catalog,
      }),
    )
    .catch((err) =>
      server.send(ws, {
        type: "antigravity_catalog",
        requestId: msg.requestId,
        error: errorMessageOf(err),
      }),
    );
}

export async function handleSetCodexModel(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_codex_model" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  if (session.provider !== "codex") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Model switching is only supported for Codex sessions.",
      errorCode: "set_codex_model_unsupported",
    });
    return;
  }

  const model = sanitizeCodexModel(msg.model);
  if (!model) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Invalid Codex model: ${msg.model}`,
      errorCode: "set_codex_model_rejected",
    });
    return;
  }

  // Older clients send model first, then normalize Fast to Standard.
  // Keep that sequence compatible; extended tiers must never downgrade.
  const currentTier = normalizeCodexServiceTierForClient(session.codexSettings?.serviceTier);
  const tierError = currentTier !== "standard" && currentTier !== "fast"
    ? codexServiceTierError(server, model, currentTier) : undefined;
  if (tierError) {
    server.send(ws, { type: "error", sessionId: msg.sessionId,
      errorCode: "set_codex_model_rejected", message: tierError });
    return;
  }
  const currentModel = sanitizeCodexModel(session.codexSettings?.model);
  const currentEffort = session.codexSettings?.modelReasoningEffort;
  const modelReasoningEffort = normalizeCodexReasoningEffortForModel(
    model,
    (msg.modelReasoningEffort ??
      currentEffort) as CodexStartOptions["modelReasoningEffort"],
  );
  if (model === currentModel && modelReasoningEffort === currentEffort) {
    return;
  }

  const process = session.process as CodexProcess;
  process.setModel(model, modelReasoningEffort);
  session.codexSettings = {
    ...(session.codexSettings ?? {}),
    model,
    ...(modelReasoningEffort !== undefined
      ? { modelReasoningEffort }
      : {}),
  };
  session.lastActivityAt = new Date();
  server.broadcast({
    type: "system",
    subtype: "set_codex_model",
    sessionId: session.id,
    provider: "codex",
    model,
    ...(modelReasoningEffort !== undefined
      ? { modelReasoningEffort }
      : {}),
  });
  server.broadcastSessionList();
  recordDebugEvent(server, session.id, {
    direction: "internal" as const,
    channel: "bridge",
    type: "codex_model_changed",
    detail: `model=${model} effort=${modelReasoningEffort ?? ""}`,
  });
  console.log(
    `[ws] set_codex_model(codex): model=${model} effort=${modelReasoningEffort ?? ""}`,
  );
}

export async function handleSetCodexSpeed(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_codex_speed" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "codex") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active Codex session.",
      errorCode: "set_codex_speed_unsupported",
    });
    return;
  }

  const process = session.process as CodexProcess;
  const model = session.codexSettings?.model ?? process.model;
  const tierError = codexServiceTierError(server, model, msg.serviceTier);
  if (tierError) {
    server.send(ws, { type: "error", sessionId: msg.sessionId,
      errorCode: "set_codex_speed_rejected", message: tierError });
    return;
  }
  const serviceTier = normalizeCodexServiceTierForClient(msg.serviceTier);
  if (session.codexSettings?.serviceTier === serviceTier) return;

  process.setServiceTier(serviceTier);
  session.codexSettings = {
    ...(session.codexSettings ?? {}),
    serviceTier,
  };
  session.lastActivityAt = new Date();
  server.broadcastSessionMessage(session.id, {
    type: "system",
    subtype: "set_codex_speed",
    sessionId: session.id,
    provider: "codex",
    serviceTier,
  });
  server.broadcastSessionList();
  console.log(
    `[ws] set_codex_speed(codex): serviceTier=${serviceTier}`,
  );
}

export async function handleSetClaudeSettings(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_claude_settings" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session || session.provider !== "claude") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active Claude session.",
      errorCode: "set_claude_settings_unsupported",
    });
    return;
  }
  const claudeProcess = session.process as SdkProcess;
  try {
    await claudeProcess.updateSettings({
      ...(msg.model !== undefined ? { model: msg.model.trim() } : {}),
      ...(msg.effort !== undefined ? { effort: msg.effort } : {}),
      ...(msg.fastMode !== undefined ? { fastMode: msg.fastMode } : {}),
      ...(msg.ultracode !== undefined
        ? { ultracode: msg.ultracode }
        : {}),
    });
  } catch (err) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Failed to change Claude settings: ${err instanceof Error ? err.message : String(err)}`,
      errorCode: "set_claude_settings_rejected",
    });
    // Re-sync the requester with the settings still in effect.
    sendClaudeCurrentSettings(server, ws, session.id, session);
    return;
  }
  session.lastActivityAt = new Date();
  server.broadcastSessionMessage(
    session.id,
    claudeSettingsMessage(session.id, session),
  );
  server.broadcastSessionList();
  const settings = claudeProcess.settings;
  console.log(
    `[ws] set_claude_settings: model=${settings.model ?? "default"} effort=${settings.effort ?? ""} fast=${settings.fastMode === true} ultracode=${settings.ultracode === true}`,
  );
}
