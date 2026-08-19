import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
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

const DEFAULT_ISOLATED_MEMORY_HIGH = "4608M";
const DEFAULT_ISOLATED_MEMORY_MAX = "5120M";
const DEFAULT_ISOLATED_MEMORY_SWAP_MAX = "2048M";
const DEFAULT_ISOLATED_SLICE = "ccpocket-codex.slice";
const DEFAULT_ISOLATED_BASE_PORT = 18700;
const ISOLATED_PORT_RANGE = 200;
const ISOLATED_CONNECT_RETRY_MS = 15_000;

const allocatedIsolatedPorts = new Set<number>();
let nextIsolatedPort = DEFAULT_ISOLATED_BASE_PORT;

interface IsolatedCodexConfig {
  memoryHigh: string;
  memoryMax: string;
  memorySwapMax: string;
  slice: string;
  basePort: number;
}

function readSystemdMemoryValue(
  env: NodeJS.ProcessEnv,
  key: string,
  fallback: string,
): string {
  const value = env[key]?.trim();
  if (!value) return fallback;
  if (
    !/^(?:infinity|[1-9]\d*(?:\.\d+)?(?:B|K|M|G|T|P|KiB|MiB|GiB|TiB|PiB)?)$/i.test(
      value,
    )
  ) {
    throw new Error(
      `${key} must be a positive systemd memory value or infinity (received ${JSON.stringify(value)})`,
    );
  }
  return value;
}

function readIsolatedCodexConfig(
  env: NodeJS.ProcessEnv = process.env,
): IsolatedCodexConfig {
  const rawBasePort = env.BRIDGE_CODEX_ISOLATED_BASE_PORT?.trim();
  const basePort = rawBasePort ? Number(rawBasePort) : DEFAULT_ISOLATED_BASE_PORT;
  if (!Number.isInteger(basePort) || basePort < 1024 || basePort > 65535) {
    throw new Error(
      `BRIDGE_CODEX_ISOLATED_BASE_PORT must be an integer from 1024 to 65535 (received ${JSON.stringify(rawBasePort ?? String(DEFAULT_ISOLATED_BASE_PORT))})`,
    );
  }

  const slice = env.BRIDGE_CODEX_ISOLATED_SLICE?.trim() || DEFAULT_ISOLATED_SLICE;
  if (!/^[A-Za-z0-9_.@:-]+\.slice$/.test(slice)) {
    throw new Error(
      `BRIDGE_CODEX_ISOLATED_SLICE must be a valid systemd slice name (received ${JSON.stringify(slice)})`,
    );
  }

  return {
    memoryHigh: readSystemdMemoryValue(
      env,
      "BRIDGE_CODEX_ISOLATED_MEMORY_HIGH",
      DEFAULT_ISOLATED_MEMORY_HIGH,
    ),
    memoryMax: readSystemdMemoryValue(
      env,
      "BRIDGE_CODEX_ISOLATED_MEMORY_MAX",
      DEFAULT_ISOLATED_MEMORY_MAX,
    ),
    memorySwapMax: readSystemdMemoryValue(
      env,
      "BRIDGE_CODEX_ISOLATED_MEMORY_SWAP_MAX",
      DEFAULT_ISOLATED_MEMORY_SWAP_MAX,
    ),
    slice,
    basePort,
  };
}

function listeningTcpPorts(): Set<number> {
  const ports = new Set<number>();
  for (const path of ["/proc/net/tcp", "/proc/net/tcp6"]) {
    try {
      const lines = readFileSync(path, "utf8").split("\n");
      for (const line of lines.slice(1)) {
        const fields = line.trim().split(/\s+/);
        const localAddress = fields[1];
        if (fields[3] !== "0A" || !localAddress) continue;
        const portHex = localAddress.split(":")[1];
        if (portHex) ports.add(Number.parseInt(portHex, 16));
      }
    } catch {
      // Port probing is best effort; systemd/WS startup remains authoritative.
    }
  }
  return ports;
}

function allocateIsolatedPort(basePort: number): number {
  const listening = listeningTcpPorts();
  for (let attempt = 0; attempt < ISOLATED_PORT_RANGE; attempt += 1) {
    const port = basePort + ((nextIsolatedPort - basePort) % ISOLATED_PORT_RANGE);
    nextIsolatedPort = port + 1;
    if (nextIsolatedPort >= basePort + ISOLATED_PORT_RANGE) {
      nextIsolatedPort = basePort;
    }
    if (!allocatedIsolatedPorts.has(port) && !listening.has(port)) {
      allocatedIsolatedPorts.add(port);
      return port;
    }
  }
  throw new Error(
    `No free isolated Codex app-server port in ${basePort}-${basePort + ISOLATED_PORT_RANGE - 1}`,
  );
}

function releaseIsolatedPort(port: number): void {
  allocatedIsolatedPorts.delete(port);
}

export interface IsolatedCodexSystemdRunSpec {
  command: string;
  args: string[];
  options: {
    stdio: "ignore";
    env: NodeJS.ProcessEnv;
  };
}

