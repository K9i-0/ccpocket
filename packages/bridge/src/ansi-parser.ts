/**
 * ANSI Parser — strips escape codes from PTY output and emits structured
 * ServerMessage objects for phone clients.
 *
 * State machine with states: idle, streaming_text, tool_result.
 *
 * Detects Claude CLI patterns:
 *   ⏺ (U+23FA)  — assistant marker
 *   ⎿ (U+23BF)  — tool results/responses
 *   Allow …?    — permission prompts
 *   Cost: $X.XX — cost summaries
 *   Session: ID — session ID
 */

import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import type { ServerMessage, Provider } from "./parser.js";

// ---- ANSI stripping ----

/** Strip all ANSI escape sequences (SGR, CSI, OSC, etc.) */
function stripAnsi(str: string): string {
  // CSI sequences: ESC [ ... (ending with a letter)
  // OSC sequences: ESC ] ... (ending with BEL or ST)
  // Simple ESC sequences: ESC followed by single char
  return str.replace(
    // eslint-disable-next-line no-control-regex
    /\x1b\[[\x20-\x3f]*[\x40-\x7e]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[^[\]]/g,
    "",
  );
}

// ---- Pattern regexes ----

const MAX_TOOL_RESULT_LINES = 2000;

const ASSISTANT_MARKER = "\u23FA"; // ⏺
const TOOL_HEADER_RE = /^\u23BF\s+([\w:.\-/]+)\((.*)?\)\s*$/;
const PERMISSION_RE = /Allow\?\s*\(/;
const COST_RE = /^Cost:\s*\$([0-9.]+)\s*\u00B7\s*Duration:\s*([0-9.]+)s/;
const SESSION_RE = /^Session:\s*(\S+)/;

type ParserState =
  | "idle"
  | "streaming_text"
  | "tool_result";

export class AnsiParser extends EventEmitter {
  private provider: Provider;
  private state: ParserState = "idle";
  private lineBuffer = "";

  // Accumulated assistant text across lines
  private assistantText = "";
  private currentMessageId = "";

  // Tool call tracking
  private currentToolName = "";
  private currentToolArgs = "";
  private currentToolId = "";
  private toolResultLines: string[] = [];

  // Session
  private sessionId: string | undefined;

  constructor(provider: Provider) {
    super();
    this.provider = provider;
  }

  /** Feed raw PTY output chunk. May contain partial lines. */
  feed(chunk: string): void {
    this.lineBuffer += chunk;

    // Process complete lines (delimited by \r\n or \n)
    let idx: number;
    while ((idx = this.lineBuffer.indexOf("\n")) !== -1) {
      // Include everything up to \n; strip trailing \r
      let line = this.lineBuffer.slice(0, idx);
      if (line.endsWith("\r")) {
        line = line.slice(0, -1);
      }
      this.lineBuffer = this.lineBuffer.slice(idx + 1);

      if (this.provider === "codex") {
        // Codex CLI has a Rust-based TUI with different output formatting.
        // Until Codex-specific patterns are captured and validated, emit all
        // non-empty lines as generic assistant text (graceful degradation).
        this.processCodexLine(line);
      } else {
        this.processLine(line);
      }
    }

  }

  /** Finalize any pending state. */
  flush(): void {
    // Process any remaining buffer as a line
    if (this.lineBuffer.length > 0) {
      const line = this.lineBuffer.replace(/\r$/, "");
      this.lineBuffer = "";
      if (this.provider === "codex") {
        this.processCodexLine(line);
      } else {
        this.processLine(line);
      }
    }

    this.finalizeCurrentState();
  }

  // ---- Internal ----

  private processLine(rawLine: string): void {
    const line = stripAnsi(rawLine);

    // --- Session ID detection (any state) ---
    const sessionMatch = SESSION_RE.exec(line);
    if (sessionMatch) {
      this.sessionId = sessionMatch[1];
      this.emit("message", {
        type: "system",
        subtype: "init",
        sessionId: this.sessionId,
      } satisfies ServerMessage);
      this.emit("session_id", this.sessionId);
      return;
    }

    // --- Cost/result detection (any state) ---
    const costMatch = COST_RE.exec(line);
    if (costMatch) {
      this.finalizeCurrentState();
      this.emit("message", {
        type: "result",
        subtype: "cost",
        cost: parseFloat(costMatch[1]),
        duration: parseFloat(costMatch[2]),
      } satisfies ServerMessage);
      return;
    }

    // --- Permission detection ---
    // Skip lines with significant indentation (4+ spaces) — real permission
    // prompts appear at the top level, not inside tool output blocks.
    if (PERMISSION_RE.test(line) && !/^ {4}/.test(line)) {
      // Capture tool context before finalization resets it
      const toolName = this.currentToolName || "unknown";
      const toolId = this.currentToolId || randomUUID();

      // Finalize any pending state (assistant text, etc.)
      // Note: we DON'T call finalizeToolResult here — the tool result IS
      // the permission request; the phone will approve/reject it.
      if (this.state === "streaming_text") {
        this.finalizeAssistant();
      }

      this.emit("message", {
        type: "permission_request",
        toolUseId: toolId,
        toolName,
        input: {},
      } satisfies ServerMessage);

      // Reset tool state
      this.currentToolName = "";
      this.currentToolArgs = "";
      this.currentToolId = "";
      this.toolResultLines = [];
      this.state = "idle";
      return;
    }

    // --- Tool header detection: ⎿ ToolName(args) ---
    const toolMatch = TOOL_HEADER_RE.exec(line);
    if (toolMatch) {
      // Finalize any pending assistant text
      this.finalizeCurrentState();

      this.currentToolName = toolMatch[1];
      this.currentToolArgs = toolMatch[2] || "";
      this.currentToolId = randomUUID();
      this.toolResultLines = [];
      this.state = "tool_result";
      return;
    }

    // --- State-specific processing ---
    switch (this.state) {
      case "idle":
        this.processIdleLine(line);
        break;
      case "streaming_text":
        this.processStreamingLine(line);
        break;
      case "tool_result":
        this.processToolResultLine(line);
        break;
    }
  }

  private processIdleLine(line: string): void {
    // Check for assistant marker ⏺
    if (line.startsWith(ASSISTANT_MARKER)) {
      this.state = "streaming_text";
      this.currentMessageId = randomUUID();
      const text = line.slice(ASSISTANT_MARKER.length).trimStart();
      if (text.length > 0) {
        this.assistantText += text + "\n";
        this.emit("message", {
          type: "stream_delta",
          text: text + "\n",
        } satisfies ServerMessage);
      }
      return;
    }

    // Empty lines in idle — skip
    if (line.trim().length === 0) {
      return;
    }

    // Unrecognized non-empty line — emit as generic assistant text
    this.emitGenericText(line);
  }

  private processStreamingLine(line: string): void {
    // New assistant marker starts a new segment
    if (line.startsWith(ASSISTANT_MARKER)) {
      // Finalize previous
      this.finalizeAssistant();

      this.currentMessageId = randomUUID();
      const text = line.slice(ASSISTANT_MARKER.length).trimStart();
      if (text.length > 0) {
        this.assistantText += text + "\n";
        this.emit("message", {
          type: "stream_delta",
          text: text + "\n",
        } satisfies ServerMessage);
      }
      return;
    }

    // Blank line might signal end of assistant block, but could also be
    // between paragraphs. We stay in streaming_text but still add it.
    if (line.trim().length === 0) {
      this.assistantText += "\n";
      return;
    }

    // Continuation line (possibly indented)
    const text = line + "\n";
    this.assistantText += text;
    this.emit("message", {
      type: "stream_delta",
      text,
    } satisfies ServerMessage);
  }

  private processToolResultLine(line: string): void {
    // Stop accumulating once the cap is hit (truncation marker already added)
    if (this.toolResultLines.length >= MAX_TOOL_RESULT_LINES) {
      return;
    }

    // Empty line can signal end of tool result block
    if (line.trim().length === 0) {
      // Don't finalize yet — might be followed by more result or permission
      this.toolResultLines.push("");
      return;
    }

    // Accumulate tool result content
    this.toolResultLines.push(line);

    // Add truncation marker when we hit the limit
    if (this.toolResultLines.length === MAX_TOOL_RESULT_LINES) {
      this.toolResultLines.push("[... output truncated]");
    }
  }

  private finalizeCurrentState(): void {
    switch (this.state) {
      case "streaming_text":
        this.finalizeAssistant();
        break;
      case "tool_result":
        this.finalizeToolResult();
        break;
    }
  }

  private finalizeAssistant(): void {
    if (this.assistantText.trim().length === 0) {
      this.state = "idle";
      return;
    }

    this.emit("message", {
      type: "assistant",
      message: {
        id: this.currentMessageId || randomUUID(),
        role: "assistant",
        content: [{ type: "text", text: this.assistantText.trimEnd() }],
        model: this.provider,
      },
    } satisfies ServerMessage);

    // Reset
    this.assistantText = "";
    this.currentMessageId = "";
    this.state = "idle";
  }

  private finalizeToolResult(): void {
    if (this.state !== "tool_result") return;

    // Emit the tool as assistant tool_use content (so phone sees the tool call)
    const toolUseId = this.currentToolId;
    const toolInput: Record<string, unknown> = {};
    if (this.currentToolArgs) {
      toolInput.args = this.currentToolArgs;
    }

    // Emit assistant message with tool_use
    this.emit("message", {
      type: "assistant",
      message: {
        id: randomUUID(),
        role: "assistant",
        content: [
          {
            type: "tool_use",
            id: toolUseId,
            name: this.currentToolName,
            input: toolInput,
          },
        ],
        model: this.provider,
      },
    } satisfies ServerMessage);

    // Emit tool result with accumulated content
    const content = this.toolResultLines
      .filter((l) => l.length > 0)
      .join("\n")
      .trim();

    this.emit("message", {
      type: "tool_result",
      toolUseId,
      content: content || "(no output)",
      toolName: this.currentToolName,
    } satisfies ServerMessage);

    // Reset tool state
    this.currentToolName = "";
    this.currentToolArgs = "";
    this.currentToolId = "";
    this.toolResultLines = [];
    this.state = "idle";
  }

  /**
   * Codex provider: emit non-empty lines as generic assistant text.
   * Codex's Rust-based TUI uses different formatting than Claude's CLI.
   * This graceful degradation ensures phone clients see all output as text
   * rather than garbled partial pattern matches.
   */
  private processCodexLine(rawLine: string): void {
    const line = stripAnsi(rawLine);
    if (line.trim().length === 0) return;

    // Still detect session ID if Codex prints one
    const sessionMatch = SESSION_RE.exec(line);
    if (sessionMatch) {
      this.sessionId = sessionMatch[1];
      this.emit("session_id", this.sessionId);
      return;
    }

    this.emitGenericText(line);
  }

  private emitGenericText(line: string): void {
    this.emit("message", {
      type: "assistant",
      message: {
        id: randomUUID(),
        role: "assistant",
        content: [{ type: "text", text: line }],
        model: this.provider,
      },
    } satisfies ServerMessage);
  }
}
