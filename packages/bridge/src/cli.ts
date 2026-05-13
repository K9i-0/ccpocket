#!/usr/bin/env node
import { setupProxy } from "./proxy.js";
import { platform } from "node:os";
import { startServer } from "./index.js";

// Configure global fetch proxy before any network calls
setupProxy();

const args = process.argv.slice(2);

// Check for subcommand
const subcommand = args.find((a) => !a.startsWith("-"));

function parseFlag(name: string): string | undefined {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) return undefined;
  return args[idx + 1];
}

function hasFlag(name: string): boolean {
  return args.includes(`--${name}`);
}

if (subcommand === "doctor") {
  // Doctor subcommand: check environment health
  const jsonOutput = hasFlag("json");
  import("./doctor.js")
    .then(({ runDoctor, printReport }) =>
      runDoctor().then((report) => {
        if (jsonOutput) {
          console.log(JSON.stringify(report));
        } else {
          printReport(report);
        }
        process.exit(report.allRequiredPassed ? 0 : 1);
      }),
    )
    .catch((err) => {
      console.error("Doctor failed:", err);
      process.exit(1);
    });
} else if (subcommand === "setup") {
  // Service setup subcommand (platform-specific)
  const opts = {
    port: parseFlag("port"),
    host: parseFlag("host"),
    apiKey: parseFlag("api-key"),
    publicWsUrl: parseFlag("public-ws-url"),
    codexAppServerMode: parseFlag("codex-app-server-mode"),
    codexSharedAppServerUrl: parseFlag("codex-shared-app-server-url"),
    codexAppServerPort: parseFlag("codex-app-server-port"),
    codexAppServerUrl: parseFlag("codex-app-server-url"),
  };

  if (platform() === "darwin") {
    import("./setup-launchd.js")
      .then(({ setupLaunchd, uninstallLaunchd }) => {
        hasFlag("uninstall") ? uninstallLaunchd() : setupLaunchd(opts);
      })
      .catch((err) => {
        console.error("Setup failed:", err);
        process.exit(1);
      });
  } else if (platform() === "linux") {
    import("./setup-systemd.js")
      .then(({ setupSystemd, uninstallSystemd }) => {
        hasFlag("uninstall") ? uninstallSystemd() : setupSystemd(opts);
      })
      .catch((err) => {
        console.error("Setup failed:", err);
        process.exit(1);
      });
  } else {
    console.error(
      `ERROR: 'setup' is not supported on ${platform()}. Supported: macOS (launchd), Linux (systemd).`,
    );
    process.exit(1);
  }
} else {
  // Server mode: set env vars from CLI flags, then start
  const port = parseFlag("port");
  const host = parseFlag("host");
  const apiKey = parseFlag("api-key");
  const publicWsUrl = parseFlag("public-ws-url");
  const codexAppServerMode = parseFlag("codex-app-server-mode");
  const codexSharedAppServerUrl = parseFlag("codex-shared-app-server-url");
  const codexAppServerPort = parseFlag("codex-app-server-port");
  const codexAppServerUrl = parseFlag("codex-app-server-url");

  if (port) process.env.BRIDGE_PORT = port;
  if (host) process.env.BRIDGE_HOST = host;
  if (apiKey) process.env.BRIDGE_API_KEY = apiKey;
  if (publicWsUrl) process.env.BRIDGE_PUBLIC_WS_URL = publicWsUrl;
  if (codexAppServerMode) {
    process.env.BRIDGE_CODEX_APP_SERVER_MODE = codexAppServerMode;
  }
  if (codexAppServerPort) {
    process.env.BRIDGE_CODEX_APP_SERVER_PORT = codexAppServerPort;
  }
  if (codexSharedAppServerUrl) {
    process.env.BRIDGE_CODEX_SHARED_APP_SERVER_URL = codexSharedAppServerUrl;
  } else if (codexAppServerUrl) {
    process.env.BRIDGE_CODEX_APP_SERVER_URL = codexAppServerUrl;
  }
  if (hasFlag("no-mdns")) process.env.BRIDGE_DISABLE_MDNS = "1";

  startServer();
}
