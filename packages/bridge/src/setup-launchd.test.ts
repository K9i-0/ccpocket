import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

const mockExecSync = vi.fn();
vi.mock("node:child_process", () => ({
  execSync: (...args: unknown[]) => mockExecSync(...args),
}));

const mockExistsSync = vi.fn();
const mockMkdirSync = vi.fn();
const mockWriteFileSync = vi.fn();
const mockUnlinkSync = vi.fn();
vi.mock("node:fs", () => ({
  existsSync: (...args: unknown[]) => mockExistsSync(...args),
  mkdirSync: (...args: unknown[]) => mockMkdirSync(...args),
  writeFileSync: (...args: unknown[]) => mockWriteFileSync(...args),
  unlinkSync: (...args: unknown[]) => mockUnlinkSync(...args),
}));

vi.mock("node:os", () => ({
  homedir: () => "/Users/testuser",
}));

const { setupLaunchd, uninstallLaunchd } = await import("./setup-launchd.js");

const PLIST_PATH = "/Users/testuser/Library/LaunchAgents/com.ccpocket.bridge.plist";
const originalBridgeEnv = {
  publicWsUrl: process.env.BRIDGE_PUBLIC_WS_URL,
  codexAppServerMode: process.env.BRIDGE_CODEX_APP_SERVER_MODE,
  codexAppServerPort: process.env.BRIDGE_CODEX_APP_SERVER_PORT,
  codexAppServerUrl: process.env.BRIDGE_CODEX_APP_SERVER_URL,
};

describe("setup-launchd", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    clearBridgeEnv();
    mockExistsSync.mockReturnValue(true);
    mockExecSync.mockReturnValue("/usr/bin/npx\n");
  });

  afterEach(() => {
    restoreBridgeEnv();
  });

  describe("setupLaunchd", () => {
    it("writes correct plist with default options", () => {
      setupLaunchd({});

      expect(mockWriteFileSync).toHaveBeenCalledOnce();
      const [path, content] = mockWriteFileSync.mock.calls[0] as [string, string];
      expect(path).toBe(PLIST_PATH);
      expect(content).toContain("<key>BRIDGE_PORT</key>");
      expect(content).toContain("<string>8765</string>");
      expect(content).toContain("<key>BRIDGE_HOST</key>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_MODE</key>");
      expect(content).toContain("<string>managed</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_PORT</key>");
      expect(content).toContain("<string>8767</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:8767</string>");
      expect(content).toContain(
        "<string>exec npx --yes @ccpocket/bridge@latest</string>",
      );
      expect(content).not.toContain("BRIDGE_API_KEY");
      expect(content).not.toContain("BRIDGE_PUBLIC_WS_URL");
    });

    it("includes BRIDGE_PUBLIC_WS_URL when publicWsUrl is provided", () => {
      setupLaunchd({ publicWsUrl: "wss://example.com/ws" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_PUBLIC_WS_URL</key>");
      expect(content).toContain("<string>wss://example.com/ws</string>");
    });

    it("prefers explicit publicWsUrl over environment", () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://env.example.com";

      setupLaunchd({ publicWsUrl: "wss://flag.example.com" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<string>wss://flag.example.com</string>");
      expect(content).not.toContain("wss://env.example.com");
    });

    it("includes explicit Codex app-server startup options", () => {
      setupLaunchd({
        codexAppServerMode: "external",
        codexAppServerPort: "18766",
        codexAppServerUrl: "ws://127.0.0.1:18766",
      });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_MODE</key>");
      expect(content).toContain("<string>external</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_PORT</key>");
      expect(content).toContain("<string>18766</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:18766</string>");
    });

    it("leaves the documented test Bridge port free by default", () => {
      setupLaunchd({ port: "8765" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_PORT</key>");
      expect(content).toContain("<string>8765</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_PORT</key>");
      expect(content).toContain("<string>8767</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:8767</string>");
    });

    it("moves the default Codex app-server port when Bridge uses 8767", () => {
      setupLaunchd({ port: "8767" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_PORT</key>");
      expect(content).toContain("<string>8767</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_PORT</key>");
      expect(content).toContain("<string>8768</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:8768</string>");
    });
  });

  describe("uninstallLaunchd", () => {
    it("deletes plist when it exists", () => {
      mockExistsSync.mockReturnValue(true);

      uninstallLaunchd();

      expect(mockUnlinkSync).toHaveBeenCalledWith(PLIST_PATH);
    });
  });
});

function clearBridgeEnv(): void {
  delete process.env.BRIDGE_PUBLIC_WS_URL;
  delete process.env.BRIDGE_CODEX_APP_SERVER_MODE;
  delete process.env.BRIDGE_CODEX_APP_SERVER_PORT;
  delete process.env.BRIDGE_CODEX_APP_SERVER_URL;
}

function restoreBridgeEnv(): void {
  restoreEnvVar("BRIDGE_PUBLIC_WS_URL", originalBridgeEnv.publicWsUrl);
  restoreEnvVar(
    "BRIDGE_CODEX_APP_SERVER_MODE",
    originalBridgeEnv.codexAppServerMode,
  );
  restoreEnvVar(
    "BRIDGE_CODEX_APP_SERVER_PORT",
    originalBridgeEnv.codexAppServerPort,
  );
  restoreEnvVar(
    "BRIDGE_CODEX_APP_SERVER_URL",
    originalBridgeEnv.codexAppServerUrl,
  );
}

function restoreEnvVar(key: string, value: string | undefined): void {
  if (value === undefined) {
    delete process.env[key];
    return;
  }
  process.env[key] = value;
}
