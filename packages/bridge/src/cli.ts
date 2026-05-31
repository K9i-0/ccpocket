#!/usr/bin/env node
import { setupProxy } from "./proxy.js";
import { platform } from "node:os";
import { startServer } from "./index.js";
import { getPackageVersion } from "./version.js";
import { hasFlag, parseCliArgs, parseFlag } from "./cli-args.js";

const args = process.argv.slice(2);
const parsed = parseCliArgs(args);

function printHelp(): void {
  console.log(`ccpocket-bridge

Usage:
  ccpocket-bridge [options]
  ccpocket-bridge <command> [options]

Commands:
  help                  Show this help
  version               Show the installed Bridge version
  doctor [--json]       Check the local Bridge environment
  setup [options]       Register Bridge as a macOS launchd or Linux systemd service

Options:
  -h, --help            Show this help
  -v, --version         Show the installed Bridge version
      --port <port>     WebSocket port (default: 8765)
      --host <host>     Bind address (default: 0.0.0.0)
      --api-key <key>   Enable API key authentication
      --public-ws-url <url>
                         Public ws:// or wss:// URL used in QR codes
      --no-mdns         Disable mDNS auto-discovery advertisement
      --codex-app-server-mode <mode>
                         Codex app-server mode: private, managed, or external
      --codex-shared-app-server-url <url>
                         Shared Codex app-server ws:// URL

Setup options:
      --uninstall       Remove the registered service
      setup persists --port, --host, --api-key, --public-ws-url,
      --no-mdns, Codex app-server options, and BRIDGE_ALLOWED_DIRS

Configuration can also be provided with BRIDGE_PORT, BRIDGE_HOST,
BRIDGE_API_KEY, BRIDGE_ALLOWED_DIRS, BRIDGE_PUBLIC_WS_URL, and
BRIDGE_DISABLE_MDNS. Codex app-server configuration can be provided with
BRIDGE_CODEX_APP_SERVER_MODE and BRIDGE_CODEX_SHARED_APP_SERVER_URL.`);
}

if (parsed.helpRequested) {
  printHelp();
} else if (parsed.versionRequested) {
  console.log(`ccpocket-bridge ${getPackageVersion()}`);
} else if (parsed.command === "doctor") {
  // Configure global fetch proxy before any network calls
  setupProxy();
  // Doctor subcommand: check environment health
  const jsonOutput = hasFlag(parsed, "json");
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
} else if (parsed.command === "setup") {
  // Service setup subcommand (platform-specific)
  const opts = {
    port: parseFlag(parsed, "port"),
    host: parseFlag(parsed, "host"),
    apiKey: parseFlag(parsed, "api-key"),
    publicWsUrl: parseFlag(parsed, "public-ws-url"),
    disableMdns: hasFlag(parsed, "no-mdns"),
    codexAppServerMode: parseFlag(parsed, "codex-app-server-mode"),
    codexSharedAppServerUrl: parseFlag(parsed, "codex-shared-app-server-url"),
    codexAppServerPort: parseFlag(parsed, "codex-app-server-port"),
    codexAppServerUrl: parseFlag(parsed, "codex-app-server-url"),
  };

  if (platform() === "darwin") {
    import("./setup-launchd.js")
      .then(({ setupLaunchd, uninstallLaunchd }) => {
        hasFlag(parsed, "uninstall")
          ? uninstallLaunchd()
          : setupLaunchd(opts);
      })
      .catch((err) => {
        console.error("Setup failed:", err);
        process.exit(1);
      });
  } else if (platform() === "linux") {
    import("./setup-systemd.js")
      .then(({ setupSystemd, uninstallSystemd }) => {
        hasFlag(parsed, "uninstall")
          ? uninstallSystemd()
          : setupSystemd(opts);
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
  // Configure global fetch proxy before any network calls
  setupProxy();
  // Server mode: set env vars from CLI flags, then start
  const port = parseFlag(parsed, "port");
  const host = parseFlag(parsed, "host");
  const apiKey = parseFlag(parsed, "api-key");
  const publicWsUrl = parseFlag(parsed, "public-ws-url");
  const codexAppServerMode = parseFlag(parsed, "codex-app-server-mode");
  const codexSharedAppServerUrl = parseFlag(
    parsed,
    "codex-shared-app-server-url",
  );
  const codexAppServerPort = parseFlag(parsed, "codex-app-server-port");
  const codexAppServerUrl = parseFlag(parsed, "codex-app-server-url");

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
  if (hasFlag(parsed, "no-mdns")) process.env.BRIDGE_DISABLE_MDNS = "1";

  startServer();
}
