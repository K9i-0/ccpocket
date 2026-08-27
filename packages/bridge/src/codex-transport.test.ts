import { existsSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const {
  spawnMock,
  children,
  createConnectionMock,
  readFileSyncMock,
  sockets,
  FakeWebSocket,
  FakeChildProcess,
} =
  vi.hoisted(() => {
    class FakeEmitter {
      private readonly listeners = new Map<string, Array<(...args: any[]) => void>>();
      on(event: string, listener: (...args: any[]) => void): this {
        this.listeners.set(event, [...(this.listeners.get(event) ?? []), listener]);
        return this;
      }
      once(event: string, listener: (...args: any[]) => void): this {
        return this.on(event, (...args) => {
          this.listeners.set(event, (this.listeners.get(event) ?? []).filter((item) => item !== listener));
          listener(...args);
        });
      }
      emit(event: string, ...args: any[]): boolean {
        for (const listener of this.listeners.get(event) ?? []) listener(...args);
        return true;
      }
    }
    class FakeStream extends FakeEmitter {
      setEncoding(): void {}
      write(_chunk: string): boolean { return true; }
    }
    class FakeChildProcess extends FakeEmitter {
      killed = false;
      stdin = new FakeStream();
      stdout = new FakeStream();
      stderr = new FakeStream();
      kill(): boolean { this.killed = true; return true; }
    }
    const state = {
      spawnMock: vi.fn(),
      children: [] as FakeChildProcess[],
      createConnectionMock: vi.fn(() => ({ kind: "unix-socket" })),
      readFileSyncMock: vi.fn(),
      sockets: [] as FakeWebSocket[],
    };
    class FakeWebSocket extends FakeEmitter {
      static OPEN = 1;
      readyState = FakeWebSocket.OPEN;
      constructor(
        public readonly url: string,
        public readonly options?: {
          headers?: Record<string, string>;
          perMessageDeflate?: boolean;
          createConnection?: (...args: any[]) => unknown;
        },
      ) { super(); state.sockets.push(this); }
      send(): void {}
      close(): void { this.emit("close"); }
    }
    return { ...state, FakeWebSocket, FakeChildProcess };
  });

vi.mock("node:child_process", () => ({ spawn: spawnMock }));
vi.mock("node:net", () => ({ createConnection: createConnectionMock }));
vi.mock("node:fs", async (importOriginal) => ({
  ...(await importOriginal<typeof import("node:fs")>()),
  readFileSync: readFileSyncMock,
}));
vi.mock("ws", () => ({ default: FakeWebSocket }));

import {
  buildManagedCodexAppServerSpawnSpec,
  buildIsolatedCodexSystemdRunSpec,
  createCodexTransport,
  stopManagedCodexAppServers,
} from "./codex-transport.js";

const isolatedEnvKeys = [
  "BRIDGE_CODEX_APP_SERVER_MODE",
  "BRIDGE_CODEX_ISOLATED_BASE_PORT",
  "BRIDGE_CODEX_ISOLATED_MEMORY_HIGH",
  "BRIDGE_CODEX_ISOLATED_MEMORY_MAX",
  "BRIDGE_CODEX_ISOLATED_MEMORY_SWAP_MAX",
  "BRIDGE_CODEX_ISOLATED_SLICE",
  "BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV",
  "BRIDGE_CODEX_CLI_AUTH_TOKEN_ENV",
  "BRIDGE_EXTERNAL_TEST_TOKEN",
] as const;

describe("isolated Codex transport", () => {
  beforeEach(() => {
    spawnMock.mockReset();
    createConnectionMock.mockClear();
    children.length = 0;
    sockets.length = 0;
    readFileSyncMock.mockReturnValue("sl  local_address rem_address st\n");
    spawnMock.mockImplementation(() => {
      const child = new (FakeChildProcess as any)();
      children.push(child);
      return child;
    });
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "isolated";
  });

  afterEach(() => {
    stopManagedCodexAppServers();
    for (const key of isolatedEnvKeys) delete process.env[key];
  });

  it("uses a loopback systemd worker with the documented defaults", () => {
    const transport = createCodexTransport("/tmp/project", "linux");
    transport.start("/tmp/project");
    const auth = (transport as any).auth;

    expect(spawnMock).toHaveBeenCalledWith(
      "systemd-run",
      expect.arrayContaining([
        "--user",
        "--slice=ccpocket-codex.slice",
        "--property=MemoryAccounting=yes",
        "--property=MemoryHigh=4608M",
        "--property=MemoryMax=5120M",
        "--property=MemorySwapMax=2048M",
        "--property=OOMPolicy=stop",
        "--property=OOMScoreAdjust=700",
        "--property=KillMode=control-group",
        "--property=StandardOutput=journal",
        "--property=StandardError=journal",
        "--working-directory=/tmp/project",
        "--listen",
        "ws://127.0.0.1:18700",
        "--ws-auth",
        "capability-token",
        "--ws-token-file",
        auth.tokenFilePath,
      ]),
      expect.objectContaining({ stdio: "ignore" }),
    );
    expect(spawnMock.mock.calls[0]![1]).not.toContain(auth.token);
    expect(sockets[0]?.url).not.toContain(auth.token);
    expect(sockets[0]?.options?.headers).toEqual({
      Authorization: `Bearer ${auth.token}`,
    });
  });

  it("rejects a base whose 200-port range exceeds 65535 before spawning", () => {
    process.env.BRIDGE_CODEX_ISOLATED_BASE_PORT = "65337";

    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "BRIDGE_CODEX_ISOLATED_BASE_PORT",
    );
    expect(spawnMock).not.toHaveBeenCalled();
  });

  it("accepts base 65336 because its final port is 65535", () => {
    process.env.BRIDGE_CODEX_ISOLATED_BASE_PORT = "65336";
    expect(() => createCodexTransport("/tmp/project", "linux")).not.toThrow();
  });

  it("rejects a systemd worker spec directly on non-Linux platforms", () => {
    expect(() =>
      buildIsolatedCodexSystemdRunSpec(
        "/tmp/project",
        18700,
        "ccpocket-codex-test.service",
        "darwin",
      ),
    ).toThrow("requires Linux systemd");
  });

  it.each([
    ["BRIDGE_CODEX_ISOLATED_MEMORY_HIGH", "not-a-memory"],
    ["BRIDGE_CODEX_ISOLATED_MEMORY_MAX", "5120W"],
    ["BRIDGE_CODEX_ISOLATED_SLICE", "not a slice"],
  ])("rejects invalid isolated config %s=%s", (key, value) => {
    process.env[key] = value;
    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow();
  });

  it.each([
    ["5121M", "5120M"],
    ["infinity", "5120M"],
  ])("rejects MemoryHigh %s above finite MemoryMax %s", (high, max) => {
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_HIGH = high;
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_MAX = max;
    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "MemoryHigh",
    );
  });

  it("allows finite MemoryHigh with infinity MemoryMax", () => {
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_HIGH = "5121M";
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_MAX = "infinity";
    expect(() => createCodexTransport("/tmp/project", "linux")).not.toThrow();
  });

  it("skips listening ports and fails closed when its bounded range is exhausted", () => {
    process.env.BRIDGE_CODEX_ISOLATED_BASE_PORT = "18700";
    readFileSyncMock.mockReturnValue(
      ["sl local_address rem_address st", ...Array.from({ length: 200 }, (_, index) => `0: 0100007F:${(18700 + index).toString(16).toUpperCase()} 00000000:0000 0A`)].join("\n"),
    );

    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "18700-18899",
    );
  });

  it("warns and uses private stdio outside Linux", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    try {
      const transport = createCodexTransport("C:/project", "win32");
      transport.start("C:/project");

      expect(warn).toHaveBeenCalledWith(expect.stringContaining("only available on Linux"));
      expect(spawnMock).toHaveBeenCalledWith("cmd.exe", expect.any(Array), expect.any(Object));
    } finally {
      warn.mockRestore();
    }
  });

  it("cleans up once after a launcher failure and terminal delegate exit", () => {
    const transport = createCodexTransport("/tmp/project", "linux");
    const errors: Error[] = [];
    const exits: number[] = [];
    transport.on("error", (error) => errors.push(error));
    transport.on("exit", (code) => exits.push(code ?? 0));
    transport.start("/tmp/project");
    children[0]!.emit("exit", 1, null);

    expect(errors).toHaveLength(1);
    expect(exits).toEqual([1]);
    expect(spawnMock).toHaveBeenCalledWith(
      "systemctl",
      expect.arrayContaining(["--user", "stop"]),
      expect.any(Object),
    );
    expect(transport.isRunning).toBe(false);
  });

  it("cleans up when isolated preflight becomes invalid after transport creation", () => {
    const first = createCodexTransport("/tmp/project", "linux");
    const errors: Error[] = [];
    const exits: number[] = [];
    first.on("error", (error) => errors.push(error));
    first.on("exit", (code) => exits.push(code ?? 0));
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_HIGH = "infinity";
    process.env.BRIDGE_CODEX_ISOLATED_MEMORY_MAX = "5120M";

    expect(() => first.start("/tmp/project")).not.toThrow();
    expect(errors).toHaveLength(1);
    expect(exits).toEqual([1]);
    expect(first.isRunning).toBe(false);

    delete process.env.BRIDGE_CODEX_ISOLATED_MEMORY_HIGH;
    delete process.env.BRIDGE_CODEX_ISOLATED_MEMORY_MAX;
    const second = createCodexTransport("/tmp/project", "linux");
    second.start("/tmp/project");

    expect(spawnMock.mock.calls[0]![1]).toContain("ws://127.0.0.1:18700");
  });

  it("stops idempotently and releases its port after a delegate exit", () => {
    const first = createCodexTransport("/tmp/project", "linux");
    const firstAuth = (first as any).auth;
    first.start("/tmp/project");
    first.stop();
    first.stop();

    expect(existsSync(firstAuth.tokenFilePath)).toBe(false);
    expect(existsSync(dirname(firstAuth.tokenFilePath))).toBe(false);

    const second = createCodexTransport("/tmp/project", "linux");
    second.start("/tmp/project");
    expect(spawnMock.mock.calls[2]![1]).toContain("ws://127.0.0.1:18700");
  });

  it("stops every isolated worker through the global lifecycle cleanup", () => {
    const first = createCodexTransport("/tmp/one", "linux");
    const second = createCodexTransport("/tmp/two", "linux");
    const firstAuth = (first as any).auth;
    const secondAuth = (second as any).auth;
    first.start("/tmp/one");
    second.start("/tmp/two");

    stopManagedCodexAppServers();

    expect(first.isRunning).toBe(false);
    expect(second.isRunning).toBe(false);
    expect(
      spawnMock.mock.calls.filter(([command]) => command === "systemctl"),
    ).toHaveLength(2);
    for (const auth of [firstAuth, secondAuth]) {
      expect(existsSync(auth.tokenFilePath)).toBe(false);
      expect(existsSync(dirname(auth.tokenFilePath))).toBe(false);
    }
  });

  it("removes an isolated credential when its launcher reports an error", () => {
    const transport = createCodexTransport("/tmp/project", "linux");
    const auth = (transport as any).auth;
    transport.on("error", () => {});
    transport.start("/tmp/project");

    children[0]!.emit("error", new Error("launcher failed"));

    expect(existsSync(auth.tokenFilePath)).toBe(false);
  });

  it("removes an isolated credential when spawning throws", () => {
    spawnMock.mockImplementation(() => {
      throw new Error("spawn failed");
    });
    const transport = createCodexTransport("/tmp/project", "linux");
    const auth = (transport as any).auth;
    transport.on("error", () => {});

    transport.start("/tmp/project");

    expect(existsSync(auth.tokenFilePath)).toBe(false);
  });

  it("removes an isolated credential when the worker reaches its terminal exit", () => {
    const transport = createCodexTransport("/tmp/project", "linux");
    const auth = (transport as any).auth;
    transport.start("/tmp/project");

    (transport as any).delegate.emit("exit", 1);

    expect(existsSync(auth.tokenFilePath)).toBe(false);
  });
});

