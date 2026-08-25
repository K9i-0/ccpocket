import { afterEach, beforeEach, describe, it, expect, vi } from "vitest";
import {
  parseRule,
  matchesSessionRule,
  buildSessionRule,
  buildAskUserAnswers,
  resolvePermissionMode,
  ACCEPT_EDITS_AUTO_APPROVE,
  extractTokenUsage,
  buildThinkingOptions,
  isFileEditToolName,
  sdkMessageToServerMessage,
  hasExplicitClaudeCredential,
  isClaudeOAuthOptInEnabled,
  listAvailableClaudeModels,
  SdkProcess,
} from "./sdk-process.js";
import type { ServerMessage } from "./parser.js";

const { mockSdkQuery } = vi.hoisted(() => ({
  mockSdkQuery: vi.fn(),
}));

vi.mock("@anthropic-ai/claude-agent-sdk", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@anthropic-ai/claude-agent-sdk")>()),
  query: mockSdkQuery,
}));

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

describe("isFileEditToolName", () => {
  it("returns true for file mutation tools", () => {
    expect(isFileEditToolName("Edit")).toBe(true);
    expect(isFileEditToolName("Write")).toBe(true);
    expect(isFileEditToolName("MultiEdit")).toBe(true);
    expect(isFileEditToolName("NotebookEdit")).toBe(true);
  });

  it("returns false for non-file tools", () => {
    expect(isFileEditToolName("Read")).toBe(false);
    expect(isFileEditToolName("Bash")).toBe(false);
  });
});

describe("extractTokenUsage", () => {
  it("extracts snake_case usage fields", () => {
    expect(
      extractTokenUsage({
        input_tokens: 1200,
        cached_input_tokens: 300,
        output_tokens: 450,
      }),
    ).toEqual({
      inputTokens: 1200,
      cachedInputTokens: 300,
      outputTokens: 450,
    });
  });

  it("extracts camelCase usage fields", () => {
    expect(
      extractTokenUsage({
        inputTokens: 10,
        cacheReadInputTokens: 4,
        outputTokens: 20,
      }),
    ).toEqual({
      inputTokens: 10,
      cachedInputTokens: 4,
      outputTokens: 20,
    });
  });

  it("returns empty object for invalid usage payload", () => {
    expect(extractTokenUsage(null)).toEqual({});
    expect(extractTokenUsage("invalid")).toEqual({});
    expect(extractTokenUsage([])).toEqual({});
  });
});

describe("buildThinkingOptions", () => {
  it("forces adaptive thinking for claude-opus-4-7", () => {
    expect(buildThinkingOptions("claude-opus-4-7")).toEqual({
      thinking: { type: "adaptive" },
    });
  });

  it("forces adaptive thinking for claude-opus-4-7[1m]", () => {
    expect(buildThinkingOptions("claude-opus-4-7[1m]")).toEqual({
      thinking: { type: "adaptive" },
    });
  });

  it("returns empty options for other models", () => {
    expect(buildThinkingOptions("claude-sonnet-4-6")).toEqual({});
  });
});

// ---- sdkMessageToServerMessage ----

describe("sdkMessageToServerMessage", () => {
  describe("assistant thinking filtering", () => {
    it("removes whitespace-only thinking while preserving visible content", () => {
      const sdkMsg = {
        type: "assistant" as const,
        message: {
          role: "assistant",
          content: [
            { type: "thinking", thinking: " \n\t " },
            { type: "text", text: "Visible response" },
          ],
        },
        session_id: "test-session",
      };

      expect(sdkMessageToServerMessage(sdkMsg as any)).toMatchObject({
        type: "assistant",
        message: {
          content: [{ type: "text", text: "Visible response" }],
        },
      });
    });

    it("drops assistant messages containing only whitespace thinking", () => {
      const sdkMsg = {
        type: "assistant" as const,
        message: {
          role: "assistant",
          content: [{ type: "thinking", thinking: "\n  " }],
        },
        session_id: "test-session",
      };

      expect(sdkMessageToServerMessage(sdkMsg as any)).toBeNull();
    });
  });

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

    it("suppresses Claude's internal EDE diagnostic result", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "error_during_execution",
        errors: [
          "[ede_diagnostic] result_type=user last_content_type=n/a stop_reason=tool_use",
        ],
        stop_reason: "tool_use",
        session_id: "test-session",
      };

      expect(sdkMessageToServerMessage(sdkMsg as any)).toBeNull();
    });

    it("keeps a real error while removing its internal EDE diagnostic", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "error_during_execution",
        errors: [
          "[ede_diagnostic] result_type=user last_content_type=n/a stop_reason=tool_use",
          "MCP server disconnected",
        ],
        stop_reason: "tool_use",
        session_id: "test-session",
      };

      expect(sdkMessageToServerMessage(sdkMsg as any)).toEqual({
        type: "result",
        subtype: "error",
        error: "MCP server disconnected",
        sessionId: "test-session",
        stopReason: "tool_use",
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

    it("includes token usage from SDK result.usage", () => {
      const sdkMsg = {
        type: "result" as const,
        subtype: "success",
        result: "Done",
        total_cost_usd: 0.02,
        duration_ms: 777,
        usage: {
          input_tokens: 1234,
          cached_input_tokens: 321,
          output_tokens: 456,
        },
        uuid: "test-uuid" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "result",
        subtype: "success",
        inputTokens: 1234,
        cachedInputTokens: 321,
        outputTokens: 456,
      });
    });
  });

  describe("Claude status handling", () => {
    it("surfaces context compaction failures", () => {
      expect(
        sdkMessageToServerMessage({
          type: "system",
          subtype: "status",
          status: null,
          compact_result: "failed",
          compact_error: "summary request timed out",
          session_id: "test-session",
        } as any),
      ).toEqual({
        type: "error",
        message: "Claude context compaction failed: summary request timed out",
        errorCode: "claude_compaction_failed",
      });
    });

    it("uses a stable fallback when compaction has no error detail", () => {
      expect(
        sdkMessageToServerMessage({
          type: "system",
          subtype: "status",
          status: null,
          compact_result: "failed",
          session_id: "test-session",
        } as any),
      ).toEqual({
        type: "error",
        message: "Claude context compaction failed.",
        errorCode: "claude_compaction_failed",
      });
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

    it("converts user text-only message to user_input", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [{ type: "text", text: "Hello Claude" }],
        },
        uuid: "usr-text-789" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "user_input",
        text: "Hello Claude",
        userMessageUuid: "usr-text-789",
      });
    });

    it("converts user text-only message without uuid", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [{ type: "text", text: "Hello" }],
        },
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "user_input",
        text: "Hello",
      });
      expect((serverMsg as any).userMessageUuid).toBeUndefined();
    });

    it("passes isSynthetic flag on synthetic user message", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [{ type: "text", text: "Plan approval prompt" }],
        },
        isSynthetic: true,
        uuid: "usr-syn-111" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "user_input",
        text: "Plan approval prompt",
        userMessageUuid: "usr-syn-111",
        isSynthetic: true,
      });
    });

    it("marks internal task notifications as synthetic when the SDK omits the flag", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [
            {
              type: "text",
              text: "<task-notification>\n<status>killed</status>\n</task-notification>",
            },
          ],
        },
        uuid: "usr-task-111" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "user_input",
        isSynthetic: true,
      });
    });

    it("omits isSynthetic when not set on user message", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [{ type: "text", text: "Hello Claude" }],
        },
        uuid: "usr-real-222" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "user_input",
        text: "Hello Claude",
        userMessageUuid: "usr-real-222",
      });
      expect((serverMsg as any).isSynthetic).toBeUndefined();
    });

    it("prefers tool_result over text when both present in user message", () => {
      const sdkMsg = {
        type: "user" as const,
        message: {
          role: "user",
          content: [
            { type: "text", text: "some text" },
            { type: "tool_result", tool_use_id: "tu-mix", content: "result" },
          ],
        },
        uuid: "usr-mix-000" as `${string}-${string}-${string}-${string}-${string}`,
        session_id: "test-session",
      };

      const serverMsg = sdkMessageToServerMessage(sdkMsg as any);

      expect(serverMsg).toMatchObject({
        type: "tool_result",
        toolUseId: "tu-mix",
        userMessageUuid: "usr-mix-000",
      });
    });
  });
});

