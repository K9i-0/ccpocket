import type { Server as HttpServer } from "node:http";
import { execFile } from "node:child_process";
import { WebSocketServer, WebSocket } from "ws";
import { SessionManager, type SessionInfo } from "./session.js";
import { parseClientMessage, type ClientMessage, type ServerMessage } from "./parser.js";
import { getAllRecentSessions, getSessionHistory } from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";
import type { GalleryStore } from "./gallery-store.js";
import type { ProjectHistory } from "./project-history.js";

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

  constructor(options: BridgeServerOptions) {
    const { server, apiKey, imageStore, galleryStore, projectHistory } = options;
    this.apiKey = apiKey ?? null;
    this.galleryStore = galleryStore ?? null;
    this.projectHistory = projectHistory ?? null;

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
        const sessionId = this.sessionManager.create(msg.projectPath, {
          sessionId: msg.sessionId,
          continueMode: msg.continue,
          permissionMode: msg.permissionMode,
        });
        this.send(ws, {
          type: "system",
          subtype: "session_created",
          sessionId,
          projectPath: msg.projectPath,
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
        session.process.sendInput(msg.text);
        break;
      }

      case "approve": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        session.process.approve(msg.id);
        break;
      }

      case "approve_always": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        session.process.approveAlways(msg.id);
        break;
      }

      case "reject": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        session.process.reject(msg.id, msg.message);
        break;
      }

      case "answer": {
        const session = this.resolveSession(msg.sessionId);
        if (!session) {
          this.send(ws, { type: "error", message: "No active session." });
          return;
        }
        session.process.answer(msg.toolUseId, msg.result);
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
        getAllRecentSessions(msg.limit).then((sessions) => {
          this.send(ws, { type: "recent_sessions", sessions } as Record<string, unknown>);
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to list recent sessions: ${err}` });
        });
        break;
      }

      case "resume_session": {
        const claudeSessionId = msg.sessionId;
        getSessionHistory(claudeSessionId).then((pastMessages) => {
          if (pastMessages.length > 0) {
            this.send(ws, {
              type: "past_history",
              claudeSessionId,
              messages: pastMessages,
            } as Record<string, unknown>);
          }
          const sessionId = this.sessionManager.create(msg.projectPath, {
            sessionId: claudeSessionId,
            permissionMode: msg.permissionMode,
          }, pastMessages);
          this.send(ws, {
            type: "system",
            subtype: "session_created",
            sessionId,
            projectPath: msg.projectPath,
          });
          this.projectHistory?.addProject(msg.projectPath);
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to load session history: ${err}` });
        });
        break;
      }

      case "list_gallery": {
        if (this.galleryStore) {
          const images = this.galleryStore.list({ projectPath: msg.project });
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
}
