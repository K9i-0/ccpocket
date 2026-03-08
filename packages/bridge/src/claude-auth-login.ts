import { EventEmitter } from "node:events";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { getClaudeAuthStatus, type ClaudeAuthStatus } from "./usage.js";

export type ClaudeAuthLoginState =
  | "idle"
  | "starting"
  | "waiting_browser"
  | "waiting_code"
  | "authorizing"
  | "success"
  | "error"
  | "cancelled";

export interface ClaudeAuthSnapshot {
  authenticated: boolean;
  source?: "api_key" | "oauth" | "none";
  loginInProgress: boolean;
  state: ClaudeAuthLoginState;
  message?: string;
  errorCode?: string;
  loginUrl?: string;
  prompt?: string;
}

interface ClaudeAuthLoginEvents {
  update: [ClaudeAuthSnapshot];
}

const URL_REGEX = /https:\/\/[^\s"'<>]+/g;
const ANSI_REGEX = /\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])/g;

function stripAnsi(text: string): string {
  return text.replaceAll(ANSI_REGEX, "");
}

function isWaitingForCode(text: string): boolean {
  return /paste.*code|enter.*code|verification code|one[- ]time code|authorization code/i.test(text);
}

function isSuccessful(text: string): boolean {
  return /login successful|logged in|authentication complete|successfully authenticated/i.test(text);
}

export class ClaudeAuthLoginManager extends EventEmitter<ClaudeAuthLoginEvents> {
  private child: ChildProcessWithoutNullStreams | null = null;
  private snapshot: ClaudeAuthSnapshot = {
    authenticated: false,
    source: "none",
    loginInProgress: false,
    state: "idle",
    message: "Claude Code is not authenticated.",
    errorCode: "auth_login_required",
  };
  private recentOutput = "";
  private cancelled = false;
  private authPollTimer: ReturnType<typeof setInterval> | null = null;

  async getStatus(): Promise<ClaudeAuthSnapshot> {
    if (this.child) {
      return this.snapshot;
    }

    const status = await getClaudeAuthStatus();
    this.snapshot = this.snapshotFromStatus(status);
    return this.snapshot;
  }

  async start(): Promise<ClaudeAuthSnapshot> {
    if (this.child) {
      return this.snapshot;
    }

    this.cancelled = false;
    this.recentOutput = "";
    this.stopPolling();
    this.update({
      authenticated: false,
      source: "none",
      loginInProgress: true,
      state: "starting",
      message: "Starting Claude Code login on the Bridge machine...",
    });

    this.child = this.spawnLoginProcess();
    this.child.stdout.on("data", (chunk: Buffer) => this.handleChunk(chunk.toString("utf-8")));
    this.child.stderr.on("data", (chunk: Buffer) => this.handleChunk(chunk.toString("utf-8")));
    this.child.on("error", (err) => {
      this.finish({
        authenticated: false,
        source: "none",
        loginInProgress: false,
        state: "error",
        message: `Failed to start claude auth login: ${err.message}`,
        errorCode: "auth_api_error",
      });
    });
    this.child.on("exit", () => {
      void this.handleExit();
    });
    this.startPolling();

    return this.snapshot;
  }

  submitCode(code: string): ClaudeAuthSnapshot {
    if (!this.child) {
      return this.snapshot;
    }
    this.child.stdin.write(`${code.trim()}\n`);
    this.update({
      ...this.snapshot,
      loginInProgress: true,
      state: "authorizing",
      prompt: "Submitted code. Waiting for Claude Code to finish authentication...",
      message: "Completing authentication...",
    });
    return this.snapshot;
  }

  cancel(): ClaudeAuthSnapshot {
    if (!this.child) {
      return this.snapshot;
    }
    this.cancelled = true;
    this.child.kill("SIGTERM");
    return this.snapshot;
  }

  private spawnLoginProcess(): ChildProcessWithoutNullStreams {
    return spawn("claude", ["auth", "login"], {
      env: process.env,
      stdio: "pipe",
    });
  }