// ---- SdkProcess.approveAlways permission mode transition ----

describe("SdkProcess.approveAlways", () => {
  /** Create a SdkProcess and inject a pending permission via private fields. */
  function setupApproveAlways(toolName: string, initialMode?: string) {
    const proc = new SdkProcess();
    const internal = proc as any;
    internal._permissionMode = initialMode ?? "default";
    internal._sessionId = "test-session";

    const resolve = vi.fn();
    internal.pendingPermissions.set("tool-1", {
      resolve,
      toolName,
      input: { file_path: "/test/file.ts" },
    });

    const messages: ServerMessage[] = [];
    proc.on("message", (msg) => messages.push(msg));

    return { proc, resolve, messages };
  }

  it("emits set_permission_mode when file-edit tool is always-approved", () => {
    const { proc, resolve, messages } = setupApproveAlways("Edit");

    proc.approveAlways("tool-1");

    // Should emit set_permission_mode with acceptEdits
    const modeMsg = messages.find(
      (m) => m.type === "system" && (m as any).subtype === "set_permission_mode"
    );
    expect(modeMsg).toBeDefined();
    expect((modeMsg as any).permissionMode).toBe("acceptEdits");
    expect((modeMsg as any).sessionId).toBe("test-session");

    // Internal state should be updated
    expect(proc.permissionMode).toBe("acceptEdits");

    // Resolve should have been called with allow + updatedPermissions
    expect(resolve).toHaveBeenCalledWith(
      expect.objectContaining({
        behavior: "allow",
        updatedPermissions: expect.arrayContaining([
          expect.objectContaining({ type: "addRules", destination: "session" }),
        ]),
      })
    );
  });

  it("emits set_permission_mode for Write tool", () => {
    const { proc, messages } = setupApproveAlways("Write");

    proc.approveAlways("tool-1");

    const modeMsg = messages.find(
      (m) => m.type === "system" && (m as any).subtype === "set_permission_mode"
    );
    expect(modeMsg).toBeDefined();
    expect(proc.permissionMode).toBe("acceptEdits");
  });

  it("does NOT emit set_permission_mode for non-file-edit tool (Bash)", () => {
    const { proc, messages } = setupApproveAlways("Bash");

    proc.approveAlways("tool-1");

    const modeMsg = messages.find(
      (m) => m.type === "system" && (m as any).subtype === "set_permission_mode"
    );
    expect(modeMsg).toBeUndefined();
    expect(proc.permissionMode).toBe("default");
  });

  it("does NOT emit set_permission_mode for non-file-edit tool (Read)", () => {
    const { proc, messages } = setupApproveAlways("Read");

    proc.approveAlways("tool-1");

    const modeMsg = messages.find(
      (m) => m.type === "system" && (m as any).subtype === "set_permission_mode"
    );
    expect(modeMsg).toBeUndefined();
    expect(proc.permissionMode).toBe("default");
  });

  it("does NOT re-emit when already in acceptEdits mode", () => {
    const { proc, messages } = setupApproveAlways("Edit", "acceptEdits");

    proc.approveAlways("tool-1");

    const modeMsg = messages.find(
      (m) => m.type === "system" && (m as any).subtype === "set_permission_mode"
    );
    expect(modeMsg).toBeUndefined();
    expect(proc.permissionMode).toBe("acceptEdits");
  });

  it("reports whether a requested tool action was accepted", () => {
    const { proc } = setupApproveAlways("Bash");

    expect(proc.approveAlways("tool-1")).toBe(true);
    expect(proc.approve("missing")).toBe(false);
    expect(proc.approveAlways("missing")).toBe(false);
    expect(proc.reject("missing")).toBe(false);
    expect(proc.answer("missing", "answer")).toBe(false);
  });
});

