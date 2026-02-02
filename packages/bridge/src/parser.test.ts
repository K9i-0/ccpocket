import { describe, it, expect } from "vitest";
import {
  normalizeToolResultContent,
  parseClaudeEvent,
  claudeEventToServerMessage,
  parseClientMessage,
  type ClaudeEvent,
} from "./parser.js";

// ---- normalizeToolResultContent ----

describe("normalizeToolResultContent", () => {
  it("returns string as-is", () => {
    expect(normalizeToolResultContent("hello")).toBe("hello");
  });

  it("returns empty string for empty string input", () => {
    expect(normalizeToolResultContent("")).toBe("");
  });

  it("extracts text blocks from array", () => {
    const content = [
      { type: "text", text: "line1" },
      { type: "text", text: "line2" },
    ];
    expect(normalizeToolResultContent(content)).toBe("line1\nline2");
  });

  it("filters out non-text blocks", () => {
    const content = [
      { type: "text", text: "keep" },
      { type: "image", data: "abc" },
      { type: "text", text: "also keep" },
    ];
    expect(normalizeToolResultContent(content)).toBe("keep\nalso keep");
  });

  it("returns empty string for empty array", () => {
    expect(normalizeToolResultContent([])).toBe("");
  });

  it("handles non-string non-array via String()", () => {
    expect(normalizeToolResultContent(42 as unknown as string)).toBe("42");
  });

  it("handles null/undefined via fallback", () => {
    expect(normalizeToolResultContent(null as unknown as string)).toBe("");
    expect(normalizeToolResultContent(undefined as unknown as string)).toBe("");
  });
});

// ---- parseClaudeEvent ----

describe("parseClaudeEvent", () => {
  it("parses valid JSON with type", () => {
    const event = parseClaudeEvent('{"type":"system","subtype":"init","session_id":"s1","tools":[],"model":"opus"}');
    expect(event).not.toBeNull();
    expect(event!.type).toBe("system");
  });

  it("returns null for empty string", () => {
    expect(parseClaudeEvent("")).toBeNull();
  });

  it("returns null for whitespace-only string", () => {
    expect(parseClaudeEvent("   \n  ")).toBeNull();
  });

  it("returns null for invalid JSON", () => {
    expect(parseClaudeEvent("{not json}")).toBeNull();
  });

  it("returns null for valid JSON without type field", () => {
    expect(parseClaudeEvent('{"foo":"bar"}')).toBeNull();
  });

  it("trims whitespace before parsing", () => {
    const event = parseClaudeEvent('  {"type":"assistant","message":{"id":"m1","role":"assistant","content":[],"model":"opus"}}  ');
    expect(event).not.toBeNull();
    expect(event!.type).toBe("assistant");
  });
});

// ---- claudeEventToServerMessage ----

