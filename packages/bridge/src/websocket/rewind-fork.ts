import { WebSocket } from "ws";
import type { SessionInfo, WorktreeOptions } from "../session.js";
import { SdkProcess } from "../sdk-process.js";
import {
  codexErrorMessage,
  CodexProcess,
  type CodexStartOptions,
} from "../codex-process.js";
import { AntigravityProcess } from "../antigravity-process.js";
import type { ClientMessage } from "../parser.js";
import { getSessionHistory } from "../sessions-index.js";
import {
  CODEX_SHUTDOWN_WAIT_MS,
  RETRACT_START_TIMEOUT_MS,
  RETRACT_IDLE_TIMEOUT_MS,
  parseCodexUserTurnOrdinal,
  countCodexUserTurnsInSession,
  buildCodexHistoryPrefix,
} from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";
import { codexHistoryFromThreadOrFallback } from "./session-history.js";
import {
  workspaceForRuntimeSession,
  attachWorkspaceToRuntimeSession,
} from "./workspaces.js";
import { withCodexAutoReviewPolicy } from "./models.js";

/**
 * Interrupt the running turn and, when the agent has shown no output for
 * the latest prompt, remove that prompt from the conversation and hand its
 * text back to the client (Claude Code's Esc-to-edit). See
 * docs/interrupt-retract.md.
 */
export async function interruptAndRetract(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  session: SessionInfo,
): Promise<void> {
  const sessionId = session.id;
  if (session.process instanceof AntigravityProcess) {
    // Antigravity cannot drop a turn from its conversation, so the prompt
    // stays in history and only the turn is cancelled.
    session.process.interrupt();
    return;
  }
  let candidate = server.sessionManager.retractableUserInput(sessionId);
  if (session.status === "idle") {
    // Stop can be tapped right after sending, before the turn has started
    // on the Bridge. Interrupting then would be a no-op and the turn would
    // still run, so wait for it to start first.
    if (
      !candidate ||
      !(await waitForSessionRunning(session, RETRACT_START_TIMEOUT_MS))
    ) {
      session.process.interrupt();
      return;
    }
    candidate = server.sessionManager.retractableUserInput(sessionId);
  }
  session.process.interrupt();
  if (!candidate) return;

  if (!(await waitForSessionIdle(session, RETRACT_IDLE_TIMEOUT_MS))) {
    return;
  }
  // Output may have arrived before the abort landed.
  const latest = server.sessionManager.retractableUserInput(sessionId);
  if (!latest || latest.historySeq !== candidate.historySeq) return;
  if (server.sessionManager.get(sessionId) !== session) return;

  server.flushSessionDeltaBatches(sessionId);
  await server.sessionManager.rewindInPlace(sessionId, null);
  server.send(ws, {
    type: "input_retracted",
    sessionId,
    text: latest.text,
  });
}

/**
 * Codex App's edit-and-resend: rewind the conversation in place to just
 * before [targetUuid], then send [text] as a new prompt through the normal
 * input path. Only allowed between turns.
 */
export async function editUserMessage(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  msg: Extract<ClientMessage, { type: "edit_message" }>,
): Promise<void> {
  const fail = (message: string) => {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message,
      errorCode: "edit_message_failed",
      ...(msg.clientMessageId ? { clientMessageId: msg.clientMessageId } : {}),
    });
  };
  const session = server.sessionManager.get(msg.sessionId);
  if (!session) {
    fail(`Session ${msg.sessionId} not found`);
    return;
  }
  if (session.status !== "idle") {
    fail("Cannot edit a message while a turn is in progress.");
    return;
  }
  try {
    server.flushSessionDeltaBatches(msg.sessionId);
    await server.sessionManager.rewindInPlace(msg.sessionId, msg.targetUuid);
  } catch (err) {
    fail(err instanceof Error ? err.message : String(err));
    return;
  }
  await server.handleClientMessage(
    {
      type: "input",
      sessionId: msg.sessionId,
      text: msg.text,
      ...(msg.clientMessageId ? { clientMessageId: msg.clientMessageId } : {}),
    },
    ws,
  );
}

