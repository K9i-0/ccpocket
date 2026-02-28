/**
 * Bridge Server doctor command.
 *
 * Checks the health of all dependencies and provides actionable guidance
 * when issues are found — similar to `flutter doctor`.
 */

import { execFile, execSync } from "node:child_process";
import {
  accessSync,
  constants as fsConstants,
  existsSync,
} from "node:fs";
import net from "node:net";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type CheckStatus = "pass" | "fail" | "warn" | "skip";

export interface CheckResult {
  name: string;
  status: CheckStatus;
  message: string;
  remediation?: string;
}

export type CheckCategory = "required" | "optional";

export interface CheckDefinition {
  name: string;
  category: CheckCategory;
  run: () => Promise<CheckResult>;
}

/** Sub-result for each CLI provider (Claude Code / Codex). */
export interface ProviderResult {
  name: string;
  installed: boolean;
  version?: string;
  authenticated: boolean;
  authMessage?: string;
  remediation?: string;
}

export interface DoctorReport {
  results: Array<CheckResult & { category: CheckCategory; providers?: ProviderResult[] }>;
  allRequiredPassed: boolean;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function execQuiet(cmd: string): string {
  return execSync(cmd, { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] }).trim();
}

// ---------------------------------------------------------------------------
// Individual checks
// ---------------------------------------------------------------------------

export async function checkNodeVersion(): Promise<CheckResult> {
  const version = process.version; // e.g. "v22.5.0"
  const major = parseInt(version.slice(1), 10);
  if (major >= 18) {
    return { name: "Node.js", status: "pass", message: version };
  }
  return {
    name: "Node.js",
    status: "fail",
    message: `${version} (requires >=18.0.0)`,
    remediation: "Install Node.js >=18.0.0: https://nodejs.org/",
  };
}

export async function checkGit(): Promise<CheckResult> {
  try {
    const out = execQuiet("git --version"); // "git version 2.44.0"
    const version = out.replace("git version ", "");
    return { name: "Git", status: "pass", message: `v${version}` };
  } catch {
    return {
      name: "Git",
      status: "fail",
      message: "Not installed",
      remediation: "Install Git: https://git-scm.com/downloads",
    };
  }
}

/** Check both Claude Code CLI and Codex CLI. At least one must be installed. */
export async function checkCliProviders(): Promise<
  CheckResult & { providers: ProviderResult[] }
> {
  const providers: ProviderResult[] = [];

  // --- Claude Code CLI ---
  {
    let installed = false;
    let version: string | undefined;
    let authenticated = false;
    let authMessage: string | undefined;
    let remediation: string | undefined;

    try {
      const out = execQuiet("claude --version");
      installed = true;
      version = out.trim().split("\n")[0];
      // Check auth
      try {
        const authOut = execQuiet("claude auth status");
        // If exit code 0, authenticated
        if (authOut.toLowerCase().includes("not logged in") || authOut.toLowerCase().includes("unauthenticated")) {
          authenticated = false;
          authMessage = "Not authenticated";
          remediation = "Run: claude auth login";
        } else {
          authenticated = true;
        }
      } catch {
        // auth command failed — treat as unauthenticated
        authenticated = false;
        authMessage = "Not authenticated";
        remediation = "Run: claude auth login";
      }
    } catch {
      remediation = "Install Claude Code: https://docs.anthropic.com/en/docs/claude-code/getting-started";
    }

    providers.push({
      name: "Claude Code CLI",
      installed,
      version,
      authenticated,
      authMessage,
      remediation,
    });
  }

  // --- Codex CLI ---
  {
    let installed = false;
    let version: string | undefined;
    let authenticated = false;
    let authMessage: string | undefined;
    let remediation: string | undefined;

    try {
      const out = execQuiet("codex --version");
      installed = true;
      version = out.trim().split("\n")[0];
      // Codex authenticates via OPENAI_API_KEY env var or ~/.codex/auth.json
      if (process.env.OPENAI_API_KEY) {
        authenticated = true;
      } else {
        const authFile = join(homedir(), ".codex", "auth.json");
        if (existsSync(authFile)) {
          authenticated = true;
        } else {
          authenticated = false;
          authMessage = "Not authenticated";
          remediation = "Run: codex login";
        }
      }
    } catch {
      remediation = "Install Codex CLI: https://github.com/openai/codex";
    }

    providers.push({
      name: "Codex CLI",
      installed,
      version,
      authenticated,
      authMessage,
      remediation,
    });
  }

  const installedCount = providers.filter((p) => p.installed).length;
  const total = providers.length;

  if (installedCount === 0) {
    return {
      name: "CLI providers",
      status: "fail",
      message: "No CLI providers installed",
      remediation: "Install at least one: https://docs.anthropic.com/en/docs/claude-code/getting-started  OR  https://github.com/openai/codex",
      providers,
    };
  }

  // At least one installed — check if any auth warnings
  const hasAuthWarn = providers.some((p) => p.installed && !p.authenticated);
  return {
    name: "CLI providers",
    status: hasAuthWarn ? "warn" : "pass",
    message: `${installedCount} of ${total} available`,
    providers,
  };
}

