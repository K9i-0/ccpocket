import type { Server as HttpServer } from "node:http";
import { execFile, execFileSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { readFile, unlink } from "node:fs/promises";
import { resolve, extname } from "node:path";
import { promisify } from "node:util";
import { WebSocketServer, WebSocket } from "ws";
import { SessionManager, type SessionInfo } from "./session.js";
import { SdkProcess } from "./sdk-process.js";
import type { CodexProcess } from "./codex-process.js";
import { parseClientMessage, type ClientMessage, type DebugTraceEvent, type ImageChange, type ServerMessage } from "./parser.js";
import { getAllRecentSessions, getCodexSessionHistory, getSessionHistory, findSessionsByClaudeIds, extractMessageImages, getClaudeSessionName, loadCodexSessionNames, renameClaudeSession, renameCodexSession } from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";
import type { GalleryStore } from "./gallery-store.js";
import type { ProjectHistory } from "./project-history.js";
import { ArchiveStore } from "./archive-store.js";
import { WorktreeStore } from "./worktree-store.js";
import { listWorktrees, removeWorktree, createWorktree, worktreeExists, getMainBranch } from "./worktree.js";
import { listWindows, takeScreenshot } from "./screenshot.js";
import { DebugTraceStore } from "./debug-trace-store.js";
import { RecordingStore } from "./recording-store.js";
import { PushRelayClient } from "./push-relay.js";
import type { FirebaseAuthClient } from "./firebase-auth.js";
import { type PushLocale, normalizePushLocale, t } from "./push-i18n.js";
import { fetchAllUsage } from "./usage.js";
import type { PromptHistoryBackupStore } from "./prompt-history-backup.js";

// ---- Codex mode mapping helpers ----

/** Map unified PermissionMode to Codex approval_policy.
 *  Only "bypassPermissions" maps to "never"; all others use "on-request". */
function permissionModeToApprovalPolicy(
  mode?: string,
): "never" | "on-request" {
  return mode === "bypassPermissions" ? "never" : "on-request";
}

/** Map simplified SandboxMode (on/off) to Codex internal sandbox mode. */
function sandboxModeToInternal(
  mode?: string,
): "workspace-write" | "danger-full-access" {
  return mode === "off" ? "danger-full-access" : "workspace-write";
}

/** Map Codex internal sandbox mode back to simplified on/off for clients. */
function sandboxModeToExternal(
  mode?: string,
): "on" | "off" {
  return mode === "danger-full-access" ? "off" : "on";
}

export interface BridgeServerOptions {
  server: HttpServer;
  apiKey?: string;
  imageStore?: ImageStore;
  galleryStore?: GalleryStore;
  projectHistory?: ProjectHistory;
  debugTraceStore?: DebugTraceStore;
  recordingStore?: RecordingStore;
  firebaseAuth?: FirebaseAuthClient;
  promptHistoryBackup?: PromptHistoryBackupStore;
}

export class BridgeWebSocketServer {
  private static readonly MAX_DEBUG_EVENTS = 800;
  private static readonly MAX_HISTORY_SUMMARY_ITEMS = 300;

  private wss: WebSocketServer;
  private sessionManager: SessionManager;
  private apiKey: string | null;
  private imageStore: ImageStore | null;
  private galleryStore: GalleryStore | null;
  private projectHistory: ProjectHistory | null;
  private debugTraceStore: DebugTraceStore;
  private recordingStore: RecordingStore;
  private worktreeStore: WorktreeStore;
  private pushRelay: PushRelayClient;
  private promptHistoryBackup: PromptHistoryBackupStore | null;
  private recentSessionsRequestId = 0;
  private debugEvents = new Map<string, DebugTraceEvent[]>();
  private notifiedPermissionToolUses = new Map<string, Set<string>>();
  private archiveStore: ArchiveStore;
  /** FCM token → push notification locale */
  private tokenLocales = new Map<string, PushLocale>();
  private tokenPrivacyMode = new Map<string, boolean>();

  constructor(options: BridgeServerOptions) {
    const { server, apiKey, imageStore, galleryStore, projectHistory, debugTraceStore, recordingStore, firebaseAuth, promptHistoryBackup } = options;
    this.apiKey = apiKey ?? null;
    this.imageStore = imageStore ?? null;
    this.galleryStore = galleryStore ?? null;
    this.projectHistory = projectHistory ?? null;
    this.debugTraceStore = debugTraceStore ?? new DebugTraceStore();
    this.recordingStore = recordingStore ?? new RecordingStore();
    this.worktreeStore = new WorktreeStore();
    this.pushRelay = new PushRelayClient({ firebaseAuth });
    this.promptHistoryBackup = promptHistoryBackup ?? null;
    this.archiveStore = new ArchiveStore();
    void this.debugTraceStore.init().catch((err) => {
      console.error("[ws] Failed to initialize debug trace store:", err);
    });
    void this.recordingStore.init().catch((err) => {
      console.error("[ws] Failed to initialize recording store:", err);
    });
    void this.archiveStore.init().catch((err) => {
      console.error("[ws] Failed to initialize archive store:", err);
    });
    if (!this.pushRelay.isConfigured) {
      console.log("[ws] Push relay disabled (Firebase auth not available)");
    } else {
      console.log("[ws] Push relay enabled (Firebase Anonymous Auth)");
    }

    this.wss = new WebSocketServer({ server });

    this.sessionManager = new SessionManager(
      (sessionId, msg) => {
        this.broadcastSessionMessage(sessionId, msg);
      },
      imageStore,
      galleryStore,
      // Broadcast gallery_new_image when a new image is added
      (meta) => {
        if (this.galleryStore) {
          const info = this.galleryStore.metaToInfo(meta);
          this.broadcast({ type: "gallery_new_image", image: info });
        }
      },
      this.worktreeStore,
    );

    this.wss.on("connection", (ws, req) => {
      // API key authentication
      if (this.apiKey) {
        const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
        const token = url.searchParams.get("token");
        if (token !== this.apiKey) {
          console.log("[ws] Client rejected: invalid token");
          ws.close(4001, "Unauthorized");
          return;
        }
      }

      console.log("[ws] Client connected");
      this.handleConnection(ws);
    });

    this.wss.on("error", (err) => {
      console.error("[ws] Server error:", err.message);
    });

    console.log(`[ws] WebSocket server attached to HTTP server`);
  }

  close(): void {
    console.log("[ws] Shutting down...");
    this.sessionManager.destroyAll();
    this.debugEvents.clear();
    this.wss.close();
  }

  /** Return session count for /health endpoint. */
  get sessionCount(): number {
    return this.sessionManager.list().length;
  }

  /** Return connected WebSocket client count. */
  get clientCount(): number {
    return this.wss.clients.size;
  }

  private handleConnection(ws: WebSocket): void {
    // Send session list on connect
    this.sendSessionList(ws);

    ws.on("message", (data) => {
      const raw = data.toString();
      const msg = parseClientMessage(raw);

      if (!msg) {
        console.error("[ws] Invalid message:", raw.slice(0, 200));
        this.send(ws, { type: "error", message: "Invalid message format" });
        return;
      }

      console.log(`[ws] Received: ${msg.type}`);
      this.handleClientMessage(msg, ws);
    });

    ws.on("close", () => {
      console.log("[ws] Client disconnected");
    });

    ws.on("error", (err) => {
      console.error("[ws] Client error:", err.message);
    });
  }

  private handleClientMessage(msg: ClientMessage, ws: WebSocket): void {
    const incomingSessionId = this.extractSessionIdFromClientMessage(msg);
    const isActiveRuntimeSession =
      incomingSessionId != null && this.sessionManager.get(incomingSessionId) != null;
    if (incomingSessionId && isActiveRuntimeSession) {
      this.recordDebugEvent(incomingSessionId, {
        direction: "incoming",
        channel: "ws",
        type: msg.type,
        detail: this.summarizeClientMessage(msg),
      });
      this.recordingStore.record(incomingSessionId, "incoming", msg);
    }

    switch (msg.type) {
      case "start": {
        try {
          const provider = msg.provider ?? "claude";
          if (provider === "codex") {
            console.log(`[ws] start(codex): permissionMode=${msg.permissionMode} → collaboration=${msg.permissionMode === "plan" ? "plan" : "default"}`);
          }
          const cached = provider === "claude" ? this.sessionManager.getCachedCommands(msg.projectPath) : undefined;
          const sessionId = this.sessionManager.create(
            msg.projectPath,
            {
              sessionId: msg.sessionId,
              continueMode: msg.continue,
              permissionMode: msg.permissionMode,
              model: msg.model,
              effort: msg.effort,
              maxTurns: msg.maxTurns,
              maxBudgetUsd: msg.maxBudgetUsd,
              fallbackModel: msg.fallbackModel,
              forkSession: msg.forkSession,
              persistSession: msg.persistSession,
            },
            undefined,
            {
              useWorktree: msg.useWorktree,
              worktreeBranch: msg.worktreeBranch,
              existingWorktreePath: msg.existingWorktreePath,
            },
            provider,
            provider === "codex"
              ? {
                  approvalPolicy: permissionModeToApprovalPolicy(msg.permissionMode),
                  sandboxMode: sandboxModeToInternal(msg.sandboxMode),
                  model: msg.model,
                  modelReasoningEffort: (msg.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh") ?? undefined,
                  networkAccessEnabled: msg.networkAccessEnabled,
                  webSearchMode: (msg.webSearchMode as "disabled" | "cached" | "live") ?? undefined,
                  threadId: msg.sessionId,
                  collaborationMode: msg.permissionMode === "plan" ? "plan" as const : "default" as const,
                }
              : undefined,
          );
          const createdSession = this.sessionManager.get(sessionId);

          // Load saved session name from CLI storage (for resumed sessions)
          void this.loadAndSetSessionName(createdSession, provider, msg.projectPath, msg.sessionId).then(() => {
            this.send(ws, {
              type: "system",
              subtype: "session_created",
              sessionId,
              provider,
              projectPath: msg.projectPath,
              ...(provider === "claude" && msg.permissionMode ? { permissionMode: msg.permissionMode } : {}),
              ...(provider === "codex" && msg.sandboxMode ? { sandboxMode: msg.sandboxMode } : {}),
              ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
              ...(createdSession?.worktreePath ? {
                worktreePath: createdSession.worktreePath,
                worktreeBranch: createdSession.worktreeBranch,
              } : {}),
            });
            this.broadcastSessionList();
          });
          this.debugEvents.set(sessionId, []);
          this.recordDebugEvent(sessionId, {
            direction: "internal",
            channel: "bridge",
            type: "session_created",
            detail: `provider=${provider} projectPath=${msg.projectPath}`,
          });
          this.recordingStore.saveMeta(sessionId, {
            bridgeSessionId: sessionId,
            projectPath: msg.projectPath,
            createdAt: new Date().toISOString(),
          });
          this.projectHistory?.addProject(msg.projectPath);
        } catch (err) {
          console.error(`[ws] Failed to start session:`, err);
          this.send(ws, { type: "error", message: `Failed to start session: ${(err as Error).message}` });
        }
        break;
      }

      case "input": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session. Send 'start' first." });
          return;
        }
        const text = msg.text;

        // Codex: reject if the process is not waiting for input (turn-based, no internal queue)
        if (session.provider === "codex" && !session.process.isWaitingForInput) {
          this.send(ws, { type: "input_rejected", sessionId: session.id, reason: "Process is busy" });
          break;
        }

        // Snapshot busy state before dispatch. We prefer the actual enqueue
        // result returned by SdkProcess sendInput* below, but keep this as a
        // fallback for test doubles and async paths.
        const isAgentBusySnapshot = session.provider === "claude" && !session.process.isWaitingForInput;

        // Normalize images: support new `images` array and legacy single-image fields
        let images: Array<{ base64: string; mimeType: string }> = [];
        if (msg.images && msg.images.length > 0) {
          images = msg.images;
        } else if (msg.imageBase64 && msg.mimeType) {
          // Legacy single-image fallback
          images = [{ base64: msg.imageBase64, mimeType: msg.mimeType }];
        }

        // Add user_input to in-memory history.
        // The SDK stream does NOT emit user messages, so session.history would
        // otherwise lack them.  This ensures get_history responses include user
        // messages and replaceEntries on the client side preserves them.
        // We do NOT broadcast this back — Flutter already shows it via sendMessage().
        //
        // Register images in the image store so they can be served via HTTP
        // when the client re-enters the session and loads history.
        let imageRefs: Array<{ id: string; url: string; mimeType: string }> | undefined;
        if (images.length > 0 && this.imageStore) {
          imageRefs = [];
          for (const img of images) {
            const ref = this.imageStore.registerFromBase64(img.base64, img.mimeType);
            if (ref) imageRefs.push(ref);
          }
          if (imageRefs.length === 0) imageRefs = undefined;
        }
        session.history.push({
          type: "user_input",
          text,
          timestamp: new Date().toISOString(),
          ...(images.length > 0 ? { imageCount: images.length } : {}),
          ...(imageRefs ? { images: imageRefs } : {}),
        } as ServerMessage);

        // Persist images to Gallery Store asynchronously (fire-and-forget)
        if (images.length > 0 && this.galleryStore && session.projectPath) {
          for (const img of images) {
            this.galleryStore.addImageFromBase64(
              img.base64,
              img.mimeType,
              session.projectPath,
              msg.sessionId,
            ).catch((err) => {
              console.warn(`[ws] Failed to persist image to gallery: ${err}`);
            });
          }
        }

        // Codex input path
        if (session.provider === "codex") {
          this.send(ws, { type: "input_ack", sessionId: session.id, queued: false });
          const codexProc = session.process as CodexProcess;
          if (images.length > 0) {
            codexProc.sendInputWithImages(text, images);
          } else if (msg.imageId && this.galleryStore) {
            this.galleryStore.getImageAsBase64(msg.imageId).then((imageData) => {
              if (imageData) {
                codexProc.sendInputWithImages(text, [imageData]);
              } else {
                console.warn(`[ws] Image not found: ${msg.imageId}`);
                codexProc.sendInput(text);
              }
            }).catch((err) => {
              console.error(`[ws] Failed to load image: ${err}`);
              codexProc.sendInput(text);
            });
          } else {
            codexProc.sendInput(text);
          }
          break;
        }

        // Claude Code input path — enqueue first, then interrupt if busy
        const claudeProc = session.process as SdkProcess;
        let wasQueued = false;
        if (images.length > 0) {
          console.log(`[ws] Sending message with ${images.length} inline Base64 image(s)`);
          const result = claudeProc.sendInputWithImages(text, images);
          wasQueued = typeof result === "boolean" ? result : isAgentBusySnapshot;
        }
        // Legacy imageId mode (backward compatibility)
        else if (msg.imageId && this.galleryStore) {
          this.send(ws, {
            type: "input_ack",
            sessionId: session.id,
            queued: isAgentBusySnapshot,
          });
          this.galleryStore.getImageAsBase64(msg.imageId).then((imageData) => {
            let queuedAfterResolve = false;
            if (imageData) {
              const result = claudeProc.sendInputWithImages(text, [imageData]);
              queuedAfterResolve = typeof result === "boolean" ? result : isAgentBusySnapshot;
            } else {
              console.warn(`[ws] Image not found: ${msg.imageId}`);
              const result = session.process.sendInput(text);
              queuedAfterResolve = typeof result === "boolean" ? result : isAgentBusySnapshot;
            }
            if (queuedAfterResolve) {
              console.log(`[ws] Agent is busy — will queue input and interrupt current turn`);
              claudeProc.interrupt();
            }
          }).catch((err) => {
            console.error(`[ws] Failed to load image: ${err}`);
            const result = session.process.sendInput(text);
            const queuedAfterResolve = typeof result === "boolean" ? result : isAgentBusySnapshot;
            if (queuedAfterResolve) {
              console.log(`[ws] Agent is busy — will queue input and interrupt current turn`);
              claudeProc.interrupt();
            }
          });
          break;
        }
        // Text-only message
        else {
          const result = session.process.sendInput(text);
          wasQueued = typeof result === "boolean" ? result : isAgentBusySnapshot;
        }

        // Acknowledge receipt so the client can mark the message state.
        // queued=true means the input was enqueued instead of being consumed
        // immediately by the SDK stream.
        this.send(ws, { type: "input_ack", sessionId: session.id, queued: wasQueued });

        if (wasQueued) {
          console.log(`[ws] Agent is busy — will queue input and interrupt current turn`);
          claudeProc.interrupt();
        }
        break;
      }

      case "push_register": {
        const locale = normalizePushLocale(msg.locale);
        const privacyMode = msg.privacyMode === true;
        console.log(`[ws] push_register received (platform: ${msg.platform}, locale: ${locale}, privacy: ${privacyMode}, configured: ${this.pushRelay.isConfigured})`);
        if (!this.pushRelay.isConfigured) {
          this.send(ws, { type: "error", message: "Push relay is not configured on bridge" });
          return;
        }
        this.tokenLocales.set(msg.token, locale);
        this.tokenPrivacyMode.set(msg.token, privacyMode);
        this.pushRelay.registerToken(msg.token, msg.platform, locale).then(() => {
          console.log("[ws] push_register: token registered successfully");
        }).catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
          console.error(`[ws] push_register failed: ${detail}`);
          this.send(ws, { type: "error", message: `Failed to register push token: ${detail}` });
        });
        break;
      }

      case "push_unregister": {
        console.log("[ws] push_unregister received");
        if (!this.pushRelay.isConfigured) {
          this.send(ws, { type: "error", message: "Push relay is not configured on bridge" });
          return;
        }
        this.tokenLocales.delete(msg.token);
        this.tokenPrivacyMode.delete(msg.token);
        this.pushRelay.unregisterToken(msg.token).then(() => {
          console.log("[ws] push_unregister: token unregistered successfully");
        }).catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
          console.error(`[ws] push_unregister failed: ${detail}`);
          this.send(ws, { type: "error", message: `Failed to unregister push token: ${detail}` });
        });
        break;
      }

      case "set_permission_mode": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider === "codex") {
          const codexProcess = session.process as CodexProcess;
          const approval = permissionModeToApprovalPolicy(msg.mode);
          const collaboration = msg.mode === "plan" ? "plan" : "default";
          console.log(`[ws] set_permission_mode(codex): mode=${msg.mode} → approval=${approval}, collaboration=${collaboration}`);
          codexProcess.setApprovalPolicy(approval);
          codexProcess.setCollaborationMode(collaboration);
          break;
        }
        (session.process as SdkProcess).setPermissionMode(msg.mode).catch((err) => {
          this.send(ws, {
            type: "error",
            message: `Failed to set permission mode: ${err instanceof Error ? err.message : String(err)}`,
          });
        });
        break;
      }

      case "set_sandbox_mode": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider !== "codex") {
          this.send(ws, { type: "error", message: "Only Codex sessions support sandbox mode changes" });
          return;
        }
        // Map on/off to internal Codex sandbox modes
        if (msg.sandboxMode !== "on" && msg.sandboxMode !== "off") {
          this.send(ws, { type: "error", message: `Invalid sandbox mode: ${msg.sandboxMode}` });
          return;
        }
        const newSandboxMode = sandboxModeToInternal(msg.sandboxMode);
        const currentSandboxMode = session.codexSettings?.sandboxMode ?? "workspace-write";
        if (newSandboxMode === currentSandboxMode) {
          break; // No change needed
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
        const collaborationMode = (session.process as CodexProcess).collaborationMode;

        this.sessionManager.destroy(oldSessionId);
        console.log(`[ws] Sandbox mode change: destroyed session ${oldSessionId}`);

        const hasMessages = (session.history && session.history.length > 0) || (session.pastMessages && session.pastMessages.length > 0);
        if (!threadId || !hasMessages) {
          // Session has no thread yet, or has a thread but no messages exchanged.
          // Create a fresh session with the new sandbox — no resume needed.
          // (A thread with no messages cannot be resumed — Codex returns
          // "no rollout found for thread id".)
          const newId = this.sessionManager.create(
            projectPath,
            undefined,
            undefined,
            worktreePath ? { existingWorktreePath: worktreePath, worktreeBranch } : undefined,
            "codex",
            {
              approvalPolicy: oldSettings.approvalPolicy as "never" | "on-request" | undefined,
              sandboxMode: newSandboxMode,
              model: oldSettings.model,
              modelReasoningEffort: oldSettings.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh" | undefined,
              networkAccessEnabled: oldSettings.networkAccessEnabled as boolean | undefined,
              webSearchMode: oldSettings.webSearchMode as "disabled" | "cached" | "live" | undefined,
              collaborationMode,
            },
          );
          const newSession = this.sessionManager.get(newId);
          if (newSession && sessionName) newSession.name = sessionName;
          this.broadcast({
            type: "system",
            subtype: "session_created",
            sessionId: newId,
            provider: "codex",
            projectPath,
            sandboxMode: sandboxModeToExternal(newSandboxMode),
            sourceSessionId: oldSessionId,
            ...(newSession?.worktreePath ? { worktreePath: newSession.worktreePath, worktreeBranch: newSession.worktreeBranch } : {}),
          });
          this.broadcastSessionList();
          console.log(`[ws] Sandbox mode change (no thread): created new session ${newId} (sandbox=${newSandboxMode})`);
          break;
        }

        // Worktree resolution (same as resume_session)
        const wtMapping = this.worktreeStore.get(threadId);
        const effectiveProjectPath = wtMapping?.projectPath ?? projectPath;
        let worktreeOpts: { useWorktree?: boolean; worktreeBranch?: string; existingWorktreePath?: string } | undefined;
        if (wtMapping) {
          if (worktreeExists(wtMapping.worktreePath)) {
            worktreeOpts = { existingWorktreePath: wtMapping.worktreePath, worktreeBranch: wtMapping.worktreeBranch };
          } else {
            worktreeOpts = { useWorktree: true, worktreeBranch: wtMapping.worktreeBranch };
          }
        } else if (worktreePath) {
          worktreeOpts = { existingWorktreePath: worktreePath, worktreeBranch };
        }

        getCodexSessionHistory(threadId).then((pastMessages) => {
          const newId = this.sessionManager.create(
            effectiveProjectPath,
            undefined,
            pastMessages,
            worktreeOpts,
            "codex",
            {
              threadId,
              approvalPolicy: oldSettings.approvalPolicy as "never" | "on-request" | undefined,
              sandboxMode: newSandboxMode,
              model: oldSettings.model,
              modelReasoningEffort: oldSettings.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh" | undefined,
              networkAccessEnabled: oldSettings.networkAccessEnabled as boolean | undefined,
              webSearchMode: oldSettings.webSearchMode as "disabled" | "cached" | "live" | undefined,
              collaborationMode,
            },
          );

          // Restore session name
          const newSession = this.sessionManager.get(newId);
          if (newSession && sessionName) {
            newSession.name = sessionName;
          }

          void this.loadAndSetSessionName(newSession, "codex", effectiveProjectPath, threadId).then(() => {
            this.broadcast({
              type: "system",
              subtype: "session_created",
              sessionId: newId,
              provider: "codex",
              projectPath: effectiveProjectPath,
              sandboxMode: sandboxModeToExternal(newSandboxMode),
              sourceSessionId: oldSessionId,
              ...(newSession?.worktreePath ? {
                worktreePath: newSession.worktreePath,
                worktreeBranch: newSession.worktreeBranch,
              } : {}),
            });
            this.broadcastSessionList();
          });

          this.debugEvents.set(newId, []);
          this.recordDebugEvent(newId, {
            direction: "internal" as const,
            channel: "bridge" as const,
            type: "sandbox_mode_changed",
            detail: `sandbox=${newSandboxMode} thread=${threadId} oldSession=${oldSessionId}`,
          });
          console.log(`[ws] Sandbox mode change: created new session ${newId} (thread=${threadId}, sandbox=${newSandboxMode})`);
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to restart session for sandbox mode change: ${err}` });
        });
        break;
      }

      case "approve": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider === "codex") {
          (session.process as CodexProcess).approve(msg.id, msg.updatedInput);
          break;
        }
        const sdkProc = session.process as SdkProcess;
        if (msg.clearContext) {
          // Clear & Accept: immediately destroy this runtime session and
          // create a fresh one that continues the same Claude conversation.
          // This guarantees chat history is cleared in the mobile UI without
          // waiting for additional in-turn tool approvals.
          const pending = sdkProc.getPendingPermission(msg.id);
          const mergedInput = {
            ...(pending?.input ?? {}),
            ...(msg.updatedInput ?? {}),
          };
          const planText = typeof mergedInput.plan === "string" ? mergedInput.plan : "";

          // Use session.id (always present) instead of msg.sessionId.
          const sessionId = session.id;

          // Capture session properties before destroy.
          const claudeSessionId = session.claudeSessionId;
          const projectPath = session.projectPath;
          const permissionMode = sdkProc.permissionMode;
          const worktreePath = session.worktreePath;
          const worktreeBranch = session.worktreeBranch;

          this.sessionManager.destroy(sessionId);
          console.log(`[ws] Clear context: destroyed session ${sessionId}`);

          const newId = this.sessionManager.create(
            projectPath,
            {
              ...(claudeSessionId
                ? {
                    sessionId: claudeSessionId,
                    continueMode: true,
                  }
                : {}),
              permissionMode,
              initialInput: planText || undefined,
            },
            undefined,
            worktreePath ? { existingWorktreePath: worktreePath, worktreeBranch } : undefined,
          );
          console.log(`[ws] Clear context: created new session ${newId} (CLI session: ${claudeSessionId ?? "new"})`);

          // Notify all clients. Broadcast is used so reconnecting clients also receive it.
          const newSession = this.sessionManager.get(newId);
          this.broadcast({
            type: "system",
            subtype: "session_created",
            sessionId: newId,
            provider: newSession?.provider ?? "claude",
            projectPath,
            ...(permissionMode ? { permissionMode } : {}),
            clearContext: true,
            sourceSessionId: sessionId,
          });
          this.broadcastSessionList();
        } else {
          sdkProc.approve(msg.id, msg.updatedInput);
        }
        break;
      }

      case "approve_always": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider === "codex") {
          (session.process as CodexProcess).approveAlways(msg.id);
          break;
        }
        (session.process as SdkProcess).approveAlways(msg.id);
        break;
      }

      case "reject": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider === "codex") {
          (session.process as CodexProcess).reject(msg.id, msg.message);
          break;
        }
        (session.process as SdkProcess).reject(msg.id, msg.message);
        break;
      }

      case "answer": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        if (session.provider === "codex") {
          (session.process as CodexProcess).answer(msg.toolUseId, msg.result);
          break;
        }
        (session.process as SdkProcess).answer(msg.toolUseId, msg.result);
        break;
      }

      case "list_sessions": {
        this.sendSessionList(ws);
        break;
      }

      case "stop_session": {
        const session = this.sessionManager.get(msg.sessionId);
        if (session) {
          // Notify clients before destroying (destroy removes listeners)
          this.broadcastSessionMessage(msg.sessionId, {
            type: "result",
            subtype: "stopped",
            sessionId: session.claudeSessionId,
          });
          this.sessionManager.destroy(msg.sessionId);
          this.recordDebugEvent(msg.sessionId, {
            direction: "internal",
            channel: "bridge",
            type: "session_stopped",
          });
          this.debugEvents.delete(msg.sessionId);
          this.notifiedPermissionToolUses.delete(msg.sessionId);
          this.sendSessionList(ws);
        } else {
          this.send(ws, { type: "error", message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case "get_history": {
        const session = this.sessionManager.get(msg.sessionId);
        if (session) {
          // Send past conversation from disk (resume) before in-memory history
          if (session.pastMessages && session.pastMessages.length > 0) {
            this.send(ws, {
              type: "past_history",
              claudeSessionId: session.claudeSessionId ?? msg.sessionId,
              sessionId: msg.sessionId,
              messages: session.pastMessages,
            } as Record<string, unknown>);
          }
          this.send(ws, { type: "history", messages: session.history, sessionId: msg.sessionId } as Record<string, unknown>);
          this.send(ws, { type: "status", status: session.status, sessionId: msg.sessionId } as Record<string, unknown>);
        } else {
          this.send(ws, { type: "error", message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case "get_debug_bundle": {
        const session = this.sessionManager.get(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: `Session ${msg.sessionId} not found` });
          return;
        }

        const emitBundle = (diff: string, diffError?: string): void => {
          const traceLimit = msg.traceLimit ?? BridgeWebSocketServer.MAX_DEBUG_EVENTS;
          const trace = this.getDebugEvents(msg.sessionId, traceLimit);
          const generatedAt = new Date().toISOString();
          const includeDiff = msg.includeDiff !== false;
          const bundlePayload: Record<string, unknown> = {
            type: "debug_bundle",
            sessionId: msg.sessionId,
            generatedAt,
            session: {
              id: session.id,
              provider: session.provider,
              status: session.status,
              projectPath: session.projectPath,
              worktreePath: session.worktreePath,
              worktreeBranch: session.worktreeBranch,
              claudeSessionId: session.claudeSessionId,
              createdAt: session.createdAt.toISOString(),
              lastActivityAt: session.lastActivityAt.toISOString(),
            },
            pastMessageCount: session.pastMessages?.length ?? 0,
            historySummary: this.buildHistorySummary(session.history),
            debugTrace: trace,
            traceFilePath: this.debugTraceStore.getTraceFilePath(msg.sessionId),
            reproRecipe: this.buildReproRecipe(
              session,
              traceLimit,
              includeDiff,
            ),
            agentPrompt: this.buildAgentPrompt(session),
            diff,
            diffError,
          };
          const savedBundlePath = this.debugTraceStore.getBundleFilePath(
            msg.sessionId,
            generatedAt,
          );
          bundlePayload.savedBundlePath = savedBundlePath;
          this.debugTraceStore.saveBundleAtPath(savedBundlePath, bundlePayload);
          this.send(ws, bundlePayload);
        };

        if (msg.includeDiff === false) {
          emitBundle("");
          break;
        }

        const cwd = session.worktreePath ?? session.projectPath;
        this.collectGitDiff(cwd, ({ diff, error }) => {
          emitBundle(diff, error);
        });
        break;
      }

      case "get_usage": {
        fetchAllUsage().then((providers) => {
          this.send(ws, { type: "usage_result", providers } as Record<string, unknown>);
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to fetch usage: ${err}` });
        });
        break;
      }

      case "list_recent_sessions": {
        const requestId = ++this.recentSessionsRequestId;
        getAllRecentSessions({
          limit: msg.limit,
          offset: msg.offset,
          projectPath: msg.projectPath,
          provider: msg.provider,
          namedOnly: msg.namedOnly,
          searchQuery: msg.searchQuery,
          archivedSessionIds: this.archiveStore.archivedIds(),
        }).then(({ sessions, hasMore }) => {
          // Drop stale responses when rapid filter switches cause out-of-order completion
          if (requestId !== this.recentSessionsRequestId) return;
          this.send(ws, { type: "recent_sessions", sessions, hasMore } as Record<string, unknown>);
        }).catch((err) => {
          if (requestId !== this.recentSessionsRequestId) return;
          this.send(ws, { type: "error", message: `Failed to list recent sessions: ${err}` });
        });
        break;
      }

      case "archive_session": {
        const { sessionId, provider, projectPath } = msg;
        this.archiveStore.archive(sessionId, provider, projectPath).then(() => {
          // For Codex sessions, also call thread/archive RPC (best-effort).
          // Requires a running Codex app-server process; skip if none active.
          if (provider === "codex") {
            const activeSessions = this.sessionManager.list();
            const codexSession = activeSessions.find((s) => s.provider === "codex");
            if (codexSession) {
              const session = this.sessionManager.get(codexSession.id);
              if (session) {
                (session.process as CodexProcess).archiveThread(sessionId).catch((err) => {
                  console.warn(`[ws] Codex thread/archive failed (non-fatal): ${err}`);
                });
              }
            }
          }
          this.send(ws, {
            type: "archive_result",
            sessionId,
            success: true,
          } as Record<string, unknown>);
        }).catch((err) => {
          this.send(ws, {
            type: "archive_result",
            sessionId,
            success: false,
            error: String(err),
          } as Record<string, unknown>);
        });
        break;
      }

      case "resume_session": {
        const provider = msg.provider ?? "claude";
        const sessionRefId = msg.sessionId;
        // Resume flow: keep past history in SessionInfo and deliver it only
        // via get_history(sessionId) to avoid duplicate/missed replay races.
        if (provider === "codex") {
          const wtMapping = this.worktreeStore.get(sessionRefId);
          const effectiveProjectPath = wtMapping?.projectPath ?? msg.projectPath;
          let worktreeOpts: { useWorktree?: boolean; worktreeBranch?: string; existingWorktreePath?: string } | undefined;
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

          getCodexSessionHistory(sessionRefId).then((pastMessages) => {
            const sessionId = this.sessionManager.create(
              effectiveProjectPath,
              undefined,
              pastMessages,
              worktreeOpts,
              "codex",
              {
                threadId: sessionRefId,
                approvalPolicy: permissionModeToApprovalPolicy(msg.permissionMode),
                sandboxMode: sandboxModeToInternal(msg.sandboxMode),
                model: msg.model,
                modelReasoningEffort: (msg.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh") ?? undefined,
                networkAccessEnabled: msg.networkAccessEnabled,
                webSearchMode: (msg.webSearchMode as "disabled" | "cached" | "live") ?? undefined,
                collaborationMode: msg.permissionMode === "plan" ? "plan" as const : "default" as const,
              },
            );
            const createdSession = this.sessionManager.get(sessionId);
            void this.loadAndSetSessionName(createdSession, "codex", effectiveProjectPath, sessionRefId).then(() => {
              this.send(ws, {
                type: "system",
                subtype: "session_created",
                sessionId,
                provider: "codex",
                projectPath: effectiveProjectPath,
                ...(createdSession?.codexSettings?.sandboxMode ? { sandboxMode: sandboxModeToExternal(createdSession.codexSettings.sandboxMode) } : {}),
                ...(createdSession?.worktreePath ? {
                  worktreePath: createdSession.worktreePath,
                  worktreeBranch: createdSession.worktreeBranch,
                } : {}),
              });
              this.broadcastSessionList();
            });
            this.debugEvents.set(sessionId, []);
            this.recordDebugEvent(sessionId, {
              direction: "internal",
              channel: "bridge",
              type: "session_resumed",
              detail: `provider=codex thread=${sessionRefId}`,
            });
            this.projectHistory?.addProject(effectiveProjectPath);
          }).catch((err) => {
            this.send(ws, { type: "error", message: `Failed to load Codex session history: ${err}` });
          });
          break;
        }

        const claudeSessionId = sessionRefId;
        const cached = this.sessionManager.getCachedCommands(msg.projectPath);

        // Look up worktree mapping for this Claude session
        const wtMapping = this.worktreeStore.get(claudeSessionId);
        let worktreeOpts: { useWorktree?: boolean; worktreeBranch?: string; existingWorktreePath?: string } | undefined;
        if (wtMapping) {
          if (worktreeExists(wtMapping.worktreePath)) {
            // Worktree exists — reuse it directly
            worktreeOpts = {
              existingWorktreePath: wtMapping.worktreePath,
              worktreeBranch: wtMapping.worktreeBranch,
            };
          } else {
            // Worktree was deleted — recreate on the same branch
            worktreeOpts = { useWorktree: true, worktreeBranch: wtMapping.worktreeBranch };
          }
        }

        getSessionHistory(claudeSessionId).then((pastMessages) => {
          const sessionId = this.sessionManager.create(
            msg.projectPath,
            {
              sessionId: claudeSessionId,
              permissionMode: msg.permissionMode,
              model: msg.model,
              effort: msg.effort,
              maxTurns: msg.maxTurns,
              maxBudgetUsd: msg.maxBudgetUsd,
              fallbackModel: msg.fallbackModel,
              forkSession: msg.forkSession,
              persistSession: msg.persistSession,
            },
            pastMessages,
            worktreeOpts,
          );
          const createdSession = this.sessionManager.get(sessionId);
          void this.loadAndSetSessionName(createdSession, "claude", msg.projectPath, claudeSessionId).then(() => {
            this.send(ws, {
              type: "system",
              subtype: "session_created",
              sessionId,
              claudeSessionId,
              provider: "claude",
              projectPath: msg.projectPath,
              ...(msg.permissionMode ? { permissionMode: msg.permissionMode } : {}),
              ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
              ...(createdSession?.worktreePath ? {
                worktreePath: createdSession.worktreePath,
                worktreeBranch: createdSession.worktreeBranch,
              } : {}),
            });
            this.broadcastSessionList();
          });
          this.debugEvents.set(sessionId, []);
          this.recordDebugEvent(sessionId, {
            direction: "internal",
            channel: "bridge",
            type: "session_resumed",
            detail: `provider=claude session=${claudeSessionId}`,
          });
          this.projectHistory?.addProject(msg.projectPath);
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to load session history: ${err}` });
        });
        break;
      }

      case "list_gallery": {
        if (this.galleryStore) {
          const images = this.galleryStore.list({
            projectPath: msg.project,
            sessionId: msg.sessionId,
          });
          this.send(ws, { type: "gallery_list", images } as Record<string, unknown>);
        } else {
          this.send(ws, { type: "gallery_list", images: [] } as Record<string, unknown>);
        }
        break;
      }

      case "get_message_images": {
        void extractMessageImages(msg.claudeSessionId, msg.messageUuid).then((images) => {
          const refs: Array<{ id: string; url: string; mimeType: string }> = [];
          if (this.imageStore) {
            for (const img of images) {
              const ref = this.imageStore.registerFromBase64(img.base64, img.mimeType);
              if (ref) refs.push(ref);
            }
          }
          this.send(ws, { type: "message_images_result", messageUuid: msg.messageUuid, images: refs });
        }).catch((err) => {
          console.error("[ws] Failed to extract message images:", err);
          this.send(ws, { type: "message_images_result", messageUuid: msg.messageUuid, images: [] });
        });
        break;
      }

      case "interrupt": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        session.process.interrupt();
        break;
      }

      case "list_project_history": {
        const projects = this.projectHistory?.getProjects() ?? [];
        this.send(ws, { type: "project_history", projects });
        break;
      }

      case "remove_project_history": {
        this.projectHistory?.removeProject(msg.projectPath);
        const projects = this.projectHistory?.getProjects() ?? [];
        this.send(ws, { type: "project_history", projects });
        break;
      }

      case "list_files": {
        execFile("git", ["ls-files"], { cwd: msg.projectPath, maxBuffer: 10 * 1024 * 1024 }, (err, stdout) => {
          if (err) {
            this.send(ws, { type: "error", message: `Failed to list files: ${err.message}` });
            return;
          }
          const files = stdout.trim().split("\n").filter(Boolean);
          this.send(ws, { type: "file_list", files } as Record<string, unknown>);
        });
        break;
      }

      case "list_recordings": {
        void this.recordingStore.listRecordings().then(async (recordings) => {
          // First pass: extract info from JSONL for recordings missing firstPrompt
          // This covers both meta-less legacy recordings and new ones where sessions-index hasn't indexed yet
          await Promise.all(
            recordings.map(async (rec) => {
              const info = await this.recordingStore.extractInfoFromJsonl(rec.name);
              if (info.firstPrompt && !rec.firstPrompt) rec.firstPrompt = info.firstPrompt;
              if (info.lastPrompt && !rec.lastPrompt) rec.lastPrompt = info.lastPrompt;
              // Backfill meta for legacy recordings
              if (!rec.meta && (info.claudeSessionId || info.projectPath)) {
                rec.meta = {
                  bridgeSessionId: rec.name,
                  claudeSessionId: info.claudeSessionId,
                  projectPath: info.projectPath ?? "",
                  createdAt: rec.modified,
                };
              }
            }),
          );

          // Second pass: look up sessions-index for summaries (if claudeSessionIds available)
          const claudeIds = new Set<string>();
          const idToIdx = new Map<string, number[]>();
          for (let i = 0; i < recordings.length; i++) {
            const cid = recordings[i].meta?.claudeSessionId;
            if (cid) {
              claudeIds.add(cid);
              const arr = idToIdx.get(cid) ?? [];
              arr.push(i);
              idToIdx.set(cid, arr);
            }
          }

          if (claudeIds.size > 0) {
            const sessionInfo = await findSessionsByClaudeIds(claudeIds);
            for (const [cid, info] of sessionInfo) {
              const indices = idToIdx.get(cid) ?? [];
              for (const idx of indices) {
                if (info.summary) recordings[idx].summary = info.summary;
                if (info.firstPrompt) recordings[idx].firstPrompt = info.firstPrompt;
                if (info.lastPrompt) recordings[idx].lastPrompt = info.lastPrompt;
              }
            }
          }

          this.send(ws, { type: "recording_list", recordings } as Record<string, unknown>);
        });
        break;
      }

      case "get_recording": {
        void this.recordingStore.getRecordingContent(msg.sessionId).then((content) => {
          if (content !== null) {
            this.send(ws, { type: "recording_content", sessionId: msg.sessionId, content } as Record<string, unknown>);
          } else {
            this.send(ws, { type: "error", message: `Recording ${msg.sessionId} not found` });
          }
        });
        break;
      }

      case "get_diff": {
        this.collectGitDiff(msg.projectPath, ({ diff, error }) => {
          if (error) {
            this.send(ws, { type: "diff_result", diff: "", error: `Failed to get diff: ${error}` });
            return;
          }
          void this.collectImageChanges(msg.projectPath, diff).then((imageChanges) => {
            if (imageChanges.length > 0) {
              this.send(ws, { type: "diff_result", diff, imageChanges });
            } else {
              this.send(ws, { type: "diff_result", diff });
            }
          });
        });
        break;
      }

      case "get_diff_image": {
        if (msg.version === "both") {
          void (async () => {
            try {
              const [oldResult, newResult] = await Promise.all([
                this.loadDiffImageAsync(msg.projectPath, msg.filePath, "old"),
                this.loadDiffImageAsync(msg.projectPath, msg.filePath, "new"),
              ]);
              const errors = [oldResult.error, newResult.error].filter(Boolean);
              this.send(ws, {
                type: "diff_image_result",
                filePath: msg.filePath,
                version: "both" as const,
                oldBase64: oldResult.base64,
                newBase64: newResult.base64,
                mimeType: oldResult.mimeType ?? newResult.mimeType,
                ...(errors.length > 0 ? { error: errors.join("; ") } : {}),
              });
            } catch {
              // WebSocket may have closed; ignore send errors.
            }
          })();
        } else {
          const version = msg.version as "old" | "new";
          void (async () => {
            try {
              const result = await this.loadDiffImageAsync(msg.projectPath, msg.filePath, version);
              this.send(ws, { type: "diff_image_result", filePath: msg.filePath, version, ...result });
            } catch {
              // WebSocket may have closed; ignore send errors.
            }
          })();
        }
        break;
      }

      case "list_worktrees": {
        try {
          const worktrees = listWorktrees(msg.projectPath);
          const mainBranch = getMainBranch(msg.projectPath);
          this.send(ws, { type: "worktree_list", worktrees, mainBranch });
        } catch (err) {
          this.send(ws, { type: "error", message: `Failed to list worktrees: ${err}` });
        }
        break;
      }

      case "remove_worktree": {
        try {
          removeWorktree(msg.projectPath, msg.worktreePath);
          this.worktreeStore.deleteByWorktreePath(msg.worktreePath);
          this.send(ws, { type: "worktree_removed", worktreePath: msg.worktreePath });
        } catch (err) {
          this.send(ws, { type: "error", message: `Failed to remove worktree: ${err}` });
        }
        break;
      }

      case "rewind_dry_run": {
        const session = this.sessionManager.get(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "rewind_preview", canRewind: false, error: `Session ${msg.sessionId} not found` });
          return;
        }
        this.sessionManager.rewindFiles(msg.sessionId, msg.targetUuid, true).then((result) => {
          this.send(ws, {
            type: "rewind_preview",
            canRewind: result.canRewind,
            filesChanged: result.filesChanged,
            insertions: result.insertions,
            deletions: result.deletions,
            error: result.error,
          });
        }).catch((err) => {
          this.send(ws, { type: "rewind_preview", canRewind: false, error: `Dry run failed: ${err}` });
        });
        break;
      }

      case "rewind": {
        const session = this.sessionManager.get(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "rewind_result", success: false, mode: msg.mode, error: `Session ${msg.sessionId} not found` });
          return;
        }

        const handleError = (err: unknown) => {
          const errMsg = err instanceof Error ? err.message : String(err);
          this.send(ws, { type: "rewind_result", success: false, mode: msg.mode, error: errMsg });
        };

        if (msg.mode === "code") {
          // Code-only rewind: rewind files without restarting the conversation
          this.sessionManager.rewindFiles(msg.sessionId, msg.targetUuid).then((result) => {
            if (result.canRewind) {
              this.send(ws, { type: "rewind_result", success: true, mode: "code" });
            } else {
              this.send(ws, { type: "rewind_result", success: false, mode: "code", error: result.error ?? "Cannot rewind files" });
            }
          }).catch(handleError);
        } else if (msg.mode === "conversation") {
          // Conversation-only rewind: restart session at the target UUID
          try {
            this.sessionManager.rewindConversation(msg.sessionId, msg.targetUuid, (newSessionId) => {
              this.send(ws, { type: "rewind_result", success: true, mode: "conversation" });
              // Notify the new session ID
              const newSession = this.sessionManager.get(newSessionId);
              const rewindPermMode = newSession?.process instanceof SdkProcess ? newSession.process.permissionMode : undefined;
              this.send(ws, {
                type: "system",
                subtype: "session_created",
                sessionId: newSessionId,
                provider: newSession?.provider ?? "claude",
                projectPath: newSession?.projectPath ?? "",
                ...(rewindPermMode ? { permissionMode: rewindPermMode } : {}),
              });
              this.sendSessionList(ws);
            });
          } catch (err) {
            handleError(err);
          }
        } else {
          // Both: rewind files first, then rewind conversation
          this.sessionManager.rewindFiles(msg.sessionId, msg.targetUuid).then((result) => {
            if (!result.canRewind) {
              this.send(ws, { type: "rewind_result", success: false, mode: "both", error: result.error ?? "Cannot rewind files" });
              return;
            }
            try {
              this.sessionManager.rewindConversation(msg.sessionId, msg.targetUuid, (newSessionId) => {
                this.send(ws, { type: "rewind_result", success: true, mode: "both" });
                const newSession = this.sessionManager.get(newSessionId);
                const rewindPermMode2 = newSession?.process instanceof SdkProcess ? newSession.process.permissionMode : undefined;
                this.send(ws, {
                  type: "system",
                  subtype: "session_created",
                  sessionId: newSessionId,
                  provider: newSession?.provider ?? "claude",
                  projectPath: newSession?.projectPath ?? "",
                  ...(rewindPermMode2 ? { permissionMode: rewindPermMode2 } : {}),
                });
                this.sendSessionList(ws);
              });
            } catch (err) {
              handleError(err);
            }
          }).catch(handleError);
        }
        break;
      }

      case "list_windows": {
        listWindows()
          .then((windows) => {
            this.send(ws, { type: "window_list", windows });
          })
          .catch((err) => {
            this.send(ws, {
              type: "error",
              message: `Failed to list windows: ${err instanceof Error ? err.message : String(err)}`,
            });
          });
        break;
      }

      case "take_screenshot": {
        // For window mode, verify the window ID is still valid.
        // The user may have fetched the window list minutes ago and the
        // window could have been closed since then.
        const doCapture = async (): Promise<{ mode: "fullscreen" | "window"; windowId?: number }> => {
          if (msg.mode !== "window" || msg.windowId == null) {
            return { mode: msg.mode };
          }
          const current = await listWindows();
          if (current.some((w) => w.windowId === msg.windowId)) {
            return { mode: "window", windowId: msg.windowId };
          }
          // Window ID is stale — fall back to fullscreen and notify
          console.warn(
            `[screenshot] Window ID ${msg.windowId} no longer exists, falling back to fullscreen`,
          );
          return { mode: "fullscreen" };
        };
        doCapture()
          .then((opts) => takeScreenshot(opts))
          .then(async (result) => {
            try {
              if (this.galleryStore) {
                const meta = await this.galleryStore.addImage(
                  result.filePath,
                  msg.projectPath,
                  msg.sessionId,
                );
                if (meta) {
                  const info = this.galleryStore.metaToInfo(meta);
                  this.send(ws, { type: "screenshot_result", success: true, image: info });
                  this.broadcast({ type: "gallery_new_image", image: info });
                  return;
                }
              }
              this.send(ws, {
                type: "screenshot_result",
                success: false,
                error: "Failed to save screenshot to gallery",
              });
            } finally {
              // Always clean up temp file
              unlink(result.filePath).catch(() => {});
            }
          })
          .catch((err) => {
            this.send(ws, {
              type: "screenshot_result",
              success: false,
              error: err instanceof Error ? err.message : String(err),
            });
          });
        break;
      }

      case "backup_prompt_history": {
        if (!this.promptHistoryBackup) {
          this.send(ws, { type: "prompt_history_backup_result", success: false, error: "Backup store not available" });
          break;
        }
        const buf = Buffer.from(msg.data, "base64");
        this.promptHistoryBackup.save(buf, msg.appVersion, msg.dbVersion).then((meta) => {
          this.send(ws, { type: "prompt_history_backup_result", success: true, backedUpAt: meta.backedUpAt });
        }).catch((err) => {
          this.send(ws, { type: "prompt_history_backup_result", success: false, error: err instanceof Error ? err.message : String(err) });
        });
        break;
      }

      case "restore_prompt_history": {
        if (!this.promptHistoryBackup) {
          this.send(ws, { type: "prompt_history_restore_result", success: false, error: "Backup store not available" });
          break;
        }
        this.promptHistoryBackup.load().then((result) => {
          if (result) {
            this.send(ws, {
              type: "prompt_history_restore_result",
              success: true,
              data: result.data.toString("base64"),
              appVersion: result.meta.appVersion,
              dbVersion: result.meta.dbVersion,
              backedUpAt: result.meta.backedUpAt,
            });
          } else {
            this.send(ws, { type: "prompt_history_restore_result", success: false, error: "No backup found" });
          }
        }).catch((err) => {
          this.send(ws, { type: "prompt_history_restore_result", success: false, error: err instanceof Error ? err.message : String(err) });
        });
        break;
      }

      case "get_prompt_history_backup_info": {
        if (!this.promptHistoryBackup) {
          this.send(ws, { type: "prompt_history_backup_info", exists: false });
          break;
        }
        this.promptHistoryBackup.getMeta().then((meta) => {
          if (meta) {
            this.send(ws, { type: "prompt_history_backup_info", exists: true, ...meta });
          } else {
            this.send(ws, { type: "prompt_history_backup_info", exists: false });
          }
        }).catch(() => {
          this.send(ws, { type: "prompt_history_backup_info", exists: false });
        });
        break;
      }

      case "rename_session": {
        const name = (msg.name as string | null) || null;
        this.handleRenameSession(ws, msg.sessionId, name, msg);
        break;
      }
    }
  }

  /**
   * Load the saved session name from CLI storage and set it on the SessionInfo.
   * Called after SessionManager.create() so that session_created carries the name.
   */
  private async loadAndSetSessionName(
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

  /**
   * Handle rename_session: update in-memory name and persist to CLI storage.
   *
   * Supports both running sessions (by bridge session id) and recent sessions
   * (by provider session id, i.e. claudeSessionId or codex threadId).
   */
  private async handleRenameSession(
    ws: WebSocket,
    sessionId: string,
    name: string | null,
    msg: ClientMessage,
  ): Promise<void> {
    // 1. Try running session first
    const runningSession = this.sessionManager.get(sessionId);
    if (runningSession) {
      this.sessionManager.renameSession(sessionId, name);

      // Persist to provider storage
      if (runningSession.provider === "claude" && runningSession.claudeSessionId) {
        await renameClaudeSession(
          runningSession.worktreePath ?? runningSession.projectPath,
          runningSession.claudeSessionId,
          name,
        );
      } else if (runningSession.provider === "codex" && runningSession.process) {
        try {
          await (runningSession.process as import("./codex-process.js").CodexProcess).renameThread(name ?? "");
        } catch (err) {
          console.warn(`[websocket] Failed to rename Codex thread:`, err);
        }
      }

      this.broadcastSessionList();
      this.send(ws, { type: "rename_result", sessionId, name, success: true });
      return;
    }

    // 2. Recent session (not running) — use provider + providerSessionId + projectPath from message
    const renameMsg = msg as Extract<ClientMessage, { type: "rename_session" }>;
    const provider = renameMsg.provider;
    const providerSessionId = renameMsg.providerSessionId;
    const projectPath = renameMsg.projectPath;

    if (provider === "claude" && providerSessionId && projectPath) {
      const success = await renameClaudeSession(projectPath, providerSessionId, name);
      this.send(ws, { type: "rename_result", sessionId, name, success });
      return;
    }

    // For Codex recent sessions, write directly to session_index.jsonl.
    if (provider === "codex" && providerSessionId) {
      const success = await renameCodexSession(providerSessionId, name);
      this.send(ws, { type: "rename_result", sessionId, name, success });
      return;
    }

    this.send(ws, { type: "rename_result", sessionId, name, success: false });
  }

  private resolveSession(sessionId: string | undefined): SessionInfo | undefined {
    if (sessionId) return this.sessionManager.get(sessionId);
    return this.getFirstSession();
  }

  private getFirstSession() {
    const sessions = this.sessionManager.list();
    if (sessions.length === 0) return undefined;
    return this.sessionManager.get(sessions[sessions.length - 1].id);
  }

  private sendSessionList(ws: WebSocket): void {
    this.pruneDebugEvents();
    const sessions = this.sessionManager.list();
    this.send(ws, { type: "session_list", sessions });
  }

  /** Broadcast session list to all connected clients. */
  private broadcastSessionList(): void {
    this.pruneDebugEvents();
    const sessions = this.sessionManager.list();
    this.broadcast({ type: "session_list", sessions });
  }

  private broadcastSessionMessage(sessionId: string, msg: ServerMessage): void {
    this.maybeSendPushNotification(sessionId, msg);
    this.recordDebugEvent(sessionId, {
      direction: "outgoing",
      channel: "session",
      type: msg.type,
      detail: this.summarizeServerMessage(msg),
    });
    this.recordingStore.record(sessionId, "outgoing", msg);

    // Update recording meta with claudeSessionId when it becomes available
    if ((msg.type === "system" || msg.type === "result") && "sessionId" in msg && msg.sessionId) {
      const session = this.sessionManager.get(sessionId);
      if (session) {
        this.recordingStore.saveMeta(sessionId, {
          bridgeSessionId: sessionId,
          claudeSessionId: msg.sessionId as string,
          projectPath: session.projectPath,
          createdAt: session.createdAt.toISOString(),
        });
      }
    }
    // Wrap the message with sessionId
    const data = JSON.stringify({ ...msg, sessionId });
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  /** Extract a short project label from the full projectPath (last directory name). */
  private projectLabel(sessionId: string): string {
    const session = this.sessionManager.get(sessionId);
    if (!session?.projectPath) return "";
    const parts = session.projectPath.replace(/\/+$/, "").split("/");
    return parts[parts.length - 1] || "";
  }

  /** Get unique locales from registered tokens. Falls back to ["en"] if none registered. */
  private getRegisteredLocales(): PushLocale[] {
    const locales = new Set(this.tokenLocales.values());
    return locales.size > 0 ? [...locales] : ["en"];
  }

  /** Whether any registered token has privacy mode enabled (conservative: privacy wins). */
  private isPrivacyMode(): boolean {
    for (const privacy of this.tokenPrivacyMode.values()) {
      if (privacy) return true;
    }
    return false;
  }

  /** Get a display label for push notification title: "name (project)" or just project. */
  private sessionLabel(sessionId: string): string {
    const session = this.sessionManager.get(sessionId);
    const project = this.projectLabel(sessionId);
    if (session?.name) {
      return project ? `${session.name} (${project})` : session.name;
    }
    return project;
  }

  private maybeSendPushNotification(sessionId: string, msg: ServerMessage): void {
    if (!this.pushRelay.isConfigured) return;

    const privacy = this.isPrivacyMode();
    const label = privacy ? "" : this.sessionLabel(sessionId);

    if (msg.type === "permission_request") {
      const seen = this.notifiedPermissionToolUses.get(sessionId) ?? new Set<string>();
      if (seen.has(msg.toolUseId)) return;
      seen.add(msg.toolUseId);
      this.notifiedPermissionToolUses.set(sessionId, seen);

      const isAskUserQuestion = msg.toolName === "AskUserQuestion";
      const isExitPlanMode = msg.toolName === "ExitPlanMode";
      const eventType = isAskUserQuestion ? "ask_user_question" : "approval_required";

      // Extract question text for AskUserQuestion (standard mode only)
      let questionText: string | undefined;
      if (!privacy && isAskUserQuestion) {
        const questions = msg.input?.questions;
        const firstQuestion = Array.isArray(questions) && questions.length > 0
          ? (questions[0] as Record<string, unknown>)?.question
          : undefined;
        if (typeof firstQuestion === "string" && firstQuestion.length > 0) {
          questionText = firstQuestion.slice(0, 120);
        }
      }

      const data: Record<string, string> = {
        sessionId,
        provider: this.sessionManager.get(sessionId)?.provider ?? "claude",
        toolUseId: msg.toolUseId,
        toolName: msg.toolName,
      };

      for (const locale of this.getRegisteredLocales()) {
        let title: string;
        let body: string;

        if (isExitPlanMode) {
          const titleKey = "plan_ready_title";
          title = label ? `${t(locale, titleKey)} - ${label}` : t(locale, titleKey);
          body = t(locale, "plan_ready_body");
        } else if (isAskUserQuestion) {
          const titleKey = "ask_title";
          title = label ? `${t(locale, titleKey)} - ${label}` : t(locale, titleKey);
          body = privacy
            ? t(locale, "ask_body_private")
            : (questionText ?? t(locale, "ask_default_body"));
        } else {
          const titleKey = "approval_title";
          title = label ? `${t(locale, titleKey)} - ${label}` : t(locale, titleKey);
          body = privacy
            ? t(locale, "approval_body_private")
            : t(locale, "approval_body", { toolName: msg.toolName });
        }

        void this.pushRelay.notify({
          eventType,
          title,
          body,
          locale,
          data,
        }).catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
          console.warn(`[ws] Failed to send push notification (${eventType}, ${locale}): ${detail}`);
        });
      }
      return;
    }

    if (msg.type !== "result") return;
    if (msg.subtype === "stopped") return;
    if (msg.subtype !== "success" && msg.subtype !== "error") return;

    const isSuccess = msg.subtype === "success";
    const eventType = isSuccess ? "session_completed" : "session_failed";

    const pieces: string[] = [];
    if (isSuccess) {
      if (msg.duration != null) pieces.push(`${msg.duration.toFixed(1)}s`);
      if (msg.cost != null) pieces.push(`$${msg.cost.toFixed(4)}`);
    }
    const stats = pieces.length > 0 ? ` (${pieces.join(", ")})` : "";

    const data: Record<string, string> = {
      sessionId,
      provider: this.sessionManager.get(sessionId)?.provider ?? "claude",
      subtype: msg.subtype,
    };
    if (msg.stopReason) data.stopReason = msg.stopReason;
    if (msg.sessionId) data.providerSessionId = msg.sessionId;

    for (const locale of this.getRegisteredLocales()) {
      let title: string;
      if (privacy) {
        title = isSuccess ? t(locale, "task_completed") : t(locale, "error_occurred");
      } else {
        title = label
          ? (isSuccess ? `✅ ${label}` : `❌ ${label}`)
          : (isSuccess ? t(locale, "task_completed") : t(locale, "error_occurred"));
      }

      let body: string;
      if (privacy) {
        const privateBody = isSuccess
          ? t(locale, "result_success_body_private")
          : t(locale, "result_error_body_private");
        body = isSuccess ? `${privateBody}${stats}` : privateBody;
      } else if (isSuccess) {
        body = msg.result
          ? `${msg.result.slice(0, 120)}${stats}`
          : `${t(locale, "session_completed")}${stats}`;
      } else {
        body = msg.error ? msg.error.slice(0, 120) : t(locale, "session_failed");
      }

      void this.pushRelay.notify({
        eventType,
        title,
        body,
        locale,
        data,
      }).catch((err) => {
        const detail = err instanceof Error ? err.message : String(err);
        console.warn(`[ws] Failed to send push notification (${eventType}, ${locale}): ${detail}`);
      });
    }
  }

  private broadcast(msg: Record<string, unknown>): void {
    const data = JSON.stringify(msg);
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  private send(ws: WebSocket, msg: ServerMessage | Record<string, unknown>): void {
    const sessionId = this.extractSessionIdFromServerMessage(msg);
    if (sessionId) {
      this.recordDebugEvent(sessionId, {
        direction: "outgoing",
        channel: "ws",
        type: String(msg.type ?? "unknown"),
        detail: this.summarizeOutboundMessage(msg),
      });
    }
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(msg));
    }
  }

  /** Broadcast a gallery_new_image message to all connected clients. */
  broadcastGalleryNewImage(image: import("./gallery-store.js").GalleryImageInfo): void {
    this.broadcast({ type: "gallery_new_image", image });
  }

  private collectGitDiff(
    cwd: string,
    callback: (result: { diff: string; error?: string }) => void,
  ): void {
    const execOpts = { cwd, maxBuffer: 10 * 1024 * 1024 };

    // Collect untracked files so they appear in the diff.
    let untrackedFiles: string[] = [];
    try {
      const out = execFileSync("git", ["ls-files", "--others", "--exclude-standard"], { cwd }).toString().trim();
      untrackedFiles = out ? out.split("\n") : [];
    } catch {
      // Ignore errors: non-git directories are handled by git diff callback.
    }

    // Temporarily stage untracked files with --intent-to-add.
    if (untrackedFiles.length > 0) {
      try {
        execFileSync("git", ["add", "--intent-to-add", ...untrackedFiles], { cwd });
      } catch {
        // Ignore staging errors.
      }
    }

    execFile("git", ["diff", "--no-color"], execOpts, (err, stdout) => {
      // Revert intent-to-add for untracked files.
      if (untrackedFiles.length > 0) {
        try {
          execFileSync("git", ["reset", "--", ...untrackedFiles], { cwd });
        } catch {
          // Ignore reset errors.
        }
      }

      if (err) {
        callback({ diff: "", error: err.message });
        return;
      }
      callback({ diff: stdout });
    });
  }

  // ---------------------------------------------------------------------------
  // Image diff helpers
  // ---------------------------------------------------------------------------

  private static readonly IMAGE_EXTENSIONS = new Set([
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".bmp", ".svg",
  ]);

  // Image diff thresholds (configurable via environment variables)
  // - Auto-display: images ≤ threshold are sent inline as base64
  // - Max size: images ≤ max are available for on-demand loading
  // - Images > max size show text info only
  private static readonly AUTO_DISPLAY_THRESHOLD = (() => {
    const kb = parseInt(process.env.DIFF_IMAGE_AUTO_DISPLAY_KB ?? "", 10);
    return Number.isFinite(kb) && kb > 0 ? kb * 1024 : 1024 * 1024; // default 1 MB
  })();
  private static readonly MAX_IMAGE_SIZE = (() => {
    const mb = parseInt(process.env.DIFF_IMAGE_MAX_SIZE_MB ?? "", 10);
    return Number.isFinite(mb) && mb > 0 ? mb * 1024 * 1024 : 5 * 1024 * 1024; // default 5 MB
  })();

  private static mimeTypeForExt(ext: string): string {
    const map: Record<string, string> = {
      ".png": "image/png",
      ".jpg": "image/jpeg",
      ".jpeg": "image/jpeg",
      ".gif": "image/gif",
      ".webp": "image/webp",
      ".ico": "image/x-icon",
      ".bmp": "image/bmp",
      ".svg": "image/svg+xml",
    };
    return map[ext.toLowerCase()] ?? "application/octet-stream";
  }

  /**
   * Scan diff text for image file changes and extract base64 data where appropriate.
   *
   * Detection strategy:
   * 1. Binary markers: "Binary files a/<path> and b/<path> differ"
   * 2. diff --git headers where the file extension is an image type
   *
   * For each detected image file:
   * - Old version: `git show HEAD:<path>` (committed version)
   * - New version: read from working tree
   * - Apply size thresholds for auto-display / on-demand / text-only
   */
  private async collectImageChanges(cwd: string, diffText: string): Promise<ImageChange[]> {
    // Phase 1: Extract image file entries from diff text (synchronous, CPU only)
    interface ImageEntry {
      filePath: string;
      isNew: boolean;
      isDeleted: boolean;
      isSvg: boolean;
      mimeType: string;
      ext: string;
    }
    const entries: ImageEntry[] = [];
    const processedPaths = new Set<string>();

    const lines = diffText.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      const gitMatch = line.match(/^diff --git a\/(.+?) b\/(.+)$/);
      if (!gitMatch) continue;

      const filePath = gitMatch[2];
      const ext = extname(filePath).toLowerCase();
      if (!BridgeWebSocketServer.IMAGE_EXTENSIONS.has(ext)) continue;
      if (processedPaths.has(filePath)) continue;
      processedPaths.add(filePath);

      let isNew = false;
      let isDeleted = false;
      for (let j = i + 1; j < Math.min(i + 6, lines.length); j++) {
        if (lines[j].startsWith("diff --git ")) break;
        if (lines[j].startsWith("new file mode")) isNew = true;
        if (lines[j].startsWith("deleted file mode")) isDeleted = true;
      }

      entries.push({
        filePath,
        isNew,
        isDeleted,
        isSvg: ext === ".svg",
        mimeType: BridgeWebSocketServer.mimeTypeForExt(ext),
        ext,
      });
    }

    if (entries.length === 0) return [];

    // Phase 2: Read image data asynchronously
    const execFileAsync = promisify(execFile);

    const changes: ImageChange[] = [];
    for (const entry of entries) {
      let oldBuf: Buffer | undefined;
      let newBuf: Buffer | undefined;

      // Read old image (committed version)
      if (!entry.isNew) {
        try {
          const result = await execFileAsync("git", ["show", `HEAD:${entry.filePath}`], {
            cwd,
            maxBuffer: BridgeWebSocketServer.MAX_IMAGE_SIZE + 1024,
            encoding: "buffer",
          });
          oldBuf = result.stdout as unknown as Buffer;
        } catch {
          // File may not exist in HEAD (e.g. untracked)
        }
      }

      // Read new image (working tree)
      if (!entry.isDeleted) {
        try {
          const absPath = resolve(cwd, entry.filePath);
          if (existsSync(absPath)) {
            newBuf = await readFile(absPath);
          }
        } catch {
          // Ignore read errors
        }
      }

      const oldSize = oldBuf?.length;
      const newSize = newBuf?.length;
      const maxSize = Math.max(oldSize ?? 0, newSize ?? 0);

      const autoDisplay = maxSize <= BridgeWebSocketServer.AUTO_DISPLAY_THRESHOLD;
      const loadable = autoDisplay || maxSize <= BridgeWebSocketServer.MAX_IMAGE_SIZE;

      const change: ImageChange = {
        filePath: entry.filePath,
        isNew: entry.isNew,
        isDeleted: entry.isDeleted,
        isSvg: entry.isSvg,
        mimeType: entry.mimeType,
        loadable,
        autoDisplay: autoDisplay || undefined,
      };

      if (oldSize !== undefined) change.oldSize = oldSize;
      if (newSize !== undefined) change.newSize = newSize;

      // Auto-display images are no longer embedded in the initial response.
      // They are loaded on-demand when the Flutter widget becomes visible.

      changes.push(change);
    }

    return changes;
  }

  /**
   * Load a single diff image on demand (async I/O for better throughput).
   */
  private async loadDiffImageAsync(
    cwd: string,
    filePath: string,
    version: "old" | "new",
  ): Promise<{ base64?: string; mimeType?: string; error?: string }> {
    // Path traversal guard: reject paths containing '..' or absolute paths
    if (filePath.includes("..") || filePath.startsWith("/")) {
      return { error: "Invalid file path" };
    }

    const ext = extname(filePath).toLowerCase();
    if (!BridgeWebSocketServer.IMAGE_EXTENSIONS.has(ext)) {
      return { error: "Not an image file" };
    }
    const mimeType = BridgeWebSocketServer.mimeTypeForExt(ext);

    try {
      const execFileAsync = promisify(execFile);

      let buf: Buffer;
      if (version === "old") {
        const result = await execFileAsync("git", ["show", `HEAD:${filePath}`], {
          cwd,
          maxBuffer: BridgeWebSocketServer.MAX_IMAGE_SIZE + 1024,
          encoding: "buffer",
        });
        buf = result.stdout as unknown as Buffer;
      } else {
        const absPath = resolve(cwd, filePath);
        // Verify resolved path stays within cwd
        if (!absPath.startsWith(resolve(cwd) + "/")) {
          return { error: "Invalid file path" };
        }
        buf = await readFile(absPath);
      }

      if (buf.length > BridgeWebSocketServer.MAX_IMAGE_SIZE) {
        return { error: "Image too large" };
      }

      return { base64: buf.toString("base64"), mimeType };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  }

  private extractSessionIdFromClientMessage(msg: ClientMessage): string | undefined {
    return "sessionId" in msg && typeof msg.sessionId === "string" ? msg.sessionId : undefined;
  }

  private extractSessionIdFromServerMessage(msg: ServerMessage | Record<string, unknown>): string | undefined {
    if ("sessionId" in msg && typeof msg.sessionId === "string") return msg.sessionId;
    return undefined;
  }

  private recordDebugEvent(
    sessionId: string,
    event: Omit<DebugTraceEvent, "ts" | "sessionId">,
  ): void {
    const events = this.debugEvents.get(sessionId) ?? [];
    const fullEvent: DebugTraceEvent = {
      ts: new Date().toISOString(),
      sessionId,
      ...event,
    };
    events.push(fullEvent);
    if (events.length > BridgeWebSocketServer.MAX_DEBUG_EVENTS) {
      events.splice(0, events.length - BridgeWebSocketServer.MAX_DEBUG_EVENTS);
    }
    this.debugEvents.set(sessionId, events);
    this.debugTraceStore.record(fullEvent);
  }

  private getDebugEvents(sessionId: string, limit: number): DebugTraceEvent[] {
    const events = this.debugEvents.get(sessionId) ?? [];
    const capped = Math.max(0, Math.min(limit, BridgeWebSocketServer.MAX_DEBUG_EVENTS));
    if (capped === 0) return [];
    return events.slice(-capped);
  }

  private buildHistorySummary(history: ServerMessage[]): string[] {
    const lines = history
      .map((msg, index) => {
        const num = String(index + 1).padStart(3, "0");
        return `${num}. ${this.summarizeServerMessage(msg)}`;
      });
    if (lines.length <= BridgeWebSocketServer.MAX_HISTORY_SUMMARY_ITEMS) {
      return lines;
    }
    return lines.slice(-BridgeWebSocketServer.MAX_HISTORY_SUMMARY_ITEMS);
  }

  private summarizeClientMessage(msg: ClientMessage): string {
    switch (msg.type) {
      case "input": {
        const textPreview = msg.text.replace(/\s+/g, " ").trim().slice(0, 80);
        const hasImage = msg.imageBase64 != null || msg.imageId != null;
        return `text=\"${textPreview}\" image=${hasImage}`;
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
      case "start":
        return `projectPath=${msg.projectPath} provider=${msg.provider ?? "claude"}`;
      case "resume_session":
        return `sessionId=${msg.sessionId} provider=${msg.provider ?? "claude"}`;
      case "get_debug_bundle":
        return `traceLimit=${msg.traceLimit ?? BridgeWebSocketServer.MAX_DEBUG_EVENTS} includeDiff=${msg.includeDiff ?? true}`;
      case "get_usage":
        return "get_usage";
      default:
        return msg.type;
    }
  }

  private summarizeServerMessage(msg: ServerMessage): string {
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
        const contentPreview = msg.content.replace(/\s+/g, " ").trim().slice(0, 100);
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

  private summarizeOutboundMessage(msg: ServerMessage | Record<string, unknown>): string {
    if ("type" in msg && typeof msg.type === "string") {
      return msg.type;
    }
    return "message";
  }

  private pruneDebugEvents(): void {
    const active = new Set(this.sessionManager.list().map((s) => s.id));
    for (const sessionId of this.debugEvents.keys()) {
      if (!active.has(sessionId)) {
        this.debugEvents.delete(sessionId);
      }
    }
    for (const sessionId of this.notifiedPermissionToolUses.keys()) {
      if (!active.has(sessionId)) {
        this.notifiedPermissionToolUses.delete(sessionId);
      }
    }
  }

  private buildReproRecipe(
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
      resumeSessionMessage: this.buildResumeSessionMessage(session),
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

  private buildResumeSessionMessage(session: SessionInfo): Record<string, unknown> {
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
      if (session.codexSettings.sandboxMode !== undefined) {
        msg.sandboxMode = session.codexSettings.sandboxMode;
      }
      if (session.codexSettings.model !== undefined) {
        msg.model = session.codexSettings.model;
      }
      if (session.codexSettings.modelReasoningEffort !== undefined) {
        msg.modelReasoningEffort = session.codexSettings.modelReasoningEffort;
      }
      if (session.codexSettings.networkAccessEnabled !== undefined) {
        msg.networkAccessEnabled = session.codexSettings.networkAccessEnabled;
      }
      if (session.codexSettings.webSearchMode !== undefined) {
        msg.webSearchMode = session.codexSettings.webSearchMode;
      }
    }

    return msg;
  }

  private buildAgentPrompt(session: SessionInfo): string {
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

}
