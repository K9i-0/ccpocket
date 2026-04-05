import { Command } from "commander";
import { spawn } from "node:child_process";
import { resolve } from "node:path";
import { render } from "ink";
import React from "react";
import { App } from "./app.js";
import { BridgeClient } from "./bridge-client.js";
import {
  findLatestCodexThreadForCwd,
  resolveCodexThreadForCwd,
  saveTrackedCodexThread,
} from "./codex-handoff.js";
import { saveConfig } from "./config.js";
import { discoverBridge } from "./discovery.js";
import { runPtySession } from "./pty-session.js";

const program = new Command()
  .name("ccpocket")
  .description("Terminal client for CC Pocket")
  .version("0.1.0")
  .option("--url <url>", "Bridge WebSocket URL")
  .option("--api-key <key>", "Bridge API key");

program
  .command("codex [path] [codexArgs...]")
  .description("Launch or reclaim native Codex for this repo, then hand off to phone on exit")
  .allowUnknownOption(true)
  .action(async (path: string | undefined, codexArgs: string[] = []) => {
    const cwd = resolveProjectPath(path);
    const url = await resolveUrl(program.opts().url);
    await runSmartCodex(cwd, codexArgs, url);
  });

program
  .command("phone [path]")
  .alias("p")
  .description("Hand off the current repo's tracked Codex thread to CC Pocket")
  .action(async (path: string | undefined) => {
    const url = await resolveUrl(program.opts().url);
    await handoffCodexToPhone(resolveProjectPath(path), url);
  });

program
  .command("laptop [path] [codexArgs...]")
  .alias("l")
  .description("Resume the current repo's tracked Codex thread back in native Codex")
  .allowUnknownOption(true)
  .action(async (path: string | undefined, codexArgs: string[] = []) => {
    const url = await resolveUrl(program.opts().url);
    await handoffCodexToLaptop(resolveProjectPath(path), codexArgs, url);
  });

program
  .command("handoff [targetOrPath] [path] [codexArgs...]")
  .alias("h")
  .description("Toggle a native Codex thread between laptop and phone")
  .allowUnknownOption(true)
  .action(async (
    targetOrPath: string | undefined,
    path: string | undefined,
    codexArgs: string[] = [],
  ) => {
    const { target, cwd, extraArgs } = resolveHandoffInvocation(
      targetOrPath,
      path,
      codexArgs,
    );
    const url = await resolveUrl(program.opts().url);

    if (target === "phone") {
      await handoffCodexToPhone(cwd, url);
      return;
    }
    if (target === "laptop") {
      await handoffCodexToLaptop(cwd, extraArgs, url);
      return;
    }

    const inferredTarget = await inferHandoffTarget(cwd, url);
    if (inferredTarget === "phone") {
      await handoffCodexToPhone(cwd, url);
      return;
    }
    if (inferredTarget === "laptop") {
      await handoffCodexToLaptop(cwd, extraArgs, url);
      return;
    }

    console.error(
      `Could not infer handoff direction for ${cwd}. Start native Codex there or attach from phone first.`,
    );
    process.exit(1);
  });

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
  if (explicit) {
    saveConfig({ bridgeUrl: explicit });
    return explicit;
  }
  console.log("  Discovering bridge...");
  const url = await discoverBridge();
  if (url) console.log(`  Found bridge at ${url}`);
  return url;
}

function resolveProjectPath(path?: string): string {
  if (path) return resolve(path);
  const npmInitCwd = process.env.INIT_CWD?.trim();
  if (npmInitCwd) return resolve(npmInitCwd);
  return resolve(process.cwd());
}

function resolveHandoffInvocation(
  targetOrPath: string | undefined,
  path: string | undefined,
  codexArgs: string[],
): {
  target: "phone" | "laptop" | null;
  cwd: string;
  extraArgs: string[];
} {
  if (targetOrPath === "phone" || targetOrPath === "laptop") {
    return {
      target: targetOrPath,
      cwd: resolveProjectPath(path),
      extraArgs: codexArgs,
    };
  }

  if (targetOrPath) {
    return {
      target: null,
      cwd: resolveProjectPath(targetOrPath),
      extraArgs: path ? [path, ...codexArgs] : codexArgs,
    };
  }

  return {
    target: null,
    cwd: resolveProjectPath(),
    extraArgs: codexArgs,
  };
}

