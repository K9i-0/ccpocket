import { EventEmitter } from "node:events";
import { Codex, type Thread, type ThreadEvent, type ThreadItem } from "@openai/codex-sdk";
import type { ServerMessage, ProcessStatus } from "./parser.js";

export interface CodexStartOptions {
  threadId?: string;
  approvalPolicy?: "never" | "on-request" | "on-failure" | "untrusted";
  sandboxMode?: "read-only" | "workspace-write" | "danger-full-access";
  model?: string;
}

export interface CodexProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
}

export class CodexProcess extends EventEmitter<CodexProcessEvents> {
  private codex: Codex;
  private thread: Thread | null = null;
  private _status: ProcessStatus = "starting";
  private _threadId: string | null = null;
  private stopped = false;
  private startModel: string | undefined;

  // User input channel
  private inputResolve: ((text: string) => void) | null = null;
  private pendingAbort: AbortController | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  get sessionId(): string | null {
    return this._threadId;
  }

  get isRunning(): boolean {
    return this.thread !== null;
  }

  constructor() {
    super();
    this.codex = new Codex();
  }

  start(projectPath: string, options?: CodexStartOptions): void {
    if (this.thread) {
      this.stop();
    }

    this.stopped = false;
    this._threadId = null;

    const threadOpts = {
      workingDirectory: projectPath,
      approvalPolicy: options?.approvalPolicy ?? "never",
      sandboxMode: options?.sandboxMode ?? "workspace-write",
      skipGitRepoCheck: true,
      ...(options?.model ? { model: options.model } : {}),
    } as const;

    console.log(`[codex-process] Starting (cwd: ${projectPath}, sandbox: ${threadOpts.sandboxMode}, approval: ${threadOpts.approvalPolicy})`);

    this.thread = options?.threadId
      ? this.codex.resumeThread(options.threadId, threadOpts)
      : this.codex.startThread(threadOpts);

    this.setStatus("idle");
    this.startModel = options?.model;

    // Start input loop
    this.runInputLoop().catch((err) => {
      if (!this.stopped) {
        console.error("[codex-process] Input loop error:", err);
        this.emitMessage({
          type: "error",
          message: `Codex error: ${err instanceof Error ? err.message : String(err)}`,
        });
      }
      this.setStatus("idle");
      this.emit("exit", 1);
    });
  }

  stop(): void {
    this.stopped = true;
    if (this.pendingAbort) {
      this.pendingAbort.abort();
      this.pendingAbort = null;
    }
    // Unblock pending input wait
    if (this.inputResolve) {
      this.inputResolve("");
      this.inputResolve = null;
    }
    this.thread = null;
    this.setStatus("idle");
    console.log("[codex-process] Stopped");
  }

  interrupt(): void {
    if (this.pendingAbort) {
      console.log("[codex-process] Interrupting current turn");
      this.pendingAbort.abort();
    }
  }

  sendInput(text: string): void {
    if (!this.inputResolve) {
      console.error("[codex-process] No pending input resolver for sendInput");
      return;
    }
    const resolve = this.inputResolve;
    this.inputResolve = null;
    resolve(text);
  }

  // ---- Private ----

  private async runInputLoop(): Promise<void> {
    while (!this.stopped) {
      // Wait for user input
      const text = await new Promise<string>((resolve) => {
        this.inputResolve = resolve;
      });
      if (this.stopped || !text || !this.thread) break;

      // Execute turn
      this.setStatus("running");
      const controller = new AbortController();
      this.pendingAbort = controller;

      try {
        const streamed = await this.thread.runStreamed(text, {
          signal: controller.signal,
        });
        for await (const event of streamed.events) {
          if (this.stopped) break;
          this.processEvent(event);
        }
      } catch (err) {
        if (!this.stopped) {
          const msg = err instanceof Error ? err.message : String(err);
          // Don't emit error for abort (user-initiated interrupt)
          if (!controller.signal.aborted) {
            this.emitMessage({ type: "error", message: msg });
          }
          this.emitMessage({
            type: "result",
            subtype: controller.signal.aborted ? "interrupted" : "error",
            error: controller.signal.aborted ? undefined : msg,
            sessionId: this._threadId ?? undefined,
          });
        }
      } finally {
        this.pendingAbort = null;
        if (!this.stopped) {
          this.setStatus("idle");
        }
      }
    }
  }