describe("SdkProcess input dispatch", () => {
  it("queues and requests interrupt while a turn is running", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const internal = proc as any;
    internal._status = "running";
    internal.userMessageResolve = resolve;

    expect(proc.dispatchInput("follow up")).toEqual({
      queued: true,
      shouldInterrupt: true,
    });
    expect(resolve).not.toHaveBeenCalled();
    expect(proc.hasInputQueue).toBe(true);
  });

  it("queues without interrupting while approval is pending", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const internal = proc as any;
    internal._status = "waiting_approval";
    internal.userMessageResolve = resolve;

    expect(proc.dispatchInput("after approval")).toEqual({
      queued: true,
      shouldInterrupt: false,
    });
    expect(resolve).not.toHaveBeenCalled();
  });

  it.each(["starting", "idle"])(
    "delivers directly through the ready resolver while %s",
    (status) => {
      const proc = new SdkProcess();
      const resolve = vi.fn();
      const internal = proc as any;
      internal._status = status;
      internal.userMessageResolve = resolve;

      expect(proc.dispatchInput("first input")).toEqual({
        queued: false,
        shouldInterrupt: false,
      });
      expect(resolve).toHaveBeenCalledTimes(1);
      expect(proc.hasInputQueue).toBe(false);
      expect(proc.status).toBe("running");
    },
  );

  it("applies the running policy to image input", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const internal = proc as any;
    internal._status = "running";
    internal.userMessageResolve = resolve;

    expect(
      proc.dispatchInputWithImages("inspect", [
        { base64: "aW1hZ2U=", mimeType: "image/png" },
      ]),
    ).toEqual({ queued: true, shouldInterrupt: true });
    expect(resolve).not.toHaveBeenCalled();
  });

  it("marks directly delivered image input as running", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const internal = proc as any;
    internal._status = "idle";
    internal.userMessageResolve = resolve;

    expect(
      proc.dispatchInputWithImages("inspect", [
        { base64: "aW1hZ2U=", mimeType: "image/png" },
      ]),
    ).toEqual({ queued: false, shouldInterrupt: false });
    expect(resolve).toHaveBeenCalledTimes(1);
    expect(proc.status).toBe("running");
  });

  it("drains queued input FIFO one item per result when a consumer is waiting", () => {
    const proc = new SdkProcess();
    const internal = proc as any;
    const firstResolve = vi.fn();
    internal._status = "running";
    internal.userMessageResolve = firstResolve;

    proc.dispatchInput("first");
    proc.dispatchInput("second");
    internal.updateStatusFromMessage({
      type: "result",
      subtype: "error_during_execution",
    });

    expect(firstResolve).toHaveBeenCalledTimes(1);
    expect(firstResolve.mock.calls[0][0].message.content).toEqual([
      { type: "text", text: "first" },
    ]);
    expect(proc.hasInputQueue).toBe(true);

    const secondResolve = vi.fn();
    internal.userMessageResolve = secondResolve;
    internal.updateStatusFromMessage({ type: "result", subtype: "success" });

    expect(firstResolve).toHaveBeenCalledTimes(1);
    expect(secondResolve).toHaveBeenCalledTimes(1);
    expect(secondResolve.mock.calls[0][0].message.content).toEqual([
      { type: "text", text: "second" },
    ]);
    expect(proc.hasInputQueue).toBe(false);
  });

  it("keeps queued input until a consumer is waiting", () => {
    const proc = new SdkProcess();
    const internal = proc as any;
    internal._status = "running";
    internal.userMessageResolve = null;

    proc.dispatchInput("later");
    internal.updateStatusFromMessage({ type: "result", subtype: "success" });

    expect(proc.hasInputQueue).toBe(true);
  });

  it("drains only one queued item per result with a greedy stream consumer", async () => {
    const proc = new SdkProcess();
    const internal = proc as any;
    internal._status = "running";

    proc.dispatchInput("first");
    proc.dispatchInput("second");

    const stream = internal.createUserMessageStream();
    const firstRequest = stream.next();
    let secondResolved = false;
    const secondRequest = stream.next().then((result: any) => {
      secondResolved = true;
      return result;
    });
    await Promise.resolve();

    expect(internal.userMessageResolve).toEqual(expect.any(Function));
    expect(proc.hasInputQueue).toBe(true);

    internal.updateStatusFromMessage({
      type: "result",
      subtype: "error_during_execution",
    });
    const first = await firstRequest;

    expect(first.value.message.content).toEqual([
      { type: "text", text: "first" },
    ]);
    await new Promise<void>((resolve) => setImmediate(resolve));

    expect(secondResolved).toBe(false);
    expect(internal.userMessageResolve).toEqual(expect.any(Function));
    expect(proc.hasInputQueue).toBe(true);
    expect(proc.status).toBe("running");

    internal.updateStatusFromMessage({ type: "result", subtype: "success" });
    const second = await secondRequest;
    expect(second.value.message.content).toEqual([
      { type: "text", text: "second" },
    ]);
    expect(proc.hasInputQueue).toBe(false);
    expect(proc.status).toBe("running");

    await stream.return(undefined);
  });

});

