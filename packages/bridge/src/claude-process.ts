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
   */
  approve(toolUseId?: string): void {
    this.resolvePendingPermission(toolUseId, { behavior: "allow" });
  }

  /**
   * Reject a pending permission request.
   */
  reject(toolUseId?: string, message?: string): void {
    this.resolvePendingPermission(toolUseId, {
      behavior: "deny",
      message: message ?? "User rejected this action",
    });
  }

  private resolvePendingPermission(toolUseId: string | undefined, decision: PermissionDecision): void {
    if (toolUseId) {
      const pending = this.pendingPermissions.get(toolUseId);
      if (pending) {
        pending.resolve(decision);
        this.pendingPermissions.delete(toolUseId);
        return;
      }
    }
    // If no specific ID, resolve the first pending request
    const first = this.pendingPermissions.values().next();
    if (!first.done) {
      first.value.resolve(decision);
      this.pendingPermissions.delete(first.value.toolUseId);
    } else {
      const action = decision.behavior === "allow" ? "approve" : "reject";
      console.log(`[claude-process] ${action}() called but no pending permission requests`);
    }
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
        // In stream-json mode, tool execution is handled by the CLI internally.
        // Don't set waiting_approval here — only set it when an explicit
        // permission_request is emitted (e.g. from stderr MCP JSON-RPC).
        this.setStatus("running");
        break;
      }
      case "user":
        this.setStatus("running");
        break;
      case "result":
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
