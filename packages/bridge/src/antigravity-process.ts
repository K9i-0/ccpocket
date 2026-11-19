import {
  execFile,
  spawn,
  type ChildProcessWithoutNullStreams,
} from "node:child_process";
import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { createInterface } from "node:readline";
import type {
  AssistantContent,
  PermissionMode,
  ProcessStatus,
  ServerMessage,
} from "./parser.js";

/**
 * Antigravity (`agy acp`) provider process.
 *
 * Talks the Agent Client Protocol (JSON-RPC over stdio) to the Antigravity
 * CLI and converts it to Bridge server messages. See
 * docs/antigravity-acp-integration.md for the protocol notes and the
 * authentication rules this file enforces.
 */

export const ANTIGRAVITY_CLI_NOT_FOUND_MESSAGE =
  "Antigravity CLI (agy) was not found. Install it and sign in with `agy`, then start the session again.";
export const ANTIGRAVITY_AUTH_REQUIRED_MESSAGE =
  "Antigravity is not signed in. Run `agy` in a terminal on the Bridge machine to sign in, or set CCPOCKET_ANTIGRAVITY_API_KEY.";

/** `~/.gemini/<name>` profile used when the Bridge authenticates with an API key. */
export const ANTIGRAVITY_API_KEY_PROFILE = "antigravity-cli-ccpocket-apikey";

const ACP_PROTOCOL_VERSION = 1;
const REQUEST_TIMEOUT_MS = 60_000;
/** `session/load` replays the whole conversation before it answers. */
const LOAD_TIMEOUT_MS = 10 * 60_000;

export type AntigravityAuthMode = "login" | "api_key";

export interface AntigravityConfig {
  /** Executable to spawn. */
  bin: string;
  /** Gemini API key. When set the Bridge uses the API-key profile. */
  apiKey?: string;
  /**
   * Refuse to send prompts unless API-key auth is verified. Agents (tests,
   * E2E, subagents) must run with this on: driving `agy` with a consumer
   * Google login from another agent violates Google's terms.
   */
  requireApiKey: boolean;
}

let capturedConfig: AntigravityConfig | undefined;

/**
 * The Bridge's Antigravity configuration, read once. The API key is then
 * removed from `process.env` so no other child process (Codex, Claude, the
 * commands they run) inherits it.
 */
export function getAntigravityConfig(): AntigravityConfig {
  if (!capturedConfig) {
    capturedConfig = resolveAntigravityConfig();
    delete process.env.CCPOCKET_ANTIGRAVITY_API_KEY;
  }
  return capturedConfig;
}

/** Start failure with the error code clients can act on. */
export class AntigravityStartError extends Error {
  constructor(
    message: string,
    readonly errorCode?: string,
  ) {
    super(message);
  }
}

export function resolveAntigravityConfig(
  env: NodeJS.ProcessEnv = process.env,
): AntigravityConfig {
  const apiKey = env.CCPOCKET_ANTIGRAVITY_API_KEY?.trim();
  const flag = env.CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY?.trim().toLowerCase();
  return {
    bin: env.CCPOCKET_ANTIGRAVITY_BIN?.trim() || "agy",
    ...(apiKey ? { apiKey } : {}),
    requireApiKey: flag === "1" || flag === "true",
  };
}

/** True when the configured CLI is installed and speaks ACP. */
export function isAntigravityCliAvailable(
  config: AntigravityConfig = getAntigravityConfig(),
): Promise<boolean> {
  return new Promise((resolve) => {
    execFile(config.bin, ["acp", "--help"], { timeout: 10_000 }, (err) =>
      resolve(!err),
    );
  });
}

export interface AntigravityStartOptions {
  /** Existing ACP session id. Loads it and replays its history. */
  sessionId?: string;
  /** ACP model id, e.g. `gemini-3.8-flash-high`. */
  model?: string;
  permissionMode?: PermissionMode;
}

export interface AntigravityModelInfo {
  id: string;
  name: string;
}

export interface AntigravitySettings {
  model?: string;
  models: AntigravityModelInfo[];
  permissionMode?: PermissionMode;
  permissionModes: PermissionMode[];
  authMode: AntigravityAuthMode;
}

export interface AntigravityProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
  input_ready: [];
  usage_limit: [retryAt?: number];
  /** Title assigned by Antigravity itself (`session_info_update`). */
  title: [string];
}

export interface AcpTransportEvents {
  message: [Record<string, unknown>];
  error: [Error];
  exit: [number | null];
}

/** Line-delimited JSON-RPC channel to an ACP agent. */
export abstract class AcpTransport extends EventEmitter<AcpTransportEvents> {
  abstract start(cwd: string): void;
  abstract write(message: Record<string, unknown>): void;
  abstract stop(): void;
}

export function buildAntigravitySpawnSpec(
  cwd: string,
  config: AntigravityConfig,
  baseEnv: NodeJS.ProcessEnv = process.env,
): { command: string; args: string[]; cwd: string; env: NodeJS.ProcessEnv } {
  const env = { ...baseEnv };
  // The key travels in the `authenticate` request. Keeping it out of the
  // environment stops it from reaching commands the agent runs, and stops a
  // globally exported key from silently switching a login session to
  // pay-as-you-go billing.
  delete env.GEMINI_API_KEY;
  delete env.CCPOCKET_ANTIGRAVITY_API_KEY;
  return {
    command: config.bin,
    args: config.apiKey
      ? ["acp", "--app-data-dir", ANTIGRAVITY_API_KEY_PROFILE]
      : ["acp"],
    cwd,
    env,
  };
}

