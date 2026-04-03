import { EventEmitter } from "node:events";
import * as pty from "node-pty";
import type { IPty } from "node-pty";
import { AnsiParser } from "./ansi-parser.js";
import type { IProcessTransport, ProcessStartOptions } from "./process-transport.js";
import type { ProcessStatus, ServerMessage } from "./parser.js";

export class PtyProcess extends EventEmitter implements IProcessTransport {
  private ptyProc: IPty | null = null;
  private parser: AnsiParser | null = null;
  private _status: ProcessStatus = "idle";
  private _sessionId: string | null = null;
  private dataDisposable: { dispose(): void } | null = null;
  private exitDisposable: { dispose(): void } | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  get isPty(): boolean {
    return true;
  }

  get sessionId(): string | null {
    return this._sessionId;
  }

  get isWaitingForInput(): boolean {
    // PTY is always ready to receive input — no turn-based protocol
    return true;
  }

  interrupt(): void {
    // Send Ctrl+C to the PTY (standard Unix SIGINT)
    this.ptyProc?.write("\x03");
  }

  start(opts: ProcessStartOptions): void {
    const { projectPath, provider, sessionId, permissionMode } = opts;

    const binary = provider === "codex" ? "codex" : "claude";
    const args = this.buildArgs(provider, projectPath, sessionId, permissionMode);

    this.parser = new AnsiParser(provider);
    this.parser.on("message", (msg: ServerMessage) => {
      this.emit("message", msg);
    });
    this.parser.on("session_id", (id: string) => {
      this._sessionId = id;
    });

    this._status = "starting";
    this.emit("status", this._status);

    this.ptyProc = pty.spawn(binary, args, {
      name: "xterm-256color",
      cols: 80,
      rows: 24,
      cwd: projectPath,
      env: process.env as Record<string, string>,
    });

    this.dataDisposable = this.ptyProc.onData((data: string) => {
      this.emit("pty_data", data);
      this.parser?.feed(data);
    });

    this.exitDisposable = this.ptyProc.onExit(
      ({ exitCode }: { exitCode: number; signal?: number }) => {
        this.parser?.flush();
        this._status = "idle";
        this.emit("status", this._status);
        this.emit("exit", exitCode);
        this.cleanup();
      },
    );

    this._status = "running";
    this.emit("status", this._status);

    if (opts.initialInput) {
      setTimeout(() => this.sendInput(opts.initialInput!), 500);
    }
  }

  stop(): void {
    this.ptyProc?.kill("SIGTERM");
  }

  kill(): void {
    this.ptyProc?.kill("SIGKILL");
  }

  write(data: string): void {
    this.ptyProc?.write(data);
  }

  sendInput(text: string): void {
    this.ptyProc?.write(text + "\n");
  }

  sendApproval(_id: string): void {
    this.ptyProc?.write("y\n");
  }

  sendRejection(_id: string, _reason?: string): void {
    this.ptyProc?.write("n\n");
  }

  resize(cols: number, rows: number): void {
    this.ptyProc?.resize(cols, rows);
  }

  private buildArgs(
    provider: string,
    projectPath: string,
    sessionId?: string,
    permissionMode?: string,
  ): string[] {
    if (provider === "codex") {
      const args = [projectPath];
      if (sessionId) args.push("--thread", sessionId);
      return args;
    }

    const args = [projectPath, "--verbose"];
    if (sessionId) {
      args.push("--resume", sessionId);
    }
    if (permissionMode === "bypassPermissions") {
      args.push("--dangerously-skip-permissions");
    }
    return args;
  }

  private cleanup(): void {
    this.dataDisposable?.dispose();
    this.exitDisposable?.dispose();
    this.dataDisposable = null;
    this.exitDisposable = null;
    this.ptyProc = null;
  }
}