  private processEvent(event: ThreadEvent): void {
    switch (event.type) {
      case "thread.started":
        this._threadId = event.thread_id;
        console.log(`[codex-process] Thread started: ${event.thread_id}`);
        this.emitMessage({
          type: "system",
          subtype: "init",
          sessionId: event.thread_id,
          model: this.startModel ?? "codex",
        });
        break;

      case "turn.started":
        this.setStatus("running");
        break;

      case "item.started":
        this.processItemStarted(event.item);
        break;

      case "item.completed":
        this.processItemCompleted(event.item);
        break;

      case "item.updated":
        // Not fired in current SDK version, but handle for future compatibility
        this.processItemCompleted(event.item);
        break;

      case "turn.completed":
        this.emitMessage({
          type: "result",
          subtype: "success",
          sessionId: this._threadId ?? undefined,
          inputTokens: event.usage.input_tokens,
          cachedInputTokens: event.usage.cached_input_tokens,
          outputTokens: event.usage.output_tokens,
        });
        break;

      case "turn.failed":
        this.emitMessage({
          type: "result",
          subtype: "error",
          error: event.error.message,
          sessionId: this._threadId ?? undefined,
        });
        break;

      case "error":
        this.emitMessage({ type: "error", message: event.message });
        break;
    }
  }

  private processItemStarted(item: ThreadItem): void {
    switch (item.type) {
      case "command_execution":
        // Emit tool_use for the command (shown before result)
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: item.id,
                name: "Bash",
                input: { command: item.command },
              },
            ],
            model: "codex",
          },
        });
        break;
      // Other item types: nothing to show on start
    }
  }

  private processItemCompleted(item: ThreadItem): void {
    switch (item.type) {
      case "agent_message":
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [{ type: "text", text: item.text }],
            model: "codex",
          },
        });
        break;

      case "reasoning":
        this.emitMessage({ type: "thinking_delta", text: item.text });
        break;

      case "command_execution":
        this.emitMessage({
          type: "tool_result",
          toolUseId: item.id,
          content: item.aggregated_output || `exit code: ${item.exit_code}`,
          toolName: "Bash",
        });
        break;

      case "file_change":
        // Emit tool_use first (for display)
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: item.id,
                name: "FileChange",
                input: { changes: item.changes },
              },
            ],
            model: "codex",
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: item.id,
          content: item.changes
            .map((c) => `${c.kind}: ${c.path}`)
            .join("\n"),
          toolName: "FileChange",
        });
        break;

      case "mcp_tool_call": {
        const toolName = `mcp:${item.server}/${item.tool}`;
        // Emit tool_use first
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: item.id,
                name: toolName,
                input: item.arguments as Record<string, unknown>,
              },
            ],
            model: "codex",
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: item.id,
          content: item.result
            ? JSON.stringify(item.result)
            : item.error?.message ?? "MCP call completed",
          toolName,
        });
        break;
      }

      case "web_search":
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: item.id,
                name: "WebSearch",
                input: { query: item.query },
              },
            ],
            model: "codex",
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: item.id,
          content: `Web search: ${item.query}`,
          toolName: "WebSearch",
        });
        break;

      case "todo_list":
        this.emitMessage({
          type: "assistant",
          message: {
            id: item.id,
            role: "assistant",
            content: [
              {
                type: "text",
                text: item.items
                  .map((t) => `${t.completed ? "\u2705" : "\u2B1C"} ${t.text}`)
                  .join("\n"),
              },
            ],
            model: "codex",
          },
        });
        break;

      case "error":
        this.emitMessage({ type: "error", message: item.message });
        break;
    }
  }

  private setStatus(status: ProcessStatus): void {
    if (this._status !== status) {
      this._status = status;
      this.emit("status", status);
      this.emitMessage({ type: "status", status });
    }
  }

  private emitMessage(msg: ServerMessage): void {
    this.emit("message", msg);
  }
}