async function runTrackedNativeCodex(
  cwd: string,
  codexArgs: string[],
  options?: {
    handoffToPhoneOnExit?: boolean;
    resolvedUrl?: string | null;
  },
): Promise<number> {
  const startedAt = Date.now();
  let lastTrackedThreadId: string | null = null;

  const maybeTrackLatestThread = (): void => {
    const thread = findLatestCodexThreadForCwd(cwd, {
      sinceMs: startedAt - 5_000,
    });
    if (!thread || thread.threadId === lastTrackedThreadId) return;
    saveTrackedCodexThread(thread);
    lastTrackedThreadId = thread.threadId;
    console.error(`[ccpocket] Tracking Codex thread ${thread.threadId} for ${cwd}`);
  };

  const pollTimer = setInterval(maybeTrackLatestThread, 1_000);
  maybeTrackLatestThread();

  console.error(`[ccpocket] Native Codex starting in ${cwd}`);
  if (options?.handoffToPhoneOnExit) {
    console.error("[ccpocket] Exit Codex to continue on your phone.");
    console.error("[ccpocket] Run `ccpocket codex` here later to reclaim the same session.");
  }

  const child = spawn("codex", ["-C", cwd, ...codexArgs], {
    stdio: "inherit",
    env: process.env,
  });

  const exitCode = await new Promise<number>((resolveExit, reject) => {
    child.on("error", reject);
    child.on("exit", (code) => resolveExit(code ?? 0));
  }).finally(() => {
    clearInterval(pollTimer);
    maybeTrackLatestThread();
  });

  if (options?.handoffToPhoneOnExit && exitCode === 0) {
    const latestThread = resolveCodexThreadForCwd(cwd, {
      sinceMs: startedAt - 5_000,
    });
    if (latestThread) {
      saveTrackedCodexThread(latestThread);
      try {
        await handoffCodexToPhone(cwd, options.resolvedUrl, {
          announceAction: false,
          source: "auto-exit",
        });
      } catch (error) {
        const message =
          error instanceof Error ? error.message : String(error);
        console.error(`[ccpocket] Auto-handoff to phone failed: ${message}`);
      }
    }
  }

  return exitCode;
}

async function handoffCodexToPhone(
  cwd: string,
  resolvedUrl?: string | null,
  options?: {
    announceAction?: boolean;
    source?: "manual" | "auto-exit";
  },
): Promise<void> {
  const thread = resolveCodexThreadForCwd(cwd);
  if (!thread) {
    throw new Error(
      `No local Codex thread found for ${cwd}. Start or resume native Codex there first.`,
    );
  }
  saveTrackedCodexThread(thread);

  const url = resolvedUrl ?? await resolveUrl(program.opts().url);
  if (!url) {
    throw new Error("Could not find bridge. Use --url to specify.");
  }

  const client = new BridgeClient(url, program.opts().apiKey);
  try {
    if (options?.announceAction !== false) {
      console.log(`[ccpocket] Handing off ${cwd} to phone...`);
    }
    await waitForOpen(client);
    await stopBridgeCodexSessionsForProject(client, cwd);
    client.send({
      type: "resume_session",
      sessionId: thread.threadId,
      projectPath: cwd,
      provider: "codex",
    });

    const response = await waitForMessage(
      client,
      (msg) =>
        (msg.type === "system" &&
          msg.subtype === "session_created" &&
          msg.provider === "codex") ||
        msg.type === "error",
      30_000,
    );

    if (response.type === "error") {
      throw new Error(String(response.message ?? "Bridge resume failed"));
    }

    console.log(
      `Handed off Codex thread ${thread.threadId} to bridge session ${String(response.sessionId)}.`,
    );
    if (options?.source === "auto-exit") {
      console.log("Open CC Pocket on your phone to continue.");
    } else {
      console.log("Open CC Pocket on your phone and attach to the running Codex session.");
    }
  } finally {
    client.disconnect();
  }
}

async function handoffCodexToLaptop(
  cwd: string,
  codexArgs: string[],
  resolvedUrl?: string | null,
): Promise<void> {
  const thread = resolveCodexThreadForCwd(cwd);
  if (!thread) {
    console.error(
      `No tracked Codex thread found for ${cwd}. Hand off to phone first or start native Codex there.`,
    );
    process.exit(1);
  }
  saveTrackedCodexThread(thread);

  const url = resolvedUrl ?? await resolveUrl(program.opts().url);
  if (url) {
    const client = new BridgeClient(url, program.opts().apiKey);
    try {
      await waitForOpen(client);
      await stopBridgeCodexSessionsForProject(client, cwd);
    } catch {
      // Best effort only. A stale bridge session should not block native resume.
    } finally {
      client.disconnect();
    }
  }

  const exitCode = await runTrackedNativeCodex(
    cwd,
    ["resume", thread.threadId, "-C", cwd, ...codexArgs],
    {
      handoffToPhoneOnExit: true,
      resolvedUrl: url,
    },
  );
  process.exit(exitCode);
}