export function waitForSessionRunning(
  session: SessionInfo,
  timeoutMs: number,
): Promise<boolean> {
  if (session.status !== "idle") return Promise.resolve(true);
  return new Promise((resolve) => {
    const proc = session.process;
    const finish = (running: boolean) => {
      clearTimeout(timer);
      proc.off("status", onStatus);
      resolve(running);
    };
    const onStatus = (status: string) => {
      if (status !== "idle") finish(true);
    };
    const timer = setTimeout(
      () => finish(session.status !== "idle"),
      timeoutMs,
    );
    proc.on("status", onStatus);
  });
}

export function waitForSessionIdle(
  session: SessionInfo,
  timeoutMs: number,
): Promise<boolean> {
  const isIdle = () =>
    session.status === "idle" &&
    (session.process.status ?? "idle") === "idle" &&
    !(session.process instanceof SdkProcess && session.process.isTurnActive);
  if (isIdle()) return Promise.resolve(true);
  return new Promise((resolve) => {
    const proc = session.process;
    const finish = (idle: boolean) => {
      clearTimeout(timer);
      proc.off("status", onStatus);
      proc.off("exit", onExit);
      resolve(idle);
    };
    const onStatus = () => {
      // The session's own status listener runs first; re-check after it.
      queueMicrotask(() => {
        if (isIdle()) finish(true);
      });
    };
    const onExit = () => finish(false);
    const timer = setTimeout(() => finish(isIdle()), timeoutMs);
    proc.on("status", onStatus);
    proc.on("exit", onExit);
  });
}

export async function rewindCodexConversation(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  targetUuid: string,
  mode: "conversation" | "code" | "both",
  onRewound?: () => void,
): Promise<void> {
  if (mode !== "conversation") {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Codex only supports conversation rewind",
    });
    return;
  }

  const session = server.sessionManager.get(sessionId);
  if (!session) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: `Session ${sessionId} not found`,
    });
    return;
  }
  const codexProcess = session.process as CodexProcess;
  if (
    session.provider !== "codex" ||
    typeof codexProcess.forkThreadAtUserTurn !== "function"
  ) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Session is not a Codex session",
    });
    return;
  }
  if (session.status !== "idle" || (codexProcess.status ?? session.status) !== "idle") {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Cannot rewind while Codex is running",
    });
    return;
  }
  if (session.queuedInput) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Cannot rewind while Codex has queued input",
    });
    return;
  }

  const targetOrdinal = parseCodexUserTurnOrdinal(targetUuid);
  const totalUserTurns = countCodexUserTurnsInSession(session);
  if (targetOrdinal === null || targetOrdinal > totalUserTurns) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Invalid Codex rewind target",
    });
    return;
  }

  const numTurns = totalUserTurns - targetOrdinal + 1;
  if (numTurns <= 0) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "Invalid Codex rewind target",
    });
    return;
  }

  const threadId = codexProcess.sessionId ?? session.claudeSessionId;
  if (!threadId) {
    server.send(ws, {
      type: "rewind_result",
      sessionId,
      success: false,
      mode,
      error: "No Codex thread ID available for rewind",
    });
    return;
  }

  const projectPath = session.projectPath;
  const codexSettings = session.codexSettings;
  const workspace = workspaceForRuntimeSession(server, session);
  const worktreeOpts: WorktreeOptions | undefined = session.worktreePath
    ? {
        existingWorktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
      }
    : undefined;

  const forked = targetOrdinal > 1
    ? await codexProcess.forkThreadAtUserTurn(targetOrdinal - 1)
    : undefined;

  const pastMessages = codexHistoryFromThreadOrFallback({
    thread: forked?.thread,
    expectedUserTurns: targetOrdinal - 1,
    fallback: buildCodexHistoryPrefix(session, targetOrdinal - 1),
  });
  // A rewind replaces the conversation rather than branching it (Codex
  // App's edit-and-resend leaves no old copy in history), so hide the
  // source thread. Archive through the process that has it loaded.
  {
    try {
      await codexProcess.archiveThread(threadId);
    } catch (err) {
      console.warn(
        `[ws] Failed to archive rewound Codex thread ${threadId}: ${codexErrorMessage(err)}`,
      );
    }
    await server.archiveStore
      .archive(threadId, "codex", projectPath)
      .catch((err: unknown) => {
        console.warn(
          `[ws] Failed to record archive for ${threadId}: ${err instanceof Error ? err.message : String(err)}`,
        );
      });
  }
  server.destroySession(sessionId);
  // The source app-server holds the forked thread's write lock until it
  // exits; resuming the fork before then fails with "active writer".
  if (forked) {
    await codexProcess.waitForShutdown?.(CODEX_SHUTDOWN_WAIT_MS);
  }
  const newSessionId = server.sessionManager.create(
    projectPath,
    undefined,
    pastMessages,
    worktreeOpts,
    "codex",
    withCodexAutoReviewPolicy(server, {
      ...(codexSettings ?? {}),
      threadId: forked?.threadId,
    } as CodexStartOptions),
  );
  attachWorkspaceToRuntimeSession(server, newSessionId, workspace);
  const newSession = server.sessionManager.get(newSessionId);

  onRewound?.();
  server.send(ws, {
    type: "rewind_result",
    sessionId,
    success: true,
    mode,
  });
  server.send(
    ws,
    server.buildSessionCreatedMessage({
      sessionId: newSessionId,
      provider: "codex",
      projectPath,
      session: newSession,
      approvalsReviewer: newSession?.codexSettings?.approvalsReviewer,
      sandboxMode: newSession?.codexSettings?.sandboxMode,
      sourceSessionId: sessionId,
    }),
  );
  server.sendSessionList(ws);
}

