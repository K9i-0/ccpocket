import { EventEmitter } from "node:events";
import type { ProcessStatus, Provider, PermissionMode } from "./parser.js";

/** Options passed to IProcessTransport.start(). */
export interface ProcessStartOptions {
  projectPath: string;
  provider: Provider;
  sessionId?: string;            // Resume existing session
  permissionMode?: PermissionMode;
  model?: string;
  initialInput?: string;         // Auto-send on start
  [key: string]: unknown;        // Provider-specific passthrough
}

/**
 * Common interface for all process backends (PtyProcess, SdkProcess, CodexProcess).
 * SessionManager interacts with processes exclusively through this interface.
 *
 * Events emitted:
 * - "message"  (msg: ServerMessage)  — structured events for phone clients
 * - "pty_data" (data: string)        — raw PTY bytes for terminal clients (PTY only)
 * - "status"   (status: ProcessStatus)
 * - "exit"     (code: number | null)
 */
export interface IProcessTransport extends EventEmitter {
  start(opts: ProcessStartOptions): void;
  /** Graceful shutdown (SIGTERM). */
  stop(): void;
  /** Forceful termination (SIGKILL). */
  kill(): void;

  /** Raw input — PTY keystrokes or no-op for SDK processes. */
  write(data: string): void;

  /** User message — adds newline/CR for PTY, queues for SDK. */
  sendInput(text: string): void;

  /** Approve a pending tool call. */
  sendApproval(id: string): void;

  /** Reject a pending tool call. */
  sendRejection(id: string, reason?: string): void;

  /** Current process status. */
  readonly status: ProcessStatus;

  /** Whether this transport emits pty_data events. */
  readonly isPty: boolean;

  /** The native session ID (Claude session UUID or Codex thread ID). */
  readonly sessionId: string | null;
}