export async function checkDependencies(): Promise<CheckResult> {
  // In monorepo setups, node_modules may be hoisted to the workspace root.
  // Use import.meta.resolve() to check if packages are resolvable.
  const requiredPackages = [
    "ws",
    "@anthropic-ai/claude-agent-sdk",
    "@openai/codex-sdk",
    "bonjour-service",
  ];
  const missing: string[] = [];

  for (const pkg of requiredPackages) {
    try {
      import.meta.resolve(pkg);
    } catch {
      missing.push(pkg);
    }
  }

  if (missing.length > 0) {
    return {
      name: "npm dependencies",
      status: "fail",
      message: `Missing: ${missing.join(", ")}`,
      remediation: "Run: npm install",
    };
  }

  return { name: "npm dependencies", status: "pass", message: "All packages available" };
}

export async function checkPortAvailable(port: number): Promise<CheckResult> {
  return new Promise((resolve) => {
    let resolved = false;
    const done = (result: CheckResult) => {
      if (resolved) return;
      resolved = true;
      resolve(result);
    };

    const server = net.createServer();
    server.once("error", (err: NodeJS.ErrnoException) => {
      if (err.code === "EADDRINUSE") {
        done({
          name: "Port availability",
          status: "warn",
          message: `Port ${port} is in use`,
          remediation: `Another Bridge may be running, or set BRIDGE_PORT to a different port`,
        });
      } else {
        done({
          name: "Port availability",
          status: "warn",
          message: `Port ${port} check failed: ${err.code}`,
        });
      }
    });
    server.listen(port, "127.0.0.1", () => {
      server.close(() => {
        done({
          name: "Port availability",
          status: "pass",
          message: `Port ${port} is available`,
        });
      });
    });
    // Safety timeout
    setTimeout(() => {
      try { server.close(); } catch { /* ignore */ }
      done({
        name: "Port availability",
        status: "warn",
        message: `Port ${port} check timed out`,
      });
    }, 3000);
  });
}

/** Resolve the tailscale CLI binary path (may be inside macOS .app bundle). */
function tailscaleCmd(): string {
  // Try bare command first (Linux, Homebrew install, etc.)
  try {
    execQuiet("tailscale version");
    return "tailscale";
  } catch { /* not in PATH */ }

  // macOS: Tailscale.app bundles the CLI inside the app
  const macPath = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
  if (existsSync(macPath)) return macPath;

  throw new Error("tailscale not found");
}

export async function checkTailscale(): Promise<CheckResult> {
  let cmd: string;
  try {
    cmd = tailscaleCmd();
  } catch {
    return {
      name: "Tailscale",
      status: "skip",
      message: "Not installed (optional for remote access)",
      remediation: "Install: https://tailscale.com/download",
    };
  }

  try {
    const out = execQuiet(`${cmd} status`);
    // Extract the Tailscale IP (first IPv4 in output)
    const ipMatch = out.match(/(\d+\.\d+\.\d+\.\d+)/);
    const ip = ipMatch ? ipMatch[1] : "";
    return {
      name: "Tailscale",
      status: "pass",
      message: ip ? `Connected (${ip})` : "Connected",
    };
  } catch {
    return {
      name: "Tailscale",
      status: "warn",
      message: "Installed but not connected",
      remediation: "Run: tailscale up",
    };
  }
}