/**
 * Branch a Claude conversation into a new session that ends at the given
 * assistant message. The source session keeps running unchanged.
 */
export async function forkClaudeSession(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  targetUuid: string,
): Promise<void> {
  const fail = (message: string): void => {
    server.send(ws, {
      type: "error",
      sessionId,
      message,
      errorCode: "fork_failed",
    });
  };
  const session = server.sessionManager.get(sessionId);
  if (!session || session.provider !== "claude") {
    fail(`Session ${sessionId} not found`);
    return;
  }
  const claudeSessionId = session.claudeSessionId;
  if (!claudeSessionId) {
    fail("Session has no Claude session ID yet");
    return;
  }
  const sdkProcess = session.process as SdkProcess;
  if (session.status !== "idle" || (sdkProcess.status ?? "idle") !== "idle") {
    fail("Cannot fork while Claude is running");
    return;
  }
  if (session.queuedInput) {
    fail("Cannot fork while Claude has queued input");
    return;
  }

  const history = await getSessionHistory(claudeSessionId);
  const targetIndex = history.findIndex(
    (message) => message.role === "assistant" && message.uuid === targetUuid,
  );
  if (targetIndex < 0) {
    fail("Fork target not found in the Claude transcript");
    return;
  }
  const pastMessages = history.slice(0, targetIndex + 1);

  const workspace = workspaceForRuntimeSession(server, session);
  const worktreeOpts: WorktreeOptions | undefined = session.worktreePath
    ? {
        existingWorktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
      }
    : undefined;
  const settings = sdkProcess.settings ?? {};
  const permissionMode = sdkProcess.permissionMode;
  const newSessionId = server.sessionManager.create(
    session.projectPath,
    {
      sessionId: claudeSessionId,
      forkSession: true,
      resumeSessionAt: targetUuid,
      ...(permissionMode ? { permissionMode } : {}),
      ...(settings.model ? { model: settings.model } : {}),
      ...(settings.effort ? { effort: settings.effort } : {}),
      ...(settings.fastMode ? { fastMode: true } : {}),
      ...(settings.ultracode ? { ultracode: true } : {}),
      ...(session.sandboxEnabled !== undefined
        ? { sandboxEnabled: session.sandboxEnabled }
        : {}),
    },
    pastMessages,
    worktreeOpts,
    "claude",
  );
  attachWorkspaceToRuntimeSession(server, newSessionId, workspace);
  const newSession = server.sessionManager.get(newSessionId);

  server.send(
    ws,
    server.buildSessionCreatedMessage({
      sessionId: newSessionId,
      provider: "claude",
      projectPath: session.projectPath,
      session: newSession,
      permissionMode,
      sourceSessionId: sessionId,
      forked: true,
    }),
  );
  server.sendSessionList(ws);
}

