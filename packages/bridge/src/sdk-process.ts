import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { EventEmitter } from "node:events";
import {
  query,
  type Query,
  type SDKMessage,
  type PermissionResult,
  type ModelInfo,
} from "@anthropic-ai/claude-agent-sdk";
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

export function buildThinkingOptions(
  model: string | undefined,
): { thinking?: { type: "adaptive" } } {
  if (
    typeof model === "string"
    && /^claude-opus-4-7(?:\[1m\])?$/.test(model.trim())
  ) {
    // Opus 4.7 rejects the legacy "thinking.type.enabled" behavior that older
    // Claude Agent SDK releases can fall back to. Force adaptive thinking.
    return { thinking: { type: "adaptive" } };
  }
  return {};
}

export type ClaudeEffortLevel = "low" | "medium" | "high" | "xhigh" | "max";

export interface ClaudeModelMetadata {
  model: string;
  displayName?: string;
  effortLevels: ClaudeEffortLevel[];
}

const CLAUDE_EFFORT_LEVELS = new Set<ClaudeEffortLevel>([
  "low",
  "medium",
  "high",
  "xhigh",
  "max",
]);

function normalizeClaudeModelMetadata(model: ModelInfo): ClaudeModelMetadata | null {
  if (!model.value) return null;
  const effortLevels = Array.isArray(model.supportedEffortLevels)
    ? model.supportedEffortLevels.filter((level): level is ClaudeEffortLevel =>
        CLAUDE_EFFORT_LEVELS.has(level as ClaudeEffortLevel),
      )
    : [];
  return {
    model: model.value,
    ...(model.displayName ? { displayName: model.displayName } : {}),
    effortLevels: model.supportsEffort === false ? [] : effortLevels,
  };
}

async function* createIdleUserMessageStream(): AsyncGenerator<SDKUserMsg> {
  await new Promise<never>(() => {});
}

export const CLAUDE_OAUTH_OPT_IN_ERROR_CODE =
  "claude_oauth_opt_in_required";

const CLAUDE_OAUTH_OPT_IN_MESSAGE =
  "⚠ Claude subscription authentication requires explicit opt-in\n\n" +
  "Set ANTHROPIC_API_KEY on the Bridge machine, or review the documented policy risk and restart Bridge with:\n\n" +
  "  BRIDGE_ALLOW_CLAUDE_OAUTH=1\n\n" +
  "https://github.com/K9i-0/ccpocket/blob/main/docs/auth-troubleshooting.md";

export function isClaudeOAuthOptInEnabled(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return env.BRIDGE_ALLOW_CLAUDE_OAUTH === "1";
}

export function hasExplicitClaudeCredential(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return Boolean(env.ANTHROPIC_API_KEY || env.ANTHROPIC_AUTH_TOKEN);
}

function canStartClaudeSdk(env: NodeJS.ProcessEnv = process.env): boolean {
  return hasExplicitClaudeCredential(env) || isClaudeOAuthOptInEnabled(env);
}