export class StdioAcpTransport extends AcpTransport {
  private child: ChildProcessWithoutNullStreams | null = null;

  constructor(private readonly config: AntigravityConfig) {
    super();
  }

  start(cwd: string): void {
    const spec = buildAntigravitySpawnSpec(cwd, this.config);
    const child = spawn(spec.command, spec.args, {
      cwd: spec.cwd,
      env: spec.env,
      stdio: "pipe",
    });
    this.child = child;
    child.on("error", (err) => this.emit("error", err));
    child.on("exit", (code) => {
      this.child = null;
      this.emit("exit", code);
    });
    child.stdin.on("error", () => {
      // EPIPE while the child is going away; its exit is reported separately.
    });
    child.stderr.on("data", () => {
      // agy writes its own log file; stderr only repeats it.
    });
    createInterface({ input: child.stdout }).on("line", (line) => {
      if (!line.trim()) return;
      try {
        const parsed: unknown = JSON.parse(line);
        if (parsed && typeof parsed === "object") {
          this.emit("message", parsed as Record<string, unknown>);
        }
      } catch {
        // Non-JSON output is not part of the protocol.
      }
    });
  }

  write(message: Record<string, unknown>): void {
    if (!this.child || this.child.stdin.destroyed) return;
    this.child.stdin.write(`${JSON.stringify(message)}\n`);
  }

  stop(): void {
    const child = this.child;
    if (!child) return;
    child.stdin.end();
    child.kill();
  }
}

interface PendingPermission {
  requestId: number | string;
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
  options: Array<{ optionId: string; kind: string }>;
}

interface ToolCallState {
  toolName: string;
  kind: string;
  title: string;
  /** A permission decision already produced the tool_result for this call. */
  rejected: boolean;
  finished: boolean;
}

interface PromptUsage {
  inputTokens?: number;
  cachedReadTokens?: number;
  outputTokens?: number;
}

class AcpError extends Error {
  constructor(
    message: string,
    readonly code?: number,
  ) {
    super(message);
  }
}

const ACP_MODE_TO_PERMISSION_MODE: Record<string, PermissionMode> = {
  default: "default",
  "accept-edits": "acceptEdits",
  auto: "auto",
  plan: "plan",
};

export function permissionModeFromAcpMode(
  mode: unknown,
): PermissionMode | undefined {
  return typeof mode === "string"
    ? ACP_MODE_TO_PERMISSION_MODE[mode]
    : undefined;
}

