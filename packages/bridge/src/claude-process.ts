import { spawn, execSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { EventEmitter } from "node:events";
import {
  parseClaudeEvent,
  claudeEventToServerMessage,
  normalizeToolResultContent,
  type ServerMessage,
  type ProcessStatus,
  type ClaudeEvent,
  type AssistantMessageEvent,
  type AssistantToolUseContent,
  type PermissionMode,
} from "./parser.js";

// Tools that are auto-approved in acceptEdits mode
const ACCEPT_EDITS_AUTO_APPROVE = new Set([
  "Read", "Glob", "Grep",
  "Edit", "Write", "NotebookEdit",
  "TaskCreate", "TaskUpdate", "TaskList", "TaskGet",
  "EnterPlanMode", "AskUserQuestion",
  "WebSearch", "WebFetch",
  "Task", "Skill",
]);

/**
 * Parse a permission rule in ToolName(ruleContent) format.
 * Matches the CLI's internal pzT() function: /^([^(]+)\(([^)]+)\)$/
 */
function parseRule(rule: string): { toolName: string; ruleContent?: string } {
  const match = rule.match(/^([^(]+)\(([^)]+)\)$/);
  if (!match || !match[1] || !match[2]) return { toolName: rule };
  return { toolName: match[1], ruleContent: match[2] };
}

/**
 * Check if a tool invocation matches any session allow rule.
 */
function matchesSessionRule(
  toolName: string,
  input: Record<string, unknown>,
  rules: Set<string>,
): boolean {
  for (const rule of rules) {
    const parsed = parseRule(rule);
    if (parsed.toolName !== toolName) continue;

    // No ruleContent → matches any invocation of this tool
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
function buildSessionRule(toolName: string, input: Record<string, unknown>): string {
  if (toolName === "Bash" && typeof input.command === "string") {
    const firstWord = (input.command as string).trim().split(/\s+/)[0] ?? "";
    if (firstWord) return `${toolName}(${firstWord}:*)`;
  }
  return toolName;
}

/**
 * Determine whether a tool needs user approval given the current permission mode.
 */
function toolNeedsApproval(toolName: string, mode: PermissionMode | undefined): boolean {
  if (!mode) return true; // default: ask for everything

  switch (mode) {
    case "bypassPermissions":
    case "dontAsk":
      return false; // auto-approve everything

    case "acceptEdits":
      // ExitPlanMode always needs approval (plan review)
      if (toolName === "ExitPlanMode") return true;
      // Known safe tools are auto-approved
      if (ACCEPT_EDITS_AUTO_APPROVE.has(toolName)) return false;
      // MCP tools and unknown tools need approval
      return true;

    case "default":
    case "plan":
    case "delegate":
    default:
      return true; // ask for everything
  }
}

export interface StartOptions {
  sessionId?: string;
  continueMode?: boolean;
  permissionMode?: PermissionMode;
}

export interface ClaudeProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
  permission_request: [PermissionRequest];
}

export interface PermissionRequest {
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
  resolve: (decision: PermissionDecision) => void;
}

export type PermissionDecision =
  | { behavior: "allow"; updatedInput?: Record<string, unknown> }
  | { behavior: "deny"; message: string };

export class ClaudeProcess extends EventEmitter<ClaudeProcessEvents> {
  private process: ChildProcess | null = null;
  private _status: ProcessStatus = "idle";
  private stdoutBuffer = "";
  private stderrBuffer = "";
  private _sessionId: string | null = null;
  private pendingPermissions = new Map<string, PermissionRequest>();
  private _permissionMode: PermissionMode | undefined;
  private sessionAllowRules = new Set<string>();

  get status(): ProcessStatus {
    return this._status;
  }

  get sessionId(): string | null {
    return this._sessionId;
  }

  start(projectPath: string, options?: StartOptions): void {
    if (this.process) {
      this.stop();
    }

    if (!existsSync(projectPath)) {
      mkdirSync(projectPath, { recursive: true });
    }

    let claudePath = "claude";
    try {
      claudePath = execSync("which claude", { encoding: "utf-8" }).trim();
    } catch {
      console.warn("[claude-process] Could not resolve claude path, using 'claude'");
    }

    const args = [
      "-p",
      "--output-format",
      "stream-json",
      "--input-format",
      "stream-json",
      "--verbose",
      "--include-partial-messages",
    ];

    // Permission mode
    if (options?.permissionMode) {
      args.push("--permission-mode", options.permissionMode);
    }

    // Session resume
    if (options?.sessionId) {
      args.push("--resume", options.sessionId);
    } else if (options?.continueMode) {
      args.push("--continue");
    }

    console.log(`[claude-process] Starting: ${claudePath} ${args.join(" ")} (cwd: ${projectPath})`);

    this.process = spawn(claudePath, args, {
      stdio: ["pipe", "pipe", "pipe"],
      cwd: projectPath,
      env: { ...process.env },
    });

    this.setStatus("running");
    this.stdoutBuffer = "";
    this.stderrBuffer = "";
    this._sessionId = null;
    this.pendingPermissions.clear();
    this._permissionMode = options?.permissionMode;
    this.sessionAllowRules.clear();

    const currentProcess = this.process;

    currentProcess.stdout?.on("data", (chunk: Buffer) => {
      if (this.process !== currentProcess) return;
      this.handleStdout(chunk.toString());
    });

    currentProcess.stderr?.on("data", (chunk: Buffer) => {
      if (this.process !== currentProcess) return;
      const text = chunk.toString();
      // Log non-empty stderr for debugging
      const trimmed = text.trim();
      if (trimmed) {
        console.error(`[claude-process] stderr: ${trimmed.slice(0, 500)}`);
      }
    });

    currentProcess.on("exit", (code) => {
      console.log(`[claude-process] Process exited with code ${code}`);
      if (this.process === currentProcess) {
        this.process = null;
        this.setStatus("idle");
        this.emit("exit", code);
      }
    });

    currentProcess.on("error", (err) => {
      console.error(`[claude-process] Process error:`, err.message);
      if (this.process === currentProcess) {
        this.emitMessage({ type: "error", message: `Process error: ${err.message}` });
        this.process = null;
        this.setStatus("idle");
      }
    });
  }

  stop(): void {
    if (this.process) {
      console.log("[claude-process] Stopping process");
      this.process.kill("SIGTERM");
      this.process = null;
      this.setStatus("idle");
      this.pendingPermissions.clear();
    }
  }

  /**
   * Interrupt the current Claude generation by sending SIGINT.
   * This is the equivalent of pressing Escape/Ctrl+C in the CLI.
   * Claude will stop the current turn and wait for new user input.
   */
  interrupt(): void {
    if (this.process) {
      console.log("[claude-process] Sending SIGINT to interrupt");
      this.process.kill("SIGINT");
      this.pendingPermissions.clear();
    }
  }

  writeStdin(text: string): void {
    if (!this.process?.stdin?.writable) {
      console.error("[claude-process] Cannot write: stdin not writable");
      return;
    }
    this.process.stdin.write(text);
  }

  sendInput(text: string): void {
    const msg = JSON.stringify({
      type: "user",
      message: {
        role: "user",
        content: [{ type: "text", text }],
      },
    });
    this.writeStdin(msg + "\n");
  }

  /**
   * Send a tool_result back to Claude (for AskUserQuestion responses etc.)
   */
  sendToolResult(toolUseId: string, result: string): void {
    const msg = JSON.stringify({
      type: "user",
      message: {
        role: "user",
        content: [{ type: "tool_result", tool_use_id: toolUseId, content: result }],
      },
    });
    this.writeStdin(msg + "\n");
  }

  /**
   * Approve a pending permission request.
   * In acceptEdits mode this is a no-op on the CLI side (tool runs automatically),
   * but we still clear the pendingPermission tracking.
   */
  approve(toolUseId?: string): void {
    const resolved = this.resolvePendingPermission(toolUseId, { behavior: "allow" });
    if (resolved && this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  /**
   * Approve a pending permission request and add a session-scoped allow rule
   * so the same tool+command pattern is auto-approved for the rest of the session.
   */
  approveAlways(toolUseId?: string): void {
    const id = toolUseId ?? this.firstPendingId();
    const pending = id ? this.pendingPermissions.get(id) : undefined;
    if (pending) {
      const rule = buildSessionRule(pending.toolName, pending.input);
      this.sessionAllowRules.add(rule);
      console.log(`[claude-process] Added session allow rule: ${rule}`);
    }
    const resolved = this.resolvePendingPermission(toolUseId, { behavior: "allow" });
    if (resolved && this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  /**
   * Reject a pending permission request.
   * Sends a tool_result with the rejection message to abort the tool.
   */
  reject(toolUseId?: string, message?: string): void {
    const id = toolUseId ?? this.firstPendingId();
    const rejectMsg = message ?? "User rejected this action";
    const resolved = this.resolvePendingPermission(toolUseId, {
      behavior: "deny",
      message: rejectMsg,
    });
    // Send tool_result to CLI so it knows the tool was rejected
    if (resolved && id) {
      this.sendToolResult(id, `User rejected: ${rejectMsg}`);
    }
    if (this.pendingPermissions.size === 0) {
      this.setStatus("running");
    }
  }

  private firstPendingId(): string | undefined {
    const first = this.pendingPermissions.values().next();
    return first.done ? undefined : first.value.toolUseId;
  }

  /**
   * Resolve a pending permission. Returns true if a permission was found and resolved.
   */
  private resolvePendingPermission(toolUseId: string | undefined, decision: PermissionDecision): boolean {
    if (toolUseId) {
      const pending = this.pendingPermissions.get(toolUseId);
      if (pending) {
        pending.resolve(decision);
        this.pendingPermissions.delete(toolUseId);
        return true;
      }
    }
    // If no specific ID, resolve the first pending request
    const first = this.pendingPermissions.values().next();
    if (!first.done) {
      first.value.resolve(decision);
      this.pendingPermissions.delete(first.value.toolUseId);
      return true;
    }
    const action = decision.behavior === "allow" ? "approve" : "reject";
    console.log(`[claude-process] ${action}() called but no pending permission requests`);
    return false;
  }

  get isRunning(): boolean {
    return this.process !== null;
  }

  private handleStdout(data: string): void {
    this.stdoutBuffer += data;

    const lines = this.stdoutBuffer.split("\n");
    this.stdoutBuffer = lines.pop() ?? "";

    for (const line of lines) {
      this.processLine(line);
    }
  }

  private processLine(line: string): void {
    const event = parseClaudeEvent(line);
    if (!event) return;

    // Capture session_id from system/init and result events
    if (event.type === "system" && event.subtype === "init") {
      this._sessionId = event.session_id;
    } else if (event.type === "result" && "session_id" in event) {
      this._sessionId = event.session_id;
    }

    this.updateStatusFromEvent(event);

    const serverMsg = claudeEventToServerMessage(event);
    if (serverMsg) {
      this.emitMessage(serverMsg);
    }

    // After assistant message, check if any tool_use blocks need approval
    if (event.type === "assistant") {
      this.checkToolApprovals(event);
    }

    // Handle multiple tool results in a single user event
    if (event.type === "user") {
      const toolResults = event.message.content.filter(
        (c) => c.type === "tool_result"
      );
      for (let i = 1; i < toolResults.length; i++) {
        const tr = toolResults[i];
        if (tr.type === "tool_result") {
          this.emitMessage({
            type: "tool_result",
            toolUseId: tr.tool_use_id,
            content: normalizeToolResultContent(tr.content),
          });
        }
      }
      // Clear pending permissions for tool_results that came back from CLI
      // (tool was auto-executed by CLI, so no approval needed)
      for (const tr of toolResults) {
        if (tr.type === "tool_result") {
          this.pendingPermissions.delete(tr.tool_use_id);
        }
      }
      if (this.pendingPermissions.size === 0 && this._status === "waiting_approval") {
        this.setStatus("running");
      }
    }
  }

  /**
   * Check tool_use blocks in an assistant message and emit permission_request
   * for tools that need approval based on the current permission mode.
   */
  private checkToolApprovals(event: AssistantMessageEvent): void {
    for (const content of event.message.content) {
      if (content.type !== "tool_use") continue;
      const toolUse = content as AssistantToolUseContent;

      // AskUserQuestion is handled by a separate UI flow — skip
      if (toolUse.name === "AskUserQuestion") continue;

      if (!toolNeedsApproval(toolUse.name, this._permissionMode)) continue;

      // Check session allow rules
      if (matchesSessionRule(toolUse.name, toolUse.input, this.sessionAllowRules)) continue;

      // Already pending (e.g. from a duplicate event)
      if (this.pendingPermissions.has(toolUse.id)) continue;

      const permReq: PermissionRequest = {
        toolUseId: toolUse.id,
        toolName: toolUse.name,
        input: toolUse.input,
        resolve: () => {}, // placeholder — replaced by caller
      };
      this.pendingPermissions.set(toolUse.id, permReq);

      this.emitMessage({
        type: "permission_request",
        toolUseId: toolUse.id,
        toolName: toolUse.name,
        input: toolUse.input,
      });

      this.setStatus("waiting_approval");
    }
  }

  private updateStatusFromEvent(event: ClaudeEvent): void {
    switch (event.type) {
      case "system":
        // After init, Claude CLI is idle and waiting for user input
        if (event.subtype === "init") {
          this.setStatus("idle");
        }
        break;
      case "assistant": {
        // Don't override waiting_approval if we have pending permissions
        if (this.pendingPermissions.size > 0) break;
        this.setStatus("running");
        break;
      }
      case "user":
        // Don't override waiting_approval if we have pending permissions
        if (this.pendingPermissions.size > 0) break;
        this.setStatus("running");
        break;
      case "result":
        // Result always clears pending state
        this.pendingPermissions.clear();
        this.setStatus("idle");
        break;
      // stream_event doesn't change status
    }
  }

  private setStatus(status: ProcessStatus): void {
    if (this._status !== status) {
      this._status = status;
      this.emit("status", status);
      this.emitMessage({ type: "status", status });
    }
  }

  private emitMessage(msg: ServerMessage): void {
    this.emit("message", msg);
  }
}