describe("SdkProcess Claude authentication", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.stubEnv("ANTHROPIC_API_KEY", "");
    vi.stubEnv("ANTHROPIC_AUTH_TOKEN", "");
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "");
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  async function runSdkMessages(
    sdkMessages: unknown[],
    permissionMode?: "acceptEdits",
    iteratorError?: Error,
    initializationResult?: () => Promise<unknown>,
    expectedExit = iteratorError ? 1 : 0,
  ) {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const statuses: string[] = [];
    const exits: Array<number | null> = [];
    proc.on("message", (message) => messages.push(message));
    proc.on("status", (status) => statuses.push(status));
    proc.on("exit", (code) => exits.push(code));
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        yield* sdkMessages;
        if (iteratorError) throw iteratorError;
      },
      close: vi.fn(),
      supportedCommands: vi.fn().mockResolvedValue([]),
      ...(initializationResult ? { initializationResult } : {}),
    });

    proc.start(process.cwd(), { permissionMode });
    await vi.waitFor(() => expect(exits).toEqual([expectedExit]), {
      timeout: 2000,
    });
    return { proc, messages, statuses };
  }

  function authTurn(apiKeySource: string, sessionId = "auth-session") {
    return [
      {
        type: "system",
        subtype: "init",
        session_id: sessionId,
        model: "claude-sonnet-4-6",
        apiKeySource,
      },
      {
        type: "result",
        subtype: "success",
        result: "Done",
        total_cost_usd: 4.7011,
        duration_ms: 100,
        session_id: sessionId,
      },
    ];
  }

  it("requires the exact OAuth opt-in value", () => {
    expect(isClaudeOAuthOptInEnabled({ BRIDGE_ALLOW_CLAUDE_OAUTH: "1" })).toBe(true);
    expect(isClaudeOAuthOptInEnabled({ BRIDGE_ALLOW_CLAUDE_OAUTH: "true" })).toBe(false);
    expect(isClaudeOAuthOptInEnabled({ BRIDGE_ALLOW_CLAUDE_OAUTH: "0" })).toBe(false);
    expect(isClaudeOAuthOptInEnabled({})).toBe(false);
  });

  it("detects explicit Claude API credentials", () => {
    expect(hasExplicitClaudeCredential({ ANTHROPIC_API_KEY: "sk-ant-test" })).toBe(true);
    expect(hasExplicitClaudeCredential({ ANTHROPIC_AUTH_TOKEN: "token" })).toBe(true);
    expect(hasExplicitClaudeCredential({ ANTHROPIC_API_KEY: "" })).toBe(false);
    expect(hasExplicitClaudeCredential({})).toBe(false);
  });

  it("blocks startup without an API credential or OAuth opt-in", async () => {
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const exits: Array<number | null> = [];
    proc.on("message", (message) => messages.push(message));
    proc.on("exit", (code) => exits.push(code));

    proc.start(process.cwd(), { initialInput: "must be discarded" });
    await vi.waitFor(() => expect(exits).toEqual([1]));

    expect(mockSdkQuery).not.toHaveBeenCalled();
    expect(proc.isRunning).toBe(false);
    expect(proc.status).toBe("idle");
    expect(proc.hasInputQueue).toBe(false);
    expect(messages).toContainEqual(expect.objectContaining({
      type: "error",
      errorCode: "claude_oauth_opt_in_required",
      message: expect.stringContaining("BRIDGE_ALLOW_CLAUDE_OAUTH=1"),
    }));
  });

  it("does not query models without an API credential or OAuth opt-in", async () => {
    await expect(listAvailableClaudeModels()).rejects.toThrow(
      "BRIDGE_ALLOW_CLAUDE_OAUTH=1",
    );
    expect(mockSdkQuery).not.toHaveBeenCalled();
  });

  it("rejects model listing when the SDK unexpectedly selects OAuth", async () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    const close = vi.fn();
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        yield {
          type: "system",
          subtype: "init",
          apiKeySource: "oauth",
        };
      },
      close,
      initializationResult: vi.fn().mockResolvedValue({
        account: { apiKeySource: "oauth" },
        models: [
          { value: "claude-sonnet-4-6", displayName: "Sonnet 4.6" },
        ],
      }),
    });

    await expect(listAvailableClaudeModels()).rejects.toThrow(
      "BRIDGE_ALLOW_CLAUDE_OAUTH=1",
    );
    expect(close).toHaveBeenCalledOnce();
  });

  it("lists models from OAuth only after explicit opt-in", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
    const close = vi.fn();
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        yield {
          type: "system",
          subtype: "init",
          apiKeySource: "oauth",
        };
      },
      close,
      initializationResult: vi.fn().mockResolvedValue({
        account: { apiKeySource: "oauth" },
        models: [
          { value: "claude-sonnet-4-6", displayName: "Sonnet 4.6" },
        ],
      }),
    });

    await expect(listAvailableClaudeModels()).resolves.toEqual([
      expect.objectContaining({
        model: "claude-sonnet-4-6",
        displayName: "Sonnet 4.6",
      }),
    ]);
    expect(close).toHaveBeenCalledOnce();
  });

  it("accepts fresh OAuth auth without exposing estimated API cost", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const exits: Array<number | null> = [];
    proc.on("message", (message) => messages.push(message));
    proc.on("exit", (code) => exits.push(code));

    const initMessage = {
      type: "system",
      subtype: "init",
      session_id: "oauth-session",
      model: "claude-sonnet-4-6",
      apiKeySource: "oauth",
    };
    const close = vi.fn();
    const initializationResult = vi.fn().mockResolvedValue({
      account: { apiKeySource: "user" },
      models: [],
    });
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        yield initMessage;
        yield authTurn("oauth", "oauth-session")[1];
      },
      close,
      supportedCommands: vi.fn().mockResolvedValue([]),
      initializationResult,
    });

    proc.start(process.cwd());
    await vi.waitFor(() => expect(exits).toEqual([0]));

    expect(proc.sessionId).toBe("oauth-session");
    expect(proc.model).toBe("claude-sonnet-4-6");
    expect(initializationResult).toHaveBeenCalledOnce();
    expect(messages).toContainEqual(expect.objectContaining({
      type: "system",
      subtype: "init",
      sessionId: "oauth-session",
    }));
    expect(messages).not.toContainEqual(expect.objectContaining({
      type: "error",
    }));
    expect(messages).toContainEqual(
      expect.objectContaining({ type: "result", subtype: "success" }),
    );
    expect(messages).not.toContainEqual(
      expect.objectContaining({ type: "result", cost: expect.any(Number) }),
    );
    expect(exits).toEqual([0]);
  });

  it("classifies resumed OAuth from initializationResult and hides cost", async () => {
    vi.stubEnv("BRIDGE_ALLOW_CLAUDE_OAUTH", "1");
    const initializationResult = vi.fn().mockResolvedValue({
      account: { apiKeySource: "oauth" },
      models: [],
    });
    const { messages } = await runSdkMessages(
      authTurn("user", "resumed-oauth-session"),
      undefined,
      undefined,
      initializationResult,
    );

    expect(initializationResult).toHaveBeenCalledOnce();
    expect(messages).not.toContainEqual(
      expect.objectContaining({ type: "result", cost: expect.any(Number) }),
    );
  });

  it("keeps cost for API key authentication", async () => {
    const initializationResult = vi.fn().mockResolvedValue({
      account: { apiKeySource: "user" },
      models: [],
    });
    const { messages } = await runSdkMessages(
      authTurn("user", "api-key-session"),
      undefined,
      undefined,
      initializationResult,
    );

    expect(initializationResult).toHaveBeenCalledOnce();
    expect(messages).toContainEqual(
      expect.objectContaining({ type: "result", cost: 4.7011 }),
    );
  });

  it("rejects OAuth from initializationResult before emitting a result", async () => {
    const initializationResult = vi.fn().mockResolvedValue({
      account: { apiKeySource: "oauth" },
      models: [],
    });
    const { messages } = await runSdkMessages(
      authTurn("user", "unapproved-oauth-session"),
      undefined,
      undefined,
      initializationResult,
      1,
    );

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "error",
        errorCode: "claude_oauth_opt_in_required",
      }),
    );
    expect(messages).not.toContainEqual(
      expect.objectContaining({ type: "result" }),
    );
  });

  it("applies late OAuth classification after timeout without leaking cost", async () => {
    vi.useFakeTimers();
    try {
      vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
      let resolveInitialization!: (value: unknown) => void;
      let finishQuery!: () => void;
      const initializationResult = vi.fn(
        () =>
          new Promise((resolve) => {
            resolveInitialization = resolve;
          }),
      );
      const queryFinished = new Promise<void>((resolve) => {
        finishQuery = resolve;
      });
      const close = vi.fn();
      mockSdkQuery.mockReturnValueOnce({
        async *[Symbol.asyncIterator]() {
          yield* authTurn("user", "late-oauth-session");
          await queryFinished;
        },
        close,
        supportedCommands: vi.fn().mockResolvedValue([]),
        initializationResult,
      });

      const proc = new SdkProcess();
      const messages: ServerMessage[] = [];
      const exits: Array<number | null> = [];
      proc.on("message", (message) => messages.push(message));
      proc.on("exit", (code) => exits.push(code));
      proc.start(process.cwd());

      await vi.advanceTimersByTimeAsync(500);
      expect(messages).toContainEqual(
        expect.objectContaining({ type: "result", subtype: "success" }),
      );
      expect(messages).not.toContainEqual(
        expect.objectContaining({ type: "result", cost: expect.any(Number) }),
      );

      resolveInitialization({
        account: { apiKeySource: "oauth" },
        models: [],
      });
      await vi.advanceTimersByTimeAsync(0);

      expect(messages).toContainEqual(
        expect.objectContaining({
          type: "error",
          errorCode: "claude_oauth_opt_in_required",
        }),
      );
      expect(close).toHaveBeenCalledOnce();
      expect(exits).toEqual([1]);

      finishQuery();
      await vi.advanceTimersByTimeAsync(0);
    } finally {
      vi.useRealTimers();
    }
  });

  it("ignores late OAuth after the query has naturally finished", async () => {
    vi.useFakeTimers();
    try {
      vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
      let resolveInitialization!: (value: unknown) => void;
      const initializationResult = vi.fn(
        () =>
          new Promise((resolve) => {
            resolveInitialization = resolve;
          }),
      );
      mockSdkQuery.mockReturnValueOnce({
        async *[Symbol.asyncIterator]() {
          yield* authTurn("user", "finished-before-auth-session");
        },
        close: vi.fn(),
        supportedCommands: vi.fn().mockResolvedValue([]),
        initializationResult,
      });

      const proc = new SdkProcess();
      const messages: ServerMessage[] = [];
      const exits: Array<number | null> = [];
      proc.on("message", (message) => messages.push(message));
      proc.on("exit", (code) => exits.push(code));
      proc.start(process.cwd());

      await vi.advanceTimersByTimeAsync(500);
      expect(exits).toEqual([0]);
      expect(messages).not.toContainEqual(
        expect.objectContaining({ type: "result", cost: expect.any(Number) }),
      );

      resolveInitialization({
        account: { apiKeySource: "oauth" },
        models: [],
      });
      await vi.advanceTimersByTimeAsync(0);

      expect(exits).toEqual([0]);
      expect(messages).not.toContainEqual(
        expect.objectContaining({
          type: "error",
          errorCode: "claude_oauth_opt_in_required",
        }),
      );
    } finally {
      vi.useRealTimers();
    }
  });

  it.each([
    {
      label: "rejects",
      initializationResult: () => Promise.reject(new Error("init unavailable")),
      exposesApiCost: true,
    },
    {
      label: "times out",
      initializationResult: () => new Promise<never>(() => {}),
      exposesApiCost: false,
    },
  ])(
    "does not block a turn when initializationResult $label",
    async ({ initializationResult, exposesApiCost }) => {
      const init = vi.fn(initializationResult);
      const { messages } = await runSdkMessages(
        authTurn("user", "fallback-api-session"),
        undefined,
        undefined,
        init,
      );

      expect(init).toHaveBeenCalledOnce();
      expect(messages).toContainEqual(
        expect.objectContaining({ type: "result", subtype: "success" }),
      );
      const result = messages.find(
        (message) => message.type === "result" && message.subtype === "success",
      );
      expect(result).toEqual(
        exposesApiCost
          ? expect.objectContaining({ cost: 4.7011 })
          : expect.not.objectContaining({ cost: expect.any(Number) }),
      );
    },
  );

  it("ignores a stale initializationResult after restart", async () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    let resolveStale!: (value: unknown) => void;
    const staleInitialization = vi.fn(
      () => new Promise((resolve) => { resolveStale = resolve; }),
    );
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const exits: Array<number | null> = [];
    proc.on("message", (message) => messages.push(message));
    proc.on("exit", (code) => exits.push(code));
    mockSdkQuery
      .mockReturnValueOnce({
        async *[Symbol.asyncIterator]() {},
        close: vi.fn(),
        supportedCommands: vi.fn().mockResolvedValue([]),
        initializationResult: staleInitialization,
      })
      .mockReturnValueOnce({
        async *[Symbol.asyncIterator]() { yield* authTurn("user", "new-session"); },
        close: vi.fn(),
        supportedCommands: vi.fn().mockResolvedValue([]),
        initializationResult: vi.fn().mockResolvedValue({
          account: { apiKeySource: "user" },
          models: [],
        }),
      });

    proc.start(process.cwd());
    await vi.waitFor(() => expect(staleInitialization).toHaveBeenCalledOnce());
    proc.stop();
    proc.start(process.cwd());
    await vi.waitFor(() => expect(exits).toEqual([0]));
    resolveStale({ account: { apiKeySource: "oauth" }, models: [] });
    await Promise.resolve();

    expect(staleInitialization).toHaveBeenCalledOnce();
    expect(messages).not.toContainEqual(expect.objectContaining({ type: "error" }));
    expect(messages).toContainEqual(
      expect.objectContaining({ type: "result", cost: 4.7011 }),
    );
  });

  it("tracks compaction lifecycle and emits one failure without changing permission mode", async () => {
    const { proc, messages, statuses } = await runSdkMessages(
      [
        {
          type: "system",
          subtype: "init",
          session_id: "compaction-session",
          model: "claude-sonnet-4-6",
          apiKeySource: "api_key",
        },
        {
          type: "system",
          subtype: "status",
          status: "compacting",
          session_id: "compaction-session",
        },
        {
          type: "system",
          subtype: "status",
          status: "requesting",
          session_id: "compaction-session",
        },
        {
          type: "system",
          subtype: "status",
          status: "compacting",
          session_id: "compaction-session",
        },
        {
          type: "system",
          subtype: "status",
          status: null,
          compact_result: "failed",
          compact_error: "summary request timed out",
          session_id: "compaction-session",
        },
      ],
      "acceptEdits",
    );

    expect(statuses).toEqual([
      "starting",
      "idle",
      "compacting",
      "running",
      "compacting",
      "running",
      "idle",
    ]);
    expect(proc.permissionMode).toBe("acceptEdits");
    expect(
      messages.filter(
        (message) =>
          message.type === "error" &&
          message.errorCode === "claude_compaction_failed",
      ),
    ).toEqual([
      {
        type: "error",
        message: "Claude context compaction failed: summary request timed out",
        errorCode: "claude_compaction_failed",
      },
    ]);
  });

  it("preserves partial assistant text and surfaces its typed error once", async () => {
    const { messages } = await runSdkMessages([
      {
          type: "system",
          subtype: "init",
          session_id: "partial-error-session",
          model: "claude-sonnet-4-6",
          apiKeySource: "api_key",
      },
      {
          type: "assistant",
          session_id: "partial-error-session",
          uuid: "assistant-error",
          error: "max_output_tokens",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "Partial useful response" }],
          },
      },
      {
          type: "result",
          subtype: "error_during_execution",
          errors: [
            "[ede_diagnostic] result_type=assistant last_content_type=text stop_reason=max_tokens",
          ],
          session_id: "partial-error-session",
      },
    ]);

    expect(messages).toContainEqual(
      expect.objectContaining({
        type: "assistant",
        message: expect.objectContaining({
          content: [{ type: "text", text: "Partial useful response" }],
        }),
      }),
    );
    expect(
      messages.filter(
        (message) =>
          message.type === "error" &&
          message.errorCode === "claude_max_output_tokens",
      ),
    ).toEqual([
      {
        type: "error",
        message: "Claude reached the maximum response length before finishing.",
        errorCode: "claude_max_output_tokens",
      },
    ]);
  });

  it("prefers a real result error over a pending assistant error", async () => {
    const { messages } = await runSdkMessages([
      {
          type: "assistant",
          session_id: "real-result-error-session",
          uuid: "assistant-error",
          error: "server_error",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "Partial response" }],
          },
      },
      {
          type: "result",
          subtype: "error_during_execution",
          errors: [
            "Bun is not defined",
            "[ede_diagnostic] internal context",
            "Upstream request failed with status 503",
          ],
          session_id: "real-result-error-session",
      },
    ]);

    expect(messages.filter((message) => message.type === "error")).toEqual([]);
    expect(
      messages.filter(
        (message) => message.type === "result" && message.subtype === "error",
      ),
    ).toEqual([
      expect.objectContaining({
        type: "result",
        subtype: "error",
        error: "Upstream request failed with status 503",
      }),
    ]);
  });

  it("flushes a typed assistant error when the SDK stream ends without a result", async () => {
    const { messages } = await runSdkMessages([
      {
        type: "assistant",
        session_id: "ended-error-session",
        uuid: "assistant-error",
        error: "authentication_failed",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "Partial response" }],
        },
      },
    ]);

    expect(messages.filter((message) => message.type === "error")).toEqual([
      expect.objectContaining({ errorCode: "auth_token_expired" }),
    ]);
  });

  it("flushes a typed assistant error instead of duplicating an iterator failure", async () => {
    const { messages } = await runSdkMessages(
      [
        {
          type: "assistant",
          session_id: "thrown-error-session",
          uuid: "assistant-error",
          error: "authentication_failed",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "Partial response" }],
          },
        },
      ],
      undefined,
      new Error("transport closed"),
    );

    expect(messages.filter((message) => message.type === "error")).toEqual([
      expect.objectContaining({ errorCode: "auth_token_expired" }),
    ]);
  });

  it.each([
    {
      assistantError: "authentication_failed",
      expectedMessage:
        "Claude authentication failed. Sign in again on the Bridge machine.",
      expectedCode: "auth_token_expired",
    },
    {
      assistantError: "unexpected_secret_runtime_value",
      expectedMessage: "Claude stopped because of an unknown request error.",
      expectedCode: "claude_assistant_error",
    },
  ])(
    "maps assistant error $assistantError to a safe structured error",
    async ({ assistantError, expectedMessage, expectedCode }) => {
      const { messages } = await runSdkMessages([
        {
            type: "assistant",
            session_id: "mapped-error-session",
            uuid: "assistant-error",
            error: assistantError,
            message: {
              role: "assistant",
              content: [{ type: "text", text: "Partial response" }],
            },
        },
        {
            type: "result",
            subtype: "error_during_execution",
            errors: [
              "[ede_diagnostic] result_type=assistant last_content_type=text",
            ],
            session_id: "mapped-error-session",
        },
      ]);

      expect(messages).toContainEqual({
        type: "error",
        message: expectedMessage,
        errorCode: expectedCode,
      });
      expect(messages.filter((message) => message.type === "error")).toHaveLength(1);
    },
  );

  it("rejects an unexpected OAuth init when only an API key was configured", async () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const exits: Array<number | null> = [];
    const close = vi.fn();
    proc.on("message", (message) => messages.push(message));
    proc.on("exit", (code) => exits.push(code));
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        yield {
          type: "system",
          subtype: "init",
          session_id: "unexpected-oauth-session",
          apiKeySource: "oauth",
        };
      },
      close,
      supportedCommands: vi.fn().mockResolvedValue([]),
    });

    proc.start(process.cwd());
    await vi.waitFor(() => expect(exits).toEqual([1]));

    expect(close).toHaveBeenCalledOnce();
    expect(messages).toContainEqual(expect.objectContaining({
      type: "error",
      errorCode: "claude_oauth_opt_in_required",
    }));
    expect(messages).not.toContainEqual(expect.objectContaining({
      type: "system",
      subtype: "init",
    }));
  });

  it("cleans up the SDK query when authentication fails", async () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    const exits: Array<number | null> = [];
    const close = vi.fn();
    proc.on("message", (message) => messages.push(message));
    proc.on("exit", (code) => exits.push(code));
    mockSdkQuery.mockReturnValueOnce({
      async *[Symbol.asyncIterator]() {
        throw new Error("authentication failed");
      },
      close,
      supportedCommands: vi.fn().mockResolvedValue([]),
    });

    proc.start(process.cwd());
    await vi.waitFor(() => expect(exits).toEqual([1]));

    expect(close).toHaveBeenCalledOnce();
    expect(proc.isRunning).toBe(false);
    expect(proc.status).toBe("idle");
    expect(messages).toContainEqual(expect.objectContaining({
      type: "error",
      message: "SDK error: authentication failed",
    }));
  });

  it("cleans up the init timer when the SDK query fails to start", () => {
    vi.stubEnv("ANTHROPIC_API_KEY", "sk-ant-test");
    const proc = new SdkProcess();
    const exits: Array<number | null> = [];
    proc.on("exit", (code) => exits.push(code));
    mockSdkQuery.mockImplementationOnce(() => {
      throw new Error("query setup failed");
    });

    expect(() => proc.start(process.cwd())).toThrow("query setup failed");

    expect(proc.isRunning).toBe(false);
    expect(proc.status).toBe("idle");
    expect((proc as any).initTimeoutId).toBeNull();
    expect(exits).toEqual([]);
  });
});

