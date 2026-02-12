#!/usr/bin/env node
import { startServer } from "./index.js";
import { setupLaunchd, uninstallLaunchd } from "./setup-launchd.js";

const args = process.argv.slice(2);

// Check for "setup" subcommand
const subcommand = args.find((a) => !a.startsWith("-"));

function parseFlag(name: string): string | undefined {
  const idx = args.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= args.length) return undefined;
  return args[idx + 1];
}

function hasFlag(name: string): boolean {
  return args.includes(`--${name}`);
}

if (subcommand === "setup") {
  // launchd setup subcommand
  if (hasFlag("uninstall")) {
    uninstallLaunchd();
  } else {
    setupLaunchd({
      port: parseFlag("port"),
      host: parseFlag("host"),
      apiKey: parseFlag("api-key"),
    });
  }
} else {
  // Server mode: set env vars from CLI flags, then start
  const port = parseFlag("port");
  const host = parseFlag("host");
  const apiKey = parseFlag("api-key");

  if (port) process.env.BRIDGE_PORT = port;
  if (host) process.env.BRIDGE_HOST = host;
  if (apiKey) process.env.BRIDGE_API_KEY = apiKey;

  startServer();
}