export function acpModeFromPermissionMode(
  mode: PermissionMode,
): string | undefined {
  return Object.entries(ACP_MODE_TO_PERMISSION_MODE).find(
    ([, value]) => value === mode,
  )?.[0];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringOr(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

/** Drop the timing header `agy` puts in front of command output. */
export function cleanCommandOutput(raw: string): string {
  const normalized = raw.replace(/\r\n/g, "\n");
  const marker = "Command output:\n";
  const index = normalized.indexOf(marker);
  const body = index >= 0 ? normalized.slice(index + marker.length) : normalized;
  return body.replace(/\n+$/, "");
}

const DIFF_CONTEXT_LINES = 3;
const DIFF_MAX_CELLS = 4_000_000;

/** Minimal unified diff for the `{oldText, newText}` pairs ACP reports. */
export function buildUnifiedDiff(
  path: string,
  oldText: string | null | undefined,
  newText: string,
): string {
  const relative = path.replace(/^\/+/, "");
  const header = `--- ${oldText == null ? "/dev/null" : `a/${relative}`}\n+++ b/${relative}\n`;
  const split = (text: string): string[] => {
    if (text === "") return [];
    const lines = text.split("\n");
    if (lines[lines.length - 1] === "") lines.pop();
    return lines;
  };
  const before = split(oldText ?? "");
  const after = split(newText);
  type Op = { tag: " " | "-" | "+"; line: string };
  const ops: Op[] = [];

  if (before.length * after.length > DIFF_MAX_CELLS) {
    for (const line of before) ops.push({ tag: "-", line });
    for (const line of after) ops.push({ tag: "+", line });
  } else {
    const rows = before.length + 1;
    const cols = after.length + 1;
    const lcs = new Uint32Array(rows * cols);
    for (let i = before.length - 1; i >= 0; i--) {
      for (let j = after.length - 1; j >= 0; j--) {
        lcs[i * cols + j] =
          before[i] === after[j]
            ? lcs[(i + 1) * cols + j + 1] + 1
            : Math.max(lcs[(i + 1) * cols + j], lcs[i * cols + j + 1]);
      }
    }
    let i = 0;
    let j = 0;
    while (i < before.length && j < after.length) {
      if (before[i] === after[j]) {
        ops.push({ tag: " ", line: before[i] });
        i++;
        j++;
      } else if (lcs[(i + 1) * cols + j] >= lcs[i * cols + j + 1]) {
        ops.push({ tag: "-", line: before[i++] });
      } else {
        ops.push({ tag: "+", line: after[j++] });
      }
    }
    while (i < before.length) ops.push({ tag: "-", line: before[i++] });
    while (j < after.length) ops.push({ tag: "+", line: after[j++] });
  }

  const keep = new Array<boolean>(ops.length).fill(false);
  ops.forEach((op, index) => {
    if (op.tag === " ") return;
    const from = Math.max(0, index - DIFF_CONTEXT_LINES);
    const to = Math.min(ops.length - 1, index + DIFF_CONTEXT_LINES);
    for (let k = from; k <= to; k++) keep[k] = true;
  });
  if (!keep.includes(true)) return `${header}@@ -0,0 +0,0 @@`;

  const hunks: string[] = [];
  let oldLine = 1;
  let newLine = 1;
  let index = 0;
  while (index < ops.length) {
    if (!keep[index]) {
      if (ops[index].tag !== "+") oldLine++;
      if (ops[index].tag !== "-") newLine++;
      index++;
      continue;
    }
    const oldStart = oldLine;
    const newStart = newLine;
    let oldCount = 0;
    let newCount = 0;
    const body: string[] = [];
    while (index < ops.length && keep[index]) {
      const op = ops[index++];
      body.push(`${op.tag}${op.line}`);
      if (op.tag !== "+") {
        oldCount++;
        oldLine++;
      }
      if (op.tag !== "-") {
        newCount++;
        newLine++;
      }
    }
    hunks.push(
      `@@ -${oldCount === 0 ? oldStart - 1 : oldStart},${oldCount} +${newCount === 0 ? newStart - 1 : newStart},${newCount} @@\n${body.join("\n")}`,
    );
  }
  return header + hunks.join("\n");
}

interface FileChange {
  path: string;
  kind: "add" | "update";
  diff: string;
}

function fileChangesFromContent(content: unknown, cwd = ""): FileChange[] {
  if (!Array.isArray(content)) return [];
  const prefix = cwd ? `${cwd.replace(/\/+$/, "")}/` : "";
  const changes: FileChange[] = [];
  for (const block of content) {
    if (!isRecord(block) || block.type !== "diff") continue;
    const path = stringOr(block.path);
    if (!path) continue;
    const oldText = typeof block.oldText === "string" ? block.oldText : null;
    changes.push({
      path,
      kind: oldText == null ? "add" : "update",
      diff: buildUnifiedDiff(
        prefix && path.startsWith(prefix) ? path.slice(prefix.length) : path,
        oldText,
        stringOr(block.newText),
      ),
    });
  }
  return changes;
}

function textFromToolContent(content: unknown): string {
  if (!Array.isArray(content)) return "";
  const parts: string[] = [];
  for (const block of content) {
    if (!isRecord(block) || block.type !== "content") continue;
    const inner = block.content;
    if (isRecord(inner) && inner.type === "text" && typeof inner.text === "string") {
      parts.push(inner.text);
    }
  }
  return parts.join("\n");
}

export class AntigravityProcess extends EventEmitter<AntigravityProcessEvents> {
  private transport: AcpTransport | null = null;
  private readonly config: AntigravityConfig;
  private readonly createTransport: (config: AntigravityConfig) => AcpTransport;

  private cwd = "";
  private _status: ProcessStatus = "starting";
  private _sessionId: string | null = null;
  private _model: string | undefined;
  private _models: AntigravityModelInfo[] = [];
  private _permissionMode: PermissionMode | undefined;
  private _permissionModes: PermissionMode[] = [];
  private _slashCommands: string[] = [];
  private stopped = false;
  private exited = false;
  private ready = false;
  /** History replay from `session/load` must not look like a live turn. */
  private replaying = false;
  private replayedUserTurns = 0;

  private resolveReady: (() => void) | null = null;
  private rejectReady: ((err: Error) => void) | null = null;
  private readonly readyPromise: Promise<void>;

  private nextRequestId = 0;
  private readonly pendingRequests = new Map<
    number,
    {
      resolve: (value: Record<string, unknown>) => void;
      reject: (err: Error) => void;
      timer?: NodeJS.Timeout;
    }
  >();

  /** `session/prompt` requests that have not answered yet. */
  private outstandingPrompts = 0;
  private cancelRequested = false;
  private turnUsage: PromptUsage = {};
  private lastStopReason: string | undefined;
  private queuedInputs: Array<{
    text: string;
    images?: Array<{ base64: string; mimeType: string }>;
  }> = [];

  private textBuffer = "";
  private thinkingBuffer = "";
  private lastResultText = "";
  private readonly toolCalls = new Map<string, ToolCallState>();
  private readonly pendingPermissions = new Map<string, PendingPermission>();

  constructor(options?: {
    config?: AntigravityConfig;
    createTransport?: (config: AntigravityConfig) => AcpTransport;
  }) {
    super();
    this.config = options?.config ?? getAntigravityConfig();
    this.createTransport =
      options?.createTransport ?? ((config) => new StdioAcpTransport(config));
    this.readyPromise = new Promise<void>((resolve, reject) => {
      this.resolveReady = resolve;
      this.rejectReady = reject;
    });
    // Callers that never wait must not see an unhandled rejection.
    this.readyPromise.catch(() => {});
  }

  /** Settles once the session is usable (history replayed) or failed to start. */
  waitUntilReady(): Promise<void> {
    return this.readyPromise;
  }

  get status(): ProcessStatus {
    return this._status;
  }

  get sessionId(): string | null {
    return this._sessionId;
  }

  get isRunning(): boolean {
    return this.transport !== null && !this.stopped;
  }

  get isWaitingForInput(): boolean {
    return this.ready && this.outstandingPrompts === 0;
  }

  get isTurnActive(): boolean {
    return this.outstandingPrompts > 0;
  }

  get model(): string | undefined {
    return this._model;
  }

  get permissionMode(): PermissionMode | undefined {
    return this._permissionMode;
  }

  get authMode(): AntigravityAuthMode {
    return this.config.apiKey ? "api_key" : "login";
  }

  get settings(): AntigravitySettings {
    return {
      ...(this._model ? { model: this._model } : {}),
      models: [...this._models],
      ...(this._permissionMode ? { permissionMode: this._permissionMode } : {}),
      permissionModes: [...this._permissionModes],
      authMode: this.authMode,
    };
  }

  start(projectPath: string, options?: AntigravityStartOptions): void {
    if (this.transport) return;
    this.cwd = projectPath;
    this.stopped = false;
    this.exited = false;
    if (this.config.requireApiKey && !this.config.apiKey) {
      // Never spawn the default (Google login) profile for an agent-driven run.
      queueMicrotask(() =>
        this.failStart(
          "CCPOCKET_ANTIGRAVITY_REQUIRE_API_KEY is set but CCPOCKET_ANTIGRAVITY_API_KEY is empty. No prompt was sent.",
          "antigravity_api_key_required",
        ),
      );
      return;
    }

    const transport = this.createTransport(this.config);
    this.transport = transport;
    transport.on("message", (message) => this.handleIncoming(message));
    transport.on("error", (err) => {
      const notFound = (err as NodeJS.ErrnoException).code === "ENOENT";
      this.failStart(
        notFound ? ANTIGRAVITY_CLI_NOT_FOUND_MESSAGE : err.message,
        notFound ? "antigravity_cli_not_found" : undefined,
      );
    });
    transport.on("exit", (code) => this.handleExit(code));
    transport.start(projectPath);

    void this.bootstrap(projectPath, options).catch((err: unknown) => {
      if (this.stopped) return;
      const authRequired =
        err instanceof AcpError &&
        (err.code === -32000 || /authentication required/i.test(err.message));
      this.failStart(
        authRequired
          ? ANTIGRAVITY_AUTH_REQUIRED_MESSAGE
          : err instanceof Error
            ? err.message
            : String(err),
        authRequired ? "antigravity_auth_required" : undefined,
      );
    });
  }

  private async bootstrap(
    projectPath: string,
    options?: AntigravityStartOptions,
  ): Promise<void> {
    await this.request("initialize", {
      protocolVersion: ACP_PROTOCOL_VERSION,
      clientInfo: { name: "ccpocket-bridge", version: "1" },
      clientCapabilities: {
        fs: { readTextFile: false, writeTextFile: false },
        terminal: false,
      },
    });

    // The default profile keeps whatever the user signed in with. Sending
    // `authenticate` there would switch their everyday `agy` to the API key.
    if (this.config.apiKey) {
      await this.request("authenticate", {
        methodId: "gemini-api-key",
        _meta: { apiKey: this.config.apiKey },
      });
    }

    let session: Record<string, unknown>;
    if (options?.sessionId) {
      this.replaying = true;
      try {
        session = await this.request(
          "session/load",
          { sessionId: options.sessionId, cwd: projectPath, mcpServers: [] },
          LOAD_TIMEOUT_MS,
        );
      } finally {
        this.flushAssistant();
        this.replaying = false;
      }
      this._sessionId = options.sessionId;
    } else {
      session = await this.request("session/new", {
        cwd: projectPath,
        mcpServers: [],
      });
      this._sessionId = stringOr(session.sessionId) || null;
    }
    if (!this._sessionId) throw new Error("Antigravity did not return a session id");

    this.applySessionState(session);
    if (this.config.requireApiKey) {
      const foreign = this._models.filter((m) => !m.id.startsWith("gemini-"));
      if (this._models.length === 0 || foreign.length > 0) {
        throw new Error(
          "API-key mode could not be verified for Antigravity (non-Gemini models are listed). No prompt was sent.",
        );
      }
    }

    if (options?.model && options.model !== this._model) {
      await this.setModel(options.model).catch(() => {
        // Keep the agent default when the requested model is not offered.
      });
    }
    if (
      options?.permissionMode &&
      options.permissionMode !== this._permissionMode
    ) {
      await this.setPermissionMode(options.permissionMode).catch(() => {
        // Modes differ per account; fall back to the agent default.
      });
    }

    this.ready = true;
    this.emitMessage({
      type: "system",
      subtype: "init",
      sessionId: this._sessionId,
      provider: "antigravity",
      ...(this._model ? { model: this._model } : {}),
      ...(this._permissionMode ? { permissionMode: this._permissionMode } : {}),
      slashCommands: [...this._slashCommands],
      antigravity: this.settings,
    });
    this.setStatus("idle");
    this.resolveReady?.();

    const queued = this.queuedInputs;
    this.queuedInputs = [];
    for (const input of queued) this.dispatchPrompt(input.text, input.images);
  }

  stop(): void {
    this.stopped = true;
    this.rejectReady?.(new Error("Antigravity session stopped"));
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error("Antigravity session stopped"));
    }
    this.pendingRequests.clear();
    this.pendingPermissions.clear();
    this.queuedInputs = [];
    this.outstandingPrompts = 0;
    const transport = this.transport;
    this.transport = null;
    transport?.stop();
  }

  interrupt(): void {
    if (!this._sessionId || this.outstandingPrompts === 0) return;
    this.cancelRequested = true;
    // ACP requires pending permission requests to be answered as cancelled.
    for (const pending of this.pendingPermissions.values()) {
      this.respond(pending.requestId, { outcome: { outcome: "cancelled" } });
      this.emitToolResult(pending.toolUseId, "Cancelled", "rejected");
      const call = this.toolCalls.get(pending.toolUseId);
      if (call) call.rejected = true;
    }
    this.pendingPermissions.clear();
    this.notify("session/cancel", { sessionId: this._sessionId });
  }

  /** Returns false when the process cannot take the input. */
  sendInput(
    text: string,
    images?: Array<{ base64: string; mimeType: string }>,
  ): boolean {
    if (this.stopped || !this.transport) return false;
    if (!this.ready) {
      this.queuedInputs.push({ text, ...(images?.length ? { images } : {}) });
      return true;
    }
    this.dispatchPrompt(text, images);
    return true;
  }

  private dispatchPrompt(
    text: string,
    images?: Array<{ base64: string; mimeType: string }>,
  ): void {
    if (!this._sessionId) return;
    if (this.outstandingPrompts === 0) {
      this.turnUsage = {};
      this.lastResultText = "";
      this.lastStopReason = undefined;
      this.cancelRequested = false;
    }
    // A prompt sent after a cancel starts over; the cancelled request still
    // answers, but it no longer decides how the turn ends.
    this.cancelRequested = false;
    this.outstandingPrompts++;
    this.setStatus("running");
    const prompt: Array<Record<string, unknown>> = [];
    for (const image of images ?? []) {
      prompt.push({ type: "image", data: image.base64, mimeType: image.mimeType });
    }
    prompt.push({ type: "text", text });
    // A prompt sent while a turn runs steers that turn: Antigravity answers
    // the earlier request at once with a bare `end_turn` and the new request
    // owns the rest. The turn ends only when every request has answered.
    this.request("session/prompt", { sessionId: this._sessionId, prompt }, 0)
      .then((result) => this.handlePromptSettled(result))
      .catch((err: unknown) => this.handlePromptSettled(undefined, err));
  }

  private handlePromptSettled(
    result?: Record<string, unknown>,
    err?: unknown,
  ): void {
    if (this.stopped) return;
    this.outstandingPrompts = Math.max(0, this.outstandingPrompts - 1);
    const usage = isRecord(result?.usage) ? result.usage : undefined;
    if (usage) {
      const add = (key: keyof PromptUsage): void => {
        const value = usage[key];
        if (typeof value === "number") {
          this.turnUsage[key] = (this.turnUsage[key] ?? 0) + value;
        }
      };
      add("inputTokens");
      add("cachedReadTokens");
      add("outputTokens");
    }
    const stopReason = stringOr(result?.stopReason) || undefined;
    if (stopReason) this.lastStopReason = stopReason;
    if (this.outstandingPrompts > 0) return;

    this.flushAssistant();
    this.pendingPermissions.clear();
    const sessionId = this._sessionId ?? undefined;
    if (err) {
      this.emitMessage({
        type: "result",
        subtype: "error",
        error: err instanceof Error ? err.message : String(err),
        sessionId,
      });
    } else if (this.lastStopReason === "cancelled" || this.cancelRequested) {
      this.emitMessage({ type: "result", subtype: "interrupted", sessionId });
    } else {
      this.emitMessage({
        type: "result",
        subtype: "success",
        sessionId,
        ...(this.lastResultText ? { result: this.lastResultText } : {}),
        ...(this.lastStopReason ? { stopReason: this.lastStopReason } : {}),
        ...(this.turnUsage.inputTokens != null
          ? { inputTokens: this.turnUsage.inputTokens }
          : {}),
        ...(this.turnUsage.cachedReadTokens != null
          ? { cachedInputTokens: this.turnUsage.cachedReadTokens }
          : {}),
        ...(this.turnUsage.outputTokens != null
          ? { outputTokens: this.turnUsage.outputTokens }
          : {}),
      });
    }
    this.cancelRequested = false;
    this.setStatus("idle");
    this.emit("input_ready");
  }

  approve(toolUseId?: string): boolean {
    return this.resolvePermission(toolUseId, "allow_once", "approved");
  }

  /** Antigravity offers no session-wide grant unless it lists `allow_always`. */
  approveAlways(toolUseId?: string): boolean {
    const pending = this.findPendingPermission(toolUseId);
    if (!pending) return false;
    const always = pending.options.some((o) => o.kind === "allow_always");
    return this.resolvePermission(
      pending.toolUseId,
      always ? "allow_always" : "allow_once",
      always ? "approved_for_session" : "approved",
    );
  }

  reject(toolUseId?: string, _message?: string): boolean {
    return this.resolvePermission(toolUseId, "reject_once", "rejected");
  }

  /** Antigravity asks nothing through this channel yet. */
  answer(_toolUseId: string, _result: string): boolean {
    return false;
  }

  getPendingPermissions(): Array<{
    toolUseId: string;
    toolName: string;
    input: Record<string, unknown>;
  }> {
    return [...this.pendingPermissions.values()].map((pending) => ({
      toolUseId: pending.toolUseId,
      toolName: pending.toolName,
      input: { ...pending.input },
    }));
  }

  getPendingPermission(toolUseId?: string):
    | { toolUseId: string; toolName: string; input: Record<string, unknown> }
    | undefined {
    const pending = this.findPendingPermission(toolUseId);
    return pending
      ? {
          toolUseId: pending.toolUseId,
          toolName: pending.toolName,
          input: { ...pending.input },
        }
      : undefined;
  }

  async setPermissionMode(mode: PermissionMode): Promise<void> {
    if (!this._sessionId) throw new Error("Antigravity session is not ready");
    const modeId = acpModeFromPermissionMode(mode);
    if (!modeId) {
      throw new Error(`Antigravity does not support the ${mode} mode`);
    }
    await this.request("session/set_mode", {
      sessionId: this._sessionId,
      modeId,
    });
    this._permissionMode = mode;
    if (this.ready) this.emitPermissionMode();
  }

  async setModel(modelId: string): Promise<void> {
    if (!this._sessionId) throw new Error("Antigravity session is not ready");
    await this.request("session/set_model", {
      sessionId: this._sessionId,
      modelId,
    });
    this._model = modelId;
    if (this.ready) this.emitSettings();
  }

  // ---- incoming -----------------------------------------------------------

  private handleIncoming(message: Record<string, unknown>): void {
    if (this.stopped) return;
    const { id, method } = message;
    if (typeof method !== "string") {
      if (typeof id !== "number") return;
      const pending = this.pendingRequests.get(id);
      if (!pending) return;
      this.pendingRequests.delete(id);
      clearTimeout(pending.timer);
      if (isRecord(message.error)) {
        pending.reject(
          new AcpError(
            stringOr(message.error.message, "Antigravity request failed"),
            typeof message.error.code === "number"
              ? message.error.code
              : undefined,
          ),
        );
      } else {
        pending.resolve(isRecord(message.result) ? message.result : {});
      }
      return;
    }

    const params = isRecord(message.params) ? message.params : {};
    if (method === "session/update") {
      if (isRecord(params.update)) this.handleUpdate(params.update);
      return;
    }
    if (typeof id !== "number" && typeof id !== "string") return;
    if (method === "session/request_permission") {
      this.handlePermissionRequest(id, params);
      return;
    }
    this.transport?.write({
      jsonrpc: "2.0",
      id,
      error: { code: -32601, message: "Method not found" },
    });
  }

  private handleUpdate(update: Record<string, unknown>): void {
    switch (update.sessionUpdate) {
      case "agent_message_chunk": {
        const text = isRecord(update.content) ? stringOr(update.content.text) : "";
        if (!text) return;
        this.textBuffer += text;
        if (!this.replaying) this.emitMessage({ type: "stream_delta", text });
        return;
      }
      case "agent_thought_chunk": {
        const text = isRecord(update.content) ? stringOr(update.content.text) : "";
        if (!text) return;
        this.thinkingBuffer += text;
        if (!this.replaying) this.emitMessage({ type: "thinking_delta", text });
        return;
      }
      case "user_message_chunk": {
        // Only `session/load` replays user turns.
        this.flushAssistant();
        const text = isRecord(update.content) ? stringOr(update.content.text) : "";
        if (text) {
          // Without an id, two identical prompts would be merged into one.
          this.emitMessage({
            type: "user_input",
            text,
            userMessageUuid: `antigravity:replay:${++this.replayedUserTurns}`,
          });
        }
        return;
      }
      case "tool_call":
        this.handleToolCall(update, true);
        return;
      case "tool_call_update":
        this.handleToolCall(update, false);
        return;
      case "session_info_update": {
        const title = stringOr(update.title).trim();
        if (title) this.emit("title", title);
        return;
      }
      case "current_mode_update": {
        const mode = permissionModeFromAcpMode(update.currentModeId);
        if (mode && mode !== this._permissionMode) {
          this._permissionMode = mode;
          if (this.ready) this.emitPermissionMode();
        }
        return;
      }
      case "available_commands_update": {
        const commands = Array.isArray(update.availableCommands)
          ? update.availableCommands
          : [];
        this._slashCommands = commands
          .map((command) => (isRecord(command) ? stringOr(command.name) : ""))
          .filter((name) => name.length > 0);
        if (this.ready) {
          this.emitMessage({
            type: "system",
            subtype: "supported_commands",
            provider: "antigravity",
            slashCommands: [...this._slashCommands],
          });
        }
        return;
      }
      default:
        // usage_update, config_option_update and future kinds carry nothing
        // the client renders.
        return;
    }
  }

  private handleToolCall(update: Record<string, unknown>, isNew: boolean): void {
    const toolUseId = stringOr(update.toolCallId);
    if (!toolUseId) return;
    let call = this.toolCalls.get(toolUseId);
    if (!call) {
      this.flushAssistant();
      const kind = stringOr(update.kind, "other");
      const title = stringOr(update.title);
      const rawInput = isRecord(update.rawInput) ? update.rawInput : {};
      let toolName: string;
      let input: Record<string, unknown>;
      if (kind === "execute") {
        toolName = "Bash";
        input = { command: stringOr(rawInput.CommandLine, title) };
      } else if (kind === "edit") {
        toolName = "FileChange";
        const changes = fileChangesFromContent(update.content, this.cwd);
        input = {
          changes: changes.length > 0 ? changes : this.changesFromLocations(update),
        };
      } else {
        toolName = stringOr(update.name) || title || kind;
        input = { ...rawInput };
      }
      call = { toolName, kind, title, rejected: false, finished: false };
      this.toolCalls.set(toolUseId, call);
      this.emitMessage({
        type: "assistant",
        message: {
          id: toolUseId,
          role: "assistant",
          content: [{ type: "tool_use", id: toolUseId, name: toolName, input }],
          model: this._model ?? "antigravity",
        },
      });
    } else if (isNew) {
      return;
    }

    const status = stringOr(update.status);
    if ((status !== "completed" && status !== "failed") || call.finished) return;
    call.finished = true;
    if (call.rejected) return;

    let content: string;
    if (call.kind === "edit") {
      const changes = fileChangesFromContent(update.content, this.cwd);
      content =
        changes.map((change) => change.diff).join("\n\n") ||
        (status === "failed" ? "File change failed" : "File changed");
    } else {
      const rawOutput = isRecord(update.rawOutput) ? update.rawOutput : {};
      const output =
        typeof rawOutput.output === "string"
          ? cleanCommandOutput(rawOutput.output)
          : cleanCommandOutput(textFromToolContent(update.content));
      const exitCode = rawOutput.exit_code;
      content =
        output ||
        (typeof exitCode === "number"
          ? `exit code: ${exitCode}`
          : status === "failed"
            ? "Failed"
            : "Done");
    }
    this.emitMessage({
      type: "tool_result",
      toolUseId,
      content,
      toolName: call.toolName,
    });
  }

  private changesFromLocations(update: Record<string, unknown>): FileChange[] {
    const locations = Array.isArray(update.locations) ? update.locations : [];
    return locations
      .map((location) => (isRecord(location) ? stringOr(location.path) : ""))
      .filter((path) => path.length > 0)
      .map((path) => ({ path, kind: "update" as const, diff: "" }));
  }

  private handlePermissionRequest(
    requestId: number | string,
    params: Record<string, unknown>,
  ): void {
    const toolCall = isRecord(params.toolCall) ? params.toolCall : {};
    const toolUseId = stringOr(toolCall.toolCallId) || `permission-${requestId}`;
    const options = (Array.isArray(params.options) ? params.options : [])
      .filter(isRecord)
      .map((option) => ({
        optionId: stringOr(option.optionId),
        kind: stringOr(option.kind),
      }))
      .filter((option) => option.optionId.length > 0);

    const availableDecisions = [
      ...(options.some((o) => o.kind === "allow_once") ? ["accept"] : []),
      ...(options.some((o) => o.kind === "allow_always")
        ? ["acceptForSession"]
        : []),
      ...(options.some((o) => o.kind.startsWith("reject")) ? ["decline"] : []),
    ];
    const kind = stringOr(toolCall.kind, this.toolCalls.get(toolUseId)?.kind ?? "other");
    const rawInput = isRecord(toolCall.rawInput) ? toolCall.rawInput : {};
    let toolName: string;
    let input: Record<string, unknown>;
    if (kind === "execute") {
      toolName = "Bash";
      input = {
        command: stringOr(rawInput.CommandLine, stringOr(toolCall.title)),
        availableDecisions,
      };
    } else if (kind === "edit") {
      toolName = "FileChange";
      const changes = fileChangesFromContent(toolCall.content, this.cwd);
      input = {
        changes: changes.length > 0 ? changes : this.changesFromLocations(toolCall),
        availableDecisions,
      };
    } else {
      toolName =
        this.toolCalls.get(toolUseId)?.toolName ||
        stringOr(toolCall.name) ||
        stringOr(toolCall.title) ||
        kind;
      input = { ...rawInput, availableDecisions };
    }

    this.pendingPermissions.set(toolUseId, {
      requestId,
      toolUseId,
      toolName,
      input,
      options,
    });
    // Status first: the session summary broadcast with the request must
    // already say "waiting_approval", or clients drop the approval again.
    this.setStatus("waiting_approval");
    this.emitMessage({ type: "permission_request", toolUseId, toolName, input });
  }

  private findPendingPermission(toolUseId?: string): PendingPermission | undefined {
    if (toolUseId) return this.pendingPermissions.get(toolUseId);
    const first = this.pendingPermissions.values().next();
    return first.done ? undefined : first.value;
  }

  private resolvePermission(
    toolUseId: string | undefined,
    wantedKind: string,
    outcome: "approved" | "approved_for_session" | "rejected",
  ): boolean {
    const pending = this.findPendingPermission(toolUseId);
    if (!pending) return false;
    const option =
      pending.options.find((o) => o.kind === wantedKind) ??
      (outcome === "rejected"
        ? pending.options.find((o) => o.kind.startsWith("reject"))
        : undefined);
    this.pendingPermissions.delete(pending.toolUseId);
    this.respond(
      pending.requestId,
      option
        ? { outcome: { outcome: "selected", optionId: option.optionId } }
        : { outcome: { outcome: "cancelled" } },
    );
    if (outcome === "rejected") {
      // Antigravity ends the turn silently after a denial, so this is the
      // only trace of it the client gets.
      const call = this.toolCalls.get(pending.toolUseId);
      if (call) call.rejected = true;
      this.emitToolResult(pending.toolUseId, "Rejected", "rejected");
    } else {
      this.emitToolResult(pending.toolUseId, "Approved", outcome);
    }
    if (this.pendingPermissions.size === 0 && this.outstandingPrompts > 0) {
      this.setStatus("running");
    }
    return true;
  }

  private applySessionState(session: Record<string, unknown>): void {
    const models = isRecord(session.models) ? session.models : {};
    this._models = (
      Array.isArray(models.availableModels) ? models.availableModels : []
    )
      .filter(isRecord)
      .map((model) => ({
        id: stringOr(model.modelId),
        name: stringOr(model.name, stringOr(model.modelId)),
      }))
      .filter((model) => model.id.length > 0);
    this._model = stringOr(models.currentModelId) || undefined;

    const modes = isRecord(session.modes) ? session.modes : {};
    this._permissionModes = (
      Array.isArray(modes.availableModes) ? modes.availableModes : []
    )
      .map((mode) =>
        isRecord(mode) ? permissionModeFromAcpMode(mode.id) : undefined,
      )
      .filter((mode): mode is PermissionMode => mode !== undefined);
    this._permissionMode = permissionModeFromAcpMode(modes.currentModeId);
  }

  // ---- outgoing -----------------------------------------------------------

  private request(
    method: string,
    params: Record<string, unknown>,
    timeoutMs = REQUEST_TIMEOUT_MS,
  ): Promise<Record<string, unknown>> {
    return new Promise((resolve, reject) => {
      if (!this.transport) {
        reject(new Error("Antigravity is not running"));
        return;
      }
      const id = ++this.nextRequestId;
      const timer =
        timeoutMs > 0
          ? setTimeout(() => {
              this.pendingRequests.delete(id);
              reject(new Error(`Antigravity did not answer ${method}`));
            }, timeoutMs)
          : undefined;
      timer?.unref?.();
      this.pendingRequests.set(id, { resolve, reject, ...(timer ? { timer } : {}) });
      this.transport.write({ jsonrpc: "2.0", id, method, params });
    });
  }

  private notify(method: string, params: Record<string, unknown>): void {
    this.transport?.write({ jsonrpc: "2.0", method, params });
  }

  private respond(id: number | string, result: Record<string, unknown>): void {
    this.transport?.write({ jsonrpc: "2.0", id, result });
  }

  // ---- emit helpers -------------------------------------------------------

  private flushAssistant(): void {
    const thinking = this.thinkingBuffer.trim();
    const text = this.textBuffer.trim();
    this.thinkingBuffer = "";
    this.textBuffer = "";
    if (!thinking && !text) return;
    const content: AssistantContent[] = [];
    if (thinking) content.push({ type: "thinking", thinking });
    if (text) {
      content.push({ type: "text", text });
      this.lastResultText = text;
    }
    this.emitMessage({
      type: "assistant",
      message: {
        id: randomUUID(),
        role: "assistant",
        content,
        model: this._model ?? "antigravity",
      },
    });
  }

  private emitSettings(): void {
    this.emitMessage({
      type: "system",
      subtype: "antigravity_settings",
      provider: "antigravity",
      ...(this._model ? { model: this._model } : {}),
      ...(this._permissionMode ? { permissionMode: this._permissionMode } : {}),
      antigravity: this.settings,
    });
  }

  /** Same shape Claude sessions use, so clients update their mode chip. */
  private emitPermissionMode(): void {
    if (!this._permissionMode) return;
    this.emitMessage({
      type: "system",
      subtype: "set_permission_mode",
      provider: "antigravity",
      permissionMode: this._permissionMode,
      sessionId: this._sessionId ?? undefined,
    });
    this.emitSettings();
  }

  private emitToolResult(
    toolUseId: string,
    content: string,
    permissionOutcome: "approved" | "approved_for_session" | "rejected",
  ): void {
    this.emitMessage({
      type: "tool_result",
      toolUseId,
      content,
      permissionOutcome,
    });
  }

  private failStart(rawMessage: string, errorCode?: string): void {
    if (this.stopped) return;
    const message = this.config.apiKey
      ? rawMessage.split(this.config.apiKey).join("<redacted>")
      : rawMessage;
    this.emitMessage({
      type: "error",
      message,
      ...(errorCode ? { errorCode } : {}),
    });
    // Before stop(), which would report a generic "stopped" instead.
    this.rejectReady?.(new AntigravityStartError(message, errorCode));
    this.stop();
    this.ready = false;
    this.setStatus("idle");
    this.emitExit(null);
  }

  private emitExit(code: number | null): void {
    if (this.exited) return;
    this.exited = true;
    this.emit("exit", code);
  }

  private handleExit(code: number | null): void {
    const wasStopped = this.stopped;
    if (!wasStopped && !this.ready) {
      // Died while starting: report it instead of leaving callers waiting.
      this.failStart(`Antigravity exited before the session was ready (code ${code})`);
      return;
    }
    this.transport = null;
    this.pendingPermissions.clear();
    this.queuedInputs = [];
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error("Antigravity exited"));
    }
    this.pendingRequests.clear();
    this.stopped = true;
    this.ready = false;
    if (!wasStopped && this.outstandingPrompts > 0) {
      this.flushAssistant();
      this.emitMessage({
        type: "result",
        subtype: "error",
        error: "Antigravity exited unexpectedly",
        sessionId: this._sessionId ?? undefined,
      });
    }
    this.outstandingPrompts = 0;
    this.setStatus("idle");
    this.emitExit(code);
  }

  private setStatus(status: ProcessStatus): void {
    if (this._status === status) return;
    this._status = status;
    this.emit("status", status);
    this.emitMessage({ type: "status", status });
  }

  private emitMessage(message: ServerMessage): void {
    this.emit("message", message);
  }
}
