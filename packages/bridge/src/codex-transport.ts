import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { resolvePlatformPath } from "./path-utils.js";
import {
  readCodexAppServerMode,
  readExternalCodexAuthToken,
  resolveCodexSharedAppServerUrl,
  type CodexAppServerMode,
} from "./codex-app-server-config.js";
import {
  createCodexAppServerAuth,
  type CodexAppServerAuth,
} from "./codex-app-server-auth.js";
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
  const value = env[key]?.trim() || fallback;
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

function systemdMemoryBytes(value: string): number | undefined {
  if (value.toLowerCase() === "infinity") return undefined;
  const match = /^([1-9]\d*(?:\.\d+)?)(B|K|M|G|T|P|KiB|MiB|GiB|TiB|PiB)?$/i.exec(value);
  if (!match) throw new Error(`Invalid systemd memory value: ${value}`);
  const unit = (match[2] ?? "B").toLowerCase();
  const scale: Record<string, number> = {
    b: 1,
    k: 1024,
    m: 1024 ** 2,
    g: 1024 ** 3,
    t: 1024 ** 4,
    p: 1024 ** 5,
    kib: 1024,
    mib: 1024 ** 2,
    gib: 1024 ** 3,
    tib: 1024 ** 4,
    pib: 1024 ** 5,
  };
  return Number(match[1]) * scale[unit]!;
}

function readIsolatedCodexConfig(
  env: NodeJS.ProcessEnv = process.env,
): IsolatedCodexConfig {
  const rawBasePort = env.BRIDGE_CODEX_ISOLATED_BASE_PORT?.trim();
  const basePort = rawBasePort ? Number(rawBasePort) : DEFAULT_ISOLATED_BASE_PORT;
  const maxBasePort = 65535 - (ISOLATED_PORT_RANGE - 1);
  if (!Number.isInteger(basePort) || basePort < 1024 || basePort > maxBasePort) {
    throw new Error(
      `BRIDGE_CODEX_ISOLATED_BASE_PORT must be an integer from 1024 to ${maxBasePort} (received ${JSON.stringify(rawBasePort ?? String(DEFAULT_ISOLATED_BASE_PORT))})`,
    );
  }

  const slice = env.BRIDGE_CODEX_ISOLATED_SLICE?.trim() || DEFAULT_ISOLATED_SLICE;
  if (!/^[A-Za-z0-9_.@:-]+\.slice$/.test(slice)) {
    throw new Error(
      `BRIDGE_CODEX_ISOLATED_SLICE must be a valid systemd slice name (received ${JSON.stringify(slice)})`,
    );
  }

  const memoryHigh = readSystemdMemoryValue(
    env,
    "BRIDGE_CODEX_ISOLATED_MEMORY_HIGH",
    DEFAULT_ISOLATED_MEMORY_HIGH,
  );
  const memoryMax = readSystemdMemoryValue(
    env,
    "BRIDGE_CODEX_ISOLATED_MEMORY_MAX",
    DEFAULT_ISOLATED_MEMORY_MAX,
  );
  const finiteHigh = systemdMemoryBytes(memoryHigh);
  const finiteMax = systemdMemoryBytes(memoryMax);
  if (finiteMax !== undefined && (finiteHigh === undefined || finiteHigh > finiteMax)) {
    throw new Error(
      `MemoryHigh (${memoryHigh}) must not exceed MemoryMax (${memoryMax})`,
    );
  }

  return {
    memoryHigh,
    memoryMax,
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
      // Probing avoids collisions where available; systemd remains authoritative.
    }
  }
  return ports;
}

