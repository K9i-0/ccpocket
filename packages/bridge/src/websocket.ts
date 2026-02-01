import type { Server as HttpServer } from "node:http";
import { WebSocketServer, WebSocket } from "ws";
import { SessionManager, type SessionInfo } from "./session.js";
import { parseClientMessage, type ClientMessage, type ServerMessage } from "./parser.js";
import { getAllRecentSessions, getSessionHistory } from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";

export interface BridgeServerOptions {
  server: HttpServer;
  apiKey?: string;
  imageStore?: ImageStore;
}

export class BridgeWebSocketServer {
  private wss: WebSocketServer;
  private sessionManager: SessionManager;
  private apiKey: string | null;

  constructor(options: BridgeServerOptions) {
    const { server, apiKey, imageStore } = options;
    this.apiKey = apiKey ?? null;

    this.wss = new WebSocketServer({ server });

    this.sessionManager = new SessionManager((sessionId, msg) => {
      this.broadcastSessionMessage(sessionId, msg);
    }, imageStore);

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
        session.process.sendToolResult(msg.toolUseId, msg.result);
        break;
      }

      case "list_sessions": {
        this.sendSessionList(ws);
        break;
      }

      case "stop_session": {
        const destroyed = this.sessionManager.destroy(msg.sessionId);
        if (destroyed) {
          this.sendSessionList(ws);
        } else {
          this.send(ws, { type: "error", message: `Session ${msg.sessionId} not found` });
        }
        break;
      }

      case "get_history": {
        const session = this.sessionManager.get(msg.sessionId);
        if (session) {
          this.send(ws, { type: "history", messages: session.history });
          this.send(ws, { type: "status", status: session.status });
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
          });
          this.send(ws, {
            type: "system",
            subtype: "session_created",
            sessionId,
            projectPath: msg.projectPath,
          });
        }).catch((err) => {
          this.send(ws, { type: "error", message: `Failed to load session history: ${err}` });
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

  private send(ws: WebSocket, msg: ServerMessage | Record<string, unknown>): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(msg));
    }
  }
}
