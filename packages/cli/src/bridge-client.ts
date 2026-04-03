import { EventEmitter } from "node:events";
import { WebSocket } from "ws";

export interface BridgeClientEvents {
  message: [msg: Record<string, unknown>];
  open: [];
  close: [code: number, reason: string];
  error: [err: Error];
}

export class BridgeClient extends EventEmitter<BridgeClientEvents> {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private shouldReconnect = true;

  constructor(url: string, apiKey?: string) {
    super();
    this.url = apiKey ? `${url}?token=${encodeURIComponent(apiKey)}` : url;
    this.connect();
  }

  private connect(): void {
    this.ws = new WebSocket(this.url);

    this.ws.on("open", () => {
      this.emit("open");
    });

    this.ws.on("message", (data) => {
      try {
        const msg = JSON.parse(data.toString()) as Record<string, unknown>;
        this.emit("message", msg);
      } catch {
        // ignore malformed messages
      }
    });

    this.ws.on("close", (code, reason) => {
      this.emit("close", code, reason.toString());
      if (this.shouldReconnect) {
        this.reconnectTimer = setTimeout(() => this.connect(), 3000);
      }
    });

    this.ws.on("error", (err) => {
      this.emit("error", err);
    });
  }

  send(msg: Record<string, unknown>): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msg));
    }
  }

  disconnect(): void {
    this.shouldReconnect = false;
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.ws?.close();
    this.ws = null;
  }

  get connected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}
