import { extname } from "node:path";
import { WebSocket } from "ws";
import type { SessionInfo } from "../session.js";
import type { ClaudeEffortLevel } from "../sdk-process.js";
import type {
  CodexStartOptions,
  CodexThreadSourceKind,
} from "../codex-process.js";
import type { ClientMessage, Provider, ServerMessage } from "../parser.js";
import {
  codexUserTurnUuid,
  type SessionHistoryMessage,
} from "../sessions-index.js";

export type SystemServerMessage = Extract<ServerMessage, { type: "system" }>;
export type ResultServerMessage = Extract<ServerMessage, { type: "result" }>;

/** How long a session must stay idle without background work before Done. */
export const BACKGROUND_COMPLETION_SETTLE_MS = 2_000;
/** How long a new session's first prompt waits for the skill list. */
export const INITIAL_PROMPT_SKILL_WAIT_MS = 5_000;
export const INITIAL_PROMPT_SKILL_POLL_MS = 100;
export type InputClientMessage = Extract<ClientMessage, { type: "input" }>;
export type ResumeClientMessage = Extract<ClientMessage, { type: "resume_session" }>;
export type CorrelatedProjectRequest = {
  projectPath: string;
  requestId?: string;
};

export function projectRequestMetadata(
  request: CorrelatedProjectRequest,
): { projectPath: string; requestId?: string } {
  return {
    projectPath: request.projectPath,
    ...(request.requestId ? { requestId: request.requestId } : {}),
  };
}
export type ResumeOperation = {
  id: string;
  provider: Provider;
  sourceSessionId: string;
  projectPath: string;
  resumeRequestId?: string;
  fingerprint: string;
  waiters: Set<WebSocket>;
  provisionalSessionId?: string;
  timeout?: ReturnType<typeof setTimeout>;
  completed?: {
    sessionId: string;
    message: SystemServerMessage;
    completedAt: number;
  };
};
export const RESUME_OPERATION_TIMEOUT_MS = 5 * 60 * 1000;
export const RESUME_COMPLETED_TTL_MS = 30 * 1000;
export type ClaudePermissionMode =
  | "default"
  | "auto"
  | "acceptEdits"
  | "bypassPermissions"
  | "plan";

// ---- Available model lists (delivered to clients via session_list) ----

// Used only when the Agent SDK cannot report its model list. These are the
// Claude Code aliases, which always resolve to the current model of each
// family, so the fallback never needs version-specific updates.
export const FALLBACK_CLAUDE_MODEL_OPTIONS: ClaudeModelOption[] = [
  { value: "default", displayName: "Default" },
  { value: "opus", displayName: "Opus" },
  { value: "sonnet", displayName: "Sonnet" },
  { value: "haiku", displayName: "Haiku" },
];

export const FALLBACK_CLAUDE_MODELS: string[] = FALLBACK_CLAUDE_MODEL_OPTIONS.map(
  (option) => option.value,
);

export const FALLBACK_CLAUDE_EFFORTS: ClaudeEffortLevel[] = ["low", "medium", "high"];

export const FALLBACK_CLAUDE_MODEL_EFFORTS: Record<string, ClaudeEffortLevel[]> = {
  default: FALLBACK_CLAUDE_EFFORTS,
  opus: FALLBACK_CLAUDE_EFFORTS,
  sonnet: FALLBACK_CLAUDE_EFFORTS,
  haiku: [],
};

export interface ClaudeModelOption {
  value: string;
  displayName?: string;
  description?: string;
  /** Claude Code fast mode is available for this model. */
  supportsFastMode?: boolean;
}

export const FALLBACK_CODEX_MODELS: string[] = [
  "gpt-5.6-sol",
  "gpt-5.6-terra",
  "gpt-5.6-luna",
  "gpt-5.5",
  "gpt-5.4",
  "gpt-5.4-mini",
  "gpt-5.3-codex",
  "gpt-5.3-codex-spark",
];

export const FALLBACK_CODEX_REASONING_EFFORTS = ["low", "medium", "high", "xhigh"];
export const FALLBACK_GPT_5_6_REASONING_EFFORTS = [
  ...FALLBACK_CODEX_REASONING_EFFORTS,
  "max",
];
export const FALLBACK_GPT_5_6_ULTRA_REASONING_EFFORTS = [
  ...FALLBACK_GPT_5_6_REASONING_EFFORTS,
  "ultra",
];

