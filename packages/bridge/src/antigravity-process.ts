import {
  execFile,
  spawn,
  type ChildProcessWithoutNullStreams,
} from "node:child_process";
import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { basename } from "node:path";
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
/** Silence after a usage report that ends a turn the agent started itself. */
const SELF_TURN_SETTLE_MS = 5_000;

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
  /**
   * Model to start with: an ACP model id (`gemini-3.8-flash-high`) or a model
   * family from the `model` config option (`gemini-3.8-flash`).
   */
  model?: string;
  /** Value for the `thought_level` config option (`low`, `high`, ...). */
  thoughtLevel?: string;
  permissionMode?: PermissionMode;
  /** Extra workspace roots (absolute paths). */
  additionalDirectories?: string[];
}

export interface AntigravityModelInfo {
  id: string;
  name: string;
}

/** A model family and the thinking levels it can run with. */
export interface AntigravityModelOption {
  id: string;
  name: string;
  thoughtLevels: string[];
}

/** The plan the signed-in account is on (`_meta.antigravity.tier`). */
export interface AntigravityTier {
  id?: string;
  name: string;
}

export interface AntigravityContextUsage {
  used: number;
  size: number;
}

export interface AntigravitySettings {
  /** ACP model id: family and thinking level in one (`gemini-3.8-flash-high`). */
  model?: string;
  models: AntigravityModelInfo[];
  /** Current model family (`gemini-3.8-flash`). */
  baseModel?: string;
  /** Model families, each with the thinking levels it offers. */
  modelOptions: AntigravityModelOption[];
  thoughtLevel?: string;
  /** Thinking levels the current model offers. */
  thoughtLevels: string[];
  permissionMode?: PermissionMode;
  permissionModes: PermissionMode[];
  authMode: AntigravityAuthMode;
  tier?: AntigravityTier;
  /** Tokens in the context window, as Antigravity reports them. */
  contextUsage?: AntigravityContextUsage;
  /** `agy` version. */
  agentVersion?: string;
}

/** What a session can be started with, read without sending a prompt. */
export interface AntigravityCatalog {
  model?: string;
  models: AntigravityModelInfo[];
  baseModel?: string;
  modelOptions: AntigravityModelOption[];
  thoughtLevel?: string;
  permissionModes: PermissionMode[];
  authMode: AntigravityAuthMode;
  tier?: AntigravityTier;
  agentVersion?: string;
}

/** Capabilities every Bridge ACP client declares. */
export const ACP_CLIENT_INFO = { name: "ccpocket-bridge", version: "1" };

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
  /** What "always allow" would cover: every edit, this exact command, or this MCP tool. */
  sessionGrant?:
    | { kind: "edit" }
    | { kind: "execute"; command: string }
    | { kind: "mcp"; tool: string };
}

interface ToolCallState {
  toolName: string;
  kind: string;
  title: string;
  /** A permission decision already produced the tool_result for this call. */
  rejected: boolean;
  finished: boolean;
}

interface ElicitationField {
  id: string;
  /** Sibling free-text property (`q1_other`) for answers outside the options. */
  otherId?: string;
  question: string;
  type: "choice" | "multi" | "boolean" | "number" | "text";
  options: Array<{ value: unknown; label: string }>;
}

interface PendingElicitation {
  requestId: number | string;
  toolUseId: string;
  input: Record<string, unknown>;
  fields: ElicitationField[];
}

interface PendingPlan {
  toolUseId: string;
  plan: string;
}

interface PromptUsage {
  inputTokens?: number;
  cachedReadTokens?: number;
  outputTokens?: number;
  thoughtTokens?: number;
}

/** Bridge-only mode: the ACP session stays in `default` and every request is allowed. */
const BYPASS_MODE: PermissionMode = "bypassPermissions";
const PLAN_APPROVED_PROMPT = "Approved. Proceed with the implementation plan.";
const THOUGHT_LEVELS = ["minimal", "low", "medium", "high", "xhigh", "max"];

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

/** `agy` keeps plans and other documents it writes for the user here. */
const ARTIFACT_PATH_PATTERN = /\/brain\/[^/]+\/[^/]+$/;
const PLAN_ARTIFACT_NAME = "implementation_plan.md";

function isArtifactPath(path: string, cwd: string): boolean {
  const prefix = cwd ? `${cwd.replace(/\/+$/, "")}/` : "";
  return !(prefix && path.startsWith(prefix)) && ARTIFACT_PATH_PATTERN.test(path);
}

/** Path to show for a file: relative to the project, or an artifact's name. */
function displayPath(path: string, cwd: string): string {
  const prefix = cwd ? `${cwd.replace(/\/+$/, "")}/` : "";
  if (prefix && path.startsWith(prefix)) return path.slice(prefix.length);
  return isArtifactPath(path, cwd) ? basename(path) : path;
}

