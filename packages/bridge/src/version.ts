import { execSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, isAbsolute, join } from "node:path";

// Read package.json version at module load time
const __dirname = dirname(fileURLToPath(import.meta.url));
const packagePath = join(__dirname, "..", "package.json");
const packageJson = JSON.parse(readFileSync(packagePath, "utf-8"));
const bridgeGeneration = randomUUID();

export const BRIDGE_PROTOCOL_MODE = "http+websocket" as const;
export const BRIDGE_READINESS_SCHEMA = "ccpocket-bridge-readiness/v1" as const;
export const BRIDGE_RUNTIME_MANIFEST_SCHEMA =
  "ccpocket-bridge-runtime-manifest/v1" as const;

export interface RuntimeManifest {
  schema: typeof BRIDGE_RUNTIME_MANIFEST_SCHEMA;
  packageVersion: string;
  upstreamVersion: string;
  upstreamTag: string;
  upstreamCommit: string;
  patchCommit: string;
  patchTreeSha256: string;
  releaseId: string;
  protocolMode: typeof BRIDGE_PROTOCOL_MODE;
  readinessSchema: typeof BRIDGE_READINESS_SCHEMA;
}

const RUNTIME_MANIFEST_KEYS = [
  "schema",
  "packageVersion",
  "upstreamVersion",
  "upstreamTag",
  "upstreamCommit",
  "patchCommit",
  "patchTreeSha256",
  "releaseId",
  "protocolMode",
  "readinessSchema",
] as const satisfies readonly (keyof RuntimeManifest)[];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertExactManifestKeys(value: Record<string, unknown>): void {
  const expected = [...RUNTIME_MANIFEST_KEYS].sort();
  const actual = Object.keys(value).sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new Error("Runtime manifest fields are invalid");
  }
}

function parseRuntimeManifest(value: unknown): RuntimeManifest {
  if (!isRecord(value)) throw new Error("Runtime manifest must be an object");
  assertExactManifestKeys(value);

  const packageVersion = getPackageVersion();
  if (value.schema !== BRIDGE_RUNTIME_MANIFEST_SCHEMA) {
    throw new Error("Runtime manifest schema is invalid");
  }
  if (value.packageVersion !== packageVersion) {
    throw new Error("Runtime manifest package version is invalid");
  }
  if (value.upstreamVersion !== packageVersion) {
    throw new Error("Runtime manifest upstream version is invalid");
  }
  if (value.upstreamTag !== `bridge/v${packageVersion}`) {
    throw new Error("Runtime manifest upstream tag is invalid");
  }
  if (
    typeof value.upstreamCommit !== "string" ||
    !/^[0-9a-f]{40}$/.test(value.upstreamCommit)
  ) {
    throw new Error("Runtime manifest upstream commit is invalid");
  }
  if (
    typeof value.patchCommit !== "string" ||
    !/^[0-9a-f]{40}$/.test(value.patchCommit)
  ) {
    throw new Error("Runtime manifest patch commit is invalid");
  }
  if (
    typeof value.patchTreeSha256 !== "string" ||
    !/^[0-9a-f]{64}$/.test(value.patchTreeSha256)
  ) {
    throw new Error("Runtime manifest patch tree hash is invalid");
  }
  if (
    typeof value.releaseId !== "string" ||
    !/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(value.releaseId)
  ) {
    throw new Error("Runtime manifest release id is invalid");
  }
  if (value.protocolMode !== BRIDGE_PROTOCOL_MODE) {
    throw new Error("Runtime manifest protocol mode is invalid");
  }
  if (value.readinessSchema !== BRIDGE_READINESS_SCHEMA) {
    throw new Error("Runtime manifest readiness schema is invalid");
  }

  return {
    schema: BRIDGE_RUNTIME_MANIFEST_SCHEMA,
    packageVersion,
    upstreamVersion: packageVersion,
    upstreamTag: `bridge/v${packageVersion}`,
    upstreamCommit: value.upstreamCommit,
    patchCommit: value.patchCommit,
    patchTreeSha256: value.patchTreeSha256,
    releaseId: value.releaseId,
    protocolMode: BRIDGE_PROTOCOL_MODE,
    readinessSchema: BRIDGE_READINESS_SCHEMA,
  };
}

// Capture git info at startup (optional, may fail in non-git environments)
function getGitInfo(): { commit?: string; branch?: string } {
  try {
    const commit = execSync("git rev-parse --short HEAD", {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
    return { commit, branch };
  } catch {
    return {};
  }
}

const gitInfo = getGitInfo();

export interface VersionInfo {
  version: string;
  nodeVersion: string;
  platform: NodeJS.Platform;
  arch: NodeJS.Architecture;
  startedAt: string;
  uptime: number;
  gitCommit?: string;
  gitBranch?: string;
}

/** Returns the package version string (e.g. "1.17.1"). */
export function getPackageVersion(): string {
  return packageJson.version;
}

/** Returns the cryptographically random identity for this Bridge process. */
export function getBridgeGeneration(): string {
  return bridgeGeneration;
}

/** Loads and validates the immutable runtime manifest named by the environment. */
export function loadRuntimeManifest(
  env: NodeJS.ProcessEnv = process.env,
): RuntimeManifest {
  const manifestPath = env.BRIDGE_RUNTIME_MANIFEST;
  if (!manifestPath || !isAbsolute(manifestPath)) {
    throw new Error("Runtime manifest is unavailable");
  }
  return parseRuntimeManifest(
    JSON.parse(readFileSync(manifestPath, "utf8")) as unknown,
  );
}

export function getVersionInfo(serverStartedAt: number): VersionInfo {
  return {
    version: packageJson.version,
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    startedAt: new Date(serverStartedAt).toISOString(),
    uptime: Math.floor((Date.now() - serverStartedAt) / 1000),
    ...(gitInfo.commit && { gitCommit: gitInfo.commit }),
    ...(gitInfo.branch && { gitBranch: gitInfo.branch }),
  };
}