async function inferHandoffTarget(
  cwd: string,
  resolvedUrl?: string | null,
): Promise<"phone" | "laptop" | null> {
  const url = resolvedUrl ?? await resolveUrl(program.opts().url);
  if (url) {
    const client = new BridgeClient(url, program.opts().apiKey);
    try {
      await waitForOpen(client);
      const activeSessions = await listBridgeCodexSessionsForProject(client, cwd);
      if (activeSessions.length > 0) {
        return "laptop";
      }
    } catch {
      // Fall back to local thread detection below.
    } finally {
      client.disconnect();
    }
  }

  return resolveCodexThreadForCwd(cwd) ? "phone" : null;
}

async function runSmartCodex(
  cwd: string,
  codexArgs: string[],
  resolvedUrl?: string | null,
): Promise<void> {
  const url = resolvedUrl ?? await resolveUrl(program.opts().url);
  const isExplicitResume = codexArgs[0] === "resume";

  if (isExplicitResume) {
    const exitCode = await runTrackedNativeCodex(cwd, codexArgs, {
      handoffToPhoneOnExit: true,
      resolvedUrl: url,
    });
    process.exit(exitCode);
  }

  const hasActivePhoneSession =
    url ? (await hasBridgeCodexSessionForProject(cwd, url)) : false;

  if (hasActivePhoneSession) {
    console.log(`[ccpocket] Reclaiming ${cwd} from phone...`);
    await handoffCodexToLaptop(cwd, codexArgs, url);
    return;
  }

  const exitCode = await runTrackedNativeCodex(cwd, codexArgs, {
    handoffToPhoneOnExit: true,
    resolvedUrl: url,
  });
  process.exit(exitCode);
}

function waitForOpen(client: BridgeClient, timeoutMs: number = 10_000): Promise<void> {
  if (client.connected) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error("Connection timed out"));
    }, timeoutMs);

    const onOpen = () => {
      cleanup();
      resolve();
    };
    const onError = (err: Error) => {
      cleanup();
      reject(err);
    };

    function cleanup() {
      clearTimeout(timer);
      client.off("open", onOpen);
      client.off("error", onError);
    }

    client.on("open", onOpen);
    client.on("error", onError);
  });
}

function waitForMessage(
  client: BridgeClient,
  predicate: (msg: Record<string, unknown>) => boolean,
  timeoutMs: number,
): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error("Timed out waiting for bridge response"));
    }, timeoutMs);

    const onMessage = (msg: Record<string, unknown>) => {
      if (!predicate(msg)) return;
      cleanup();
      resolve(msg);
    };

    function cleanup() {
      clearTimeout(timer);
      client.off("message", onMessage);
    }

    client.on("message", onMessage);
  });
}

async function stopBridgeCodexSessionsForProject(
  client: BridgeClient,
  cwd: string,
): Promise<void> {
  const matchingSessions = await listBridgeCodexSessionsForProject(client, cwd);
  for (const session of matchingSessions) {
    client.send({ type: "stop_session", sessionId: String(session.id) });
  }
}

async function listBridgeCodexSessionsForProject(
  client: BridgeClient,
  cwd: string,
): Promise<Array<Record<string, unknown>>> {
  client.send({ type: "list_sessions" });
  const response = await waitForMessage(
    client,
    (msg) => msg.type === "session_list" || msg.type === "error",
    5_000,
  ).catch(() => null);

  if (!response || response.type !== "session_list" || !Array.isArray(response.sessions)) {
    return [];
  }

  return (response.sessions as Array<Record<string, unknown>>)
    .filter((session) => {
      return (
        session.provider === "codex" &&
        typeof session.projectPath === "string" &&
        resolve(session.projectPath) === cwd &&
        typeof session.id === "string"
      );
    })
    .sort((a, b) => {
      return (
        new Date(String(b.lastActivityAt ?? 0)).getTime() -
        new Date(String(a.lastActivityAt ?? 0)).getTime()
      );
    });
}

async function hasBridgeCodexSessionForProject(
  cwd: string,
  resolvedUrl: string,
): Promise<boolean> {
  const client = new BridgeClient(resolvedUrl, program.opts().apiKey);
  try {
    await waitForOpen(client);
    const sessions = await listBridgeCodexSessionsForProject(client, cwd);
    return sessions.length > 0;
  } catch {
    return false;
  } finally {
    client.disconnect();
  }
}

program.parse();