function fileChangesFromContent(content: unknown, cwd = ""): FileChange[] {
  if (!Array.isArray(content)) return [];
  const changes: FileChange[] = [];
  for (const block of content) {
    if (!isRecord(block) || block.type !== "diff") continue;
    const path = stringOr(block.path);
    if (!path) continue;
    const oldText = typeof block.oldText === "string" ? block.oldText : null;
    const shown = displayPath(path, cwd);
    changes.push({
      // Artifacts live deep in the Antigravity profile; show their name.
      path: isArtifactPath(path, cwd) ? shown : path,
      kind: oldText == null ? "add" : "update",
      diff: buildUnifiedDiff(shown, oldText, stringOr(block.newText)),
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

function numberOr(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

interface AcpSelectOption {
  current?: string;
  options: AntigravityModelInfo[];
}

function selectOption(configOptions: unknown, id: string): AcpSelectOption | undefined {
  if (!Array.isArray(configOptions)) return undefined;
  const option = configOptions.find(
    (candidate) => isRecord(candidate) && candidate.id === id,
  );
  if (!isRecord(option)) return undefined;
  return {
    current: stringOr(option.currentValue) || undefined,
    options: (Array.isArray(option.options) ? option.options : [])
      .filter(isRecord)
      .map((entry) => ({
        id: stringOr(entry.value),
        name: stringOr(entry.name, stringOr(entry.value)),
      }))
      .filter((entry) => entry.id.length > 0),
  };
}

export interface AcpConfigState {
  baseModel?: string;
  baseModels: AntigravityModelInfo[];
  thoughtLevel?: string;
  thoughtLevels: string[];
}

/** Reads the `model` and `thought_level` config options. */
export function parseAcpConfigOptions(configOptions: unknown): AcpConfigState | undefined {
  const model = selectOption(configOptions, "model");
  const thought = selectOption(configOptions, "thought_level");
  if (!model && !thought) return undefined;
  return {
    ...(model?.current ? { baseModel: model.current } : {}),
    baseModels: model?.options ?? [],
    ...(thought?.current ? { thoughtLevel: thought.current } : {}),
    thoughtLevels: (thought?.options ?? []).map((option) => option.id),
  };
}

/**
 * Model families with their thinking levels. ACP lists every family/level
 * pair as its own model (`gemini-3.8-flash-high`), so the levels of a family
 * are the suffixes of the models that start with its id.
 */
export function buildModelOptions(
  baseModels: AntigravityModelInfo[],
  models: AntigravityModelInfo[],
): AntigravityModelOption[] {
  return baseModels.map((base) => ({
    id: base.id,
    name: base.name,
    thoughtLevels: models
      .filter((model) => model.id.startsWith(`${base.id}-`))
      .map((model) => model.id.slice(base.id.length + 1))
      .filter((level) => THOUGHT_LEVELS.includes(level))
      // Lowest first, whatever order the models are listed in.
      .sort((a, b) => THOUGHT_LEVELS.indexOf(a) - THOUGHT_LEVELS.indexOf(b)),
  }));
}

export interface AcpSessionState {
  model?: string;
  models: AntigravityModelInfo[];
  permissionMode?: PermissionMode;
  permissionModes: PermissionMode[];
  config?: AcpConfigState;
  tier?: AntigravityTier;
}

/** Reads a `session/new` or `session/load` response. */
export function parseAcpSessionState(session: Record<string, unknown>): AcpSessionState {
  const models = isRecord(session.models) ? session.models : {};
  const modes = isRecord(session.modes) ? session.modes : {};
  const meta = isRecord(session._meta) ? session._meta : {};
  const antigravity = isRecord(meta.antigravity) ? meta.antigravity : {};
  const tier = isRecord(antigravity.tier) ? antigravity.tier : undefined;
  const tierName = stringOr(tier?.name).trim();
  const config = parseAcpConfigOptions(session.configOptions);
  const model = stringOr(models.currentModelId) || undefined;
  const permissionMode = permissionModeFromAcpMode(modes.currentModeId);
  return {
    ...(model ? { model } : {}),
    models: (Array.isArray(models.availableModels) ? models.availableModels : [])
      .filter(isRecord)
      .map((entry) => ({
        id: stringOr(entry.modelId),
        name: stringOr(entry.name, stringOr(entry.modelId)),
      }))
      .filter((entry) => entry.id.length > 0),
    ...(permissionMode ? { permissionMode } : {}),
    permissionModes: (Array.isArray(modes.availableModes) ? modes.availableModes : [])
      .map((mode) => (isRecord(mode) ? permissionModeFromAcpMode(mode.id) : undefined))
      .filter((mode): mode is PermissionMode => mode !== undefined),
    ...(config ? { config } : {}),
    ...(tierName
      ? { tier: { ...(stringOr(tier?.id) ? { id: stringOr(tier?.id) } : {}), name: tierName } }
      : {}),
  };
}

function firstString(source: Record<string, unknown>, keys: string[]): string {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === "string" && value.length > 0) return value;
  }
  return "";
}

function firstLocation(update: Record<string, unknown>): string {
  const locations = Array.isArray(update.locations) ? update.locations : [];
  for (const location of locations) {
    if (isRecord(location) && typeof location.path === "string") return location.path;
  }
  return "";
}

/** `ask_question` arguments in the shape clients render question forms from. */
function questionsFromAskQuestion(rawInput: Record<string, unknown>): Array<Record<string, unknown>> {
  return (Array.isArray(rawInput.questions) ? rawInput.questions : [])
    .filter(isRecord)
    .map((question) => ({
      question: stringOr(question.question),
      header: "",
      options: (Array.isArray(question.options) ? question.options : [])
        .filter((option): option is string => typeof option === "string")
        .map((label) => ({ label, description: "" })),
      multiSelect: question.is_multi_select === true,
    }));
}

/**
 * Tool name and input clients already know how to render. Antigravity's own
 * names (`read_file`, `search_web`, ...) would otherwise show as raw JSON.
 */
/**
 * An MCP tool call. Antigravity reports every one as its own `call_mcp_tool`
 * of kind `execute`, which would otherwise show as a shell command.
 */
function mcpToolFromAcp(
  update: Record<string, unknown>,
): { key: string; toolName: string; input: Record<string, unknown> } | undefined {
  if (stringOr(update.name) !== "call_mcp_tool") return undefined;
  const rawInput = isRecord(update.rawInput) ? update.rawInput : {};
  const server = stringOr(rawInput.ServerName);
  const tool = stringOr(rawInput.ToolName);
  if (!server || !tool) return undefined;
  let args: unknown = rawInput.Arguments;
  if (typeof args === "string") {
    try {
      args = JSON.parse(args);
    } catch {
      args = { arguments: args };
    }
  }
  return {
    key: `${server}/${tool}`,
    // The name Claude sessions use, which clients already render.
    toolName: `mcp__${server}__${tool}`,
    input: isRecord(args) ? { ...args } : {},
  };
}

export function describeAcpTool(
  update: Record<string, unknown>,
): { toolName: string; input: Record<string, unknown> } | undefined {
  const kind = stringOr(update.kind, "other");
  const name = stringOr(update.name);
  const rawInput = isRecord(update.rawInput) ? update.rawInput : {};
  const mcp = mcpToolFromAcp(update);
  if (mcp) return { toolName: mcp.toolName, input: mcp.input };
  if (name === "ask_question") {
    return {
      toolName: "AskUserQuestion",
      input: { questions: questionsFromAskQuestion(rawInput) },
    };
  }
  if (kind === "read") {
    const path =
      firstString(rawInput, ["Path", "AbsolutePath", "path", "file_path"]) ||
      firstLocation(update);
    if (path) return { toolName: "Read", input: { file_path: path } };
  }
  if (kind === "search") {
    const query = firstString(rawInput, ["query", "Query", "Pattern", "pattern"]);
    const path = firstString(rawInput, ["SearchPath", "SearchDirectory", "Path", "path"]);
    if (query) {
      return name.includes("web")
        ? { toolName: "WebSearch", input: { query } }
        : { toolName: "Grep", input: { pattern: query, ...(path ? { path } : {}) } };
    }
  }
  if (kind === "fetch") {
    const url = firstString(rawInput, ["Url", "url", "URL"]);
    if (url) return { toolName: "WebFetch", input: { url } };
  }
  return undefined;
}

function schemaOptions(schema: Record<string, unknown>): Array<{ value: unknown; label: string }> {
  const variants = Array.isArray(schema.oneOf)
    ? schema.oneOf
    : Array.isArray(schema.anyOf)
      ? schema.anyOf
      : undefined;
  if (variants) {
    return variants
      .filter(isRecord)
      .filter((variant) => variant.const !== undefined)
      .map((variant) => ({
        value: variant.const,
        label: stringOr(variant.title, String(variant.const)),
      }));
  }
  if (Array.isArray(schema.enum)) {
    const names = Array.isArray(schema.enumNames) ? schema.enumNames : [];
    return schema.enum.map((value, index) => ({
      value,
      label: typeof names[index] === "string" ? (names[index] as string) : String(value),
    }));
  }
  return [];
}

/** Turns an ACP elicitation form schema into the questions clients render. */
export function elicitationFieldsFromSchema(requestedSchema: unknown): ElicitationField[] {
  const schema = isRecord(requestedSchema) ? requestedSchema : {};
  const properties = isRecord(schema.properties) ? schema.properties : {};
  const fields: ElicitationField[] = [];
  for (const [id, raw] of Object.entries(properties)) {
    if (!isRecord(raw)) continue;
    // `q1_other` is the free-text escape hatch of `q1`, not its own question.
    if (id.endsWith("_other") && isRecord(properties[id.slice(0, -"_other".length)])) {
      continue;
    }
    const items = isRecord(raw.items) ? raw.items : undefined;
    const multi = raw.type === "array" && items !== undefined;
    const options = schemaOptions(multi ? items : raw);
    fields.push({
      id,
      ...(isRecord(properties[`${id}_other`]) ? { otherId: `${id}_other` } : {}),
      question: stringOr(raw.title) || stringOr(raw.description) || id,
      type: multi
        ? "multi"
        : options.length > 0
          ? "choice"
          : raw.type === "boolean"
            ? "boolean"
            : raw.type === "number" || raw.type === "integer"
              ? "number"
              : "text",
      options:
        options.length === 0 && raw.type === "boolean"
          ? [
              { value: true, label: "Yes" },
              { value: false, label: "No" },
            ]
          : options,
    });
  }
  return fields;
}

function answerValues(value: unknown): string[] {
  if (Array.isArray(value)) return value.flatMap(answerValues);
  if (typeof value === "string") return value.trim() ? [value.trim()] : [];
  if (typeof value === "number" || typeof value === "boolean") return [String(value)];
  if (isRecord(value)) return answerValues(value.answers ?? value.value);
  return [];
}

/**
 * Builds the elicitation `content` from a client answer: either
 * `{"answers": {<id or question>: <label or labels>}}` or plain text for the
 * first question.
 */
export function elicitationContentFromAnswer(
  fields: ElicitationField[],
  rawResult: string,
): Record<string, unknown> {
  let answers: Record<string, unknown> = {};
  try {
    const parsed: unknown = JSON.parse(rawResult);
    if (isRecord(parsed) && isRecord(parsed.answers)) answers = parsed.answers;
  } catch {
    // Plain text answers the first question.
  }
  const structured = Object.keys(answers).length > 0;
  const content: Record<string, unknown> = {};
  fields.forEach((field, index) => {
    const values = answerValues(
      answers[field.id] ??
        answers[field.question] ??
        (!structured && index === 0 ? rawResult : undefined),
    );
    if (values.length === 0) return;
    const matched: unknown[] = [];
    const other: string[] = [];
    for (const value of values) {
      const option = field.options.find(
        (candidate) => candidate.label === value || String(candidate.value) === value,
      );
      if (option) matched.push(option.value);
      else other.push(value);
    }
    if (field.type === "multi") {
      if (matched.length > 0) content[field.id] = matched;
      if (other.length > 0) {
        if (field.otherId) content[field.otherId] = other.join(", ");
        else content[field.id] = [...matched, ...other];
      }
      return;
    }
    if (matched.length > 0) {
      content[field.id] = matched[0];
    } else if (field.otherId) {
      content[field.otherId] = other.join(", ");
    } else if (field.type === "number" && Number.isFinite(Number(other[0]))) {
      content[field.id] = Number(other[0]);
    } else {
      content[field.id] = other.join(", ");
    }
  });
  return content;
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
  /** Mode to return to once a plan is approved. */
  private modeBeforePlan: PermissionMode = "default";
  private bypass = false;
  private acpConfig: AcpConfigState | undefined;
  private _tier: AntigravityTier | undefined;
  private _contextUsage: AntigravityContextUsage | undefined;
  private contextUsageDirty = false;
  private _agentVersion: string | undefined;
  private _slashCommands: string[] = [];
  private _slashCommandDescriptions: Record<string, string> = {};
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
  /**
   * A turn Antigravity started on its own: a `schedule` timer or a finished
   * background task woke the agent after the last prompt had answered. No
   * request frames such a turn, so its end is read from the stream.
   */
  private selfTurn = false;
  private selfTurnTimer: ReturnType<typeof setTimeout> | null = null;
  private cancelRequested = false;
  private turnUsage: PromptUsage = {};
  private turnStartedAt = 0;
  private turnToolCalls = 0;
  private turnFileEdits = 0;
  /** Plan document written during this turn, awaiting review at its end. */
  private planArtifact: { path: string; content: string } | null = null;
  private pendingPlan: PendingPlan | null = null;
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
  private readonly pendingElicitations = new Map<string, PendingElicitation>();
  /**
   * "Always allow" choices of this session. Antigravity only offers allow
   * once, so the Bridge remembers the choice and answers repeats itself.
   */
  private allowEditsForSession = false;
  private readonly allowedCommands = new Set<string>();
  private readonly allowedMcpTools = new Set<string>();

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
    return (
      this.ready &&
      this.outstandingPrompts === 0 &&
      !this.selfTurn &&
      !this.pendingPlan
    );
  }

  get isTurnActive(): boolean {
    return this.outstandingPrompts > 0 || this.selfTurn;
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
      ...this.catalog,
      thoughtLevels: [...(this.acpConfig?.thoughtLevels ?? [])],
      ...(this._permissionMode ? { permissionMode: this._permissionMode } : {}),
      ...(this._contextUsage ? { contextUsage: { ...this._contextUsage } } : {}),
    };
  }

  /** The part of the settings that holds for any new session on this account. */
  get catalog(): AntigravityCatalog {
    return {
      ...(this._model ? { model: this._model } : {}),
      models: [...this._models],
      ...(this.acpConfig?.baseModel ? { baseModel: this.acpConfig.baseModel } : {}),
      modelOptions: buildModelOptions(this.acpConfig?.baseModels ?? [], this._models),
      ...(this.acpConfig?.thoughtLevel ? { thoughtLevel: this.acpConfig.thoughtLevel } : {}),
      // Bypass is the Bridge's own mode, so it is always on offer.
      permissionModes: [...this._permissionModes, BYPASS_MODE],
      authMode: this.authMode,
      ...(this._tier ? { tier: { ...this._tier } } : {}),
      ...(this._agentVersion ? { agentVersion: this._agentVersion } : {}),
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
      // A missing working directory fails the spawn with ENOENT as well.
      if (!existsSync(projectPath)) {
        this.failStart(`Project folder not found: ${projectPath}`);
        return;
      }
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
    const initialized = await this.request("initialize", {
      protocolVersion: ACP_PROTOCOL_VERSION,
      clientInfo: ACP_CLIENT_INFO,
      clientCapabilities: {
        fs: { readTextFile: false, writeTextFile: false },
        terminal: false,
        // Without this, `ask_question` prints its options and ends the turn.
        elicitation: { form: {} },
      },
    });
    const agentInfo = isRecord(initialized.agentInfo) ? initialized.agentInfo : {};
    this._agentVersion = stringOr(agentInfo.version) || undefined;
    const capabilities = isRecord(initialized.agentCapabilities)
      ? initialized.agentCapabilities
      : {};
    const sessionCapabilities = isRecord(capabilities.sessionCapabilities)
      ? capabilities.sessionCapabilities
      : {};
    const additionalDirectories =
      options?.additionalDirectories?.length &&
      isRecord(sessionCapabilities.additionalDirectories)
        ? { additionalDirectories: [...options.additionalDirectories] }
        : {};

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
          {
            sessionId: options.sessionId,
            cwd: projectPath,
            mcpServers: [],
            ...additionalDirectories,
          },
          LOAD_TIMEOUT_MS,
        );
      } finally {
        this.flushAssistant();
        this.replaying = false;
        // Replayed questions and plans were settled in an earlier run.
        this.planArtifact = null;
        this.toolCalls.clear();
      }
      this._sessionId = options.sessionId;
    } else {
      session = await this.request("session/new", {
        cwd: projectPath,
        mcpServers: [],
        ...additionalDirectories,
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
    if (options?.thoughtLevel) {
      await this.setThoughtLevel(options.thoughtLevel).catch(() => {
        // Levels differ per model; keep the one the model starts with.
      });
    }
    // The `agy` CLI starts in auto where the account has it, while ACP
    // sessions start in default; a new session with no mode asked for
    // follows the CLI.
    const startMode =
      options?.permissionMode ??
      (!options?.sessionId && this._permissionModes.includes("auto")
        ? "auto"
        : undefined);
    if (startMode && startMode !== this._permissionMode) {
      await this.setPermissionMode(startMode).catch(() => {
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
      slashCommandDescriptions: { ...this._slashCommandDescriptions },
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
    this.pendingElicitations.clear();
    this.pendingPlan = null;
    this.queuedInputs = [];
    this.outstandingPrompts = 0;
    this.clearSelfTurn();
    const transport = this.transport;
    this.transport = null;
    transport?.stop();
  }

  interrupt(): void {
    if (this.pendingPlan && this.outstandingPrompts === 0) {
      this.settlePlan("Plan review dismissed", "rejected");
      this.setStatus("idle");
      this.emit("input_ready");
      return;
    }
    if (!this._sessionId || !this.isTurnActive) return;
    const selfTurn = this.outstandingPrompts === 0;
    if (!selfTurn) this.cancelRequested = true;
    // ACP requires pending permission requests to be answered as cancelled.
    for (const pending of this.pendingPermissions.values()) {
      this.respond(pending.requestId, { outcome: { outcome: "cancelled" } });
      this.emitToolResult(pending.toolUseId, "Cancelled", "rejected");
      const call = this.toolCalls.get(pending.toolUseId);
      if (call) call.rejected = true;
    }
    this.pendingPermissions.clear();
    for (const pending of this.pendingElicitations.values()) {
      this.respond(pending.requestId, { action: "cancel" });
      this.emitToolResult(pending.toolUseId, "Cancelled", "rejected");
      const call = this.toolCalls.get(pending.toolUseId);
      if (call) call.rejected = true;
    }
    this.pendingElicitations.clear();
    this.notify("session/cancel", { sessionId: this._sessionId });
    // No prompt is open to answer `cancelled`, so the turn ends here.
    if (selfTurn) this.endSelfTurn("interrupted");
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
    // Typing a reply instead of using the plan buttons is feedback on the plan.
    if (this.pendingPlan) this.settlePlan("Plan feedback sent", "rejected");
    this.dispatchPrompt(text, images);
    return true;
  }

  private dispatchPrompt(
    text: string,
    images?: Array<{ base64: string; mimeType: string }>,
  ): void {
    if (!this._sessionId) return;
    // A prompt sent into a turn the agent started steers it and owns its end.
    const steersSelfTurn = this.selfTurn;
    this.clearSelfTurn();
    if (this.outstandingPrompts === 0 && !steersSelfTurn) {
      this.turnUsage = {};
      this.turnStartedAt = Date.now();
      this.turnToolCalls = 0;
      this.turnFileEdits = 0;
      this.planArtifact = null;
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
      add("thoughtTokens");
    }
    const stopReason = stringOr(result?.stopReason) || undefined;
    if (stopReason) this.lastStopReason = stopReason;
    if (this.outstandingPrompts > 0) return;

    this.flushAssistant();
    this.pendingPermissions.clear();
    this.pendingElicitations.clear();
    const sessionId = this._sessionId ?? undefined;
    if (this.contextUsageDirty) this.emitSettings();
    const succeeded =
      !err && this.lastStopReason !== "cancelled" && !this.cancelRequested;
    this.dropSettledToolCalls(succeeded);
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
        ...(this.turnUsage.thoughtTokens != null
          ? { thoughtTokens: this.turnUsage.thoughtTokens }
          : {}),
        ...(this.turnStartedAt > 0
          ? { duration: Date.now() - this.turnStartedAt }
          : {}),
        toolCalls: this.turnToolCalls,
        fileEdits: this.turnFileEdits,
      });
    }
    this.cancelRequested = false;
    const planArtifact = this.planArtifact;
    this.planArtifact = null;
    if (succeeded && planArtifact && this._permissionMode === "plan") {
      void this.requestPlanReview(planArtifact);
      return;
    }
    this.setStatus("idle");
    this.emit("input_ready");
  }

  /**
   * Antigravity writes its plan to a document and waits for the next message.
   * Offer the plan for approval the way Claude and Codex sessions do.
   */
  private async requestPlanReview(artifact: {
    path: string;
    content: string;
  }): Promise<void> {
    // Later edits in the turn change the file, not the first write's content.
    const plan = await readFile(artifact.path, "utf8").catch(() => artifact.content);
    if (this.stopped || this.outstandingPrompts > 0 || !plan.trim()) {
      if (!this.stopped && this.outstandingPrompts === 0) {
        this.setStatus("idle");
        this.emit("input_ready");
      }
      return;
    }
    const toolUseId = `plan_${randomUUID()}`;
    this.pendingPlan = { toolUseId, plan };
    this.setStatus("waiting_approval");
    this.emitMessage({
      type: "permission_request",
      toolUseId,
      toolName: "ExitPlanMode",
      input: { plan },
    });
  }

  private settlePlan(content: string, outcome: "approved" | "rejected"): void {
    const pending = this.pendingPlan;
    if (!pending) return;
    this.pendingPlan = null;
    this.emitToolResult(pending.toolUseId, content, outcome);
  }

  /**
   * Sends text as the user's next message. Used for the one message a plan
   * decision or a denial reason stands for, never for prompts the Bridge
   * makes up on its own.
   */
  private sendAsUser(text: string): void {
    // No `userMessageUuid`: it would read as the id of the message the user
    // typed last. The client id keeps two identical decisions apart.
    this.emitMessage({
      type: "user_input",
      text,
      clientMessageId: `antigravity-${randomUUID()}`,
      timestamp: new Date().toISOString(),
    });
    this.dispatchPrompt(text);
  }

  private approvePlan(): void {
    this.settlePlan("Plan approved", "approved");
    const next = this.modeBeforePlan;
    void this.setPermissionMode(next)
      .catch(() => {
        // Stay in plan mode; the approval message still asks to proceed.
      })
      .then(() => {
        if (!this.stopped) this.sendAsUser(PLAN_APPROVED_PROMPT);
      });
  }

  private rejectPlan(feedback?: string): void {
    this.settlePlan("Plan rejected", "rejected");
    if (feedback?.trim()) {
      this.sendAsUser(feedback.trim());
      return;
    }
    this.setStatus("idle");
    this.emit("input_ready");
  }

  approve(toolUseId?: string): boolean {
    if (this.isPendingPlan(toolUseId)) {
      this.approvePlan();
      return true;
    }
    return this.resolvePermission(toolUseId, "allow_once", "approved");
  }

  /**
   * Allows the request and its repeats for the rest of the session: through
   * Antigravity's own `allow_always` when it lists one, otherwise by
   * remembering the choice here (every file edit, this exact command, or
   * this MCP tool).
   */
  approveAlways(toolUseId?: string): boolean {
    if (this.isPendingPlan(toolUseId)) {
      this.approvePlan();
      return true;
    }
    const pending = this.findPendingPermission(toolUseId);
    if (!pending) return false;
    const always = pending.options.some((o) => o.kind === "allow_always");
    const grant = always ? undefined : pending.sessionGrant;
    const resolved = this.resolvePermission(
      pending.toolUseId,
      always ? "allow_always" : "allow_once",
      always || grant ? "approved_for_session" : "approved",
    );
    if (resolved && grant) {
      if (grant.kind === "edit") this.allowEditsForSession = true;
      else if (grant.kind === "mcp") this.allowedMcpTools.add(grant.tool);
      else this.allowedCommands.add(grant.command);
      // Requests of the same kind that are already waiting are covered too.
      for (const other of [...this.pendingPermissions.values()]) {
        if (this.isGrantedForSession(other.sessionGrant)) {
          this.resolvePermission(other.toolUseId, "allow_once", "approved_for_session");
        }
      }
    }
    return resolved;
  }

  private isGrantedForSession(grant: PendingPermission["sessionGrant"]): boolean {
    if (!grant) return false;
    if (grant.kind === "edit") return this.allowEditsForSession;
    if (grant.kind === "mcp") return this.allowedMcpTools.has(grant.tool);
    return this.allowedCommands.has(grant.command);
  }

  reject(toolUseId?: string, message?: string): boolean {
    if (this.isPendingPlan(toolUseId)) {
      this.rejectPlan(message);
      return true;
    }
    const elicitation = this.findPendingElicitation(toolUseId);
    if (elicitation && (toolUseId || this.pendingPermissions.size === 0)) {
      this.pendingElicitations.delete(elicitation.toolUseId);
      this.respond(elicitation.requestId, { action: "decline" });
      const call = this.toolCalls.get(elicitation.toolUseId);
      if (call) call.rejected = true;
      this.emitToolResult(elicitation.toolUseId, "Rejected", "rejected");
      this.resumeRunningIfSettled();
      this.armSelfTurnEnd();
      return true;
    }
    if (!this.resolvePermission(toolUseId, "reject_once", "rejected")) return false;
    // ACP carries no reason with a denial and the turn ends without a word,
    // so the reason the user typed goes in as their next message.
    if (message?.trim()) this.sendAsUser(message.trim());
    return true;
  }

  /** Answers an `ask_question` form (ACP elicitation). */
  answer(toolUseId: string, result: string): boolean {
    const pending = this.findPendingElicitation(toolUseId);
    if (!pending) return false;
    this.pendingElicitations.delete(pending.toolUseId);
    this.respond(pending.requestId, {
      action: "accept",
      content: elicitationContentFromAnswer(pending.fields, result),
    });
    const call = this.toolCalls.get(pending.toolUseId);
    if (call) call.rejected = true;
    this.emitToolResult(pending.toolUseId, result, "answered");
    this.resumeRunningIfSettled();
    return true;
  }

  private isPendingPlan(toolUseId?: string): boolean {
    if (!this.pendingPlan) return false;
    return toolUseId
      ? toolUseId === this.pendingPlan.toolUseId
      : this.pendingPermissions.size === 0 && this.pendingElicitations.size === 0;
  }

  private findPendingElicitation(toolUseId?: string): PendingElicitation | undefined {
    if (toolUseId) return this.pendingElicitations.get(toolUseId);
    const first = this.pendingElicitations.values().next();
    return first.done ? undefined : first.value;
  }

  private resumeRunningIfSettled(): void {
    if (
      this.pendingPermissions.size === 0 &&
      this.pendingElicitations.size === 0 &&
      this.isTurnActive
    ) {
      this.setStatus("running");
    }
  }

  /**
   * Finished calls are never updated again; drop them so a long session does
   * not keep every call it ever made. Calls still open after a turn that
   * ended normally run in the background (a timer, a long command) and
   * report their result later.
   */
  private dropSettledToolCalls(keepOpen: boolean): void {
    if (!keepOpen) {
      this.toolCalls.clear();
      return;
    }
    for (const [id, call] of this.toolCalls) {
      if (call.finished || call.rejected) this.toolCalls.delete(id);
    }
  }

  // ---- turns the agent starts on its own -----------------------------------

  /**
   * Called for everything the agent sends that belongs to a turn. Outside a
   * prompt it means the agent woke up by itself: show the session as running
   * again instead of leaving it "done" while tools run.
   */
  private noteAgentActivity(): void {
    if (this.selfTurnTimer) {
      clearTimeout(this.selfTurnTimer);
      this.selfTurnTimer = null;
    }
    if (
      this.selfTurn ||
      this.replaying ||
      this.stopped ||
      !this.ready ||
      this.outstandingPrompts > 0
    ) {
      return;
    }
    this.selfTurn = true;
    this.turnUsage = {};
    this.turnStartedAt = Date.now();
    this.turnToolCalls = 0;
    this.turnFileEdits = 0;
    this.planArtifact = null;
    this.lastResultText = "";
    this.lastStopReason = undefined;
    if (this.pendingPlan) this.settlePlan("Plan review dismissed", "rejected");
    this.setStatus("running");
  }

  /**
   * Antigravity reports context usage after each model call. A tool call
   * follows within milliseconds when the turn goes on, so a report followed
   * by silence is the end of a turn nothing else marks. A denied call ends
   * the turn the same way, without a report.
   */
  private armSelfTurnEnd(): void {
    if (!this.selfTurn || this.outstandingPrompts > 0) return;
    if (this.selfTurnTimer) clearTimeout(this.selfTurnTimer);
    this.selfTurnTimer = setTimeout(() => {
      this.selfTurnTimer = null;
      if (
        this.pendingPermissions.size > 0 ||
        this.pendingElicitations.size > 0
      ) {
        return;
      }
      this.endSelfTurn("success");
    }, SELF_TURN_SETTLE_MS);
  }

  private clearSelfTurn(): void {
    this.selfTurn = false;
    if (this.selfTurnTimer) {
      clearTimeout(this.selfTurnTimer);
      this.selfTurnTimer = null;
    }
  }

  private endSelfTurn(subtype: "success" | "interrupted"): void {
    if (!this.selfTurn || this.stopped) return;
    this.clearSelfTurn();
    this.flushAssistant();
    this.pendingPermissions.clear();
    this.pendingElicitations.clear();
    this.dropSettledToolCalls(subtype === "success");
    const sessionId = this._sessionId ?? undefined;
    if (this.contextUsageDirty) this.emitSettings();
    if (subtype === "interrupted") {
      this.emitMessage({ type: "result", subtype: "interrupted", sessionId });
    } else {
      // No prompt answered, so there is no token usage to report.
      this.emitMessage({
        type: "result",
        subtype: "success",
        sessionId,
        ...(this.lastResultText ? { result: this.lastResultText } : {}),
        ...(this.turnStartedAt > 0
          ? { duration: Date.now() - this.turnStartedAt }
          : {}),
        toolCalls: this.turnToolCalls,
        fileEdits: this.turnFileEdits,
      });
    }
    this.planArtifact = null;
    this.setStatus("idle");
    this.emit("input_ready");
  }

  getPendingPermissions(): Array<{
    toolUseId: string;
    toolName: string;
    input: Record<string, unknown>;
  }> {
    return [
      ...[...this.pendingPermissions.values()].map((pending) => ({
        toolUseId: pending.toolUseId,
        toolName: pending.toolName,
        input: { ...pending.input },
      })),
      ...[...this.pendingElicitations.values()].map((pending) => ({
        toolUseId: pending.toolUseId,
        toolName: "AskUserQuestion",
        input: { ...pending.input },
      })),
      ...(this.pendingPlan
        ? [
            {
              toolUseId: this.pendingPlan.toolUseId,
              toolName: "ExitPlanMode",
              input: { plan: this.pendingPlan.plan },
            },
          ]
        : []),
    ];
  }

  getPendingPermission(toolUseId?: string):
    | { toolUseId: string; toolName: string; input: Record<string, unknown> }
    | undefined {
    const all = this.getPendingPermissions();
    return toolUseId ? all.find((p) => p.toolUseId === toolUseId) : all[0];
  }

  async setPermissionMode(mode: PermissionMode): Promise<void> {
    if (!this._sessionId) throw new Error("Antigravity session is not ready");
    const bypass = mode === BYPASS_MODE;
    // Bypass keeps the ACP session in `default` and answers every request
    // itself, so it works on accounts that have no `auto` mode.
    const modeId = bypass ? "default" : acpModeFromPermissionMode(mode);
    if (!modeId) {
      throw new Error(`Antigravity does not support the ${mode} mode`);
    }
    const acpMode = this.bypass ? "default" : this._permissionMode;
    if (permissionModeFromAcpMode(modeId) !== acpMode) {
      // Set first: `current_mode_update` arrives before the answer and must
      // not read as the agent leaving bypass on its own.
      this.bypass = bypass;
      try {
        await this.request("session/set_mode", {
          sessionId: this._sessionId,
          modeId,
        });
      } catch (err) {
        this.bypass = this._permissionMode === BYPASS_MODE;
        throw err;
      }
    }
    this.bypass = bypass;
    this.applyPermissionMode(mode);
    if (bypass) this.allowPendingPermissions();
  }

  private applyPermissionMode(mode: PermissionMode): void {
    if (mode !== "plan") this.modeBeforePlan = mode;
    if (mode === this._permissionMode) return;
    this._permissionMode = mode;
    if (this.ready) this.emitPermissionMode();
  }

  /** Switches to an ACP model id or, failing that, to a model family. */
  async setModel(modelId: string): Promise<void> {
    if (!this._sessionId) throw new Error("Antigravity session is not ready");
    const isFamily =
      !this._models.some((model) => model.id === modelId) &&
      (this.acpConfig?.baseModels.some((model) => model.id === modelId) ?? false);
    if (isFamily) {
      await this.setConfigOption("model", modelId);
    } else {
      await this.request("session/set_model", {
        sessionId: this._sessionId,
        modelId,
      });
      this._model = modelId;
      this.syncConfigFromModel(modelId);
    }
    if (this.ready) this.emitSettings();
  }

  /**
   * The `config_option_update` for a model switch arrives after the answer,
   * so work out the family and level here for whoever asks in between.
   */
  private syncConfigFromModel(modelId: string): void {
    const config = this.acpConfig;
    if (!config) return;
    const options = buildModelOptions(config.baseModels, this._models);
    const family =
      options.find((option) =>
        option.thoughtLevels.some((level) => `${option.id}-${level}` === modelId),
      ) ?? options.find((option) => option.id === modelId);
    if (!family) return;
    const level =
      family.id === modelId ? undefined : modelId.slice(family.id.length + 1);
    this.acpConfig = {
      ...config,
      baseModel: family.id,
      ...(level ? { thoughtLevel: level } : {}),
      thoughtLevels: family.thoughtLevels,
    };
    if (!level) delete this.acpConfig.thoughtLevel;
  }

  async setThoughtLevel(level: string): Promise<void> {
    if (!this._sessionId) throw new Error("Antigravity session is not ready");
    if (level === this.acpConfig?.thoughtLevel) return;
    if (!this.acpConfig?.thoughtLevels.includes(level)) {
      throw new Error(`The current model has no ${level} thinking level`);
    }
    await this.setConfigOption("thought_level", level);
    if (this.ready) this.emitSettings();
  }

  private async setConfigOption(configId: string, value: string): Promise<void> {
    const result = await this.request("session/set_config_option", {
      sessionId: this._sessionId,
      configId,
      value,
    });
    this.applyConfigOptions(result.configOptions);
  }

  /** Returns true when the model or thinking level changed. */
  private applyConfigOptions(configOptions: unknown): boolean {
    const config = parseAcpConfigOptions(configOptions);
    if (!config) return false;
    const before = `${this._model}|${this.acpConfig?.baseModel}|${this.acpConfig?.thoughtLevel}|${this.acpConfig?.thoughtLevels.join(",")}`;
    this.acpConfig = config;
    // The ACP model id is the family plus the level, when the family has levels.
    const candidates = [
      ...(config.baseModel && config.thoughtLevel
        ? [`${config.baseModel}-${config.thoughtLevel}`]
        : []),
      ...(config.baseModel ? [config.baseModel] : []),
    ];
    const model = candidates.find((id) => this._models.some((m) => m.id === id));
    if (model) this._model = model;
    return (
      before !==
      `${this._model}|${config.baseModel}|${config.thoughtLevel}|${config.thoughtLevels.join(",")}`
    );
  }

  private allowPendingPermissions(): void {
    for (const pending of [...this.pendingPermissions.values()]) {
      this.resolvePermission(pending.toolUseId, "allow_once", "approved");
    }
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
      this.noteAgentActivity();
      this.handlePermissionRequest(id, params);
      return;
    }
    if (method === "elicitation/create") {
      this.noteAgentActivity();
      this.handleElicitation(id, params);
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
        this.noteAgentActivity();
        this.textBuffer += text;
        if (!this.replaying) this.emitMessage({ type: "stream_delta", text });
        return;
      }
      case "agent_thought_chunk": {
        const text = isRecord(update.content) ? stringOr(update.content.text) : "";
        if (!text) return;
        this.noteAgentActivity();
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
        if (!mode) return;
        // Bypass runs on the ACP `default` mode.
        if (this.bypass && mode === "default") return;
        this.bypass = false;
        this.applyPermissionMode(mode);
        return;
      }
      case "config_option_update": {
        if (this.applyConfigOptions(update.configOptions) && this.ready) {
          this.emitSettings();
        }
        return;
      }
      case "usage_update": {
        this.armSelfTurnEnd();
        const used = numberOr(update.used);
        const size = numberOr(update.size);
        if (used === undefined || size === undefined || size <= 0) return;
        if (this._contextUsage?.used === used && this._contextUsage.size === size) {
          return;
        }
        this._contextUsage = { used, size };
        // Reported once per turn, with its result: this arrives after every
        // model call and each report lands in the session history.
        this.contextUsageDirty = true;
        return;
      }
      case "available_commands_update": {
        const commands = Array.isArray(update.availableCommands)
          ? update.availableCommands
          : [];
        this._slashCommands = commands
          .map((command) => (isRecord(command) ? stringOr(command.name) : ""))
          .filter((name) => name.length > 0);
        this._slashCommandDescriptions = Object.fromEntries(
          commands
            .filter(isRecord)
            .map((command) => [
              stringOr(command.name),
              stringOr(command.description).trim(),
            ])
            .filter(([name, description]) => name.length > 0 && description.length > 0),
        );
        if (this.ready) {
          this.emitMessage({
            type: "system",
            subtype: "supported_commands",
            provider: "antigravity",
            slashCommands: [...this._slashCommands],
            slashCommandDescriptions: { ...this._slashCommandDescriptions },
          });
        }
        return;
      }
      default:
        // Kinds the client has nothing to render for.
        return;
    }
  }

  private handleToolCall(update: Record<string, unknown>, isNew: boolean): void {
    const toolUseId = stringOr(update.toolCallId);
    if (!toolUseId) return;
    let call = this.toolCalls.get(toolUseId);
    // A background call (a timer, a long command) finishing is not a turn:
    // only what the agent does next is.
    const closing = ["completed", "failed"].includes(stringOr(update.status));
    // The result of a call that was dropped with its cancelled turn.
    if (!call && closing && !this.replaying && !this.isTurnActive) return;
    if (!closing) this.noteAgentActivity();
    // Antigravity says nothing more after a denial, not even a usage report.
    else if (call?.rejected) this.armSelfTurnEnd();
    if (!call) {
      this.flushAssistant();
      const kind = stringOr(update.kind, "other");
      const title = stringOr(update.title);
      const rawInput = isRecord(update.rawInput) ? update.rawInput : {};
      const known = describeAcpTool(update);
      const mcp = mcpToolFromAcp(update);
      let toolName: string;
      let input: Record<string, unknown>;
      if (mcp) {
        ({ toolName, input } = mcp);
      } else if (kind === "execute") {
        toolName = "Bash";
        const summary = stringOr(rawInput.toolSummary);
        input = {
          command: stringOr(rawInput.CommandLine, title),
          ...(summary ? { description: summary } : {}),
        };
      } else if (kind === "edit") {
        toolName = "FileChange";
        const changes = fileChangesFromContent(update.content, this.cwd);
        input = {
          changes: changes.length > 0 ? changes : this.changesFromLocations(update),
        };
        if (!this.replaying) this.turnFileEdits++;
      } else if (known) {
        ({ toolName, input } = known);
      } else {
        toolName = stringOr(update.name) || title || kind;
        input = { ...rawInput };
      }
      if (!this.replaying) this.turnToolCalls++;
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
    if (status === "completed" && call.kind === "edit" && !this.replaying) {
      this.notePlanArtifact(update);
    }
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

  /** Remembers the plan document a plan-mode turn wrote, for review at its end. */
  private notePlanArtifact(update: Record<string, unknown>): void {
    const rawInput = isRecord(update.rawInput) ? update.rawInput : {};
    const path = firstString(rawInput, ["Path", "TargetFile"]) || firstLocation(update);
    if (!isArtifactPath(path, this.cwd)) return;
    // The plan is the document Antigravity wants reviewed; its file name
    // varies (`implementation_plan.md`, `plan_add_subtract.md`, ...).
    const metadata = isRecord(rawInput.ArtifactMetadata) ? rawInput.ArtifactMetadata : {};
    if (metadata.RequestFeedback !== true && basename(path) !== PLAN_ARTIFACT_NAME) {
      return;
    }
    this.planArtifact = { path, content: stringOr(rawInput.Content) };
  }

  private handleElicitation(
    requestId: number | string,
    params: Record<string, unknown>,
  ): void {
    const fields = elicitationFieldsFromSchema(params.requestedSchema);
    if (params.mode !== "form" || fields.length === 0) {
      this.respond(requestId, { action: "decline" });
      return;
    }
    const toolUseId = stringOr(params.toolCallId) || `elicitation-${requestId}`;
    const message = stringOr(params.message).trim();
    const input: Record<string, unknown> = {
      ...(message ? { message } : {}),
      questions: fields.map((field) => ({
        id: field.id,
        question: field.question,
        header: "",
        options: field.options.map((option) => ({
          label: option.label,
          description: "",
        })),
        multiSelect: field.type === "multi",
        // Free text is possible unless the schema offers options only.
        isOther: field.otherId !== undefined || field.options.length === 0,
      })),
    };
    this.pendingElicitations.set(toolUseId, { requestId, toolUseId, input, fields });
    this.setStatus("waiting_approval");
    this.emitMessage({
      type: "permission_request",
      toolUseId,
      toolName: "AskUserQuestion",
      input,
    });
  }

  private changesFromLocations(update: Record<string, unknown>): FileChange[] {
    const locations = Array.isArray(update.locations) ? update.locations : [];
    return locations
      .map((location) => (isRecord(location) ? stringOr(location.path) : ""))
      .filter((path) => path.length > 0)
      .map((path) => ({
        path: isArtifactPath(path, this.cwd) ? basename(path) : path,
        kind: "update" as const,
        diff: "",
      }));
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

    if (this.bypass) {
      const allow =
        options.find((o) => o.kind === "allow_once") ??
        options.find((o) => o.kind.startsWith("allow"));
      if (allow) {
        this.respond(requestId, {
          outcome: { outcome: "selected", optionId: allow.optionId },
        });
        return;
      }
    }

    const kind = stringOr(toolCall.kind, this.toolCalls.get(toolUseId)?.kind ?? "other");
    const rawInput = isRecord(toolCall.rawInput) ? toolCall.rawInput : {};
    const allowOnce = options.find((o) => o.kind === "allow_once");
    const command = stringOr(rawInput.CommandLine, stringOr(toolCall.title));
    const mcp = mcpToolFromAcp(toolCall);
    // Edits, commands and MCP tools can be allowed for the session by the Bridge.
    const sessionGrant: PendingPermission["sessionGrant"] = !allowOnce
      ? undefined
      : mcp
        ? { kind: "mcp", tool: mcp.key }
        : kind === "edit"
          ? { kind: "edit" }
          : kind === "execute" && command
            ? { kind: "execute", command }
            : undefined;
    if (allowOnce && this.isGrantedForSession(sessionGrant)) {
      this.respond(requestId, {
        outcome: { outcome: "selected", optionId: allowOnce.optionId },
      });
      return;
    }
    const availableDecisions = [
      ...(allowOnce ? ["accept"] : []),
      ...(options.some((o) => o.kind === "allow_always") || sessionGrant
        ? ["acceptForSession"]
        : []),
      ...(options.some((o) => o.kind.startsWith("reject")) ? ["decline"] : []),
    ];
    let toolName: string;
    let input: Record<string, unknown>;
    if (mcp) {
      toolName = mcp.toolName;
      input = { ...mcp.input, availableDecisions };
    } else if (kind === "execute") {
      toolName = "Bash";
      input = { command, availableDecisions };
    } else if (kind === "edit") {
      toolName = "FileChange";
      const changes = fileChangesFromContent(toolCall.content, this.cwd);
      input = {
        changes: changes.length > 0 ? changes : this.changesFromLocations(toolCall),
        availableDecisions,
      };
    } else {
      const known = describeAcpTool(toolCall);
      toolName =
        known?.toolName ||
        this.toolCalls.get(toolUseId)?.toolName ||
        stringOr(toolCall.name) ||
        stringOr(toolCall.title) ||
        kind;
      input = { ...(known?.input ?? rawInput), availableDecisions };
    }

    this.pendingPermissions.set(toolUseId, {
      requestId,
      toolUseId,
      toolName,
      input,
      options,
      ...(sessionGrant ? { sessionGrant } : {}),
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
      pending.options.find((o) =>
        o.kind.startsWith(outcome === "rejected" ? "reject" : "allow"),
      );
    // Never report an approval the agent was not told about.
    if (!option && outcome !== "rejected") return false;
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
    this.resumeRunningIfSettled();
    if (outcome === "rejected") this.armSelfTurnEnd();
    return true;
  }

  private applySessionState(session: Record<string, unknown>): void {
    const state = parseAcpSessionState(session);
    this._models = state.models;
    this._model = state.model;
    this._permissionModes = state.permissionModes;
    this._permissionMode = state.permissionMode;
    if (state.permissionMode && state.permissionMode !== "plan") {
      this.modeBeforePlan = state.permissionMode;
    }
    this.acpConfig = state.config;
    this._tier = state.tier;
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
    this.contextUsageDirty = false;
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
    permissionOutcome: "approved" | "approved_for_session" | "rejected" | "answered",
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
    this.pendingElicitations.clear();
    this.pendingPlan = null;
    this.queuedInputs = [];
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error("Antigravity exited"));
    }
    this.pendingRequests.clear();
    this.stopped = true;
    this.ready = false;
    const turnWasActive = this.isTurnActive;
    this.clearSelfTurn();
    if (!wasStopped && turnWasActive) {
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