export async function checkFirebaseConnectivity(): Promise<CheckResult> {
  // Use a read-only endpoint to avoid creating anonymous accounts as a side effect
  const FIREBASE_API_KEY = "AIzaSyAptNnokWPqJIgv2Lr3I8ETN6bqZb5BGvc";
  const url = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${FIREBASE_API_KEY}`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
      signal: AbortSignal.timeout(5000),
    });
    // Any response (even 400) means the API is reachable
    if (response.status < 500) {
      return {
        name: "Firebase connectivity",
        status: "pass",
        message: "Firebase Auth API reachable",
      };
    }
    return {
      name: "Firebase connectivity",
      status: "warn",
      message: `Firebase Auth API returned ${response.status}`,
      remediation: "Push notifications may not work. Check network connectivity.",
    };
  } catch {
    return {
      name: "Firebase connectivity",
      status: "warn",
      message: "Unreachable",
      remediation:
        "Push notifications will be disabled. Check network connectivity.",
    };
  }
}

export async function checkDataDirectory(): Promise<CheckResult> {
  const dir = join(homedir(), ".ccpocket");
  if (!existsSync(dir)) {
    return {
      name: "Data directory",
      status: "pass",
      message: "~/.ccpocket/ will be created on first run",
    };
  }
  try {
    accessSync(dir, fsConstants.R_OK | fsConstants.W_OK);
    return {
      name: "Data directory",
      status: "pass",
      message: "~/.ccpocket/ exists",
    };
  } catch {
    return {
      name: "Data directory",
      status: "warn",
      message: "~/.ccpocket/ is not writable",
      remediation: "Fix permissions: chmod u+rw ~/.ccpocket",
    };
  }
}

export async function checkLaunchdService(): Promise<CheckResult> {
  if (process.platform !== "darwin") {
    return {
      name: "launchd service",
      status: "skip",
      message: "macOS only",
    };
  }
  try {
    const out = execSync("launchctl list", {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
    });
    if (out.includes("com.ccpocket.bridge")) {
      return {
        name: "launchd service",
        status: "pass",
        message: "Registered",
      };
    }
    return {
      name: "launchd service",
      status: "skip",
      message: "Not registered",
      remediation: "Register with: ccpocket-bridge setup",
    };
  } catch {
    return {
      name: "launchd service",
      status: "skip",
      message: "Unable to check",
    };
  }
}

// ---------------------------------------------------------------------------
// macOS permission checks
// ---------------------------------------------------------------------------

/**
 * Swift inline script to check Screen Recording permission.
 * CGWindowListCopyWindowInfo returns window names only when the process has
 * Screen Recording permission. Without it, kCGWindowName is always empty.
 * We check if *any* on-screen window has a non-empty name.
 */
const CHECK_SCREEN_RECORDING_SWIFT = `
import CoreGraphics

let windowList = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

var hasName = false
for w in windowList {
    guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    if let name = w[kCGWindowName as String] as? String, !name.isEmpty {
        hasName = true
        break
    }
}
print(hasName ? "granted" : "denied")
`;

export async function checkScreenRecording(): Promise<CheckResult> {
  if (process.platform !== "darwin") {
    return { name: "Screen Recording", status: "skip", message: "macOS only" };
  }

  return new Promise<CheckResult>((resolve) => {
    execFile(
      "swift",
      ["-e", CHECK_SCREEN_RECORDING_SWIFT],
      { timeout: 15_000 },
      (err, stdout) => {
        if (err) {
          resolve({
            name: "Screen Recording",
            status: "warn",
            message: "Unable to check (swift not available)",
            remediation:
              "Install Xcode Command Line Tools: xcode-select --install",
          });
          return;
        }
        const result = stdout.trim();
        if (result === "granted") {
          resolve({
            name: "Screen Recording",
            status: "pass",
            message: "Permission granted",
          });
        } else {
          resolve({
            name: "Screen Recording",
            status: "warn",
            message: "Permission not granted (screenshots will fail)",
            remediation:
              "System Settings > Privacy & Security > Screen Recording > enable your terminal app",
          });
        }
      },
    );
  });
}

export async function checkKeychainAccess(): Promise<CheckResult> {
  if (process.platform !== "darwin") {
    return { name: "Keychain access", status: "skip", message: "macOS only" };
  }

  return new Promise<CheckResult>((resolve) => {
    execFile(
      "security",
      ["find-generic-password", "-s", "Claude Code-credentials", "-w"],
      { timeout: 5_000 },
      (err, _stdout, stderr) => {
        if (!err) {
          // Successfully read credentials
          resolve({
            name: "Keychain access",
            status: "pass",
            message: "Claude Code credentials accessible",
          });
          return;
        }

        const msg = (stderr ?? "").toLowerCase() + (err.message ?? "").toLowerCase();
        // "could not be found" = no credential stored (not an error)
        if (msg.includes("could not be found") || msg.includes("not found") || msg.includes("no matching")) {
          resolve({
            name: "Keychain access",
            status: "skip",
            message: "No Claude Code credentials stored",
            remediation: "Run: claude auth login (if using Claude Code)",
          });
        } else {
          // Access denied or other Keychain error
          resolve({
            name: "Keychain access",
            status: "warn",
            message: "Keychain access denied",
            remediation:
              "Allow Keychain access for your terminal app, or re-login: claude auth login",
          });
        }
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

function getAllChecks(): CheckDefinition[] {
  const port = parseInt(process.env.BRIDGE_PORT ?? "8765", 10);

  return [
    // Required
    { name: "Node.js", category: "required", run: checkNodeVersion },
    { name: "Git", category: "required", run: checkGit },
    { name: "CLI providers", category: "required", run: checkCliProviders },
    { name: "npm dependencies", category: "required", run: checkDependencies },
    {
      name: "Port availability",
      category: "required",
      run: () => checkPortAvailable(port),
    },
    // Optional — macOS permissions
    {
      name: "Screen Recording",
      category: "optional",
      run: checkScreenRecording,
    },
    {
      name: "Keychain access",
      category: "optional",
      run: checkKeychainAccess,
    },
    // Optional — connectivity & services
    { name: "Tailscale", category: "optional", run: checkTailscale },
    {
      name: "Firebase connectivity",
      category: "optional",
      run: checkFirebaseConnectivity,
    },
    { name: "Data directory", category: "optional", run: checkDataDirectory },
    {
      name: "launchd service",
      category: "optional",
      run: checkLaunchdService,
    },
  ];
}

export async function runDoctor(): Promise<DoctorReport> {
  const checks = getAllChecks();
  const results: DoctorReport["results"] = [];

  for (const check of checks) {
    const result = await check.run();
    results.push({ ...result, category: check.category });
  }

  const allRequiredPassed = results
    .filter((r) => r.category === "required")
    .every((r) => r.status === "pass" || r.status === "warn");

  return { results, allRequiredPassed };
}

// ---------------------------------------------------------------------------
// Output formatting
// ---------------------------------------------------------------------------

const SYMBOLS_TTY = {
  pass: "\x1b[32m✓\x1b[0m",
  fail: "\x1b[31m✗\x1b[0m",
  warn: "\x1b[33m!\x1b[0m",
  skip: "\x1b[90m-\x1b[0m",
} as const;

const SYMBOLS_PLAIN = {
  pass: "[OK]",
  fail: "[FAIL]",
  warn: "[WARN]",
  skip: "[SKIP]",
} as const;

function providerStatusIcon(
  p: ProviderResult,
  sym: typeof SYMBOLS_TTY | typeof SYMBOLS_PLAIN,
): string {
  if (!p.installed) return sym.skip;
  if (!p.authenticated) return sym.warn;
  return sym.pass;
}

function providerStatusMessage(p: ProviderResult): string {
  if (!p.installed) return "Not installed";
  const parts: string[] = [];
  if (p.version) parts.push(p.version);
  if (p.authenticated) {
    parts.push("(authenticated)");
  } else if (p.authMessage) {
    parts.push(`(${p.authMessage})`);
  }
  return parts.join(" ") || "Installed";
}

export function printReport(report: DoctorReport): void {
  const isTTY = process.stdout.isTTY ?? false;
  const sym = isTTY ? SYMBOLS_TTY : SYMBOLS_PLAIN;
  const NAME_WIDTH = 22;

  console.log("");
  console.log("ccpocket-bridge doctor");
  console.log("======================");

  // Required checks
  const required = report.results.filter((r) => r.category === "required");
  if (required.length > 0) {
    console.log("");
    console.log("Required:");
    for (const r of required) {
      const icon = sym[r.status];
      const nameCol = r.name.padEnd(NAME_WIDTH);
      console.log(`  ${icon} ${nameCol} ${r.message}`);

      // Print provider sub-items for CLI providers check
      if (r.providers) {
        for (const p of r.providers) {
          const pIcon = providerStatusIcon(p, sym);
          const pName = p.name.padEnd(NAME_WIDTH);
          console.log(`      ${pIcon} ${pName} ${providerStatusMessage(p)}`);
          if (p.remediation) {
            console.log(`          → ${p.remediation}`);
          }
        }
      } else if (r.remediation && (r.status === "fail" || r.status === "warn")) {
        console.log(`      → ${r.remediation}`);
      }
    }
  }

  // Optional checks
  const optional = report.results.filter((r) => r.category === "optional");
  if (optional.length > 0) {
    console.log("");
    console.log("Optional:");
    for (const r of optional) {
      const icon = sym[r.status];
      const nameCol = r.name.padEnd(NAME_WIDTH);
      console.log(`  ${icon} ${nameCol} ${r.message}`);
      if (r.remediation && (r.status === "fail" || r.status === "warn" || r.status === "skip")) {
        console.log(`      → ${r.remediation}`);
      }
    }
  }

  // Summary
  console.log("");
  const failCount = report.results.filter((r) => r.status === "fail").length;
  const warnCount = report.results.filter((r) => r.status === "warn").length;

  if (report.allRequiredPassed) {
    const msg = "All required checks passed.";
    console.log(isTTY ? `\x1b[32m${msg}\x1b[0m` : msg);
  } else {
    const msg = `${failCount} required check(s) failed.`;
    console.log(isTTY ? `\x1b[31m${msg}\x1b[0m` : msg);
  }

  if (warnCount > 0) {
    console.log(`${warnCount} warning(s).`);
  }

  console.log("");
}