describe("claudeEventToServerMessage", () => {
  it("converts system/init event", () => {
    const event: ClaudeEvent = {
      type: "system",
      subtype: "init",
      session_id: "s1",
      tools: ["Read", "Write"],
      model: "opus",
      slash_commands: ["/help"],
      skills: ["commit"],
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "system",
      subtype: "init",
      sessionId: "s1",
      model: "opus",
      slashCommands: ["/help"],
      skills: ["commit"],
    });
  });

  it("omits slashCommands and skills when not present", () => {
    const event: ClaudeEvent = {
      type: "system",
      subtype: "init",
      session_id: "s2",
      tools: [],
      model: "sonnet",
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "system",
      subtype: "init",
      sessionId: "s2",
      model: "sonnet",
    });
  });

  it("converts assistant event", () => {
    const event: ClaudeEvent = {
      type: "assistant",
      message: {
        id: "msg_1",
        role: "assistant",
        content: [{ type: "text", text: "Hello" }],
        model: "opus",
      },
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "assistant",
      message: event.message,
    });
  });

  it("converts user/tool_result event", () => {
    const event: ClaudeEvent = {
      type: "user",
      message: {
        role: "user",
        content: [
          { type: "tool_result", tool_use_id: "tu1", content: "output text" },
        ],
      },
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "tool_result",
      toolUseId: "tu1",
      content: "output text",
    });
  });

  it("returns null for user event with no tool_result content", () => {
    const event: ClaudeEvent = {
      type: "user",
      message: {
        role: "user",
        content: [] as any,
      },
    };
    expect(claudeEventToServerMessage(event)).toBeNull();
  });

  it("converts result/success event", () => {
    const event: ClaudeEvent = {
      type: "result",
      subtype: "success",
      result: "done",
      total_cost_usd: 0.05,
      duration_ms: 1234,
      duration_api_ms: 1000,
      num_turns: 3,
      is_error: false,
      session_id: "s1",
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "result",
      subtype: "success",
      result: "done",
      cost: 0.05,
      duration: 1234,
      sessionId: "s1",
    });
  });

  it("converts result/error event", () => {
    const event: ClaudeEvent = {
      type: "result",
      subtype: "error",
      error: "something failed",
      is_error: true,
      session_id: "s2",
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({
      type: "result",
      subtype: "error",
      error: "something failed",
      sessionId: "s2",
    });
  });

  it("converts stream_event text_delta", () => {
    const event: ClaudeEvent = {
      type: "stream_event",
      event: {
        type: "content_block_delta",
        index: 0,
        delta: { type: "text_delta", text: "hi" },
      },
      parent_tool_use_id: null,
      uuid: "u1",
      session_id: "s1",
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({ type: "stream_delta", text: "hi" });
  });

  it("converts stream_event thinking_delta", () => {
    const event: ClaudeEvent = {
      type: "stream_event",
      event: {
        type: "content_block_delta",
        index: 0,
        delta: { type: "thinking_delta", thinking: "hmm" },
      },
      parent_tool_use_id: null,
      uuid: "u2",
      session_id: "s1",
    };
    const msg = claudeEventToServerMessage(event);
    expect(msg).toEqual({ type: "thinking_delta", text: "hmm" });
  });

  it("returns null for stream_event with non-delta event type", () => {
    const event: ClaudeEvent = {
      type: "stream_event",
      event: { type: "message_start", message: {} },
      parent_tool_use_id: null,
      uuid: "u3",
      session_id: "s1",
    };
    expect(claudeEventToServerMessage(event)).toBeNull();
  });

  it("returns null for stream_event content_block_delta with input_json_delta", () => {
    const event: ClaudeEvent = {
      type: "stream_event",
      event: {
        type: "content_block_delta",
        index: 0,
        delta: { type: "input_json_delta", partial_json: '{"a":' },
      },
      parent_tool_use_id: null,
      uuid: "u4",
      session_id: "s1",
    };
    expect(claudeEventToServerMessage(event)).toBeNull();
  });

  it("returns null for text_delta with empty text", () => {
    const event: ClaudeEvent = {
      type: "stream_event",
      event: {
        type: "content_block_delta",
        index: 0,
        delta: { type: "text_delta", text: "" },
      },
      parent_tool_use_id: null,
      uuid: "u5",
      session_id: "s1",
    };
    expect(claudeEventToServerMessage(event)).toBeNull();
  });
});

// ---- parseClientMessage ----

