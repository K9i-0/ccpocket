import { hasGitHead } from "./git-project-state.js";
import { performanceMessage } from "./performance-mode.js";
import type { Server as HttpServer } from "node:http";
import { randomUUID } from "node:crypto";
import { execFile, execFileSync } from "node:child_process";
import { WebSocketServer, WebSocket } from "ws";
import {
  SessionManager,
  type HistoryEntry,
  type SessionInfo,
} from "./session.js";
import {
  SdkProcess,
  type ClaudeEffortLevel,
  type ClaudeModelMetadata,
} from "./sdk-process.js";
import {
  CodexProcess,
  type CodexModelMetadata,
  type CodexThreadSummary,
} from "./codex-process.js";
import {
  AntigravityProcess,
  getAntigravityConfig,
  type AntigravityCatalog,
  type AntigravityConfig,
} from "./antigravity-process.js";
import { AntigravityStore } from "./antigravity-store.js";
import {
  antigravityRecentSessions,
  fetchAntigravityCatalog,
  listAntigravitySessions,
  type AntigravityRecentSession,
  type AntigravitySessionEntry,
} from "./antigravity-sessions.js";
import {
  type CodexServiceTierMetadata,
} from "./codex-service-tier.js";
import { stopManagedCodexAppServers } from "./codex-transport.js";
import {
  parseClientMessage,
  type ClientMessage,
  type DebugTraceEvent,
  type Provider,
  type ServerMessage,
} from "./parser.js";
import {
  CONTENT_SEARCH_MAX_FILES,
  withRecentSessionMetadataSearchMatch,
} from "./recent-session-search.js";
import { CodexThreadSnapshot } from "./codex-thread-snapshot.js";
import {
  BRIDGE_PROTOCOL_MAX_VERSION,
  BRIDGE_PROTOCOL_MIN_VERSION,
  clientProtocolRange,
  negotiateProtocolVersion,
} from "./protocol-version.js";
import {
  getAllRecentSessions,
  type SessionHistoryMessage,
  getCodexSessionIndexMetadata,
  loadCodexSessionNames,
  renameClaudeSession,
  renameCodexSession,
} from "./sessions-index.js";
import type { ImageStore } from "./image-store.js";
import {
  createAssistantImageResolver,
  type AssistantImageResolver,
} from "./markdown-images.js";
import type { MediaStore } from "./media-store.js";
import {
  type UploadStore,
} from "./upload-store.js";
import type { GalleryStore } from "./gallery-store.js";
import type { ProjectHistory } from "./project-history.js";
import {
  type ResolvedWorkspace,
  type WorkspaceStore,
} from "./workspace-store.js";
import { ArchiveStore } from "./archive-store.js";
import { WorktreeStore } from "./worktree-store.js";
import { DebugTraceStore } from "./debug-trace-store.js";
import { RecordingStore } from "./recording-store.js";
import { PushRelayClient } from "./push-relay.js";
import type { FirebaseAuthClient } from "./firebase-auth.js";
import { type PushLocale } from "./push-i18n.js";
import {
  fetchAntigravityUsage,
  type UsageInfo,
} from "./usage.js";
import type { PromptHistoryBackupStore } from "./prompt-history-backup.js";
import type { PromptHistoryStore } from "./prompt-history-store.js";
import { getPackageVersion } from "./version.js";
import { tokensMatch } from "./bridge-auth.js";
import { BackgroundCompletionGate } from "./background-completion-gate.js";
import {
  withDerivedCodexPermissionsMode,
} from "./codex-permissions.js";
import {
  type SystemServerMessage,
  type ResultServerMessage,
  BACKGROUND_COMPLETION_SETTLE_MS,
  type InputClientMessage,
  type ResumeClientMessage,
  type ResumeOperation,
  RESUME_OPERATION_TIMEOUT_MS,
  RESUME_COMPLETED_TTL_MS,
  FALLBACK_CLAUDE_MODEL_OPTIONS,
  FALLBACK_CLAUDE_MODELS,
  FALLBACK_CLAUDE_MODEL_EFFORTS,
  type ClaudeModelOption,
  FALLBACK_CODEX_MODELS,
  fallbackCodexReasoningEfforts,
  fallbackCodexServiceTiers,
  CODEX_RECENT_THREAD_SOURCE_KINDS,
  BRIDGE_PROTOCOL_CAPABILITIES,
  ANTIGRAVITY_PROTOCOL_CAPABILITIES,
  ANTIGRAVITY_CATALOG_TTL_MS,
  OPT_IN_SERVER_MESSAGES,
  isRecord,
  errorMessageOf,
  envFlagEnabled,
  positiveEnvInt,
  nonNegativeEnvInt,
  normalizePositiveLimit,
  normalizeNonNegativeLimit,
} from "./websocket/shared.js";
import {
  codexThreadToRecentSession,
  type RecentSessionsListing,
  pinnedSessionKeysForRecentRequest,
  pinnedOnlySessionKeys,
  recentSessionsCoalescingKey,
  isRecentContentSearch,
  recentSessionsFiltersRequested,
  buildRecentSessionPredicate,
  mergeRecentSessionPages,
} from "./websocket/recent-sessions.js";
import {
  CONNECT_METADATA_REFRESH_COOLDOWN_MS,
  DEFAULT_FILE_LIST_MAX_ENTRIES,
  DEFAULT_FILE_LIST_MAX_BYTES,
  DEFAULT_FILE_DOWNLOAD_MAX_BYTES,
  DEFAULT_FILE_UPLOAD_MAX_BYTES,
  DEFAULT_DELTA_BATCH_MS,
  DEFAULT_DELTA_BATCH_MAX_CHARS,
} from "./websocket/shared.js";
import {
  handleGetDiff,
  handleGetDiffImage,
  handleListWorktrees,
  handleRemoveWorktree,
  handleGitStage,
  handleGitUnstage,
  handleGitUnstageHunks,
  handleGitCommit,
  handleGitPush,
  handleGitBranches,
  handleGitCreateBranch,
  handleGitCheckoutBranch,
  handleGitRevertFile,
  handleGitRevertHunks,
  handleGitFetch,
  handleGitPull,
  handleGitStatus,
  handleGitRemoteStatus,
  handleGithubList,
} from "./websocket/handlers/git.js";
import {
  handlePrepareFileDownload,
  handlePrepareFileUpload,
  handleFinalizeFileUpload,
  handleCancelFileUpload,
  handleRevealFileLocal,
  handleReadFile,
  handleListFiles,
} from "./websocket/handlers/files.js";
import {
  handleListProjectHistory,
  handleRemoveProjectHistory,
  handleListProjects,
  handleBootstrapProject,
  handleTrustProject,
  handleCreateProject,
  handleUpdateProject,
  handleRemoveProject,
  handleListDirectory,
} from "./websocket/handlers/projects.js";
import {
  handleBackupPromptHistory,
  handleRestorePromptHistory,
  handleGetPromptHistoryBackupInfo,
  handleRecordPromptHistory,
  handleSyncPromptHistory,
  handleMutatePromptHistory,
  handleImportPromptHistoryV1,
} from "./websocket/handlers/prompt-history.js";
import {
  handlePushRegister,
  handlePushUnregister,
} from "./websocket/handlers/push.js";
import {
  handleGetDebugBundle,
  handleGetUsage,
  handleListRecordings,
  handleGetRecording,
  handleListWindows,
  handleTakeScreenshot,
} from "./websocket/handlers/diagnostics.js";
import {
  handleApprove,
  handleApproveAlways,
  handleReject,
  handleAnswer,
  handleInstallToolSuggestion,
} from "./websocket/handlers/approvals.js";
import {
  handleSetCodexRecovery,
  handleGetGoal,
  handleSetGoal,
  handleClearGoal,
} from "./websocket/handlers/codex-control.js";
import {
  handleSetAntigravityModel,
  handleSetAntigravitySettings,
  handleGetAntigravityCatalog,
  handleSetCodexModel,
  handleSetCodexSpeed,
  handleSetClaudeSettings,
} from "./websocket/handlers/session-settings.js";
import {
  handleListSessions,
  handleStopSession,
  handleResolveSessionLink,
  handleRefreshBranch,
  handleListRecentSessions,
  handleArchiveSession,
  handleRenameSession,
} from "./websocket/handlers/session-catalog.js";
import {
  handleGetHistory,
  handleGetSessionTranscript,
  handleGetSessionContext,
  handleGetHistoryDelta,
  handleListGallery,
  handleGetMessageImages,
} from "./websocket/handlers/session-history.js";
import {
  handleRewindDryRun,
  handleRewind,
  handleFork,
} from "./websocket/handlers/rewind-fork.js";
import {
  handleInput,
  handleUpdateQueuedInput,
  handleCancelQueuedInput,
  handleSteerQueuedInput,
  handleInterrupt,
  handleEditMessage,
} from "./websocket/handlers/session-input.js";
import {
  handleSetPermissionMode,
  handleSetSandboxMode,
} from "./websocket/handlers/session-modes.js";
import { handleStart } from "./websocket/handlers/session-start.js";
import { handleResumeSession } from "./websocket/handlers/session-resume.js";
import {
  extractSessionIdFromClientMessage,
  extractSessionIdFromServerMessage,
  recordDebugEvent,
  summarizeClientMessage,
  summarizeServerMessage,
  summarizeOutboundMessage,
  pruneDebugEvents,
} from "./websocket/debug-trace.js";
import {
  isPathReadable,
  isCanonicalPathReadable,
} from "./websocket/file-access.js";
import {
  codexThreadIdForSession,
  applyCodexCanonicalHistoryBaseline,
  historyValueKey,
  codexHistoryToServerMessages,
  sessionHistoryText,
  sessionHistoryAssistantContent,
  sessionHistorySingleToolUseId,
  registerPastUserMessageImages,
  resolveAssistantImages,
  registerPastToolResultImages,
  getCodexThreadHistoryFromRpc,
} from "./websocket/session-history.js";
import {
  getFirstSession,
  sendPromptHistoryStatus,
  sendConversationQueue,
} from "./websocket/session-state.js";
import {
  listFilteredAntigravitySessions,
  listPinnedCodexSessions,
  listSnapshotOnlyCodexSessions,
  listWorkspaceFilteredIndexedSessions,
  listRecentSessionsRaw,
  enrichRecentSessionWorkspace,
} from "./websocket/recent-sessions.js";
import {
  runtimeSessionsWithWorkspaces,
  persistPendingSessionWorkspace,
  workspaceForRuntimeSession,
  legacyProjectHistoryProjects,
} from "./websocket/workspaces.js";
import {
  loadClaudeModels,
  applyFallbackClaudeModels,
  readCodexModels,
  readCodexAutoReviewDisabled,
  applyFallbackCodexModels,
} from "./websocket/models.js";
import {
  maybeSendPushNotification,
  keepsWorkingInBackground,
  sendCompletionPush,
} from "./websocket/push-notifications.js";
export {
  pinnedSessionKeysForRecentRequest,
  pinnedOnlySessionKeys,
  recentSessionsCoalescingKey,
  isRecentContentSearch,
  recentSessionsFiltersRequested,
  buildRecentSessionPredicate,
} from "./websocket/recent-sessions.js";
export { downloadMimeType } from "./websocket/shared.js";
export type { ClaudeModelOption } from "./websocket/shared.js";

export interface BridgeServerOptions {
  /**
   * Reports whether the Antigravity CLI can be used. Left out, Antigravity is
   * treated as unavailable (tests); the Bridge entry point passes the real probe.
   */
  detectAntigravity?: () => Promise<boolean>;
  /** Reads what a new Antigravity session offers. Tests replace it. */
  fetchAntigravityCatalog?: () => Promise<AntigravityCatalog>;
  /** Reads Antigravity's plan quota from the CLI. Tests replace it. */
  fetchAntigravityUsage?: (bin: string) => Promise<UsageInfo[]>;
  /** Antigravity config override for tests. */
  antigravityConfig?: AntigravityConfig;
  /** Where names and models of Antigravity conversations are kept. */
  antigravityStore?: AntigravityStore;
  server: HttpServer;
  apiKey?: string;
  allowedDirs?: string[];
  /** Extra roots that file preview, download, and reveal may read. */
  readOnlyDirs?: string[];
  fileDownloadAllowAllPaths?: boolean;
  imageStore?: ImageStore;
  mediaStore?: MediaStore;
  uploadStore?: UploadStore;
  galleryStore?: GalleryStore;
  projectHistory?: ProjectHistory;
  workspaceStore?: WorkspaceStore;
  debugTraceStore?: DebugTraceStore;
  recordingStore?: RecordingStore;
  firebaseAuth?: FirebaseAuthClient;
  promptHistoryBackup?: PromptHistoryBackupStore;
  promptHistoryStore?: PromptHistoryStore;
  platform?: NodeJS.Platform;
  fileListMaxEntries?: number;
  fileListMaxBytes?: number;
  fileDownloadMaxBytes?: number;
  fileUploadMaxBytes?: number;
  deltaBatchMs?: number;
  deltaBatchMaxChars?: number;
}

type DeltaServerMessage = Extract<
  ServerMessage,
  { type: "stream_delta" | "thinking_delta" }
>;

