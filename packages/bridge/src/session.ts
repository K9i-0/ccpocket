import { randomUUID } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  pathToSlug,
  codexUserTurnUuid,
  isCodexUserTurnUuid,
  renameClaudeSession,
  renameCodexSession,
  saveCodexSessionAdditionalWritableRoots,
  saveCodexSessionProfile,
} from "./sessions-index.js";
import {
  SdkProcess,
  type StartOptions,
  type RewindFilesResult,
} from "./sdk-process.js";
import { CodexProcess, type CodexStartOptions } from "./codex-process.js";
import type {
  ServerMessage,
  ProcessStatus,
  AssistantToolUseContent,
  Provider,
  QueuedInputItem,
  CodexGoal,
} from "./parser.js";
import type { ImageRef, ImageStore } from "./image-store.js";
import type { GalleryStore, GalleryImageMeta } from "./gallery-store.js";
import { withDerivedCodexPermissionsMode } from "./codex-permissions.js";
import { createWorktree, worktreeExists } from "./worktree.js";
import type { WorktreeStore } from "./worktree-store.js";
import {
  buildAutoRenameTranscript,
  generateAutoRenameName,
} from "./auto-rename.js";

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
  historyEntries: HistoryEntry[];
  historyRevision: number;
  historyLowWatermark: number;
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
    profile?: string;
    approvalPolicy?: string;
    approvalsReviewer?: string;
    codexPermissionsMode?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    serviceTier?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
    additionalWritableRoots?: string[];
  };
  /** Claude sandbox enabled state (for resume). */
  sandboxEnabled?: boolean;
  /** Codex-only pending input waiting for the next turn. */
  codexQueuedInput?: QueuedCodexInput;
  /** Latest Codex goal state. Kept out of chat history. */
  codexGoal?: CodexGoal | null;
  /** Synthetic Codex user UUIDs waiting for their app-server echo. */
  pendingCodexUserEchoUuids?: Set<string>;
  /** Raw Codex app-server user item ids mapped to valid ccpocket turn UUIDs. */
  codexUserTurnUuidByRawId?: Map<string, string>;
  /** Last Bridge history seq covered by the canonical Codex thread snapshot. */
  codexCanonicalHistoryRevision?: number;
  /** Whether to generate a session name after the first completed turn. */
  autoRename?: boolean;
  /** Prevents automatic rename from running more than once. */
  autoRenameAttempted?: boolean;
}

export interface HistoryEntry {
  seq: number;
  message: ServerMessage;
}

export type HistoryDeltaResult =
  | {
      kind: "delta";
      fromSeq: number;
      toSeq: number;
      entries: HistoryEntry[];
    }
  | {
      kind: "snapshot";
      fromSeq: number;
      toSeq: number;
      entries: HistoryEntry[];
      reason: "compacted" | "reset";
    };

export interface QueuedCodexInput extends QueuedInputItem {
  userMessageUuid?: string;
  images?: Array<{
    base64: string;
    mimeType: string;
  }>;
  imageRefs?: ImageRef[];
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
  worktreePath?: string;
  worktreeBranch?: string;
  permissionMode?: string;
  executionMode?: string;
  planMode?: boolean;
  model?: string;
  codexSettings?: {
    profile?: string;
    approvalPolicy?: string;
    approvalsReviewer?: string;
    codexPermissionsMode?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    serviceTier?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
    additionalWritableRoots?: string[];
  };
  agentNickname?: string;
  agentRole?: string;
  /** Claude sandbox enabled state. */
  sandboxEnabled?: boolean;
  pendingPermission?: {
    toolUseId: string;
    toolName: string;
    input: Record<string, unknown>;
  };
  queuedInput?: QueuedInputItem;
}

const MAX_HISTORY_PER_SESSION = 100;
const MAX_IDLE_SESSIONS = 30;

export type GalleryImageCallback = (meta: GalleryImageMeta) => void;
export type SessionUpdatedCallback = (sessionId: string) => void;

function mergeCodexSettings(
  current: SessionInfo["codexSettings"],
  msg: Extract<ServerMessage, { type: "system" }>,
): SessionInfo["codexSettings"] {
  const model = sanitizeCodexModel(msg.model);
  const hasRuntimePermissionUpdate =
    msg.approvalPolicy !== undefined ||
    msg.approvalsReviewer !== undefined ||
    msg.sandboxMode !== undefined;
  const currentSettings = { ...(current ?? {}) };
  if (hasRuntimePermissionUpdate && msg.codexPermissionsMode === undefined) {
    delete currentSettings.codexPermissionsMode;
  }
  const next = {
    ...currentSettings,
    ...(msg.approvalPolicy !== undefined
      ? { approvalPolicy: msg.approvalPolicy }
      : {}),
    ...(msg.approvalsReviewer !== undefined
      ? { approvalsReviewer: msg.approvalsReviewer }
      : {}),
    ...(msg.codexPermissionsMode !== undefined
      ? { codexPermissionsMode: msg.codexPermissionsMode }
      : {}),
    ...(msg.sandboxMode !== undefined ? { sandboxMode: msg.sandboxMode } : {}),
    ...(model !== undefined ? { model } : {}),
    ...(msg.modelReasoningEffort !== undefined
      ? { modelReasoningEffort: msg.modelReasoningEffort }
      : {}),
    ...(msg.serviceTier !== undefined
      ? { serviceTier: msg.serviceTier }
      : {}),
    ...(msg.networkAccessEnabled !== undefined
      ? { networkAccessEnabled: msg.networkAccessEnabled }
      : {}),
    ...(msg.webSearchMode !== undefined
      ? { webSearchMode: msg.webSearchMode }
      : {}),
    ...(msg.additionalWritableRoots !== undefined
      ? { additionalWritableRoots: msg.additionalWritableRoots }
      : {}),
  };

  return Object.values(next).some((value) => value !== undefined)
    ? next
    : current;
}

