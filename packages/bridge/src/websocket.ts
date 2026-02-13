import type { Server as HttpServer } from "node:http";
import { execFile, execFileSync } from "node:child_process";
import { unlink } from "node:fs/promises";
import { WebSocketServer, WebSocket } from "ws";
import { SessionManager, type SessionInfo } from "./session.js";
import type { SdkProcess } from "./sdk-process.js";
import { parseClientMessage, type ClientMessage, type ServerMessage } from "./parser.js";
import { getAllRecentSessions, getCodexSessionHistory, getSessionHistory } from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";
import type { GalleryStore } from "./gallery-store.js";
import type { ProjectHistory } from "./project-history.js";
import { WorktreeStore } from "./worktree-store.js";
import { listWorktrees, removeWorktree, createWorktree, worktreeExists } from "./worktree.js";
import { listWindows, takeScreenshot } from "./screenshot.js";

export interface BridgeServerOptions {
  server: HttpServer;
  apiKey?: string;
  imageStore?: ImageStore;
  galleryStore?: GalleryStore;
  projectHistory?: ProjectHistory;
}

export class BridgeWebSocketServer {
  private wss: WebSocketServer;
  private sessionManager: SessionManager;
  private apiKey: string | null;
  private galleryStore: GalleryStore | null;
  private projectHistory: ProjectHistory | null;
  private worktreeStore: WorktreeStore;
  private recentSessionsRequestId = 0;

  constructor(options: BridgeServerOptions) {
    const { server, apiKey, imageStore, galleryStore, projectHistory } = options;
    this.apiKey = apiKey ?? null;
    this.galleryStore = galleryStore ?? null;
    this.projectHistory = projectHistory ?? null;
    this.worktreeStore = new WorktreeStore();

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
                threadId: msg.sessionId,
              }
            : undefined,
        );
        const createdSession = this.sessionManager.get(sessionId);
        this.send(ws, {
          type: "system",
          subtype: "session_created",
          sessionId,
          projectPath: msg.projectPath,
          ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
          ...(createdSession?.worktreePath ? {
            worktreePath: createdSession.worktreePath,
            worktreeBranch: createdSession.worktreeBranch,
          } : {}),
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

        // Codex: text-only input (no image support via SDK)
        if (session.provider === "codex") {
          session.process.sendInput(text);
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
        (session.process as SdkProcess).approve(msg.id, msg.updatedInput, msg.clearContext);
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
        if (provider === "codex") {
          getCodexSessionHistory(sessionRefId).then((pastMessages) => {
            if (pastMessages.length > 0) {
              this.send(ws, {
                type: "past_history",
                claudeSessionId: sessionRefId,
                messages: pastMessages,
              } as Record<string, unknown>);
            }
            const sessionId = this.sessionManager.create(
              msg.projectPath,
              undefined,
              pastMessages,
              undefined,
              "codex",
              { threadId: sessionRefId },
            );
            this.send(ws, {
              type: "system",
              subtype: "session_created",
              sessionId,
              projectPath: msg.projectPath,
            });
            this.projectHistory?.addProject(msg.projectPath);
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
          if (pastMessages.length > 0) {
            this.send(ws, {
              type: "past_history",
              claudeSessionId,
              messages: pastMessages,
            } as Record<string, unknown>);
          }
          const sessionId = this.sessionManager.create(
            msg.projectPath,
            {
              sessionId: claudeSessionId,
              permissionMode: msg.permissionMode,
            },
            pastMessages,
            worktreeOpts,
          );
          const createdSession = this.sessionManager.get(sessionId);
          this.send(ws, {
            type: "system",
            subtype: "session_created",
            sessionId,
            projectPath: msg.projectPath,
            ...(cached ? { slashCommands: cached.slashCommands, skills: cached.skills } : {}),
            ...(createdSession?.worktreePath ? {
              worktreePath: createdSession.worktreePath,
              worktreeBranch: createdSession.worktreeBranch,
            } : {}),
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
        const cwd = msg.projectPath;
        const execOpts = { cwd, maxBuffer: 10 * 1024 * 1024 };

        // Collect untracked files so they appear in the diff
        let untrackedFiles: string[] = [];
        try {
          const out = execFileSync("git", ["ls-files", "--others", "--exclude-standard"], { cwd }).toString().trim();
          untrackedFiles = out ? out.split("\n") : [];
        } catch { /* ignore */ }

        // Temporarily stage untracked files with --intent-to-add
        if (untrackedFiles.length > 0) {
          try {
            execFileSync("git", ["add", "--intent-to-add", ...untrackedFiles], { cwd });
          } catch { /* ignore */ }
        }

        execFile("git", ["diff", "--no-color"], execOpts, (err, stdout) => {
          // Revert intent-to-add for untracked files
          if (untrackedFiles.length > 0) {
            try {
              execFileSync("git", ["reset", "--", ...untrackedFiles], { cwd });
            } catch { /* ignore */ }
          }

          if (err) {
            this.send(ws, { type: "diff_result", diff: "", error: `Failed to get diff: ${err.message}` });
            return;
          }
          this.send(ws, { type: "diff_result", diff: stdout });
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
    const sessions = this.sessionManager.list();
    const msg = JSON.stringify({ type: "session_list", sessions });
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }

  private broadcastSessionMessage(sessionId: string, msg: ServerMessage): void {
    // Wrap the message with sessionId
    const data = JSON.stringify({ ...msg, sessionId });
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
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
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(msg));
    }
  }

  /** Broadcast a gallery_new_image message to all connected clients. */
  broadcastGalleryNewImage(image: import("./gallery-store.js").GalleryImageInfo): void {
    this.broadcast({ type: "gallery_new_image", image });
  }

}
