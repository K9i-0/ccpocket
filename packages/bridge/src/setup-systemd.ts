import { execSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import {
  defaultCodexSharedAppServerUrl,
  readCodexSharedAppServerUrl,
} from "./codex-app-server-config.js";
import { parseBridgePort } from "./bridge-port.js";

const SERVICE_NAME = "ccpocket-bridge";

function getServiceDir(): string {
  const dir = join(homedir(), ".config", "systemd", "user");
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
}

function getServicePath(): string {
  return join(getServiceDir(), `${SERVICE_NAME}.service`);
}

export function uninstallSystemd(): void {
  const servicePath = getServicePath();
  console.log("==> Uninstalling Bridge Server service...");

  try {
    execSync(`systemctl --user stop "${SERVICE_NAME}"`, { stdio: "ignore" });
  } catch {
    /* ok */
  }
  try {
    execSync(`systemctl --user disable "${SERVICE_NAME}"`, { stdio: "ignore" });
  } catch {
    /* ok */
  }

  if (existsSync(servicePath)) {
    unlinkSync(servicePath);
  }

  try {
    execSync("systemctl --user daemon-reload", { stdio: "ignore" });
  } catch {
    /* ok */
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

function uniquePathEntries(entries: string[]): string[] {
  const seen = new Set<string>();
  return entries.filter((entry) => {
    if (!entry || seen.has(entry)) return false;
    seen.add(entry);
    return true;
  });
}

function buildServicePath(nodeBinDir: string): string {
  const home = homedir();
  const systemBins = ["/usr/local/bin", "/usr/bin", "/bin"];
  const nodeFallback = systemBins.includes(nodeBinDir) ? [] : [nodeBinDir];
  return uniquePathEntries([
    join(home, ".local", "bin"),
    join(home, "bin"),
    join(home, ".nvm", "versions", "node", "current", "bin"),
    join(home, ".volta", "bin"),
    join(home, ".mise", "shims"),
    join(home, ".asdf", "shims"),
    join(home, ".bun", "bin"),
    join(home, ".npm-global", "bin"),
    ...nodeFallback,
    ...systemBins,
  ]).join(":");
}

const START_BRIDGE_COMMAND =
  'if [ -s "$HOME/.nvm/nvm.sh" ]; then . "$HOME/.nvm/nvm.sh"; nvm use --silent default >/dev/null 2>&1 || nvm use --silent node >/dev/null 2>&1 || true; fi; export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; exec npx --yes @ccpocket/bridge@latest';

export function setupSystemd(opts: SetupOptions): void {
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
  const servicePath = getServicePath();

  // Resolve the npx binary path
  let npxPath: string;
  try {
    npxPath = execSync("command -v npx", { encoding: "utf-8" }).trim();
  } catch {
    console.error("ERROR: npx not found in PATH. Install Node.js first.");
    process.exit(1);
    return; // unreachable, but helps TypeScript and tests
  }
  console.log(`==> npx: ${npxPath}`);

  // Resolve the directory containing npx (and node)
  // This is needed because systemd doesn't load .bashrc, so tools like
  // nvm/mise/volta won't add node to PATH automatically.
  const nodeBinDir = dirname(npxPath);

  // Build environment lines
  let envLines = `Environment=PATH=${buildServicePath(nodeBinDir)}
Environment=BRIDGE_PORT=${port}
Environment=BRIDGE_HOST=${host}`;

  if (apiKey) {
    envLines += `\nEnvironment=BRIDGE_API_KEY=${apiKey}`;
  }
  if (allowedDirs) {
    envLines += `\nEnvironment=BRIDGE_ALLOWED_DIRS=${allowedDirs}`;
  }
  if (publicWsUrl) {
    envLines += `\nEnvironment=BRIDGE_PUBLIC_WS_URL=${publicWsUrl}`;
  }
  if (disableMdns) {
    envLines += "\nEnvironment=BRIDGE_DISABLE_MDNS=1";
  }
  if (codexAppServerMode) {
    envLines += `\nEnvironment=BRIDGE_CODEX_APP_SERVER_MODE=${codexAppServerMode}`;
  }
  if (codexAppServerMode && codexAppServerUrl) {
    envLines += `\nEnvironment=BRIDGE_CODEX_SHARED_APP_SERVER_URL=${codexAppServerUrl}`;
  }

  // Generate systemd user service unit
  // Run through bash so npx is resolved when the service starts. That lets the
  // service follow stable shims/current symlinks instead of pinning one NVM
  // version forever, while still falling back to the npx path found at setup.
  const unit = `[Unit]
Description=CC Pocket Bridge Server
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -lc '${START_BRIDGE_COMMAND}'
${envLines}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
`;

  console.log(`==> Writing ${servicePath}`);
  writeFileSync(servicePath, unit);

  // Reload and enable
  console.log("==> Registering service...");
  execSync("systemctl --user daemon-reload");
  execSync(`systemctl --user enable "${SERVICE_NAME}"`);

  // Start the service
  try {
    execSync(`systemctl --user restart "${SERVICE_NAME}"`);
    console.log(`==> Bridge Server started on port ${port}`);
    if (codexAppServerMode && codexAppServerUrl) {
      console.log(
        `    Codex remote: codex resume --all --remote ${codexAppServerUrl}`,
      );
    }
  } catch {
    console.log(
      "==> Service registered (start may have failed — check logs with: journalctl --user -u ccpocket-bridge)",
    );
  }

  // Enable lingering so the user service persists after logout.
  // Without this, systemd user services stop when the last session ends
  // (e.g. SSH disconnect), which defeats the purpose of a background service.
  try {
    const lingerStatus = execSync("loginctl show-user $USER --property=Linger", {
      encoding: "utf-8",
    }).trim();
    if (lingerStatus !== "Linger=yes") {
      console.log("==> Enabling linger to keep service running after logout...");
      execSync("loginctl enable-linger $USER");
      console.log("    Linger enabled.");
    }
  } catch {
    console.log(
      "    Note: Could not enable linger. Run `loginctl enable-linger $USER` manually to keep the service running after logout.",
    );
  }

  console.log("    Done.");
}
