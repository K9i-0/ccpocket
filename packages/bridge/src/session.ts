import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { SdkProcess, type StartOptions } from "./sdk-process.js";
import type { ServerMessage, ProcessStatus, AssistantToolUseContent } from "./parser.js";
import type { ImageStore } from "./image-store.js";
import type { GalleryStore, GalleryImageMeta } from "./gallery-store.js";
import { createWorktree, worktreeExists } from "./worktree.js";
import type { WorktreeStore } from "./worktree-store.js";

export interface WorktreeOptions {
  useWorktree?: boolean;
  worktreeBranch?: string;
  /** Reuse an existing worktree path (skip creation). */
  existingWorktreePath?: string;
}

export interface SessionInfo {
  id: string;
  process: SdkProcess;
  history: ServerMessage[];
  /** Past conversation loaded from disk on resume (SessionHistoryMessage[]). */
  pastMessages?: unknown[];
  projectPath: string;
  claudeSessionId?: string;
  status: ProcessStatus;
  createdAt: Date;
  lastActivityAt: Date;
  gitBranch: string;
  /** If this session uses a worktree, the path to it. */
  worktreePath?: string;
  /** Branch name of the worktree. */
  worktreeBranch?: string;
}

export interface SessionSummary {
  id: string;
  projectPath: string;
  claudeSessionId?: string;
  status: ProcessStatus;
  createdAt: string;
  lastActivityAt: string;
  gitBranch: string;
  lastMessage: string;
  messageCount: number;
  worktreePath?: string;
  worktreeBranch?: string;
}

const MAX_HISTORY_PER_SESSION = 100;

export type GalleryImageCallback = (meta: GalleryImageMeta) => void;

export class SessionManager {
  private sessions = new Map<string, SessionInfo>();
  private onMessage: (sessionId: string, msg: ServerMessage) => void;
  private imageStore: ImageStore | null;
  private galleryStore: GalleryStore | null;
  private onGalleryImage: GalleryImageCallback | null;
  private worktreeStore: WorktreeStore | null;

  /** Cache slash commands per project path for early loading on subsequent sessions. */
  private commandCache = new Map<string, { slashCommands: string[]; skills: string[] }>();

  constructor(
    onMessage: (sessionId: string, msg: ServerMessage) => void,
    imageStore?: ImageStore,
    galleryStore?: GalleryStore,
    onGalleryImage?: GalleryImageCallback,
    worktreeStore?: WorktreeStore,
  ) {
    this.onMessage = onMessage;
    this.imageStore = imageStore ?? null;
    this.galleryStore = galleryStore ?? null;
    this.onGalleryImage = onGalleryImage ?? null;
    this.worktreeStore = worktreeStore ?? null;
  }

