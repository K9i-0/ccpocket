// ---- Claude CLI stream-json event types ----

export interface SystemInitEvent {
  type: "system";
  subtype: "init";
  session_id: string;
  tools: string[];
  model: string;
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

export type AssistantContent = AssistantTextContent | AssistantToolUseContent;

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
  content: string;
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
  cost_usd: number;
  duration_ms: number;
  duration_api_ms: number;
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

export type ClaudeEvent =
  | SystemInitEvent
  | AssistantMessageEvent
  | UserToolResultEvent
  | ResultSuccessEvent
  | ResultErrorEvent;

// ---- Client <-> Server message types ----

export type ClientMessage =
  | { type: "start"; projectPath: string }
  | { type: "input"; text: string }
  | { type: "approve"; id: string }
  | { type: "reject"; id: string };

export type ServerMessage =
  | { type: "system"; subtype: string; sessionId?: string; model?: string }
  | { type: "assistant"; message: AssistantMessageEvent["message"] }
  | { type: "tool_result"; toolUseId: string; content: string }
  | { type: "result"; subtype: string; result?: string; error?: string; cost?: number; duration?: number }
  | { type: "error"; message: string }
  | { type: "status"; status: ProcessStatus }
  | { type: "history"; messages: ServerMessage[] };

export type ProcessStatus = "idle" | "running" | "waiting_approval";

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
      // Send each tool result as a separate message; return the first one here
      // Additional results should be handled by the caller if needed
      const first = results[0];
      return {
        type: "tool_result",
        toolUseId: first.tool_use_id,
        content: first.content,
      };
    }

    case "result":
      if (event.subtype === "success") {
        const success = event as ResultSuccessEvent;
        return {
          type: "result",
          subtype: "success",
          result: success.result,
          cost: success.cost_usd,
          duration: success.duration_ms,
        };
      } else {
        const error = event as ResultErrorEvent;
        return {
          type: "result",
          subtype: "error",
          error: error.error,
        };
      }

    default:
      return null;
  }
}

export function parseClientMessage(data: string): ClientMessage | null {
  try {
    const msg = JSON.parse(data) as ClientMessage;
    if (!msg.type) return null;
    return msg;
  } catch {
    return null;
  }
}