describe("buildAskUserAnswers", () => {
  const multiInput = {
    questions: [
      { question: "Which database?" },
      { question: "Which ORM?" },
    ],
  };
  const singleInput = { questions: [{ question: "Which database?" }] };

  it("maps a bare answer for a single question", () => {
    expect(buildAskUserAnswers(singleInput, "SQLite")).toEqual({
      "Which database?": "SQLite",
    });
  });

  it("maps multi-question JSON answers by question text", () => {
    const result = JSON.stringify({
      questions: multiInput.questions,
      answers: {
        "Which database?": "SQLite",
        "Which ORM?": "Drizzle, Prisma",
      },
    });
    expect(buildAskUserAnswers(multiInput, result)).toEqual({
      "Which database?": "SQLite",
      "Which ORM?": "Drizzle, Prisma",
    });
  });

  it("joins string arrays for multi-select and ignores invalid values", () => {
    const result = JSON.stringify({
      questions: multiInput.questions,
      answers: {
        "Which database?": ["SQLite", "Postgres"],
        injected: "value",
        "Which ORM?": { nested: true },
      },
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(buildAskUserAnswers(multiInput, result)).toEqual({
      "Which database?": "SQLite, Postgres",
    });
    warn.mockRestore();
  });

  it("preserves existing answers and overwrites matching new answers", () => {
    const result = JSON.stringify({
      questions: multiInput.questions,
      answers: { "Which ORM?": "Drizzle" },
    });
    expect(buildAskUserAnswers({
      ...multiInput,
      answers: { "Which database?": "SQLite", injected: "value" },
    }, result)).toEqual({
      "Which database?": "SQLite",
      "Which ORM?": "Drizzle",
    });
  });

  it("does not map non-envelope input onto the first of multiple questions", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(buildAskUserAnswers(multiInput, "SQLite")).toEqual({});
    expect(buildAskUserAnswers(multiInput, "{bad json")).toEqual({});
    warn.mockRestore();
  });

  it("preserves JSON-shaped custom text for a single question", () => {
    const result = JSON.stringify({ custom: true });
    expect(buildAskUserAnswers(singleInput, result)).toEqual({
      "Which database?": result,
    });
  });

  it("does not mistake a mismatched envelope-shaped custom answer for app data", () => {
    const result = JSON.stringify({
      questions: [],
      answers: { other: "value" },
    });
    expect(buildAskUserAnswers(singleInput, result)).toEqual({
      "Which database?": result,
    });
  });

  it("creates safe own properties for special question text", () => {
    const answers = buildAskUserAnswers(
      { questions: [{ question: "__proto__" }] },
      "safe",
    );
    expect(Object.hasOwn(answers, "__proto__")).toBe(true);
    expect(answers.__proto__).toBe("safe");
  });

  it("collapses duplicate question text deterministically", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const duplicateInput = {
      questions: [{ question: "Same" }, { question: "Same" }],
    };
    const result = JSON.stringify({
      questions: duplicateInput.questions,
      answers: { Same: "answer" },
    });
    expect(buildAskUserAnswers(duplicateInput, result)).toEqual({
      Same: "answer",
    });
    expect(buildAskUserAnswers(duplicateInput, "answer")).toEqual({});
    warn.mockRestore();
  });

  it("returns an empty map when the pending input has no question text", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(buildAskUserAnswers({ questions: [] }, "SQLite")).toEqual({});
    warn.mockRestore();
  });
});

