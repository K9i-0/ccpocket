import { execSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import {
  defaultCodexSharedAppServerUrl,
  readCodexSharedAppServerUrl,
} from "./codex-app-server-config.js";
import { parseBridgePort } from "./bridge-port.js";

const PLIST_LABEL = "com.ccpocket.bridge";

function getPlistPath(): string {
  const dir = join(homedir(), "Library", "LaunchAgents");
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return join(dir, `${PLIST_LABEL}.plist`);
}

export function uninstallLaunchd(): void {
  const plistPath = getPlistPath();
  console.log("==> Uninstalling Bridge Server service...");

  try { execSync(`launchctl stop "${PLIST_LABEL}"`, { stdio: "ignore" }); } catch { /* ok */ }
  try { execSync(`launchctl unload "${plistPath}"`, { stdio: "ignore" }); } catch { /* ok */ }

  if (existsSync(plistPath)) {
    unlinkSync(plistPath);
  }
  console.log("    Service removed.");
}

interface SetupOptions {
  port?: string;
  host?: string;
  apiKey?: string;
  publicWsUrl?: string;
  disableMdns?: boolean;
  codexAppServerMode?: string;
  codexSharedAppServerUrl?: string;
  /** @deprecated Use codexSharedAppServerUrl. */
  codexAppServerPort?: string;
  /** @deprecated Use codexSharedAppServerUrl. */
  codexAppServerUrl?: string;
}

export function setupLaunchd(opts: SetupOptions): void {
  const port = parseBridgePort(opts.port ?? process.env.BRIDGE_PORT);
  const host = opts.host ?? process.env.BRIDGE_HOST ?? "0.0.0.0";
  const apiKey = opts.apiKey ?? process.env.BRIDGE_API_KEY ?? "";
  const allowedDirs = process.env.BRIDGE_ALLOWED_DIRS ?? "";
  const publicWsUrl =
    opts.publicWsUrl ?? process.env.BRIDGE_PUBLIC_WS_URL ?? "";
  const disableMdns = opts.disableMdns || process.env.BRIDGE_DISABLE_MDNS;
  const codexAppServerMode =
    opts.codexAppServerMode ?? process.env.BRIDGE_CODEX_APP_SERVER_MODE ?? "";
  const legacyCodexAppServerPort =
    opts.codexAppServerPort ?? process.env.BRIDGE_CODEX_APP_SERVER_PORT;
  const explicitCodexAppServerUrl =
    opts.codexSharedAppServerUrl ??
    opts.codexAppServerUrl ??
    readCodexSharedAppServerUrl();
  const codexAppServerUrl =
    explicitCodexAppServerUrl ??
    (codexAppServerMode === "managed"
      ? legacyCodexAppServerPort
        ? `ws://127.0.0.1:${legacyCodexAppServerPort}`
        : defaultCodexSharedAppServerUrl(String(port))
      : "");
  if (codexAppServerMode === "external" && !codexAppServerUrl) {
    throw new Error(
      "BRIDGE_CODEX_SHARED_APP_SERVER_URL is required when Codex app-server mode is external",
    );
  }
  const plistPath = getPlistPath();

  // Resolve the npx binary path
  let npxPath: string;
  try {
    npxPath = execSync("which npx", { encoding: "utf-8" }).trim();
  } catch {
    console.error("ERROR: npx not found in PATH. Install Node.js first.");
    process.exit(1);
  }
  console.log(`==> npx: ${npxPath}`);

  // Build environment variables block
  let envBlock = `        <key>BRIDGE_PORT</key>
        <string>${port}</string>
        <key>BRIDGE_HOST</key>
        <string>${host}</string>`;

  if (apiKey) {
    envBlock += `
        <key>BRIDGE_API_KEY</key>
        <string>${apiKey}</string>`;
  }

  if (allowedDirs) {
    envBlock += `
        <key>BRIDGE_ALLOWED_DIRS</key>
        <string>${allowedDirs}</string>`;
  }

  if (publicWsUrl) {
    envBlock += `
        <key>BRIDGE_PUBLIC_WS_URL</key>
        <string>${publicWsUrl}</string>`;
  }

  if (disableMdns) {
    envBlock += `
        <key>BRIDGE_DISABLE_MDNS</key>
        <string>1</string>`;
  }

  if (codexAppServerMode) {
    envBlock += `
        <key>BRIDGE_CODEX_APP_SERVER_MODE</key>
        <string>${codexAppServerMode}</string>`;
  }

  if (codexAppServerMode && codexAppServerUrl) {
    envBlock += `
        <key>BRIDGE_CODEX_SHARED_APP_SERVER_URL</key>
        <string>${codexAppServerUrl}</string>`;
  }

  // Generate plist
  // Use zsh -li -c to inherit the user's full shell environment
  // (mise, nvm, pyenv, Homebrew, etc.)
  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-li</string>
        <string>-c</string>
        <string>exec npx --yes @ccpocket/bridge@latest</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
${envBlock}
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/ccpocket-bridge.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/ccpocket-bridge.err</string>
</dict>
</plist>
`;

  console.log(`==> Writing ${plistPath}`);
  writeFileSync(plistPath, plist);

  // Register with launchctl
  console.log("==> Registering service...");
  try { execSync(`launchctl unload "${plistPath}"`, { stdio: "ignore" }); } catch { /* ok */ }
  execSync(`launchctl load "${plistPath}"`);

  // Start the service
  try {
    execSync(`launchctl start "${PLIST_LABEL}"`);
    console.log(`==> Bridge Server started on port ${port}`);
    if (codexAppServerMode && codexAppServerUrl) {
      console.log(
        `    Codex remote: codex resume --all --remote ${codexAppServerUrl}`,
      );
    }
  } catch {
    console.log("==> Service registered (start may have failed — check logs at /tmp/ccpocket-bridge.log)");
  }

  console.log("    Done.");
}
