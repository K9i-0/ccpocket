import { WebSocket } from "ws";
import { SdkProcess } from "../../sdk-process.js";
import { CodexProcess, type CodexStartOptions } from "../../codex-process.js";
import { AntigravityProcess } from "../../antigravity-process.js";
import type { ClientMessage } from "../../parser.js";
import { worktreeExists } from "../../worktree.js";
import {
  deriveCodexPermissionsMode,
  normalizeCodexPermissionsMode,
} from "../../codex-permissions.js";
import {
  normalizeCodexApprovalPolicy,
  isCodexAutoReviewApprovalsReviewer,
  codexSettingsFromPermissionsMode,
  errorMessageOf,
  isClaudeAutoModeUnavailableError,
  deriveExecutionMode,
  derivePlanMode,
  modesToLegacyPermissionMode,
  sandboxModeToInternal,
  sandboxModeToExternal,
} from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { recordDebugEvent } from "../debug-trace.js";
import { getCodexThreadHistory } from "../session-history.js";
import { loadAndSetSessionName } from "../session-state.js";
import {
  workspaceForRuntimeSession,
  attachWorkspaceToRuntimeSession,
} from "../workspaces.js";
import { withCodexAutoReviewPolicy } from "../models.js";

export async function handleSetPermissionMode(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_permission_mode" }>,
  ws: WebSocket,
): Promise<void> {
  if (server.failSetPermissionMode) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Failed to set permission mode: forced test failure",
      errorCode: "set_permission_mode_rejected",
    });
    return;
  }
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  if (session.provider === "codex") {
    // Permission mode for Codex requires a session restart (like sandbox mode).
    // approvalPolicy and collaborationMode are thread-level settings that
    // only take effect reliably at thread/start or thread/resume time.
    const normalizedCodexPermissionsMode =
      normalizeCodexPermissionsMode(msg.codexPermissionsMode);
    const requestedCodexPermissionsMode =
      server.codexAutoReviewDisabled &&
      normalizedCodexPermissionsMode === "autoReview"
        ? "default"
        : normalizedCodexPermissionsMode;
    const requestedApprovalsReviewer =
      server.codexAutoReviewDisabled &&
      isCodexAutoReviewApprovalsReviewer(msg.approvalsReviewer)
        ? "user"
        : msg.approvalsReviewer;
    const codexPermissionSettings = requestedCodexPermissionsMode
      ? codexSettingsFromPermissionsMode(requestedCodexPermissionsMode)
      : undefined;
    const process = session.process as CodexProcess;
    const currentApproval = normalizeCodexApprovalPolicy(
      process.approvalPolicy,
    );
    const currentReviewer = process.approvalsReviewer;
    const currentSandboxMode = session.codexSettings?.sandboxMode;
    const currentPermissionsMode = normalizeCodexPermissionsMode(
      session.codexSettings?.codexPermissionsMode,
    );
    const collaborationOnlyChange =
      requestedCodexPermissionsMode === undefined &&
      msg.approvalPolicy === undefined &&
      msg.approvalsReviewer === undefined &&
      (msg.planMode !== undefined || msg.mode === "plan");
    const explicitApproval = requestedCodexPermissionsMode
      ? codexPermissionSettings?.approvalPolicy
      : collaborationOnlyChange
        ? currentApproval
      : normalizeCodexApprovalPolicy(
          msg.approvalPolicy ??
            (msg.executionMode == null
              ? undefined
              : msg.executionMode === "fullAccess"
                ? "never"
                : "on-request"),
        );
    const executionMode = deriveExecutionMode({
      provider: "codex",
      permissionMode: msg.mode,
      executionMode: msg.executionMode,
      approvalPolicy: explicitApproval,
    });
    const planMode = derivePlanMode({
      permissionMode: msg.mode,
      planMode: msg.planMode,
    });
    const legacyPermissionMode = modesToLegacyPermissionMode(
      "codex",
      executionMode,
      planMode,
    );
    const newApproval = explicitApproval;
    const newSandboxMode = codexPermissionSettings
      ? codexPermissionSettings.sandboxMode
      : currentSandboxMode;
    const configuredReviewer =
      requestedCodexPermissionsMode === "custom"
        ? undefined
        : (codexPermissionSettings?.approvalsReviewer ??
          requestedApprovalsReviewer ??
          currentReviewer);
    const newReviewer = server.codexAutoReviewDisabled
      ? "user"
      : configuredReviewer;
    const derivedPermissionsMode =
      codexPermissionSettings?.codexPermissionsMode ??
      (collaborationOnlyChange ? currentPermissionsMode : undefined) ??
      deriveCodexPermissionsMode({
        approvalPolicy: newApproval,
        approvalsReviewer: newReviewer,
        sandboxMode: newSandboxMode,
      });
    const newPermissionsMode =
      server.codexAutoReviewDisabled &&
      derivedPermissionsMode === "autoReview"
        ? "default"
        : derivedPermissionsMode;
    const newCollaboration: "plan" | "default" = planMode
      ? "plan"
      : "default";
    const currentCollaboration = process.collaborationMode;
    if (
      newApproval === currentApproval &&
      newReviewer === currentReviewer &&
      newSandboxMode === currentSandboxMode &&
      newPermissionsMode === currentPermissionsMode &&
      newCollaboration === currentCollaboration
    ) {
      return; // No change needed
    }
    const canApplyModeInPlace =
      session.status === "idle" &&
      requestedCodexPermissionsMode !== "custom" &&
      newSandboxMode === currentSandboxMode &&
      (server.codexAutoReviewPolicyLoaded ||
        !isCodexAutoReviewApprovalsReviewer(newReviewer));

    if (canApplyModeInPlace) {
      const process = session.process as CodexProcess;
      if (newApproval && newApproval !== currentApproval) {
        process.setApprovalPolicy(newApproval);
      }
      if (newReviewer && newReviewer !== currentReviewer) {
        process.setApprovalsReviewer(newReviewer);
      }
      if (newCollaboration !== currentCollaboration) {
        process.setCollaborationMode(newCollaboration);
      }
      session.codexSettings = {
        ...(session.codexSettings ?? {}),
        approvalPolicy: newApproval,
        approvalsReviewer: newReviewer,
        codexPermissionsMode: newPermissionsMode,
        sandboxMode: newSandboxMode,
      };
      session.lastActivityAt = new Date();
      server.broadcast({
        type: "system",
        subtype: "set_permission_mode",
        sessionId: session.id,
        permissionMode: legacyPermissionMode,
        executionMode,
        approvalPolicy: newApproval,
        approvalsReviewer: newReviewer,
        codexPermissionsMode: newPermissionsMode,
        planMode,
      });
      server.broadcastSessionList();
      recordDebugEvent(server, session.id, {
        direction: "internal" as const,
        channel: "bridge" as const,
        type: "permission_mode_changed",
        detail: `mode=${msg.mode} approval=${newApproval} reviewer=${newReviewer} collaboration=${newCollaboration} applied=in-place`,
      });
      console.log(
        `[ws] set_permission_mode(codex): execution=${executionMode} plan=${planMode} → approval=${newApproval}, reviewer=${newReviewer}, collaboration=${newCollaboration} (in-place)`,
      );
      return;
    }
    console.log(
      `[ws] set_permission_mode(codex): execution=${executionMode} plan=${planMode} → approval=${newApproval}, reviewer=${newReviewer}, collaboration=${newCollaboration} (restart)`,
    );

    const oldSessionId = session.id;
    const threadId = session.claudeSessionId;
    const projectPath = session.projectPath;
    const oldSettings = session.codexSettings ?? {};
    const worktreePath = session.worktreePath;
    const worktreeBranch = session.worktreeBranch;
    const sessionName = session.name;
    const workspace = workspaceForRuntimeSession(server, session);

    server.destroySession(oldSessionId);
    console.log(
      `[ws] Permission mode change: destroyed session ${oldSessionId}`,
    );

    const hasUserMessages =
      session.history?.some(
        (m: Record<string, unknown>) =>
          m.type === "user_input" || m.type === "assistant",
      ) ||
      (session.pastMessages && session.pastMessages.length > 0);
    if (!threadId || !hasUserMessages) {
      const newId = server.sessionManager.create(
        projectPath,
        undefined,
        undefined,
        worktreePath
          ? { existingWorktreePath: worktreePath, worktreeBranch }
          : undefined,
        "codex",
        withCodexAutoReviewPolicy(server, {
          approvalPolicy: newApproval,
          approvalsReviewer: newReviewer as
            | "user"
            | "auto_review"
            | "guardian_subagent",
          codexPermissionsMode: newPermissionsMode,
          sandboxMode: newSandboxMode as
            | "read-only"
            | "workspace-write"
            | "danger-full-access"
            | undefined,
          model: oldSettings.model,
          modelReasoningEffort:
            oldSettings.modelReasoningEffort as CodexStartOptions["modelReasoningEffort"],
          serviceTier: oldSettings.serviceTier,
          networkAccessEnabled: oldSettings.networkAccessEnabled as
            | boolean
            | undefined,
          webSearchMode: oldSettings.webSearchMode as
            | "disabled"
            | "cached"
            | "live"
            | undefined,
          additionalWritableRoots: oldSettings.additionalWritableRoots,
          collaborationMode: newCollaboration,
        }),
      );
      attachWorkspaceToRuntimeSession(server, newId, workspace);
      const newSession = server.sessionManager.get(newId);
      if (newSession && sessionName) newSession.name = sessionName;
      server.broadcast(
        server.buildSessionCreatedMessage({
          sessionId: newId,
          provider: "codex",
          projectPath,
          session: newSession,
          permissionMode: legacyPermissionMode,
          executionMode,
          planMode,
          sandboxMode: newSandboxMode
            ? sandboxModeToExternal(newSandboxMode)
            : undefined,
          approvalsReviewer: newReviewer,
          codexPermissionsMode: newPermissionsMode,
          sourceSessionId: oldSessionId,
        }),
      );
      server.broadcastSessionList();
      console.log(
        `[ws] Permission mode change (no thread): created new session ${newId} (mode=${msg.mode})`,
      );
      return;
    }

    // Worktree resolution
    const wtMapping = server.worktreeStore.get(threadId);
    const effectiveProjectPath = wtMapping?.projectPath ?? projectPath;
    let worktreeOpts:
      | {
          useWorktree?: boolean;
          worktreeBranch?: string;
          existingWorktreePath?: string;
        }
      | undefined;
    if (wtMapping) {
      if (worktreeExists(wtMapping.worktreePath)) {
        worktreeOpts = {
          existingWorktreePath: wtMapping.worktreePath,
          worktreeBranch: wtMapping.worktreeBranch,
        };
      } else {
        worktreeOpts = {
          useWorktree: true,
          worktreeBranch: wtMapping.worktreeBranch,
        };
      }
    } else if (worktreePath) {
      worktreeOpts = {
        existingWorktreePath: worktreePath,
        worktreeBranch,
      };
    }

    getCodexThreadHistory(server, threadId, effectiveProjectPath)
      .then((pastMessages) => {
        const newId = server.sessionManager.create(
          effectiveProjectPath,
          undefined,
          pastMessages,
          worktreeOpts,
          "codex",
          withCodexAutoReviewPolicy(server, {
            threadId,
            approvalPolicy: newApproval,
            approvalsReviewer: newReviewer as
              | "user"
              | "auto_review"
              | "guardian_subagent",
            codexPermissionsMode: newPermissionsMode,
            sandboxMode: newSandboxMode as
              | "read-only"
              | "workspace-write"
              | "danger-full-access"
              | undefined,
            model: oldSettings.model,
            modelReasoningEffort:
              oldSettings.modelReasoningEffort as CodexStartOptions["modelReasoningEffort"],
            serviceTier: oldSettings.serviceTier,
            networkAccessEnabled: oldSettings.networkAccessEnabled as
              | boolean
              | undefined,
            webSearchMode: oldSettings.webSearchMode as
              | "disabled"
              | "cached"
              | "live"
              | undefined,
            additionalWritableRoots: oldSettings.additionalWritableRoots,
            collaborationMode: newCollaboration,
          }),
        );
        attachWorkspaceToRuntimeSession(server, newId, workspace);

        const newSession = server.sessionManager.get(newId);
        if (newSession && sessionName) {
          newSession.name = sessionName;
        }

        void loadAndSetSessionName(
          newSession,
          "codex",
          effectiveProjectPath,
          threadId,
        ).then(() => {
          server.broadcast(
            server.buildSessionCreatedMessage({
              sessionId: newId,
              provider: "codex",
              projectPath: effectiveProjectPath,
              session: newSession,
              permissionMode: legacyPermissionMode,
              executionMode,
              planMode,
              sandboxMode: newSandboxMode
                ? sandboxModeToExternal(newSandboxMode)
                : undefined,
              approvalsReviewer: newReviewer,
              codexPermissionsMode: newPermissionsMode,
              sourceSessionId: oldSessionId,
            }),
          );
          server.broadcastSessionList();
        });

        server.debugEvents.set(newId, []);
        recordDebugEvent(server, newId, {
          direction: "internal" as const,
          channel: "bridge" as const,
          type: "permission_mode_changed",
          detail: `mode=${msg.mode} approval=${newApproval} reviewer=${newReviewer} collaboration=${newCollaboration} thread=${threadId} oldSession=${oldSessionId}`,
        });
        console.log(
          `[ws] Permission mode change: created new session ${newId} (thread=${threadId}, mode=${msg.mode})`,
        );
      })
      .catch((err) => {
        server.send(ws, {
          type: "error",
          sessionId: msg.sessionId,
          message: `Failed to restart session for permission mode change: ${err}`,
        });
      });
    return;
  }
  if (session.process instanceof AntigravityProcess) {
    session.process.setPermissionMode(msg.mode).catch((err) => {
      // Modes differ per account: auto needs the OS terminal sandbox.
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        message:
          msg.mode === "auto"
            ? "Auto mode is unavailable in this environment. Keeping the current permission mode."
            : `Failed to set permission mode: ${errorMessageOf(err)}`,
        errorCode:
          msg.mode === "auto"
            ? "auto_mode_unavailable"
            : "set_permission_mode_rejected",
      });
    });
    return;
  }
  (session.process as SdkProcess)
    .setPermissionMode(msg.mode)
    .catch((err) => {
      if (
        msg.mode === "auto" &&
        isClaudeAutoModeUnavailableError(err)
      ) {
        server.send(ws, {
          type: "error",
          sessionId: msg.sessionId,
          message:
            "Auto mode is unavailable in this environment. Keeping the current permission mode.",
          errorCode: "auto_mode_unavailable",
        });
        return;
      }
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        message: `Failed to set permission mode: ${errorMessageOf(err)}`,
      });
    });
}

