import type { GalleryImageInfo } from "./gallery-store.js";
import type { ImageRef } from "./image-store.js";
import type { WindowInfo } from "./screenshot.js";
import type { WorktreeInfo } from "./worktree.js";

// Re-export for convenience
export type { ImageRef } from "./image-store.js";

// ---- Assistant message content types (used by ServerMessage and session.ts) ----

export interface AssistantTextContent {
  type: "text";
  text: string;
}

export interface AssistantToolUseContent {
  type: "tool_use";
  id: string;
  name: string;
  input: Record<string, unknown>;
}

export interface AssistantThinkingContent {
  type: "thinking";
  thinking: string;
}

export type AssistantContent = AssistantTextContent | AssistantToolUseContent | AssistantThinkingContent;

/** Shape of the assistant message object within ServerMessage. */
export interface AssistantMessage {
  id: string;
  role: "assistant";
  content: AssistantContent[];
  model: string;
}

// ---- Client <-> Server message types ----

export type PermissionMode =
  | "default"
  | "acceptEdits"
  | "bypassPermissions"
  | "plan"
  | "delegate"
  | "dontAsk";

export type Provider = "claude" | "codex";

export type ClientMessage =
  | {
      type: "start";
      projectPath: string;
      provider?: Provider;
      sessionId?: string;
      continue?: boolean;
      permissionMode?: PermissionMode;
      approvalPolicy?: string;
      sandboxMode?: string;
      model?: string;
      effort?: "low" | "medium" | "high" | "max";
      maxTurns?: number;
      maxBudgetUsd?: number;
      fallbackModel?: string;
      forkSession?: boolean;
      persistSession?: boolean;
      modelReasoningEffort?: string;
      networkAccessEnabled?: boolean;
      webSearchMode?: string;
      useWorktree?: boolean;
      worktreeBranch?: string;
      existingWorktreePath?: string;
    }
  | { type: "input"; text: string; sessionId?: string; imageId?: string; imageBase64?: string; mimeType?: string }
  | { type: "push_register"; token: string; platform: "ios" | "android" | "web" }
  | { type: "push_unregister"; token: string }
  | { type: "set_permission_mode"; mode: PermissionMode; sessionId?: string }
  | { type: "approve"; id: string; updatedInput?: Record<string, unknown>; clearContext?: boolean; sessionId?: string }
  | { type: "approve_always"; id: string; sessionId?: string }
  | { type: "reject"; id: string; message?: string; sessionId?: string }
  | { type: "answer"; toolUseId: string; result: string; sessionId?: string }
  | { type: "list_sessions" }
  | { type: "stop_session"; sessionId: string }
  | { type: "get_history"; sessionId: string }
  | { type: "list_recent_sessions"; limit?: number; offset?: number; projectPath?: string }
  | {
      type: "resume_session";
      sessionId: string;
      projectPath: string;
      permissionMode?: PermissionMode;
      provider?: Provider;
      approvalPolicy?: string;
      sandboxMode?: string;
      model?: string;
      effort?: "low" | "medium" | "high" | "max";
      maxTurns?: number;
      maxBudgetUsd?: number;
      fallbackModel?: string;
      forkSession?: boolean;
      persistSession?: boolean;
      modelReasoningEffort?: string;
      networkAccessEnabled?: boolean;
      webSearchMode?: string;
    }
  | { type: "list_gallery"; project?: string; sessionId?: string }
  | { type: "list_files"; projectPath: string }
  | { type: "get_diff"; projectPath: string }
  | { type: "interrupt"; sessionId?: string }
  | { type: "list_project_history" }
  | { type: "remove_project_history"; projectPath: string }
  | { type: "list_worktrees"; projectPath: string }
  | { type: "remove_worktree"; projectPath: string; worktreePath: string }
  | { type: "rewind"; sessionId: string; targetUuid: string; mode: "conversation" | "code" | "both" }
  | { type: "rewind_dry_run"; sessionId: string; targetUuid: string }
  | { type: "list_windows" }
  | { type: "take_screenshot"; mode: "fullscreen" | "window"; windowId?: number; projectPath: string; sessionId?: string }
  | { type: "get_debug_bundle"; sessionId: string; traceLimit?: number; includeDiff?: boolean };

export interface DebugTraceEvent {
  ts: string;
  sessionId: string;
  direction: "incoming" | "outgoing" | "internal";
  channel: "ws" | "session" | "bridge";
  type: string;
  detail?: string;
}

