import { randomUUID } from "node:crypto";
import { WebSocket } from "ws";
import type { CodexStartOptions } from "../../codex-process.js";
import type { ClientMessage } from "../../parser.js";
import type { ResolvedWorkspace } from "../../workspace-store.js";
import { resolvePlatformPath } from "../../path-utils.js";
import { normalizeCodexPermissionsMode } from "../../codex-permissions.js";
import {
  normalizeCodexApprovalPolicy,
  codexSettingsFromPermissionsMode,
  deriveExecutionMode,
  derivePlanMode,
  modesToLegacyPermissionMode,
  sandboxModeToInternal,
  sandboxModeToExternal,
} from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { recordDebugEvent } from "../debug-trace.js";
import {
  buildPathNotAllowedError,
  isPathAllowed,
  normalizeAdditionalWritableRoots,
} from "../file-access.js";
import {
  createClaudeSessionWithFallback,
  loadAndSetSessionName,
  sendTip,
  prepareInitialPrompt,
} from "../session-state.js";
import {
  normalizeWorkspaceRoots,
  persistPendingSessionWorkspace,
} from "../workspaces.js";
import { codexServiceTierError, withCodexAutoReviewPolicy } from "../models.js";

/** Options of a start the Bridge issues itself; clients cannot send them. */
export interface InternalStartOptions {
  /** Continue this stopped session of another provider (session handoff). */
  handoffSourceSessionId?: string;
  /**
   * Send `initialPrompt` as written. A handoff prompt quotes earlier user
   * turns, and their skill triggers must not be rewritten or attached.
   */
  rawInitialPrompt?: boolean;
  /** Name for the session, kept in memory until it can be persisted. */
  name?: string;
}

