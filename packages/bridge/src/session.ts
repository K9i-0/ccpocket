import { randomUUID } from "node:crypto";
import { ClaudeProcess, type StartOptions } from "./claude-process.js";
import type { ServerMessage, ProcessStatus } from "./parser.js";
import type { ImageStore } from "./image-store.js";

export interface SessionInfo {
  id: string;
  process: ClaudeProcess;
  history: ServerMessage[];
  projectPath: string;
  claudeSessionId?: string;
  status: ProcessStatus;
  createdAt: Date;
  lastActivityAt: Date;
}

export interface SessionSummary {
  id: string;
  projectPath: string;
  claudeSessionId?: string;
  status: ProcessStatus;
  createdAt: string;
  lastActivityAt: string;
}

const MAX_HISTORY_PER_SESSION = 100;

export class SessionManager {
  private sessions = new Map<string, SessionInfo>();
  private onMessage: (sessionId: string, msg: ServerMessage) => void;
  private imageStore: ImageStore | null;

  constructor(
    onMessage: (sessionId: string, msg: ServerMessage) => void,
    imageStore?: ImageStore,
  ) {
    this.onMessage = onMessage;
    this.imageStore = imageStore ?? null;
  }

  create(projectPath: string, options?: StartOptions): string {
    const id = randomUUID().slice(0, 8);
    const proc = new ClaudeProcess();
    const session: SessionInfo = {
      id,
      process: proc,
      history: [],
      projectPath,
      status: "idle",
      createdAt: new Date(),
      lastActivityAt: new Date(),
    };

    proc.on("message", async (msg) => {
      session.lastActivityAt = new Date();

      // Capture Claude session_id from result events
      if (msg.type === "result" && "sessionId" in msg && msg.sessionId) {
        session.claudeSessionId = msg.sessionId;
      }
      if (msg.type === "system" && "sessionId" in msg && msg.sessionId) {
        session.claudeSessionId = msg.sessionId;
      }

      // Extract images from tool_result content
      if (msg.type === "tool_result" && this.imageStore) {
        const paths = this.imageStore.extractImagePaths(msg.content);
        if (paths.length > 0) {
          const images = await this.imageStore.registerImages(paths);
          if (images.length > 0) {
            msg = { ...msg, images };
          }
        }
      }

      // Don't add stream_delta to history
      if (msg.type !== "stream_delta") {
        session.history.push(msg);
        if (session.history.length > MAX_HISTORY_PER_SESSION) {
          session.history.shift();
        }
      }

      this.onMessage(id, msg);
    });

    proc.on("status", (status) => {
      session.status = status;
    });

    proc.on("exit", () => {
      session.status = "idle";
    });

    this.sessions.set(id, session);
    proc.start(projectPath, options);

    console.log(`[session] Created session ${id} for ${projectPath}`);
    return id;
  }

  get(id: string): SessionInfo | undefined {
    return this.sessions.get(id);
  }

  list(): SessionSummary[] {
    return Array.from(this.sessions.values()).map((s) => ({
      id: s.id,
      projectPath: s.projectPath,
      claudeSessionId: s.claudeSessionId,
      status: s.status,
      createdAt: s.createdAt.toISOString(),
      lastActivityAt: s.lastActivityAt.toISOString(),
    }));
  }

  destroy(id: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.process.stop();
    session.process.removeAllListeners();
    this.sessions.delete(id);
    console.log(`[session] Destroyed session ${id}`);
    return true;
  }

  destroyAll(): void {
    for (const [id] of this.sessions) {
      this.destroy(id);
    }
  }
}