export type ServerMessage =
  | { type: "system"; subtype: string; sessionId?: string; model?: string; provider?: Provider; projectPath?: string; slashCommands?: string[]; skills?: string[]; worktreePath?: string; worktreeBranch?: string; permissionMode?: PermissionMode }
  | { type: "assistant"; message: AssistantMessage; messageUuid?: string }
  | { type: "tool_result"; toolUseId: string; content: string; toolName?: string; images?: ImageRef[]; userMessageUuid?: string }
  | {
      type: "result";
      subtype: string;
      result?: string;
      error?: string;
      cost?: number;
      duration?: number;
      sessionId?: string;
      stopReason?: string;
      inputTokens?: number;
      cachedInputTokens?: number;
      outputTokens?: number;
      toolCalls?: number;
      fileEdits?: number;
    }
  | { type: "error"; message: string }
  | { type: "status"; status: ProcessStatus }
  | { type: "history"; messages: ServerMessage[] }
  | { type: "permission_request"; toolUseId: string; toolName: string; input: Record<string, unknown> }
  | { type: "stream_delta"; text: string }
  | { type: "thinking_delta"; text: string }
  | { type: "file_list"; files: string[] }
  | { type: "project_history"; projects: string[] }
  | { type: "diff_result"; diff: string; error?: string }
  | { type: "worktree_list"; worktrees: WorktreeInfo[] }
  | { type: "worktree_removed"; worktreePath: string }
  | { type: "tool_use_summary"; summary: string; precedingToolUseIds: string[] }
  | { type: "rewind_preview"; canRewind: boolean; filesChanged?: string[]; insertions?: number; deletions?: number; error?: string }
  | { type: "rewind_result"; success: boolean; mode: "conversation" | "code" | "both"; error?: string }
  | { type: "user_input"; text: string; userMessageUuid?: string }
  | { type: "window_list"; windows: WindowInfo[] }
  | { type: "screenshot_result"; success: boolean; image?: GalleryImageInfo; error?: string }
  | {
      type: "debug_bundle";
      sessionId: string;
      generatedAt: string;
      session: {
        id: string;
        provider: Provider;
        status: ProcessStatus;
        projectPath: string;
        worktreePath?: string;
        worktreeBranch?: string;
        claudeSessionId?: string;
        createdAt: string;
        lastActivityAt: string;
      };
      pastMessageCount: number;
      historySummary: string[];
      debugTrace: DebugTraceEvent[];
      traceFilePath: string;
      reproRecipe: {
        wsUrlHint: string;
        startBridgeCommand: string;
        resumeSessionMessage: Record<string, unknown>;
        getHistoryMessage: Record<string, unknown>;
        getDebugBundleMessage: Record<string, unknown>;
        notes: string[];
      };
      agentPrompt: string;
      diff: string;
      diffError?: string;
      savedBundlePath?: string;
    };

export type ProcessStatus = "starting" | "idle" | "running" | "waiting_approval" | "clearing";

// ---- Helpers ----

/** Normalize tool_result content: may be string or array of content blocks. */
export function normalizeToolResultContent(content: string | unknown[]): string {
  if (Array.isArray(content)) {
    return (content as Array<Record<string, unknown>>)
      .filter((c) => c.type === "text")
      .map((c) => c.text as string)
      .join("\n");
  }
  return typeof content === "string" ? content : String(content ?? "");
}

// ---- Parser ----

