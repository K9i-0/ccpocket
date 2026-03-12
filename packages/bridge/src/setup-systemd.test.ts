import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock child_process before importing the module
const mockExecSync = vi.fn();
vi.mock("node:child_process", () => ({
  execSync: (...args: unknown[]) => mockExecSync(...args),
}));

// Mock node:fs
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

// Mock node:os
vi.mock("node:os", () => ({
  homedir: () => "/home/testuser",
}));

// Import after mocks
const { setupSystemd, uninstallSystemd } = await import("./setup-systemd.js");

const SERVICE_PATH =
  "/home/testuser/.config/systemd/user/ccpocket-bridge.service";

describe("setup-systemd", () => {
  const originalPlatform = process.platform;

  beforeEach(() => {
    vi.clearAllMocks();
    Object.defineProperty(process, "platform", { value: "linux" });
    // Default: directory exists, npx found
    mockExistsSync.mockReturnValue(true);
    mockExecSync.mockReturnValue("/usr/bin/npx\n");
  });

  afterEach(() => {
    Object.defineProperty(process, "platform", { value: originalPlatform });
  });

  describe("setupSystemd", () => {
    it("writes correct service file with default options", () => {
      setupSystemd({});

      expect(mockWriteFileSync).toHaveBeenCalledOnce();
      const [path, content] = mockWriteFileSync.mock.calls[0] as [
        string,
        string,
      ];
      expect(path).toBe(SERVICE_PATH);
      expect(content).toContain("[Unit]");
      expect(content).toContain("Description=CC Pocket Bridge Server");
      expect(content).toContain(
        "ExecStart=/usr/bin/npx @ccpocket/bridge@latest",
      );
      expect(content).toContain(
        "Environment=PATH=/usr/bin:/usr/local/bin:/usr/bin:/bin",
      );
      expect(content).toContain("Environment=BRIDGE_PORT=8765");
      expect(content).toContain("Environment=BRIDGE_HOST=0.0.0.0");
      expect(content).toContain("Restart=on-failure");
      expect(content).toContain("WantedBy=default.target");
      expect(content).not.toContain("BRIDGE_API_KEY");
    });

    it("includes BRIDGE_API_KEY when apiKey is provided", () => {
      setupSystemd({ apiKey: "my-secret" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("Environment=BRIDGE_API_KEY=my-secret");
    });

    it("omits BRIDGE_API_KEY when apiKey is empty", () => {
      setupSystemd({ apiKey: "" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).not.toContain("BRIDGE_API_KEY");
    });

    it("uses custom port and host", () => {
      setupSystemd({ port: "9999", host: "127.0.0.1" });

      const content = mockWriteFileSync.mock.calls[0]![1] as string;
      expect(content).toContain("Environment=BRIDGE_PORT=9999");
      expect(content).toContain("Environment=BRIDGE_HOST=127.0.0.1");
    });

    it("creates directory when it does not exist", () => {
      mockExistsSync.mockImplementation((p: string) => {
        if (p.includes("systemd/user")) return false;
        return true;
      });

      setupSystemd({});

      expect(mockMkdirSync).toHaveBeenCalledWith(
        "/home/testuser/.config/systemd/user",
        { recursive: true },
      );
    });

    it("calls systemctl daemon-reload, enable, and restart in order", () => {
      setupSystemd({});

      const systemctlCalls = mockExecSync.mock.calls
        .map((c) => c[0] as string)
        .filter((cmd: string) => cmd.includes("systemctl"));

      expect(systemctlCalls).toEqual([
        "systemctl --user daemon-reload",
        'systemctl --user enable "ccpocket-bridge"',
        'systemctl --user restart "ccpocket-bridge"',
      ]);
    });

    it("enables linger when not already enabled", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "command -v npx") return "/usr/bin/npx\n";
        if (cmd.includes("show-user")) return "Linger=no\n";
        return "";
      });

      setupSystemd({});

      const allCmds = mockExecSync.mock.calls.map((c) => c[0] as string);
      expect(allCmds).toContain("loginctl enable-linger $USER");
    });

    it("skips linger when already enabled", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "command -v npx") return "/usr/bin/npx\n";
        if (cmd.includes("show-user")) return "Linger=yes\n";
        return "";
      });

      setupSystemd({});

      const allCmds = mockExecSync.mock.calls.map((c) => c[0] as string);
      expect(allCmds).not.toContain("loginctl enable-linger $USER");
    });

    it("handles linger check failure gracefully", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "command -v npx") return "/usr/bin/npx\n";
        if (cmd.includes("loginctl")) throw new Error("loginctl failed");
        return "";
      });

      expect(() => setupSystemd({})).not.toThrow();
    });

    it("exits with code 1 when npx is not found", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "command -v npx") throw new Error("not found");
        return "";
      });

      const mockExit = vi
        .spyOn(process, "exit")
        .mockImplementation(() => undefined as never);

      setupSystemd({});

      expect(mockExit).toHaveBeenCalledWith(1);
      mockExit.mockRestore();
    });
  });

  describe("uninstallSystemd", () => {
    it("calls stop, disable, deletes file, and daemon-reload", () => {
      mockExistsSync.mockReturnValue(true);

      uninstallSystemd();

      const allCmds = mockExecSync.mock.calls.map((c) => c[0] as string);
      expect(allCmds).toContain(
        'systemctl --user stop "ccpocket-bridge"',
      );
      expect(allCmds).toContain(
        'systemctl --user disable "ccpocket-bridge"',
      );
      expect(allCmds).toContain("systemctl --user daemon-reload");
      expect(mockUnlinkSync).toHaveBeenCalledWith(SERVICE_PATH);
    });

    it("does not delete file when it does not exist", () => {
      mockExistsSync.mockImplementation((p: string) => {
        if (p.endsWith(".service")) return false;
        return true;
      });

      uninstallSystemd();

      expect(mockUnlinkSync).not.toHaveBeenCalled();
    });

    it("handles systemctl errors gracefully", () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("systemctl failed");
      });
      mockExistsSync.mockReturnValue(false);

      expect(() => uninstallSystemd()).not.toThrow();
    });
  });
});
