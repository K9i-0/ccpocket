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
  allowedDirs: process.env.BRIDGE_ALLOWED_DIRS,
  publicWsUrl: process.env.BRIDGE_PUBLIC_WS_URL,
  disableMdns: process.env.BRIDGE_DISABLE_MDNS,
  codexAppServerMode: process.env.BRIDGE_CODEX_APP_SERVER_MODE,
  codexSharedAppServerUrl: process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL,
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
      expect(content).toContain(
        "<string>exec npx --yes @ccpocket/bridge@latest</string>",
      );
      expect(content).not.toContain("BRIDGE_API_KEY");
      expect(content).not.toContain("BRIDGE_ALLOWED_DIRS");
      expect(content).not.toContain("BRIDGE_PUBLIC_WS_URL");
      expect(content).not.toContain("BRIDGE_DISABLE_MDNS");
      expect(content).not.toContain("BRIDGE_CODEX_APP_SERVER_MODE");
      expect(content).not.toContain("BRIDGE_CODEX_SHARED_APP_SERVER_URL");
    });

    it("includes BRIDGE_ALLOWED_DIRS when provided", () => {
      process.env.BRIDGE_ALLOWED_DIRS = "/Users/testuser,/tmp/work";

      setupLaunchd({});

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_ALLOWED_DIRS</key>");
      expect(content).toContain("<string>/Users/testuser,/tmp/work</string>");
    });

    it("includes BRIDGE_DISABLE_MDNS when requested", () => {
      setupLaunchd({ disableMdns: true });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_DISABLE_MDNS</key>");
      expect(content).toContain("<string>1</string>");
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

    it("does not persist shared app-server URL without an explicit mode", () => {
      process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = "ws://127.0.0.1:18766";

      setupLaunchd({});

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).not.toContain("BRIDGE_CODEX_APP_SERVER_MODE");
      expect(content).not.toContain("BRIDGE_CODEX_SHARED_APP_SERVER_URL");
    });

    it("includes explicit Codex app-server startup options", () => {
      setupLaunchd({
        codexAppServerMode: "external",
        codexSharedAppServerUrl: "ws://127.0.0.1:18766",
      });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_MODE</key>");
      expect(content).toContain("<string>external</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_SHARED_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:18766</string>");
      expect(content).not.toContain("BRIDGE_CODEX_APP_SERVER_PORT");
      expect(content).not.toContain("BRIDGE_CODEX_APP_SERVER_URL");
    });

    it("requires a shared app-server URL for external mode", () => {
      expect(() => setupLaunchd({ codexAppServerMode: "external" })).toThrow(
        "BRIDGE_CODEX_SHARED_APP_SERVER_URL is required",
      );
    });

    it("uses the documented default shared URL when managed mode is enabled", () => {
      setupLaunchd({ port: "8765", codexAppServerMode: "managed" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_PORT</key>");
      expect(content).toContain("<string>8765</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_APP_SERVER_MODE</key>");
      expect(content).toContain("<string>managed</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_SHARED_APP_SERVER_URL</key>");
      expect(content).toContain("<string>ws://127.0.0.1:8767</string>");
    });

    it("moves the default shared app-server URL when Bridge uses 8767", () => {
      setupLaunchd({ port: "8767", codexAppServerMode: "managed" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("<key>BRIDGE_PORT</key>");
      expect(content).toContain("<string>8767</string>");
      expect(content).toContain("<key>BRIDGE_CODEX_SHARED_APP_SERVER_URL</key>");
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
  delete process.env.BRIDGE_ALLOWED_DIRS;
  delete process.env.BRIDGE_PUBLIC_WS_URL;
  delete process.env.BRIDGE_DISABLE_MDNS;
  delete process.env.BRIDGE_CODEX_APP_SERVER_MODE;
  delete process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL;
  delete process.env.BRIDGE_CODEX_APP_SERVER_PORT;
  delete process.env.BRIDGE_CODEX_APP_SERVER_URL;
}

function restoreBridgeEnv(): void {
  restoreEnvVar("BRIDGE_ALLOWED_DIRS", originalBridgeEnv.allowedDirs);
  restoreEnvVar("BRIDGE_PUBLIC_WS_URL", originalBridgeEnv.publicWsUrl);
  restoreEnvVar("BRIDGE_DISABLE_MDNS", originalBridgeEnv.disableMdns);
  restoreEnvVar(
    "BRIDGE_CODEX_APP_SERVER_MODE",
    originalBridgeEnv.codexAppServerMode,
  );
  restoreEnvVar(
    "BRIDGE_CODEX_SHARED_APP_SERVER_URL",
    originalBridgeEnv.codexSharedAppServerUrl,
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