export function fallbackCodexReasoningEfforts(model: string): string[] {
  if (model === "gpt-5.6-sol" || model === "gpt-5.6-terra") {
    return FALLBACK_GPT_5_6_ULTRA_REASONING_EFFORTS;
  }
  if (model === "gpt-5.6-luna") return FALLBACK_GPT_5_6_REASONING_EFFORTS;
  return FALLBACK_CODEX_REASONING_EFFORTS;
}

export function fallbackCodexServiceTiers(model: string): string[] {
  return [
    "gpt-5.6-sol",
    "gpt-5.6-terra",
    "gpt-5.6-luna",
    "gpt-5.5",
    "gpt-5.4",
  ].includes(model)
    ? ["fast"]
    : [];
}

export const CODEX_RECENT_THREAD_SOURCE_KINDS: CodexThreadSourceKind[] = [
  "cli",
  "vscode",
  "appServer",
];

export const CODEX_USER_TURN_UUID_RE = /^codex:user-turn:(\d+)$/;
/** Upper bound for waiting on a replaced Codex app-server to exit. */
export const CODEX_SHUTDOWN_WAIT_MS = 5_000;
/** How long a retract waits for a just-sent prompt's turn to start. */
export const RETRACT_START_TIMEOUT_MS = 3_000;
/** How long a retract waits for the interrupted turn to end. */
export const RETRACT_IDLE_TIMEOUT_MS = 15_000;

export const BRIDGE_PROTOCOL_CAPABILITIES = [
  "performance_mode_v1",
  "project_request_correlation_v1",
  "session_context_v1",
  "codex_service_tiers_v1",
  "input_delivery_v1",
  "claude_session_settings_v1",
  "claude_fork_v1",
  "message_edit_v1",
  "recent_sessions_filters_v1",
  "context_compaction_v1",
  "shared_state_v1",
  "session_handoff_v1",
];
/** Advertised only while the Antigravity CLI is installed on this machine. */
export const ANTIGRAVITY_PROTOCOL_CAPABILITIES = [
  "antigravity_v1",
  // Catalog, model family and thinking level, question forms, plan review,
  // context usage and the bypass mode.
  "antigravity_v2",
];
/**
 * How long a catalog read is reused. Every read opens an empty conversation
 * that `agy` keeps on disk (about 400 KB), and running sessions refresh the
 * catalog for free, so a day is enough.
 */
export const ANTIGRAVITY_CATALOG_TTL_MS = 24 * 60 * 60_000;

/** Default and maximum page size for `get_session_transcript`. */
export const TRANSCRIPT_PAGE_DEFAULT = 200;
export const TRANSCRIPT_PAGE_MAX = 1000;

export const OPT_IN_SERVER_MESSAGE_TYPES = [
  "agent_activity",
  "background_tasks",
  "context_compaction",
  "conversation_queue",
  "goal_state",
  "codex_recovery_state",
  "guardian_approval",
  "pins",
  "prompt_history_status",
  "projects",
  "push_registration_result",
  "session_recap",
  "shared_state",
  "shared_state_changed",
  "shared_state_seeded",
] as const;

export const OPT_IN_SERVER_MESSAGES = new Set<string>(
  OPT_IN_SERVER_MESSAGE_TYPES,
);

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseCodexUserTurnOrdinal(uuid: string | undefined): number | null {
  if (!uuid) return null;
  const match = uuid.match(CODEX_USER_TURN_UUID_RE);
  if (!match) return null;
  const ordinal = Number(match[1]);
  return Number.isInteger(ordinal) && ordinal > 0 ? ordinal : null;
}

export function countCodexUserTurnsInSession(session: SessionInfo): number {
  let count = 0;
  let maxOrdinal = 0;

  const observe = (uuid?: string): void => {
    count += 1;
    const ordinal = parseCodexUserTurnOrdinal(uuid);
    if (ordinal !== null) {
      maxOrdinal = Math.max(maxOrdinal, ordinal);
    }
  };

  if (Array.isArray(session.pastMessages)) {
    for (const message of session.pastMessages) {
      if (!message || typeof message !== "object") continue;
      const item = message as { role?: unknown; uuid?: unknown; isMeta?: unknown };
      if (item.role === "user" && item.isMeta !== true) {
        observe(typeof item.uuid === "string" ? item.uuid : undefined);
      }
    }
  }

  for (const message of session.history) {
    if (message.type === "user_input") {
      observe(message.userMessageUuid);
    }
  }

  return Math.max(count, maxOrdinal);
}

export function nextCodexUserTurnUuid(session: SessionInfo): string {
  return codexUserTurnUuid(countCodexUserTurnsInSession(session) + 1);
}

