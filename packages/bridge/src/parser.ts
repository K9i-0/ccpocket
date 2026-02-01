import type { ImageRef } from "./image-store.js";

// Re-export for convenience
export type { ImageRef } from "./image-store.js";

// ---- Claude CLI stream-json event types ----

export interface SystemInitEvent {
  type: "system";
  subtype: "init";
  session_id: string;
  tools: string[];
  model: string;
  slash_commands?: string[];
  skills?: string[];
}

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

export interface AssistantMessageEvent {
  type: "assistant";
  message: {
    id: string;
    role: "assistant";
    content: AssistantContent[];
    model: string;
  };
}

export interface UserToolResultContent {
  type: "tool_result";
  tool_use_id: string;
  content: string | unknown[];
}

export interface UserToolResultEvent {
  type: "user";
  message: {
    role: "user";
    content: UserToolResultContent[];
  };
}

export interface ResultSuccessEvent {
  type: "result";
  subtype: "success";
  result: string;
  total_cost_usd: number;
  duration_ms: number;
  duration_api_ms: number;
  num_turns: number;
  is_error: boolean;
  session_id: string;
}

export interface ResultErrorEvent {
  type: "result";
  subtype: "error";
  error: string;
  is_error: boolean;
  session_id: string;
}

// ---- Partial message (stream_event) types ----

export interface StreamEventMessage {
  type: "stream_event";
  event: StreamEvent;
  parent_tool_use_id: string | null;
  uuid: string;
  session_id: string;
}

export type StreamEvent =
  | { type: "message_start"; message: Record<string, unknown> }
  | { type: "content_block_start"; index: number; content_block: StreamContentBlock }
  | { type: "content_block_delta"; index: number; delta: StreamDelta }
  | { type: "content_block_stop"; index: number }
  | { type: "message_delta"; delta: Record<string, unknown>; usage?: Record<string, unknown> }
  | { type: "message_stop" };

export interface StreamContentBlock {
  type: "text" | "tool_use" | "thinking";
  id?: string;
  name?: string;
  text?: string;
  thinking?: string;
}

export interface StreamDelta {
  type: "text_delta" | "input_json_delta" | "thinking_delta";
  text?: string;
  thinking?: string;
  partial_json?: string;
}

export type ClaudeEvent =
  | SystemInitEvent
  | AssistantMessageEvent
  | UserToolResultEvent
  | ResultSuccessEvent
  | ResultErrorEvent
  | StreamEventMessage;

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
  | { type: "list_recent_sessions"; limit?: number }
  | { type: "resume_session"; sessionId: string; projectPath: string; permissionMode?: PermissionMode }
  | { type: "list_gallery"; project?: string };

export type ServerMessage =
  | { type: "system"; subtype: string; sessionId?: string; model?: string; projectPath?: string; slashCommands?: string[]; skills?: string[] }
  | { type: "assistant"; message: AssistantMessageEvent["message"] }
  | { type: "tool_result"; toolUseId: string; content: string; toolName?: string; images?: ImageRef[] }
  | { type: "result"; subtype: string; result?: string; error?: string; cost?: number; duration?: number; sessionId?: string }
  | { type: "error"; message: string }
  | { type: "status"; status: ProcessStatus }
  | { type: "history"; messages: ServerMessage[] }
  | { type: "permission_request"; toolUseId: string; toolName: string; input: Record<string, unknown> }
  | { type: "stream_delta"; text: string }
  | { type: "thinking_delta"; text: string };

export type ProcessStatus = "idle" | "running" | "waiting_approval";

// ---- Helpers ----

/** Normalize tool_result content: Claude CLI may send string or array of content blocks. */
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

export function parseClaudeEvent(line: string): ClaudeEvent | null {
  const trimmed = line.trim();
  if (trimmed === "") return null;

  try {
    const event = JSON.parse(trimmed) as ClaudeEvent;
    if (!event.type) return null;
    return event;
  } catch {
    console.error("[parser] Failed to parse JSON line:", trimmed.slice(0, 200));
    return null;
  }
}

export function claudeEventToServerMessage(event: ClaudeEvent): ServerMessage | null {
  switch (event.type) {
    case "system":
      return {
        type: "system",
        subtype: event.subtype,
        sessionId: event.session_id,
        model: event.model,
        ...(event.slash_commands ? { slashCommands: event.slash_commands } : {}),
        ...(event.skills ? { skills: event.skills } : {}),
      };

    case "assistant":
      return {
        type: "assistant",
        message: event.message,
      };

    case "user": {
      const results = event.message.content.filter(
        (c): c is UserToolResultContent => c.type === "tool_result"
      );
      if (results.length === 0) return null;
      const first = results[0];
      return {
        type: "tool_result",
        toolUseId: first.tool_use_id,
        content: normalizeToolResultContent(first.content),
      };
    }

    case "result":
      if (event.subtype === "success") {
        const success = event as ResultSuccessEvent;
        return {
          type: "result",
          subtype: "success",
          result: success.result,
          cost: success.total_cost_usd,
          duration: success.duration_ms,
          sessionId: success.session_id,
        };
      } else {
        const error = event as ResultErrorEvent;
        return {
          type: "result",
          subtype: "error",
          error: error.error,
          sessionId: error.session_id,
        };
      }

    case "stream_event": {
      if (event.event.type === "content_block_delta") {
        // Extract text deltas for real-time streaming display
        if (event.event.delta.type === "text_delta" && event.event.delta.text) {
          return {
            type: "stream_delta",
            text: event.event.delta.text,
          };
        }
        // Extract thinking deltas for real-time thinking display
        if (event.event.delta.type === "thinking_delta" && event.event.delta.thinking) {
          return {
            type: "thinking_delta",
            text: event.event.delta.thinking,
          };
        }
      }
      return null;
    }

    default:
      return null;
  }
}

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
      default:
        return null;
    }

    return msg as unknown as ClientMessage;
  } catch {
    return null;
  }
}
