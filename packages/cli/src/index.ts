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
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("Connection timed out")), 10_000);
      const onOpen = () => { client.off("error", onError); clearTimeout(timer); resolve(); };
      const onError = (err: Error) => { client.off("open", onOpen); clearTimeout(timer); reject(err); };
      client.once("open", onOpen);
      client.once("error", onError);
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
    const sessionId = await new Promise<string>((resolve, reject) => {
      const timer = setTimeout(() => {
        cleanup();
        reject(new Error("Session creation timed out"));
      }, 30_000);

      const onOpen = () => {
        client.send({
          type: "start",
          projectPath: path,
          provider: opts.provider,
        });
      };
      const onError = (err: Error) => { cleanup(); reject(err); };
      const onMessage = (msg: Record<string, unknown>) => {
        if (
          msg.type === "system" &&
          msg.subtype === "session_created" &&
          msg.sessionId
        ) {
          cleanup();
          resolve(msg.sessionId as string);
        }
        if (msg.type === "error") {
          cleanup();
          reject(new Error((msg.message as string) ?? "Session creation failed"));
        }
      };

      function cleanup() {
        clearTimeout(timer);
        client.off("open", onOpen);
        client.off("error", onError);
        client.off("message", onMessage);
      }

      client.once("open", onOpen);
      client.on("error", onError);
      client.on("message", onMessage);
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