describe("parseClientMessage", () => {
  it("parses start message", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/tmp/foo"}');
    expect(msg).toEqual({ type: "start", projectPath: "/tmp/foo" });
  });

  it("parses start with optional fields", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/p","sessionId":"s1","continue":true,"permissionMode":"acceptEdits"}');
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      sessionId: "s1",
      continue: true,
      permissionMode: "acceptEdits",
    });
  });

  it("rejects start without projectPath", () => {
    expect(parseClientMessage('{"type":"start"}')).toBeNull();
  });

  it("parses input message", () => {
    const msg = parseClientMessage('{"type":"input","text":"hello"}');
    expect(msg).toEqual({ type: "input", text: "hello" });
  });

  it("rejects input without text", () => {
    expect(parseClientMessage('{"type":"input"}')).toBeNull();
  });

  it("parses approve message", () => {
    const msg = parseClientMessage('{"type":"approve","id":"tu1"}');
    expect(msg).toEqual({ type: "approve", id: "tu1" });
  });

  it("rejects approve without id", () => {
    expect(parseClientMessage('{"type":"approve"}')).toBeNull();
  });

  it("parses approve_always message", () => {
    const msg = parseClientMessage('{"type":"approve_always","id":"tu2"}');
    expect(msg).toEqual({ type: "approve_always", id: "tu2" });
  });

  it("rejects approve_always without id", () => {
    expect(parseClientMessage('{"type":"approve_always"}')).toBeNull();
  });

  it("parses reject message", () => {
    const msg = parseClientMessage('{"type":"reject","id":"tu3","message":"no"}');
    expect(msg).toEqual({ type: "reject", id: "tu3", message: "no" });
  });

  it("rejects reject without id", () => {
    expect(parseClientMessage('{"type":"reject"}')).toBeNull();
  });

  it("parses answer message", () => {
    const msg = parseClientMessage('{"type":"answer","toolUseId":"tu4","result":"yes"}');
    expect(msg).toEqual({ type: "answer", toolUseId: "tu4", result: "yes" });
  });

  it("rejects answer without toolUseId", () => {
    expect(parseClientMessage('{"type":"answer","result":"yes"}')).toBeNull();
  });

  it("rejects answer without result", () => {
    expect(parseClientMessage('{"type":"answer","toolUseId":"tu4"}')).toBeNull();
  });

  it("parses list_sessions message", () => {
    const msg = parseClientMessage('{"type":"list_sessions"}');
    expect(msg).toEqual({ type: "list_sessions" });
  });

  it("parses stop_session message", () => {
    const msg = parseClientMessage('{"type":"stop_session","sessionId":"s1"}');
    expect(msg).toEqual({ type: "stop_session", sessionId: "s1" });
  });

  it("rejects stop_session without sessionId", () => {
    expect(parseClientMessage('{"type":"stop_session"}')).toBeNull();
  });

  it("parses get_history message", () => {
    const msg = parseClientMessage('{"type":"get_history","sessionId":"s2"}');
    expect(msg).toEqual({ type: "get_history", sessionId: "s2" });
  });

  it("rejects get_history without sessionId", () => {
    expect(parseClientMessage('{"type":"get_history"}')).toBeNull();
  });

  it("parses list_recent_sessions message", () => {
    const msg = parseClientMessage('{"type":"list_recent_sessions"}');
    expect(msg).toEqual({ type: "list_recent_sessions" });
  });

  it("parses resume_session message", () => {
    const msg = parseClientMessage('{"type":"resume_session","sessionId":"s3","projectPath":"/p"}');
    expect(msg).toEqual({ type: "resume_session", sessionId: "s3", projectPath: "/p" });
  });

  it("rejects resume_session without sessionId", () => {
    expect(parseClientMessage('{"type":"resume_session","projectPath":"/p"}')).toBeNull();
  });

  it("rejects resume_session without projectPath", () => {
    expect(parseClientMessage('{"type":"resume_session","sessionId":"s3"}')).toBeNull();
  });

  it("parses list_gallery message", () => {
    const msg = parseClientMessage('{"type":"list_gallery"}');
    expect(msg).toEqual({ type: "list_gallery" });
  });

  it("parses list_files message", () => {
    const msg = parseClientMessage('{"type":"list_files","projectPath":"/p"}');
    expect(msg).toEqual({ type: "list_files", projectPath: "/p" });
  });

  it("rejects list_files without projectPath", () => {
    expect(parseClientMessage('{"type":"list_files"}')).toBeNull();
  });

  it("parses interrupt message", () => {
    const msg = parseClientMessage('{"type":"interrupt"}');
    expect(msg).toEqual({ type: "interrupt" });
  });

  it("returns null for unknown type", () => {
    expect(parseClientMessage('{"type":"unknown_type"}')).toBeNull();
  });

  it("returns null for missing type", () => {
    expect(parseClientMessage('{"foo":"bar"}')).toBeNull();
  });

  it("returns null for non-string type", () => {
    expect(parseClientMessage('{"type":123}')).toBeNull();
  });

  it("returns null for invalid JSON", () => {
    expect(parseClientMessage("not json")).toBeNull();
  });
});