interface DeltaBatch {
  messages: DeltaServerMessage[];
  timer: NodeJS.Timeout;
  charCount: number;
}

interface DeltaTextChunk {
  text: string;
  charCount: number;
}

export class BridgeWebSocketServer {

  private wss: WebSocketServer;
  sessionManager: SessionManager;
  private apiKey: string | null;
  allowedDirs: string[];
  readOnlyDirs: string[];
  assistantImageResolver: AssistantImageResolver | null = null;
  fileDownloadAllowAllPaths: boolean;
  imageStore: ImageStore | null;
  mediaStore: MediaStore | null;
  uploadStore: UploadStore | null;
  galleryStore: GalleryStore | null;
  projectHistory: ProjectHistory | null;
  workspaceStore: WorkspaceStore | null;
  pendingSessionWorkspaces = new Map<string, ResolvedWorkspace>();
  debugTraceStore: DebugTraceStore;
  recordingStore: RecordingStore | null;
  worktreeStore: WorktreeStore;
  pushRelay: PushRelayClient;
  completionGate: BackgroundCompletionGate<ResultServerMessage>;
  promptHistoryBackup: PromptHistoryBackupStore | null;
  promptHistoryStore: PromptHistoryStore | null;

  recentSessionsRequestIds = new WeakMap<WebSocket, number>();
  private recentSessionsInFlight = new Map<
    string,
    Promise<RecentSessionsListing>
  >();
  /**
   * Transcript files the last content search page read, per query (offset
   * excluded). Later pages read that many plus one more budget, so "load
   * more" keeps going past the per-request file bound instead of rereading
   * the same files.
   */
  private contentSearchDepth = new Map<string, { files: number; at: number }>();
  /** Every Codex thread, for threads only kept as compressed rollouts. */
  codexThreadSnapshot = new CodexThreadSnapshot((onPage) =>
    this.loadAllCodexThreads(onPage),
  );
  debugEvents = new Map<string, DebugTraceEvent[]>();
  notifiedPermissionToolUses = new Map<string, Set<string>>();
  archiveStore: ArchiveStore;
  readonly antigravityStore: AntigravityStore;
  antigravityUsageCache: { at: number; usage: UsageInfo[] } | undefined;
  private antigravityUsageRead: Promise<UsageInfo[]> | undefined;
  private readonly loadAntigravityUsage: (bin: string) => Promise<UsageInfo[]>;
  /** A catalog read in flight, shared by everyone who asks meanwhile. */
  private antigravityCatalogRead: Promise<AntigravityCatalog> | undefined;
  private readonly loadAntigravityCatalog: () => Promise<AntigravityCatalog>;
  codexProfiles: string[] = [];
  defaultCodexProfile: string | undefined;
  codexAutoReviewDisabled = false;
  /** `agy acp` is installed; gates the `antigravity_v1` capability. */
  private antigravityAvailable = false;
  private readonly detectAntigravity: (() => Promise<boolean>) | undefined;
  private readonly antigravityConfigOverride: AntigravityConfig | undefined;
  private antigravitySessionsCache:
    | { at: number; entries: Promise<AntigravitySessionEntry[]> }
    | undefined;
  codexAutoReviewPolicyLoaded = false;
  private codexMetadataRequest: Promise<void> | null = null;
  private lastConnectMetadataRefreshAt: number | null = null;
  claudeModels: string[] = FALLBACK_CLAUDE_MODELS;
  claudeModelOptions: ClaudeModelOption[] = FALLBACK_CLAUDE_MODEL_OPTIONS;
  claudeModelEfforts: Record<string, ClaudeEffortLevel[]> = {
    ...FALLBACK_CLAUDE_MODEL_EFFORTS,
  };
  private claudeModelsRequest: Promise<void> | null = null;
  codexModels: string[] = FALLBACK_CODEX_MODELS;
  codexModelReasoningEfforts: Record<string, string[]> =
    Object.fromEntries(
      FALLBACK_CODEX_MODELS.map((model) => [
        model,
        fallbackCodexReasoningEfforts(model),
      ]),
    );
  codexModelServiceTiers: Record<string, string[]> = Object.fromEntries(
    FALLBACK_CODEX_MODELS.map((model) => [
      model,
      fallbackCodexServiceTiers(model),
    ]),
  );
  codexModelServiceTierMetadata: Record<
    string,
    CodexServiceTierMetadata[]
  > = {};
  /** FCM token → push notification locale */
  tokenLocales = new Map<string, PushLocale>();
  tokenPrivacyMode = new Map<string, boolean>();
  pushTokenGeneration = new Map<string, number>();
  pushTokenOperations = new Map<string, Promise<void>>();
  nextPushTokenGeneration = 0;
  failSetPermissionMode = envFlagEnabled(
    "BRIDGE_FAIL_SET_PERMISSION_MODE",
  );
  failSetSandboxMode = envFlagEnabled("BRIDGE_FAIL_SET_SANDBOX_MODE");
  readonly fileListMaxEntries: number;
  readonly fileListMaxBytes: number;
  readonly fileDownloadMaxBytes: number;
  readonly fileUploadMaxBytes: number;
  private readonly deltaBatchMs: number;
  private readonly deltaBatchMaxChars: number;
  private deltaBatches = new Map<WebSocket, Map<string, DeltaBatch>>();
  platform: NodeJS.Platform;
  private deliveryPreferences = new WeakMap<
    WebSocket,
    { enabled: boolean; sessions: Record<string, boolean> }
  >();
  private activityTimes = new WeakMap<WebSocket, Map<string, number>>();

  private performanceEnabled(ws: WebSocket, msg: Record<string, unknown>): boolean {
    const prefs = this.deliveryPreferences.get(ws);
    if (!prefs || typeof msg.sessionId !== "string") return false;
    return Object.hasOwn(prefs.sessions, msg.sessionId)
      ? prefs.sessions[msg.sessionId]
      : prefs.enabled;
  }

  clientSupportedServerMessages = new WeakMap<WebSocket, Set<string>>();
  private clientProtocolVersions = new WeakMap<WebSocket, number>();
  private rejectedProtocolClients = new WeakSet<WebSocket>();
  pendingClaudeResumeInputs = new WeakMap<
    WebSocket,
    Map<string, InputClientMessage[]>
  >();
  private resumeOperations = new Map<string, ResumeOperation>();

  constructor(options: BridgeServerOptions) {
    this.detectAntigravity = options.detectAntigravity;
    this.antigravityConfigOverride = options.antigravityConfig;
    this.loadAntigravityUsage =
      options.fetchAntigravityUsage ?? fetchAntigravityUsage;
    this.loadAntigravityCatalog =
      options.fetchAntigravityCatalog ?? (() => fetchAntigravityCatalog());
    const {
      server,
      apiKey,
      allowedDirs,
      imageStore,
      mediaStore,
      uploadStore,
      galleryStore,
      projectHistory,
      workspaceStore,
      debugTraceStore,
      recordingStore,
      firebaseAuth,
      promptHistoryBackup,
      promptHistoryStore,
      platform,
      fileListMaxEntries,
      fileListMaxBytes,
      fileDownloadMaxBytes,
      fileUploadMaxBytes,
      deltaBatchMs,
      deltaBatchMaxChars,
    } = options;
    this.apiKey = apiKey ?? null;
    this.allowedDirs = allowedDirs ?? [];
    this.readOnlyDirs = options.readOnlyDirs ?? [];
    this.fileDownloadAllowAllPaths = options.fileDownloadAllowAllPaths ?? false;
    this.imageStore = imageStore ?? null;
    this.mediaStore = mediaStore ?? null;
    this.uploadStore = uploadStore ?? null;
    this.galleryStore = galleryStore ?? null;
    this.projectHistory = projectHistory ?? null;
    this.workspaceStore = workspaceStore ?? null;
    this.debugTraceStore = debugTraceStore ?? new DebugTraceStore();
    this.recordingStore = recordingStore ?? null;
    this.worktreeStore = new WorktreeStore();
    this.pushRelay = new PushRelayClient({ firebaseAuth });
    this.completionGate = new BackgroundCompletionGate<ResultServerMessage>({
      settleMs: BACKGROUND_COMPLETION_SETTLE_MS,
      isSettled: (sessionId) => {
        const session = this.sessionManager.get(sessionId);
        return (
          !!session &&
          session.status === "idle" &&
          !keepsWorkingInBackground(this, sessionId)
        );
      },
      release: (sessionId, completion) =>
        sendCompletionPush(this, sessionId, completion),
    });
    this.promptHistoryBackup = promptHistoryBackup ?? null;
    this.promptHistoryStore = promptHistoryStore ?? null;
    this.platform = platform ?? process.platform;
    this.fileListMaxEntries = normalizePositiveLimit(
      fileListMaxEntries,
      positiveEnvInt(
        "BRIDGE_FILE_LIST_MAX_ENTRIES",
        DEFAULT_FILE_LIST_MAX_ENTRIES,
      ),
    );
    this.fileListMaxBytes = normalizePositiveLimit(
      fileListMaxBytes,
      positiveEnvInt(
        "BRIDGE_FILE_LIST_MAX_BYTES",
        DEFAULT_FILE_LIST_MAX_BYTES,
      ),
    );
    this.fileDownloadMaxBytes = normalizePositiveLimit(
      fileDownloadMaxBytes,
      positiveEnvInt(
        "BRIDGE_FILE_DOWNLOAD_MAX_SIZE_MB",
        DEFAULT_FILE_DOWNLOAD_MAX_BYTES / 1024 / 1024,
      ) * 1024 * 1024,
    );
    this.fileUploadMaxBytes = normalizePositiveLimit(
      fileUploadMaxBytes,
      positiveEnvInt(
        "BRIDGE_FILE_UPLOAD_MAX_SIZE_MB",
        DEFAULT_FILE_UPLOAD_MAX_BYTES / 1024 / 1024,
      ) * 1024 * 1024,
    );
    this.deltaBatchMs = normalizeNonNegativeLimit(
      deltaBatchMs,
      nonNegativeEnvInt(
        "BRIDGE_DELTA_BATCH_MS",
        DEFAULT_DELTA_BATCH_MS,
      ),
    );
    this.deltaBatchMaxChars = normalizePositiveLimit(
      deltaBatchMaxChars,
      positiveEnvInt(
        "BRIDGE_DELTA_BATCH_MAX_CHARS",
        DEFAULT_DELTA_BATCH_MAX_CHARS,
      ),
    );

    this.archiveStore = new ArchiveStore();
    this.antigravityStore = options.antigravityStore ?? new AntigravityStore();
    void this.antigravityStore.init().catch((err) => {
      console.error("[ws] Failed to initialize Antigravity store:", err);
    });
    void this.debugTraceStore.init().catch((err) => {
      console.error("[ws] Failed to initialize debug trace store:", err);
    });
    if (this.recordingStore) {
      void this.recordingStore.init().catch((err) => {
        console.error("[ws] Failed to initialize recording store:", err);
      });
    }
    void this.archiveStore.init().catch((err) => {
      console.error("[ws] Failed to initialize archive store:", err);
    });
    if (!this.pushRelay.isConfigured) {
      console.log("[ws] Push relay disabled (Firebase auth not available)");
    } else {
      console.log("[ws] Push relay enabled (Firebase Anonymous Auth)");
    }

    this.wss = new WebSocketServer({
      server,
      perMessageDeflate: {
        serverNoContextTakeover: true,
        clientNoContextTakeover: true,
        threshold: 1024,
        zlibDeflateOptions: { level: 3 },
      },
    });

    this.assistantImageResolver = imageStore
      ? createAssistantImageResolver({
          imageStore,
          isPathReadable: (path) => isPathReadable(this, path),
          isCanonicalPathReadable: (path) => isCanonicalPathReadable(this, path),
        })
      : null;

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
      (sessionId) => {
        void persistPendingSessionWorkspace(this, sessionId);
        this.broadcastSessionList();
      },
    );
    this.sessionManager.setAssistantImageResolver(this.assistantImageResolver);
    this.sessionManager.setAntigravityCompactionHandler(
      (claudeSessionId, record) => {
        void this.antigravityStore.addCompaction(claudeSessionId, record);
      },
    );
    this.sessionManager.setAntigravityPermissionGrantsHandler(
      (claudeSessionId, grants) => {
        void this.antigravityStore.setPermissionGrants(claudeSessionId, grants);
      },
    );

