import { WebSocket } from "ws";
import type { SessionInfo, WorktreeOptions } from "../session.js";
import { SdkProcess, type StartOptions } from "../sdk-process.js";
import { CodexProcess } from "../codex-process.js";
import { AntigravityProcess } from "../antigravity-process.js";
import type { Provider, ServerMessage } from "../parser.js";
import {
  getClaudeSessionName,
  loadCodexSessionNames,
} from "../sessions-index.js";
import {
  catalogFromCachedCommands,
  convertSkillTriggers,
  hasForeignSkillTrigger,
} from "../skill-triggers.js";
import {
  INITIAL_PROMPT_SKILL_WAIT_MS,
  INITIAL_PROMPT_SKILL_POLL_MS,
  type ClaudePermissionMode,
  isClaudeAutoModeUnavailableError,
  deriveExecutionMode,
  derivePlanMode,
} from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";

export function sendTip(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  tipCode: string,
  session?: SessionInfo,
): void {
  const tipMsg = {
    type: "system",
    subtype: "tip",
    tipCode,
    sessionId,
  } as ServerMessage;
  if (session) {
    server.sessionManager.appendHistory(session.id, tipMsg);
  }
  server.send(ws, tipMsg);
}

export function claudeSettingsMessage(
  sessionId: string,
  session: SessionInfo,
): ServerMessage {
  const settings =
    session.provider === "claude"
      ? ((session.process as Partial<Pick<SdkProcess, "settings">>)
          .settings ?? {})
      : {};
  return {
    type: "system",
    subtype: "claude_settings",
    sessionId,
    provider: "claude",
    ...(settings.model ? { model: settings.model } : {}),
    ...(settings.effort ? { effort: settings.effort } : {}),
    fastMode: settings.fastMode === true,
    ultracode: settings.ultracode === true,
  } as ServerMessage;
}

export function sendClaudeCurrentSettings(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): void {
  if (session.provider !== "claude") return;
  server.send(ws, claudeSettingsMessage(sessionId, session));
}

export function sendAntigravityCurrentSettings(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): void {
  if (!(session.process instanceof AntigravityProcess)) return;
  const settings = session.process.settings;
  server.send(ws, {
    type: "system",
    subtype: "antigravity_settings",
    sessionId,
    provider: "antigravity",
    ...(settings.model ? { model: settings.model } : {}),
    ...(settings.permissionMode
      ? { permissionMode: settings.permissionMode }
      : {}),
    antigravity: settings,
  });
}

export function sendCodexCurrentSettings(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): void {
  const process = session.process instanceof CodexProcess
    ? session.process
    : undefined;
  const settings = session.codexSettings;
  server.send(ws, {
    type: "system",
    subtype: "codex_settings",
    sessionId,
    provider: "codex",
    ...(settings?.model ?? process?.model
      ? { model: settings?.model ?? process?.model }
      : {}),
    ...(settings?.modelReasoningEffort ?? process?.modelReasoningEffort
      ? {
          modelReasoningEffort:
            settings?.modelReasoningEffort ?? process?.modelReasoningEffort,
        }
      : {}),
    serviceTier: settings?.serviceTier ?? process?.serviceTier ?? "standard",
  });
}

export function createClaudeSessionWithFallback(
  server: BridgeWebSocketServer,
  params: {
    projectPath: string;
    options?: StartOptions & { permissionMode?: ClaudePermissionMode };
    pastMessages?: unknown[];
    worktreeOptions?: WorktreeOptions;
  },
): {
  sessionId: string;
  permissionMode: ClaudePermissionMode;
  executionMode: "default" | "acceptEdits" | "fullAccess";
  planMode: boolean;
  usedFallback: boolean;
} {
  const initialMode = params.options?.permissionMode ?? "default";
  try {
    const sessionId = server.sessionManager.create(
      params.projectPath,
      params.options,
      params.pastMessages,
      params.worktreeOptions,
    );
    return {
      sessionId,
      permissionMode: initialMode,
      executionMode: deriveExecutionMode({
        provider: "claude",
        permissionMode: initialMode,
      }),
      planMode: derivePlanMode({ permissionMode: initialMode }),
      usedFallback: false,
    };
  } catch (err) {
    if (
      initialMode !== "auto" ||
      !isClaudeAutoModeUnavailableError(err)
    ) {
      throw err;
    }
    const fallbackOptions = {
      ...params.options,
      permissionMode: "default" as const,
    };
    const sessionId = server.sessionManager.create(
      params.projectPath,
      fallbackOptions,
      params.pastMessages,
      params.worktreeOptions,
    );
    return {
      sessionId,
      permissionMode: "default",
      executionMode: "default",
      planMode: false,
      usedFallback: true,
    };
  }
}