export function normalizeHistoryContent(
  content: unknown,
): SessionHistoryMessage["content"] {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return [];

  const normalized: Array<{
    type: string;
    text?: string;
    id?: string;
    name?: string;
    input?: Record<string, unknown>;
  }> = [];

  for (const item of content) {
    if (!item || typeof item !== "object") continue;
    const value = item as Record<string, unknown>;
    if (typeof value.type !== "string") continue;
    if (value.type === "text") {
      normalized.push({
        type: "text",
        text: typeof value.text === "string" ? value.text : "",
      });
    } else if (value.type === "tool_use") {
      normalized.push({
        type: "tool_use",
        id: typeof value.id === "string" ? value.id : undefined,
        name: typeof value.name === "string" ? value.name : undefined,
        input:
          value.input && typeof value.input === "object" && !Array.isArray(value.input)
            ? (value.input as Record<string, unknown>)
            : undefined,
      });
    }
  }

  return normalized;
}

export function buildCodexHistoryPrefix(
  session: SessionInfo,
  targetOrdinal: number,
): SessionHistoryMessage[] {
  const messages: SessionHistoryMessage[] = [];
  let userOrdinal = 0;
  let reachedEnd = false;

  const appendPastMessage = (message: unknown): void => {
    if (reachedEnd || !message || typeof message !== "object") return;
    const item = message as SessionHistoryMessage;
    if (item.role === "user" && item.isMeta !== true) {
      userOrdinal += 1;
      if (userOrdinal > targetOrdinal) {
        reachedEnd = true;
        return;
      }
      messages.push({ ...item });
      return;
    }
    if (item.role === "assistant" && userOrdinal > 0 && userOrdinal <= targetOrdinal) {
      messages.push({ ...item });
    }
  };

  for (const message of session.pastMessages ?? []) {
    appendPastMessage(message);
    if (reachedEnd) return messages;
  }

  for (const message of session.history) {
    if (message.type === "user_input") {
      if (message.isMeta === true) continue;
      const userInput = message as typeof message & { timestamp?: string };
      userOrdinal += 1;
      if (userOrdinal > targetOrdinal) break;
      messages.push({
        role: "user",
        uuid: userInput.userMessageUuid,
        timestamp: userInput.timestamp,
        imageCount: userInput.imageCount,
        content: [{ type: "text", text: userInput.text }],
      });
    } else if (
      message.type === "assistant" &&
      userOrdinal > 0 &&
      userOrdinal <= targetOrdinal
    ) {
      messages.push({
        role: "assistant",
        uuid: message.messageUuid,
        content: normalizeHistoryContent(message.message.content),
      });
    }
  }

  return messages;
}

export function countCodexHistoryUserTurns(messages: SessionHistoryMessage[]): number {
  return messages.filter((message) => message.role === "user" && !message.isMeta)
    .length;
}

// ---- Codex mode mapping helpers ----

/** Map unified PermissionMode to Codex approval_policy.
 *  Only "bypassPermissions" maps to "never"; all others use "on-request". */
export function permissionModeToApprovalPolicy(mode?: string): "never" | "on-request" {
  return mode === "bypassPermissions" ? "never" : "on-request";
}

export function normalizeCodexApprovalPolicy(
  value?: string,
): "never" | "on-request" | "on-failure" | "untrusted" {
  switch (value) {
    case "untrusted":
      return "untrusted";
    case "on-failure":
      return "on-failure";
    case "never":
      return "never";
    case "on-request":
    default:
      return "on-request";
  }
}

export type CodexPermissionsMode = NonNullable<
  CodexStartOptions["codexPermissionsMode"]
>;

export interface CodexPermissionSettings {
  codexPermissionsMode?: CodexPermissionsMode;
  approvalPolicy?: CodexStartOptions["approvalPolicy"];
  approvalsReviewer?: CodexStartOptions["approvalsReviewer"];
  sandboxMode?: CodexStartOptions["sandboxMode"];
}

export function isCodexAutoReviewApprovalsReviewer(value: unknown): boolean {
  return value === "auto_review" || value === "guardian_subagent";
}

export function sanitizeCodexModel(model: unknown): string | undefined {
  if (typeof model !== "string") return undefined;
  const normalized = model.trim();
  if (!normalized || normalized === "codex") return undefined;
  return normalized;
}

