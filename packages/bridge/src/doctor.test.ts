import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import type { CheckResult, ProviderResult, DoctorReport } from "./doctor.js";

// Mock child_process before importing the module
const mockExecSync = vi.fn();
vi.mock("node:child_process", () => ({
  execSync: (...args: unknown[]) => mockExecSync(...args),
}));

// Mock node:fs
const mockExistsSync = vi.fn();
const mockAccessSync = vi.fn();
vi.mock("node:fs", () => ({
  existsSync: (...args: unknown[]) => mockExistsSync(...args),
  accessSync: (...args: unknown[]) => mockAccessSync(...args),
  constants: { R_OK: 4, W_OK: 2 },
}));

// Import after mocks
const {
  checkNodeVersion,
  checkGit,
  checkCliProviders,
  checkDependencies,
  checkPortAvailable,
  checkTailscale,
  checkDataDirectory,
  checkLaunchdService,
  printReport,
  runDoctor,
} = await import("./doctor.js");

describe("doctor checks", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("checkNodeVersion", () => {
    it("passes on current Node.js version (>=18)", async () => {
      const result = await checkNodeVersion();
      expect(result.status).toBe("pass");
      expect(result.message).toMatch(/^v\d+/);
    });
  });

  describe("checkGit", () => {
    it("passes when git is installed", async () => {
      mockExecSync.mockReturnValue("git version 2.44.0");
      const result = await checkGit();
      expect(result.status).toBe("pass");
      expect(result.message).toContain("2.44.0");
    });

    it("fails when git is not installed", async () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("command not found");
      });
      const result = await checkGit();
      expect(result.status).toBe("fail");
      expect(result.remediation).toBeDefined();
    });
  });

  describe("checkCliProviders", () => {
    it("passes when both CLIs are installed and authenticated", async () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "claude --version") return "1.0.23";
        if (cmd === "claude auth status") return "Logged in";
        if (cmd === "codex --version") return "0.104.0";
        return "";
      });
      const originalEnv = process.env.OPENAI_API_KEY;
      process.env.OPENAI_API_KEY = "test-key";
      try {
        const result = await checkCliProviders();
        expect(result.status).toBe("pass");
        expect(result.message).toBe("2 of 2 available");
        expect(result.providers).toHaveLength(2);
      } finally {
        if (originalEnv === undefined) delete process.env.OPENAI_API_KEY;
        else process.env.OPENAI_API_KEY = originalEnv;
      }
    });

    it("passes when only Claude Code is installed", async () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "claude --version") return "1.0.23";
        if (cmd === "claude auth status") return "Logged in";
        throw new Error("command not found");
      });
      const result = await checkCliProviders();
      expect(result.status).toBe("pass");
      expect(result.message).toBe("1 of 2 available");
    });

    it("passes when only Codex is installed", async () => {
      const originalEnv = process.env.OPENAI_API_KEY;
      process.env.OPENAI_API_KEY = "test-key";
      try {
        mockExecSync.mockImplementation((cmd: string) => {
          if (cmd === "codex --version") return "0.104.0";
          throw new Error("command not found");
        });
        const result = await checkCliProviders();
        expect(result.status).toBe("pass");
        expect(result.message).toBe("1 of 2 available");
      } finally {
        if (originalEnv === undefined) delete process.env.OPENAI_API_KEY;
        else process.env.OPENAI_API_KEY = originalEnv;
      }
    });

    it("fails when neither CLI is installed", async () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("command not found");
      });
      const result = await checkCliProviders();
      expect(result.status).toBe("fail");
      expect(result.remediation).toContain("Install at least one:");
    });

    it("warns when CLI is installed but not authenticated", async () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "claude --version") return "1.0.23";
        if (cmd === "claude auth status") return "not logged in";
        throw new Error("command not found");
      });
      const result = await checkCliProviders();
      expect(result.status).toBe("warn");
      const claude = result.providers.find((p: ProviderResult) => p.name === "Claude Code CLI");
      expect(claude?.installed).toBe(true);
      expect(claude?.authenticated).toBe(false);
    });
  });

  describe("checkPortAvailable", () => {
    it("passes when port is available", async () => {
      const result = await checkPortAvailable(0); // port 0 = random available
      expect(result.status).toBe("pass");
    });
  });

  describe("checkTailscale", () => {
    it("passes when tailscale is connected", async () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd.includes("tailscale version")) return "1.62.0";
        if (cmd.includes("tailscale status")) return "100.64.1.2  myhost  linux  -";
        throw new Error("unknown");
      });
      const result = await checkTailscale();
      expect(result.status).toBe("pass");
      expect(result.message).toContain("100.64.1.2");
    });

    it("warns when tailscale is installed but not connected", async () => {
      mockExecSync.mockImplementation((cmd: string) => {
        // tailscaleCmd() finds the binary via `tailscale version`
        if (cmd.includes("tailscale version")) return "1.62.0";
        // but `tailscale status` fails (not connected)
        if (cmd.includes("tailscale status")) throw new Error("not running");
        throw new Error("unknown");
      });
      const result = await checkTailscale();
      expect(result.status).toBe("warn");
    });

    it("skips when tailscale is not installed", async () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("command not found");
      });
      mockExistsSync.mockReturnValue(false); // macOS app path doesn't exist either
      const result = await checkTailscale();
      expect(result.status).toBe("skip");
    });
  });

  describe("checkDataDirectory", () => {
    it("passes when directory exists and is writable", async () => {
      mockExistsSync.mockReturnValue(true);
      mockAccessSync.mockReturnValue(undefined);
      const result = await checkDataDirectory();
      expect(result.status).toBe("pass");
      expect(result.message).toContain("exists");
    });

    it("passes when directory does not exist (will be created)", async () => {
      mockExistsSync.mockReturnValue(false);
      const result = await checkDataDirectory();
      expect(result.status).toBe("pass");
      expect(result.message).toContain("will be created");
    });

    it("warns when directory is not writable", async () => {
      mockExistsSync.mockReturnValue(true);
      mockAccessSync.mockImplementation(() => {
        throw new Error("EACCES");
      });
      const result = await checkDataDirectory();
      expect(result.status).toBe("warn");
    });
  });

  describe("printReport", () => {
    it("does not throw for a basic report", () => {
      const report: DoctorReport = {
        results: [
          { name: "Node.js", status: "pass", message: "v22.0.0", category: "required" },
          { name: "Git", status: "fail", message: "Not installed", remediation: "Install Git", category: "required" },
          { name: "Tailscale", status: "skip", message: "Not installed", category: "optional" },
        ],
        allRequiredPassed: false,
      };
      expect(() => printReport(report)).not.toThrow();
    });

    it("handles report with providers", () => {
      const report: DoctorReport = {
        results: [
          {
            name: "CLI providers",
            status: "pass",
            message: "2 of 2 available",
            category: "required",
            providers: [
              { name: "Claude Code CLI", installed: true, version: "1.0.0", authenticated: true },
              { name: "Codex CLI", installed: false, authenticated: false, remediation: "Install Codex" },
            ],
          },
        ],
        allRequiredPassed: true,
      };
      expect(() => printReport(report)).not.toThrow();
    });
  });
});