describe("WebSocket Codex app-server authentication", () => {
  beforeEach(() => {
    spawnMock.mockReset();
    createConnectionMock.mockClear();
    children.length = 0;
    sockets.length = 0;
    readFileSyncMock.mockReturnValue("sl  local_address rem_address st\n");
    spawnMock.mockImplementation(() => {
      const child = new (FakeChildProcess as any)();
      children.push(child);
      return child;
    });
  });

  afterEach(() => {
    stopManagedCodexAppServers();
    for (const key of isolatedEnvKeys) delete process.env[key];
    vi.useRealTimers();
  });

  it("fails before connecting when external token indirection is missing or invalid", () => {
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "external";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";

    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV",
    );
    process.env.BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV = "not-valid";
    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "environment-variable name",
    );
    expect(sockets).toHaveLength(0);
  });

  it("sends an external bearer header without placing the token in the URL", () => {
    const token = randomUUID();
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "external";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";
    process.env.BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV = "BRIDGE_EXTERNAL_TEST_TOKEN";
    process.env.BRIDGE_EXTERNAL_TEST_TOKEN = token;

    const transport = createCodexTransport("/tmp/project", "linux");
    transport.start("/tmp/project");

    expect(sockets[0]?.url).toBe("ws://127.0.0.1:18767");
    expect(sockets[0]?.url).not.toContain(token);
    expect(sockets[0]?.options?.headers).toEqual({ Authorization: `Bearer ${token}` });
    transport.stop();
  });

  it("connects to an external Unix WebSocket without a bearer token", () => {
    const socketPath =
      "/home/test/.codex/app-server-control/app-server-control.sock";
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "external";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = `unix://${socketPath}`;

    const transport = createCodexTransport("/tmp/project", "linux");
    transport.start("/tmp/project");

    expect(sockets[0]?.url).toBe("ws://localhost/rpc");
    expect(sockets[0]?.options?.headers).toBeUndefined();
    expect(sockets[0]?.options?.perMessageDeflate).toBe(false);
    expect(sockets[0]?.options?.createConnection).toEqual(expect.any(Function));
    sockets[0]?.options?.createConnection?.({});
    expect(createConnectionMock).toHaveBeenCalledWith({ path: socketPath });
    transport.stop();
  });

  it("uses a fresh managed credential after child replacement and removes both terminal files", () => {
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "managed";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";

    const first = createCodexTransport("/tmp/project", "linux");
    first.start("/tmp/project");
    const firstArgs = spawnMock.mock.calls[0]![1] as string[];
    const firstFile = firstArgs[firstArgs.indexOf("--ws-token-file") + 1]!;
    const firstHeader = sockets[0]?.options?.headers.Authorization;
    children[0]!.emit("exit", 1);

    expect(existsSync(firstFile)).toBe(false);

    const second = createCodexTransport("/tmp/project", "linux");
    second.start("/tmp/project");
    const secondArgs = spawnMock.mock.calls[1]![1] as string[];
    const secondFile = secondArgs[secondArgs.indexOf("--ws-token-file") + 1]!;

    expect(secondFile).not.toBe(firstFile);
    expect(sockets[1]?.options?.headers.Authorization).not.toBe(firstHeader);
    stopManagedCodexAppServers();
    expect(existsSync(secondFile)).toBe(false);
  });

  it("removes a managed credential after synchronous spawn failure", () => {
    let tokenFilePath: string | undefined;
    spawnMock.mockImplementation((_command, args: string[]) => {
      tokenFilePath = args[args.indexOf("--ws-token-file") + 1];
      throw new Error("managed spawn failed");
    });
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "managed";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";

    expect(() => createCodexTransport("/tmp/project", "linux")).toThrow(
      "managed spawn failed",
    );
    expect(tokenFilePath).toBeDefined();
    expect(existsSync(tokenFilePath!)).toBe(false);
    expect(existsSync(dirname(tokenFilePath!))).toBe(false);
  });

  it("removes a managed credential after explicit and global shutdown", () => {
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "managed";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";

    const explicit = createCodexTransport("/tmp/project", "linux");
    explicit.start("/tmp/project");
    const explicitArgs = spawnMock.mock.calls[0]![1] as string[];
    const explicitFile = explicitArgs[explicitArgs.indexOf("--ws-token-file") + 1]!;
    stopManagedCodexAppServers();

    expect(existsSync(explicitFile)).toBe(false);
    expect(existsSync(dirname(explicitFile))).toBe(false);

    const global = createCodexTransport("/tmp/project", "linux");
    global.start("/tmp/project");
    const globalArgs = spawnMock.mock.calls[1]![1] as string[];
    const globalFile = globalArgs[globalArgs.indexOf("--ws-token-file") + 1]!;
    stopManagedCodexAppServers();

    expect(existsSync(globalFile)).toBe(false);
    expect(existsSync(dirname(globalFile))).toBe(false);
  });

  it("sends the managed bearer header again on retry", () => {
    vi.useFakeTimers();
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = "managed";
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18767";

    const transport = createCodexTransport("/tmp/project", "linux");
    transport.start("/tmp/project");
    const header = sockets[0]?.options?.headers.Authorization;
    sockets[0]!.emit("close");
    vi.advanceTimersByTime(100);

    expect(sockets[1]?.options?.headers.Authorization).toBe(header);
    transport.stop();
  });

  it("resolves an npm codex.cmd shim without interpolating managed arguments", () => {
    const shimDirectory = mkdtempSync(join(tmpdir(), "ccpocket-codex-shim-"));
    const shimPath = join(shimDirectory, "codex.cmd");
    const token = randomUUID();
    const tokenFilePath = "C:\\Temp Folder\\worker&replacement\\capability-token";
    writeFileSync(shimPath, "@echo off\r\n", "utf8");

    try {
      const spec = buildManagedCodexAppServerSpawnSpec(
        "C:\\Project Folder",
        "ws://127.0.0.1:18767",
        { token, tokenFilePath, cleanup: () => {} },
        "win32",
        {
          PATH: shimDirectory,
          PATHEXT: ".cmd",
          ComSpec: "C:\\Windows\\System32\\cmd.exe",
        },
      );

      expect(spec.command).toBe("C:\\Windows\\System32\\cmd.exe");
      expect(spec.args.slice(0, 4)).toEqual(["/d", "/s", "/v:off", "/c"]);
      const commandText = spec.args[4]!;
      expect(commandText).toContain("--ws-token-file");
      expect(commandText).not.toContain(tokenFilePath);
      expect(commandText).not.toContain(token);
      expect(spec.options.env.CCPOCKET_CODEX_MANAGED_COMMAND).toBe(shimPath);
      expect(spec.options.env.CCPOCKET_CODEX_MANAGED_TOKEN_FILE).toBe(tokenFilePath);
    } finally {
      rmSync(shimDirectory, { recursive: true, force: true });
    }
  });

  it("rejects a quote-bearing managed Windows URL before cmd expansion", () => {
    const shimDirectory = mkdtempSync(join(tmpdir(), "ccpocket-codex-shim-"));
    const shimPath = join(shimDirectory, "codex.cmd");
    const token = randomUUID();
    const tokenFilePath = "C:\\Temp Folder\\capability-token";
    writeFileSync(shimPath, "@echo off\r\n", "utf8");

    try {
      expect(() =>
        buildManagedCodexAppServerSpawnSpec(
          "C:\\Project Folder",
          'ws://127.0.0.1:18767/"&whoami',
          { token, tokenFilePath, cleanup: () => {} },
          "win32",
          { PATH: shimDirectory, PATHEXT: ".cmd" },
        ),
      ).toThrow("managed Codex app-server URL");
    } finally {
      rmSync(shimDirectory, { recursive: true, force: true });
    }
  });

  it("skips unsupported PATHEXT entries before resolving codex.cmd", () => {
    const shimDirectory = mkdtempSync(join(tmpdir(), "ccpocket-codex-shim-"));
    const unsupportedPath = join(shimDirectory, "codex.ps1");
    const shimPath = join(shimDirectory, "codex.cmd");
    writeFileSync(unsupportedPath, "exit 0\r\n", "utf8");
    writeFileSync(shimPath, "@echo off\r\n", "utf8");

    try {
      const spec = buildManagedCodexAppServerSpawnSpec(
        "C:\\Project Folder",
        "ws://127.0.0.1:18767",
        { token: randomUUID(), tokenFilePath: "C:\\Temp\\token", cleanup: () => {} },
        "win32",
        {
          PATH: shimDirectory,
          PATHEXT: ".ps1;.cmd",
          ComSpec: "C:\\Windows\\System32\\cmd.exe",
        },
      );

      expect(spec.command).toBe("C:\\Windows\\System32\\cmd.exe");
      expect(spec.options.env.CCPOCKET_CODEX_MANAGED_COMMAND).toBe(shimPath);
    } finally {
      rmSync(shimDirectory, { recursive: true, force: true });
    }
  });

  it.each([".exe", ".com"])("launches native codex%s directly", (extension) => {
    const executableDirectory = mkdtempSync(join(tmpdir(), "ccpocket-codex-native-"));
    const executablePath = join(executableDirectory, `codex${extension}`);
    const token = randomUUID();
    const tokenFilePath = "C:\\Temp Folder\\capability-token";
    writeFileSync(executablePath, "", "utf8");

    try {
      const spec = buildManagedCodexAppServerSpawnSpec(
        "C:\\Project Folder",
        "ws://127.0.0.1:18767",
        { token, tokenFilePath, cleanup: () => {} },
        "win32",
        { PATH: executableDirectory, PATHEXT: extension },
      );

      expect(spec.command).toBe(executablePath);
      expect(spec.args).toEqual([
        "app-server",
        "--listen",
        "ws://127.0.0.1:18767",
        "--ws-auth",
        "capability-token",
        "--ws-token-file",
        tokenFilePath,
      ]);
      expect(spec.args).not.toContain(token);
      expect(spec.options.windowsVerbatimArguments).toBeUndefined();
    } finally {
      rmSync(executableDirectory, { recursive: true, force: true });
    }
  });

  it("fails closed when PATHEXT contains only unsupported script types", () => {
    const executableDirectory = mkdtempSync(join(tmpdir(), "ccpocket-codex-script-"));
    writeFileSync(join(executableDirectory, "codex.ps1"), "exit 0\r\n", "utf8");

    try {
      expect(() =>
        buildManagedCodexAppServerSpawnSpec(
          "C:\\Project Folder",
          "ws://127.0.0.1:18767",
          {
            token: randomUUID(),
            tokenFilePath: "C:\\Temp\\capability-token",
            cleanup: () => {},
          },
          "win32",
          { PATH: executableDirectory, PATHEXT: ".ps1" },
        ),
      ).toThrow("Codex CLI executable");
    } finally {
      rmSync(executableDirectory, { recursive: true, force: true });
    }
  });

  it("fails closed without a Windows Codex executable or shim", () => {
    const token = randomUUID();
    const tokenFilePath = "C:\\Temp Folder\\worker&replacement\\capability-token";
    let message = "";

    try {
      buildManagedCodexAppServerSpawnSpec(
        "C:\\Project Folder",
        "ws://127.0.0.1:18767",
        { token, tokenFilePath, cleanup: () => {} },
        "win32",
        { PATH: "", PATHEXT: ".exe;.cmd" },
      );
    } catch (error) {
      message = (error as Error).message;
    }

    expect(message).toContain("Codex CLI executable");
    expect(message).not.toContain(token);
    expect(message).not.toContain(tokenFilePath);
  });
});
