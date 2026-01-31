import { spawn, type ChildProcess } from "node:child_process";
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

    const args = [
      "--output-format",
      "stream-json",
      "--verbose",
      "--project",
      projectPath,
    ];

    console.log(`[claude-process] Starting: claude ${args.join(" ")}`);

    this.process = spawn("claude", args, {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    this.setStatus("running");
    this.stdoutBuffer = "";

    this.process.stdout?.on("data", (chunk: Buffer) => {
      this.handleStdout(chunk.toString());
    });

    this.process.stderr?.on("data", (chunk: Buffer) => {
      const text = chunk.toString().trim();
      if (text) {
        console.error(`[claude-process] stderr: ${text}`);
      }
    });

    this.process.on("exit", (code) => {
      console.log(`[claude-process] Process exited with code ${code}`);
      this.process = null;
      this.setStatus("idle");
      this.emit("exit", code);
    });

    this.process.on("error", (err) => {
      console.error(`[claude-process] Process error:`, err.message);
      this.emitMessage({ type: "error", message: `Process error: ${err.message}` });
      this.process = null;
      this.setStatus("idle");
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
    this.writeStdin(text + "\n");
  }

  approve(): void {
    this.writeStdin("y\n");
  }

  reject(): void {
    this.writeStdin("n\n");
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