export async function forkCodexSession(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  targetUuid: string,
): Promise<void> {
  const session = server.sessionManager.get(sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      message: `Session ${sessionId} not found`,
      errorCode: "fork_failed",
    });
    return;
  }
  const codexProcess = session.process as CodexProcess;
  if (
    session.provider !== "codex" ||
    typeof codexProcess.forkThreadAtUserTurn !== "function"
  ) {
    server.send(ws, {
      type: "error",
      message: "Fork is only supported for Codex sessions",
      errorCode: "fork_failed",
    });
    return;
  }
  if (session.status !== "idle" || (codexProcess.status ?? session.status) !== "idle") {
    server.send(ws, {
      type: "error",
      message: "Cannot fork while Codex is running",
      errorCode: "fork_failed",
    });
    return;
  }
  if (session.queuedInput) {
    server.send(ws, {
      type: "error",
      message: "Cannot fork while Codex has queued input",
      errorCode: "fork_failed",
    });
    return;
  }

  const targetOrdinal = parseCodexUserTurnOrdinal(targetUuid);
  const totalUserTurns = countCodexUserTurnsInSession(session);
  if (targetOrdinal === null || targetOrdinal > totalUserTurns) {
    server.send(ws, {
      type: "error",
      message: "Invalid Codex fork target",
      errorCode: "fork_failed",
    });
    return;
  }

  const projectPath = session.projectPath;
  const codexSettings = session.codexSettings;
  const workspace = workspaceForRuntimeSession(server, session);
  const worktreeOpts: WorktreeOptions | undefined = session.worktreePath
    ? {
        existingWorktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
      }
    : undefined;

  const sourceThreadId = codexProcess.sessionId ?? session.claudeSessionId;
  if (!sourceThreadId) {
    server.send(ws, {
      type: "error",
      message: "No Codex thread ID available for fork",
      errorCode: "fork_failed",
    });
    return;
  }
  // Fork in a throwaway app-server: whichever app-server forks a thread
  // holds its write lock until it exits, and the source session keeps
  // running, so the fork must not be created by the source process.
  const forker = await server.createStandaloneCodexProcess(
    session.worktreePath ?? projectPath,
  );
  let forked: Awaited<ReturnType<CodexProcess["forkThreadAtUserTurn"]>>;
  try {
    forked = await forker.forkThreadAtUserTurn(targetOrdinal, sourceThreadId);
  } finally {
    forker.stop();
    await forker.waitForShutdown(CODEX_SHUTDOWN_WAIT_MS);
  }
  const forkedThreadId = forked.threadId;
  const forkedThread = forked.thread;

  const pastMessages = codexHistoryFromThreadOrFallback({
    thread: forkedThread,
    expectedUserTurns: targetOrdinal,
    fallback: buildCodexHistoryPrefix(session, targetOrdinal),
  });
  const newSessionId = server.sessionManager.create(
    projectPath,
    undefined,
    pastMessages,
    worktreeOpts,
    "codex",
    withCodexAutoReviewPolicy(server, {
      ...(codexSettings ?? {}),
      threadId: forkedThreadId,
    } as CodexStartOptions),
  );
  attachWorkspaceToRuntimeSession(server, newSessionId, workspace);
  const newSession = server.sessionManager.get(newSessionId);

  server.send(
    ws,
    server.buildSessionCreatedMessage({
      sessionId: newSessionId,
      provider: "codex",
      projectPath,
      session: newSession,
      approvalsReviewer: newSession?.codexSettings?.approvalsReviewer,
      sandboxMode: newSession?.codexSettings?.sandboxMode,
      sourceSessionId: sessionId,
      forked: true,
    }),
  );
  server.sendSessionList(ws);
}