    this.wss.on("connection", (ws, req) => {
      // API key authentication
      if (this.apiKey) {
        const url = new URL(req.url ?? "/", `http://${req.headers.host}`);
        const token = url.searchParams.get("token");
        if (!tokensMatch(token, this.apiKey)) {
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

  buildSessionCreatedMessage(params: {
    sessionId: string;
    provider: Provider;
    projectPath: string;
    session?: SessionInfo;
    permissionMode?: string;
    executionMode?: string;
    planMode?: boolean;
    approvalsReviewer?: string;
    codexPermissionsMode?: string;
    sandboxMode?: string;
    slashCommands?: string[];
    slashCommandDescriptions?: Record<string, string>;
    skills?: string[];
    skillMetadata?: Array<Record<string, unknown>>;
    apps?: string[];
    appMetadata?: Array<Record<string, unknown>>;
    plugins?: string[];
    pluginMetadata?: Array<Record<string, unknown>>;
    sourceSessionId?: string;
    /** The source session keeps running (fork), unlike restarts/rewinds. */
    forked?: boolean;
    resumeRequestId?: string;
    requestId?: string;
  }): SystemServerMessage {
    const {
      sessionId,
      provider,
      projectPath,
      session,
      permissionMode,
      executionMode,
      planMode,
      approvalsReviewer,
      codexPermissionsMode,
      sandboxMode,
      slashCommands,
      slashCommandDescriptions,
      skills,
      skillMetadata,
      apps,
      appMetadata,
      plugins,
      pluginMetadata,
      sourceSessionId,
      resumeRequestId,
      requestId,
    } = params;
    const derivedCodexSettings = provider === "codex"
      ? withDerivedCodexPermissionsMode(session?.codexSettings)
      : session?.codexSettings;
    const workspace = session
      ? workspaceForRuntimeSession(this, session)
      : undefined;

    const msg: SystemServerMessage = {
      type: "system",
      subtype: "session_created",
      sessionId,
      provider,
      projectPath,
      ...(workspace ? { workspace } : {}),
      ...(permissionMode
        ? {
            permissionMode: permissionMode as
              | "default"
              | "auto"
              | "acceptEdits"
              | "bypassPermissions"
              | "plan",
          }
        : {}),
      ...((approvalsReviewer ?? derivedCodexSettings?.approvalsReviewer)
        ? {
            approvalsReviewer:
              approvalsReviewer ?? derivedCodexSettings?.approvalsReviewer,
          }
        : {}),
      ...((codexPermissionsMode ?? derivedCodexSettings?.codexPermissionsMode)
        ? {
            codexPermissionsMode: (codexPermissionsMode ??
              derivedCodexSettings?.codexPermissionsMode) as
              | "default"
              | "autoReview"
              | "fullAccess"
              | "custom",
          }
        : {}),
      ...((executionMode ??
      (session?.process instanceof SdkProcess
        ? session.process.permissionMode === "bypassPermissions"
          ? "fullAccess"
          : session.process.permissionMode === "acceptEdits"
            ? "acceptEdits"
            : "default"
        : session?.process instanceof CodexProcess
          ? session.process.approvalPolicy === "never"
            ? "fullAccess"
            : "default"
          : session?.process instanceof AntigravityProcess
            ? session.process.permissionMode === "bypassPermissions"
              ? "fullAccess"
              : session.process.permissionMode === "acceptEdits"
                ? "acceptEdits"
                : "default"
            : undefined))
        ? {
            executionMode: (executionMode ??
              (session?.process instanceof SdkProcess
                ? session.process.permissionMode === "bypassPermissions"
                  ? "fullAccess"
                  : session.process.permissionMode === "acceptEdits"
                    ? "acceptEdits"
                    : "default"
                : session?.process instanceof CodexProcess
                  ? session.process.approvalPolicy === "never"
                    ? "fullAccess"
                    : "default"
                  : session?.process instanceof AntigravityProcess
                    ? session.process.permissionMode === "bypassPermissions"
                      ? "fullAccess"
                      : session.process.permissionMode === "acceptEdits"
                        ? "acceptEdits"
                        : "default"
                    : undefined)) as "default" | "acceptEdits" | "fullAccess",
          }
        : {}),
      ...((planMode ??
        (session?.process instanceof SdkProcess
          ? session.process.permissionMode === "plan"
          : session?.process instanceof CodexProcess
            ? session.process.collaborationMode === "plan"
            : session?.process instanceof AntigravityProcess
              ? session.process.permissionMode === "plan"
              : undefined)) != null
        ? {
            planMode:
              planMode ??
              (session?.process instanceof SdkProcess
                ? session.process.permissionMode === "plan"
                : session?.process instanceof CodexProcess
                  ? session.process.collaborationMode === "plan"
                  : session?.process instanceof AntigravityProcess
                    ? session.process.permissionMode === "plan"
                    : false),
          }
        : {}),
      ...(sandboxMode ? { sandboxMode } : {}),
      ...(slashCommands ? { slashCommands } : {}),
      ...(slashCommandDescriptions ? { slashCommandDescriptions } : {}),
      ...(skills ? { skills } : {}),
      ...(skillMetadata
        ? {
            skillMetadata:
              skillMetadata as SystemServerMessage["skillMetadata"],
          }
        : {}),
      ...(apps ? { apps } : {}),
      ...(appMetadata
        ? {
            appMetadata:
              appMetadata as SystemServerMessage["appMetadata"],
          }
        : {}),
      ...(plugins ? { plugins } : {}),
      ...(pluginMetadata
        ? {
            pluginMetadata:
              pluginMetadata as SystemServerMessage["pluginMetadata"],
          }
        : {}),
      ...(session?.worktreePath
        ? {
            worktreePath: session.worktreePath,
            worktreeBranch: session.worktreeBranch,
          }
        : {}),
      ...(sourceSessionId ? { sourceSessionId } : {}),
      ...(params.forked ? { forked: true } : {}),
      ...(resumeRequestId ? { resumeRequestId } : {}),
      ...(requestId ? { requestId } : {}),
    };

    if (provider === "codex" && derivedCodexSettings) {
      if (derivedCodexSettings.model !== undefined) {
        msg.model = derivedCodexSettings.model;
      }
      if (derivedCodexSettings.approvalPolicy !== undefined) {
        msg.approvalPolicy = derivedCodexSettings.approvalPolicy;
      }
      if (derivedCodexSettings.codexPermissionsMode !== undefined) {
        msg.codexPermissionsMode = derivedCodexSettings.codexPermissionsMode as
          | "default"
          | "autoReview"
          | "fullAccess"
          | "custom";
      }
      if (derivedCodexSettings.modelReasoningEffort !== undefined) {
        msg.modelReasoningEffort = derivedCodexSettings.modelReasoningEffort;
      }
      if (derivedCodexSettings.serviceTier !== undefined) {
        msg.serviceTier = derivedCodexSettings.serviceTier;
      }
      if (derivedCodexSettings.networkAccessEnabled !== undefined) {
        msg.networkAccessEnabled = derivedCodexSettings.networkAccessEnabled;
      }
      if (derivedCodexSettings.webSearchMode !== undefined) {
        msg.webSearchMode = derivedCodexSettings.webSearchMode;
      }
      if (derivedCodexSettings.additionalWritableRoots !== undefined) {
        msg.additionalWritableRoots =
          derivedCodexSettings.additionalWritableRoots;
      }
    }

    return msg;
  }

  /** Registers past-history images so clients can fetch them by URL. */
  async preparePastHistoryMessages(
    session: SessionInfo,
    messages: readonly unknown[],
  ): Promise<{ pastMessages: unknown[]; historyMessages: ServerMessage[] }> {
    const pastMessages: unknown[] = [];
    const historyMessages: ServerMessage[] = [];

    for (const raw of messages) {
      const msg = raw as Record<string, unknown>;
      if (msg.role === "user") {
        const images = await registerPastUserMessageImages(this, session, msg);
        pastMessages.push(
          images.length > 0
            ? {
                ...msg,
                images,
                imageCount:
                  typeof msg.imageCount === "number"
                    ? Math.max(msg.imageCount, images.length)
                    : images.length,
              }
            : raw,
        );
        continue;
      }

      if (msg.role === "assistant") {
        const images = await resolveAssistantImages(this, session, msg.content);
        pastMessages.push(images.length > 0 ? { ...msg, images } : raw);
        continue;
      }

      if (msg.role !== "tool_result") {
        pastMessages.push(raw);
        continue;
      }

      const content = typeof msg.content === "string" ? msg.content : "";
      const images = await registerPastToolResultImages(this, session, msg);

      pastMessages.push({
        role: "tool_result",
        toolUseId:
          typeof msg.toolUseId === "string"
            ? msg.toolUseId
            : `past-tool-result-${pastMessages.length}`,
        content,
        ...(typeof msg.toolName === "string" ? { toolName: msg.toolName } : {}),
        ...(images.length > 0 ? { images } : {}),
      });
    }

    return { pastMessages, historyMessages };
  }

  async codexCanonicalHistoryEntries(
    session: SessionInfo,
  ): Promise<HistoryEntry[] | null> {
    const threadId = codexThreadIdForSession(session);
    if (!threadId) return null;

    const history = session.codexInitialHistoryPending
      ? ((session.pastMessages ?? []) as SessionHistoryMessage[])
      : await getCodexThreadHistoryFromRpc(
          this,
          threadId,
          session.projectPath,
          session.process as CodexProcess,
        );
    session.claudeSessionId = threadId;

    const messages = await codexHistoryToServerMessages(this, session, history);
    const entries = messages.map((message, index) => ({
      seq: index + 1,
      message,
    }));
    applyCodexCanonicalHistoryBaseline(
      this,
      session,
      history,
      entries,
    );
    session.codexInitialHistoryPending = false;
    return entries;
  }

  codexHistoryMessageIdentityKeys(message: ServerMessage): string[] {
    if (message.type === "context_compaction") {
      return message.id ? [`compaction:${message.id}`] : [];
    }
    if (message.type === "user_input") {
      return message.userMessageUuid ? [`user:${message.userMessageUuid}`] : [];
    }
    if (message.type === "assistant") {
      const assistantId = message.messageUuid ?? message.message.id;
      if (assistantId) return [`assistant:${assistantId}`];
      return [
        `assistant-content:${historyValueKey(message.message.content)}`,
      ];
    }
    if (message.type === "tool_result") {
      if (message.toolUseId) {
        return [`tool-result:${message.toolUseId}:${message.toolName ?? ""}`];
      }
      return [
        `tool-result-content:${message.toolName ?? ""}:${message.content}`,
      ];
    }
    return [];
  }

  async codexHistoryMessageToServerMessage(
    session: SessionInfo,
    item: SessionHistoryMessage,
  ): Promise<ServerMessage | null> {
    if (item.role === "compaction") {
      return {
        type: "context_compaction",
        provider: "codex",
        ...(item.uuid ? { id: item.uuid } : {}),
        ...item.compaction,
        ...(item.timestamp ? { timestamp: item.timestamp } : {}),
      };
    }
    if (item.role === "user") {
      const images = await registerPastUserMessageImages(
        this,
        session,
        item as unknown as Record<string, unknown>,
      );
      const text = sessionHistoryText(item.content);
      if (!text && item.imageCount == null && images.length === 0) return null;
      return {
        type: "user_input",
        text,
        ...(item.uuid ? { userMessageUuid: item.uuid } : {}),
        ...(item.isMeta ? { isMeta: true } : {}),
        ...(item.imageCount != null || images.length > 0
          ? { imageCount: Math.max(item.imageCount ?? 0, images.length) }
          : {}),
        ...(item.timestamp ? { timestamp: item.timestamp } : {}),
        ...(images.length > 0 ? { images } : {}),
      };
    }

    if (item.role === "assistant") {
      const content = sessionHistoryAssistantContent(item.content);
      if (content.length === 0) return null;
      const assistantImages = await resolveAssistantImages(
        this,
        session,
        content,
      );
      const messageId =
        item.uuid ??
        sessionHistorySingleToolUseId(item.content) ??
        randomUUID();
      return {
        type: "assistant",
        message: {
          id: messageId,
          role: "assistant",
          content,
          model: session.codexSettings?.model ?? "",
        },
        ...(item.uuid ? { messageUuid: item.uuid } : {}),
        ...(assistantImages.length > 0 ? { images: assistantImages } : {}),
      };
    }

    const images = await registerPastToolResultImages(
      this,
      session,
      item as unknown as Record<string, unknown>,
    );
    const content = sessionHistoryText(item.content);
    if (!content && images.length === 0) return null;
    return {
      type: "tool_result",
      toolUseId:
        item.toolUseId ?? item.uuid ?? `codex-history-tool-${randomUUID()}`,
      content,
      ...(item.toolName ? { toolName: item.toolName } : {}),
      ...(images.length > 0 ? { images } : {}),
    };
  }

  close(): void {
    console.log("[ws] Shutting down...");
    for (const operation of this.resumeOperations.values()) {
      if (operation.timeout) clearTimeout(operation.timeout);
    }
    this.resumeOperations.clear();
    this.flushAllDeltaBatches();
    this.sessionManager.destroyAll();
    this.flushAllDeltaBatches();
    this.completionGate.dispose();
    stopManagedCodexAppServers();
    this.debugEvents.clear();
    this.wss.close();
  }

  /** Return session count for /health endpoint. */
  get sessionCount(): number {
    return this.sessionManager.list().length;
  }

  /** Return connected WebSocket client count. */
  /** Claude plan usage through a running session, if any. */
  readClaudePlanUsage(): Promise<unknown> {
    return this.sessionManager.readClaudePlanUsage();
  }

  get clientCount(): number {
    return this.wss.clients.size;
  }

  private handleConnection(ws: WebSocket): void {
    // Send session list and project history on connect
    this.refreshConnectionMetadata();
    this.sendSessionList(ws);
    const projects = legacyProjectHistoryProjects(this);
    this.send(ws, { type: "project_history", projects });

    ws.on("message", (data) => {
      if (this.rejectedProtocolClients.has(ws)) return;
      const raw = data.toString();
      const msg = parseClientMessage(raw);

      if (!msg) {
        // Try to extract the message type so the client can decide how to
        // handle the unsupported message (suppress vs show update hint).
        let rawType: string | undefined;
        try {
          rawType = (JSON.parse(raw) as Record<string, unknown>)
            ?.type as string;
        } catch {
          /* ignore */
        }
        if (rawType === "client_capabilities") {
          this.rejectedProtocolClients.add(ws);
          this.send(ws, {
            type: "error",
            errorCode: "incompatible_protocol",
            message: "Client advertised a malformed protocol range.",
            protocolVersion: BRIDGE_PROTOCOL_MAX_VERSION,
            minimumProtocolVersion: BRIDGE_PROTOCOL_MIN_VERSION,
          });
          ws.close(4406, "Incompatible protocol version");
          return;
        }
        console.error(
          "[ws] Unsupported message:",
          rawType ?? raw.slice(0, 200),
        );
        this.send(ws, {
          type: "error",
          errorCode: "unsupported_message",
          message: rawType ?? "unknown",
        });
        return;
      }

      console.log(`[ws] Received: ${msg.type}`);
      this.handleClientMessage(msg, ws).catch((err: unknown) => {
        this.reportClientMessageFailure(ws, msg, err);
      });
    });

    ws.on("close", () => {
      console.log("[ws] Client disconnected");
      this.recentSessionsRequestIds.delete(ws);
      this.discardClientDeltaBatches(ws);
      this.clearPendingClaudeResumeInputs(ws);
    });

    ws.on("error", (err) => {
      console.error("[ws] Client error:", err.message);
    });
  }

  private refreshConnectionMetadata(now = Date.now()): void {
    const lastRefreshAt = this.lastConnectMetadataRefreshAt;
    if (
      lastRefreshAt !== null &&
      now >= lastRefreshAt &&
      now - lastRefreshAt <
        CONNECT_METADATA_REFRESH_COOLDOWN_MS
    ) {
      return;
    }
    this.lastConnectMetadataRefreshAt = now;
    void this.refreshCodexMetadata();
    void this.refreshClaudeModels();
    void this.refreshAntigravityAvailability();
    // Load the Codex thread snapshot before the first search / filter.
    this.codexThreadSnapshot.warm();
  }

  /**
   * Last-resort handler for a rejected handleClientMessage call. Without it an
   * async handler failure becomes an unhandled rejection and terminates the
   * Bridge process.
   */
  private reportClientMessageFailure(
    ws: WebSocket,
    msg: ClientMessage,
    err: unknown,
  ): void {
    const detail = err instanceof Error ? err.message : String(err);
    console.error(`[ws] Failed to handle ${msg.type}:`, err);
    const fields = msg as { sessionId?: unknown; requestId?: unknown };
    try {
      this.send(ws, {
        type: "error",
        message: `Failed to handle ${msg.type}: ${detail}`,
        ...(typeof fields.sessionId === "string"
          ? { sessionId: fields.sessionId }
          : {}),
        ...(typeof fields.requestId === "string"
          ? { requestId: fields.requestId }
          : {}),
      });
    } catch (sendErr) {
      console.error("[ws] Failed to report handler error:", sendErr);
    }
  }

  async handleClientMessage(
    msg: ClientMessage,
    ws: WebSocket,
    echoInput = false,
  ): Promise<void> {
    if (this.rejectedProtocolClients.has(ws)) return;
    if (msg.type === "client_capabilities") {
      const clientRange = clientProtocolRange(msg);
      const selectedProtocolVersion = negotiateProtocolVersion(clientRange);
      if (selectedProtocolVersion === null) {
        this.rejectedProtocolClients.add(ws);
        this.send(ws, {
          type: "error",
          errorCode: "incompatible_protocol",
          protocolVersion: BRIDGE_PROTOCOL_MAX_VERSION,
          minimumProtocolVersion: BRIDGE_PROTOCOL_MIN_VERSION,
          message:
            `Client protocol range ${clientRange.min}-${clientRange.max} `
            + `does not overlap Bridge protocol range `
            + `${BRIDGE_PROTOCOL_MIN_VERSION}-${BRIDGE_PROTOCOL_MAX_VERSION}.`,
        });
        ws.close(4406, "Incompatible protocol version");
        return;
      }
      this.clientProtocolVersions.set(ws, selectedProtocolVersion);
      this.clientSupportedServerMessages.set(
        ws,
        new Set(msg.supportedServerMessages ?? []),
      );
      this.deliveryPreferences.set(ws, {
        enabled: msg.performanceMode ?? false,
        sessions: msg.sessionPerformanceModes ?? {},
      });
      if (msg.deliveryRevision !== undefined) {
        this.send(ws, { type: "performance_mode_state", deliveryRevision: msg.deliveryRevision });
      }
      sendPromptHistoryStatus(this, ws);
      return;
    }

    const incomingSessionId = extractSessionIdFromClientMessage(msg);
    const isActiveRuntimeSession =
      incomingSessionId != null &&
      this.sessionManager.get(incomingSessionId) != null;
    if (incomingSessionId && isActiveRuntimeSession) {
      recordDebugEvent(this, incomingSessionId, {
        direction: "incoming",
        channel: "ws",
        type: msg.type,
        detail: summarizeClientMessage(msg),
      });
      this.recordingStore?.record(incomingSessionId, "incoming", msg);
    }

    switch (msg.type) {
      case "start":
        await handleStart(this, msg, ws);
        break;

      case "input":
        await handleInput(this, msg, ws, echoInput);
        break;

      case "update_queued_input":
        await handleUpdateQueuedInput(this, msg, ws);
        break;

      case "cancel_queued_input":
        await handleCancelQueuedInput(this, msg, ws);
        break;

      case "steer_queued_input":
        await handleSteerQueuedInput(this, msg, ws);
        break;

      case "push_register":
        await handlePushRegister(this, msg, ws);
        break;

      case "push_unregister":
        await handlePushUnregister(this, msg, ws);
        break;

      case "set_permission_mode":
        await handleSetPermissionMode(this, msg, ws);
        break;

      case "set_antigravity_model":
        await handleSetAntigravityModel(this, msg, ws);
        break;

      case "set_antigravity_settings":
        await handleSetAntigravitySettings(this, msg, ws);
        break;

      case "get_antigravity_catalog":
        await handleGetAntigravityCatalog(this, msg, ws);
        break;

      case "set_codex_model":
        await handleSetCodexModel(this, msg, ws);
        break;

      case "set_codex_speed":
        await handleSetCodexSpeed(this, msg, ws);
        break;

      case "set_claude_settings":
        await handleSetClaudeSettings(this, msg, ws);
        break;

      case "set_codex_recovery":
      case "cancel_codex_recovery":
        await handleSetCodexRecovery(this, msg, ws);
        break;

      case "get_goal":
        await handleGetGoal(this, msg, ws);
        break;

      case "set_goal":
        await handleSetGoal(this, msg, ws);
        break;

      case "clear_goal":
        await handleClearGoal(this, msg, ws);
        break;

      case "set_sandbox_mode":
        await handleSetSandboxMode(this, msg, ws);
        break;

      case "approve":
        await handleApprove(this, msg, ws);
        break;

      case "approve_always":
        await handleApproveAlways(this, msg, ws);
        break;

      case "reject":
        await handleReject(this, msg, ws);
        break;

      case "answer":
        await handleAnswer(this, msg, ws);
        break;

      case "install_tool_suggestion":
        await handleInstallToolSuggestion(this, msg, ws);
        break;

      case "list_sessions":
        await handleListSessions(this, msg, ws);
        break;

      case "stop_session":
        await handleStopSession(this, msg, ws);
        break;

      case "get_history":
        await handleGetHistory(this, msg, ws);
        break;

      case "get_session_transcript":
        await handleGetSessionTranscript(this, msg, ws);
        break;

      case "get_session_context":
        await handleGetSessionContext(this, msg, ws);
        break;

      case "resolve_session_link":
        await handleResolveSessionLink(this, msg, ws);
        break;

      case "get_history_delta":
        await handleGetHistoryDelta(this, msg, ws);
        break;

      case "refresh_branch":
        await handleRefreshBranch(this, msg, ws);
        break;

      case "get_debug_bundle":
        await handleGetDebugBundle(this, msg, ws);
        break;

      case "get_usage":
        await handleGetUsage(this, msg, ws);
        break;

      case "list_recent_sessions":
        await handleListRecentSessions(this, msg, ws);
        break;

      case "archive_session":
        await handleArchiveSession(this, msg, ws);
        break;

      case "resume_session":
        await handleResumeSession(this, msg, ws);
        break;

      case "list_gallery":
        await handleListGallery(this, msg, ws);
        break;

      case "get_message_images":
        await handleGetMessageImages(this, msg, ws);
        break;

      case "interrupt":
        await handleInterrupt(this, msg, ws);
        break;

      case "edit_message":
        await handleEditMessage(this, msg, ws);
        break;

      case "list_project_history":
        await handleListProjectHistory(this, msg, ws);
        break;

      case "remove_project_history":
        await handleRemoveProjectHistory(this, msg, ws);
        break;

      case "list_projects":
        await handleListProjects(this, msg, ws);
        break;

      case "bootstrap_project":
        await handleBootstrapProject(this, msg, ws);
        break;
      case "trust_project":
      case "initialize_git":
        await handleTrustProject(this, msg, ws);
        break;
      case "create_project":
        await handleCreateProject(this, msg, ws);
        break;

      case "update_project":
        await handleUpdateProject(this, msg, ws);
        break;

      case "remove_project":
        await handleRemoveProject(this, msg, ws);
        break;

      case "list_directory":
        await handleListDirectory(this, msg, ws);
        break;

      case "prepare_file_download":
        await handlePrepareFileDownload(this, msg, ws);
        break;

      case "prepare_file_upload":
        await handlePrepareFileUpload(this, msg, ws);
        break;

      case "finalize_file_upload":
        await handleFinalizeFileUpload(this, msg, ws);
        break;

      case "cancel_file_upload":
        await handleCancelFileUpload(this, msg, ws);
        break;

      case "reveal_file_local":
      case "reveal_file":
        await handleRevealFileLocal(this, msg, ws);
        break;

      case "read_file":
      case "read_media_file":
      case "read_model_file":
        await handleReadFile(this, msg, ws);
        break;

      case "list_files":
        await handleListFiles(this, msg, ws);
        break;

      case "list_recordings":
        await handleListRecordings(this, msg, ws);
        break;

      case "get_recording":
        await handleGetRecording(this, msg, ws);
        break;

      case "get_diff":
        await handleGetDiff(this, msg, ws);
        break;

      case "get_diff_image":
        await handleGetDiffImage(this, msg, ws);
        break;

      case "list_worktrees":
        await handleListWorktrees(this, msg, ws);
        break;

      case "remove_worktree":
        await handleRemoveWorktree(this, msg, ws);
        break;

      // ---- Git Operations (Phase 1-3) ----

      case "git_stage":
        await handleGitStage(this, msg, ws);
        break;

      case "git_unstage":
        await handleGitUnstage(this, msg, ws);
        break;

      case "git_unstage_hunks":
        await handleGitUnstageHunks(this, msg, ws);
        break;

      case "git_commit":
        await handleGitCommit(this, msg, ws);
        break;

      case "git_push":
        await handleGitPush(this, msg, ws);
        break;

      case "git_branches":
        await handleGitBranches(this, msg, ws);
        break;

      case "git_create_branch":
        await handleGitCreateBranch(this, msg, ws);
        break;

      case "git_checkout_branch":
        await handleGitCheckoutBranch(this, msg, ws);
        break;

      case "git_revert_file":
        await handleGitRevertFile(this, msg, ws);
        break;

      case "git_revert_hunks":
        await handleGitRevertHunks(this, msg, ws);
        break;

      case "git_fetch":
        await handleGitFetch(this, msg, ws);
        break;

      case "git_pull":
        await handleGitPull(this, msg, ws);
        break;

      case "git_status":
        await handleGitStatus(this, msg, ws);
        break;

      case "git_remote_status":
        await handleGitRemoteStatus(this, msg, ws);
        break;

      case "github_list":
      case "github_item":
        await handleGithubList(this, msg, ws);
        break;

      case "rewind_dry_run":
        await handleRewindDryRun(this, msg, ws);
        break;

      case "rewind":
        await handleRewind(this, msg, ws);
        break;

      case "fork":
        await handleFork(this, msg, ws);
        break;

      case "list_windows":
        await handleListWindows(this, msg, ws);
        break;

      case "take_screenshot":
        await handleTakeScreenshot(this, msg, ws);
        break;

      case "backup_prompt_history":
        await handleBackupPromptHistory(this, msg, ws);
        break;

      case "restore_prompt_history":
        await handleRestorePromptHistory(this, msg, ws);
        break;

      case "get_prompt_history_backup_info":
        await handleGetPromptHistoryBackupInfo(this, msg, ws);
        break;

      case "record_prompt_history":
        await handleRecordPromptHistory(this, msg, ws);
        break;

      case "sync_prompt_history":
        await handleSyncPromptHistory(this, msg, ws);
        break;

      case "mutate_prompt_history":
        await handleMutatePromptHistory(this, msg, ws);
        break;

      case "import_prompt_history_v1":
        await handleImportPromptHistoryV1(this, msg, ws);
        break;

      case "rename_session":
        await handleRenameSession(this, msg, ws);
        break;
    }
  }

  private clearPendingClaudeResumeInputs(ws: WebSocket): void {
    this.pendingClaudeResumeInputs.get(ws)?.clear();
    this.pendingClaudeResumeInputs.delete(ws);
    for (const operation of this.resumeOperations.values()) {
      operation.waiters.delete(ws);
    }
  }

  private resumeOperationKey(
    provider: Provider,
    sourceSessionId: string,
  ): string {
    return `${provider}:${sourceSessionId}`;
  }

  private resumeRequestFingerprint(msg: ResumeClientMessage): string {
    return JSON.stringify({
      provider: msg.provider ?? "claude",
      sessionId: msg.sessionId,
      projectPath: msg.projectPath,
      permissionMode: msg.permissionMode,
      executionMode: msg.executionMode,
      approvalPolicy: msg.approvalPolicy,
      approvalsReviewer: msg.approvalsReviewer,
      codexPermissionsMode: msg.codexPermissionsMode,
      planMode: msg.planMode,
      sandboxMode: msg.sandboxMode,
      model: msg.model,
      effort: msg.effort,
      fastMode: msg.claudeFastMode,
      ultracode: msg.claudeUltracode,
      maxTurns: msg.maxTurns,
      maxBudgetUsd: msg.maxBudgetUsd,
      fallbackModel: msg.fallbackModel,
      forkSession: msg.forkSession ?? false,
      persistSession: msg.persistSession,
      profile: msg.profile,
      modelReasoningEffort: msg.modelReasoningEffort,
      serviceTier: msg.serviceTier,
      networkAccessEnabled: msg.networkAccessEnabled,
      webSearchMode: msg.webSearchMode,
      additionalWritableRoots: [...(msg.additionalWritableRoots ?? [])].sort(),
      resumeRequestId: msg.resumeRequestId,
    });
  }

  private clearResumeOperation(key: string, operation: ResumeOperation): void {
    if (operation.timeout) clearTimeout(operation.timeout);
    if (this.resumeOperations.get(key) === operation) {
      this.resumeOperations.delete(key);
    }
  }

  private ensurePendingClaudeResume(
    ws: WebSocket,
    sourceSessionId: string,
  ): void {
    let pendingResumes = this.pendingClaudeResumeInputs.get(ws);
    if (!pendingResumes) {
      pendingResumes = new Map();
      this.pendingClaudeResumeInputs.set(ws, pendingResumes);
    }
    if (!pendingResumes.has(sourceSessionId)) {
      pendingResumes.set(sourceSessionId, []);
    }
  }

  beginResumeOperation(params: {
    ws: WebSocket;
    provider: Provider;
    sourceSessionId: string;
    projectPath: string;
    request: ResumeClientMessage;
  }): { key: string; operationId: string; isOwner: boolean } {
    const { ws, provider, sourceSessionId, projectPath, request } = params;
    const key = this.resumeOperationKey(provider, sourceSessionId);
    const fingerprint = this.resumeRequestFingerprint(request);
    let operation = this.resumeOperations.get(key);
    if (
      operation?.completed &&
      (!this.sessionManager.get(operation.completed.sessionId) ||
        Date.now() - operation.completed.completedAt >
          RESUME_COMPLETED_TTL_MS ||
        operation.fingerprint !== fingerprint ||
        request.forkSession === true)
    ) {
      this.clearResumeOperation(key, operation);
      operation = undefined;
    }

    if (
      operation &&
      !operation.completed &&
      operation.fingerprint !== fingerprint
    ) {
      this.sendResumeFailed(ws, {
        provider,
        sourceSessionId,
        projectPath,
        resumeRequestId: request.resumeRequestId,
      });
      this.send(ws, {
        type: "error",
        message:
          "This session is already being restored with different settings. Wait for it to finish, then try again.",
        sessionId: sourceSessionId,
        ...(request.resumeRequestId
          ? { requestId: request.resumeRequestId }
          : {}),
      });
      return { key, operationId: operation.id, isOwner: false };
    }

    this.send(ws, {
      type: "system",
      subtype: "session_resume_started",
      sourceSessionId,
      provider,
      projectPath,
      ...(request.resumeRequestId
        ? { resumeRequestId: request.resumeRequestId }
        : {}),
    });

    if (provider === "claude") {
      this.ensurePendingClaudeResume(ws, sourceSessionId);
    }

    if (operation) {
      if (operation.completed) {
        this.send(ws, operation.completed.message);
        this.flushPendingClaudeResumeInputs(
          ws,
          sourceSessionId,
          operation.completed.sessionId,
        );
      } else {
        operation.waiters.add(ws);
      }
      return { key, operationId: operation.id, isOwner: false };
    }

    const operationId = randomUUID();
    const newOperation: ResumeOperation = {
      id: operationId,
      provider,
      sourceSessionId,
      projectPath,
      resumeRequestId: request.resumeRequestId,
      fingerprint,
      waiters: new Set([ws]),
    };
    const timeout = setTimeout(() => {
      this.failResumeOperation(
        key,
        operationId,
        "Session restore is taking longer than expected. Please reconnect and try again.",
      );
    }, RESUME_OPERATION_TIMEOUT_MS);
    timeout.unref?.();
    newOperation.timeout = timeout;
    this.resumeOperations.set(key, newOperation);
    return { key, operationId, isOwner: true };
  }

  completeResumeOperation(
    key: string,
    operationId: string,
    sessionId: string,
    message: SystemServerMessage,
  ): boolean {
    const operation = this.resumeOperations.get(key);
    if (!operation || operation.id !== operationId) return false;
    if (operation.timeout) clearTimeout(operation.timeout);
    operation.provisionalSessionId = undefined;
    operation.completed = {
      sessionId,
      message,
      completedAt: Date.now(),
    };
    for (const waiter of operation.waiters) {
      this.send(waiter, message);
      this.flushPendingClaudeResumeInputs(
        waiter,
        operation.sourceSessionId,
        sessionId,
      );
    }
    operation.waiters.clear();
    const timeout = setTimeout(() => {
      this.clearResumeOperation(key, operation);
    }, RESUME_COMPLETED_TTL_MS);
    timeout.unref?.();
    operation.timeout = timeout;
    this.pruneCompletedResumeOperations();
    return true;
  }

  failResumeOperation(
    key: string,
    operationId: string,
    message: string,
    errorCode?: string,
  ): void {
    const operation = this.resumeOperations.get(key);
    if (!operation || operation.id !== operationId) return;
    if (operation.provisionalSessionId) {
      this.sessionManager.destroy(operation.provisionalSessionId);
      operation.provisionalSessionId = undefined;
    }
    this.clearResumeOperation(key, operation);
    for (const waiter of operation.waiters) {
      this.rejectPendingClaudeResumeInputs(
        waiter,
        operation.sourceSessionId,
      );
      this.sendResumeFailed(waiter, operation);
      this.send(waiter, {
        type: "error",
        message,
        sessionId: operation.sourceSessionId,
        ...(operation.resumeRequestId
          ? { requestId: operation.resumeRequestId }
          : {}),
        ...(errorCode ? { errorCode } : {}),
      });
    }
  }

  attachProvisionalResumeSession(
    key: string,
    operationId: string,
    sessionId: string,
  ): boolean {
    const operation = this.resumeOperations.get(key);
    if (!operation || operation.id !== operationId || operation.completed) {
      return false;
    }
    operation.provisionalSessionId = sessionId;
    return true;
  }

  sendResumeFailed(
    ws: WebSocket,
    resume: {
      provider: Provider;
      sourceSessionId: string;
      projectPath: string;
      resumeRequestId?: string;
    },
  ): void {
    this.send(ws, {
      type: "system",
      subtype: "session_resume_failed",
      provider: resume.provider,
      sourceSessionId: resume.sourceSessionId,
      projectPath: resume.projectPath,
      ...(resume.resumeRequestId
        ? { resumeRequestId: resume.resumeRequestId }
        : {}),
    });
  }

  private flushPendingClaudeResumeInputs(
    ws: WebSocket,
    sourceSessionId: string,
    sessionId: string,
  ): void {
    const pendingResumes = this.pendingClaudeResumeInputs.get(ws);
    const queuedInputs = pendingResumes?.get(sourceSessionId) ?? [];
    pendingResumes?.delete(sourceSessionId);
    for (const input of queuedInputs) {
      const message = { ...input, sessionId };
      this.handleClientMessage(message, ws).catch((err: unknown) => {
        this.reportClientMessageFailure(ws, message, err);
      });
    }
  }

  private rejectPendingClaudeResumeInputs(
    ws: WebSocket,
    sourceSessionId: string,
  ): void {
    const pendingResumes = this.pendingClaudeResumeInputs.get(ws);
    const queuedInputs = pendingResumes?.get(sourceSessionId) ?? [];
    pendingResumes?.delete(sourceSessionId);
    for (const input of queuedInputs) {
      if (!input.clientMessageId) continue;
      this.send(ws, {
        type: "input_rejected",
        sessionId: sourceSessionId,
        clientMessageId: input.clientMessageId,
        reason: "Session resume failed",
      });
    }
  }

  private pruneCompletedResumeOperations(): void {
    const completed = [...this.resumeOperations.entries()]
      .filter((entry) => entry[1].completed)
      .sort(
        (a, b) =>
          (a[1].completed?.completedAt ?? 0) -
          (b[1].completed?.completedAt ?? 0),
      );
    while (completed.length > 100) {
      const oldest = completed.shift();
      if (oldest) this.clearResumeOperation(oldest[0], oldest[1]);
    }
  }

  /**
   * Handle rename_session: update in-memory name and persist to CLI storage.
   *
   * Supports both running sessions (by bridge session id) and recent sessions
   * (by provider session id, i.e. claudeSessionId or codex threadId).
   */
  async handleRenameSession(
    ws: WebSocket,
    sessionId: string,
    name: string | null,
    msg: ClientMessage,
  ): Promise<void> {
    // 1. Try running session first
    const runningSession = this.sessionManager.get(sessionId);
    if (runningSession) {
      this.sessionManager.renameSession(sessionId, name);

      // Persist to provider storage
      if (
        runningSession.provider === "claude" &&
        runningSession.claudeSessionId
      ) {
        await renameClaudeSession(
          runningSession.worktreePath ?? runningSession.projectPath,
          runningSession.claudeSessionId,
          name,
        );
      } else if (
        runningSession.provider === "codex" &&
        runningSession.process
      ) {
        try {
          await (
            runningSession.process as import("./codex-process.js").CodexProcess
          ).renameThread(name ?? "");
        } catch (err) {
          console.warn(`[websocket] Failed to rename Codex thread:`, err);
        }
      } else if (
        runningSession.provider === "antigravity" &&
        runningSession.claudeSessionId
      ) {
        // `agy` cannot rename a conversation, so the Bridge keeps the name.
        await this.antigravityStore.setName(runningSession.claudeSessionId, name);
        this.antigravitySessionsCache = undefined;
      }

      this.broadcastSessionList();
      this.send(ws, { type: "rename_result", sessionId, name, success: true });
      return;
    }

    // 2. Recent session (not running) — use provider + providerSessionId + projectPath from message
    const renameMsg = msg as Extract<ClientMessage, { type: "rename_session" }>;
    const provider = renameMsg.provider;
    const providerSessionId = renameMsg.providerSessionId;
    const projectPath = renameMsg.projectPath;

    if (provider === "claude" && providerSessionId && projectPath) {
      const success = await renameClaudeSession(
        projectPath,
        providerSessionId,
        name,
      );
      this.send(ws, { type: "rename_result", sessionId, name, success });
      return;
    }

    // For Codex recent sessions, write directly to session_index.jsonl.
    if (provider === "codex" && providerSessionId) {
      const success = await renameCodexSession(providerSessionId, name);
      this.send(ws, { type: "rename_result", sessionId, name, success });
      return;
    }

    if (provider === "antigravity" && providerSessionId) {
      await this.antigravityStore.setName(providerSessionId, name);
      this.send(ws, { type: "rename_result", sessionId, name, success: true });
      return;
    }

    this.send(ws, { type: "rename_result", sessionId, name, success: false });
  }

  resolveSession(
    sessionId: string | undefined,
  ): SessionInfo | undefined {
    if (sessionId) return this.sessionManager.get(sessionId);
    return getFirstSession(this);
  }

  sendSessionList(ws: WebSocket): void {
    pruneDebugEvents(this);
    const sessions = runtimeSessionsWithWorkspaces(this);
    this.send(ws, {
      type: "session_list",
      sessions,
      allowedDirs: this.allowedDirs,
      claudeModels: this.claudeModels,
      claudeModelOptions: this.claudeModelOptions,
      claudeModelEfforts: this.claudeModelEfforts,
      codexModels: this.codexModels,
      codexModelReasoningEfforts: this.codexModelReasoningEfforts,
      codexModelServiceTiers: this.codexModelServiceTiers,
      codexModelServiceTierMetadata: this.codexModelServiceTierMetadata,
      codexProfiles: this.codexProfiles,
      defaultCodexProfile: this.defaultCodexProfile,
      codexAutoReviewDisabled: this.codexAutoReviewDisabled,
      bridgeVersion: getPackageVersion(),
      bridgeInstanceId: this.promptHistoryStore?.bridgeInstanceId,
      protocolVersion: BRIDGE_PROTOCOL_MAX_VERSION,
      minimumProtocolVersion: BRIDGE_PROTOCOL_MIN_VERSION,
      protocolCapabilities: this.protocolCapabilities(),
    });
  }

  /** Broadcast session list to all connected clients. */
  broadcastSessionList(): void {
    pruneDebugEvents(this);
    const sessions = runtimeSessionsWithWorkspaces(this);
    this.broadcast({
      type: "session_list",
      sessions,
      allowedDirs: this.allowedDirs,
      claudeModels: this.claudeModels,
      claudeModelOptions: this.claudeModelOptions,
      claudeModelEfforts: this.claudeModelEfforts,
      codexModels: this.codexModels,
      codexModelReasoningEfforts: this.codexModelReasoningEfforts,
      codexModelServiceTiers: this.codexModelServiceTiers,
      codexModelServiceTierMetadata: this.codexModelServiceTierMetadata,
      codexProfiles: this.codexProfiles,
      defaultCodexProfile: this.defaultCodexProfile,
      codexAutoReviewDisabled: this.codexAutoReviewDisabled,
      bridgeVersion: getPackageVersion(),
      bridgeInstanceId: this.promptHistoryStore?.bridgeInstanceId,
      protocolVersion: BRIDGE_PROTOCOL_MAX_VERSION,
      minimumProtocolVersion: BRIDGE_PROTOCOL_MIN_VERSION,
      protocolCapabilities: this.protocolCapabilities(),
    });
  }

  broadcastSessionMessage(
    sessionId: string,
    msg: ServerMessage,
    exclude?: WebSocket,
  ): void {
    if (
      msg.type === "system" &&
      (msg.provider === "antigravity" || msg.antigravity !== undefined)
    ) {
      const session = this.sessionManager.get(sessionId);
      const agyProcess =
        session?.process instanceof AntigravityProcess
          ? session.process
          : undefined;
      if (session?.claudeSessionId) {
        const model = msg.antigravity?.model ?? msg.model;
        if (model) {
          void this.antigravityStore.setModel(
            session.claudeSessionId,
            model,
          );
        }
        const permissionMode = msg.antigravity?.permissionMode ?? msg.permissionMode;
        if (
          permissionMode &&
          (msg.subtype === "init" ||
            msg.subtype === "antigravity_settings" ||
            msg.subtype === "set_permission_mode")
        ) {
          void this.antigravityStore.setPermissionMode(
            session.claudeSessionId,
            permissionMode,
            agyProcess?.currentModeBeforePlan,
          );
        }
      }
      // Each session start is a free, fresh reading of the catalog.
      if (msg.subtype === "init" && agyProcess) {
        void this.antigravityStore.setCatalog(agyProcess.catalog);
      }
    }
    if (this.shouldBatchDelta(msg, exclude)) {
      this.trackSessionMessage(sessionId, msg);
      let chunks: DeltaTextChunk[] | undefined;
      for (const client of this.wss.clients) {
        if (client.readyState !== WebSocket.OPEN) continue;
        if (!this.shouldSendToClient(client, msg)) continue;
        chunks ??= this.splitDeltaText(msg.text);
        this.queueDeltaForClient(client, sessionId, msg.type, chunks);
      }
      return;
    }

    this.flushSessionDeltaBatches(sessionId);
    this.trackSessionMessage(sessionId, msg);
    this.broadcastSessionMessageNow(sessionId, msg, exclude);
  }

  private shouldBatchDelta(
    msg: ServerMessage,
    exclude?: WebSocket,
  ): msg is DeltaServerMessage {
    if (this.deltaBatchMs === 0 || exclude) return false;
    return msg.type === "stream_delta" || msg.type === "thinking_delta";
  }

  private queueDeltaForClient(
    client: WebSocket,
    sessionId: string,
    type: DeltaServerMessage["type"],
    chunks: DeltaTextChunk[],
  ): void {
    for (const chunk of chunks) {
      let batch = this.deltaBatches.get(client)?.get(sessionId);
      if (
        batch &&
        batch.charCount > 0 &&
        batch.charCount + chunk.charCount > this.deltaBatchMaxChars
      ) {
        this.flushClientDeltaBatch(client, sessionId);
        batch = undefined;
      }

      if (!batch) {
        const clientBatches = this.deltaBatches.get(client) ?? new Map();
        batch = {
          messages: [],
          charCount: 0,
          timer: setTimeout(() => {
            this.flushClientDeltaBatch(client, sessionId);
          }, this.deltaBatchMs),
        };
        clientBatches.set(sessionId, batch);
        this.deltaBatches.set(client, clientBatches);
      }

      const last = batch.messages.at(-1);
      if (last?.type === type) {
        last.text += chunk.text;
      } else {
        batch.messages.push({ type, text: chunk.text });
      }
      batch.charCount += chunk.charCount;

      if (batch.charCount >= this.deltaBatchMaxChars) {
        this.flushClientDeltaBatch(client, sessionId);
      }
    }
  }

  private splitDeltaText(text: string): DeltaTextChunk[] {
    if (text.length === 0) return [{ text, charCount: 0 }];

    const chunks: DeltaTextChunk[] = [];
    let chars: string[] = [];
    let charCount = 0;
    for (const char of text) {
      chars.push(char);
      charCount += 1;
      if (charCount >= this.deltaBatchMaxChars) {
        chunks.push({ text: chars.join(""), charCount });
        chars = [];
        charCount = 0;
      }
    }
    if (chars.length > 0) {
      chunks.push({ text: chars.join(""), charCount });
    }
    return chunks;
  }

  flushSessionDeltaBatches(sessionId: string): void {
    for (const client of Array.from(this.deltaBatches.keys())) {
      this.flushClientDeltaBatch(client, sessionId);
    }
  }

  private flushAllDeltaBatches(): void {
    for (const [client, batches] of Array.from(this.deltaBatches.entries())) {
      for (const sessionId of Array.from(batches.keys())) {
        this.flushClientDeltaBatch(client, sessionId);
      }
    }
  }

  private flushClientDeltaBatch(client: WebSocket, sessionId: string): void {
    const clientBatches = this.deltaBatches.get(client);
    const batch = clientBatches?.get(sessionId);
    if (!batch) return;

    clearTimeout(batch.timer);
    clientBatches?.delete(sessionId);
    if (clientBatches?.size === 0) this.deltaBatches.delete(client);
    if (client.readyState !== WebSocket.OPEN) return;

    for (const msg of batch.messages) {
      this.send(client, { ...msg, sessionId } as Record<string, unknown>);
    }
  }

  private discardClientDeltaBatches(client: WebSocket): void {
    const batches = this.deltaBatches.get(client);
    if (!batches) return;
    for (const batch of batches.values()) clearTimeout(batch.timer);
    this.deltaBatches.delete(client);
  }

  destroySession(sessionId: string): void {
    this.flushSessionDeltaBatches(sessionId);
    this.completionGate.discard(sessionId);
    this.pendingSessionWorkspaces.delete(sessionId);
    this.sessionManager.destroy(sessionId);
  }

  private trackSessionMessage(sessionId: string, msg: ServerMessage): void {
    maybeSendPushNotification(this, sessionId, msg);
    recordDebugEvent(this, sessionId, {
      direction: "outgoing",
      channel: "session",
      type: msg.type,
      detail: summarizeServerMessage(msg),
    });
    this.recordingStore?.record(sessionId, "outgoing", msg);

    // Update recording meta with claudeSessionId when it becomes available
    if (
      (msg.type === "system" || msg.type === "result") &&
      "sessionId" in msg &&
      msg.sessionId
    ) {
      const session = this.sessionManager.get(sessionId);
      if (session) {
        const workspace = workspaceForRuntimeSession(this, session);
        this.recordingStore?.saveMeta(sessionId, {
          bridgeSessionId: sessionId,
          claudeSessionId: msg.sessionId as string,
          projectPath: session.projectPath,
          ...(workspace?.projectId ? { projectId: workspace.projectId } : {}),
          ...(workspace?.projectName
            ? { projectName: workspace.projectName }
            : {}),
          createdAt: session.createdAt.toISOString(),
        });
      }
    }
  }

  private broadcastSessionMessageNow(
    sessionId: string,
    msg: ServerMessage,
    exclude?: WebSocket,
  ): void {
    for (const client of this.wss.clients) {
      if (client === exclude) continue;
      if (client.readyState === WebSocket.OPEN) {
        const outboundMsg = {
          ...(msg as unknown as Record<string, unknown>),
          sessionId,
        };
        const compatibleMsg = this.prepareServerMessageForClient(
          client,
          outboundMsg,
        );
        if (!compatibleMsg) continue;
        client.send(JSON.stringify(compatibleMsg));
      }
    }
  }

  private async listRecentSessions(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ): Promise<RecentSessionsListing> {
    if (msg.provider === "antigravity") {
      const pinnedOnlyExtras =
        msg.pinnedOnly === true &&
        msg.requestScope !== "project" &&
        (msg.offset ?? 0) === 0 &&
        (msg.pinnedSessions?.length ?? 0) > 0
          ? { pinnedSessions: [] as unknown[] }
          : {};
      const limit = msg.limit ?? 20;
      const offset = msg.offset ?? 0;
      const filtered = await listFilteredAntigravitySessions(this, msg);
      return {
        sessions: filtered.sessions.slice(offset, offset + limit),
        hasMore: filtered.sessions.length > offset + limit,
        ...(filtered.pinnedSessions
          ? { pinnedSessions: filtered.pinnedSessions }
          : pinnedOnlyExtras),
      };
    }
    const listing = await this.listRecentClaudeAndCodexSessions(msg);
    // Antigravity rows join the first page: its list is small and the
    // other providers page on their own offsets.
    if (
      msg.provider !== undefined ||
      !msg.includeAntigravity ||
      !this.antigravityAvailable ||
      (msg.offset ?? 0) > 0
    ) {
      return listing;
    }
    const antigravity = await listFilteredAntigravitySessions(this, msg);
    const mergedPinned =
      listing.pinnedSessions || antigravity.pinnedSessions
        ? mergeRecentSessionPages([
            ...(listing.pinnedSessions ?? []),
            ...(antigravity.pinnedSessions ?? []),
          ])
        : undefined;
    return {
      ...listing,
      sessions: mergeRecentSessionPages([
        ...listing.sessions,
        ...antigravity.sessions.slice(0, msg.limit ?? 20),
      ]),
      ...(mergedPinned ? { pinnedSessions: mergedPinned } : {}),
    };
  }

  private async listRecentClaudeAndCodexSessions(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ): Promise<RecentSessionsListing> {
    const pinnedKeys = pinnedSessionKeysForRecentRequest(msg);
    const listProjects = () => this.workspaceStore?.listProjects() ?? [];
    const primaryProjectIds = new Set(
      msg.projectPath === undefined
        ? []
        : listProjects()
            .filter((project) => project.rootPaths[0] === msg.projectPath)
            .map((project) => project.id),
    );
    const workspaceFilterRequested =
      msg.projectId !== undefined ||
      msg.workspaceKind !== undefined ||
      primaryProjectIds.size > 0;
    const filtersRequested = recentSessionsFiltersRequested(msg);
    // Plain listings switch to the index + thread snapshot once the snapshot
    // is loaded; until then (first listing after start) app-server thread/list
    // answers without waiting for the full snapshot.
    if (
      !workspaceFilterRequested &&
      !filtersRequested &&
      !this.codexThreadSnapshot.isReady
    ) {
      const rawResult = await listRecentSessionsRaw(this, msg, pinnedKeys);
      const enriched = rawResult.sessions.map((session) =>
        enrichRecentSessionWorkspace(this, session),
      );
      return {
        sessions: enriched,
        hasMore: rawResult.hasMore,
        ...(rawResult.pinnedSessions
          ? {
              pinnedSessions: rawResult.pinnedSessions.map((session) =>
                enrichRecentSessionWorkspace(this, session),
              ),
            }
          : {}),
      };
    }

    // pinnedOnly: the page already contains every pinned session, so a first
    // list page that sent pins answers with an empty extras list.
    const pinnedOnlyExtras =
      msg.pinnedOnly === true &&
      msg.requestScope !== "project" &&
      (msg.offset ?? 0) === 0 &&
      (msg.pinnedSessions?.length ?? 0) > 0
        ? { pinnedSessions: [] as unknown[] }
        : {};
    const pinnedOnlyKeys = pinnedOnlySessionKeys(msg);
    if (
      pinnedOnlyKeys &&
      pinnedOnlyKeys.size === 0 &&
      (msg.pinnedProjects?.length ?? 0) === 0
    ) {
      return { sessions: [], hasMore: false, ...pinnedOnlyExtras };
    }
    const matchesWorkspace = buildRecentSessionPredicate(
      msg,
      listProjects,
      pinnedOnlyKeys,
    );
    const offset = msg.offset ?? 0;
    const limit = msg.limit ?? 20;
    const requiredMatches = offset + limit + 1;
    // The filesystem index answers for both providers (parsed rollouts are
    // cached); threads Codex only kept as compressed rollouts come from the
    // thread snapshot. Paging app-server thread/list per request took
    // seconds for searches, sparse results and older date ranges, and it
    // cannot search transcripts at all.
    const depthKey = isRecentContentSearch(msg)
      ? recentSessionsCoalescingKey({ ...msg, offset: 0, limit: undefined })
      : undefined;
    const maxFiles = depthKey
      ? this.contentSearchMaxFiles(depthKey, offset)
      : undefined;
    const indexed = await listWorkspaceFilteredIndexedSessions(
      this,
      msg,
      matchesWorkspace,
      requiredMatches,
      pinnedKeys,
      maxFiles,
    );
    if (depthKey && indexed.filesRead !== undefined) {
      this.contentSearchDepth.set(depthKey, {
        files: indexed.filesRead,
        at: Date.now(),
      });
    }
    const archived = await listSnapshotOnlyCodexSessions(
      this,
      msg,
      matchesWorkspace,
      requiredMatches,
      pinnedKeys,
    );
    // Index entries come first so they win the dedupe (richer metadata).
    const filtered = mergeRecentSessionPages([
      ...indexed.sessions,
      ...archived.sessions,
    ]);
    const pinnedSessions = indexed.pinnedSessions
      ? mergeRecentSessionPages([
          ...indexed.pinnedSessions,
          ...archived.pinnedSessions,
        ])
      : undefined;
    const incomplete = indexed.incomplete;
    return {
      sessions: filtered.slice(offset, offset + limit),
      hasMore: filtered.length > offset + limit || incomplete,
      ...(pinnedSessions ? { pinnedSessions } : pinnedOnlyExtras),
    };
  }

  /** Page through every Codex thread with one standalone app-server. */
  private async loadAllCodexThreads(
    onPage: (page: { data: CodexThreadSummary[]; nextCursor: string | null }) => void,
  ): Promise<void> {
    const process = await this.createStandaloneCodexProcess(undefined);
    try {
      let cursor: string | null | undefined;
      do {
        const request: Parameters<CodexProcess["listThreads"]>[0] = {
          limit: 500,
          sourceKinds: CODEX_RECENT_THREAD_SOURCE_KINDS,
        };
        if (cursor != null) request.cursor = cursor;
        const result = await process.listThreads(request);
        onPage(result);
        cursor = result.nextCursor;
      } while (cursor != null);
    } finally {
      process.stop();
    }
  }

  /**
   * File bound for a content search page: the base budget for the first
   * page, and the previous page's depth plus one budget for later pages.
   */
  private contentSearchMaxFiles(depthKey: string, offset: number): number {
    const now = Date.now();
    for (const [key, value] of this.contentSearchDepth) {
      if (now - value.at > 10 * 60_000) this.contentSearchDepth.delete(key);
    }
    if (offset === 0) {
      this.contentSearchDepth.delete(depthKey);
      return CONTENT_SEARCH_MAX_FILES;
    }
    const previous = this.contentSearchDepth.get(depthKey)?.files ?? 0;
    return previous + CONTENT_SEARCH_MAX_FILES;
  }

  /** Antigravity conversations matching the request filters, newest first. */
  async listRecentAntigravitySessions(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ): Promise<AntigravityRecentSession[]> {
    if (!this.antigravityAvailable) return [];
    const now = Date.now();
    if (
      !this.antigravitySessionsCache ||
      now - this.antigravitySessionsCache.at > 15_000
    ) {
      this.antigravitySessionsCache = {
        at: now,
        entries: listAntigravitySessions().catch((err) => {
          console.warn(
            `[ws] Failed to list Antigravity sessions: ${errorMessageOf(err)}`,
          );
          return [];
        }),
      };
    }
    return antigravityRecentSessions(
      await this.antigravitySessionsCache.entries,
      {
        searchQuery: msg.searchQuery,
        namedOnly: msg.namedOnly,
        archivedSessionIds: this.archiveStore.archivedIds(),
        records: this.antigravityStore.records(),
        worktrees: this.worktreeStore.getAll(),
      },
    );
  }

  /**
   * Antigravity's plan quota. The CLI is asked when a client requests usage
   * and the last reading is older than fifteen minutes, or a minute when
   * [refresh] is set (a person tapped refresh). Nothing runs on a timer: no
   * client asking means no read. Never read with an API key (it has no plan)
   * or on a Bridge that must not touch the Google login.
   */
  async antigravityUsage(refresh: boolean): Promise<UsageInfo[]> {
    const config = this.antigravityConfigOverride ?? getAntigravityConfig();
    if (!this.antigravityAvailable || config.apiKey || config.requireApiKey) {
      return [];
    }
    const cached = this.antigravityUsageCache;
    const maxAge = refresh ? 60_000 : 15 * 60_000;
    if (cached && Date.now() - cached.at < maxAge) return cached.usage;
    // Several clients asking at once share one read.
    this.antigravityUsageRead ??= this.loadAntigravityUsage(config.bin)
      .then(
        (usage) => {
          this.antigravityUsageCache = { at: Date.now(), usage };
          return usage;
        },
        (err) => {
          console.warn(
            `[ws] Failed to read Antigravity usage: ${errorMessageOf(err)}`,
          );
          // Keep the last reading, and do not ask again right away.
          const usage = cached?.usage ?? [];
          this.antigravityUsageCache = { at: Date.now(), usage };
          return usage;
        },
      )
      .finally(() => {
        this.antigravityUsageRead = undefined;
      });
    return this.antigravityUsageRead;
  }

  /** What a new Antigravity session offers; read without sending a prompt. */
  antigravityCatalog(): Promise<AntigravityCatalog> {
    // A running session already knows, and is fresher than the cache.
    for (const summary of this.sessionManager.list()) {
      const process = this.sessionManager.get(summary.id)?.process;
      if (process instanceof AntigravityProcess && process.isRunning) {
        const catalog = process.catalog;
        if (catalog.models.length > 0) return Promise.resolve(catalog);
      }
    }
    const authMode = getAntigravityConfig().apiKey ? "api_key" : "login";
    const stored = this.antigravityStore.catalog(authMode, ANTIGRAVITY_CATALOG_TTL_MS);
    if (stored) return Promise.resolve(stored);
    if (!this.antigravityCatalogRead) {
      const read = this.loadAntigravityCatalog().then((catalog) => {
        void this.antigravityStore.setCatalog(catalog);
        return catalog;
      });
      this.antigravityCatalogRead = read;
      const done = () => {
        if (this.antigravityCatalogRead === read) {
          this.antigravityCatalogRead = undefined;
        }
      };
      read.then(done, done);
    }
    return this.antigravityCatalogRead;
  }

  private async refreshAntigravityAvailability(): Promise<void> {
    const available = (await this.detectAntigravity?.().catch(() => false)) ?? false;
    if (available === this.antigravityAvailable) return;
    this.antigravityAvailable = available;
    this.broadcastSessionList();
  }

  private protocolCapabilities(): string[] {
    return this.antigravityAvailable
      ? [...BRIDGE_PROTOCOL_CAPABILITIES, ...ANTIGRAVITY_PROTOCOL_CAPABILITIES]
      : BRIDGE_PROTOCOL_CAPABILITIES;
  }

  listRecentSessionsCoalesced(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ): Promise<RecentSessionsListing> {
    const key = recentSessionsCoalescingKey(msg);
    const existing = this.recentSessionsInFlight.get(key);
    if (existing) return existing;

    const request = this.listRecentSessions(msg);
    this.recentSessionsInFlight.set(key, request);
    const clear = (): void => {
      if (this.recentSessionsInFlight.get(key) === request) {
        this.recentSessionsInFlight.delete(key);
      }
    };
    void request.then(clear, clear);
    return request;
  }

  async listRecentCodexSessions(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
    pinnedKeys?: ReadonlySet<string>,
  ): Promise<RecentSessionsListing> {
    try {
      const [page, pinnedSessions] = await Promise.all([
        this.listRecentCodexThreads(msg),
        pinnedKeys ? listPinnedCodexSessions(this, msg, pinnedKeys) : undefined,
      ]);
      return { ...page, ...(pinnedSessions ? { pinnedSessions } : {}) };
    } catch (err) {
      console.warn(
        `[ws] Codex thread/list failed, falling back to rollout scan: ${err}`,
      );
      return getAllRecentSessions({
        limit: msg.limit,
        offset: msg.offset,
        projectPath: msg.projectPath,
        provider: "codex",
        namedOnly: msg.namedOnly,
        searchQuery: msg.searchQuery,
        archivedSessionIds: this.archiveStore.archivedIds(),
        pinnedSessionKeys: pinnedKeys,
      });
    }
  }

  async refreshCodexMetadata(projectPath?: string): Promise<void> {
    if (this.codexMetadataRequest) {
      if (projectPath) {
        return this.codexMetadataRequest.then(() =>
          this.refreshCodexMetadata(projectPath),
        );
      }
      return this.codexMetadataRequest;
    }
    this.codexMetadataRequest = this.loadAndApplyCodexMetadata(projectPath)
      .catch((err) => {
        console.warn(`[ws] Failed to load Codex metadata: ${err}`);
        this.codexProfiles = [];
        this.defaultCodexProfile = undefined;
        this.codexAutoReviewPolicyLoaded = false;
        applyFallbackCodexModels(this);
        this.broadcastSessionList();
      })
      .finally(() => {
        this.codexMetadataRequest = null;
      });
    return this.codexMetadataRequest;
  }

  private async loadAndApplyCodexMetadata(
    projectPath?: string,
  ): Promise<void> {
    const activeProcess = this.getActiveCodexProcess();
    const codexProcess =
      activeProcess ?? (await this.createStandaloneCodexProcess(projectPath));
    try {
      const [profileResult, modelResult, requirementsResult] =
        await Promise.allSettled([
          codexProcess.readProfileConfig(projectPath),
          readCodexModels(codexProcess),
          readCodexAutoReviewDisabled(codexProcess),
        ]);

      if (profileResult.status === "fulfilled") {
        this.codexProfiles = profileResult.value.profiles;
        this.defaultCodexProfile = profileResult.value.defaultProfile;
      } else {
        console.warn(
          `[ws] Failed to load Codex profiles: ${profileResult.reason}`,
        );
        this.codexProfiles = [];
        this.defaultCodexProfile = undefined;
      }

      if (modelResult.status === "fulfilled" && modelResult.value.length > 0) {
        this.applyCodexModels(modelResult.value);
      } else {
        if (modelResult.status === "rejected") {
          console.warn(`[ws] Failed to load Codex models: ${modelResult.reason}`);
        }
        applyFallbackCodexModels(this);
      }

      if (requirementsResult.status === "fulfilled") {
        this.codexAutoReviewDisabled = requirementsResult.value;
        this.codexAutoReviewPolicyLoaded = true;
      } else {
        console.warn(
          `[ws] Failed to load Codex config requirements: ${requirementsResult.reason}`,
        );
        this.codexAutoReviewPolicyLoaded = false;
      }
      this.broadcastSessionList();
    } finally {
      if (!activeProcess) codexProcess.stop();
    }
  }

  async refreshClaudeModels(projectPath?: string): Promise<void> {
    if (this.claudeModelsRequest) return this.claudeModelsRequest;
    this.claudeModelsRequest = loadClaudeModels(this, projectPath)
      .then((models) => {
        if (models.length > 0) {
          this.applyClaudeModels(models);
        } else {
          applyFallbackClaudeModels(this);
        }
        this.broadcastSessionList();
      })
      .catch((err) => {
        console.warn(`[ws] Failed to load Claude models: ${err}`);
        applyFallbackClaudeModels(this);
        this.broadcastSessionList();
      })
      .finally(() => {
        this.claudeModelsRequest = null;
      });
    return this.claudeModelsRequest;
  }

  private applyClaudeModels(models: ClaudeModelMetadata[]): void {
    this.claudeModels = models.map((model) => model.model);
    this.claudeModelOptions = models.map((model) => ({
      value: model.model,
      ...(model.displayName ? { displayName: model.displayName } : {}),
      ...(model.description ? { description: model.description } : {}),
      ...(model.supportsFastMode ? { supportsFastMode: true } : {}),
    }));
    this.claudeModelEfforts = Object.fromEntries(
      models.map((model) => [model.model, model.effortLevels]),
    );
  }

  private applyCodexModels(models: CodexModelMetadata[]): void {
    this.codexModels = models.map((model) => model.model);
    this.codexModelReasoningEfforts = Object.fromEntries(
      models.map((model) => [
        model.model,
        model.supportedReasoningEfforts.length > 0
          ? model.supportedReasoningEfforts
          : fallbackCodexReasoningEfforts(model.model),
      ]),
    );
    this.codexModelServiceTiers = Object.fromEntries(
      models.map((model) => [
        model.model,
        model.supportedServiceTiers ?? fallbackCodexServiceTiers(model.model),
      ]),
    );
    this.codexModelServiceTierMetadata = Object.fromEntries(
      models.map((model) => [model.model, model.serviceTierMetadata ?? []]),
    );
  }

  async loadCodexProfiles(
    projectPath?: string,
  ): Promise<{ profiles: string[]; defaultProfile?: string }> {
    const process =
      this.getActiveCodexProcess() ??
      (await this.createStandaloneCodexProcess(projectPath));
    const isStandalone = process !== this.getActiveCodexProcess();
    try {
      return await process.readProfileConfig(projectPath);
    } finally {
      if (isStandalone) {
        process.stop();
      }
    }
  }

  async validateCodexProfile(
    profile: string | undefined,
    projectPath?: string,
  ): Promise<boolean> {
    if (!profile) return true;
    const snapshot = await this.loadCodexProfiles(projectPath);
    this.codexProfiles = snapshot.profiles;
    this.defaultCodexProfile = snapshot.defaultProfile;
    return snapshot.profiles.includes(profile);
  }

  getActiveCodexProcess(): CodexProcess | null {
    // SessionManager retains idle sessions after their process exits.
    // Skip those entries so auxiliary RPCs can use a healthy process or
    // create a temporary standalone app-server.
    for (const summary of this.sessionManager.list()) {
      if (summary.provider !== "codex") continue;
      const session = this.sessionManager.get(summary.id);
      if (session?.provider !== "codex") continue;
      const process = session.process as CodexProcess;
      if (process.isRunning) return process;
    }
    return null;
  }

  private async listRecentCodexThreads(
    msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  ): Promise<{ sessions: unknown[]; hasMore: boolean }> {
    const limit = msg.limit ?? 20;
    const offset = msg.offset ?? 0;
    const process = await this.createStandaloneCodexProcess(msg.projectPath);

    try {
      const archivedIds = this.archiveStore.archivedIds();
      const visibleThreads: CodexThreadSummary[] = [];
      const seenThreadIds = new Set<string>();
      let cursor: string | null | undefined;
      let hasServerMore = false;
      const targetCount = offset + limit;

      do {
        const request: Parameters<CodexProcess["listThreads"]>[0] = {
          limit: Math.max(limit, 1),
          cwd: msg.projectPath,
          searchTerm: msg.searchQuery,
          sourceKinds: CODEX_RECENT_THREAD_SOURCE_KINDS,
        };
        if (cursor != null) request.cursor = cursor;

        const result = await process.listThreads(request);
        for (const thread of result.data) {
          if (archivedIds.has(thread.id)) continue;
          if (msg.namedOnly && !thread.name) continue;
          // A thread split into rollout segments can be listed more than
          // once; keep the first (newest) entry.
          if (seenThreadIds.has(thread.id)) continue;
          seenThreadIds.add(thread.id);
          visibleThreads.push(thread);
        }
        cursor = result.nextCursor;
        hasServerMore = cursor != null;
      } while (visibleThreads.length < targetCount && cursor != null);

      const pageThreads = visibleThreads.slice(offset, offset + limit);
      const [indexedById, threadNames] = await Promise.all([
        getCodexSessionIndexMetadata(pageThreads.map((thread) => thread.id)),
        loadCodexSessionNames(),
      ]);
      const sessions = pageThreads.map((thread) =>
        withRecentSessionMetadataSearchMatch(
          {
            ...codexThreadToRecentSession(thread, indexedById.get(thread.id)),
            ...(threadNames.get(thread.id)
              ? { name: threadNames.get(thread.id) }
              : {}),
          },
          msg.searchQuery,
        ),
      );
      return {
        sessions,
        hasMore: hasServerMore || visibleThreads.length > offset + limit,
      };
    } finally {
      process.stop();
    }
  }

  async createStandaloneCodexProcess(
    projectPath?: string,
  ): Promise<CodexProcess> {
    const proc = new CodexProcess();
    try {
      await proc.initializeOnly(projectPath ?? process.cwd());
      return proc;
    } catch (err) {
      proc.stop();
      throw err;
    }
  }

  broadcast(msg: Record<string, unknown>): void {
    for (const client of this.wss.clients) {
      if (client.readyState === WebSocket.OPEN) {
        const compatibleMsg = this.prepareServerMessageForClient(client, msg);
        if (!compatibleMsg) continue;
        client.send(JSON.stringify(compatibleMsg));
      }
    }
  }

  private prepareServerMessageForClient(
    ws: WebSocket,
    msg: ServerMessage | Record<string, unknown>,
  ): ServerMessage | Record<string, unknown> | null {
    if (!this.shouldSendToClient(ws, msg)) return null;
    if (this.performanceEnabled(ws, msg as Record<string, unknown>)) {
      const projected = performanceMessage(msg as Record<string, unknown>);
      if (projected) {
        msg = projected;
      } else {
        const sessionId = (msg as Record<string, unknown>).sessionId as string;
        const times = this.activityTimes.get(ws) ?? new Map<string, number>();
        this.activityTimes.set(ws, times);
        const now = Date.now();
        if (now - (times.get(sessionId) ?? 0) < 1000) return null;
        times.set(sessionId, now);
        const historySeq = (msg as Record<string, unknown>).historySeq;
        return {
          type: "session_activity",
          sessionId,
          historySeq: typeof historySeq === "number" ? historySeq : undefined,
          at: new Date(now).toISOString(),
        };
      }
    }
    if (!("messages" in msg) || !Array.isArray(msg.messages)) return msg;
    const messages = msg.messages as unknown[];

    if (msg.type === "past_history") {
      const supported = this.clientSupportedServerMessages.get(ws);
      const supportsCompaction = supported?.has("context_compaction") ?? false;
      const supportsRecap = supported?.has("session_recap") ?? false;
      if (supportsCompaction && supportsRecap) {
        return msg;
      }
      return {
        ...(msg as unknown as Record<string, unknown>),
        messages: messages.filter((message) => {
          if (!isRecord(message)) return true;
          if (!supportsCompaction && message.role === "compaction") return false;
          if (!supportsRecap && message.role === "recap") return false;
          return true;
        }),
      };
    }

    if (msg.type === "history") {
      return {
        ...(msg as unknown as Record<string, unknown>),
        messages: messages.filter(
          (message) =>
            isRecord(message) && this.shouldSendToClient(ws, message),
        ),
      };
    }
    if (msg.type === "history_delta" || msg.type === "history_snapshot") {
      return {
        ...(msg as unknown as Record<string, unknown>),
        messages: messages.filter((entry) => {
          if (!isRecord(entry) || !isRecord(entry.message)) return true;
          return this.shouldSendToClient(ws, entry.message);
        }),
      };
    }
    return msg;
  }

  shouldSendToClient(
    ws: WebSocket,
    msg: ServerMessage | Record<string, unknown>,
  ): boolean {
    const type = typeof msg.type === "string" ? msg.type : "";
    if (!OPT_IN_SERVER_MESSAGES.has(type)) return true;
    return (
      this.clientSupportedServerMessages.get(ws)?.has(type) ?? false
    );
  }

  sendQueueState(
    ws: WebSocket,
    sessionId: string,
    session: SessionInfo,
  ): void {
    const item = session.queuedInput;
    sendConversationQueue(this, ws, {
      type: "conversation_queue",
      sessionId,
      limit: 1,
      items: item
        ? [
            {
              ...(item.clientMessageId ? { clientMessageId: item.clientMessageId } : {}),
              ...(item.waitingForUsageLimit ? { waitingForUsageLimit: true } : {}),
              ...(item.retryAt ? { retryAt: item.retryAt } : {}),
              itemId: item.itemId,
              text: item.text,
              createdAt: item.createdAt,
              ...(item.updatedAt ? { updatedAt: item.updatedAt } : {}),
              ...(item.imageCount ? { imageCount: item.imageCount } : {}),
              ...(item.skills?.length ? { skills: item.skills } : {}),
              ...(item.mentions?.length ? { mentions: item.mentions } : {}),
            },
          ]
        : [],
    } as Record<string, unknown>);
  }

  sendCachedCommands(
    ws: WebSocket,
    sessionId: string,
    session: SessionInfo,
  ): void {
    // Restore command metadata when the original init/supported_commands event
    // has fallen out of the bounded in-memory history.
    const cached = this.sessionManager.getCachedCommands(
      session.provider,
      session.worktreePath ?? session.projectPath,
    );
    if (
      !cached ||
      (cached.slashCommands.length === 0 &&
        cached.skills.length === 0 &&
        cached.apps.length === 0 &&
        cached.plugins.length === 0)
    ) {
      return;
    }

    this.send(ws, {
      type: "system",
      subtype: "supported_commands",
      sessionId,
      provider: session.provider,
      slashCommands: cached.slashCommands,
      ...(cached.slashCommandDescriptions
        ? { slashCommandDescriptions: cached.slashCommandDescriptions }
        : {}),
      skills: cached.skills,
      ...(cached.skillMetadata ? { skillMetadata: cached.skillMetadata } : {}),
      apps: cached.apps,
      ...(cached.appMetadata ? { appMetadata: cached.appMetadata } : {}),
      plugins: cached.plugins,
      ...(cached.pluginMetadata ? { pluginMetadata: cached.pluginMetadata } : {}),
    });
  }

  send(
    ws: WebSocket,
    msg: ServerMessage | Record<string, unknown>,
  ): void {
    const compatibleMsg = this.prepareServerMessageForClient(ws, msg);
    if (!compatibleMsg) return;
    const sessionId = extractSessionIdFromServerMessage(compatibleMsg);
    if (sessionId && this.debugEvents.has(sessionId)) {
      recordDebugEvent(this, sessionId, {
        direction: "outgoing",
        channel: "ws",
        type: String(compatibleMsg.type ?? "unknown"),
        detail: summarizeOutboundMessage(compatibleMsg),
      });
    }
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(compatibleMsg));
    }
  }

  /** Broadcast a gallery_new_image message to all connected clients. */
  broadcastGalleryNewImage(
    image: import("./gallery-store.js").GalleryImageInfo,
  ): void {
    this.broadcast({ type: "gallery_new_image", image });
  }

  collectGitDiff(
    cwd: string,
    callback: (result: { diff: string; error?: string }) => void,
    options?: { staged?: boolean; unstaged?: boolean },
  ): void {
    const execOpts = { cwd, maxBuffer: 10 * 1024 * 1024 };
    const gitArgs = (...args: string[]) => [
      "-c",
      "core.quotePath=false",
      ...args,
    ];
    const listUntrackedFiles = () => {
      const out = execFileSync(
        "git",
        gitArgs("ls-files", "-z", "--others", "--exclude-standard"),
        { cwd, encoding: "utf-8" },
      );
      return out.split("\0").filter(Boolean);
    };

    // Staged only: git diff --cached
    if (options?.staged) {
      execFile(
        "git",
        gitArgs("diff", "--cached", "--no-color"),
        execOpts,
        (err, stdout) => {
          if (err) {
            callback({ diff: "", error: err.message });
            return;
          }
          callback({ diff: stdout });
        },
      );
      return;
    }

    // Unstaged only: git diff (working tree vs index) — original behavior
    if (options?.unstaged) {
      // Collect untracked files so they appear in the diff.
      let untrackedFiles: string[] = [];
      try {
        untrackedFiles = listUntrackedFiles();
      } catch {
        // Ignore errors: non-git directories are handled by git diff callback.
      }

      // Temporarily stage untracked files with --intent-to-add.
      if (untrackedFiles.length > 0) {
        try {
          execFileSync(
            "git",
            ["add", "--intent-to-add", "--", ...untrackedFiles],
            {
              cwd,
            },
          );
        } catch {
          // Ignore staging errors.
        }
      }

      execFile(
        "git",
        gitArgs("diff", "--no-color"),
        execOpts,
        (err, stdout) => {
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
        },
      );
      return;
    }

    // All mode (no options): git diff HEAD — shows both staged and unstaged vs HEAD
    let untrackedFilesAll: string[] = [];
    try {
      untrackedFilesAll = listUntrackedFiles();
    } catch {
      // Ignore
    }

    if (untrackedFilesAll.length > 0) {
      try {
        execFileSync(
          "git",
          ["add", "--intent-to-add", "--", ...untrackedFilesAll],
          {
            cwd,
          },
        );
      } catch {
        // Ignore
      }
    }

    const resetUntrackedAll = () => {
      if (untrackedFilesAll.length === 0) return;
      try {
        execFileSync("git", ["reset", "--", ...untrackedFilesAll], { cwd });
      } catch {
        // Ignore
      }
    };

    // Unborn branches have no HEAD; diff against the empty tree instead.
    // Computing it spawns git synchronously, which throws (e.g. ENOENT) when
    // cwd no longer exists, such as a deleted worktree.
    let diffBase: string;
    try {
      diffBase = hasGitHead(cwd)
        ? "HEAD"
        : execFileSync("git", ["hash-object", "-t", "tree", "--stdin"], {
            cwd,
            input: "",
            encoding: "utf8",
          }).trim();
    } catch (err) {
      resetUntrackedAll();
      callback({
        diff: "",
        error: err instanceof Error ? err.message : String(err),
      });
      return;
    }

    execFile(
      "git",
      gitArgs("diff", diffBase, "--no-color"),
      execOpts,
      (err, stdout) => {
        resetUntrackedAll();

        if (err) {
          callback({ diff: "", error: err.message });
          return;
        }
        callback({ diff: stdout });
      },
    );
  }
}