  create(
    projectPath: string,
    options?: StartOptions,
    pastMessages?: unknown[],
    worktreeOpts?: WorktreeOptions,
  ): string {
    const id = randomUUID().slice(0, 8);
    const proc = new SdkProcess();

    // Handle worktree: reuse existing or create new
    let wtPath: string | undefined;
    let wtBranch: string | undefined;
    if (worktreeOpts?.existingWorktreePath) {
      // Reuse an existing worktree (resume case)
      wtPath = worktreeOpts.existingWorktreePath;
      wtBranch = worktreeOpts.worktreeBranch;
      console.log(`[session] Reusing existing worktree at ${wtPath}`);
    } else if (worktreeOpts?.useWorktree) {
      // Create a new worktree
      try {
        const wt = createWorktree(projectPath, id, worktreeOpts.worktreeBranch);
        wtPath = wt.worktreePath;
        wtBranch = wt.branch;
        console.log(`[session] Created worktree at ${wtPath} (branch: ${wtBranch})`);
      } catch (err) {
        console.error(`[session] Failed to create worktree:`, err);
        // Fall through to use original projectPath
      }
    }

    // Use worktree path as cwd if available
    const effectiveCwd = wtPath ?? projectPath;

    let gitBranch = "";
    try {
      gitBranch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
        cwd: effectiveCwd, encoding: "utf-8",
      }).trim();
    } catch { /* not a git repo */ }

    const session: SessionInfo = {
      id,
      process: proc,
      history: [],
      pastMessages: pastMessages && pastMessages.length > 0 ? pastMessages : undefined,
      projectPath,
      status: "starting",
      createdAt: new Date(),
      lastActivityAt: new Date(),
      gitBranch,
      worktreePath: wtPath,
      worktreeBranch: wtBranch,
    };

    // Cache tool_use id → name for enriching tool_result messages
    const toolUseNames = new Map<string, string>();

    proc.on("message", async (msg) => {
      try {
        session.lastActivityAt = new Date();

        // Capture Claude session_id from result events
        if (msg.type === "result" && "sessionId" in msg && msg.sessionId) {
          session.claudeSessionId = msg.sessionId;
          this.saveWorktreeMapping(session);
        }
        if (msg.type === "system" && "sessionId" in msg && msg.sessionId) {
          session.claudeSessionId = msg.sessionId;
          this.saveWorktreeMapping(session);
        }

        // Inject Bridge-specific slash commands into any system message
        // that carries a slashCommands list (init, supported_commands).
        if (
          msg.type === "system" &&
          (msg.subtype === "init" || msg.subtype === "supported_commands") &&
          msg.slashCommands
        ) {
          const bridgeCommands = ["preview"];
          const allCommands = [...msg.slashCommands, ...bridgeCommands];
          msg = { ...msg, slashCommands: allCommands };
          this.commandCache.set(projectPath, {
            slashCommands: allCommands,
            skills: msg.skills ?? this.commandCache.get(projectPath)?.skills ?? [],
          });
        }

        // Cache tool_use names from assistant messages
        if (msg.type === "assistant") {
          for (const content of msg.message.content) {
            if (content.type === "tool_use") {
              const toolUse = content as AssistantToolUseContent;
              toolUseNames.set(toolUse.id, toolUse.name);
            }
          }
        }

        // Enrich tool_result with toolName
        if (msg.type === "tool_result") {
          const cachedName = toolUseNames.get(msg.toolUseId);
          if (cachedName) {
            msg = { ...msg, toolName: cachedName };
          }
        }

        // Extract images from tool_result content
        if (msg.type === "tool_result" && this.imageStore) {
          const paths = this.imageStore.extractImagePaths(msg.content);
          if (paths.length > 0) {
            const images = await this.imageStore.registerImages(paths);
            if (images.length > 0) {
              msg = { ...msg, images };
            }

            // Also register in GalleryStore (disk-persistent)
            if (this.galleryStore) {
              for (const p of paths) {
                const meta = await this.galleryStore.addImage(
                  p,
                  session.projectPath,
                  session.id,
                );
                if (meta && this.onGalleryImage) {
                  this.onGalleryImage(meta);
                }
              }
            }
          }
        }

        // Don't add streaming deltas to history
        if (msg.type !== "stream_delta" && msg.type !== "thinking_delta") {
          session.history.push(msg);
          if (session.history.length > MAX_HISTORY_PER_SESSION) {
            session.history.shift();
          }
        }

        this.onMessage(id, msg);
      } catch (err) {
        console.error(`[session] Error processing message for session ${id}:`, err);
      }
    });

    proc.on("status", (status) => {
      session.status = status;
    });

    proc.on("exit", () => {
      session.status = "idle";
    });

    this.sessions.set(id, session);
    proc.start(effectiveCwd, options);

    console.log(`[session] Created session ${id} for ${effectiveCwd}${wtPath ? ` (worktree of ${projectPath})` : ""}`);
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
      gitBranch: s.gitBranch,
      lastMessage: this.extractLastMessage(s),
      messageCount: (s.pastMessages?.length ?? 0) + s.history.length,
      worktreePath: s.worktreePath,
      worktreeBranch: s.worktreeBranch,
    }));
  }

  private extractLastMessage(s: SessionInfo): string {
    // Search in-memory history (newest first) for assistant text
    for (let i = s.history.length - 1; i >= 0; i--) {
      const msg = s.history[i];
      if (msg.type === "assistant") {
        const textBlock = msg.message.content.find((c) => c.type === "text");
        if (textBlock && "text" in textBlock && textBlock.text) {
          return textBlock.text.replace(/\s+/g, " ").trim().slice(0, 100);
        }
      }
    }
    // Fallback to pastMessages (raw Claude CLI format)
    if (s.pastMessages) {
      for (let i = s.pastMessages.length - 1; i >= 0; i--) {
        const msg = s.pastMessages[i] as Record<string, unknown>;
        if (msg.role === "assistant") {
          const content = msg.content as Array<Record<string, unknown>> | undefined;
          const textBlock = content?.find((c) => c.type === "text");
          if (textBlock?.text) return (textBlock.text as string).replace(/\s+/g, " ").trim().slice(0, 100);
        }
      }
    }
    return "";
  }

  getCachedCommands(projectPath: string): { slashCommands: string[]; skills: string[] } | undefined {
    return this.commandCache.get(projectPath);
  }

  /** Get worktree store for external use (e.g., resume_session in websocket.ts). */
  getWorktreeStore(): WorktreeStore | null {
    return this.worktreeStore;
  }

  /** Save worktree mapping when claudeSessionId is captured. */
  private saveWorktreeMapping(session: SessionInfo): void {
    if (this.worktreeStore && session.claudeSessionId && session.worktreePath && session.worktreeBranch) {
      this.worktreeStore.set(session.claudeSessionId, {
        worktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
        projectPath: session.projectPath,
      });
    }
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
