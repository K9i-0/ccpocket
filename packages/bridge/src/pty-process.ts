import { EventEmitter } from "node:events";
import { execFileSync } from "node:child_process";
import * as pty from "node-pty";
import type { IPty } from "node-pty";
import type { ProcessStartOptions } from "./process-transport.js";
import type { ProcessStatus } from "./parser.js";

/**
 * Sidecar PTY process — spawns the native CLI binary (`claude` or `codex`)
 * for terminal display. Emits raw `pty_data` bytes for CLI clients.
 *
 * This is NOT the primary session process. SdkProcess/CodexProcess own the
 * session and emit structured events for phone clients. PtyProcess is a
 * secondary display process that attaches to the same conversation via
 * `claude --resume` or `codex --thread`.
 *
 * Events emitted:
 * - "pty_data" (data: string)           — raw terminal bytes
 * - "status"   (status: ProcessStatus)  — lifecycle status changes
 * - "exit"     (code: number)           — process exited
 */
export class PtyProcess extends EventEmitter {
  private ptyProc: IPty | null = null;
  private _status: ProcessStatus = "idle";
  private dataDisposable: { dispose(): void } | null = null;
  private exitDisposable: { dispose(): void } | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  /**
   * Spawn the native CLI as a sidecar PTY.
   * For Claude: `claude --resume <sessionId> <projectPath> --verbose`
   * For Codex:  `codex --thread <sessionId> <projectPath>`
   */
  start(opts: ProcessStartOptions): void {
    const { projectPath, provider, sessionId } = opts;

    if (!sessionId) {
      throw new Error("Sidecar PTY requires a sessionId (--resume/--thread)");
    }

    const binaryName = provider === "codex" ? "codex" : "claude";
    let binary: string;
    try {
      binary = execFileSync("which", [binaryName], { encoding: "utf-8" }).trim();
    } catch {
      binary = binaryName;
    }

    const args = this.buildArgs(provider, projectPath, sessionId, opts.permissionMode);
    console.log(`[pty] Spawning sidecar: ${binary} ${args.join(" ")}`);

    this._status = "starting";
    this.emit("status", this._status);

    this.ptyProc = pty.spawn(binary, args, {
      name: "xterm-256color",
      cols: opts.cols ?? 80,
      rows: opts.rows ?? 24,
      cwd: projectPath,
      env: process.env as Record<string, string>,
    });

    this.dataDisposable = this.ptyProc.onData((data: string) => {
      this.emit("pty_data", data);
    });

    this.exitDisposable = this.ptyProc.onExit(
      ({ exitCode }: { exitCode: number; signal?: number }) => {
        this._status = "idle";
        this.emit("status", this._status);
        this.emit("exit", exitCode);
        this.cleanup();
      },
    );

    this._status = "running";
    this.emit("status", this._status);
  }

  /** Write raw bytes to the PTY (keystrokes from CLI client). */
  write(data: string): void {
    this.ptyProc?.write(data);
  }

  /** Resize the PTY terminal. */
  resize(cols: number, rows: number): void {
    this.ptyProc?.resize(cols, rows);
  }

  /** Graceful stop (SIGTERM). */
  stop(): void {
    this.ptyProc?.kill("SIGTERM");
  }

  /** Forceful kill (SIGKILL). */
  kill(): void {
    this.ptyProc?.kill("SIGKILL");
  }

  private buildArgs(
    provider: string,
    projectPath: string,
    sessionId: string,
    permissionMode?: string,
  ): string[] {
    if (provider === "codex") {
      return [projectPath, "--thread", sessionId];
    }
    const args = [projectPath, "--verbose", "--resume", sessionId];
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
