import type { BridgeClient } from "./bridge-client.js";

/**
 * Run a raw PTY session — direct terminal passthrough.
 * Resolves when the user detaches (Ctrl+D) or the session ends.
 */
export async function runPtySession(
  client: BridgeClient,
  sessionId: string,
): Promise<void> {
  return new Promise<void>((resolve) => {
    const stdin = process.stdin;
    const stdout = process.stdout;

    // Attach to session as CLI client
    client.send({
      type: "attach_session",
      sessionId,
      clientType: "cli",
    });

    // Send terminal dimensions
    if (stdout.columns && stdout.rows) {
      client.send({
        type: "pty_resize",
        sessionId,
        cols: stdout.columns,
        rows: stdout.rows,
      });
    }

    // Enter raw mode
    const wasRaw = stdin.isRaw;
    if (stdin.isTTY) {
      stdin.setRawMode(true);
    }
    stdin.resume();

    // Forward keystrokes → bridge
    const onStdinData = (data: Buffer) => {
      // Ctrl+D (0x04) = detach
      if (data.length === 1 && data[0] === 0x04) {
        cleanup();
        return;
      }

      client.send({
        type: "pty_input",
        sessionId,
        data: data.toString("utf-8"),
      });
    };

    // Forward PTY output → terminal
    const onMessage = (msg: Record<string, unknown>) => {
      if (msg.sessionId !== sessionId) return;

      if (msg.type === "pty_output") {
        stdout.write(msg.data as string);
      }
    };

    // Handle terminal resize
    const onResize = () => {
      if (stdout.columns && stdout.rows) {
        client.send({
          type: "pty_resize",
          sessionId,
          cols: stdout.columns,
          rows: stdout.rows,
        });
      }
    };

    // Handle session end — PtyProcess emits "idle" when the CLI exits
    const onSessionEnd = (msg: Record<string, unknown>) => {
      if (msg.sessionId !== sessionId) return;
      if (
        msg.type === "status" &&
        (msg.status === "idle" || msg.status === "exited" || msg.status === "stopped")
      ) {
        cleanup();
      }
    };

    // Handle connection drop
    const onClose = () => {
      cleanup();
    };

    // Wire up listeners
    stdin.on("data", onStdinData);
    client.on("message", onMessage);
    client.on("message", onSessionEnd);
    client.on("close", onClose);
    stdout.on("resize", onResize);

    let cleaned = false;
    function cleanup() {
      if (cleaned) return;
      cleaned = true;
      // Restore terminal state
      stdin.off("data", onStdinData);
      client.off("message", onMessage);
      client.off("message", onSessionEnd);
      client.off("close", onClose);
      stdout.off("resize", onResize);

      if (stdin.isTTY) {
        stdin.setRawMode(wasRaw ?? false);
      }
      stdin.pause();

      // Detach from session
      client.send({ type: "detach_session", sessionId });

      // Clear screen and show cursor
      stdout.write("\x1b[2J\x1b[H\x1b[?25h");

      resolve();
    }
  });
}