function sanitizeCodexModel(model: unknown): string | undefined {
  if (typeof model !== "string") return undefined;
  const normalized = model.trim();
  if (!normalized || normalized === "codex") return undefined;
  return normalized;
}

function publicQueuedInput(item?: QueuedCodexInput): QueuedInputItem | undefined {
  if (!item) return undefined;
  return {
    itemId: item.itemId,
    text: item.text,
    createdAt: item.createdAt,
    ...(item.updatedAt ? { updatedAt: item.updatedAt } : {}),
    ...(item.imageCount ? { imageCount: item.imageCount } : {}),
    ...(item.skills?.length ? { skills: item.skills } : {}),
    ...(item.mentions?.length ? { mentions: item.mentions } : {}),
  };
}

export class SessionManager {
  private sessions = new Map<string, SessionInfo>();
  private onMessage: (sessionId: string, msg: ServerMessage) => void;
  private imageStore: ImageStore | null;
  private galleryStore: GalleryStore | null;
  private onGalleryImage: GalleryImageCallback | null;
  private worktreeStore: WorktreeStore | null;
  private onSessionUpdated: SessionUpdatedCallback | null;

  /** Cache slash commands per project path for early loading on subsequent sessions. */
  private commandCache = new Map<
    string,
    {
      slashCommands: string[];
      skills: string[];
      skillMetadata?: Array<Record<string, unknown>>;
      apps: string[];
      appMetadata?: Array<Record<string, unknown>>;
      plugins: string[];
      pluginMetadata?: Array<Record<string, unknown>>;
    }
  >();

