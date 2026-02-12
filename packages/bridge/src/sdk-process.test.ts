import { describe, it, expect } from "vitest";
import {
  parseRule,
  matchesSessionRule,
  buildSessionRule,
  ACCEPT_EDITS_AUTO_APPROVE,
  sdkMessageToServerMessage,
} from "./sdk-process.js";

// ---- ACCEPT_EDITS_AUTO_APPROVE ----

describe("ACCEPT_EDITS_AUTO_APPROVE", () => {
  it("contains file operation tools", () => {
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Read")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Edit")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Write")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Glob")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Grep")).toBe(true);
  });

  it("contains task tools", () => {
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("TaskCreate")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("TaskUpdate")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("TaskList")).toBe(true);
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("TaskGet")).toBe(true);
  });

  it("does not contain Bash", () => {
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("Bash")).toBe(false);
  });

  it("does not contain ExitPlanMode", () => {
    expect(ACCEPT_EDITS_AUTO_APPROVE.has("ExitPlanMode")).toBe(false);
  });
});

// ---- parseRule ----

describe("parseRule", () => {
  it("parses simple tool name", () => {
    expect(parseRule("Edit")).toEqual({ toolName: "Edit" });
  });

  it("parses ToolName(content) format", () => {
    expect(parseRule("Bash(npm:*)")).toEqual({
      toolName: "Bash",
      ruleContent: "npm:*",
    });
  });

  it("parses ToolName(content) with complex content", () => {
    expect(parseRule("Bash(git commit -m:*)")).toEqual({
      toolName: "Bash",
      ruleContent: "git commit -m:*",
    });
  });

  it("returns toolName only for empty parens (no content inside)", () => {
    // Empty parens "Bash()" -> regex requires [^)]+ so it won't match
    expect(parseRule("Bash()")).toEqual({ toolName: "Bash()" });
  });

  it("handles tool name with no parens", () => {
    expect(parseRule("WebSearch")).toEqual({ toolName: "WebSearch" });
  });
});

// ---- matchesSessionRule ----

describe("matchesSessionRule", () => {
  it("matches exact tool name rule", () => {
    const rules = new Set(["Edit"]);
    expect(matchesSessionRule("Edit", {}, rules)).toBe(true);
  });

  it("does not match different tool name", () => {
    const rules = new Set(["Edit"]);
    expect(matchesSessionRule("Write", {}, rules)).toBe(false);
  });

  it("matches Bash prefix rule with :* suffix", () => {
    const rules = new Set(["Bash(npm:*)"]);
    expect(matchesSessionRule("Bash", { command: "npm install foo" }, rules)).toBe(true);
  });

  it("matches Bash prefix rule - first word match", () => {
    const rules = new Set(["Bash(git:*)"]);
    expect(matchesSessionRule("Bash", { command: "git status" }, rules)).toBe(true);
  });

  it("does not match Bash prefix rule with different command", () => {
    const rules = new Set(["Bash(npm:*)"]);
    expect(matchesSessionRule("Bash", { command: "git push" }, rules)).toBe(false);
  });

  it("matches Bash exact command rule", () => {
    const rules = new Set(["Bash(ls -la)"]);
    expect(matchesSessionRule("Bash", { command: "ls -la" }, rules)).toBe(true);
  });

  it("does not match Bash exact rule with different command", () => {
    const rules = new Set(["Bash(ls -la)"]);
    expect(matchesSessionRule("Bash", { command: "ls -l" }, rules)).toBe(false);
  });

  it("returns false for empty rules set", () => {
    expect(matchesSessionRule("Edit", {}, new Set())).toBe(false);
  });

  it("matches when multiple rules exist", () => {
    const rules = new Set(["Read", "Edit", "Bash(npm:*)"]);
    expect(matchesSessionRule("Edit", {}, rules)).toBe(true);
    expect(matchesSessionRule("Bash", { command: "npm test" }, rules)).toBe(true);
  });

  it("skips non-matching rules and finds match", () => {
    const rules = new Set(["Read", "Bash(git:*)"]);
    expect(matchesSessionRule("Bash", { command: "git log" }, rules)).toBe(true);
  });

  it("handles Bash rule when input has no command field", () => {
    const rules = new Set(["Bash(npm:*)"]);
    expect(matchesSessionRule("Bash", {}, rules)).toBe(false);
  });

  it("handles Bash rule when command is not a string", () => {
    const rules = new Set(["Bash(npm:*)"]);
    expect(matchesSessionRule("Bash", { command: 123 }, rules)).toBe(false);
  });
});

// ---- buildSessionRule ----

