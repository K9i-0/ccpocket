import { existsSync } from "node:fs";
import { WebSocket } from "ws";
import type { WorktreeOptions } from "../../session.js";
import {
  codexErrorMessage,
  isCodexThreadWriterConflict,
  type CodexStartOptions,
} from "../../codex-process.js";
import {
  AntigravityProcess,
  AntigravityStartError,
} from "../../antigravity-process.js";
import type { ClientMessage } from "../../parser.js";
import {
  getSessionHistory,
  normalizeWorktreePath,
} from "../../sessions-index.js";
import {
  formatResumePerformanceLog,
  summarizeResumeHistory,
} from "../../resume-metrics.js";
import type { ResolvedWorkspace } from "../../workspace-store.js";
import { worktreeExists } from "../../worktree.js";
import { resolvePlatformPath } from "../../path-utils.js";
import { normalizeCodexPermissionsMode } from "../../codex-permissions.js";
import {
  type SystemServerMessage,
  normalizeCodexApprovalPolicy,
  codexSettingsFromPermissionsMode,
  errorMessageOf,
  deriveExecutionMode,
  derivePlanMode,
  modesToLegacyPermissionMode,
  sandboxModeToInternal,
  sandboxModeToExternal,
} from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { recordDebugEvent } from "../debug-trace.js";
import {
  isPathAllowed,
  buildPathNotAllowedError,
  normalizeAdditionalWritableRoots,
} from "../file-access.js";
import { getCodexThreadHistory } from "../session-history.js";
import {
  loadAndSetSessionName,
  createClaudeSessionWithFallback,
  sendTip,
} from "../session-state.js";
import {
  codexServiceTierError,
  resolveCodexResumeProfile,
  withCodexAutoReviewPolicy,
} from "../models.js";