export async function listAvailableClaudeModels(
  projectPath?: string,
): Promise<ClaudeModelMetadata[]> {
  if (!canStartClaudeSdk()) {
    throw new Error(CLAUDE_OAUTH_OPT_IN_MESSAGE);
  }

  const queryInstance = query({
    prompt: createIdleUserMessageStream(),
    options: {
      cwd: projectPath ?? process.cwd(),
      permissionMode: "default",
      settingSources: ["user", "project", "local"],
      stderr: (data: string) => {
        const trimmed = data.trim();
        if (trimmed) {
          console.error(`[sdk-process:models:stderr] ${trimmed}`);
        }
      },
    },
  });
  const drain = (async () => {
    try {
      for await (const _message of queryInstance) {
        // Drain initialization/status messages so control requests can resolve.
      }
    } catch {
      // Closing the standalone query can reject the iterator; model loading is
      // best-effort and the supportedModels() result/error is handled below.
    }
  })();

  try {
    const initialization = await queryInstance.initializationResult();
    if (
      initialization.account.apiKeySource === "oauth" &&
      !isClaudeOAuthOptInEnabled()
    ) {
      throw new Error(CLAUDE_OAUTH_OPT_IN_MESSAGE);
    }
    return initialization.models
      .map(normalizeClaudeModelMetadata)
      .filter((model): model is ClaudeModelMetadata => model != null);
  } finally {
    queryInstance.close();
    void drain;
  }
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

export function buildAskUserAnswers(
  input: Record<string, unknown>,
  result: string,
): Record<string, string> {
  const extractQuestionTexts = (questions: unknown): string[] =>
    Array.isArray(questions)
      ? questions.flatMap((question) => {
        if (
          !question ||
          typeof question !== "object" ||
          Array.isArray(question)
        ) {
          return [];
        }
        const text = (question as Record<string, unknown>).question;
        return typeof text === "string" && text.trim().length > 0 ? [text] : [];
      })
      : [];
  const rawQuestionTexts = extractQuestionTexts(input.questions);
  const questionTexts = [...new Set(rawQuestionTexts)];

  if (questionTexts.length === 0) {
    console.warn(
      "[sdk-process] answer() could not resolve AskUserQuestion text",
    );
    return {};
  }
  if (questionTexts.length !== rawQuestionTexts.length) {
    console.warn("[sdk-process] AskUserQuestion contains duplicate question text");
  }

  const mapped = new Map<string, string>();
  const existingAnswers = input.answers;
  if (
    existingAnswers &&
    typeof existingAnswers === "object" &&
    !Array.isArray(existingAnswers)
  ) {
    const existingRecord = existingAnswers as Record<string, unknown>;
    for (const questionText of questionTexts) {
      const answer = existingRecord[questionText];
      if (typeof answer === "string") mapped.set(questionText, answer);
    }
  }

  try {
    const parsed = JSON.parse(result) as unknown;
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      const payload = parsed as Record<string, unknown>;
      const answers = payload.answers;
      const payloadQuestionTexts = extractQuestionTexts(payload.questions);
      const questionsMatch =
        payloadQuestionTexts.length === rawQuestionTexts.length &&
        payloadQuestionTexts.every(
          (questionText, index) => questionText === rawQuestionTexts[index],
        );
      if (
        questionsMatch &&
        answers &&
        typeof answers === "object" &&
        !Array.isArray(answers)
      ) {
        const answerRecord = answers as Record<string, unknown>;
        for (const questionText of questionTexts) {
          const answer = answerRecord[questionText];
          if (typeof answer === "string") {
            mapped.set(questionText, answer);
          } else if (
            Array.isArray(answer) &&
            answer.every((value) => typeof value === "string")
          ) {
            mapped.set(questionText, answer.join(", "));
          } else if (answer !== undefined) {
            console.warn(
              `[sdk-process] Ignoring invalid answer for question: ${questionText}`,
            );
          }
        }
        return Object.fromEntries(mapped);
      }
    }
  } catch {
    // A normal single-question answer is not JSON.
  }

  if (rawQuestionTexts.length === 1) {
    mapped.set(questionTexts[0], result);
  } else {
    console.warn(
      "[sdk-process] Ignoring non-envelope answer for multiple questions",
    );
  }
  return Object.fromEntries(mapped);
}

export function resolvePermissionMode(
  current: PermissionMode | undefined,
  requested: PermissionMode | undefined,
): PermissionMode | undefined {
  return requested ?? current;
}

export interface StartOptions {
  sessionId?: string;
  continueMode?: boolean;
  permissionMode?: PermissionMode;
  model?: string;
  effort?: ClaudeEffortLevel;
  maxTurns?: number;
  maxBudgetUsd?: number;
  fallbackModel?: string;
  forkSession?: boolean;
  persistSession?: boolean;
  /** When resuming, only resume messages up to this UUID (for conversation rewind). */
  resumeSessionAt?: string;
  /** Text to send as the first user message immediately after session starts. */
  initialInput?: string;
  /** Enable OS-level sandbox for Claude Code. Details configured via .claude/settings.json. */
  sandboxEnabled?: boolean;
  /** Generate a session name after the first completed turn. Bridge-only. */
  autoRename?: boolean;
}

