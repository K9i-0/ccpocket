import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync } from "node:fs";
import { EventEmitter } from "node:events";
import { query, type Query, type SDKMessage } from "@anthropic-ai/claude-agent-sdk";
import {
  normalizeToolResultContent,
  type ServerMessage,
  type ProcessStatus,
  type PermissionMode,
} from "./parser.js";

// Tools that are auto-approved in acceptEdits mode
export const ACCEPT_EDITS_AUTO_APPROVE = new Set([
  "Read", "Glob", "Grep",
  "Edit", "Write", "NotebookEdit",
  "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
  "EnterPlanMode", "AskUserQuestion",
  "WebSearch", "WebFetch",
  "Task", "Skill",
]);

const FILE_EDIT_TOOLS = new Set([
  "Edit",
  "Write",
  "MultiEdit",
  "NotebookEdit",
]);

function toFiniteNumber(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return value;
}

export function isFileEditToolName(toolName: string): boolean {
  return FILE_EDIT_TOOLS.has(toolName);
}

export function extractTokenUsage(
  usage: unknown,
): {
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
} {
  if (!usage || typeof usage !== "object" || Array.isArray(usage)) {
    return {};
  }
  const obj = usage as Record<string, unknown>;

  const inputTokens = toFiniteNumber(obj.input_tokens)
    ?? toFiniteNumber(obj.inputTokens);
  const outputTokens = toFiniteNumber(obj.output_tokens)
    ?? toFiniteNumber(obj.outputTokens);
  const cachedReadTokens = toFiniteNumber(obj.cached_input_tokens)
    ?? toFiniteNumber(obj.cache_read_input_tokens)
    ?? toFiniteNumber(obj.cachedInputTokens)
    ?? toFiniteNumber(obj.cacheReadInputTokens);

  return {
    ...(inputTokens != null ? { inputTokens } : {}),
    ...(cachedReadTokens != null ? { cachedInputTokens: cachedReadTokens } : {}),
    ...(outputTokens != null ? { outputTokens } : {}),
  };
}

/**
 * Parse a permission rule in ToolName(ruleContent) format.
 * Matches the CLI's internal pzT() function: /^([^(]+)\(([^)]+)\)$/
 */
export function parseRule(rule: string): { toolName: string; ruleContent?: string } {
  const match = rule.match(/^([^(]+)\(([^)]+)\)$/);
  if (!match || !match[1] || !match[2]) return { toolName: rule };
  return { toolName: match[1], ruleContent: match[2] };
}

/**
 * Check if a tool invocation matches any session allow rule.
 */
export function matchesSessionRule(
  toolName: string,
  input: Record<string, unknown>,
  rules: Set<string>,
): boolean {
  for (const rule of rules) {
    const parsed = parseRule(rule);
    if (parsed.toolName !== toolName) continue;

    // No ruleContent -> matches any invocation of this tool
    if (!parsed.ruleContent) return true;

    // Bash: prefix matching with ":*" suffix
    if (toolName === "Bash" && typeof input.command === "string") {
      if (parsed.ruleContent.endsWith(":*")) {
        const prefix = parsed.ruleContent.slice(0, -2);
        const firstWord = (input.command as string).trim().split(/\s+/)[0] ?? "";
        if (firstWord === prefix) return true;
      } else {
        if (input.command === parsed.ruleContent) return true;
      }
    }
  }
  return false;
}

/**
 * Build a session allow rule string from a tool name and input.
 * Bash: uses first word as prefix (e.g., "Bash(npm:*)")
 * Others: tool name only (e.g., "Edit")
 */
export function buildSessionRule(toolName: string, input: Record<string, unknown>): string {
  if (toolName === "Bash" && typeof input.command === "string") {
    const firstWord = (input.command as string).trim().split(/\s+/)[0] ?? "";
    if (firstWord) return `${toolName}(${firstWord}:*)`;
  }
  return toolName;
}

