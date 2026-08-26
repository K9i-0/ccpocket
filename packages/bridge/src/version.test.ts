import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import {
  BRIDGE_PROTOCOL_MODE,
  getBridgeGeneration,
  getPackageVersion,
  getVersionInfo,
  loadRuntimeManifest,
  type VersionInfo,
} from "./version.js";

const SYNTHETIC_MANIFEST = {
  schema: "ccpocket-bridge-runtime-manifest/v1",
  packageVersion: getPackageVersion(),
  upstreamVersion: getPackageVersion(),
  upstreamTag: `bridge/v${getPackageVersion()}`,
  upstreamCommit: "a".repeat(40),
  patchCommit: "b".repeat(40),
  patchTreeSha256: "c".repeat(64),
  releaseId: `release-${getPackageVersion()}-test`,
  protocolMode: "http+websocket",
  readinessSchema: "ccpocket-bridge-readiness/v1",
};
const MANIFEST_WITH_MISSING_FIELD: Record<string, unknown> = {
  ...SYNTHETIC_MANIFEST,
};
delete MANIFEST_WITH_MISSING_FIELD.patchCommit;

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
    expect(info).toHaveProperty("nodeVersion");
    expect(info).toHaveProperty("platform");
    expect(info).toHaveProperty("arch");
    expect(info).toHaveProperty("startedAt");
    expect(info).toHaveProperty("uptime");
  });
});

describe("runtime identity", () => {
  it("uses the package version and one stable UUID generation per process", () => {
    const packageJson = JSON.parse(
      readFileSync(new URL("../package.json", import.meta.url), "utf8"),
    ) as { version: string };

    expect(getPackageVersion()).toBe(packageJson.version);
    expect(getBridgeGeneration()).toBe(getBridgeGeneration());
    expect(getBridgeGeneration()).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    expect(BRIDGE_PROTOCOL_MODE).toBe("http+websocket");
  });

  it("keeps CLI --version equal to the package version", () => {
    const cliPath = new URL("./cli.ts", import.meta.url);
    const output = execFileSync(
      process.execPath,
      ["--import", "tsx", cliPath.pathname, "--version"],
      { encoding: "utf8" },
    ).trim();

    expect(output).toBe(`ccpocket-bridge ${getPackageVersion()}`);
  });

  it("uses a different generation in each fresh Node process", () => {
    const moduleUrl = new URL("./version.ts", import.meta.url).href;
    const script = `import { getBridgeGeneration } from ${JSON.stringify(moduleUrl)}; process.stdout.write(getBridgeGeneration());`;
    const generation = () =>
      execFileSync(
        process.execPath,
        ["--import", "tsx", "--input-type=module", "--eval", script],
        { encoding: "utf8" },
      );

    expect(generation()).not.toBe(generation());
  });
});

describe("loadRuntimeManifest", () => {
  const temporaryPaths: string[] = [];

  afterEach(() => {
    for (const path of temporaryPaths.splice(0)) {
      rmSync(path, { recursive: true, force: true });
    }
  });

  function writeManifest(value: unknown): string {
    const dir = mkdtempSync(join(tmpdir(), "ccpocket-runtime-manifest-"));
    temporaryPaths.push(dir);
    const path = join(dir, "RUNTIME_MANIFEST.json");
    writeFileSync(path, JSON.stringify(value));
    return path;
  }

  it("accepts and allowlists the exact immutable manifest schema", () => {
    const path = writeManifest(SYNTHETIC_MANIFEST);
    expect(loadRuntimeManifest({ BRIDGE_RUNTIME_MANIFEST: path })).toEqual(
      SYNTHETIC_MANIFEST,
    );
  });

  it.each([
    ["missing path", undefined, SYNTHETIC_MANIFEST],
    ["relative path", "relative.json", SYNTHETIC_MANIFEST],
    ["unreadable path", join(tmpdir(), "missing-ccpocket-manifest.json"), SYNTHETIC_MANIFEST],
    ["unknown schema", null, { ...SYNTHETIC_MANIFEST, schema: "unknown" }],
    ["unknown field", null, { ...SYNTHETIC_MANIFEST, protectedPayload: "sentinel" }],
    ["missing required field", null, MANIFEST_WITH_MISSING_FIELD],
    ["package mismatch", null, { ...SYNTHETIC_MANIFEST, packageVersion: "9.9.9" }],
    ["upstream mismatch", null, { ...SYNTHETIC_MANIFEST, upstreamVersion: "1.72.0" }],
    ["tag mismatch", null, { ...SYNTHETIC_MANIFEST, upstreamTag: "bridge/v1.72.0" }],
    ["short upstream commit", null, { ...SYNTHETIC_MANIFEST, upstreamCommit: "a".repeat(39) }],
    ["uppercase patch commit", null, { ...SYNTHETIC_MANIFEST, patchCommit: "B".repeat(40) }],
    ["short tree hash", null, { ...SYNTHETIC_MANIFEST, patchTreeSha256: "c".repeat(63) }],
    ["invalid release id", null, { ...SYNTHETIC_MANIFEST, releaseId: "bad release" }],
    ["protocol mismatch", null, { ...SYNTHETIC_MANIFEST, protocolMode: "websocket" }],
    ["readiness mismatch", null, { ...SYNTHETIC_MANIFEST, readinessSchema: "unknown" }],
  ])("rejects %s", (_label, explicitPath, manifest) => {
    const path = explicitPath === null ? writeManifest(manifest) : explicitPath;
    expect(() =>
      loadRuntimeManifest({ BRIDGE_RUNTIME_MANIFEST: path }),
    ).toThrow();
  });

  it("rejects malformed JSON", () => {
    const path = writeManifest(SYNTHETIC_MANIFEST);
    writeFileSync(path, "{");
    expect(() => loadRuntimeManifest({ BRIDGE_RUNTIME_MANIFEST: path })).toThrow();
  });
});
