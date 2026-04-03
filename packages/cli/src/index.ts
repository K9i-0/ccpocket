import { Command } from "commander";
import { render } from "ink";
import React from "react";
import { App } from "./app.js";
import { BridgeClient } from "./bridge-client.js";
import { discoverBridge } from "./discovery.js";
import { loadConfig } from "./config.js";

const program = new Command()
  .name("ccpocket")
  .description("Terminal client for CC Pocket")
  .version("0.1.0")
  .option("--url <url>", "Bridge WebSocket URL")
  .option("--api-key <key>", "Bridge API key");

program
  .command("attach <sessionId>")
  .description("Attach to a running session")
  .action(async (sessionId: string) => {
    const url = await resolveUrl(program.opts().url);
    if (!url) {
      console.error("Could not find bridge. Use --url to specify.");
      process.exit(1);
    }
    const client = new BridgeClient(url, program.opts().apiKey);
    render(
      React.createElement(App, {
        client,
        initialScreen: { name: "session", sessionId },
      }),
    );
  });

program
  .command("start <path>")
  .description("Start a new session")
  .option("--provider <provider>", "Provider (claude/codex)", "claude")
  .action(async (path: string, opts: { provider: string }) => {
    const url = await resolveUrl(program.opts().url);
    if (!url) {
      console.error("Could not find bridge. Use --url to specify.");
      process.exit(1);
    }
    const client = new BridgeClient(url, program.opts().apiKey);
    client.on("open", () => {
      client.send({
        type: "start",
        projectPath: path,
        provider: opts.provider,
      });
    });
    client.on("message", (msg) => {
      if (msg.type === "system" && msg.subtype === "session_created" && msg.sessionId) {
        render(
          React.createElement(App, {
            client,
            initialScreen: { name: "session", sessionId: msg.sessionId as string },
          }),
        );
      }
    });
  });

// Default command: show session picker
program.action(async () => {
  const url = await resolveUrl(program.opts().url);
  if (!url) {
    console.error("Could not find bridge. Use --url to specify.");
    process.exit(1);
  }
  const client = new BridgeClient(url, program.opts().apiKey);
  render(React.createElement(App, { client }));
});

async function resolveUrl(explicit?: string): Promise<string | null> {
  if (explicit) return explicit;
  console.log("  Discovering bridge...");
  const url = await discoverBridge();
  if (url) console.log(`  Found bridge at ${url}`);
  return url;
}

program.parse();
