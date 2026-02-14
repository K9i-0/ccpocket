import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { rm, writeFile } from "node:fs/promises";
import { Codex, type Input, type Thread, type ThreadEvent, type ThreadItem } from "@openai/codex-sdk";
import type { ServerMessage, ProcessStatus } from "./parser.js";

export interface CodexStartOptions {
  threadId?: string;
  approvalPolicy?: "never" | "on-request" | "on-failure" | "untrusted";
  sandboxMode?: "read-only" | "workspace-write" | "danger-full-access";
  model?: string;
  modelReasoningEffort?: "minimal" | "low" | "medium" | "high" | "xhigh";
  networkAccessEnabled?: boolean;
  webSearchMode?: "disabled" | "cached" | "live";
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
  private inputResolve: ((input: PendingInput) => void) | null = null;
  private pendingAbort: AbortController | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  get isWaitingForInput(): boolean {
    return this.inputResolve !== null;
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
      networkAccessEnabled: options?.networkAccessEnabled ?? true,
      skipGitRepoCheck: true,
      ...(options?.model ? { model: options.model } : {}),
      ...(options?.modelReasoningEffort ? { modelReasoningEffort: options.modelReasoningEffort } : {}),
      ...(options?.webSearchMode ? { webSearchMode: options.webSearchMode } : {}),
    } as const;

    console.log(
      `[codex-process] Starting (cwd: ${projectPath}, sandbox: ${threadOpts.sandboxMode}, approval: ${threadOpts.approvalPolicy}, model: ${threadOpts.model ?? "default"}, reasoning: ${threadOpts.modelReasoningEffort ?? "default"}, network: ${threadOpts.networkAccessEnabled}, webSearch: ${threadOpts.webSearchMode ?? "default"})`,
    );

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
      this.inputResolve({ text: "" });
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
    resolve({ text });
  }

  sendInputWithImage(text: string, image: { base64: string; mimeType: string }): void {
    if (!this.inputResolve) {
      console.error("[codex-process] No pending input resolver for sendInputWithImage");
      return;
    }
    const resolve = this.inputResolve;
    this.inputResolve = null;
    resolve({
      text,
      image,
    });
  }

  // ---- Private ----

  private async runInputLoop(): Promise<void> {
    while (!this.stopped) {
      // Wait for user input
      const pendingInput = await new Promise<PendingInput>((resolve) => {
        this.inputResolve = resolve;
      });
      if (this.stopped || !pendingInput.text || !this.thread) break;

      const { input, tempPaths } = await this.toSdkInput(pendingInput);
      if (!input) {
        continue;
      }

      // Execute turn
      this.setStatus("running");
      const controller = new AbortController();
      this.pendingAbort = controller;

      try {
        const streamed = await this.thread.runStreamed(input, {
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
        for (const path of tempPaths) {
          await rm(path, { force: true }).catch(() => {});
        }
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

  private async toSdkInput(
    pendingInput: PendingInput,
  ): Promise<{ input: Input | null; tempPaths: string[] }> {
    if (!pendingInput.image) {
      return { input: pendingInput.text, tempPaths: [] };
    }

    const ext = extensionFromMime(pendingInput.image.mimeType);
    if (!ext) {
      this.emitMessage({
        type: "error",
        message: `Unsupported image mime type for Codex: ${pendingInput.image.mimeType}`,
      });
      return { input: null, tempPaths: [] };
    }

    let buffer: Buffer;
    try {
      buffer = Buffer.from(pendingInput.image.base64, "base64");
    } catch {
      this.emitMessage({
        type: "error",
        message: "Invalid base64 image data for Codex input",
      });
      return { input: null, tempPaths: [] };
    }

    const tempPath = join(tmpdir(), `ccpocket-codex-image-${randomUUID()}.${ext}`);
    await writeFile(tempPath, buffer);

    return {
      input: [
        { type: "text", text: pendingInput.text },
        { type: "local_image", path: tempPath },
      ],
      tempPaths: [tempPath],
    };
  }
}

interface PendingInput {
  text: string;
  image?: {
    base64: string;
    mimeType: string;
  };
}

function extensionFromMime(mimeType: string): string | null {
  switch (mimeType) {
    case "image/png":
      return "png";
    case "image/jpeg":
      return "jpg";
    case "image/webp":
      return "webp";
    case "image/gif":
      return "gif";
    default:
      return null;
  }
}