export async function handleSetSandboxMode(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_sandbox_mode" }>,
  ws: WebSocket,
): Promise<void> {
  if (server.failSetSandboxMode) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Failed to set sandbox mode: forced test failure",
      errorCode: "set_sandbox_mode_rejected",
    });
    return;
  }
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  if (msg.sandboxMode !== "on" && msg.sandboxMode !== "off") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Invalid sandbox mode: ${msg.sandboxMode}`,
    });
    return;
  }
  if (session.provider === "antigravity") {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Sandbox mode cannot be changed for Antigravity sessions.",
      errorCode: "set_sandbox_mode_rejected",
    });
    return;
  }

  // ---- Claude sandbox toggle ----
  if (session.provider === "claude") {
    const newEnabled = msg.sandboxMode === "on";
    if (session.sandboxEnabled === newEnabled) {
      return; // No change needed
    }

    // Sandbox is a query-level setting — requires session restart.
    const oldSessionId = session.id;
    const claudeSessionId = session.claudeSessionId;
    const projectPath = session.projectPath;
    const worktreePath = session.worktreePath;
    const worktreeBranch = session.worktreeBranch;
    const sessionName = session.name;
    const permissionMode = (session.process as SdkProcess).permissionMode;
    // Use the user's selected settings (alias, effort, fast mode) rather
    // than the resolved runtime model id, matching fork behavior.
    const settings = (session.process as SdkProcess).settings ?? {};
    const workspace = workspaceForRuntimeSession(server, session);

    server.destroySession(oldSessionId);
    console.log(
      `[ws] Claude sandbox change: destroyed session ${oldSessionId}`,
    );

    const newId = server.sessionManager.create(
      projectPath,
      {
        sessionId: claudeSessionId,
        permissionMode,
        ...(settings.model ? { model: settings.model } : {}),
        ...(settings.effort ? { effort: settings.effort } : {}),
        ...(settings.fastMode ? { fastMode: true } : {}),
        ...(settings.ultracode ? { ultracode: true } : {}),
        sandboxEnabled: newEnabled,
        additionalDirectories: workspace?.rootPaths.slice(1),
      },
      undefined,
      worktreePath
        ? { existingWorktreePath: worktreePath, worktreeBranch }
        : undefined,
      "claude",
    );
    attachWorkspaceToRuntimeSession(server, newId, workspace);

    const newSession = server.sessionManager.get(newId);
    if (newSession && sessionName) newSession.name = sessionName;

    void loadAndSetSessionName(
      newSession,
      "claude",
      projectPath,
      claudeSessionId,
    ).then(() => {
      server.broadcast(
        server.buildSessionCreatedMessage({
          sessionId: newId,
          provider: "claude",
          projectPath,
          session: newSession,
          sandboxMode: msg.sandboxMode,
          sourceSessionId: oldSessionId,
        }),
      );
      server.broadcastSessionList();
    });

    server.debugEvents.set(newId, []);
    recordDebugEvent(server, newId, {
      direction: "internal" as const,
      channel: "bridge" as const,
      type: "sandbox_mode_changed",
      detail: `sandbox=${newEnabled} claude=${claudeSessionId} oldSession=${oldSessionId}`,
    });
    console.log(
      `[ws] Claude sandbox change: created new session ${newId} (sandbox=${newEnabled})`,
    );
    return;
  }

  // ---- Codex sandbox toggle ----
  const newSandboxMode = sandboxModeToInternal(msg.sandboxMode);
  const currentSandboxMode =
    session.codexSettings?.sandboxMode ?? "workspace-write";
  if (newSandboxMode === currentSandboxMode) {
    return; // No change needed
  }

  // Sandbox mode is a thread-level setting — it can only be applied at
  // thread/start or thread/resume time, not per-turn. To apply the new
  // mode we destroy the current session and resume the same Codex thread
  // with the updated sandbox parameter (same pattern as clearContext).
  const oldSessionId = session.id;
  const threadId = session.claudeSessionId;
  const projectPath = session.projectPath;
  const oldSettings = session.codexSettings ?? {};
  const worktreePath = session.worktreePath;
  const worktreeBranch = session.worktreeBranch;
  const sessionName = session.name;
  const collaborationMode = (session.process as CodexProcess)
    .collaborationMode;
  const workspace = workspaceForRuntimeSession(server, session);
  const executionMode =
    oldSettings.approvalPolicy === "never" ? "fullAccess" : "default";
  const planMode = collaborationMode === "plan";
  const legacyPermissionMode = modesToLegacyPermissionMode(
    "codex",
    executionMode,
    planMode,
  );

  server.destroySession(oldSessionId);
  console.log(
    `[ws] Sandbox mode change: destroyed session ${oldSessionId}`,
  );

  // Check if the user actually exchanged messages in this session.
  // session.history always contains system events (init, status, etc.)
  // even before the first user turn, so we check for user_input/assistant
  // messages specifically.
  const hasUserMessages =
    session.history?.some(
      (m: Record<string, unknown>) =>
        m.type === "user_input" || m.type === "assistant",
    ) ||
    (session.pastMessages && session.pastMessages.length > 0);
  if (!threadId || !hasUserMessages) {
    // Session has no thread yet, or has a thread but no messages exchanged.
    // Create a fresh session with the new sandbox — no resume needed.
    // (A thread with no messages cannot be resumed — Codex returns
    // "no rollout found for thread id".)
    const newId = server.sessionManager.create(
      projectPath,
      undefined,
      undefined,
      worktreePath
        ? { existingWorktreePath: worktreePath, worktreeBranch }
        : undefined,
      "codex",
      withCodexAutoReviewPolicy(server, {
        approvalPolicy: oldSettings.approvalPolicy as
          | "never"
          | "on-request"
          | undefined,
        approvalsReviewer: oldSettings.approvalsReviewer as
          | "user"
          | "auto_review"
          | "guardian_subagent"
          | undefined,
        codexPermissionsMode: oldSettings.codexPermissionsMode as
          | "default"
          | "autoReview"
          | "fullAccess"
          | "custom"
          | undefined,
        sandboxMode: newSandboxMode,
        model: oldSettings.model,
        modelReasoningEffort:
          oldSettings.modelReasoningEffort as CodexStartOptions["modelReasoningEffort"],
        serviceTier: oldSettings.serviceTier,
        networkAccessEnabled: oldSettings.networkAccessEnabled as
          | boolean
          | undefined,
        webSearchMode: oldSettings.webSearchMode as
          | "disabled"
          | "cached"
          | "live"
          | undefined,
        additionalWritableRoots: oldSettings.additionalWritableRoots,
        collaborationMode,
      }),
    );
    attachWorkspaceToRuntimeSession(server, newId, workspace);
    const newSession = server.sessionManager.get(newId);
    if (newSession && sessionName) newSession.name = sessionName;
    server.broadcast(
      server.buildSessionCreatedMessage({
        sessionId: newId,
        provider: "codex",
        projectPath,
        session: newSession,
        permissionMode: legacyPermissionMode,
        executionMode,
        planMode,
        sandboxMode: sandboxModeToExternal(newSandboxMode),
        sourceSessionId: oldSessionId,
      }),
    );
    server.broadcastSessionList();
    console.log(
      `[ws] Sandbox mode change (no thread): created new session ${newId} (sandbox=${newSandboxMode})`,
    );
    return;
  }

  // Worktree resolution (same as resume_session)
  const wtMapping = server.worktreeStore.get(threadId);
  const effectiveProjectPath = wtMapping?.projectPath ?? projectPath;
  let worktreeOpts:
    | {
        useWorktree?: boolean;
        worktreeBranch?: string;
        existingWorktreePath?: string;
      }
    | undefined;
  if (wtMapping) {
    if (worktreeExists(wtMapping.worktreePath)) {
      worktreeOpts = {
        existingWorktreePath: wtMapping.worktreePath,
        worktreeBranch: wtMapping.worktreeBranch,
      };
    } else {
      worktreeOpts = {
        useWorktree: true,
        worktreeBranch: wtMapping.worktreeBranch,
      };
    }
  } else if (worktreePath) {
    worktreeOpts = { existingWorktreePath: worktreePath, worktreeBranch };
  }

  getCodexThreadHistory(server, threadId, effectiveProjectPath)
    .then((pastMessages) => {
      const newId = server.sessionManager.create(
        effectiveProjectPath,
        undefined,
        pastMessages,
        worktreeOpts,
        "codex",
        withCodexAutoReviewPolicy(server, {
          threadId,
          approvalPolicy: oldSettings.approvalPolicy as
            | "never"
            | "on-request"
            | undefined,
          approvalsReviewer: oldSettings.approvalsReviewer as
            | "user"
            | "auto_review"
            | "guardian_subagent"
            | undefined,
          codexPermissionsMode: oldSettings.codexPermissionsMode as
            | "default"
            | "autoReview"
            | "fullAccess"
            | "custom"
            | undefined,
          sandboxMode: newSandboxMode,
          model: oldSettings.model,
          modelReasoningEffort:
            oldSettings.modelReasoningEffort as CodexStartOptions["modelReasoningEffort"],
          serviceTier: oldSettings.serviceTier,
          networkAccessEnabled: oldSettings.networkAccessEnabled as
            | boolean
            | undefined,
          webSearchMode: oldSettings.webSearchMode as
            | "disabled"
            | "cached"
            | "live"
            | undefined,
          additionalWritableRoots: oldSettings.additionalWritableRoots,
          collaborationMode,
        }),
      );
      attachWorkspaceToRuntimeSession(server, newId, workspace);

      // Restore session name
      const newSession = server.sessionManager.get(newId);
      if (newSession && sessionName) {
        newSession.name = sessionName;
      }

      void loadAndSetSessionName(
        newSession,
        "codex",
        effectiveProjectPath,
        threadId,
      ).then(() => {
        server.broadcast(
          server.buildSessionCreatedMessage({
            sessionId: newId,
            provider: "codex",
            projectPath: effectiveProjectPath,
            session: newSession,
            permissionMode: legacyPermissionMode,
            executionMode,
            planMode,
            sandboxMode: sandboxModeToExternal(newSandboxMode),
            sourceSessionId: oldSessionId,
          }),
        );
        server.broadcastSessionList();
      });

      server.debugEvents.set(newId, []);
      recordDebugEvent(server, newId, {
        direction: "internal" as const,
        channel: "bridge" as const,
        type: "sandbox_mode_changed",
        detail: `sandbox=${newSandboxMode} thread=${threadId} oldSession=${oldSessionId}`,
      });
      console.log(
        `[ws] Sandbox mode change: created new session ${newId} (thread=${threadId}, sandbox=${newSandboxMode})`,
      );
    })
    .catch((err) => {
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        message: `Failed to restart session for sandbox mode change: ${err}`,
      });
    });
}