export interface StartOptions {
  sessionId?: string;
  continueMode?: boolean;
  permissionMode?: PermissionMode;
  model?: string;
  effort?: "low" | "medium" | "high" | "max";
  maxTurns?: number;
  maxBudgetUsd?: number;
  fallbackModel?: string;
  forkSession?: boolean;
  persistSession?: boolean;
  /** When resuming, only resume messages up to this UUID (for conversation rewind). */
  resumeSessionAt?: string;
  /** Text to send as the first user message immediately after session starts. */
  initialInput?: string;
}

export interface RewindFilesResult {
  canRewind: boolean;
  error?: string;
  filesChanged?: string[];
  insertions?: number;
  deletions?: number;
}

/**
 * Convert SDK messages to the ServerMessage format used by the WebSocket protocol.
 * Exported for testing.
 */
export function sdkMessageToServerMessage(msg: SDKMessage): ServerMessage | null {
  switch (msg.type) {
    case "system": {
      const sys = msg as Record<string, unknown>;
      if (sys.subtype === "init") {
        return {
          type: "system",
          subtype: "init",
          sessionId: msg.session_id,
          model: sys.model as string,
          ...(sys.slash_commands ? { slashCommands: sys.slash_commands as string[] } : {}),
          ...(sys.skills ? { skills: sys.skills as string[] } : {}),
        };
      }
      return null;
    }

    case "assistant": {
      const ast = msg as { message: Record<string, unknown>; uuid?: string };
      return {
        type: "assistant",
        message: ast.message as ServerMessage extends { type: "assistant" } ? ServerMessage["message"] : never,
        ...(ast.uuid ? { messageUuid: ast.uuid } : {}),
      } as ServerMessage;
    }

    case "user": {
      const usr = msg as { message: { content?: unknown[] }; uuid?: string; isSynthetic?: boolean; isMeta?: boolean };

      // Filter out meta messages early (e.g., skill loading prompts).
      // Following Happy Coder's approach: isMeta messages are not user-facing.
      if (usr.isMeta) return null;

      const content = usr.message?.content;
      if (!Array.isArray(content)) return null;

      const results = content.filter(
        (c: unknown) => (c as Record<string, unknown>).type === "tool_result"
      );

      if (results.length > 0) {
        const first = results[0] as Record<string, unknown>;
        const rawContent = first.content as string | unknown[];
        return {
          type: "tool_result",
          toolUseId: first.tool_use_id as string,
          content: normalizeToolResultContent(rawContent),
          ...(Array.isArray(rawContent) ? { rawContentBlocks: rawContent } : {}),
          ...(usr.uuid ? { userMessageUuid: usr.uuid } : {}),
        };
      }

      // User text input (first prompt of each turn)
      const texts = content
        .filter((c: unknown) => (c as Record<string, unknown>).type === "text")
        .map((c: unknown) => (c as Record<string, unknown>).text as string);
      if (texts.length > 0) {
        return {
          type: "user_input",
          text: texts.join("\n"),
          ...(usr.uuid ? { userMessageUuid: usr.uuid } : {}),
          ...(usr.isSynthetic ? { isSynthetic: true } : {}),
          ...(usr.isMeta ? { isMeta: true } : {}),
        } as ServerMessage;
      }

      return null;
    }

    case "result": {
      const res = msg as Record<string, unknown>;
      const tokenUsage = extractTokenUsage(res.usage);
      if (res.subtype === "success") {
        return {
          type: "result",
          subtype: "success",
          result: res.result as string,
          cost: res.total_cost_usd as number,
          duration: res.duration_ms as number,
          sessionId: msg.session_id,
          stopReason: res.stop_reason as string | undefined,
          ...tokenUsage,
        };
      }
      // All other result subtypes are errors
      const errorText = Array.isArray(res.errors) ? (res.errors as string[]).join("\n") : "Unknown error";
      // Suppress spurious CLI runtime errors (SDK bug: Bun API referenced on Node.js)
      if (errorText.includes("Bun is not defined")) {
        return null;
      }
      return {
        type: "result",
        subtype: "error",
        error: errorText,
        sessionId: msg.session_id,
        stopReason: res.stop_reason as string | undefined,
        ...tokenUsage,
      };
    }

    case "stream_event": {
      const stream = msg as { event: Record<string, unknown> };
      const event = stream.event;
      if (event.type === "content_block_delta") {
        const delta = event.delta as Record<string, unknown>;
        if (delta.type === "text_delta" && delta.text) {
          return { type: "stream_delta", text: delta.text as string };
        }
        if (delta.type === "thinking_delta" && delta.thinking) {
          return { type: "thinking_delta", text: delta.thinking as string };
        }
      }
      return null;
    }

    case "tool_use_summary": {
      const summary = msg as {
        summary: string;
        preceding_tool_use_ids: string[];
      };
      return {
        type: "tool_use_summary",
        summary: summary.summary,
        precedingToolUseIds: summary.preceding_tool_use_ids,
      };
    }

    default:
      return null;
  }
}