export function codexSettingsFromPermissionsMode(
  mode: CodexPermissionsMode,
): CodexPermissionSettings {
  switch (mode) {
    case "default":
      return {
        codexPermissionsMode: mode,
        approvalPolicy: "on-request",
        approvalsReviewer: "user",
        sandboxMode: "workspace-write",
      };
    case "autoReview":
      return {
        codexPermissionsMode: mode,
        approvalPolicy: "on-request",
        approvalsReviewer: "auto_review",
        sandboxMode: "workspace-write",
      };
    case "fullAccess":
      return {
        codexPermissionsMode: mode,
        approvalPolicy: "never",
        approvalsReviewer: "user",
        sandboxMode: "danger-full-access",
      };
    case "custom":
      return { codexPermissionsMode: mode };
  }
}

export function errorMessageOf(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export function isClaudeAutoModeUnavailableError(err: unknown): boolean {
  const message = errorMessageOf(err).toLowerCase();
  const autoMentionsMode =
    message.includes("auto mode") ||
    message.includes('permission mode "auto"') ||
    message.includes("permission mode auto") ||
    message.includes("mode auto");
  if (!autoMentionsMode) return false;
  return (
    message.includes("unavailable") ||
    message.includes("not available") ||
    message.includes("unsupported") ||
    message.includes("not supported") ||
    message.includes("disabled") ||
    message.includes("requires") ||
    message.includes("only available") ||
    message.includes("not enabled")
  );
}

export function deriveExecutionMode(params: {
  permissionMode?: string;
  executionMode?: string;
  approvalPolicy?: string;
  provider?: Provider;
}): "default" | "acceptEdits" | "fullAccess" {
  if (
    params.executionMode === "default" ||
    params.executionMode === "acceptEdits" ||
    params.executionMode === "fullAccess"
  ) {
    return params.executionMode;
  }
  if (
    params.permissionMode === "bypassPermissions" ||
    params.approvalPolicy === "never"
  ) {
    return "fullAccess";
  }
  if (params.permissionMode === "acceptEdits") {
    return params.provider === "codex" ? "default" : "acceptEdits";
  }
  return "default";
}

export function derivePlanMode(params: {
  permissionMode?: string;
  planMode?: boolean;
  collaborationMode?: "plan" | "default";
}): boolean {
  return (
    params.planMode ??
    (params.permissionMode === "plan" || params.collaborationMode === "plan")
  );
}

export function modesToLegacyPermissionMode(
  provider: Provider,
  executionMode: "default" | "acceptEdits" | "fullAccess",
  planMode: boolean,
): "default" | "acceptEdits" | "bypassPermissions" | "plan" {
  if (planMode) return "plan";
  switch (executionMode) {
    case "fullAccess":
      return "bypassPermissions";
    case "acceptEdits":
      return "acceptEdits";
    case "default":
    default:
      return provider === "codex" ? "acceptEdits" : "default";
  }
}

/** Map simplified SandboxMode (on/off) to Codex internal sandbox mode. */
export function sandboxModeToInternal(
  mode?: string,
): "read-only" | "workspace-write" | "danger-full-access" {
  switch (mode) {
    case "danger-full-access":
    case "workspace-write":
    case "read-only":
      return mode;
    case "off":
      return "danger-full-access";
    default:
      return "workspace-write";
  }
}

/** Map Codex internal sandbox mode back to simplified on/off for clients. */
export function sandboxModeToExternal(mode?: string): "on" | "off" {
  return mode === "danger-full-access" ? "off" : "on";
}

export function threadTimestampToIso(value: number): string {
  return value > 0 ? new Date(value * 1000).toISOString() : "";
}

export function envFlagEnabled(name: string): boolean {
  const value = process.env[name]?.trim().toLowerCase();
  return value === "1" || value === "true" || value === "yes" || value === "on";
}

export const MAX_TIMER_DELAY_MS = 2_147_483_647;

export function positiveEnvInt(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isSafeInteger(value) && value > 0 ? value : fallback;
}

export function nonNegativeEnvInt(name: string, fallback: number): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isSafeInteger(value) &&
    value >= 0 &&
    value <= MAX_TIMER_DELAY_MS
    ? value
    : fallback;
}

export function normalizePositiveLimit(
  value: number | undefined,
  fallback: number,
): number {
  return value !== undefined && Number.isSafeInteger(value) && value > 0
    ? value
    : fallback;
}

export function normalizeNonNegativeLimit(
  value: number | undefined,
  fallback: number,
): number {
  return value !== undefined &&
    Number.isSafeInteger(value) &&
    value >= 0 &&
    value <= MAX_TIMER_DELAY_MS
    ? value
    : fallback;
}

export const FILE_PEEK_MEDIA_TYPES: Record<
  string,
  { kind: "audio" | "video"; mimeType: string }