/** Returns the id of the created session, or undefined when it failed. */
export async function handleStart(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "start" }>,
  ws: WebSocket,
  internal: InternalStartOptions = {},
): Promise<string | undefined> {
  let projectPath = resolvePlatformPath(msg.projectPath, server.platform);
  let resolvedWorkspace: ResolvedWorkspace | undefined;
  if (msg.projectId) {
    const project = server.workspaceStore?.getProject(msg.projectId);
    if (!project) {
      server.send(ws, {
        type: "error",
        requestId: msg.requestId,
        errorCode: "project_not_found",
        message: `Project not found: ${msg.projectId}`,
      });
      return;
    }
    const normalized = normalizeWorkspaceRoots(server, project.rootPaths);
    if (normalized.deniedRoot || !normalized.roots) {
      server.send(
        ws,
        buildPathNotAllowedError(
          normalized.deniedRoot ?? project.rootPaths[0],
          msg.requestId,
        ),
      );
      return;
    }
    projectPath = normalized.roots[0];
    resolvedWorkspace = {
      kind: "project",
      projectId: project.id,
      projectName: project.name,
      rootPaths: normalized.roots,
    };
  }
  if (!isPathAllowed(server, projectPath)) {
    server.send(ws, {
      ...buildPathNotAllowedError(msg.projectPath),
      requestId: msg.requestId,
      path: msg.projectPath,
    });
    return;
  }
  try {
    const provider = msg.provider ?? "claude";
    const tierError = provider === "codex"
      ? codexServiceTierError(server, msg.model, msg.serviceTier) : undefined;
    if (tierError) {
      server.send(ws, { type: "error", requestId: msg.requestId,
        errorCode: "codex_service_tier_unavailable", message: tierError });
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
      provider !== "codex"
        ? ((msg.permissionMode as
            | "default"
            | "auto"
            | "acceptEdits"
            | "bypassPermissions"
            | "plan"
            | undefined) ?? legacyPermissionMode)
        : legacyPermissionMode;
    const antigravityPermissionMode =
      provider === "antigravity" &&
      msg.permissionMode === undefined &&
      msg.executionMode === undefined &&
      msg.planMode === undefined
        ? undefined
        : claudePermissionMode;
    if (provider === "codex") {
      console.log(
        `[ws] start(codex): execution=${executionMode} plan=${planMode}`,
      );
      if (
        msg.profile &&
        !(await server.validateCodexProfile(msg.profile, projectPath))
      ) {
        server.send(ws, {
          type: "error",
          requestId: msg.requestId,
          path: projectPath,
          message: `Codex profile not found: ${msg.profile}`,
        });
        return;
      }
    }
    const requestedAdditionalRoots =
      resolvedWorkspace?.rootPaths.slice(1) ??
      msg.additionalWritableRoots;
    const additionalWritableRoots = normalizeAdditionalWritableRoots(
      server,
      requestedAdditionalRoots,
      projectPath,
    );
    if (additionalWritableRoots.deniedRoot) {
      server.send(
        ws,
        {
          ...buildPathNotAllowedError(
            additionalWritableRoots.deniedRoot,
          ),
          requestId: msg.requestId,
          path: projectPath,
        },
      );
      return;
    }
    const {
      sessionId,
      permissionMode: effectivePermissionMode,
      executionMode: effectiveExecutionMode,
      planMode: effectivePlanMode,
      usedFallback: autoFallbackUsed,
    } =
      provider === "claude"
        ? createClaudeSessionWithFallback(server, {
            projectPath,
            options: {
              sessionId: msg.sessionId,
              continueMode: msg.continue,
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
              autoRename: msg.autoRename,
              ...(msg.sandboxMode
                ? { sandboxEnabled: msg.sandboxMode === "on" }
                : {}),
              additionalDirectories: additionalWritableRoots.roots,
            },
            worktreeOptions: {
              useWorktree: msg.useWorktree,
              worktreeBranch: msg.worktreeBranch,
              existingWorktreePath: msg.existingWorktreePath,
            },
          })
        : provider === "antigravity"
          ? {
              sessionId: server.sessionManager.create(
                projectPath,
                {},
                undefined,
                {
                  useWorktree: msg.useWorktree,
                  worktreeBranch: msg.worktreeBranch,
                  existingWorktreePath: msg.existingWorktreePath,
                },
                provider,
                undefined,
                undefined,
                {
                  sessionId: msg.sessionId,
                  model: msg.model,
                  thoughtLevel: msg.effort,
                  permissionMode: antigravityPermissionMode,
                  additionalDirectories: additionalWritableRoots.roots,
                },
              ),
              permissionMode: antigravityPermissionMode,
              executionMode:
                antigravityPermissionMode === "bypassPermissions"
                  ? "fullAccess"
                  : executionMode === "fullAccess"
                    ? "default"
                    : executionMode,
              planMode,
              usedFallback: false,
            }
        : {
            sessionId: server.sessionManager.create(
              projectPath,
              { autoRename: msg.autoRename },
              undefined,
              {
                useWorktree: msg.useWorktree,
                worktreeBranch: msg.worktreeBranch,
                existingWorktreePath: msg.existingWorktreePath,
              },
              provider,
              withCodexAutoReviewPolicy(server, {
                profile: msg.profile,
                approvalPolicy: codexPermissionSettings
                  ? codexPermissionSettings.approvalPolicy
                  : (codexApprovalPolicy ??
                    normalizeCodexApprovalPolicy(
                      executionMode === "fullAccess"
                        ? "never"
                        : "on-request",
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
                threadId: msg.sessionId,
                collaborationMode: planMode
                  ? ("plan" as const)
                  : ("default" as const),
              }),
            ),
            permissionMode: claudePermissionMode,
            executionMode,
            planMode,
            usedFallback: false,
          };
    const createdSession = server.sessionManager.get(sessionId);
    if (internal.name) {
      server.sessionManager.renameSession(sessionId, internal.name);
    }
    if (resolvedWorkspace) {
      server.pendingSessionWorkspaces.set(sessionId, resolvedWorkspace);
      void persistPendingSessionWorkspace(server, sessionId);
    }
    const cached = server.sessionManager.getCachedCommands(
      provider,
      createdSession?.worktreePath ?? projectPath,
    );

    // Load saved session name from CLI storage (for resumed sessions)
    void loadAndSetSessionName(
      createdSession,
      provider,
      projectPath,
      msg.sessionId,
    ).then(() => {
      server.send(
        ws,
        server.buildSessionCreatedMessage({
          sessionId,
          provider,
          projectPath,
          session: createdSession,
          permissionMode:
            provider !== "codex"
              ? effectivePermissionMode
              : claudePermissionMode,
          executionMode:
            provider !== "codex"
              ? effectiveExecutionMode
              : executionMode,
          planMode: provider !== "codex" ? effectivePlanMode : planMode,
          sandboxMode: createdSession?.codexSettings?.sandboxMode
            ? sandboxModeToExternal(createdSession.codexSettings.sandboxMode)
            : msg.sandboxMode,
          codexPermissionsMode:
            createdSession?.codexSettings?.codexPermissionsMode,
          approvalsReviewer:
            createdSession?.codexSettings?.approvalsReviewer,
          requestId: msg.requestId,
          ...(internal.handoffSourceSessionId
            ? {
                sourceSessionId: internal.handoffSourceSessionId,
                handoff: true,
              }
            : {}),
          ...(cached
            ? {
                slashCommands: cached.slashCommands,
                ...(cached.slashCommandDescriptions
                  ? {
                      slashCommandDescriptions:
                        cached.slashCommandDescriptions,
                    }
                  : {}),
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
      );
      server.broadcastSessionList();
      if (provider === "codex") {
        void server.refreshCodexMetadata(projectPath);
      } else if (provider === "claude") {
        void server.refreshClaudeModels(projectPath);
      }
      if (autoFallbackUsed) {
        sendTip(
          server,
          ws,
          sessionId,
          "auto_mode_fallback_default",
          createdSession,
        );
      }
      if (msg.initialPrompt?.trim()) {
        const initialPrompt = msg.initialPrompt;
        void (internal.rawInitialPrompt
          ? Promise.resolve({ text: initialPrompt, skills: [] })
          : prepareInitialPrompt(
              server,
              provider,
              createdSession?.worktreePath ?? projectPath,
              sessionId,
              initialPrompt,
            )
        )
          .then((prepared) =>
            server.handleClientMessage(
              {
                type: "input",
                sessionId,
                text: prepared.text,
                clientMessageId: randomUUID(),
                ...(prepared.skills.length > 0
                  ? { skills: prepared.skills }
                  : {}),
              },
              ws,
              true,
            ),
          )
          .catch((error) => {
            server.send(ws, { type: "error", sessionId, message: `Failed to send initial project request: ${(error as Error).message}` });
          });
      }
      // Send a gentle tip when the project is not a git repository
      if (createdSession && !createdSession.gitBranch) {
        sendTip(server, ws, sessionId, "git_not_available", createdSession);
      }
    });
    server.debugEvents.set(sessionId, []);
    recordDebugEvent(server, sessionId, {
      direction: "internal",
      channel: "bridge",
      type: "session_created",
      detail: `provider=${provider} projectPath=${projectPath}`,
    });
    server.recordingStore?.saveMeta(sessionId, {
      bridgeSessionId: sessionId,
      projectPath,
      ...(resolvedWorkspace?.projectId
        ? { projectId: resolvedWorkspace.projectId }
        : {}),
      ...(resolvedWorkspace?.projectName
        ? { projectName: resolvedWorkspace.projectName }
        : {}),
      createdAt: new Date().toISOString(),
    });
    if (!resolvedWorkspace) {
      server.projectHistory?.addProject(projectPath);
    }
    return sessionId;
  } catch (err) {
    console.error(`[ws] Failed to start session:`, err);
    server.send(ws, {
      type: "error",
      requestId: msg.requestId,
      path: msg.projectPath,
      message: `Failed to start session: ${(err as Error).message}`,
    });
    return undefined;
  }
}
