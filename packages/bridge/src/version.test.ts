import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { getVersionInfo, type VersionInfo } from "./version.js";

describe("getVersionInfo", () => {
  const mockStartedAt = new Date("2026-02-11T10:00:00.000Z").getTime();

  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-02-11T11:00:00.000Z")); // 1 hour later
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("returns version from package.json", () => {
    const info = getVersionInfo(mockStartedAt);
    expect(info.version).toBe("0.1.0");
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
    expect(info).toHaveProperty("nodeVersion");
    expect(info).toHaveProperty("platform");
    expect(info).toHaveProperty("arch");
    expect(info).toHaveProperty("startedAt");
    expect(info).toHaveProperty("uptime");
  });
});