/**
 * Load the saved session name from CLI storage and set it on the SessionInfo.
 * Called after SessionManager.create() so that session_created carries the name.
 */
/**
 * Rewrite skills in a new session's first prompt to the agent's trigger
 * (`/` for Claude, `$` for Codex). The app converts later messages itself,
 * but it cannot know the skills before the session starts. When the prompt
 * contains a candidate and the skills are not cached yet, wait briefly for
 * the provider to report them; on timeout the prompt is sent unchanged.
 */
export async function prepareInitialPrompt(
  server: BridgeWebSocketServer,
  provider: Provider,
  effectiveCwd: string,
  sessionId: string,
  text: string,
): Promise<{ text: string; skills: Array<{ name: string; path: string }> }> {
  // Antigravity has no skill catalog to translate triggers against.
  if (provider === "antigravity") return { text, skills: [] };
  if (!hasForeignSkillTrigger(text, provider)) return { text, skills: [] };
  const deadline = Date.now() + INITIAL_PROMPT_SKILL_WAIT_MS;
  let catalog = catalogFromCachedCommands(
    provider,
    server.sessionManager.getCachedCommands(provider, effectiveCwd),
  );
  while (
    !catalog &&
    Date.now() < deadline &&
    server.sessionManager.get(sessionId)
  ) {
    await new Promise((resolve) =>
      setTimeout(resolve, INITIAL_PROMPT_SKILL_POLL_MS),
    );
    catalog = catalogFromCachedCommands(
      provider,
      server.sessionManager.getCachedCommands(provider, effectiveCwd),
    );
  }
  if (!catalog) return { text, skills: [] };
  return convertSkillTriggers(text, catalog);
}

export async function loadAndSetSessionName(
  session: SessionInfo | undefined,
  provider: string,
  projectPath: string,
  cliSessionId?: string,
): Promise<void> {
  if (!session || !cliSessionId) return;
  try {
    if (provider === "claude") {
      const name = await getClaudeSessionName(projectPath, cliSessionId);
      if (name) session.name = name;
    } else if (provider === "codex") {
      const names = await loadCodexSessionNames();
      const name = names.get(cliSessionId);
      if (name) session.name = name;
    }
  } catch {
    // Non-critical: session works without name
  }
}

export function getFirstSession(server: BridgeWebSocketServer) {
  const sessions = server.sessionManager.list();
  if (sessions.length === 0) return undefined;
  return server.sessionManager.get(sessions[sessions.length - 1].id);
}

export function sendPromptHistoryStatus(
  server: BridgeWebSocketServer,
  ws: WebSocket,
): void {
  if (!server.promptHistoryStore) return;
  const entries = server.promptHistoryStore.list(true);
  const updatedAt = entries.reduce<string | undefined>(
    (latest, entry) =>
      !latest || entry.updatedAt > latest ? entry.updatedAt : latest,
    undefined,
  );
  server.send(ws, {
    type: "prompt_history_status",
    bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
    revision: server.promptHistoryStore.revision,
    entryCount: entries.filter((entry) => !entry.deletedAt).length,
    updatedAt,
  });
}

export function broadcastPromptHistoryStatus(server: BridgeWebSocketServer): void {
  if (!server.promptHistoryStore) return;
  const entries = server.promptHistoryStore.list(true);
  const updatedAt = entries.reduce<string | undefined>(
    (latest, entry) =>
      !latest || entry.updatedAt > latest ? entry.updatedAt : latest,
    undefined,
  );
  server.broadcast({
    type: "prompt_history_status",
    bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
    revision: server.promptHistoryStore.revision,
    entryCount: entries.filter((entry) => !entry.deletedAt).length,
    updatedAt,
  });
}