describe("SdkProcess.answer", () => {
  it("resolves AskUserQuestion with question-keyed SDK answers", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const internal = proc as any;
    internal._status = "waiting_approval";
    internal.pendingPermissions.set("ask-1", {
      resolve,
      toolName: "AskUserQuestion",
      input: { questions: [{ question: "Which database?" }] },
    });

    proc.answer("ask-1", "SQLite");

    expect(resolve).toHaveBeenCalledWith({
      behavior: "allow",
      updatedInput: {
        questions: [{ question: "Which database?" }],
        answers: { "Which database?": "SQLite" },
      },
    });
    expect(resolve.mock.calls[0][0].updatedInput.answers).not.toHaveProperty(
      "result",
    );
    expect(proc.status).toBe("running");
  });

  it("resolves multi-question envelopes with every mapped answer", () => {
    const proc = new SdkProcess();
    const resolve = vi.fn();
    const questions = [
      { question: "Which database?" },
      { question: "Which ORM?" },
    ];
    (proc as any).pendingPermissions.set("ask-multi", {
      resolve,
      toolName: "AskUserQuestion",
      input: { questions },
    });

    proc.answer("ask-multi", JSON.stringify({
      questions,
      answers: {
        "Which database?": "SQLite",
        "Which ORM?": "Drizzle",
      },
    }));

    expect(resolve.mock.calls[0][0].updatedInput.answers).toEqual({
      "Which database?": "SQLite",
      "Which ORM?": "Drizzle",
    });
  });
});