export interface SdkProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
  /** Fired just before "exit" to allow re-persisting session metadata. */
  session_end: [];
}

interface PendingPermission {
  resolve: (result: PermissionResult) => void;
  toolName: string;
  input: Record<string, unknown>;
}

type PermissionResult =
  | { behavior: "allow"; updatedInput?: Record<string, unknown> }
  | { behavior: "deny"; message: string };

/** Image content block for SDK message */
interface ImageBlock {
  type: "image";
  source: {
    type: "base64";
    media_type: string;
    data: string;
  };
}

/** User message type for SDK's AsyncIterable prompt */
interface SDKUserMsg {
  type: "user";
  session_id: string;
  message: {
    role: "user";
    content: Array<
      | { type: "text"; text: string }
      | { type: "tool_result"; tool_use_id: string; content: string }
      | ImageBlock
    >;
  };
  parent_tool_use_id: null;
}

export class SdkProcess extends EventEmitter<SdkProcessEvents> {
  private queryInstance: Query | null = null;
  private _status: ProcessStatus = "idle";
  private _sessionId: string | null = null;
  private pendingPermissions = new Map<string, PendingPermission>();
  private _permissionMode: PermissionMode | undefined;
  get permissionMode(): PermissionMode | undefined { return this._permissionMode; }
  private sessionAllowRules = new Set<string>();

  private initTimeoutId: ReturnType<typeof setTimeout> | null = null;
  private sessionEndEmitted = false;

  // User message channel
  private userMessageResolve: ((msg: SDKUserMsg) => void) | null = null;
  private stopped = false;

  private pendingInput: { text: string; images?: Array<{ base64: string; mimeType: string }> } | null = null;
  private _projectPath: string | null = null;
  private toolCallsSinceLastResult = 0;
  private fileEditsSinceLastResult = 0;

  get status(): ProcessStatus {
    return this._status;
  }

  get isWaitingForInput(): boolean {
    return this.userMessageResolve !== null;
  }

  get sessionId(): string | null {
    return this._sessionId;
  }

  get isRunning(): boolean {
    return this.queryInstance !== null;
  }

