import { Command } from "commander";
import { render } from "ink";
import React from "react";
import { App } from "./app.js";
import { BridgeClient } from "./bridge-client.js";
import { discoverBridge } from "./discovery.js";
import { runPtySession } from "./pty-session.js";

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

    // Wait for connection, then go straight to raw PTY session
    await new Promise<void>((resolve) => {
      client.on("open", () => resolve());
    });
    await runPtySession(client, sessionId);
    client.disconnect();
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

    // Wait for connection, start session, then enter raw PTY mode
    const sessionId = await new Promise<string>((resolve) => {
      client.on("open", () => {
        client.send({
          type: "start",
          projectPath: path,
          provider: opts.provider,
        });
      });
      client.on("message", (msg) => {
        if (
          msg.type === "system" &&
          msg.subtype === "session_created" &&
          msg.sessionId
        ) {
          resolve(msg.sessionId as string);
        }
      });
    });

    await runPtySession(client, sessionId);
    client.disconnect();
  });

// Default command: session picker with Ink ↔ raw PTY loop
program.action(async () => {
  const url = await resolveUrl(program.opts().url);
  if (!url) {
    console.error("Could not find bridge. Use --url to specify.");
    process.exit(1);
  }
  const client = new BridgeClient(url, program.opts().apiKey);

  // Loop: Ink screen → raw session → back to Ink
  let running = true;
  while (running) {
    const result = await new Promise<{ action: "session"; sessionId: string } | { action: "quit" }>(
      (resolve) => {
        const { unmount } = render(
          React.createElement(App, {
            client,
            onEnterRawSession: (sessionId: string) => {
              unmount();
              resolve({ action: "session", sessionId });
            },
            onQuit: () => {
              unmount();
              resolve({ action: "quit" });
            },
          }),
        );
      },
    );

    if (result.action === "quit") {
      running = false;
    } else {
      await runPtySession(client, result.sessionId);
      // After raw session ends, loop back to Ink home screen
    }
  }

  client.disconnect();
});

async function resolveUrl(explicit?: string): Promise<string | null> {
  if (explicit) return explicit;
  console.log("  Discovering bridge...");
  const url = await discoverBridge();
  if (url) console.log(`  Found bridge at ${url}`);
  return url;
}

program.parse();
