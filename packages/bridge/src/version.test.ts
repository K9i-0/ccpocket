import { readFileSync } from "node:fs";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { getPackageVersion, getVersionInfo, type VersionInfo } from "./version.js";

describe("getVersionInfo", () => {
  const mockStartedAt = new Date("2026-02-11T10:00:00.000Z").getTime();

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-02-11T11:00:00.000Z")); // 1 hour later
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns node version in expected format", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.nodeVersion).toMatch(/^v\d+\.\d+\.\d+/);
  });

  it("returns current platform", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.platform).toBe(process.platform);
  });

  it("returns current arch", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.arch).toBe(process.arch);
  });

  it("calculates uptime correctly", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.uptime).toBe(3600); // 1 hour = 3600 seconds
  });

  it("returns ISO formatted startedAt", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.startedAt).toBe("2026-02-11T10:00:00.000Z");
  });

  it("includes git info when available (in git repo)", () => {
    const info = getVersionInfo(mockStartedAt);
    // In a git repo, these should be present
    if (info.gitCommit) {
      expect(info.gitCommit).toMatch(/^[a-f0-9]{7,}$/);
    }
    if (info.gitBranch) {
      expect(typeof info.gitBranch).toBe("string");
      expect(info.gitBranch.length).toBeGreaterThan(0);
    }
  });

  it("returns all required fields", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info).toHaveProperty("version");
    expect(info).toMatchObject({
      protocolVersion: 1,
      minimumProtocolVersion: 1,
    });
    expect(info).toHaveProperty("nodeVersion");
    expect(info).toHaveProperty("platform");
    expect(info).toHaveProperty("arch");
    expect(info).toHaveProperty("startedAt");
    expect(info).toHaveProperty("uptime");
  });
});

describe("package version", () => {
  it("reports the version from the Bridge package.json", () => {
    const packageJson = JSON.parse(
      readFileSync(new URL("../package.json", import.meta.url), "utf-8"),
    ) as { version: string };
    expect(packageJson.version).toMatch(/^\d+\.\d+\.\d+/);
    expect(getPackageVersion()).toBe(packageJson.version);
    expect(getVersionInfo(Date.now()).version).toBe(packageJson.version);
  });
});

// Git info is captured once at module load, so each case loads a fresh copy of
// the module with `git` replaced; nothing depends on the real repository.
describe("git info", () => {
  const execSync = vi.fn();

  async function loadVersionInfo(): Promise<VersionInfo> {
    vi.resetModules();
    vi.doMock("node:child_process", () => ({ execSync }));
    const mod = await import("./version.js");
    return mod.getVersionInfo(Date.now());
  }

  afterEach(() => {
    vi.doUnmock("node:child_process");
    vi.resetModules();
    execSync.mockReset();
  });

  it("reports the trimmed commit and branch from git", async () => {
    execSync.mockImplementation((command: string) =>
      command.includes("--abbrev-ref") ? "feature/x\n" : " abc1234\n",
    );

    const info = await loadVersionInfo();

    expect(info).toMatchObject({ gitCommit: "abc1234", gitBranch: "feature/x" });
    // Text output, and no git error output leaking into the Bridge log.
    const options = { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] };
    expect(execSync.mock.calls).toEqual([
      ["git rev-parse --short HEAD", options],
      ["git rev-parse --abbrev-ref HEAD", options],
    ]);
    // Only the documented fields are added.
    expect(Object.keys(info).sort()).toEqual([
      "arch", "gitBranch", "gitCommit", "minimumProtocolVersion", "nodeVersion",
      "platform", "protocolVersion", "startedAt", "uptime", "version",
    ]);
  });

  it("omits git fields outside a git repository", async () => {
    execSync.mockImplementation(() => {
      throw new Error("fatal: not a git repository");
    });

    const info = await loadVersionInfo();

    expect(info).not.toHaveProperty("gitCommit");
    expect(info).not.toHaveProperty("gitBranch");
    expect(info.version).toMatch(/^\d+\.\d+\.\d+/);
  });

  it("omits git fields when git prints nothing", async () => {
    execSync.mockReturnValue("\n");

    const info = await loadVersionInfo();

    expect("gitCommit" in info).toBe(false);
    expect("gitBranch" in info).toBe(false);
  });
});