> = {
  ".wav": { kind: "audio", mimeType: "audio/wav" },
  ".mp3": { kind: "audio", mimeType: "audio/mpeg" },
  ".m4a": { kind: "audio", mimeType: "audio/mp4" },
  ".aac": { kind: "audio", mimeType: "audio/aac" },
  ".flac": { kind: "audio", mimeType: "audio/flac" },
  ".ogg": { kind: "audio", mimeType: "audio/ogg" },
  ".opus": { kind: "audio", mimeType: "audio/ogg" },
  ".aif": { kind: "audio", mimeType: "audio/aiff" },
  ".aiff": { kind: "audio", mimeType: "audio/aiff" },
  ".aifc": { kind: "audio", mimeType: "audio/aiff" },
  ".mp4": { kind: "video", mimeType: "video/mp4" },
  ".mov": { kind: "video", mimeType: "video/quicktime" },
  ".m4v": { kind: "video", mimeType: "video/x-m4v" },
  ".webm": { kind: "video", mimeType: "video/webm" },
  ".mkv": { kind: "video", mimeType: "video/x-matroska" },
  ".avi": { kind: "video", mimeType: "video/x-msvideo" },
  ".mpg": { kind: "video", mimeType: "video/mpeg" },
  ".mpeg": { kind: "video", mimeType: "video/mpeg" },
};

export function downloadMimeType(filePath: string): string {
  const extension = extname(filePath).toLowerCase();
  const mediaType = FILE_PEEK_MEDIA_TYPES[extension];
  if (mediaType) return mediaType.mimeType;
  const mimeTypes: Record<string, string> = {
    ".glb": "model/gltf-binary",
    ".bmp": "image/bmp",
    ".csv": "text/csv",
    ".doc": "application/msword",
    ".docx":
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".gif": "image/gif",
    ".gz": "application/gzip",
    ".html": "text/html",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".json": "application/json",
    ".md": "text/markdown",
    ".pdf": "application/pdf",
    ".png": "image/png",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx":
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".svg": "image/svg+xml",
    ".tar": "application/x-tar",
    ".txt": "text/plain",
    ".webp": "image/webp",
    ".xls": "application/vnd.ms-excel",
    ".xlsx":
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".xml": "application/xml",
    ".zip": "application/zip",
  };
  return mimeTypes[extension] ?? "application/octet-stream";
}

export const MAX_DEBUG_EVENTS = 800;

export const MAX_HISTORY_SUMMARY_ITEMS = 300;

export const CONNECT_METADATA_REFRESH_COOLDOWN_MS = 5 * 60 * 1000;

export const DEFAULT_FILE_LIST_MAX_ENTRIES = 5000;

export const DEFAULT_FILE_LIST_MAX_BYTES = 512 * 1024;

export const DEFAULT_FILE_DOWNLOAD_MAX_BYTES = 512 * 1024 * 1024;

export const DEFAULT_FILE_UPLOAD_MAX_BYTES = 512 * 1024 * 1024;

export const DEFAULT_DELTA_BATCH_MS = 100;

export const DEFAULT_DELTA_BATCH_MAX_CHARS = 4096;

// ---------------------------------------------------------------------------
// Image diff helpers
// ---------------------------------------------------------------------------

export const IMAGE_EXTENSIONS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".ico",
  ".bmp",
  ".svg",
]);

export const FILE_PEEK_IMAGE_EXTENSIONS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".svg",
]);

// Image diff thresholds (configurable via environment variables)
// - Auto-display: images ≤ threshold are sent inline as base64
// - Max size: images ≤ max are available for on-demand loading
// - Images > max size show text info only
export const AUTO_DISPLAY_THRESHOLD = (() => {
  const kb = parseInt(process.env.DIFF_IMAGE_AUTO_DISPLAY_KB ?? "", 10);
  return Number.isFinite(kb) && kb > 0 ? kb * 1024 : 1024 * 1024; // default 1 MB
})();

export const MAX_IMAGE_SIZE = (() => {
  const mb = parseInt(process.env.DIFF_IMAGE_MAX_SIZE_MB ?? "", 10);
  return Number.isFinite(mb) && mb > 0 ? mb * 1024 * 1024 : 5 * 1024 * 1024; // default 5 MB
})();

export function mimeTypeForExt(ext: string): string {
  const map: Record<string, string> = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".ico": "image/x-icon",
    ".bmp": "image/bmp",
    ".svg": "image/svg+xml",
  };
  return map[ext.toLowerCase()] ?? "application/octet-stream";
}
