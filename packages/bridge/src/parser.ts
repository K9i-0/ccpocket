import type { ImageRef } from "./image-store.js";

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

export type ClientMessage =
  | { type: "start"; projectPath: string; sessionId?: string; continue?: boolean; permissionMode?: PermissionMode }
  | { type: "input"; text: string; sessionId?: string }
  | { type: "approve"; id: string; sessionId?: string }
  | { type: "approve_always"; id: string; sessionId?: string }
  | { type: "reject"; id: string; message?: string; sessionId?: string }
  | { type: "answer"; toolUseId: string; result: string; sessionId?: string }
  | { type: "list_sessions" }
  | { type: "stop_session"; sessionId: string }
  | { type: "get_history"; sessionId: string }
  | { type: "list_recent_sessions"; limit?: number; offset?: number; projectPath?: string }
  | { type: "resume_session"; sessionId: string; projectPath: string; permissionMode?: PermissionMode }
  | { type: "list_gallery"; project?: string; sessionId?: string }
  | { type: "list_files"; projectPath: string }
  | { type: "get_diff"; projectPath: string }
  | { type: "interrupt"; sessionId?: string }
  | { type: "list_project_history" }
  | { type: "remove_project_history"; projectPath: string };

export type ServerMessage =
  | { type: "system"; subtype: string; sessionId?: string; model?: string; projectPath?: string; slashCommands?: string[]; skills?: string[] }
  | { type: "assistant"; message: AssistantMessage }
  | { type: "tool_result"; toolUseId: string; content: string; toolName?: string; images?: ImageRef[] }
  | { type: "result"; subtype: string; result?: string; error?: string; cost?: number; duration?: number; sessionId?: string }
  | { type: "error"; message: string }
  | { type: "status"; status: ProcessStatus }
  | { type: "history"; messages: ServerMessage[] }
  | { type: "permission_request"; toolUseId: string; toolName: string; input: Record<string, unknown> }
  | { type: "stream_delta"; text: string }
  | { type: "thinking_delta"; text: string }
  | { type: "file_list"; files: string[] }
  | { type: "project_history"; projects: string[] }
  | { type: "diff_result"; diff: string; error?: string };

export type ProcessStatus = "starting" | "idle" | "running" | "waiting_approval";

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
        break;
      case "input":
        if (typeof msg.text !== "string") return null;
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
      default:
        return null;
    }

    return msg as unknown as ClientMessage;
  } catch {
    return null;
  }
}
