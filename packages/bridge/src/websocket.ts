import { WebSocketServer, WebSocket } from "ws";
import { ClaudeProcess } from "./claude-process.js";
import { parseClientMessage, type ServerMessage } from "./parser.js";

const MAX_HISTORY = 100;

export class BridgeWebSocketServer {
  private wss: WebSocketServer;
  private claudeProcess: ClaudeProcess;
  private messageHistory: ServerMessage[] = [];

  constructor(port: number) {
    this.wss = new WebSocketServer({ port });
    this.claudeProcess = new ClaudeProcess();

    this.claudeProcess.on("message", (msg) => {
      this.addToHistory(msg);
      this.broadcast(msg);
    });

    this.wss.on("connection", (ws) => {
      console.log("[ws] Client connected");
      this.handleConnection(ws);
    });

    this.wss.on("error", (err) => {
      console.error("[ws] Server error:", err.message);
    });

    console.log(`[ws] WebSocket server listening on port ${port}`);
  }

  close(): void {
    console.log("[ws] Shutting down...");
    this.claudeProcess.stop();
    this.wss.close();
  }

  private handleConnection(ws: WebSocket): void {
    // Send message history to reconnecting client
    if (this.messageHistory.length > 0) {
      this.send(ws, { type: "history", messages: this.messageHistory });
    }

    // Send current status
    this.send(ws, { type: "status", status: this.claudeProcess.status });

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

  private handleClientMessage(msg: ReturnType<typeof parseClientMessage>, ws: WebSocket): void {
    if (!msg) return;

    switch (msg.type) {
      case "start":
        if (this.claudeProcess.isRunning) {
          this.claudeProcess.stop();
        }
        this.messageHistory = [];
        this.claudeProcess.start(msg.projectPath);
        break;

      case "input":
        if (!this.claudeProcess.isRunning) {
          this.send(ws, { type: "error", message: "No Claude process running. Send 'start' first." });
          return;
        }
        this.claudeProcess.sendInput(msg.text);
        break;

      case "approve":
        if (!this.claudeProcess.isRunning) {
          this.send(ws, { type: "error", message: "No Claude process running." });
          return;
        }
        this.claudeProcess.approve();
        break;

      case "reject":
        if (!this.claudeProcess.isRunning) {
          this.send(ws, { type: "error", message: "No Claude process running." });
          return;
        }
        this.claudeProcess.reject();
        break;
    }
  }

  private addToHistory(msg: ServerMessage): void {
    this.messageHistory.push(msg);
    if (this.messageHistory.length > MAX_HISTORY) {
      this.messageHistory.shift();
    }
  }

  private broadcast(msg: ServerMessage): void {
    const data = JSON.stringify(msg);
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        client.send(data);
      }
    }
  }

  private send(ws: WebSocket, msg: ServerMessage): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(msg));
    }
  }
}
