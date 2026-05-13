import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { EventEmitter } from "node:events";
import { resolvePlatformPath } from "./path-utils.js";
import {
  readCodexAppServerMode,
  resolveCodexSharedAppServerUrl,
  type CodexAppServerMode,
} from "./codex-app-server-config.js";
import WebSocket from "ws";

export interface CodexTransportEvents {
  data: [string];
  log: [string];
  error: [Error];
  exit: [number | null];
}

export abstract class CodexTransport extends EventEmitter<CodexTransportEvents> {
  abstract start(projectPath: string): void;
  abstract write(envelope: Record<string, unknown>): void;
  abstract stop(): void;
  abstract get isRunning(): boolean;
}

export function buildCodexSpawnSpec(
  projectPath: string,
  platform: NodeJS.Platform = process.platform,
): {
  command: string;
  args: string[];
  options: {
    cwd: string;
    stdio: "pipe";
    env: NodeJS.ProcessEnv;
    windowsVerbatimArguments?: boolean;
  };
} {
  const cwd = resolvePlatformPath(projectPath, platform);

  if (platform === "win32") {
    return {
      command: "cmd.exe",
      args: ["/d", "/s", "/c", "codex app-server --listen stdio://"],
      options: {
        cwd,
        stdio: "pipe",
        env: process.env,
        windowsVerbatimArguments: true,
      },
    };
  }

  return {
    command: "codex",
    args: ["app-server", "--listen", "stdio://"],
    options: {
      cwd,
      stdio: "pipe",
      env: process.env,
    },
  };
}

class StdioCodexTransport extends CodexTransport {
  private child: ChildProcessWithoutNullStreams | null = null;

  constructor(private readonly platform: NodeJS.Platform) {
    super();
  }

  get isRunning(): boolean {
    return this.child !== null && !this.child.killed;
  }

  start(projectPath: string): void {
    const spawnSpec = buildCodexSpawnSpec(projectPath, this.platform);
    const child = spawn(spawnSpec.command, spawnSpec.args, spawnSpec.options);
    this.child = child;

    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      this.emit("data", chunk);
    });

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) this.emit("log", line);
    });

    child.on("error", (err) => {
      this.emit("error", err);
    });

    child.on("exit", (code) => {
      this.child = null;
      this.emit("exit", code ?? 0);
    });
  }

  write(envelope: Record<string, unknown>): void {
    if (!this.child || this.child.killed) {
      throw new Error("codex app-server is not running");
    }
    this.child.stdin.write(`${JSON.stringify(envelope)}\n`);
  }

  stop(): void {
    if (this.child) {
      this.child.kill("SIGTERM");
      this.child = null;
    }
  }
}

class WebSocketCodexTransport extends CodexTransport {
  private ws: WebSocket | null = null;
  private stopped = false;
  private connected = false;
  private queue: string[] = [];
  private retryTimer: NodeJS.Timeout | null = null;
  private firstAttemptAt = 0;

  constructor(
    private readonly url: string,
    private readonly retryDurationMs = 0,
  ) {
    super();
  }

  get isRunning(): boolean {
    return !this.stopped && (this.connected || this.ws !== null);
  }

  start(_projectPath: string): void {
    this.stopped = false;
    this.firstAttemptAt = Date.now();
    this.connect();
  }

  write(envelope: Record<string, unknown>): void {
    if (this.stopped) {
      throw new Error("codex app-server is not running");
    }
    const payload = JSON.stringify(envelope);
    if (this.connected && this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(payload);
      return;
    }
    this.queue.push(payload);
  }

  stop(): void {
    this.stopped = true;
    this.queue = [];
    if (this.retryTimer) {
      clearTimeout(this.retryTimer);
      this.retryTimer = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  private connect(): void {
    if (this.stopped) return;

    const ws = new WebSocket(this.url);
    this.ws = ws;

    ws.on("open", () => {
      this.connected = true;
      const queued = this.queue.splice(0);
      for (const payload of queued) {
        ws.send(payload);
      }
    });

    ws.on("message", (data) => {
      const text = data.toString();
      this.emit("data", text.endsWith("\n") ? text : `${text}\n`);
    });

    ws.on("error", (err) => {
      if (this.shouldRetry()) return;
      this.emit("error", err instanceof Error ? err : new Error(String(err)));
    });

    ws.on("close", () => {
      this.connected = false;
      this.ws = null;
      if (this.stopped) return;
      if (this.shouldRetry()) {
        this.retryTimer = setTimeout(() => this.connect(), 100);
        return;
      }
      this.emit("exit", 1);
    });
  }

  private shouldRetry(): boolean {
    return (
      !this.stopped &&
      this.retryDurationMs > 0 &&
      Date.now() - this.firstAttemptAt < this.retryDurationMs
    );
  }
}

class ManagedCodexAppServer {
  private child: ChildProcessWithoutNullStreams | null = null;

  constructor(
    private readonly url: string,
    private readonly platform: NodeJS.Platform,
  ) {}

  ensureStarted(projectPath: string): void {
    if (this.child && !this.child.killed) return;

    const cwd = resolvePlatformPath(projectPath, this.platform);
    const child =
      this.platform === "win32"
        ? spawn(
            "cmd.exe",
            ["/d", "/s", "/c", `codex app-server --listen ${this.url}`],
            {
              cwd,
              stdio: "pipe",
              env: process.env,
              windowsVerbatimArguments: true,
            },
          )
        : spawn("codex", ["app-server", "--listen", this.url], {
            cwd,
            stdio: "pipe",
            env: process.env,
          });

    this.child = child;
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) console.log(`[codex-app-server] ${line}`);
    });
    child.stderr.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) console.log(`[codex-app-server] ${line}`);
    });
    child.on("error", (err) => {
      if (this.child === child) {
        this.child = null;
      }
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[codex-app-server] Failed to start: ${message}`);
    });
    child.on("exit", () => {
      this.child = null;
    });
  }

  createTransport(projectPath: string): CodexTransport {
    this.ensureStarted(projectPath);
    return new WebSocketCodexTransport(this.url, 5000);
  }

  stop(): void {
    if (!this.child) return;
    this.child.kill("SIGTERM");
    this.child = null;
  }
}

const managedServers = new Map<string, ManagedCodexAppServer>();

export function createCodexTransport(
  projectPath: string,
  platform: NodeJS.Platform = process.platform,
): CodexTransport {
  const mode = readCodexAppServerMode();
  if (mode === "external") {
    return new WebSocketCodexTransport(readCodexAppServerUrl(mode));
  }
  if (mode === "managed") {
    const url = readCodexAppServerUrl(mode);
    let manager = managedServers.get(url);
    if (!manager) {
      manager = new ManagedCodexAppServer(url, platform);
      managedServers.set(url, manager);
    }
    return manager.createTransport(projectPath);
  }
  return new StdioCodexTransport(platform);
}

export function stopManagedCodexAppServers(): void {
  for (const manager of managedServers.values()) {
    manager.stop();
  }
  managedServers.clear();
}

function readCodexAppServerUrl(mode: CodexAppServerMode): string {
  const url = resolveCodexSharedAppServerUrl(mode);
  if (url) return url;

  if (mode === "external") {
    throw new Error(
      "BRIDGE_CODEX_SHARED_APP_SERVER_URL is required when BRIDGE_CODEX_APP_SERVER_MODE=external",
    );
  }
  throw new Error("codex app-server URL could not be resolved");
}