describe("buildSessionRule", () => {
  it("builds Bash prefix rule from command", () => {
    expect(buildSessionRule("Bash", { command: "npm install foo" })).toBe("Bash(npm:*)");
  });

  it("builds Bash prefix rule from single-word command", () => {
    expect(buildSessionRule("Bash", { command: "ls" })).toBe("Bash(ls:*)");
  });

  it("returns tool name only for non-Bash tool", () => {
    expect(buildSessionRule("Edit", { file_path: "/tmp/foo" })).toBe("Edit");
  });

  it("returns tool name only for Bash with no command", () => {
    expect(buildSessionRule("Bash", {})).toBe("Bash");
  });

  it("returns tool name only for Bash with non-string command", () => {
    expect(buildSessionRule("Bash", { command: 42 })).toBe("Bash");
  });

  it("handles Bash with whitespace-padded command", () => {
    expect(buildSessionRule("Bash", { command: "  git status  " })).toBe("Bash(git:*)");
  });

  it("returns tool name for Bash with empty string command", () => {
    expect(buildSessionRule("Bash", { command: "" })).toBe("Bash");
  });
});

// ---- sdkMessageToServerMessage ----

describe("sdkMessageToServerMessage", () => {
  describe("tool_use_summary handling", () => {
    it("converts SDKToolUseSummaryMessage to ServerMessage", () => {
      const sdkMsg = {
        type: "tool_use_summary" as const,
        summary: "Read 3 files and analyzed code",
        preceding_tool_use_ids: ["tu-1", "tu-2", "tu-3"],
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg);

      expect(serverMsg).toEqual({
        type: "tool_use_summary",
        summary: "Read 3 files and analyzed code",
        precedingToolUseIds: ["tu-1", "tu-2", "tu-3"],
      });
    });

    it("handles empty preceding_tool_use_ids", () => {
      const sdkMsg = {
        type: "tool_use_summary" as const,
        summary: "Quick analysis completed",
        preceding_tool_use_ids: [],
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg);

      expect(serverMsg).toEqual({
        type: "tool_use_summary",
        summary: "Quick analysis completed",
        precedingToolUseIds: [],
      });
    });
  });

  describe("result message stop_reason handling", () => {
    it("forwards stop_reason from success result", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "success",
        result: "Done",
        total_cost_usd: 0.05,
        duration_ms: 1234,
        stop_reason: "end_turn",
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toEqual({
        type: "result",
        subtype: "success",
        result: "Done",
        cost: 0.05,
        duration: 1234,
        sessionId: "test-session",
        stopReason: "end_turn",
      });
    });

    it("forwards stop_reason from error result", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "error",
        errors: ["Something failed"],
        stop_reason: "max_tokens",
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toEqual({
        type: "result",
        subtype: "error",
        error: "Something failed",
        sessionId: "test-session",
        stopReason: "max_tokens",
      });
    });

    it("omits stopReason when not present in SDK message", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "success",
        result: "Done",
        total_cost_usd: 0.01,
        duration_ms: 500,
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "result",
        subtype: "success",
      });
      expect((serverMsg as any).stopReason).toBeUndefined();
    });
  });

  describe("returns null for unhandled message types", () => {
    it("returns null for unknown message type", () => {
      const sdkMsg = {
        type: "unknown_type" as const,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toBeNull();
    });
  });

  describe("UUID tracking", () => {
    it("includes messageUuid for assistant messages with uuid", () => {
      const sdkMsg = {
        type: "assistant" as const,
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Hello" }],
        },
        uuid: "ast-uuid-123" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "assistant",
        messageUuid: "ast-uuid-123",
      });
    });

    it("omits messageUuid for assistant messages without uuid", () => {
      const sdkMsg = {
        type: "assistant" as const,
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Hello" }],
        },
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({ type: "assistant" });
      expect((serverMsg as any).messageUuid).toBeUndefined();
    });

    it("includes userMessageUuid for tool_result from user messages with uuid", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [
            {
              type: "tool_result",
              tool_use_id: "tu-1",
              content: "result text",
            },
          ],
        },
        uuid: "usr-uuid-456" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "tool_result",
        toolUseId: "tu-1",
        userMessageUuid: "usr-uuid-456",
      });
    });

    it("omits userMessageUuid for tool_result from user messages without uuid", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [
            {
              type: "tool_result",
              tool_use_id: "tu-1",
              content: "result text",
            },
          ],
        },
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "tool_result",
        toolUseId: "tu-1",
      });
      expect((serverMsg as any).userMessageUuid).toBeUndefined();
    });
  });
});
