import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  BRIDGE_PROTOCOL_MAX_VERSION,
  BRIDGE_PROTOCOL_MIN_VERSION,
} from "./protocol-version.js";

// Read package.json version at module load time
const __dirname = dirname(fileURLToPath(import.meta.url));
const packagePath = join(__dirname, "..", "package.json");
const packageJson = JSON.parse(readFileSync(packagePath, "utf-8"));

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

/**
 * What started this Bridge, as far as a client needs to know to explain how to
 * update it. `desktop-app`: the launcher of the CC Pocket desktop app, which
 * updates the Bridge when it is restarted from that app. `other`: the `setup`
 * service or a manual run.
 */
export type BridgeManagedBy = "desktop-app" | "other";

export function getManagedBy(
  env: NodeJS.ProcessEnv = process.env,
): BridgeManagedBy {
  // Set by the desktop app's launcher (see admin-api.ts); shipped launchers
  // already pass it, so this needs no app update.
  return env.CCPOCKET_BRIDGE_SUPERVISED === "1" ? "desktop-app" : "other";
}

export interface VersionInfo {
  version: string;
  protocolVersion: number;
  minimumProtocolVersion: number;
  nodeVersion: string;
  platform: NodeJS.Platform;
  arch: NodeJS.Architecture;
  managedBy: BridgeManagedBy;
  startedAt: string;
  uptime: number;
  gitCommit?: string;
  gitBranch?: string;
}

/** Returns the package version string (e.g. "1.17.1"). */
export function getPackageVersion(): string {
  return packageJson.version;
}

export function getVersionInfo(serverStartedAt: number): VersionInfo {
  return {
    version: packageJson.version,
    protocolVersion: BRIDGE_PROTOCOL_MAX_VERSION,
    minimumProtocolVersion: BRIDGE_PROTOCOL_MIN_VERSION,
    nodeVersion: process.version,
    platform: process.platform,
    arch: process.arch,
    managedBy: getManagedBy(),
    startedAt: new Date(serverStartedAt).toISOString(),
    uptime: Math.floor((Date.now() - serverStartedAt) / 1000),
    ...(gitInfo.commit && { gitCommit: gitInfo.commit }),
    ...(gitInfo.branch && { gitBranch: gitInfo.branch }),
  };
}