function allocateIsolatedPort(basePort: number): number {
  const listening = listeningTcpPorts();
  for (let offset = 0; offset < ISOLATED_PORT_RANGE; offset += 1) {
    const port = basePort + offset;
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
  options: { stdio: "ignore"; env: NodeJS.ProcessEnv };
}

export function buildIsolatedCodexSystemdRunSpec(
  projectPath: string,
  port: number,
  unitName: string,
  platform: NodeJS.Platform = process.platform,
  env: NodeJS.ProcessEnv = process.env,
  auth?: CodexAppServerAuth,
): IsolatedCodexSystemdRunSpec {
  if (platform !== "linux") {
    throw new Error("isolated Codex app-server mode requires Linux systemd");
  }
  if (!auth) {
    throw new Error("isolated Codex app-server mode requires a capability credential");
  }
  if (!/^ccpocket-codex-[A-Za-z0-9_.@:-]+\.service$/.test(unitName)) {
    throw new Error(`Invalid isolated Codex systemd unit name: ${unitName}`);
  }

  const config = readIsolatedCodexConfig(env);
  const cwd = resolvePlatformPath(projectPath, platform);
  const home = env.HOME?.trim() || homedir();
  const codexHome = env.CODEX_HOME?.trim() || join(home, ".codex");
  const path = env.PATH?.trim() || "/usr/local/bin:/usr/bin:/bin";

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
      "--ws-auth",
      "capability-token",
      "--ws-token-file",
      auth.tokenFilePath,
    ],
    options: { stdio: "ignore", env },
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

export interface ManagedCodexAppServerSpawnSpec {
  command: string;
  args: string[];
  options: {
    cwd: string;
    stdio: "pipe";
    env: NodeJS.ProcessEnv;
    windowsVerbatimArguments?: boolean;
  };
}

interface ResolvedWindowsCodexCommand {
  path: string;
  kind: "native" | "shim";
}

const WINDOWS_CODEX_COMMAND_ENV = "CCPOCKET_CODEX_MANAGED_COMMAND";
const WINDOWS_CODEX_URL_ENV = "CCPOCKET_CODEX_MANAGED_URL";
const WINDOWS_CODEX_TOKEN_FILE_ENV = "CCPOCKET_CODEX_MANAGED_TOKEN_FILE";
const WINDOWS_CODEX_SHIM_COMMAND =
  `""%${WINDOWS_CODEX_COMMAND_ENV}%" app-server --listen "%${WINDOWS_CODEX_URL_ENV}%" ` +
  `--ws-auth capability-token --ws-token-file "%${WINDOWS_CODEX_TOKEN_FILE_ENV}%""`;

function validateManagedCodexAppServerUrl(url: string): void {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error("managed Codex app-server URL must be a valid ws:// or wss:// URL");
  }

  if (
    (parsed.protocol !== "ws:" && parsed.protocol !== "wss:") ||
    /["\r\n]/.test(url)
  ) {
    throw new Error("managed Codex app-server URL must be a valid ws:// or wss:// URL");
  }
}

function resolveWindowsCodexCommand(
  env: NodeJS.ProcessEnv,
): ResolvedWindowsCodexCommand {
  const searchPath = env.PATH ?? env.Path ?? env.path ?? "";
  const pathExt = env.PATHEXT?.trim() || ".COM;.EXE;.BAT;.CMD";
  const extensions = pathExt
    .split(";")
    .map((extension) => extension.trim())
    .filter(Boolean)
    .map((extension) =>
      (extension.startsWith(".") ? extension : `.${extension}`).toLowerCase(),
    )
    .filter(
      (extension) =>
        extension === ".com" ||
        extension === ".exe" ||
        extension === ".bat" ||
        extension === ".cmd",
    );

  for (const rawDirectory of searchPath.split(";")) {
    const directory = rawDirectory.trim().replace(/^"|"$/g, "");
    if (!directory) continue;
    for (const extension of extensions) {
      const candidate = join(directory, `codex${extension}`);
      try {
        if (!statSync(candidate).isFile()) continue;
      } catch {
        continue;
      }
      return {
        path: candidate,
        kind: extension === ".cmd" || extension === ".bat" ? "shim" : "native",
      };
    }
  }

  throw new Error(
    "Codex CLI executable was not found on PATH for managed Windows app-server mode",
  );
}

export function buildManagedCodexAppServerSpawnSpec(
  projectPath: string,
  url: string,
  auth: CodexAppServerAuth,
  platform: NodeJS.Platform = process.platform,
  env: NodeJS.ProcessEnv = process.env,
): ManagedCodexAppServerSpawnSpec {
  validateManagedCodexAppServerUrl(url);
  const args = [
    "app-server",
    "--listen",
    url,
    "--ws-auth",
    "capability-token",
    "--ws-token-file",
    auth.tokenFilePath,
  ];
  const cwd = resolvePlatformPath(projectPath, platform);

  if (platform === "win32") {
    const resolved = resolveWindowsCodexCommand(env);
    if (resolved.kind === "native") {
      return {
        command: resolved.path,
        args,
        options: { cwd, stdio: "pipe", env },
      };
    }

    return {
      command: env.ComSpec?.trim() || env.COMSPEC?.trim() || "cmd.exe",
      args: ["/d", "/s", "/v:off", "/c", WINDOWS_CODEX_SHIM_COMMAND],
      options: {
        cwd,
        stdio: "pipe",
        env: {
          ...env,
          [WINDOWS_CODEX_COMMAND_ENV]: resolved.path,
          [WINDOWS_CODEX_URL_ENV]: url,
          [WINDOWS_CODEX_TOKEN_FILE_ENV]: auth.tokenFilePath,
        },
        windowsVerbatimArguments: true,
      },
    };
  }

  return {
    command: "codex",
    args,
    options: {
      cwd,
      stdio: "pipe",
      env,
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
    private readonly retryDurationMs: number,
    private readonly auth: Pick<CodexAppServerAuth, "token">,
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

    const ws = new WebSocket(this.url, {
      headers: { Authorization: `Bearer ${this.auth.token}` },
    });
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
      if (this.stopped) return;
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
  private readonly auth: CodexAppServerAuth;
  private readonly delegate: WebSocketCodexTransport;
  private readonly port: number;
  private readonly unitName: string;
  private started = false;
  private stopped = false;
  private terminal = false;

  constructor(private readonly platform: NodeJS.Platform) {
    super();
    const config = readIsolatedCodexConfig();
    this.auth = createCodexAppServerAuth();
    try {
      this.port = allocateIsolatedPort(config.basePort);
    } catch (error) {
      this.auth.cleanup();
      throw error;
    }
    this.unitName = `ccpocket-codex-${randomUUID().replaceAll("-", "")}.service`;
    this.delegate = new WebSocketCodexTransport(
      `ws://127.0.0.1:${this.port}`,
      ISOLATED_CONNECT_RETRY_MS,
      this.auth,
    );
    this.delegate.on("data", (chunk) => this.emit("data", chunk));
    this.delegate.on("log", (chunk) => this.emit("log", chunk));
    this.delegate.on("error", (error) => this.emit("error", error));
    this.delegate.on("exit", (code) => this.finish(code ?? 1));
  }

  get isRunning(): boolean {
    return !this.stopped && !this.terminal && this.delegate.isRunning;
  }

  start(projectPath: string): void {
    if (this.stopped || this.terminal) return;
    try {
      const spec = buildIsolatedCodexSystemdRunSpec(
        projectPath,
        this.port,
        this.unitName,
        this.platform,
        process.env,
        this.auth,
      );
      this.started = true;
      const launcher = spawn(spec.command, spec.args, spec.options);
      launcher.once("error", (error) => this.fail(error));
      launcher.once("exit", (code, signal) => {
        if (code === 0 || this.stopped || this.terminal) return;
        this.fail(
          new Error(
            `systemd-run failed for ${this.unitName}: code=${code ?? "null"} signal=${signal ?? "null"}`,
          ),
        );
      });
      this.delegate.start(projectPath);
    } catch (error) {
      this.fail(error instanceof Error ? error : new Error(String(error)));
    }
  }

  write(envelope: Record<string, unknown>): void {
    this.delegate.write(envelope);
  }

  stop(): void {
    if (this.stopped || this.terminal) return;
    this.stopped = true;
    this.cleanup();
  }

  private fail(error: Error): void {
    if (this.stopped || this.terminal) return;
    this.finish(1, error);
  }

  private finish(code: number, error?: Error): void {
    if (this.terminal) return;
    this.terminal = true;
    this.stopped = true;
    this.cleanup();
    if (error) this.emit("error", error);
    this.emit("exit", code);
  }

  private cleanup(): void {
    this.delegate.stop();
    if (this.started) this.stopUnit();
    this.auth.cleanup();
    releaseIsolatedPort(this.port);
    isolatedTransports.delete(this);
  }

  private stopUnit(): void {
    try {
      const stopper = spawn(
        "systemctl",
        ["--user", "stop", this.unitName],
        { stdio: "ignore", env: process.env },
      );
      stopper.on("error", () => {
        // The transient unit may already have been collected after an OOM exit.
      });
    } catch {
      // No transient unit can remain when its launcher could not be spawned.
    }
  }
}

class ManagedCodexAppServer {
  private child: ChildProcessWithoutNullStreams | null = null;
  private auth: CodexAppServerAuth | null = null;

  constructor(
    private readonly url: string,
    private readonly platform: NodeJS.Platform,
  ) {}

  ensureStarted(projectPath: string): CodexAppServerAuth {
    if (this.child && !this.child.killed && this.auth) return this.auth;

    const auth = createCodexAppServerAuth();
    let child: ChildProcessWithoutNullStreams;
    try {
      const spec = buildManagedCodexAppServerSpawnSpec(
        projectPath,
        this.url,
        auth,
        this.platform,
      );
      child = spawn(spec.command, spec.args, spec.options);
    } catch (error) {
      auth.cleanup();
      throw error;
    }

    this.child = child;
    this.auth = auth;
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
        this.cleanupAuth(auth);
      }
      const message = err instanceof Error ? err.message : String(err);
      console.error(`[codex-app-server] Failed to start: ${message}`);
    });
    child.on("exit", () => {
      if (this.child === child) {
        this.child = null;
        this.cleanupAuth(auth);
      }
    });
    return auth;
  }

  createTransport(projectPath: string): CodexTransport {
    return new WebSocketCodexTransport(this.url, 5000, this.ensureStarted(projectPath));
  }

  stop(): void {
    if (this.child) this.child.kill("SIGTERM");
    this.child = null;
    if (this.auth) this.cleanupAuth(this.auth);
  }

  private cleanupAuth(auth: CodexAppServerAuth): void {
    auth.cleanup();
    if (this.auth === auth) this.auth = null;
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
    return new WebSocketCodexTransport(
      readCodexAppServerUrl(mode),
      0,
      readExternalCodexAuthToken(),
    );
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