  start(projectPath: string, options?: StartOptions): void {
    if (this.queryInstance) {
      this.stop();
    }

    this._projectPath = projectPath;

    if (!existsSync(projectPath)) {
      mkdirSync(projectPath, { recursive: true });
    }

    this.stopped = false;
    this._sessionId = null;
    this.sessionEndEmitted = false;
    this.pendingPermissions.clear();
    this._permissionMode = options?.permissionMode;
    this.sessionAllowRules.clear();
    this.toolCallsSinceLastResult = 0;
    this.fileEditsSinceLastResult = 0;
    if (options?.initialInput) {
      this.pendingInput = { text: options.initialInput };
    }

    this.setStatus("starting");

    console.log(`[sdk-process] Starting SDK query (cwd: ${projectPath}, mode: ${options?.permissionMode ?? "default"})`);

    // In -p mode with --input-format stream-json, Claude CLI won't emit
    // system/init until the first user input. Set a fallback timeout to
    // transition to "idle" if init hasn't arrived, since the process IS
    // ready to accept input at that point.
    if (this.initTimeoutId) clearTimeout(this.initTimeoutId);
    this.initTimeoutId = setTimeout(() => {
      if (this._status === "starting") {
        console.log("[sdk-process] Init timeout: setting status to idle (process ready for input)");
        this.setStatus("idle");
      }
      this.initTimeoutId = null;
    }, 3000);

    this.queryInstance = query({
      prompt: this.createUserMessageStream(),
      options: {
        cwd: projectPath,
        resume: options?.sessionId,
        continue: options?.continueMode,
        permissionMode: options?.permissionMode ?? "default",
        ...(options?.model ? { model: options.model } : {}),
        ...(options?.effort ? { effort: options.effort } : {}),
        ...(options?.maxTurns != null ? { maxTurns: options.maxTurns } : {}),
        ...(options?.maxBudgetUsd != null ? { maxBudgetUsd: options.maxBudgetUsd } : {}),
        ...(options?.fallbackModel ? { fallbackModel: options.fallbackModel } : {}),
        ...(options?.forkSession != null ? { forkSession: options.forkSession } : {}),
        ...(options?.persistSession != null ? { persistSession: options.persistSession } : {}),
        hooks: {
          PostToolUse: [{
            hooks: [async (input) => {
              this.handlePostToolUseHook(input);
              return { continue: true };
            }],
          }],
        },
        includePartialMessages: true,
        canUseTool: this.handleCanUseTool.bind(this),
        settingSources: ["user", "project", "local"],
        enableFileCheckpointing: true,
        ...(options?.resumeSessionAt ? { resumeSessionAt: options.resumeSessionAt } : {}),
      },
    });

    // Background message processing
    this.processMessages().catch((err) => {
      if (this.stopped) {
        // Suppress errors from intentional stop (SDK bug: Bun API referenced on Node.js)
        return;
      }
      console.error("[sdk-process] Message processing error:", err);
      this.emitMessage({ type: "error", message: `SDK error: ${err instanceof Error ? err.message : String(err)}` });
      this.setStatus("idle");
      this.emit("exit", 1);
    });

    // Proactively fetch supported commands via SDK API (non-blocking)
    this.fetchSupportedCommands();
  }

  stop(): void {
    if (this.initTimeoutId) {
      clearTimeout(this.initTimeoutId);
      this.initTimeoutId = null;
    }
    this.stopped = true;
    this.pendingInput = null;
    if (this.queryInstance) {
      console.log("[sdk-process] Stopping query");
      this.queryInstance.close();
      this.queryInstance = null;
    }
    this.pendingPermissions.clear();
    this.userMessageResolve = null;
    this.toolCallsSinceLastResult = 0;
    this.fileEditsSinceLastResult = 0;

    // Emit session_end so listeners can re-persist metadata before cleanup.
    // processMessages() won't reach its session_end emit because close()
    // causes the iterator to throw and the error is suppressed.
    this.emitSessionEnd();

    this.setStatus("idle");
  }

  interrupt(): void {
    if (this.queryInstance) {
      console.log("[sdk-process] Interrupting query");
      this.pendingInput = null;
      this.queryInstance.interrupt().catch((err) => {
        console.error("[sdk-process] Interrupt error:", err);
      });
      this.pendingPermissions.clear();
    }
  }

  sendInput(text: string): void {
    if (!this.userMessageResolve) {
      // Queue the message instead of dropping it. The async generator
      // (createUserMessageStream) checks pendingInput on each iteration,
      // so the message will be delivered once the SDK is ready.
      // NOTE: This is a single-slot queue — if called multiple times before
      // the resolver is set, only the last message is preserved.
      this.pendingInput = { text };
      console.log("[sdk-process] Queued input (waiting for resolver)");
      return;
    }
    const resolve = this.userMessageResolve;
    this.userMessageResolve = null;
    resolve({
      type: "user",
      session_id: this._sessionId ?? "",
      message: {
        role: "user",
        content: [{ type: "text", text }],
      },
      parent_tool_use_id: null,
    });
  }

