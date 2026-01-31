import { spawn, execSync, type ChildProcess } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { EventEmitter } from "node:events";
import {
  parseClaudeEvent,
  claudeEventToServerMessage,
  type ServerMessage,
  type ProcessStatus,
  type ClaudeEvent,
  type AssistantMessageEvent,
  type AssistantToolUseContent,
} from "./parser.js";

export interface ClaudeProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
}

export class ClaudeProcess extends EventEmitter<ClaudeProcessEvents> {
  private process: ChildProcess | null = null;
  private _status: ProcessStatus = "idle";
  private stdoutBuffer = "";

  get status(): ProcessStatus {
    return this._status;
  }

  start(projectPath: string): void {
    if (this.process) {
      this.stop();
    }

    // Ensure project directory exists
    if (!existsSync(projectPath)) {
      mkdirSync(projectPath, { recursive: true });
    }

    // Resolve claude CLI path
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
    ];

    console.log(`[claude-process] Starting: ${claudePath} ${args.join(" ")} (cwd: ${projectPath})`);

    this.process = spawn(claudePath, args, {
      stdio: ["pipe", "pipe", "pipe"],
      cwd: projectPath,
      env: { ...process.env },
    });

    this.setStatus("running");
    this.stdoutBuffer = "";

    const currentProcess = this.process;

    currentProcess.stdout?.on("data", (chunk: Buffer) => {
      if (this.process !== currentProcess) return;
      this.handleStdout(chunk.toString());
    });

    currentProcess.stderr?.on("data", (chunk: Buffer) => {
      const text = chunk.toString().trim();
      if (text) {
        console.error(`[claude-process] stderr: ${text}`);
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

  approve(): void {
    // TODO: Tool approval handling in stream-json mode needs investigation
    console.log("[claude-process] approve() called - not yet supported in stream-json mode");
  }

  reject(): void {
    // TODO: Tool rejection handling in stream-json mode needs investigation
    console.log("[claude-process] reject() called - not yet supported in stream-json mode");
  }

  get isRunning(): boolean {
    return this.process !== null;
  }

  private handleStdout(data: string): void {
    this.stdoutBuffer += data;

    const lines = this.stdoutBuffer.split("\n");
    // Keep the last incomplete line in the buffer
    this.stdoutBuffer = lines.pop() ?? "";

    for (const line of lines) {
      this.processLine(line);
    }
  }

  private processLine(line: string): void {
    const event = parseClaudeEvent(line);
    if (!event) return;

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
      // First one is already handled by claudeEventToServerMessage
      for (let i = 1; i < toolResults.length; i++) {
        const tr = toolResults[i];
        if (tr.type === "tool_result") {
          this.emitMessage({
            type: "tool_result",
            toolUseId: tr.tool_use_id,
            content: tr.content,
          });
        }
      }
    }
  }

  private updateStatusFromEvent(event: ClaudeEvent): void {
    switch (event.type) {
      case "assistant": {
        const hasToolUse = (event as AssistantMessageEvent).message.content.some(
          (c): c is AssistantToolUseContent => c.type === "tool_use"
        );
        if (hasToolUse) {
          this.setStatus("waiting_approval");
        } else {
          this.setStatus("running");
        }
        break;
      }
      case "user":
        this.setStatus("running");
        break;
      case "result":
        this.setStatus("idle");
        break;
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