describe("SdkProcess.setPermissionMode", () => {
  it("keeps an idle mode unless the next start explicitly overrides it", () => {
    expect(resolvePermissionMode("acceptEdits", undefined)).toBe(
      "acceptEdits",
    );
    expect(resolvePermissionMode("acceptEdits", "bypassPermissions")).toBe(
      "bypassPermissions",
    );
    expect(resolvePermissionMode(undefined, undefined)).toBeUndefined();
  });

  it("retains an idle mode when start omits permissionMode", async () => {
    const proc = new SdkProcess();
    await proc.setPermissionMode("acceptEdits");

    proc.start("/tmp");
    expect(proc.permissionMode).toBe("acceptEdits");
    proc.stop();
  });

  it("lets an explicit start mode override the retained idle mode", async () => {
    const proc = new SdkProcess();
    await proc.setPermissionMode("acceptEdits");

    proc.start("/tmp", { permissionMode: "bypassPermissions" });
    expect(proc.permissionMode).toBe("bypassPermissions");
    proc.stop();
  });

  it("records and emits a permission mode change while idle", async () => {
    const proc = new SdkProcess();
    const messages: ServerMessage[] = [];
    (proc as any)._sessionId = "claude-session";
    proc.on("message", (message) => messages.push(message));

    await proc.setPermissionMode("bypassPermissions");

    expect(proc.permissionMode).toBe("bypassPermissions");
    expect(messages).toContainEqual(expect.objectContaining({
      type: "system",
      subtype: "set_permission_mode",
      permissionMode: "bypassPermissions",
      sessionId: "claude-session",
    }));
  });

  it("applies a permission mode change to a live query before updating state", async () => {
    const proc = new SdkProcess();
    const setPermissionMode = vi.fn(async () => {});
    (proc as any).queryInstance = { setPermissionMode };

    await proc.setPermissionMode("acceptEdits");

    expect(setPermissionMode).toHaveBeenCalledWith("acceptEdits");
    expect(proc.permissionMode).toBe("acceptEdits");
  });

  it("does not update state when a live query rejects the change", async () => {
    const proc = new SdkProcess();
    (proc as any)._permissionMode = "default";
    (proc as any).queryInstance = {
      setPermissionMode: vi.fn(async () => {
        throw new Error("unsupported");
      }),
    };

    await expect(proc.setPermissionMode("auto")).rejects.toThrow("unsupported");
    expect(proc.permissionMode).toBe("default");
  });

  it("ignores an old live update that finishes after a new start", async () => {
    const proc = new SdkProcess();
    let finishUpdate!: () => void;
    const setPermissionMode = vi.fn(
      () => new Promise<void>((resolve) => {
        finishUpdate = resolve;
      }),
    );
    (proc as any).queryInstance = {
      setPermissionMode,
      close: vi.fn(),
    };
    const messages: ServerMessage[] = [];
    proc.on("message", (message) => messages.push(message));

    const oldUpdate = proc.setPermissionMode("bypassPermissions");
    await Promise.resolve();
    proc.start("/tmp", { permissionMode: "default" });
    finishUpdate();
    await oldUpdate;

    expect(proc.permissionMode).toBe("default");
    expect(messages).not.toContainEqual(expect.objectContaining({
      type: "system",
      subtype: "set_permission_mode",
      permissionMode: "bypassPermissions",
    }));
    proc.stop();
  });

  it("commits an earlier success when the next queued change fails", async () => {
    const proc = new SdkProcess();
    let finishFirst!: () => void;
    const firstUpdate = new Promise<void>((resolve) => {
      finishFirst = resolve;
    });
    const setPermissionMode = vi.fn()
      .mockImplementationOnce(() => firstUpdate)
      .mockRejectedValueOnce(new Error("unsupported"));
    (proc as any)._permissionMode = "default";
    (proc as any).queryInstance = { setPermissionMode };

    const earlier = proc.setPermissionMode("bypassPermissions");
    const later = proc.setPermissionMode("default");
    await Promise.resolve();
    finishFirst();

    await earlier;
    await expect(later).rejects.toThrow("unsupported");
    expect(setPermissionMode.mock.calls).toEqual([
      ["bypassPermissions"],
      ["default"],
    ]);
    expect(proc.permissionMode).toBe("bypassPermissions");
  });

  it("does not let an unresolved old update block the new generation", async () => {
    const proc = new SdkProcess();
    const neverFinishes = new Promise<void>(() => {});
    (proc as any).queryInstance = {
      setPermissionMode: vi.fn(() => neverFinishes),
      close: vi.fn(),
    };

    void proc.setPermissionMode("bypassPermissions");
    await Promise.resolve();
    proc.start("/tmp", { permissionMode: "acceptEdits" });
    proc.stop();

    await expect(proc.setPermissionMode("default")).resolves.toBeUndefined();
    expect(proc.permissionMode).toBe("default");
  });
});
