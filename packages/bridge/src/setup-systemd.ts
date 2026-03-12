import { execSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

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
}

export function setupSystemd(opts: SetupOptions): void {
  const port = opts.port ?? process.env.BRIDGE_PORT ?? "8765";
  const host = opts.host ?? process.env.BRIDGE_HOST ?? "0.0.0.0";
  const apiKey = opts.apiKey ?? process.env.BRIDGE_API_KEY ?? "";
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
  let envLines = `Environment=PATH=${nodeBinDir}:/usr/local/bin:/usr/bin:/bin
Environment=BRIDGE_PORT=${port}
Environment=BRIDGE_HOST=${host}`;

  if (apiKey) {
    envLines += `\nEnvironment=BRIDGE_API_KEY=${apiKey}`;
  }

  // Generate systemd user service unit
  // Run npx directly with its full path. We set Environment=PATH to include
  // the node bin directory so that npx can find node (since systemd doesn't
  // load .bashrc/.profile where nvm/mise/volta set up PATH).
  const unit = `[Unit]
Description=CC Pocket Bridge Server
After=network.target

[Service]
Type=simple
ExecStart=${npxPath} @ccpocket/bridge@latest
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