export function parseClientMessage(data: string): ClientMessage | null {
  try {
    const msg = JSON.parse(data) as Record<string, unknown>;
    if (!msg.type || typeof msg.type !== "string") return null;

    switch (msg.type) {
      case "start":
        if (typeof msg.projectPath !== "string") return null;
        if (msg.model !== undefined && typeof msg.model !== "string") return null;
        if (msg.effort !== undefined && !["low", "medium", "high", "max"].includes(String(msg.effort))) return null;
        if (
          msg.maxTurns !== undefined
          && (!Number.isInteger(msg.maxTurns) || Number(msg.maxTurns) < 1)
        ) return null;
        if (
          msg.maxBudgetUsd !== undefined
          && (typeof msg.maxBudgetUsd !== "number" || !Number.isFinite(msg.maxBudgetUsd) || msg.maxBudgetUsd < 0)
        ) return null;
        if (msg.fallbackModel !== undefined && typeof msg.fallbackModel !== "string") return null;
        if (msg.forkSession !== undefined && typeof msg.forkSession !== "boolean") return null;
        if (msg.persistSession !== undefined && typeof msg.persistSession !== "boolean") return null;
        if (msg.networkAccessEnabled !== undefined && typeof msg.networkAccessEnabled !== "boolean") return null;
        if (
          msg.modelReasoningEffort !== undefined
          && !["minimal", "low", "medium", "high", "xhigh"].includes(String(msg.modelReasoningEffort))
        ) return null;
        if (
          msg.webSearchMode !== undefined
          && !["disabled", "cached", "live"].includes(String(msg.webSearchMode))
        ) return null;
        break;
      case "input":
        if (typeof msg.text !== "string") return null;
        // imageBase64 requires mimeType
        if (msg.imageBase64 && typeof msg.mimeType !== "string") return null;
        break;
      case "push_register":
        if (typeof msg.token !== "string") return null;
        if (msg.platform !== "ios" && msg.platform !== "android" && msg.platform !== "web") return null;
        break;
      case "push_unregister":
        if (typeof msg.token !== "string") return null;
        break;
      case "set_permission_mode":
        if (
          typeof msg.mode !== "string"
          || !["default", "acceptEdits", "bypassPermissions", "plan", "delegate", "dontAsk"].includes(msg.mode)
        ) return null;
        break;
      case "approve":
        if (typeof msg.id !== "string") return null;
        break;
      case "approve_always":
        if (typeof msg.id !== "string") return null;
        break;
      case "reject":
        if (typeof msg.id !== "string") return null;
        break;
      case "answer":
        if (typeof msg.toolUseId !== "string" || typeof msg.result !== "string") return null;
        break;
      case "list_sessions":
        break;
      case "stop_session":
        if (typeof msg.sessionId !== "string") return null;
        break;
      case "get_history":
        if (typeof msg.sessionId !== "string") return null;
        break;
      case "list_recent_sessions":
        break;
      case "resume_session":
        if (typeof msg.sessionId !== "string" || typeof msg.projectPath !== "string") return null;
        if (msg.provider && msg.provider !== "claude" && msg.provider !== "codex") return null;
        if (msg.model !== undefined && typeof msg.model !== "string") return null;
        if (msg.effort !== undefined && !["low", "medium", "high", "max"].includes(String(msg.effort))) return null;
        if (
          msg.maxTurns !== undefined
          && (!Number.isInteger(msg.maxTurns) || Number(msg.maxTurns) < 1)
        ) return null;
        if (
          msg.maxBudgetUsd !== undefined
          && (typeof msg.maxBudgetUsd !== "number" || !Number.isFinite(msg.maxBudgetUsd) || msg.maxBudgetUsd < 0)
        ) return null;
        if (msg.fallbackModel !== undefined && typeof msg.fallbackModel !== "string") return null;
        if (msg.forkSession !== undefined && typeof msg.forkSession !== "boolean") return null;
        if (msg.persistSession !== undefined && typeof msg.persistSession !== "boolean") return null;
        if (msg.networkAccessEnabled !== undefined && typeof msg.networkAccessEnabled !== "boolean") return null;
        if (
          msg.modelReasoningEffort !== undefined
          && !["minimal", "low", "medium", "high", "xhigh"].includes(String(msg.modelReasoningEffort))
        ) return null;
        if (
          msg.webSearchMode !== undefined
          && !["disabled", "cached", "live"].includes(String(msg.webSearchMode))
        ) return null;
        break;
      case "list_gallery":
        break;
      case "list_files":
        if (typeof msg.projectPath !== "string") return null;
        break;
      case "get_diff":
        if (typeof msg.projectPath !== "string") return null;
        break;
      case "interrupt":
        break;
      case "list_project_history":
        break;
      case "remove_project_history":
        if (typeof msg.projectPath !== "string") return null;
        break;
      case "list_worktrees":
        if (typeof msg.projectPath !== "string") return null;
        break;
      case "remove_worktree":
        if (typeof msg.projectPath !== "string" || typeof msg.worktreePath !== "string") return null;
        break;
      case "rewind":
        if (typeof msg.sessionId !== "string" || typeof msg.targetUuid !== "string") return null;
        if (msg.mode !== "conversation" && msg.mode !== "code" && msg.mode !== "both") return null;
        break;
      case "rewind_dry_run":
        if (typeof msg.sessionId !== "string" || typeof msg.targetUuid !== "string") return null;
        break;
      case "list_windows":
        break;
      case "take_screenshot":
        if (msg.mode !== "fullscreen" && msg.mode !== "window") return null;
        if (msg.mode === "window" && typeof msg.windowId !== "number") return null;
        if (typeof msg.projectPath !== "string") return null;
        break;
      case "get_debug_bundle":
        if (typeof msg.sessionId !== "string") return null;
        if (msg.traceLimit !== undefined && typeof msg.traceLimit !== "number") return null;
        if (msg.includeDiff !== undefined && typeof msg.includeDiff !== "boolean") return null;
        break;
      default:
        return null;
    }

    return msg as unknown as ClientMessage;
  } catch {
    return null;
  }
}