export interface RewindFilesResult {
  canRewind: boolean;
  error?: string;
  filesChanged?: string[];
  insertions?: number;
  deletions?: number;
}

const CLAUDE_ASSISTANT_ERROR_MESSAGES: Record<string, string> = {
  authentication_failed: "Claude authentication failed. Sign in again on the Bridge machine.",
  oauth_org_not_allowed: "This Claude subscription organization cannot be used by the Agent SDK.",
  billing_error: "Claude could not continue because of an account billing error.",
  rate_limit: "Claude is temporarily rate limited. Try again shortly.",
  invalid_request: "Claude rejected this request as invalid.",
  model_not_found: "The selected Claude model is not available for this account.",
  server_error: "Claude encountered a server error.",
  unknown: "Claude stopped because of an unknown request error.",
  max_output_tokens: "Claude reached the maximum response length before finishing.",
};

function claudeAssistantErrorMessage(error: string): ServerMessage {
  return {
    type: "error",
    message:
      CLAUDE_ASSISTANT_ERROR_MESSAGES[error] ??
      `Claude stopped: ${error.replaceAll("_", " ")}.`,
    errorCode:
      error === "authentication_failed"
        ? "auth_token_expired"
        : `claude_${error}`,
  };
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
      if (sys.subtype === "compact_boundary") {
        return { type: "status", status: "compacting" as ProcessStatus };
      }
      if (sys.subtype === "status" && sys.compact_result === "failed") {
        return {
          type: "error",
          message:
            typeof sys.compact_error === "string" && sys.compact_error
              ? `Claude context compaction failed: ${sys.compact_error}`
              : "Claude context compaction failed.",
          errorCode: "claude_compaction_failed",
        };
      }
      return null;
    }

    case "assistant": {
      const ast = msg as unknown as { message: Record<string, unknown>; uuid?: string };
      const rawContent = ast.message.content;
      const content = Array.isArray(rawContent)
        ? rawContent.filter((item) => {
            const block = item as Record<string, unknown>;
            return block.type !== "thinking" ||
              (typeof block.thinking === "string" && block.thinking.trim().length > 0);
          })
        : rawContent;
      if (Array.isArray(content) && content.length === 0) return null;
      return {
        type: "assistant",
        message: {
          ...ast.message,
          content,
        } as ServerMessage extends { type: "assistant" } ? ServerMessage["message"] : never,
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
      // Claude Code can misclassify a routine interrupt as
      // error_during_execution and prepend an internal-only EDE diagnostic.
      // Its own terminal renderer filters these records, so keep the same
      // boundary here while preserving any accompanying real error.
      const rawErrors = Array.isArray(res.errors)
        ? (res.errors as unknown[]).filter(
            (error): error is string => typeof error === "string",
          )
        : [];
      const visibleErrors = rawErrors.filter(
        (error) => !error.startsWith("[ede_diagnostic]"),
      );
      if (rawErrors.length > 0 && visibleErrors.length === 0) {
        return null;
      }
      // All other result subtypes are errors
      const errorText =
        visibleErrors.length > 0 ? visibleErrors.join("\n") : "Unknown error";
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
      const stream = msg as unknown as { event: Record<string, unknown> };
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

// PermissionResult is imported from @anthropic-ai/claude-agent-sdk

type ImageMediaType = "image/png" | "image/jpeg" | "image/gif" | "image/webp";

/** Image content block for SDK message */
interface ImageBlock {
  type: "image";
  source: {
    type: "base64";
    media_type: ImageMediaType;
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
  private permissionModeGeneration = 0;
  private permissionModeUpdates: Promise<void> = Promise.resolve();
  get permissionMode(): PermissionMode | undefined { return this._permissionMode; }
  private _model: string | undefined;
  get model(): string | undefined { return this._model; }
  private usesSubscriptionAuth = false;
  private sessionAllowRules = new Set<string>();

  private initTimeoutId: ReturnType<typeof setTimeout> | null = null;
  private sessionEndEmitted = false;

  // User message channel
  private userMessageResolve: ((msg: SDKUserMsg) => void) | null = null;
  private stopped = false;

  private pendingInputQueue: Array<{ text: string; images?: Array<{ base64: string; mimeType: string }> }> = [];
  private _projectPath: string | null = null;
  private toolCallsSinceLastResult = 0;
  private fileEditsSinceLastResult = 0;
  private launchStartedAt = 0;

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
      try {
        mkdirSync(projectPath, { recursive: true });
      } catch (err) {
        throw new Error(`Cannot create project directory: ${projectPath} (${(err as NodeJS.ErrnoException).code ?? err})`);
      }
    }

    this.stopped = false;
    this._sessionId = null;
    this.usesSubscriptionAuth = false;
    this.sessionEndEmitted = false;
    this.pendingPermissions.clear();
    this.permissionModeGeneration += 1;
    this.permissionModeUpdates = Promise.resolve();
    this._permissionMode = resolvePermissionMode(
      this._permissionMode,
      options?.permissionMode,
    );
    // Keep the requested model visible before the SDK's init event. This is
    // also the value the Bridge persists if it restarts while Claude is idle.
    this._model = options?.model;
    this.sessionAllowRules.clear();
    this.toolCallsSinceLastResult = 0;
    this.fileEditsSinceLastResult = 0;
    this.launchStartedAt = Date.now();
    if (options?.initialInput) {
      this.pendingInputQueue.push({ text: options.initialInput });
    }

    this.setStatus("starting");

    if (!canStartClaudeSdk()) {
      // Defer the failure until SessionManager has registered the process and
      // its listeners. This keeps the structured error visible to clients.
      queueMicrotask(() => {
        if (this.stopped) return;
        this.emitMessage({
          type: "error",
          message: CLAUDE_OAUTH_OPT_IN_MESSAGE,
          errorCode: CLAUDE_OAUTH_OPT_IN_ERROR_CODE,
        });
        this.stop();
        this.emit("exit", 1);
      });
      return;
    }

    // Delegate credential loading and refresh to the official Agent SDK.
    try {
      this.startSdkQuery(projectPath, options);
    } catch (err) {
      console.error("[sdk-process] SDK query start error:", err);
      this.stop();
      throw err;
    }
  }

  private startSdkQuery(projectPath: string, options?: StartOptions): void {
    console.log(`[sdk-process] Starting SDK query (cwd: ${projectPath}, mode: ${this._permissionMode ?? "default"}${options?.sessionId ? `, resume: ${options.sessionId}` : ""}${options?.continueMode ? ", continue: true" : ""})`);

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
        permissionMode: this._permissionMode ?? "default",
        ...(options?.model ? { model: options.model } : {}),
        ...buildThinkingOptions(options?.model),
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
        ...(options?.sandboxEnabled === true
          ? { sandbox: { enabled: true } }
          : options?.sandboxEnabled === false
            ? { sandbox: { enabled: false } }
            : {}),
        stderr: (data: string) => {
          // Capture CLI stderr for resume failure diagnostics
          const trimmed = data.trim();
          if (trimmed) {
            console.error(`[sdk-process:stderr] ${trimmed}`);
          }
        },
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
      this.stop();
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
    this.pendingInputQueue = [];
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
      // NOTE: Do NOT clear pendingInputQueue here — queued messages should
      // survive an interrupt so they are delivered on the next turn.
      this.queryInstance.interrupt().catch((err) => {
        console.error("[sdk-process] Interrupt error:", err);
      });
      this.pendingPermissions.clear();
    }
  }

  /**
   * Returns true when the SDK async generator is blocked waiting for the
   * next user message (i.e. the agent is idle between turns).
   * When false, the agent is mid-turn and input will be queued.
   */
  get hasInputQueue(): boolean {
    return this.pendingInputQueue.length > 0;
  }

  private buildUserMessage(
    text: string,
    images?: Array<{ base64: string; mimeType: string }>,
  ): SDKUserMsg {
    const content: SDKUserMsg["message"]["content"] = [];
    for (const image of images ?? []) {
      content.push({
        type: "image",
        source: {
          type: "base64",
          media_type: image.mimeType as ImageMediaType,
          data: image.base64,
        },
      });
    }
    content.push({ type: "text", text });
    return {
      type: "user",
      session_id: this._sessionId ?? "",
      message: { role: "user", content },
      parent_tool_use_id: null,
    };
  }

  private deliverQueuedInputIfWaiting(): void {
    const resolve = this.userMessageResolve;
    const queued = this.pendingInputQueue.shift();
    if (!resolve || !queued) {
      if (queued) this.pendingInputQueue.unshift(queued);
      return;
    }
    this.userMessageResolve = null;
    console.log(
      `[sdk-process] Delivering queued input after turn completion (remaining: ${this.pendingInputQueue.length})`,
    );
    resolve(this.buildUserMessage(queued.text, queued.images));
  }

  dispatchInput(text: string): { queued: boolean; shouldInterrupt: boolean } {
    const shouldInterrupt =
      this._status === "running" || this._status === "compacting";
    const mustQueue = shouldInterrupt || this._status === "waiting_approval";
    if (mustQueue || !this.userMessageResolve) {
      // Queue the message. The async generator (createUserMessageStream)
      // drains pendingInputQueue on each iteration, so it will be
      // delivered once the SDK is ready for the next turn.
      this.pendingInputQueue.push({ text });
      console.log(`[sdk-process] Queued input (queue depth: ${this.pendingInputQueue.length})`);
      return { queued: true, shouldInterrupt };
    }
    const resolve = this.userMessageResolve;
    this.userMessageResolve = null;
    resolve(this.buildUserMessage(text));
    return { queued: false, shouldInterrupt: false };
  }

  sendInput(text: string): boolean {
    return this.dispatchInput(text).queued;
  }

  /**
   * Send a message with one or more image attachments.
   * @param text - The text message
   * @param images - Array of base64-encoded image data with mime types
   */
  dispatchInputWithImages(
    text: string,
    images: Array<{ base64: string; mimeType: string }>,
  ): { queued: boolean; shouldInterrupt: boolean } {
    const shouldInterrupt =
      this._status === "running" || this._status === "compacting";
    const mustQueue = shouldInterrupt || this._status === "waiting_approval";
    if (mustQueue || !this.userMessageResolve) {
      this.pendingInputQueue.push({ text, images });
      console.log(`[sdk-process] Queued input with ${images.length} image(s) (queue depth: ${this.pendingInputQueue.length})`);
      return { queued: true, shouldInterrupt };
    }
    const resolve = this.userMessageResolve;
    this.userMessageResolve = null;

    const totalKB = images.reduce((sum, img) => sum + Math.round(img.base64.length / 1024), 0);
    console.log(`[sdk-process] Sending message with ${images.length} image(s) (${totalKB}KB base64 total)`);
    resolve(this.buildUserMessage(text, images));
    return { queued: false, shouldInterrupt: false };
  }

  sendInputWithImages(
    text: string,
    images: Array<{ base64: string; mimeType: string }>,
  ): boolean {
    return this.dispatchInputWithImages(text, images).queued;
  }

  /**
   * Approve a pending permission request.
   * With the SDK, this actually blocks tool execution until approved.
   */
  approve(
    toolUseId?: string,
    updatedInput?: Record<string, unknown>,
  ): boolean {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending) {
      console.log("[sdk-process] approve() called but no pending permission requests");
      return false;
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
    return true;
  }

  /**
   * Approve a pending permission request and add a session-scoped allow rule.
   */
  approveAlways(toolUseId?: string): boolean {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending) {
      console.log("[sdk-process] approveAlways() called but no pending permission requests");
      return false;
    }

    const rule = buildSessionRule(pending.toolName, pending.input);
    this.sessionAllowRules.add(rule);
    console.log(`[sdk-process] Added session allow rule: ${rule}`);

    // When a file-edit tool is always-approved, the effective mode is
    // "acceptEdits" — mirror the CLI behaviour by notifying clients.
    if (isFileEditToolName(pending.toolName) && this._permissionMode !== "acceptEdits") {
      console.log(`[sdk-process] Permission mode changed: ${this._permissionMode} → acceptEdits (file-edit always-approved)`);
      this._permissionMode = "acceptEdits";
      this.emitMessage({
        type: "system",
        subtype: "set_permission_mode",
        permissionMode: "acceptEdits",
        sessionId: this._sessionId ?? undefined,
      });
    }

    this.pendingPermissions.delete(id!);
    pending.resolve({
      behavior: "allow",
      updatedInput: pending.input,
      updatedPermissions: [{
        type: "addRules",
        rules: [{ toolName: pending.toolName }],
        behavior: "allow",
        destination: "session",
      }],
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
    return true;
  }

  /**
   * Reject a pending permission request.
   * The SDK's canUseTool will return deny, which tells Claude the tool was rejected.
   */
  reject(toolUseId?: string, message?: string): boolean {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (!pending) {
      console.log("[sdk-process] reject() called but no pending permission requests");
      return false;
    }

    this.pendingPermissions.delete(id!);
    pending.resolve({
      behavior: "deny",
      message: message ?? "User rejected this action",
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
    return true;
  }

  /**
   * Answer an AskUserQuestion tool call.
   * The SDK handles this through canUseTool with updatedInput.
   */
  answer(toolUseId: string, result: string): boolean {
    const pending = this.pendingPermissions.get(toolUseId);
    if (!pending || pending.toolName !== "AskUserQuestion") {
      console.log("[sdk-process] answer() called but no pending AskUserQuestion");
      return false;
    }

    this.pendingPermissions.delete(toolUseId);
    const answers = buildAskUserAnswers(pending.input, result);
    pending.resolve({
      behavior: "allow",
      updatedInput: {
        ...pending.input,
        answers,
      },
    });

    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
    return true;
  }

  /**
   * Update permission mode for the current session.
   * Idle changes are retained and applied when the next query starts.
   */
  async setPermissionMode(mode: PermissionMode): Promise<void> {
    const generation = this.permissionModeGeneration;
    const update = this.permissionModeUpdates.then(async () => {
      if (generation !== this.permissionModeGeneration) return;

      const queryInstance = this.queryInstance;
      if (queryInstance) {
        await queryInstance.setPermissionMode(mode);
        if (
          generation !== this.permissionModeGeneration ||
          queryInstance !== this.queryInstance
        ) {
          return;
        }
      }
      this._permissionMode = mode;
      this.emitMessage({
        type: "system",
        subtype: "set_permission_mode",
        permissionMode: mode,
        sessionId: this._sessionId ?? undefined,
      });
    });
    this.permissionModeUpdates = update.catch(() => {});
    return update;
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

  async listAvailableModels(): Promise<ClaudeModelMetadata[]> {
    if (!this.queryInstance) return [];
    const models = await this.queryInstance.supportedModels();
    return models
      .map(normalizeClaudeModelMetadata)
      .filter((model): model is ClaudeModelMetadata => model != null);
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
        // Build skill metadata from description field returned by the SDK.
        // This provides human-readable descriptions for custom skills
        // that are not in the client's hardcoded knownCommands map.
        const skillMetadata = result
          .filter((cmd) => cmd.description && cmd.description !== cmd.name)
          .map((cmd) => ({
            name: cmd.name,
            path: "",
            description: cmd.description,
            shortDescription: cmd.description,
            enabled: true,
            scope: "project" as const,
          }));
        const skills = skillMetadata.map((m) => m.name);
        const elapsedMs = Date.now() - this.launchStartedAt;
        console.log(
          `[sdk-process] supportedCommands() returned ${slashCommands.length} commands (${skills.length} with descriptions, ${elapsedMs}ms since start)`,
        );
        this.emitMessage({
          type: "system",
          subtype: "supported_commands",
          slashCommands,
          ...(skills.length > 0 ? { skills, skillMetadata } : {}),
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
      // Drain queued messages first (FIFO order)
      if (this.pendingInputQueue.length > 0) {
        const { text, images } = this.pendingInputQueue.shift()!;
        console.log(`[sdk-process] Sending queued input${images ? ` with ${images.length} image(s)` : ""} (remaining: ${this.pendingInputQueue.length})`);
        yield this.buildUserMessage(text, images);
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

      if (
        message.type === "system" &&
        "subtype" in message &&
        (message as Record<string, unknown>).subtype === "init" &&
        (message as Record<string, unknown>).apiKeySource === "oauth" &&
        !isClaudeOAuthOptInEnabled()
      ) {
        console.log("[sdk-process] OAuth auth source requires explicit opt-in");
        this.emitMessage({
          type: "error",
          message: CLAUDE_OAUTH_OPT_IN_MESSAGE,
          errorCode: CLAUDE_OAUTH_OPT_IN_ERROR_CODE,
        });
        this.stop();
        this.emit("exit", 1);
        return;
      }

      // Convert SDK message to ServerMessage
      let serverMsg = sdkMessageToServerMessage(message);
      if (serverMsg?.type === "result") {
        if (this.usesSubscriptionAuth) {
          const { cost: _estimatedApiCost, ...withoutCost } = serverMsg;
          serverMsg = withoutCost as ServerMessage;
        }
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
      if (message.type === "assistant") {
        const assistantError = (message as Record<string, unknown>).error;
        if (typeof assistantError === "string" && assistantError) {
          this.emitMessage(claudeAssistantErrorMessage(assistantError));
        }
      }

      // Extract session ID and model from system/init
      if (message.type === "system" && "subtype" in message && (message as Record<string, unknown>).subtype === "init") {
        if (this.initTimeoutId) {
          clearTimeout(this.initTimeoutId);
          this.initTimeoutId = null;
        }
        this._sessionId = message.session_id;
        this.usesSubscriptionAuth =
          (message as Record<string, unknown>).apiKeySource === "oauth";
        const initModel = (message as Record<string, unknown>).model;
        if (typeof initModel === "string" && initModel) {
          this._model = initModel;
        }
        this.setStatus("idle");
      }

      // Detect permission mode changes from SDK status messages (SSOT).
      // When the CLI internally transitions (e.g. "Always allow" edits →
      // default → acceptEdits), the SDK emits a status message with the new
      // permissionMode.  Propagate the change to connected clients.
      if (message.type === "system" && "subtype" in message) {
        const sys = message as Record<string, unknown>;
        if (sys.subtype === "status" && typeof sys.permissionMode === "string") {
          const newMode = sys.permissionMode as PermissionMode;
          if (newMode !== this._permissionMode) {
            console.log(`[sdk-process] Permission mode changed: ${this._permissionMode} → ${newMode}`);
            this._permissionMode = newMode;
            this.emitMessage({
              type: "system",
              subtype: "set_permission_mode",
              permissionMode: newMode,
              sessionId: this._sessionId ?? undefined,
            });
          }
        }
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
      case "system": {
        const sys = msg as Record<string, unknown>;
        if (sys.subtype === "status") {
          if (sys.status === "compacting") {
            this.setStatus("compacting");
          } else if (sys.status === "requesting") {
            this.setStatus("running");
          } else if (sys.status === null && this._status === "compacting") {
            this.setStatus("running");
          }
        }
        break;
      }
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
        this.deliverQueuedInputIfWaiting();
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