export function buildIsolatedCodexSystemdRunSpec(
  projectPath: string,
  port: number,
  unitName: string,
  platform: NodeJS.Platform = process.platform,
  env: NodeJS.ProcessEnv = process.env,
): IsolatedCodexSystemdRunSpec {
  if (platform !== "linux") {
    throw new Error("isolated Codex app-server mode requires Linux systemd");
  }
  if (!/^ccpocket-codex-[A-Za-z0-9_.@:-]+\.service$/.test(unitName)) {
    throw new Error(`Invalid isolated Codex systemd unit name: ${unitName}`);
  }

  const config = readIsolatedCodexConfig(env);
  const cwd = resolvePlatformPath(projectPath, platform);
  const home = env.HOME?.trim() || homedir();
  const codexHome = env.CODEX_HOME?.trim() || join(home, ".codex");
  const path =
    env.PATH?.trim() || "/home/david/.local/bin:/usr/local/bin:/usr/bin:/bin";

  return {
    command: "systemd-run",
    args: [
      "--user",
      `--unit=${unitName}`,
      `--slice=${config.slice}`,
      "--collect",
      "--quiet",
      "--property=MemoryAccounting=yes",
      `--property=MemoryHigh=${config.memoryHigh}`,
      `--property=MemoryMax=${config.memoryMax}`,
      `--property=MemorySwapMax=${config.memorySwapMax}`,
      "--property=OOMPolicy=stop",
      "--property=OOMScoreAdjust=700",
      "--property=KillMode=control-group",
      "--property=StandardOutput=journal",
      "--property=StandardError=journal",
      "--property=SyslogIdentifier=ccpocket-codex",
      `--working-directory=${cwd}`,
      `--setenv=HOME=${home}`,
      `--setenv=CODEX_HOME=${codexHome}`,
      `--setenv=PATH=${path}`,
      "codex",
      "app-server",
      "--listen",
      `ws://127.0.0.1:${port}`,
    ],
    options: {
      stdio: "ignore",
      env,
    },
  };
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

class IsolatedCodexTransport extends CodexTransport {
  private readonly delegate: WebSocketCodexTransport;
  private readonly unitName: string;
  private readonly port: number;
  private stopped = false;
  private delegateExited = false;

  constructor(platform: NodeJS.Platform) {
    super();
    if (platform !== "linux") {
      throw new Error("isolated Codex app-server mode requires Linux systemd");
    }

    const config = readIsolatedCodexConfig();
    this.port = allocateIsolatedPort(config.basePort);
    this.unitName = `ccpocket-codex-${randomUUID().replaceAll("-", "")}.service`;
    this.delegate = new WebSocketCodexTransport(
      `ws://127.0.0.1:${this.port}`,
      ISOLATED_CONNECT_RETRY_MS,
    );

    this.delegate.on("data", (chunk) => this.emit("data", chunk));
    this.delegate.on("log", (chunk) => this.emit("log", chunk));
    this.delegate.on("error", (error) => this.emit("error", error));
    this.delegate.on("exit", (code) => {
      this.delegateExited = true;
      isolatedTransports.delete(this);
      this.releasePort();
      this.emit("exit", code);
    });
  }

  get isRunning(): boolean {
    return !this.stopped && this.delegate.isRunning;
  }

  start(projectPath: string): void {
    const spec = buildIsolatedCodexSystemdRunSpec(
      projectPath,
      this.port,
      this.unitName,
    );
    const launcher = spawn(spec.command, spec.args, spec.options);
    launcher.once("error", (error) => {
      if (this.stopped) return;
      this.delegate.stop();
      this.stopUnit();
      this.emit("error", error);
    });
    launcher.once("exit", (code, signal) => {
      if (this.stopped || this.delegateExited || code === 0) return;
      this.delegate.stop();
      this.stopUnit();
      this.emit(
        "error",
        new Error(
          `systemd-run failed for ${this.unitName}: code=${code ?? "null"} signal=${signal ?? "null"}`,
        ),
      );
    });
    this.delegate.start(projectPath);
  }

  write(envelope: Record<string, unknown>): void {
    this.delegate.write(envelope);
  }

  stop(): void {
    if (this.stopped) return;
    this.stopped = true;
    this.delegate.stop();
    this.stopUnit();
    this.releasePort();
  }

  private releasePort(): void {
    releaseIsolatedPort(this.port);
  }

  private stopUnit(): void {
    const stopper = spawn(
      "systemctl",
      ["--user", "stop", this.unitName],
      { stdio: "ignore", env: process.env },
    );
    stopper.on("error", () => {
      // The transient unit may already have been collected.
    });
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
const isolatedTransports = new Set<IsolatedCodexTransport>();

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
  if (mode === "isolated") {
    if (platform !== "linux") {
      console.warn(
        "[codex-app-server] isolated mode is only available on Linux; using private mode",
      );
      return new StdioCodexTransport(platform);
    }
    const transport = new IsolatedCodexTransport(platform);
    isolatedTransports.add(transport);
    return transport;
  }
  return new StdioCodexTransport(platform);
}

export function stopManagedCodexAppServers(): void {
  for (const manager of managedServers.values()) {
    manager.stop();
  }
  managedServers.clear();
  for (const transport of isolatedTransports) {
    transport.stop();
  }
  isolatedTransports.clear();
}

function readCodexAppServerUrl(mode: CodexAppServerMode): string {
  if (mode === "isolated") {
    throw new Error("isolated Codex app-server mode does not use a shared URL");
  }
  const url = resolveCodexSharedAppServerUrl(mode);
  if (url) return url;

  if (mode === "external") {
    throw new Error(
      "BRIDGE_CODEX_SHARED_APP_SERVER_URL is required when BRIDGE_CODEX_APP_SERVER_MODE=external",
    );
  }
  throw new Error("codex app-server URL could not be resolved");
}
