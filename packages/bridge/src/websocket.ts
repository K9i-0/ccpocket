import type { Server as HttpServer } from "node:http";
import { execFile, execFileSync } from "node:child_process";
import { unlink } from "node:fs/promises";
import { WebSocketServer, WebSocket } from "ws";
import { SessionManager, type SessionInfo } from "./session.js";
import type { SdkProcess } from "./sdk-process.js";
import type { CodexProcess } from "./codex-process.js";
import { parseClientMessage, type ClientMessage, type DebugTraceEvent, type ServerMessage } from "./parser.js";
import { getAllRecentSessions, getCodexSessionHistory, getSessionHistory } from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";
import type { GalleryStore } from "./gallery-store.js";
import type { ProjectHistory } from "./project-history.js";
import { WorktreeStore } from "./worktree-store.js";
import { listWorktrees, removeWorktree, createWorktree, worktreeExists } from "./worktree.js";
import { listWindows, takeScreenshot } from "./screenshot.js";
import { DebugTraceStore } from "./debug-trace-store.js";
import { RecordingStore } from "./recording-store.js";
import { PushRelayClient } from "./push-relay.js";
import { fetchAllUsage } from "./usage.js";

export interface BridgeServerOptions {
  server: HttpServer;
  apiKey?: string;
  imageStore?: ImageStore;
  galleryStore?: GalleryStore;
  projectHistory?: ProjectHistory;
  debugTraceStore?: DebugTraceStore;
  recordingStore?: RecordingStore;
}

export class BridgeWebSocketServer {
  private static readonly MAX_DEBUG_EVENTS = 800;
  private static readonly MAX_HISTORY_SUMMARY_ITEMS = 300;

  private wss: WebSocketServer;
  private sessionManager: SessionManager;
  private apiKey: string | null;
  private galleryStore: GalleryStore | null;
  private projectHistory: ProjectHistory | null;
  private debugTraceStore: DebugTraceStore;
  private recordingStore: RecordingStore;
  private worktreeStore: WorktreeStore;
  private pushRelay: PushRelayClient;
  private recentSessionsRequestId = 0;
  private debugEvents = new Map<string, DebugTraceEvent[]>();
  private notifiedPermissionToolUses = new Map<string, Set<string>>();