  /**
   * Send a message with one or more image attachments.
   * @param text - The text message
   * @param images - Array of base64-encoded image data with mime types
   */
  sendInputWithImages(text: string, images: Array<{ base64: string; mimeType: string }>): void {
    if (!this.userMessageResolve) {
      this.pendingInput = { text, images };
      console.log(`[sdk-process] Queued input with ${images.length} image(s) (waiting for resolver)`);
      return;
    }
    const resolve = this.userMessageResolve;
    this.userMessageResolve = null;

    const content: SDKUserMsg["message"]["content"] = [];

    // Add image blocks first (Claude processes images before text)
    for (const image of images) {
      content.push({
        type: "image",
        source: {
          type: "base64",
          media_type: image.mimeType,
          data: image.base64,
        },
      });
    }

    // Add text block
    content.push({ type: "text", text });

    const totalKB = images.reduce((sum, img) => sum + Math.round(img.base64.length / 1024), 0);
    console.log(`[sdk-process] Sending message with ${images.length} image(s) (${totalKB}KB base64 total)`);

    resolve({
      type: "user",
      session_id: this._sessionId ?? "",
      message: {
        role: "user",
        content,
      },
      parent_tool_use_id: null,
    });
  }

  /**
   * Approve a pending permission request.
   * With the SDK, this actually blocks tool execution until approved.
   */
  approve(toolUseId?: string, updatedInput?: Record<string, unknown>): void {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending) {
      console.log("[sdk-process] approve() called but no pending permission requests");
      return;
    }

    const mergedInput = updatedInput
      ? { ...pending.input, ...updatedInput }
      : pending.input;

