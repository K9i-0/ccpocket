import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToSlug, renameClaudeSession, renameCodexSession } from "./sessions-index.js";
import { SdkProcess, type StartOptions, type RewindFilesResult } from "./sdk-process.js";
import { CodexProcess, type CodexStartOptions } from "./codex-process.js";
import type { ServerMessage, ProcessStatus, AssistantToolUseContent, Provider } from "./parser.js";
import type { ImageRef, ImageStore } from "./image-store.js";
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
  process: SdkProcess | CodexProcess;
  provider: Provider;
  history: ServerMessage[];
  /** Past conversation loaded from disk on resume (SessionHistoryMessage[]). */
  pastMessages?: unknown[];
  projectPath: string;
  claudeSessionId?: string;
  /** User-assigned session name (via /rename or mobile rename). */
  name?: string;
  status: ProcessStatus;
  createdAt: Date;
  lastActivityAt: Date;
  gitBranch: string;
  /** If this session uses a worktree, the path to it. */
  worktreePath?: string;
  /** Branch name of the worktree. */
  worktreeBranch?: string;
  /** Codex-specific settings used to start this session (for resume). */
  codexSettings?: {
    approvalPolicy?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
  };
}

export interface SessionSummary {
  id: string;
  provider: Provider;
  projectPath: string;
  claudeSessionId?: string;
  /** User-assigned session name. */
  name?: string;
  status: ProcessStatus;
  createdAt: string;
  lastActivityAt: string;
  gitBranch: string;
  lastMessage: string;
  messageCount: number;
  worktreePath?: string;
  worktreeBranch?: string;
  permissionMode?: string;
  codexSettings?: {
    approvalPolicy?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
  };
  pendingPermission?: {
    toolUseId: string;
    toolName: string;
    input: Record<string, unknown>;
  };
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
    provider?: Provider,
    codexOptions?: CodexStartOptions,
  ): string {
    const id = randomUUID().slice(0, 8);
    const effectiveProvider = provider ?? "claude";
    const proc = effectiveProvider === "codex" ? new CodexProcess() : new SdkProcess();

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
      provider: effectiveProvider,
      history: [],
      pastMessages: pastMessages && pastMessages.length > 0 ? pastMessages : undefined,
      projectPath,
      status: "starting",
      createdAt: new Date(),
      lastActivityAt: new Date(),
      gitBranch,
      worktreePath: wtPath,
      worktreeBranch: wtBranch,
      // Pre-populate claudeSessionId for resumed sessions so that get_history
      // can return it immediately (before the SDK sends a system/result event).
      claudeSessionId: options?.sessionId,
    };

    // Cache tool_use id → name for enriching tool_result messages
    const toolUseNames = new Map<string, string>();

    proc.on("message", async (msg) => {
      try {
        session.lastActivityAt = new Date();

        if (effectiveProvider === "claude") {
          // Capture Claude session_id from result events
          if (msg.type === "result" && "sessionId" in msg && msg.sessionId) {
            session.claudeSessionId = msg.sessionId;
            this.saveWorktreeMapping(session);
          }
          if (msg.type === "system" && "sessionId" in msg && msg.sessionId) {
            session.claudeSessionId = msg.sessionId;
            this.saveWorktreeMapping(session);
          }

          // Cache slash commands and skills from system messages.
          if (
            msg.type === "system" &&
            (msg.subtype === "init" || msg.subtype === "supported_commands") &&
            msg.slashCommands
          ) {
            this.commandCache.set(projectPath, {
              slashCommands: msg.slashCommands,
              skills: msg.skills ?? this.commandCache.get(projectPath)?.skills ?? [],
            });
          }

          // Cache tool_use names from assistant messages
          if (msg.type === "assistant" && Array.isArray(msg.message.content)) {
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
              const images = await this.imageStore.registerImages(paths, session.projectPath);
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

            // Extract base64 images from content blocks (e.g., MCP screenshots)
            if (msg.rawContentBlocks) {
              const imageBlocks = (msg.rawContentBlocks as Array<Record<string, unknown>>)
                .filter((c) => c.type === "image" && (c.source as Record<string, unknown>)?.type === "base64");

              if (imageBlocks.length > 0) {
                const existingImages = msg.images ?? [];
                const newImages: ImageRef[] = [];

                for (const block of imageBlocks) {
                  const source = block.source as Record<string, unknown>;
                  if (typeof source?.data !== "string" || typeof source?.media_type !== "string") continue;
                  const b64Data = source.data as string;
                  const mimeType = source.media_type as string;
                  const ref = this.imageStore.registerFromBase64(b64Data, mimeType);
                  if (ref) {
                    newImages.push(ref);

                    // Also persist to GalleryStore
                    if (this.galleryStore) {
                      const meta = await this.galleryStore.addImageFromBase64(
                        b64Data,
                        mimeType,
                        session.projectPath,
                        session.id,
                      );
                      if (meta && this.onGalleryImage) {
                        this.onGalleryImage(meta);
                      }
                    }
                  }
                }

                if (newImages.length > 0) {
                  msg = { ...msg, images: [...existingImages, ...newImages] };
                }
              }

              // Strip transient rawContentBlocks before sending to client
              const { rawContentBlocks: _, ...cleanMsg } = msg;
              msg = cleanMsg as typeof msg;
            }
          }
        } else {
          // Codex: capture thread_id for session tracking and worktree restore.
          if (msg.type === "system" && "sessionId" in msg && msg.sessionId) {
            session.claudeSessionId = msg.sessionId;
            this.saveWorktreeMapping(session);
          }
        }

        // Don't add streaming deltas to history
        if (msg.type !== "stream_delta" && msg.type !== "thinking_delta") {
          // When SDK echoes back a user_input with UUID, merge into the
          // UUID-less placeholder that websocket.ts pushed earlier.
          // This avoids duplicate entries while preserving the UUID needed
          // for rewind candidate matching.
          let merged = false;
          if (
            msg.type === "user_input" &&
            "userMessageUuid" in msg &&
            msg.userMessageUuid
          ) {
            for (let i = session.history.length - 1; i >= 0; i--) {
              const m = session.history[i];
              if (
                m.type === "user_input" &&
                !("userMessageUuid" in m && m.userMessageUuid)
              ) {
                session.history[i] = { ...m, ...msg };
                merged = true;
                break;
              }
            }
          }

          if (!merged) {
            session.history.push(msg);
          }
          if (session.history.length > MAX_HISTORY_PER_SESSION) {
            // Protect user_input messages from eviction so they remain
            // visible when the client requests history after reconnecting.
            const idx = session.history.findIndex(m => m.type !== "user_input");
            if (idx >= 0) {
              session.history.splice(idx, 1);
            } else {
              session.history.shift();
            }
          }
        }

        this.onMessage(id, msg);

        // After a result (turn complete), backfill UUIDs from disk.
        // The SDK does not echo user messages via the stream, so
        // in-memory user_input entries lack UUIDs.  The disk
        // conversation file always has them.
        if (msg.type === "result") {
          this.backfillUserUuidsFromDisk(session);
        }
      } catch (err) {
        console.error(`[session] Error processing message for session ${id}:`, err);
      }
    });

    proc.on("status", (status) => {
      session.status = status;
    });

    proc.on("exit", () => {
      session.status = "idle";
      // Add status message to history so it stays in sync with session.status
      session.history.push({ type: "status", status: "idle" } as ServerMessage);
    });

    // Re-persist customTitle after CLI finishes writing sessions-index.json.
    // session_end fires after the query iterator completes (CLI has shut down
    // and flushed its files), so writing the name here prevents the CLI from
    // overwriting our customTitle.
    if (proc instanceof SdkProcess) {
      proc.on("session_end", async () => {
        if (!session.name) return;
        try {
          if (session.provider === "claude" && session.claudeSessionId) {
            await renameClaudeSession(
              session.worktreePath ?? session.projectPath,
              session.claudeSessionId,
              session.name,
            );
          } else if (session.provider === "codex" && session.claudeSessionId) {
            await renameCodexSession(session.claudeSessionId, session.name);
          }
        } catch (err) {
          console.warn(`[session] Failed to re-persist session name on session end:`, err);
        }
      });
    }

    if (effectiveProvider === "codex" && codexOptions) {
      session.codexSettings = {
        approvalPolicy: codexOptions.approvalPolicy,
        sandboxMode: codexOptions.sandboxMode,
        model: codexOptions.model,
        modelReasoningEffort: codexOptions.modelReasoningEffort,
        networkAccessEnabled: codexOptions.networkAccessEnabled,
        webSearchMode: codexOptions.webSearchMode,
      };
      // Resume starts know the thread id up front.
      if (codexOptions.threadId) {
        session.claudeSessionId = codexOptions.threadId;
        this.saveWorktreeMapping(session);
      }
    }

    this.sessions.set(id, session);

    if (effectiveProvider === "codex") {
      (proc as CodexProcess).start(effectiveCwd, codexOptions);
    } else {
      (proc as SdkProcess).start(effectiveCwd, options);
    }

    console.log(`[session] Created ${effectiveProvider} session ${id} for ${effectiveCwd}${wtPath ? ` (worktree of ${projectPath})` : ""}`);
    return id;
  }

  get(id: string): SessionInfo | undefined {
    return this.sessions.get(id);
  }

  list(): SessionSummary[] {
    return Array.from(this.sessions.values()).map((s) => {
      const processWithPending = s.process as {
        getPendingPermission?: () => {
          toolUseId: string;
          toolName: string;
          input: Record<string, unknown>;
        } | undefined;
      };
      const pendingPermission =
        s.status === "waiting_approval"
          ? processWithPending.getPendingPermission?.()
          : undefined;
      return {
        id: s.id,
        provider: s.provider,
        projectPath: s.projectPath,
        claudeSessionId: s.claudeSessionId,
        name: s.name,
        status: s.status,
        createdAt: s.createdAt.toISOString(),
        lastActivityAt: s.lastActivityAt.toISOString(),
        gitBranch: s.gitBranch,
        lastMessage: this.extractLastMessage(s),
        messageCount: (s.pastMessages?.length ?? 0) + s.history.length,
        worktreePath: s.worktreePath,
        worktreeBranch: s.worktreeBranch,
        permissionMode:
          s.process instanceof SdkProcess
            ? s.process.permissionMode
            : s.process instanceof CodexProcess
              ? (s.process.collaborationMode === "plan"
                ? "plan"
                : s.process.approvalPolicy === "never"
                  ? "bypassPermissions"
                  : "acceptEdits")
              : undefined,
        codexSettings: s.codexSettings,
        pendingPermission,
      };
    });
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
          // Handle string content (defensive — normally array)
          if (typeof msg.content === "string") {
            return msg.content.replace(/\s+/g, " ").trim().slice(0, 100);
          }
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

  /** Save worktree mapping when a provider session ID is available. */
  private saveWorktreeMapping(session: SessionInfo): void {
    if (this.worktreeStore && session.claudeSessionId && session.worktreePath && session.worktreeBranch) {
      this.worktreeStore.set(session.claudeSessionId, {
        worktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
        projectPath: session.projectPath,
      });
    }
  }

  /**
   * Rewind files to their state at the specified user message.
   * Delegates to the session's SdkProcess.rewindFiles().
   */
  async rewindFiles(id: string, targetUuid: string, dryRun?: boolean): Promise<RewindFilesResult> {
    const session = this.sessions.get(id);
    if (!session) {
      return { canRewind: false, error: "Session not found" };
    }
    if (session.provider === "codex") {
      return { canRewind: false, error: "Rewind is not supported for Codex sessions" };
    }
    return (session.process as SdkProcess).rewindFiles(targetUuid, dryRun);
  }

  /**
   * Rewind the conversation to a specific point.
   * Stops the current process and restarts with resumeSessionAt.
   *
   * `targetUuid` is a **user message UUID**. The SDK's `resumeSessionAt`
   * expects an **assistant message UUID**, so we look up the assistant
   * message that follows the target user message.
   */
  rewindConversation(
    id: string,
    targetUuid: string,
    onReady: (newSessionId: string) => void,
  ): void {
    const session = this.sessions.get(id);
    if (!session) {
      throw new Error(`Session ${id} not found`);
    }
    if (session.provider === "codex") {
      throw new Error("Rewind is not supported for Codex sessions");
    }

    const claudeSessionId = session.claudeSessionId;
    if (!claudeSessionId) {
      throw new Error("Session has no Claude session ID");
    }

    // resumeSessionAt expects assistant message UUID (per SDK docs).
    // Convert user UUID → following assistant UUID.
    const assistantUuid = this.findAssistantUuidAfterUser(session, targetUuid);
    if (!assistantUuid) {
      throw new Error("Cannot find assistant message after target user message");
    }

    const projectPath = session.projectPath;
    const permissionMode = (session.process as SdkProcess).permissionMode;
    const worktreePath = session.worktreePath;
    const worktreeBranch = session.worktreeBranch;

    // Stop and destroy the current session
    this.destroy(id);

    // Create a new session with resumeSessionAt (assistant UUID)
    const newId = this.create(
      projectPath,
      {
        sessionId: claudeSessionId,
        permissionMode,
        resumeSessionAt: assistantUuid,
      },
      undefined,
      worktreePath ? { existingWorktreePath: worktreePath, worktreeBranch } : undefined,
    );

    onReady(newId);
  }

  /**
   * Find the assistant message UUID that follows a given user message UUID.
   *
   * Searches in-memory history first, then pastMessages (disk history).
   */
  private findAssistantUuidAfterUser(session: SessionInfo, userUuid: string): string | null {
    // 1. Search in-memory history
    let foundUser = false;
    for (const msg of session.history) {
      if (!foundUser) {
        // user_input or tool_result with matching userMessageUuid
        if (
          (msg.type === "user_input" || msg.type === "tool_result") &&
          "userMessageUuid" in msg &&
          msg.userMessageUuid === userUuid
        ) {
          foundUser = true;
        }
        continue;
      }
      // Found user message — look for next assistant
      if (msg.type === "assistant" && "messageUuid" in msg && msg.messageUuid) {
        return msg.messageUuid as string;
      }
    }

    // 2. Search pastMessages (disk history with uuid field)
    if (session.pastMessages) {
      foundUser = false;
      for (const raw of session.pastMessages) {
        const pm = raw as { role?: string; uuid?: string };
        if (!foundUser) {
          if (pm.role === "user" && pm.uuid === userUuid) {
            foundUser = true;
          }
          continue;
        }
        if (pm.role === "assistant" && pm.uuid) {
          return pm.uuid;
        }
      }
    }

    return null;
  }

  /**
   * Read the Claude CLI conversation history file from disk and backfill
   * `userMessageUuid` into in-memory history entries that are missing it.
   *
   * The SDK does not echo user messages via the stream, so in-memory
   * `user_input` entries (pushed by websocket.ts) lack UUIDs.  The disk
   * file, however, always contains UUIDs.  We match by text content.
   *
   * Also re-broadcasts the updated `user_input` message so the Flutter
   * client can update its UserChatEntry.messageUuid values.
   */
  private backfillUserUuidsFromDisk(session: SessionInfo): void {
    if (!session.claudeSessionId || !session.projectPath) return;

    const historyPath = this.findHistoryJsonlPath(session);
    if (!historyPath) return;

    let lines: string[];
    try {
      const raw = readFileSync(historyPath, "utf-8").trim();
      if (!raw) return;
      lines = raw.split("\n");
    } catch {
      // File may not exist yet (e.g., very new session)
      return;
    }

    // Collect user message text→uuid queue from disk.
    // Use an array per text key so duplicate messages ("yes", "ok", etc.)
    // are matched in order rather than collapsed to one UUID.
    const diskUuids = new Map<string, string[]>();
    for (const line of lines) {
      try {
        const entry = JSON.parse(line) as {
          type?: string;
          role?: string;
          uuid?: string;
          message?: { content?: unknown[] };
        };
        if (entry.type !== "user" && entry.role !== "user") continue;
        if (!entry.uuid) continue;

        // Extract text from content array
        const content = entry.message?.content;
        if (!Array.isArray(content)) continue;
        const texts = content
          .filter((c: unknown) => (c as Record<string, unknown>).type === "text")
          .map((c: unknown) => (c as Record<string, unknown>).text as string);
        if (texts.length > 0) {
          const key = texts.join("\n");
          const arr = diskUuids.get(key) ?? [];
          arr.push(entry.uuid);
          diskUuids.set(key, arr);
        }
      } catch {
        // skip malformed lines
      }
    }

    // Backfill UUIDs into in-memory history
    for (const msg of session.history) {
      if (
        msg.type === "user_input" &&
        !("userMessageUuid" in msg && (msg as Record<string, unknown>).userMessageUuid)
      ) {
        const text = (msg as { text?: string }).text;
        const queue = text ? diskUuids.get(text) : undefined;
        if (queue && queue.length > 0) {
          (msg as Record<string, unknown>).userMessageUuid = queue.shift();
          // Re-broadcast so Flutter can update UserChatEntry.messageUuid
          this.onMessage(session.id, msg);
        }
      }
    }
  }

  private findHistoryJsonlPath(session: SessionInfo): string | null {
    if (!session.claudeSessionId) return null;

    const projectsDir = join(homedir(), ".claude", "projects");
    const fileName = `${session.claudeSessionId}.jsonl`;
    const slugCandidates = new Set<string>([
      pathToSlug(session.projectPath),
    ]);

    // Worktree sessions are persisted under the worktree slug, not projectPath.
    if (session.worktreePath) {
      slugCandidates.add(pathToSlug(session.worktreePath));
    }

    for (const slug of slugCandidates) {
      const candidate = join(projectsDir, slug, fileName);
      if (existsSync(candidate)) return candidate;
    }

    // Fallback: scan all project dirs in case metadata paths drift.
    try {
      const entries = readdirSync(projectsDir, { withFileTypes: true });
      for (const entry of entries) {
        if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
        const candidate = join(projectsDir, entry.name, fileName);
        if (existsSync(candidate)) return candidate;
      }
    } catch {
      return null;
    }

    return null;
  }

  /**
   * Rename a running session (in-memory only).
   * Persistent storage is handled by the caller (websocket.ts).
   */
  renameSession(id: string, name: string | null): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.name = name ?? undefined;
    return true;
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