  constructor(options: BridgeServerOptions) {
    const { server, apiKey, imageStore, galleryStore, projectHistory, debugTraceStore, recordingStore } = options;
    this.apiKey = apiKey ?? null;
    this.galleryStore = galleryStore ?? null;
    this.projectHistory = projectHistory ?? null;
    this.debugTraceStore = debugTraceStore ?? new DebugTraceStore();
    this.recordingStore = recordingStore ?? new RecordingStore();
    this.worktreeStore = new WorktreeStore();
    this.pushRelay = new PushRelayClient();
    void this.debugTraceStore.init().catch((err) => {
      console.error("[ws] Failed to initialize debug trace store:", err);
    });
    void this.recordingStore.init().catch((err) => {
      console.error("[ws] Failed to initialize recording store:", err);
    });
    if (!this.pushRelay.isConfigured) {
      console.log("[ws] Push relay disabled (set PUSH_RELAY_URL and PUSH_RELAY_SECRET to enable)");
    } else {
      console.log("[ws] Push relay enabled");
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
        const provider = msg.provider ?? "claude";
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
                approvalPolicy: (msg.approvalPolicy as "never" | "on-request" | "on-failure" | "untrusted") ?? undefined,
                sandboxMode: (msg.sandboxMode as "read-only" | "workspace-write" | "danger-full-access") ?? undefined,
                model: msg.model,
                modelReasoningEffort: (msg.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh") ?? undefined,
                networkAccessEnabled: msg.networkAccessEnabled,
                webSearchMode: (msg.webSearchMode as "disabled" | "cached" | "live") ?? undefined,
                threadId: msg.sessionId,
              }
            : undefined,
        );
        const createdSession = this.sessionManager.get(sessionId);
        this.send(ws, {
          type: "system",
          subtype: "session_created",
          sessionId,
          provider,
          projectPath: msg.projectPath,
          ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
          ...(createdSession?.worktreePath ? {
            worktreePath: createdSession.worktreePath,
            worktreeBranch: createdSession.worktreeBranch,
          } : {}),
        });
        this.debugEvents.set(sessionId, []);
        this.recordDebugEvent(sessionId, {
          direction: "internal",
          channel: "bridge",
          type: "session_created",
          detail: `provider=${provider} projectPath=${msg.projectPath}`,
        });
        this.projectHistory?.addProject(msg.projectPath);
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
        // SDK (Claude Code): always accept — the async generator keeps the resolver set during processing
        if (session.provider === "codex" && !session.process.isWaitingForInput) {
          this.send(ws, { type: "input_rejected", sessionId: session.id, reason: "Process is busy" });
          break;
        }

        // Acknowledge receipt immediately so the client can mark the message as sent
        this.send(ws, { type: "input_ack", sessionId: session.id });

        // Add user_input to in-memory history.
        // The SDK stream does NOT emit user messages, so session.history would
        // otherwise lack them.  This ensures get_history responses include user
        // messages and replaceEntries on the client side preserves them.
        // We do NOT broadcast this back — Flutter already shows it via sendMessage().
        session.history.push({ type: "user_input", text } as ServerMessage);

        // Codex input path (text + optional image)
        if (session.provider === "codex") {
          const codexProc = session.process as CodexProcess;
          if (msg.imageBase64 && msg.mimeType) {
            codexProc.sendInputWithImage(text, {
              base64: msg.imageBase64,
              mimeType: msg.mimeType,
            });
            if (this.galleryStore && session.projectPath) {
              this.galleryStore.addImageFromBase64(
                msg.imageBase64,
                msg.mimeType,
                session.projectPath,
                msg.sessionId,
              ).catch((err) => {
                console.warn(`[ws] Failed to persist image to gallery: ${err}`);
              });
            }
          } else if (msg.imageId && this.galleryStore) {
            this.galleryStore.getImageAsBase64(msg.imageId).then((imageData) => {
              if (imageData) {
                codexProc.sendInputWithImage(text, imageData);
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

        // Priority 1: Direct Base64 image (simplified flow)
        const claudeProc = session.process as SdkProcess;
        if (msg.imageBase64 && msg.mimeType) {
          console.log(`[ws] Sending message with inline Base64 image (${msg.mimeType})`);
          claudeProc.sendInputWithImage(text, {
            base64: msg.imageBase64,
            mimeType: msg.mimeType,
          });
          // Persist to Gallery Store asynchronously (fire-and-forget)
          if (this.galleryStore && session.projectPath) {
            this.galleryStore.addImageFromBase64(
              msg.imageBase64,
              msg.mimeType,
              session.projectPath,
              msg.sessionId,
            ).catch((err) => {
              console.warn(`[ws] Failed to persist image to gallery: ${err}`);
            });
          }
        }
        // Priority 2: Legacy imageId mode (backward compatibility)
        else if (msg.imageId && this.galleryStore) {
          this.galleryStore.getImageAsBase64(msg.imageId).then((imageData) => {
            if (imageData) {
              claudeProc.sendInputWithImage(text, imageData);
            } else {
              console.warn(`[ws] Image not found: ${msg.imageId}`);
              session.process.sendInput(text);
            }
          }).catch((err) => {
            console.error(`[ws] Failed to load image: ${err}`);
            session.process.sendInput(text);
          });
        }
        // Priority 3: Text-only message
        else {
          session.process.sendInput(text);
        }
        break;
      }

      case "push_register": {
        if (!this.pushRelay.isConfigured) {
          this.send(ws, { type: "error", message: "Push relay is not configured on bridge" });
          return;
        }
        this.pushRelay.registerToken(msg.token, msg.platform).catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
          this.send(ws, { type: "error", message: `Failed to register push token: ${detail}` });
        });
        break;
      }

      case "push_unregister": {
        if (!this.pushRelay.isConfigured) {
          this.send(ws, { type: "error", message: "Push relay is not configured on bridge" });
          return;
        }
        this.pushRelay.unregisterToken(msg.token).catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
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
          this.send(ws, {
            type: "error",
            message: "Codex sessions do not support runtime permission mode changes",
          });
          return;
        }
        (session.process as SdkProcess).setPermissionMode(msg.mode).catch((err) => {
          this.send(ws, {
            type: "error",
            message: `Failed to set permission mode: ${err instanceof Error ? err.message : String(err)}`,
          });
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
          this.send(ws, { type: "error", message: "Codex sessions do not support approval" });
          return;
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
            clearContext: true,
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
          this.send(ws, { type: "error", message: "Codex sessions do not support approval" });
          return;
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
          this.send(ws, { type: "error", message: "Codex sessions do not support rejection" });
          return;
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
          this.send(ws, { type: "error", message: "Codex sessions do not support answer" });
          return;
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
                approvalPolicy: (msg.approvalPolicy as "never" | "on-request" | "on-failure" | "untrusted") ?? undefined,
                sandboxMode: (msg.sandboxMode as "read-only" | "workspace-write" | "danger-full-access") ?? undefined,
                model: msg.model,
                modelReasoningEffort: (msg.modelReasoningEffort as "minimal" | "low" | "medium" | "high" | "xhigh") ?? undefined,
                networkAccessEnabled: msg.networkAccessEnabled,
                webSearchMode: (msg.webSearchMode as "disabled" | "cached" | "live") ?? undefined,
              },
            );
            const createdSession = this.sessionManager.get(sessionId);
            this.send(ws, {
              type: "system",
              subtype: "session_created",
              sessionId,
              provider: "codex",
              projectPath: effectiveProjectPath,
              ...(createdSession?.worktreePath ? {
                worktreePath: createdSession.worktreePath,
                worktreeBranch: createdSession.worktreeBranch,
              } : {}),
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
          this.send(ws, {
            type: "system",
            subtype: "session_created",
            sessionId,
            provider: "claude",
            projectPath: msg.projectPath,
            ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
            ...(createdSession?.worktreePath ? {
              worktreePath: createdSession.worktreePath,
              worktreeBranch: createdSession.worktreeBranch,
            } : {}),
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

      case "get_diff": {
        this.collectGitDiff(msg.projectPath, ({ diff, error }) => {
          if (error) {
            this.send(ws, { type: "diff_result", diff: "", error: `Failed to get diff: ${error}` });
            return;
          }
          this.send(ws, { type: "diff_result", diff });
        });
        break;
      }

      case "list_worktrees": {
        try {
          const worktrees = listWorktrees(msg.projectPath);
          this.send(ws, { type: "worktree_list", worktrees });
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
              this.send(ws, {
                type: "system",
                subtype: "session_created",
                sessionId: newSessionId,
                provider: newSession?.provider ?? "claude",
                projectPath: newSession?.projectPath ?? "",
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
                this.send(ws, {
                  type: "system",
                  subtype: "session_created",
                  sessionId: newSessionId,
                  provider: newSession?.provider ?? "claude",
                  projectPath: newSession?.projectPath ?? "",
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
    }
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
    // Wrap the message with sessionId
    const data = JSON.stringify({ ...msg, sessionId });
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  private maybeSendPushNotification(sessionId: string, msg: ServerMessage): void {
    if (!this.pushRelay.isConfigured) return;

    if (msg.type === "permission_request") {
      const seen = this.notifiedPermissionToolUses.get(sessionId) ?? new Set<string>();
      if (seen.has(msg.toolUseId)) return;
      seen.add(msg.toolUseId);
      this.notifiedPermissionToolUses.set(sessionId, seen);

      const isAskUserQuestion = msg.toolName === "AskUserQuestion";
      const eventType = isAskUserQuestion ? "ask_user_question" : "approval_required";
      const title = isAskUserQuestion ? "回答待ち" : "承認待ち";
      const body = isAskUserQuestion
        ? "Claude が質問しています"
        : "ツール実行の承認が必要です";
      void this.pushRelay.notify({
        eventType,
        title,
        body,
        data: {
          sessionId,
          toolUseId: msg.toolUseId,
          toolName: msg.toolName,
        },
      }).catch((err) => {
        const detail = err instanceof Error ? err.message : String(err);
        console.warn(`[ws] Failed to send push notification (${eventType}): ${detail}`);
      });
      return;
    }

    if (msg.type !== "result") return;
    if (msg.subtype === "stopped") return;
    if (msg.subtype !== "success" && msg.subtype !== "error") return;

    const isSuccess = msg.subtype === "success";
    const eventType = isSuccess ? "session_completed" : "session_failed";
    const title = isSuccess ? "タスク完了" : "エラー発生";
    let body = isSuccess ? "セッションが完了しました" : "セッションが失敗しました";
    if (isSuccess && (msg.duration != null || msg.cost != null)) {
      const pieces: string[] = [];
      if (msg.duration != null) pieces.push(`${msg.duration.toFixed(1)}s`);
      if (msg.cost != null) pieces.push(`$${msg.cost.toFixed(4)}`);
      if (pieces.length > 0) body = `セッション完了 (${pieces.join(", ")})`;
    } else if (!isSuccess && msg.error) {
      body = msg.error.slice(0, 120);
    }

    const data: Record<string, string> = {
      sessionId,
      subtype: msg.subtype,
    };
    if (msg.stopReason) data.stopReason = msg.stopReason;
    if (msg.sessionId) data.providerSessionId = msg.sessionId;

    void this.pushRelay.notify({
      eventType,
      title,
      body,
      data,
    }).catch((err) => {
      const detail = err instanceof Error ? err.message : String(err);
      console.warn(`[ws] Failed to send push notification (${eventType}): ${detail}`);
    });
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