    this.pendingPermissions.delete(id!);
    pending.resolve({
      behavior: "allow",
      updatedInput: mergedInput,
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  /**
   * Approve a pending permission request and add a session-scoped allow rule.
   */
  approveAlways(toolUseId?: string): void {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (pending) {
      const rule = buildSessionRule(pending.toolName, pending.input);
      this.sessionAllowRules.add(rule);
      console.log(`[sdk-process] Added session allow rule: ${rule}`);
    }
    this.approve(id);
  }

  /**
   * Reject a pending permission request.
   * The SDK's canUseTool will return deny, which tells Claude the tool was rejected.
   */
  reject(toolUseId?: string, message?: string): void {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending) {
      console.log("[sdk-process] reject() called but no pending permission requests");
      return;
    }

    this.pendingPermissions.delete(id!);
    pending.resolve({
      behavior: "deny",
      message: message ?? "User rejected this action",
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  /**
   * Answer an AskUserQuestion tool call.
   * The SDK handles this through canUseTool with updatedInput.
   */
  answer(toolUseId: string, result: string): void {
    const pending = this.pendingPermissions.get(toolUseId);
    if (!pending || pending.toolName !== "AskUserQuestion") {
      console.log("[sdk-process] answer() called but no pending AskUserQuestion");
      return;
    }

    this.pendingPermissions.delete(toolUseId);
    pending.resolve({
      behavior: "allow",
      updatedInput: {
        ...pending.input,
        answers: { ...(pending.input.answers as Record<string, string> ?? {}), result },
      },
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  /**
   * Update permission mode for the current session.
   * Only available while the query instance is active.
   */
  async setPermissionMode(mode: PermissionMode): Promise<void> {
    if (!this.queryInstance) {
      throw new Error("No active query instance");
    }
    await this.queryInstance.setPermissionMode(mode);
    this._permissionMode = mode;
    this.emitMessage({
      type: "system",
      subtype: "set_permission_mode",
      permissionMode: mode,
      sessionId: this._sessionId ?? undefined,
    });
  }

  /**
   * Rewind files to their state at the specified user message.
   * Requires enableFileCheckpointing to be enabled (done in start()).
   */
  async rewindFiles(userMessageId: string, dryRun?: boolean): Promise<RewindFilesResult> {
    if (!this.queryInstance) {
      return { canRewind: false, error: "No active query instance" };
    }
    try {
      const result = await this.queryInstance.rewindFiles(userMessageId, { dryRun });
      return result as RewindFilesResult;
    } catch (err) {
      return { canRewind: false, error: err instanceof Error ? err.message : String(err) };
    }
  }

  // ---- Private ----

  /**
   * Proactively fetch supported commands from the SDK.
   * This may resolve before the first user input, providing slash commands
   * without waiting for system/init.
   */
  private fetchSupportedCommands(): void {
    if (!this.queryInstance) return;

    const TIMEOUT_MS = 10_000;
    const timeoutPromise = new Promise<null>((resolve) => {
      setTimeout(() => resolve(null), TIMEOUT_MS);
    });

    Promise.race([
      this.queryInstance.supportedCommands(),
      timeoutPromise,
    ])
      .then((result) => {
        if (this.stopped || !result) return;
        const slashCommands = result.map((cmd) => cmd.name);
        console.log(`[sdk-process] supportedCommands() returned ${slashCommands.length} commands`);
        this.emitMessage({
          type: "system",
          subtype: "supported_commands",
          slashCommands,
        });
      })
      .catch((err) => {
        console.log(`[sdk-process] supportedCommands() failed (non-fatal): ${err instanceof Error ? err.message : String(err)}`);
      });
  }

  private firstPendingId(): string | undefined {
    const first = this.pendingPermissions.keys().next();
    return first.done ? undefined : first.value;
  }

  /**
   * Returns a snapshot of a pending permission request.
   * Used by the bridge to support Clear & Accept flows.
   */
  getPendingPermission(
    toolUseId?: string,
  ): { toolUseId: string; toolName: string; input: Record<string, unknown> } | undefined {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending || !id) return undefined;
    return {
      toolUseId: id,
      toolName: pending.toolName,
      input: { ...pending.input },
    };
  }

  private async *createUserMessageStream(): AsyncGenerator<SDKUserMsg> {
    while (!this.stopped) {
      if (this.pendingInput) {
        const { text, images } = this.pendingInput;
        this.pendingInput = null;
        console.log(`[sdk-process] Sending pending input${images ? ` with ${images.length} image(s)` : ""}`);
        const content: SDKUserMsg["message"]["content"] = [];
        if (images) {
          for (const image of images) {
            content.push({
              type: "image",
              source: {
                type: "base64",
                media_type: image.mimeType,
                data: image.base64,
              },
            });
          }
        }
        content.push({ type: "text", text });
        yield {
          type: "user",
          session_id: this._sessionId ?? "",
          message: {
            role: "user",
            content,
          },
          parent_tool_use_id: null,
        };
        continue;
      }
      const msg = await new Promise<SDKUserMsg>((resolve) => {
        this.userMessageResolve = resolve;
      });
      if (this.stopped) break;
      yield msg;
    }
  }

  private async processMessages(): Promise<void> {
    if (!this.queryInstance) return;

    for await (const message of this.queryInstance) {
      if (this.stopped) break;

      // Convert SDK message to ServerMessage
      let serverMsg = sdkMessageToServerMessage(message);
      if (serverMsg?.type === "result") {
        if (this.toolCallsSinceLastResult > 0 || this.fileEditsSinceLastResult > 0) {
          serverMsg = {
            ...serverMsg,
            ...(this.toolCallsSinceLastResult > 0
              ? { toolCalls: this.toolCallsSinceLastResult }
              : {}),
            ...(this.fileEditsSinceLastResult > 0
              ? { fileEdits: this.fileEditsSinceLastResult }
              : {}),
          };
        }
        this.toolCallsSinceLastResult = 0;
        this.fileEditsSinceLastResult = 0;
      }
      if (serverMsg) {
        this.emitMessage(serverMsg);
      }

      // Extract session ID from system/init
      if (message.type === "system" && "subtype" in message && (message as Record<string, unknown>).subtype === "init") {
        if (this.initTimeoutId) {
          clearTimeout(this.initTimeoutId);
          this.initTimeoutId = null;
        }
        this._sessionId = message.session_id;
        this.setStatus("idle");
      }

      // Update status from message type
      this.updateStatusFromMessage(message);
    }

    // Query finished — CLI has completed shutdown including file writes.
    this.queryInstance = null;

    // Emit session_end before exit so listeners can re-persist metadata
    // (e.g. customTitle) that the CLI may have overwritten during shutdown.
    this.emitSessionEnd();

    this.setStatus("idle");
    this.emit("exit", 0);
  }

  /**
   * Core permission handler: called by SDK before each tool execution.
   * Returns a Promise that resolves when the user approves/rejects.
   */
  private async handleCanUseTool(
    toolName: string,
    input: Record<string, unknown>,
    options: {
      signal: AbortSignal;
      suggestions?: unknown[];
      toolUseID: string;
    },
  ): Promise<PermissionResult> {
    // AskUserQuestion: always forward to client for response
    if (toolName === "AskUserQuestion") {
      return this.waitForPermission(options.toolUseID, toolName, input, options.signal);
    }

    // Auto-approve check: session allow rules
    if (matchesSessionRule(toolName, input, this.sessionAllowRules)) {
      return { behavior: "allow", updatedInput: input };
    }

    // SDK handles permissionMode internally, but canUseTool is only called
    // for tools that the SDK thinks need permission. We emit the request
    // to the mobile client and wait.
    return this.waitForPermission(options.toolUseID, toolName, input, options.signal);
  }

  private waitForPermission(
    toolUseId: string,
    toolName: string,
    input: Record<string, unknown>,
    signal: AbortSignal,
  ): Promise<PermissionResult> {
    // Emit permission request to client
    this.emitMessage({
      type: "permission_request",
      toolUseId,
      toolName,
      input,
    });
    this.setStatus("waiting_approval");

    return new Promise<PermissionResult>((resolve) => {
      this.pendingPermissions.set(toolUseId, { resolve, toolName, input });

      // Handle abort (timeout)
      if (signal.aborted) {
        this.pendingPermissions.delete(toolUseId);
        resolve({ behavior: "deny", message: "Permission request aborted" });
        return;
      }

      signal.addEventListener("abort", () => {
        if (this.pendingPermissions.has(toolUseId)) {
          this.pendingPermissions.delete(toolUseId);
          resolve({ behavior: "deny", message: "Permission request timed out" });
        }
      }, { once: true });
    });
  }

  private updateStatusFromMessage(msg: SDKMessage): void {
    switch (msg.type) {
      case "system":
        // Already handled in processMessages for init
        break;
      case "assistant":
        if (this.pendingPermissions.size === 0) {
          this.setStatus("running");
        }
        break;
      case "user":
        if (this.pendingPermissions.size === 0) {
          this.setStatus("running");
        }
        break;
      case "result":
        this.pendingPermissions.clear();
        this.setStatus("idle");
        break;
    }
  }

  private handlePostToolUseHook(input: unknown): void {
    if (!input || typeof input !== "object" || Array.isArray(input)) {
      return;
    }
    const hookInput = input as Record<string, unknown>;
    const toolName = hookInput.tool_name;
    if (typeof toolName !== "string" || toolName.length === 0) {
      return;
    }
    this.toolCallsSinceLastResult += 1;
    if (isFileEditToolName(toolName)) {
      this.fileEditsSinceLastResult += 1;
    }
  }

  private setStatus(status: ProcessStatus): void {
    if (this._status !== status) {
      this._status = status;
      this.emit("status", status);
      this.emitMessage({ type: "status", status });
    }
  }

  /** Emit session_end at most once per session lifecycle. */
  private emitSessionEnd(): void {
    if (this.sessionEndEmitted) return;
    this.sessionEndEmitted = true;
    this.emit("session_end");
  }

  private emitMessage(msg: ServerMessage): void {
    this.emit("message", msg);
  }
}