export async function handleResumeSession(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "resume_session" }>,
  ws: WebSocket,
): Promise<void> {
  const resumeStartedAt = Date.now();
  const provider = msg.provider ?? "claude";
  const tierError = provider === "codex"
    ? codexServiceTierError(server, msg.model, msg.serviceTier) : undefined;
  if (tierError) {
    server.sendResumeFailed(ws, { provider, sourceSessionId: msg.sessionId,
      projectPath: msg.projectPath, resumeRequestId: msg.resumeRequestId });
    server.send(ws, { type: "error", sessionId: msg.sessionId,
      requestId: msg.resumeRequestId,
      errorCode: "codex_service_tier_unavailable", message: tierError });
    return;
  }
  const storedAssignment = server.workspaceStore?.getAssignment(
    provider,
    msg.sessionId,
  );
  const requestedProject =
    !storedAssignment && msg.projectId
      ? server.workspaceStore?.getProject(msg.projectId)
      : undefined;
  if (!storedAssignment && msg.projectId && !requestedProject) {
    server.sendResumeFailed(ws, {
      provider,
      sourceSessionId: msg.sessionId,
      projectPath: msg.projectPath,
      resumeRequestId: msg.resumeRequestId,
    });
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      requestId: msg.resumeRequestId,
      errorCode: "project_not_found",
      message: `Project not found: ${msg.projectId}`,
    });
    return;
  }
  const assignedProject = storedAssignment?.projectId
    ? server.workspaceStore?.getProject(storedAssignment.projectId)
    : undefined;
  const resolvedResumeProjectName =
    assignedProject?.name ?? storedAssignment?.projectName;
  const resumeRoots =
    storedAssignment?.rootPaths ?? requestedProject?.rootPaths;
  console.log(
    `[ws] resume_session: sessionId=${msg.sessionId} projectPath=${msg.projectPath} provider=${msg.provider ?? "claude"}`,
  );
  // A stored assignment supplies the root snapshot and secondary roots,
  // while the recent-session path may be a worktree cwd that must win.
  const resumeProjectPath = resolvePlatformPath(
    storedAssignment
      ? msg.projectPath
      : (resumeRoots?.[0] ?? msg.projectPath),
    server.platform,
  );
  const resumeAdditionalRoots =
    resumeRoots?.slice(1) ?? msg.additionalWritableRoots;
  const resolvedResumeWorkspace: ResolvedWorkspace | undefined =
    storedAssignment
      ? {
          kind: storedAssignment.kind,
          ...(storedAssignment.projectId
            ? { projectId: storedAssignment.projectId }
            : {}),
          ...(resolvedResumeProjectName
            ? { projectName: resolvedResumeProjectName }
            : {}),
          rootPaths: storedAssignment.rootPaths,
        }
      : requestedProject
        ? {
            kind: "project",
            projectId: requestedProject.id,
            projectName: requestedProject.name,
            rootPaths: requestedProject.rootPaths,
          }
        : undefined;
  if (!isPathAllowed(server, resumeProjectPath)) {
    server.sendResumeFailed(ws, {
      provider,
      sourceSessionId: msg.sessionId,
      projectPath: resumeProjectPath,
      resumeRequestId: msg.resumeRequestId,
    });
    server.send(ws, {
      ...buildPathNotAllowedError(
        msg.projectPath,
        msg.resumeRequestId,
      ),
      sessionId: msg.sessionId,
    });
    return;
  }
  if (
    resolvedResumeWorkspace &&
    !storedAssignment &&
    server.workspaceStore
  ) {
    void server.workspaceStore.assignSession(
      provider,
      msg.sessionId,
      resolvedResumeWorkspace,
    ).catch((error) => {
      console.error("[workspace] Failed to persist resume assignment:", error);
    });
  }
  if (provider === "antigravity") {
    const live = server.sessionManager
      .list()
      .find(
        (candidate) =>
          candidate.provider === "antigravity" &&
          candidate.claudeSessionId === msg.sessionId,
      );
    const liveSession = live ? server.sessionManager.get(live.id) : undefined;
    const reusable =
      liveSession?.process instanceof AntigravityProcess &&
      liveSession.process.isRunning;
    // An exited process stays listed until eviction; replace it.
    if (liveSession && !reusable) server.sessionManager.destroy(liveSession.id);
    const remembered = server.antigravityStore.get(msg.sessionId);
    const wtMapping = server.worktreeStore.get(msg.sessionId);
    let effectiveResumeProjectPath = resumeProjectPath;
    let worktreeOpts: WorktreeOptions | undefined;
    if (wtMapping && worktreeExists(wtMapping.worktreePath)) {
      const mappedProject = resolvePlatformPath(
        wtMapping.projectPath,
        server.platform,
      );
      if (isPathAllowed(server, mappedProject)) {
        effectiveResumeProjectPath = mappedProject;
      }
      worktreeOpts = {
        existingWorktreePath: wtMapping.worktreePath,
        worktreeBranch: wtMapping.worktreeBranch,
      };
    }
    if (!existsSync(effectiveResumeProjectPath)) {
      const fallbackPath = resolvePlatformPath(
        wtMapping?.projectPath ?? normalizeWorktreePath(effectiveResumeProjectPath),
        server.platform,
      );
      if (isPathAllowed(server, fallbackPath)) {
        effectiveResumeProjectPath = fallbackPath;
      }
    }
    const sessionId =
      (reusable ? liveSession?.id : undefined) ??
      server.sessionManager.create(
        effectiveResumeProjectPath,
        {},
        undefined,
        worktreeOpts,
        "antigravity",
        undefined,
        undefined,
        {
          sessionId: msg.sessionId,
          // `session/load` starts on the agent default, so put back the
          // model and mode the conversation last ran on.
          model: msg.model ?? remembered?.model,
          permissionMode: msg.permissionMode ?? remembered?.permissionMode,
          modeBeforePlan: remembered?.modeBeforePlan,
          compactions: remembered?.compactions,
          permissionGrants: remembered?.permissionGrants,
          // Roots outside the allowed folders are left out.
          additionalDirectories: normalizeAdditionalWritableRoots(
            server,
            resumeAdditionalRoots,
            effectiveResumeProjectPath,
          ).roots,
        },
      );
    if (!reusable && remembered?.name) {
      server.sessionManager.renameSession(sessionId, remembered.name);
    }
    const resumed = server.sessionManager.get(sessionId);
    try {
      // `session/load` replays the conversation into history before
      // the client asks for it.
      if (resumed?.process instanceof AntigravityProcess) {
        await resumed.process.waitUntilReady();
        await server.sessionManager.waitForPendingMessages(sessionId);
      }
    } catch (err) {
      server.sessionManager.destroy(sessionId);
      server.sendResumeFailed(ws, {
        provider,
        sourceSessionId: msg.sessionId,
        projectPath: resumeProjectPath,
        resumeRequestId: msg.resumeRequestId,
      });
      server.send(ws, {
        type: "error",
        sessionId: msg.sessionId,
        requestId: msg.resumeRequestId,
        message: `Failed to restore Antigravity session: ${errorMessageOf(err)}`,
        ...(err instanceof AntigravityStartError && err.errorCode
          ? { errorCode: err.errorCode }
          : {}),
      });
      return;
    }
    if (resolvedResumeWorkspace) {
      server.pendingSessionWorkspaces.set(sessionId, resolvedResumeWorkspace);
    }
    server.send(
      ws,
      server.buildSessionCreatedMessage({
        sessionId,
        provider,
        projectPath: resumeProjectPath,
        session: resumed,
        permissionMode: resumed?.process instanceof AntigravityProcess
          ? resumed.process.permissionMode
          : msg.permissionMode,
        resumeRequestId: msg.resumeRequestId,
      }),
    );
    server.broadcastSessionList();
    return;
  }
  const normalizedCodexPermissionsMode =
    provider === "codex"
      ? normalizeCodexPermissionsMode(msg.codexPermissionsMode)
      : undefined;
  const requestedCodexPermissionsMode =
    server.codexAutoReviewDisabled &&
    normalizedCodexPermissionsMode === "autoReview"
      ? "default"
      : normalizedCodexPermissionsMode;
  const codexPermissionSettings = requestedCodexPermissionsMode
    ? codexSettingsFromPermissionsMode(requestedCodexPermissionsMode)
    : undefined;
  const codexApprovalPolicy =
    provider === "codex"
      ? requestedCodexPermissionsMode
        ? codexPermissionSettings?.approvalPolicy
        : normalizeCodexApprovalPolicy(
            msg.approvalPolicy ??
              (msg.executionMode == null
                ? undefined
                : msg.executionMode === "fullAccess"
                  ? "never"
                  : "on-request"),
          )
      : undefined;
  const executionMode = deriveExecutionMode({
    provider,
    permissionMode: msg.permissionMode,
    executionMode: msg.executionMode,
    approvalPolicy: codexApprovalPolicy,
  });
  const planMode = derivePlanMode({
    permissionMode: msg.permissionMode,
    planMode: msg.planMode,
  });
  const legacyPermissionMode = modesToLegacyPermissionMode(
    provider,
    executionMode,
    planMode,
  );
  const claudePermissionMode =
    provider === "claude"
      ? ((msg.permissionMode as
          | "default"
          | "auto"
          | "acceptEdits"
          | "bypassPermissions"
          | "plan"
          | undefined) ?? legacyPermissionMode)
      : legacyPermissionMode;
  const sessionRefId = msg.sessionId;
  // Resume flow: keep past history in SessionInfo and deliver it only
  // via get_history(sessionId) to avoid duplicate/missed replay races.
  if (provider === "codex") {
    const wtMapping = server.worktreeStore.get(sessionRefId);
    const effectiveProjectPath =
      resolvePlatformPath(
        wtMapping?.projectPath ?? resumeProjectPath,
        server.platform,
      );
    let effectiveProfile: string | undefined;
    try {
      effectiveProfile = msg.profile
        ? await resolveCodexResumeProfile(
            server,
            msg.profile,
            sessionRefId,
            effectiveProjectPath,
          )
        : undefined;
    } catch (err) {
      console.error(
        `[ws] Failed to resolve Codex profile on resume: ${err}`,
      );
      server.sendResumeFailed(ws, {
        provider,
        sourceSessionId: sessionRefId,
        projectPath: effectiveProjectPath,
        resumeRequestId: msg.resumeRequestId,
      });
      server.send(ws, {
        type: "error",
        sessionId: sessionRefId,
        requestId: msg.resumeRequestId,
        message: `Failed to resolve Codex profile: ${codexErrorMessage(err)}`,
      });
      return;
    }
    const additionalWritableRoots =
      normalizeAdditionalWritableRoots(
        server,
        resumeAdditionalRoots,
        effectiveProjectPath,
      );
    if (additionalWritableRoots.deniedRoot) {
      server.sendResumeFailed(ws, {
        provider,
        sourceSessionId: sessionRefId,
        projectPath: effectiveProjectPath,
        resumeRequestId: msg.resumeRequestId,
      });
      server.send(ws, {
        ...buildPathNotAllowedError(
          additionalWritableRoots.deniedRoot,
          msg.resumeRequestId,
        ),
        sessionId: sessionRefId,
      });
      return;
    }
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
    }

    const resumeOperation = server.beginResumeOperation({
      ws,
      provider: "codex",
      sourceSessionId: sessionRefId,
      projectPath: effectiveProjectPath,
      request: msg,
    });
    if (!resumeOperation.isOwner) return;

    let historyMetrics = summarizeResumeHistory([]);
    let historyLoadMs = 0;
    let historyLoaded = false;
    let sessionCreateMs = 0;
    let nameLoadMs = 0;
    const historyStartedAt = Date.now();
    try {
      const pastMessages = await getCodexThreadHistory(
        server,
        sessionRefId,
        effectiveProjectPath,
      );
      historyLoadMs = Date.now() - historyStartedAt;
      historyLoaded = true;
      historyMetrics = summarizeResumeHistory(pastMessages);
      const createStartedAt = Date.now();
      const sessionId = server.sessionManager.create(
        effectiveProjectPath,
        undefined,
        pastMessages,
        worktreeOpts,
        "codex",
        withCodexAutoReviewPolicy(server, {
          threadId: sessionRefId,
          profile: effectiveProfile,
          approvalPolicy: codexPermissionSettings
            ? codexPermissionSettings.approvalPolicy
            : (codexApprovalPolicy ??
              normalizeCodexApprovalPolicy(
                executionMode === "fullAccess" ? "never" : "on-request",
              )),
          approvalsReviewer:
            codexPermissionSettings?.approvalsReviewer ??
            msg.approvalsReviewer,
          codexPermissionsMode:
            codexPermissionSettings?.codexPermissionsMode,
          sandboxMode: codexPermissionSettings
            ? codexPermissionSettings.sandboxMode
            : sandboxModeToInternal(msg.sandboxMode),
          model: msg.model,
          modelReasoningEffort:
            (msg.modelReasoningEffort as CodexStartOptions["modelReasoningEffort"]) ??
            undefined,
          serviceTier: msg.serviceTier,
          networkAccessEnabled: msg.networkAccessEnabled,
          webSearchMode:
            (msg.webSearchMode as "disabled" | "cached" | "live") ??
            undefined,
          additionalWritableRoots: additionalWritableRoots.roots,
          collaborationMode: planMode
            ? ("plan" as const)
            : ("default" as const),
        }),
        { deferProcessMessages: true },
      );
      if (
        !server.attachProvisionalResumeSession(
          resumeOperation.key,
          resumeOperation.operationId,
          sessionId,
        )
      ) {
        server.sessionManager.destroy(sessionId);
        return;
      }
      sessionCreateMs = Date.now() - createStartedAt;
      const createdSession = server.sessionManager.get(sessionId);
      const waitUntilReady = (
        createdSession?.process as
          | { waitUntilReady?: () => Promise<void> }
          | undefined
      )?.waitUntilReady;
      if (!waitUntilReady) {
        throw new Error("Codex session readiness is unavailable");
      }
      await waitUntilReady.call(createdSession?.process);
      if (createdSession) {
        // get_history immediately follows session_created on the app.
        // Reuse the canonical history loaded above instead of issuing a
        // second thread/read for the same restored session.
        createdSession.codexInitialHistoryPending = true;
      }
      const cached = server.sessionManager.getCachedCommands(
        "codex",
        createdSession?.worktreePath ?? effectiveProjectPath,
      );
      const nameStartedAt = Date.now();
      await loadAndSetSessionName(
        createdSession,
        "codex",
        effectiveProjectPath,
        sessionRefId,
      );
      nameLoadMs = Date.now() - nameStartedAt;
      const createdMessage = server.buildSessionCreatedMessage({
        sessionId,
        provider: "codex",
        projectPath: effectiveProjectPath,
        session: createdSession,
        sandboxMode: createdSession?.codexSettings?.sandboxMode
          ? sandboxModeToExternal(createdSession.codexSettings.sandboxMode)
          : undefined,
        approvalsReviewer:
          createdSession?.codexSettings?.approvalsReviewer,
        codexPermissionsMode:
          createdSession?.codexSettings?.codexPermissionsMode,
        permissionMode: legacyPermissionMode,
        executionMode,
        planMode,
        resumeRequestId: msg.resumeRequestId,
        ...(cached
          ? {
              slashCommands: cached.slashCommands,
              skills: cached.skills,
              ...(cached.skillMetadata
                ? { skillMetadata: cached.skillMetadata }
                : {}),
              apps: cached.apps,
              ...(cached.appMetadata
                ? { appMetadata: cached.appMetadata }
                : {}),
              plugins: cached.plugins,
              ...(cached.pluginMetadata
                ? { pluginMetadata: cached.pluginMetadata }
                : {}),
            }
          : {}),
      });
      if (
        !server.completeResumeOperation(
          resumeOperation.key,
          resumeOperation.operationId,
          sessionId,
          createdMessage,
        )
      ) {
        server.sessionManager.destroy(sessionId);
        return;
      }
      server.sessionManager.releaseDeferredProcessMessages(sessionId);
      server.broadcastSessionList();
      server.debugEvents.set(sessionId, []);
      recordDebugEvent(server, sessionId, {
        direction: "internal",
        channel: "bridge",
        type: "session_resumed",
        detail: `provider=codex thread=${sessionRefId}`,
      });
      if (!resolvedResumeWorkspace) {
        server.projectHistory?.addProject(effectiveProjectPath);
      }
      console.info(
        formatResumePerformanceLog({
          provider: "codex",
          sourceSessionId: sessionRefId,
          outcome: "success",
          ...historyMetrics,
          historyLoadMs,
          sessionCreateMs,
          nameLoadMs,
          totalMs: Date.now() - resumeStartedAt,
        }),
      );
    } catch (err) {
      if (!historyLoaded) {
        historyLoadMs = Date.now() - historyStartedAt;
      }
      console.info(
        formatResumePerformanceLog({
          provider: "codex",
          sourceSessionId: sessionRefId,
          outcome: "failed",
          ...historyMetrics,
          historyLoadMs,
          sessionCreateMs,
          nameLoadMs,
          totalMs: Date.now() - resumeStartedAt,
        }),
      );
      const activeWriterConflict = isCodexThreadWriterConflict(err);
      server.failResumeOperation(
        resumeOperation.key,
        resumeOperation.operationId,
        activeWriterConflict
          ? codexErrorMessage(err)
          : historyLoaded
            ? `Failed to restore Codex session: ${err}`
            : `Failed to load Codex session history: ${err}`,
        activeWriterConflict
          ? "codex_thread_writer_conflict"
          : undefined,
      );
    }
    return;
  }

  const claudeSessionId = sessionRefId;
  const additionalDirectories = normalizeAdditionalWritableRoots(
    server,
    resumeAdditionalRoots,
    resumeProjectPath,
  );
  if (additionalDirectories.deniedRoot) {
    server.sendResumeFailed(ws, {
      provider,
      sourceSessionId: sessionRefId,
      projectPath: resumeProjectPath,
      resumeRequestId: msg.resumeRequestId,
    });
    server.send(ws, {
      ...buildPathNotAllowedError(
        additionalDirectories.deniedRoot,
        msg.resumeRequestId,
      ),
      sessionId: sessionRefId,
    });
    return;
  }
  // Look up worktree mapping for this Claude session
  const wtMapping = server.worktreeStore.get(claudeSessionId);
  let worktreeOpts:
    | {
        useWorktree?: boolean;
        worktreeBranch?: string;
        existingWorktreePath?: string;
      }
    | undefined;
  if (wtMapping) {
    if (worktreeExists(wtMapping.worktreePath)) {
      // Worktree exists — reuse it directly
      worktreeOpts = {
        existingWorktreePath: wtMapping.worktreePath,
        worktreeBranch: wtMapping.worktreeBranch,
      };
    } else {
      // Worktree was deleted — recreate on the same branch
      worktreeOpts = {
        useWorktree: true,
        worktreeBranch: wtMapping.worktreeBranch,
      };
    }
  }

  const resumeOperation = server.beginResumeOperation({
    ws,
    provider: "claude",
    sourceSessionId: claudeSessionId,
    projectPath: resumeProjectPath,
    request: msg,
  });
  if (!resumeOperation.isOwner) return;

  const historyStartedAt = Date.now();
  let historyMetrics = summarizeResumeHistory([]);
  let historyLoadMs = 0;
  let historyLoaded = false;
  let sessionCreateMs = 0;
  getSessionHistory(claudeSessionId)
    .then((pastMessages) => {
      historyLoadMs = Date.now() - historyStartedAt;
      historyLoaded = true;
      historyMetrics = summarizeResumeHistory(pastMessages);
      const createStartedAt = Date.now();
      const {
        sessionId,
        permissionMode: effectivePermissionMode,
        executionMode: effectiveExecutionMode,
        planMode: effectivePlanMode,
        usedFallback: autoFallbackUsed,
      } = createClaudeSessionWithFallback(server, {
        projectPath: resumeProjectPath,
        options: {
          sessionId: claudeSessionId,
          permissionMode: claudePermissionMode,
          model: msg.model,
          effort: msg.effort,
          fastMode: msg.claudeFastMode,
          ultracode: msg.claudeUltracode,
          maxTurns: msg.maxTurns,
          maxBudgetUsd: msg.maxBudgetUsd,
          fallbackModel: msg.fallbackModel,
          forkSession: msg.forkSession,
          persistSession: msg.persistSession,
          ...(msg.sandboxMode
            ? { sandboxEnabled: msg.sandboxMode === "on" }
            : {}),
          additionalDirectories: additionalDirectories.roots,
        },
        pastMessages,
        worktreeOptions: worktreeOpts,
      });
      sessionCreateMs = Date.now() - createStartedAt;
      const createdSession = server.sessionManager.get(sessionId);
      const cached = server.sessionManager.getCachedCommands(
        "claude",
        createdSession?.worktreePath ?? resumeProjectPath,
      );
      const nameStartedAt = Date.now();
      const finishResume = () => {
        const createdMessage = {
          ...server.buildSessionCreatedMessage({
            sessionId,
            provider: "claude",
            projectPath: resumeProjectPath,
            session: createdSession,
            permissionMode: effectivePermissionMode,
            executionMode: effectiveExecutionMode,
            planMode: effectivePlanMode,
            sandboxMode: msg.sandboxMode,
            resumeRequestId: msg.resumeRequestId,
            ...(cached
              ? {
                  slashCommands: cached.slashCommands,
                  skills: cached.skills,
                  ...(cached.skillMetadata
                    ? { skillMetadata: cached.skillMetadata }
                    : {}),
                  apps: cached.apps,
                  ...(cached.appMetadata
                    ? { appMetadata: cached.appMetadata }
                    : {}),
                  plugins: cached.plugins,
                  ...(cached.pluginMetadata
                    ? { pluginMetadata: cached.pluginMetadata }
                    : {}),
                }
              : {}),
          }),
          claudeSessionId,
        } as SystemServerMessage;
        if (
          !server.completeResumeOperation(
            resumeOperation.key,
            resumeOperation.operationId,
            sessionId,
            createdMessage,
          )
        ) {
          server.sessionManager.destroy(sessionId);
          return;
        }
        server.broadcastSessionList();
        if (autoFallbackUsed) {
          sendTip(
            server,
            ws,
            sessionId,
            "auto_mode_fallback_default",
            createdSession,
          );
        }
        console.info(
          formatResumePerformanceLog({
            provider: "claude",
            sourceSessionId: claudeSessionId,
            outcome: "success",
            ...historyMetrics,
            historyLoadMs,
            sessionCreateMs,
            nameLoadMs: Date.now() - nameStartedAt,
            totalMs: Date.now() - resumeStartedAt,
          }),
        );
      };
      void loadAndSetSessionName(
        createdSession,
        "claude",
        resumeProjectPath,
        claudeSessionId,
      ).then(finishResume, (err) => {
        console.error("[ws] Failed to load resumed session name:", err);
        finishResume();
      });
      server.debugEvents.set(sessionId, []);
      recordDebugEvent(server, sessionId, {
        direction: "internal",
        channel: "bridge",
        type: "session_resumed",
        detail: `provider=claude session=${claudeSessionId}`,
      });
      if (!resolvedResumeWorkspace) {
        server.projectHistory?.addProject(resumeProjectPath);
      }
    })
    .catch((err) => {
      if (!historyLoaded) {
        historyLoadMs = Date.now() - historyStartedAt;
      }
      console.info(
        formatResumePerformanceLog({
          provider: "claude",
          sourceSessionId: claudeSessionId,
          outcome: "failed",
          ...historyMetrics,
          historyLoadMs,
          sessionCreateMs,
          nameLoadMs: 0,
          totalMs: Date.now() - resumeStartedAt,
        }),
      );
      server.failResumeOperation(
        resumeOperation.key,
        resumeOperation.operationId,
        `Failed to load session history: ${err}`,
      );
    });
}