  private handleChunk(rawChunk: string): void {
    const chunk = stripAnsi(rawChunk);
    this.recentOutput = `${this.recentOutput}${chunk}`.slice(-8000);

    const urls = chunk.match(URL_REGEX) ?? [];
    const loginUrl = urls.length > 0 ? urls[0] : this.snapshot.loginUrl;
    const lines = chunk
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    const latestLine = lines.length > 0 ? lines[lines.length - 1] : undefined;

    if (isSuccessful(chunk)) {
      this.update({
        ...this.snapshot,
        loginInProgress: true,
        state: "success",
        loginUrl,
        message: latestLine ?? "Claude Code authentication completed.",
        prompt: undefined,
      });
      return;
    }

    if (isWaitingForCode(chunk)) {
      this.update({
        ...this.snapshot,
        loginInProgress: true,
        state: "waiting_code",
        loginUrl,
        prompt: latestLine ?? "Paste the verification code shown after browser authentication.",
        message: "Waiting for verification code...",
      });
      return;
    }

    if (loginUrl && this.snapshot.loginUrl != loginUrl) {
      this.update({
        ...this.snapshot,
        loginInProgress: true,
        state: this.snapshot.state === "waiting_code" ? "waiting_code" : "waiting_browser",
        loginUrl,
        message: "Finish sign-in in your browser.",
        prompt: "Open the login page and complete the browser flow. If Claude shows a verification code, return here and paste it.",
      });
      return;
    }

    if (
      latestLine != null &&
      !latestLine.includes("http") &&
      (this.snapshot.state === "starting" || this.snapshot.state === "waiting_browser")
    ) {
      this.update({
        ...this.snapshot,
        message: latestLine,
      });
    }
  }

  private async handleExit(): Promise<void> {
    this.child = null;
    this.stopPolling();

    if (this.cancelled) {
      this.finish({
        authenticated: false,
        source: "none",
        loginInProgress: false,
        state: "cancelled",
        message: "Claude Code login was cancelled.",
        errorCode: "auth_login_required",
        loginUrl: this.snapshot.loginUrl,
      });
      return;
    }

    const status = await getClaudeAuthStatus();
    if (status.authenticated) {
      this.finish({
        authenticated: true,
        source: status.source,
        loginInProgress: false,
        state: "success",
        message: "Claude Code is authenticated.",
      });
      return;
    }

    this.finish({
      authenticated: false,
      source: status.source,
      loginInProgress: false,
      state: "error",
      loginUrl: this.snapshot.loginUrl,
      prompt: this.snapshot.prompt,
      message: status.message ?? this.lastRelevantLine() ?? "Claude Code authentication failed.",
      errorCode: status.errorCode ?? "auth_api_error",
    });
  }

  private startPolling(): void {
    if (this.authPollTimer) {
      return;
    }
    this.authPollTimer = setInterval(() => {
      void this.pollForCompletion();
    }, 1500);
  }

  private stopPolling(): void {
    if (!this.authPollTimer) {
      return;
    }
    clearInterval(this.authPollTimer);
    this.authPollTimer = null;
  }

  private async pollForCompletion(): Promise<void> {
    if (!this.child || this.cancelled) {
      return;
    }

    try {
      const status = await getClaudeAuthStatus();
      if (!status.authenticated) {
        return;
      }

      this.update({
        authenticated: true,
        source: status.source,
        loginInProgress: false,
        state: "success",
        message: "Claude Code is authenticated.",
      });

      this.child.kill("SIGTERM");
    } catch {
      // Ignore transient polling failures while the login process is still active.
    }
  }

  private lastRelevantLine(): string | undefined {
    const lines = this.recentOutput
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    return lines.length > 0 ? lines[lines.length - 1] : undefined;
  }

  private snapshotFromStatus(status: ClaudeAuthStatus): ClaudeAuthSnapshot {
    return {
      authenticated: status.authenticated,
      source: status.source,
      loginInProgress: false,
      state: status.authenticated ? "success" : "idle",
      message: status.message,
      errorCode: status.errorCode,
    };
  }

  private finish(snapshot: ClaudeAuthSnapshot): void {
    this.snapshot = snapshot;
    this.emit("update", this.snapshot);
  }

  private update(snapshot: ClaudeAuthSnapshot): void {
    this.snapshot = snapshot;
    this.emit("update", this.snapshot);
  }
}