export function hasInputConflictSince(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  baseSeq: number,
): boolean {
  const codexResetRevision = session.codexHistoryResetRevision ??
    session.codexCanonicalHistoryRevision;
  if (
    session.provider === "codex" &&
    typeof codexResetRevision === "number" &&
    baseSeq < codexResetRevision
  ) {
    return true;
  }

  const delta = server.sessionManager.getHistorySince(session.id, baseSeq);
  if (!delta) return true;
  if (delta.kind === "snapshot") return true;

  return delta.entries.some((entry) => {
    const msg = entry.message;
    if (msg.type === "user_input" || msg.type === "result") return true;
    if (msg.type === "system") {
      const subtype = (msg as Record<string, unknown>).subtype;
      return (
        subtype === "session_switched" ||
        subtype === "session_rewound" ||
        subtype === "sandbox_restarted" ||
        subtype === "session_stopped"
      );
    }
    return false;
  });
}

export function sendBackgroundTasksState(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): void {
  server.send(ws, {
    type: "background_tasks",
    sessionId,
    tasks: session.backgroundTasks ?? [],
  });
  if (session.agentActivity) {
    server.send(ws, {
      type: "agent_activity",
      sessionId,
      activity: session.agentActivity,
    });
  }
}

export function sendCodexGoalState(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): void {
  const recovery = (session.process as CodexProcess).getRecoveryState?.();
  if (recovery) server.send(ws, { type: "codex_recovery_state", sessionId, recovery });
  if (session.codexGoal === undefined) return;
  server.send(ws, {
    type: "goal_state",
    sessionId,
    goal: session.codexGoal,
  });
}

export function sendConversationQueue(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  msg:
    | Extract<ServerMessage, { type: "conversation_queue" }>
    | Record<string, unknown>,
): void {
  if (!server.shouldSendToClient(ws, msg)) return;
  server.send(ws, msg);
}

export function buildResumeSessionMessage(
  session: SessionInfo,
): Record<string, unknown> {
  const msg: Record<string, unknown> = {
    type: "resume_session",
    sessionId: session.claudeSessionId ?? "<session_id_from_recent_sessions>",
    projectPath: session.projectPath,
    provider: session.provider,
  };

  if (session.provider === "codex" && session.codexSettings) {
    if (session.codexSettings.approvalPolicy !== undefined) {
      msg.approvalPolicy = session.codexSettings.approvalPolicy;
    }
    if (session.codexSettings.approvalsReviewer !== undefined) {
      msg.approvalsReviewer = session.codexSettings.approvalsReviewer;
    }
    if (session.codexSettings.sandboxMode !== undefined) {
      msg.sandboxMode = session.codexSettings.sandboxMode;
    }
    if (session.codexSettings.model !== undefined) {
      msg.model = session.codexSettings.model;
    }
    if (session.codexSettings.modelReasoningEffort !== undefined) {
      msg.modelReasoningEffort = session.codexSettings.modelReasoningEffort;
    }
    if (session.codexSettings.serviceTier !== undefined) {
      msg.serviceTier = session.codexSettings.serviceTier;
    }
    if (session.codexSettings.networkAccessEnabled !== undefined) {
      msg.networkAccessEnabled = session.codexSettings.networkAccessEnabled;
    }
    if (session.codexSettings.webSearchMode !== undefined) {
      msg.webSearchMode = session.codexSettings.webSearchMode;
    }
    if (session.codexSettings.additionalWritableRoots !== undefined) {
      msg.additionalWritableRoots =
        session.codexSettings.additionalWritableRoots;
    }
  }

  return msg;
}

export function buildAgentPrompt(session: SessionInfo): string {
  return [
    "Use this ccpocket debug bundle to investigate a chat-screen bug.",
    `Target provider: ${session.provider}`,
    `Project path: ${session.projectPath}`,
    "Required output:",
    "1) Timeline analysis from historySummary + debugTrace.",
    "2) Top 1-3 root-cause hypotheses with confidence.",
    "3) Concrete validation steps and the minimum extra logs needed.",
  ].join("\n");
}