  constructor(
    onMessage: (sessionId: string, msg: ServerMessage) => void,
    imageStore?: ImageStore,
    galleryStore?: GalleryStore,
    onGalleryImage?: GalleryImageCallback,
    worktreeStore?: WorktreeStore,
    onSessionUpdated?: SessionUpdatedCallback,
  ) {
    this.onMessage = onMessage;
    this.imageStore = imageStore ?? null;
    this.galleryStore = galleryStore ?? null;
    this.onGalleryImage = onGalleryImage ?? null;
    this.worktreeStore = worktreeStore ?? null;
    this.onSessionUpdated = onSessionUpdated ?? null;
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
    const proc =
      effectiveProvider === "codex" ? new CodexProcess() : new SdkProcess();

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
        console.log(
          `[session] Created worktree at ${wtPath} (branch: ${wtBranch})`,
        );
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
        cwd: effectiveCwd,
        encoding: "utf-8",
      }).trim();
    } catch {
      /* not a git repo */
    }

    const session: SessionInfo = {
      id,
      process: proc,
      provider: effectiveProvider,
      history: [],
      historyEntries: [],
      historyRevision: 0,
      historyLowWatermark: 1,
      pastMessages:
        pastMessages && pastMessages.length > 0 ? pastMessages : undefined,
      projectPath,
      status: "starting",
      createdAt: new Date(),
      lastActivityAt: new Date(),
      gitBranch,
      worktreePath: wtPath,
      worktreeBranch: wtBranch,
      autoRename:
        options?.autoRename === true &&
        !options.sessionId &&
        !options.continueMode &&
        !codexOptions?.threadId,
      // Pre-populate claudeSessionId for resumed sessions so that get_history
      // can return it immediately (before the SDK sends a system/result event).
      claudeSessionId: options?.sessionId,
    };
    if (effectiveProvider === "codex") {
      this.seedCodexPastUserTurnUuidMap(session);
    }

    // Cache tool_use id → name for enriching tool_result messages
    const toolUseNames = new Map<string, string>();

    proc.on("message", async (msg) => {
      try {
        session.lastActivityAt = new Date();
        const previousProviderSessionId = session.claudeSessionId;

        if (msg.type === "goal_state") {
          session.codexGoal = msg.goal;
          this.onMessage(id, msg);
          return;
        }

        if (
          msg.type === "system" &&
          (msg.subtype === "init" || msg.subtype === "supported_commands") &&
          (msg.slashCommands ||
            msg.skills ||
            msg.skillMetadata ||
            msg.apps ||
            msg.appMetadata ||
            msg.plugins ||
            msg.pluginMetadata)
        ) {
          this.commandCache.set(projectPath, {
            slashCommands:
              msg.slashCommands ??
              this.commandCache.get(projectPath)?.slashCommands ??
              [],
            skills:
              msg.skills ?? this.commandCache.get(projectPath)?.skills ?? [],
            skillMetadata:
              (msg.skillMetadata as
                | Array<Record<string, unknown>>
                | undefined) ??
              this.commandCache.get(projectPath)?.skillMetadata,
            apps: msg.apps ?? this.commandCache.get(projectPath)?.apps ?? [],
            appMetadata:
              (msg.appMetadata as
                | Array<Record<string, unknown>>
                | undefined) ??
              this.commandCache.get(projectPath)?.appMetadata,
            plugins:
              msg.plugins ?? this.commandCache.get(projectPath)?.plugins ?? [],
            pluginMetadata:
              (msg.pluginMetadata as
                | Array<Record<string, unknown>>
                | undefined) ??
              this.commandCache.get(projectPath)?.pluginMetadata,
          });
        }

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
        } else {
          // Codex: capture thread_id for session tracking and worktree restore.
          if (msg.type === "system" && "sessionId" in msg && msg.sessionId) {
            session.claudeSessionId = msg.sessionId;
            this.saveWorktreeMapping(session);
            if (session.codexSettings?.profile) {
              void saveCodexSessionProfile(
                msg.sessionId,
                session.codexSettings.profile,
              );
            }
            if (session.codexSettings?.additionalWritableRoots) {
              void saveCodexSessionAdditionalWritableRoots(
                msg.sessionId,
                session.codexSettings.additionalWritableRoots,
              );
            }
          }
          if (msg.type === "system") {
            session.codexSettings = mergeCodexSettings(
              session.codexSettings,
              msg,
            );
          }
          const messageModel = sanitizeCodexModel(
            msg.type === "assistant" ? msg.message.model : undefined,
          );
          if (msg.type === "assistant" && messageModel) {
            session.codexSettings = {
              ...(session.codexSettings ?? {}),
              model: messageModel,
            };
          }
        }

        if (
          session.claudeSessionId &&
          session.claudeSessionId !== previousProviderSessionId
        ) {
          this.onSessionUpdated?.(session.id);
        }

        // Extract images from tool_result content for both Claude and Codex.
        if (msg.type === "tool_result" && this.imageStore) {
          const paths = this.imageStore.extractImagePaths(msg.content);
          if (paths.length > 0) {
            const images = await this.imageStore.registerImages(
              paths,
              session.projectPath,
            );
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
            const imageBlocks = (
              msg.rawContentBlocks as Array<Record<string, unknown>>
            ).filter(
              (c) =>
                c.type === "image" &&
                (c.source as Record<string, unknown>)?.type === "base64",
            );

            if (imageBlocks.length > 0) {
              const existingImages = msg.images ?? [];
              const newImages: ImageRef[] = [];

              for (const block of imageBlocks) {
                const source = block.source as Record<string, unknown>;
                if (
                  typeof source?.data !== "string" ||
                  typeof source?.media_type !== "string"
                )
                  continue;
                const b64Data = source.data as string;
                const mimeType = source.media_type as string;
                const ref = this.imageStore.registerFromBase64(
                  b64Data,
                  mimeType,
                );
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

        // Don't add streaming deltas to history
        let mergedUserInput = false;
        let historyMsg: ServerMessage = msg;
        if (msg.type !== "stream_delta" && msg.type !== "thinking_delta") {
          if (this.shouldSuppressCodexCanonicalUserEcho(session, msg)) {
            return;
          }
          const mergedMsg = this.mergeUserInputIntoHistory(session, msg);
          if (mergedMsg) {
            mergedUserInput = true;
            historyMsg = mergedMsg;
          } else {
            historyMsg = this.buildHistoryProcessMessage(session, msg);
            this.appendHistoryToSession(session, historyMsg);
          }
        }

        this.onMessage(
          id,
          this.buildLiveProcessMessage(session, historyMsg, mergedUserInput),
        );

        // After a result (turn complete), backfill UUIDs from disk.
        // The SDK does not echo user messages via the stream, so
        // in-memory user_input entries lack UUIDs.  The disk
        // conversation file always has them.
        if (msg.type === "result") {
          this.backfillUserUuidsFromDisk(session);
          this.scheduleAutoRename(session);
        }
      } catch (err) {
        console.error(
          `[session] Error processing message for session ${id}:`,
          err,
        );
      }
    });

    proc.on("status", (status) => {
      session.status = status;
      if (status === "idle") {
        this.evictStaleIdleSessions();
      }
    });

    if (proc instanceof CodexProcess) {
      proc.on("input_ready", () => {
        this.drainCodexQueue(session);
      });
    }

    proc.on("exit", () => {
      session.status = "idle";
      session.codexQueuedInput = undefined;
      // Add status message to history so it stays in sync with session.status
      this.appendHistoryToSession(session, {
        type: "status",
        status: "idle",
      } as ServerMessage);
      if (session.provider === "codex") {
        this.broadcastCodexQueue(session);
      }
      this.evictStaleIdleSessions();
    });

    // Retry name persistence after the SDK/CLI has flushed transcript files.
    // This covers early renames that happened before the provider session id
    // or JSONL file was available.
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
          console.warn(
            `[session] Failed to re-persist session name on session end:`,
            err,
          );
        }
      });
    }

    // Store Claude sandbox state for resume
    if (effectiveProvider === "claude" && options?.sandboxEnabled != null) {
      session.sandboxEnabled = options.sandboxEnabled;
    }

    if (effectiveProvider === "codex" && codexOptions) {
      session.codexSettings = {
        profile: codexOptions.profile,
        approvalPolicy: codexOptions.approvalPolicy,
        approvalsReviewer: codexOptions.approvalsReviewer,
        codexPermissionsMode: codexOptions.codexPermissionsMode,
        sandboxMode: codexOptions.sandboxMode,
        model: codexOptions.model,
        modelReasoningEffort: codexOptions.modelReasoningEffort,
        serviceTier: codexOptions.serviceTier,
        networkAccessEnabled: codexOptions.networkAccessEnabled,
        webSearchMode: codexOptions.webSearchMode,
        additionalWritableRoots: codexOptions.additionalWritableRoots,
      };
      // Resume starts know the thread id up front.
      if (codexOptions.threadId) {
        session.claudeSessionId = codexOptions.threadId;
        this.saveWorktreeMapping(session);
        if (codexOptions.profile) {
          void saveCodexSessionProfile(codexOptions.threadId, codexOptions.profile);
        }
        if (codexOptions.additionalWritableRoots) {
          void saveCodexSessionAdditionalWritableRoots(
            codexOptions.threadId,
            codexOptions.additionalWritableRoots,
          );
        }
      }
    }

    if (effectiveProvider === "codex") {
      (proc as CodexProcess).start(effectiveCwd, codexOptions);
    } else {
      (proc as SdkProcess).start(effectiveCwd, options);
    }

    // Add session to Map only after proc.start() succeeds.
    // If start() throws, no zombie session is left behind.
    this.sessions.set(id, session);
    this.evictStaleIdleSessions();

    console.log(
      `[session] Created ${effectiveProvider} session ${id} for ${effectiveCwd}${wtPath ? ` (worktree of ${projectPath})` : ""}`,
    );
    return id;
  }

  get(id: string): SessionInfo | undefined {
    return this.sessions.get(id);
  }

  appendHistory(sessionId: string, msg: ServerMessage): HistoryEntry | undefined {
    const session = this.sessions.get(sessionId);
    if (!session) return undefined;
    const entry = this.appendHistoryToSession(session, msg);
    this.markPendingCodexUserEcho(session, msg);
    return entry;
  }

  getHistorySince(
    sessionId: string,
    sinceSeq: number,
  ): HistoryDeltaResult | undefined {
    const session = this.sessions.get(sessionId);
    if (!session) return undefined;

    const toSeq = session.historyRevision;
    const entries = session.historyEntries;
    if (entries.length === 0) {
      return {
        kind: "delta",
        fromSeq: toSeq + 1,
        toSeq,
        entries: [],
      };
    }

    const firstSeq = entries[0].seq;
    if (sinceSeq < firstSeq - 1) {
      return {
        kind: "snapshot",
        fromSeq: firstSeq,
        toSeq,
        entries: [...entries],
        reason: "compacted",
      };
    }

    const deltaEntries = entries.filter((entry) => entry.seq > sinceSeq);
    return {
      kind: "delta",
      fromSeq: deltaEntries[0]?.seq ?? toSeq + 1,
      toSeq,
      entries: deltaEntries,
    };
  }

  list(): SessionSummary[] {
    return Array.from(this.sessions.values()).map((s) => {
      const codexSettings = s.process instanceof CodexProcess
        ? withDerivedCodexPermissionsMode(
            s.codexSettings ??
              (s.process.codexPermissionsMode
                ? { codexPermissionsMode: s.process.codexPermissionsMode }
                : undefined),
          )
        : s.codexSettings;
      const processWithPending = s.process as {
        getPendingPermission?: () =>
          | {
              toolUseId: string;
              toolName: string;
              input: Record<string, unknown>;
            }
          | undefined;
      };
      const pendingPermission =
        s.status === "waiting_approval"
          ? processWithPending.getPendingPermission?.()
          : undefined;
      const executionMode =
        s.process instanceof SdkProcess
          ? s.process.permissionMode === "bypassPermissions"
            ? "fullAccess"
            : s.process.permissionMode === "acceptEdits"
              ? "acceptEdits"
              : "default"
          : s.process instanceof CodexProcess
            ? (codexSettings?.approvalPolicy ?? s.process.approvalPolicy) ===
              "never"
              ? "fullAccess"
              : "default"
            : undefined;
      const planMode =
        s.process instanceof SdkProcess
          ? s.process.permissionMode === "plan"
          : s.process instanceof CodexProcess
            ? s.process.collaborationMode === "plan"
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
        worktreePath: s.worktreePath,
        worktreeBranch: s.worktreeBranch,
        permissionMode:
          s.process instanceof SdkProcess
            ? s.process.permissionMode
            : s.process instanceof CodexProcess
              ? s.process.collaborationMode === "plan"
                ? "plan"
                : (codexSettings?.approvalPolicy ??
                    s.process.approvalPolicy) === "never"
                  ? "bypassPermissions"
                  : "acceptEdits"
              : undefined,
        executionMode,
        planMode,
        model: s.process instanceof SdkProcess ? s.process.model : undefined,
        codexSettings,
        agentNickname:
          s.process instanceof CodexProcess
            ? (s.process.agentNickname ?? undefined)
            : undefined,
        agentRole:
          s.process instanceof CodexProcess
            ? (s.process.agentRole ?? undefined)
            : undefined,
        sandboxEnabled: s.sandboxEnabled,
        pendingPermission,
        queuedInput:
          s.provider === "codex"
            ? publicQueuedInput(s.codexQueuedInput)
            : undefined,
      };
    });
  }

  private appendHistoryToSession(
    session: SessionInfo,
    msg: ServerMessage,
  ): HistoryEntry {
    const entry = {
      seq: session.historyRevision + 1,
      message: msg,
    };
    (msg as Record<string, unknown>).historySeq = entry.seq;
    session.historyRevision = entry.seq;
    session.history.push(msg);
    session.historyEntries.push(entry);
    this.trimHistory(session);
    return entry;
  }

  private mergeUserInputIntoHistory(
    session: SessionInfo,
    msg: ServerMessage,
  ): ServerMessage | null {
    if (msg.type !== "user_input") return null;

    for (let i = session.history.length - 1; i >= 0; i--) {
      const current = session.history[i];
      if (current.type !== "user_input") continue;
      if (!this.isSameUserInput(session, current, msg)) continue;

      const mergedMsg = {
        ...current,
        userMessageUuid: this.mergeUserMessageUuid(current, msg),
        timestamp:
          ("timestamp" in current && current.timestamp) ||
          ("timestamp" in msg ? msg.timestamp : undefined),
      } as ServerMessage;

      const entry = session.historyEntries[i];
      if (entry) {
        (mergedMsg as Record<string, unknown>).historySeq = entry.seq;
        entry.message = mergedMsg;
      }
      session.history[i] = mergedMsg;
      this.clearPendingCodexUserEcho(session, current);
      this.clearPendingCodexUserEcho(session, msg);
      return mergedMsg;
    }

    return null;
  }

  private buildLiveProcessMessage(
    session: SessionInfo,
    msg: ServerMessage,
    mergedUserInput: boolean,
  ): ServerMessage {
    if (
      session.provider === "codex" &&
      msg.type === "user_input" &&
      !mergedUserInput &&
      "userMessageUuid" in msg &&
      msg.userMessageUuid
    ) {
      // Current mobile builds treat a user_input with userMessageUuid as a UUID
      // backfill for an optimistic local message.  New remote turns need to be
      // added as chat entries, while history still keeps the Codex item id.
      const { userMessageUuid: _, ...liveMsg } = msg;
      return liveMsg as ServerMessage;
    }
    return msg;
  }

  private shouldSuppressCodexCanonicalUserEcho(
    session: SessionInfo,
    msg: ServerMessage,
  ): boolean {
    if (session.provider !== "codex" || msg.type !== "user_input") {
      return false;
    }
    const rawId = "userMessageUuid" in msg ? msg.userMessageUuid : undefined;
    if (!rawId || isCodexUserTurnUuid(rawId)) return false;
    const canonicalUuid = session.codexUserTurnUuidByRawId?.get(rawId);
    if (!canonicalUuid) return false;
    return this.hasPastCodexUserMessage(session, canonicalUuid);
  }

  private seedCodexPastUserTurnUuidMap(session: SessionInfo): void {
    for (const message of session.pastMessages ?? []) {
      if (!message || typeof message !== "object") continue;
      const item = message as {
        role?: unknown;
        uuid?: unknown;
        rawItemId?: unknown;
        isMeta?: unknown;
      };
      if (
        item.role !== "user" ||
        item.isMeta === true ||
        typeof item.rawItemId !== "string" ||
        typeof item.uuid !== "string"
      ) {
        continue;
      }
      session.codexUserTurnUuidByRawId ??= new Map<string, string>();
      session.codexUserTurnUuidByRawId.set(item.rawItemId, item.uuid);
    }
  }

  private hasPastCodexUserMessage(
    session: SessionInfo,
    uuid: string,
  ): boolean {
    return (session.pastMessages ?? []).some((message) => {
      if (!message || typeof message !== "object") return false;
      const item = message as {
        role?: unknown;
        uuid?: unknown;
        isMeta?: unknown;
      };
      return item.role === "user" && item.uuid === uuid && item.isMeta !== true;
    });
  }

  private buildHistoryProcessMessage(
    session: SessionInfo,
    msg: ServerMessage,
  ): ServerMessage {
    if (session.provider !== "codex" || msg.type !== "user_input") return msg;
    const uuid = "userMessageUuid" in msg ? msg.userMessageUuid : undefined;
    if (!uuid || isCodexUserTurnUuid(uuid)) return msg;
    return {
      ...msg,
      userMessageUuid: this.codexUserTurnUuidForRawItem(session, uuid),
    } as ServerMessage;
  }

  private isSameUserInput(
    session: SessionInfo,
    existing: ServerMessage,
    incoming: ServerMessage,
  ): boolean {
    if (existing.type !== "user_input" || incoming.type !== "user_input") {
      return false;
    }

    const existingClientId =
      "clientMessageId" in existing ? existing.clientMessageId : undefined;
    const incomingClientId =
      "clientMessageId" in incoming ? incoming.clientMessageId : undefined;
    if (existingClientId && incomingClientId) {
      return existingClientId === incomingClientId;
    }

    const existingUuid =
      "userMessageUuid" in existing ? existing.userMessageUuid : undefined;
    const incomingUuid =
      "userMessageUuid" in incoming ? incoming.userMessageUuid : undefined;
    if (existingUuid && incomingUuid && existingUuid === incomingUuid) {
      return true;
    }

    if (session.provider !== "codex" && !existingUuid && incomingUuid) {
      return true;
    }

    if (existing.text !== incoming.text) return false;
    const existingHasImageCount = "imageCount" in existing;
    const incomingHasImageCount = "imageCount" in incoming;
    if (existingHasImageCount && incomingHasImageCount) {
      const existingImages = existing.imageCount ?? 0;
      const incomingImages = incoming.imageCount ?? 0;
      if (existingImages !== incomingImages) return false;
    }
    if (isCodexUserTurnUuid(existingUuid) || isCodexUserTurnUuid(incomingUuid)) {
      return (
        this.isPendingCodexUserEcho(session, existingUuid) ||
        this.isPendingCodexUserEcho(session, incomingUuid)
      );
    }
    return !existingUuid || !incomingUuid;
  }

  private mergeUserMessageUuid(
    existing: ServerMessage,
    incoming: ServerMessage,
  ): string | undefined {
    const existingUuid =
      existing.type === "user_input" && "userMessageUuid" in existing
        ? existing.userMessageUuid
        : undefined;
    const incomingUuid =
      incoming.type === "user_input" && "userMessageUuid" in incoming
        ? incoming.userMessageUuid
        : undefined;
    if (isCodexUserTurnUuid(existingUuid)) {
      return existingUuid;
    }
    if (isCodexUserTurnUuid(incomingUuid)) {
      return incomingUuid;
    }
    return existingUuid || incomingUuid;
  }

  private markPendingCodexUserEcho(
    session: SessionInfo,
    msg: ServerMessage,
  ): void {
    if (session.provider !== "codex" || msg.type !== "user_input") return;
    const uuid = "userMessageUuid" in msg ? msg.userMessageUuid : undefined;
    if (!isCodexUserTurnUuid(uuid)) return;
    session.pendingCodexUserEchoUuids ??= new Set<string>();
    session.pendingCodexUserEchoUuids.add(uuid);
  }

  private clearPendingCodexUserEcho(
    session: SessionInfo,
    msg: ServerMessage,
  ): void {
    if (session.provider !== "codex" || msg.type !== "user_input") return;
    const uuid = "userMessageUuid" in msg ? msg.userMessageUuid : undefined;
    if (!isCodexUserTurnUuid(uuid)) return;
    session.pendingCodexUserEchoUuids?.delete(uuid);
  }

  private isPendingCodexUserEcho(
    session: SessionInfo,
    uuid: string | undefined,
  ): boolean {
    return (
      isCodexUserTurnUuid(uuid) &&
      (session.pendingCodexUserEchoUuids?.has(uuid) ?? false)
    );
  }

  private codexUserTurnUuidForRawItem(
    session: SessionInfo,
    rawId: string,
  ): string {
    session.codexUserTurnUuidByRawId ??= new Map<string, string>();
    const existing = session.codexUserTurnUuidByRawId.get(rawId);
    if (existing) return existing;
    const uuid = this.nextCodexUserTurnUuid(session);
    session.codexUserTurnUuidByRawId.set(rawId, uuid);
    return uuid;
  }

  private nextCodexUserTurnUuid(session: SessionInfo): string {
    let maxOrdinal = 0;
    let userTurnCount = 0;

    const observe = (uuid?: string): void => {
      userTurnCount += 1;
      if (!isCodexUserTurnUuid(uuid)) return;
      const ordinal = Number(uuid.slice("codex:user-turn:".length));
      if (Number.isInteger(ordinal)) {
        maxOrdinal = Math.max(maxOrdinal, ordinal);
      }
    };

    for (const message of session.pastMessages ?? []) {
      if (!message || typeof message !== "object") continue;
      const item = message as {
        role?: unknown;
        uuid?: unknown;
        isMeta?: unknown;
      };
      if (item.role !== "user" || item.isMeta === true) continue;
      observe(typeof item.uuid === "string" ? item.uuid : undefined);
    }

    for (const message of session.history) {
      if (message.type !== "user_input") continue;
      observe(
        "userMessageUuid" in message ? message.userMessageUuid : undefined,
      );
    }
    if (session.codexQueuedInput) {
      observe(session.codexQueuedInput.userMessageUuid);
    }
    return codexUserTurnUuid(Math.max(maxOrdinal, userTurnCount) + 1);
  }

  private trimHistory(session: SessionInfo): void {
    while (session.history.length > MAX_HISTORY_PER_SESSION) {
      // Keep the retained in-memory history as a chronological tail.  The
      // mobile client renders history snapshots directly; preferentially
      // preserving user_input/system entries makes long sessions degrade into
      // a run of user bubbles after compaction.
      session.history.shift();
      session.historyEntries.shift();
    }

    session.historyLowWatermark =
      session.historyEntries[0]?.seq ?? session.historyRevision + 1;
  }

  private scheduleAutoRename(session: SessionInfo): void {
    if (!this.shouldAutoRename(session)) return;
    session.autoRenameAttempted = true;
    setTimeout(() => {
      void this.autoRenameSession(session).catch((err) => {
        console.warn(
          `[session] Failed to auto-rename session ${session.id}:`,
          err,
        );
      });
    }, 0);
  }

  private shouldAutoRename(session: SessionInfo): boolean {
    if (!session.autoRename || session.autoRenameAttempted || session.name) {
      return false;
    }
    if (this.isInternalAutoRenameSession(session)) return false;
    return buildAutoRenameTranscript(session.history) !== null;
  }

  private isInternalAutoRenameSession(session: SessionInfo): boolean {
    if (session.codexSettings?.model === "codex-auto-review") return true;
    const firstUser = session.history.find((msg) => msg.type === "user_input");
    return (
      firstUser?.type === "user_input" &&
      firstUser.text.startsWith(
        "The following is the Codex agent history whose request action",
      )
    );
  }

  private async autoRenameSession(session: SessionInfo): Promise<void> {
    if (session.name) return;
    const transcript = buildAutoRenameTranscript(session.history);
    if (!transcript) return;

    const name = generateAutoRenameName({
      provider: session.provider,
      projectPath: session.worktreePath ?? session.projectPath,
      model:
        session.provider === "claude"
          ? session.process instanceof SdkProcess
            ? session.process.model
            : undefined
          : session.codexSettings?.model,
      transcript,
    });
    if (!name || session.name) return;

    const persisted = await this.persistSessionName(session, name);
    if (!persisted || session.name) return;
    session.name = name;
    this.onSessionUpdated?.(session.id);
  }

  private async persistSessionName(
    session: SessionInfo,
    name: string,
  ): Promise<boolean> {
    if (session.provider === "claude" && session.claudeSessionId) {
      await renameClaudeSession(
        session.worktreePath ?? session.projectPath,
        session.claudeSessionId,
        name,
      );
      return true;
    }

    if (session.provider !== "codex") return false;
    if (session.process instanceof CodexProcess) {
      try {
        await session.process.renameThread(name);
        return true;
      } catch (err) {
        console.warn(`[session] Failed to auto-rename Codex thread:`, err);
      }
    }
    if (session.claudeSessionId) {
      await renameCodexSession(session.claudeSessionId, name);
      return true;
    }
    return false;
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
          const content = msg.content as
            | Array<Record<string, unknown>>
            | undefined;
          const textBlock = content?.find((c) => c.type === "text");
          if (textBlock?.text)
            return (textBlock.text as string)
              .replace(/\s+/g, " ")
              .trim()
              .slice(0, 100);
        }
      }
    }
    return "";
  }

  queueCodexInput(id: string, input: QueuedCodexInput): boolean {
    const session = this.sessions.get(id);
    if (!session || session.provider !== "codex") return false;
    if (session.codexQueuedInput) return false;
    session.codexQueuedInput = input;
    session.lastActivityAt = new Date();
    this.broadcastCodexQueue(session);
    return true;
  }

  updateCodexQueuedInput(
    id: string,
    itemId: string,
    text: string,
    options?: {
      skills?: Array<{ name: string; path: string }>;
      mentions?: Array<{ name: string; path: string }>;
    },
  ): boolean {
    const session = this.sessions.get(id);
    if (!session || session.provider !== "codex") return false;
    const current = session.codexQueuedInput;
    if (!current || current.itemId !== itemId) return false;
    session.codexQueuedInput = {
      ...current,
      text,
      updatedAt: new Date().toISOString(),
      skills: options?.skills,
      mentions: options?.mentions,
    };
    session.lastActivityAt = new Date();
    this.broadcastCodexQueue(session);
    return true;
  }

  cancelCodexQueuedInput(id: string, itemId: string): boolean {
    const session = this.sessions.get(id);
    if (!session || session.provider !== "codex") return false;
    if (!session.codexQueuedInput || session.codexQueuedInput.itemId !== itemId) {
      return false;
    }
    session.codexQueuedInput = undefined;
    session.lastActivityAt = new Date();
    this.broadcastCodexQueue(session);
    return true;
  }

  async steerCodexQueuedInput(
    id: string,
    itemId: string,
  ): Promise<{ ok: true } | { ok: false; error: string }> {
    const session = this.sessions.get(id);
    if (!session || session.provider !== "codex") {
      return { ok: false, error: "No active Codex session." };
    }
    const queued = session.codexQueuedInput;
    if (!queued || queued.itemId !== itemId) {
      return { ok: false, error: "Queued message not found." };
    }
    if (!(session.process instanceof CodexProcess)) {
      return { ok: false, error: "No active Codex process." };
    }

    try {
      await session.process.steerInputStructured(queued.text, {
        images: queued.images,
        skills: queued.skills,
        mentions: queued.mentions,
      });
    } catch (err) {
      return {
        ok: false,
        error: err instanceof Error ? err.message : String(err),
      };
    }

    session.codexQueuedInput = undefined;
    session.lastActivityAt = new Date();
    this.broadcastCodexQueue(session);

    const userMsg = this.buildQueuedUserInputMessage(queued);
    this.appendHistoryToSession(session, userMsg);
    this.markPendingCodexUserEcho(session, userMsg);
    this.onMessage(session.id, userMsg);
    return { ok: true };
  }

  private broadcastCodexQueue(session: SessionInfo): void {
    const item = publicQueuedInput(session.codexQueuedInput);
    this.onMessage(session.id, {
      type: "conversation_queue",
      sessionId: session.id,
      limit: 1,
      items: item ? [item] : [],
    });
  }

  private drainCodexQueue(session: SessionInfo): void {
    if (session.provider !== "codex") return;
    const queued = session.codexQueuedInput;
    if (!queued || !(session.process instanceof CodexProcess)) return;
    if (!session.process.isWaitingForInput) return;

    session.codexQueuedInput = undefined;
    this.broadcastCodexQueue(session);

    const userMsg = this.buildQueuedUserInputMessage(queued);
    this.appendHistoryToSession(session, userMsg);
    this.markPendingCodexUserEcho(session, userMsg);
    this.onMessage(session.id, userMsg);

    session.process.sendInputStructured(queued.text, {
      images: queued.images,
      skills: queued.skills,
      mentions: queued.mentions,
    });
  }

  private buildQueuedUserInputMessage(queued: QueuedCodexInput): ServerMessage {
    return {
      type: "user_input",
      text: queued.text,
      ...(queued.userMessageUuid ? { userMessageUuid: queued.userMessageUuid } : {}),
      timestamp: new Date().toISOString(),
      ...(queued.imageCount ? { imageCount: queued.imageCount } : {}),
      ...(queued.imageRefs ? { images: queued.imageRefs } : {}),
    } as ServerMessage;
  }

  getCachedCommands(
    projectPath: string,
  ):
    | {
        slashCommands: string[];
        skills: string[];
        skillMetadata?: Array<Record<string, unknown>>;
        apps: string[];
        appMetadata?: Array<Record<string, unknown>>;
        plugins: string[];
        pluginMetadata?: Array<Record<string, unknown>>;
      }
    | undefined {
    return this.commandCache.get(projectPath);
  }

  /** Get worktree store for external use (e.g., resume_session in websocket.ts). */
  getWorktreeStore(): WorktreeStore | null {
    return this.worktreeStore;
  }

  /** Save worktree mapping when a provider session ID is available. */
  private saveWorktreeMapping(session: SessionInfo): void {
    if (
      this.worktreeStore &&
      session.claudeSessionId &&
      session.worktreePath &&
      session.worktreeBranch
    ) {
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
  async rewindFiles(
    id: string,
    targetUuid: string,
    dryRun?: boolean,
  ): Promise<RewindFilesResult> {
    const session = this.sessions.get(id);
    if (!session) {
      return { canRewind: false, error: "Session not found" };
    }
    if (session.provider === "codex") {
      return {
        canRewind: false,
        error: "Rewind is not supported for Codex sessions",
      };
    }
    return (session.process as SdkProcess).rewindFiles(targetUuid, dryRun);
  }

  /**
   * Rewind the conversation to just before a specific user message.
   * Stops the current process and restarts with resumeSessionAt pointing at
   * the assistant message before the selected user message. If the selected
   * message is the first turn, there is no previous assistant boundary, so a
   * fresh empty Claude session is created.
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

    const assistantUuid = this.findAssistantUuidBeforeUser(session, targetUuid);

    const projectPath = session.projectPath;
    const permissionMode = (session.process as SdkProcess).permissionMode;
    const worktreePath = session.worktreePath;
    const worktreeBranch = session.worktreeBranch;

    // Stop and destroy the current session
    this.destroy(id);

    // Create a new session with resumeSessionAt (assistant UUID). When there
    // is no previous assistant, start empty rather than keeping the selected
    // user turn in history.
    const newId = this.create(
      projectPath,
      assistantUuid
        ? {
            sessionId: claudeSessionId,
            permissionMode,
            resumeSessionAt: assistantUuid,
          }
        : { permissionMode },
      undefined,
      worktreePath
        ? { existingWorktreePath: worktreePath, worktreeBranch }
        : undefined,
    );

    onReady(newId);
  }

  /**
   * Find the assistant message UUID immediately before a given user message UUID.
   *
   * Searches in-memory history first, then pastMessages (disk history).
   */
  private findAssistantUuidBeforeUser(
    session: SessionInfo,
    userUuid: string,
  ): string | null {
    // 1. Search in-memory history
    let previousAssistantUuid: string | null = null;
    for (const msg of session.history) {
      if (msg.type === "assistant" && "messageUuid" in msg && msg.messageUuid) {
        previousAssistantUuid = msg.messageUuid as string;
        continue;
      }
      if (
        (msg.type === "user_input" || msg.type === "tool_result") &&
        "userMessageUuid" in msg &&
        msg.userMessageUuid === userUuid
      ) {
        return previousAssistantUuid;
      }
    }

    // 2. Search pastMessages (disk history with uuid field)
    if (session.pastMessages) {
      previousAssistantUuid = null;
      for (const raw of session.pastMessages) {
        const pm = raw as { role?: string; uuid?: string };
        if (pm.role === "assistant" && pm.uuid) {
          previousAssistantUuid = pm.uuid;
          continue;
        }
        if (pm.role === "user" && pm.uuid === userUuid) {
          return previousAssistantUuid;
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
          .filter(
            (c: unknown) => (c as Record<string, unknown>).type === "text",
          )
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
        !(
          "userMessageUuid" in msg &&
          (msg as Record<string, unknown>).userMessageUuid
        )
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
    const slugCandidates = new Set<string>([pathToSlug(session.projectPath)]);

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
    session.autoRenameAttempted = true;
    return true;
  }

  destroy(id: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    // Remove first so synchronous status/exit events from stop() cannot try to
    // evict the same session recursively.
    this.sessions.delete(id);
    session.process.stop();
    session.process.removeAllListeners();
    console.log(`[session] Destroyed session ${id}`);
    return true;
  }

  private evictStaleIdleSessions(): void {
    const staleIdleSessions = Array.from(this.sessions.values())
      .filter((session) => session.status === "idle")
      .sort(
        (left, right) =>
          left.lastActivityAt.getTime() - right.lastActivityAt.getTime(),
      )
      .slice(0, Math.max(0, this.idleSessionCount() - MAX_IDLE_SESSIONS));

    for (const session of staleIdleSessions) {
      console.log(
        `[session] Evicting idle session ${session.id} (last active ${session.lastActivityAt.toISOString()})`,
      );
      this.destroy(session.id);
    }
    if (staleIdleSessions.length > 0) {
      this.onSessionUpdated?.(staleIdleSessions.at(-1)!.id);
    }
  }

  private idleSessionCount(): number {
    let count = 0;
    for (const session of this.sessions.values()) {
      if (session.status === "idle") count += 1;
    }
    return count;
  }

  destroyAll(): void {
    for (const [id] of this.sessions) {
      this.destroy(id);
    }
  }
}
