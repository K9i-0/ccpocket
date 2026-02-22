import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { rm, writeFile } from "node:fs/promises";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import type { ServerMessage, ProcessStatus } from "./parser.js";

export interface CodexStartOptions {
  threadId?: string;
  approvalPolicy?: "never" | "on-request" | "on-failure" | "untrusted";
  sandboxMode?: "read-only" | "workspace-write" | "danger-full-access";
  model?: string;
  modelReasoningEffort?: "minimal" | "low" | "medium" | "high" | "xhigh";
  networkAccessEnabled?: boolean;
  webSearchMode?: "disabled" | "cached" | "live";
  collaborationMode?: "plan" | "default";
}

export interface CodexProcessEvents {
  message: [ServerMessage];
  status: [ProcessStatus];
  exit: [number | null];
}

interface PendingInput {
  text: string;
  images?: Array<{
    base64: string;
    mimeType: string;
  }>;
}

interface PendingApproval {
  requestId: string | number;
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
}

interface PendingUserInputQuestion {
  id: string;
  question: string;
}

interface PendingUserInputRequest {
  requestId: string | number;
  toolUseId: string;
  questions: PendingUserInputQuestion[];
  input: Record<string, unknown>;
}

interface PendingTurnCompletion {
  resolve: () => void;
  reject: (error: Error) => void;
}

interface RpcSuccess {
  id: number | string;
  result: unknown;
}

interface RpcError {
  id: number | string;
  error: {
    code?: number;
    message?: string;
    data?: unknown;
  };
}

interface JsonRpcEnvelope {
  id?: number | string;
  method?: string;
  params?: Record<string, unknown>;
  result?: unknown;
  error?: {
    code?: number;
    message?: string;
    data?: unknown;
  };
}

export class CodexProcess extends EventEmitter<CodexProcessEvents> {
  private child: ChildProcessWithoutNullStreams | null = null;
  private _status: ProcessStatus = "starting";
  private _threadId: string | null = null;
  private stopped = false;
  private startModel: string | undefined;

  private inputResolve: ((input: PendingInput) => void) | null = null;
  private pendingTurnId: string | null = null;
  private pendingTurnCompletion: PendingTurnCompletion | null = null;
  private pendingApprovals = new Map<string, PendingApproval>();
  private pendingUserInputs = new Map<string, PendingUserInputRequest>();
  private lastTokenUsage: { input?: number; cachedInput?: number; output?: number } | null = null;

  private rpcSeq = 1;
  private pendingRpc = new Map<number, {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
    method: string;
  }>();

  private stdoutBuffer = "";

  // Collaboration mode & plan completion state
  private _approvalPolicy: string = "never";
  private _collaborationMode: "plan" | "default" = "default";
  private lastPlanItemText: string | null = null;
  private pendingPlanCompletion: {
    toolUseId: string;
    planText: string;
  } | null = null;

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
    return this.child !== null;
  }

  get approvalPolicy(): string {
    return this._approvalPolicy;
  }

  /**
   * Update approval policy at runtime.
   * Takes effect on the next `turn/start` RPC call.
   */
  setApprovalPolicy(policy: string): void {
    this._approvalPolicy = policy;
    console.log(`[codex-process] Approval policy changed to: ${policy}`);
  }

  /**
   * Set collaboration mode ("plan" or "default").
   * Takes effect on the next `turn/start` RPC call.
   */
  setCollaborationMode(mode: "plan" | "default"): void {
    this._collaborationMode = mode;
    console.log(`[codex-process] Collaboration mode changed to: ${mode}`);
  }

  get collaborationMode(): "plan" | "default" {
    return this._collaborationMode;
  }

  start(projectPath: string, options?: CodexStartOptions): void {
    if (this.child) {
      this.stop();
    }

    this.stopped = false;
    this._threadId = null;
    this.pendingTurnId = null;
    this.pendingTurnCompletion = null;
    this.pendingApprovals.clear();
    this.pendingUserInputs.clear();
    this.lastTokenUsage = null;
    this.startModel = options?.model;
    this._approvalPolicy = options?.approvalPolicy ?? "never";
    this._collaborationMode = options?.collaborationMode ?? "default";
    this.lastPlanItemText = null;
    this.pendingPlanCompletion = null;

    console.log(
      `[codex-process] Starting app-server (cwd: ${projectPath}, sandbox: ${options?.sandboxMode ?? "workspace-write"}, approval: ${options?.approvalPolicy ?? "never"}, model: ${options?.model ?? "default"}, collaboration: ${this._collaborationMode})`,
    );

    const child = spawn("codex", ["app-server", "--listen", "stdio://"], {
      cwd: projectPath,
      stdio: "pipe",
      env: process.env,
    });
    this.child = child;

    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      this.handleStdoutChunk(chunk);
    });

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) {
        console.log(`[codex-process] stderr: ${line}`);
      }
    });

    child.on("error", (err) => {
      if (this.stopped) return;
      console.error("[codex-process] app-server process error:", err);
      this.emitMessage({ type: "error", message: `Failed to start codex app-server: ${err.message}` });
      this.setStatus("idle");
      this.emit("exit", 1);
    });

    child.on("exit", (code) => {
      const exitCode = code ?? 0;
      this.child = null;
      this.rejectAllPending(new Error("codex app-server exited"));
      if (!this.stopped && exitCode !== 0) {
        this.emitMessage({ type: "error", message: `codex app-server exited with code ${exitCode}` });
      }
      this.setStatus("idle");
      this.emit("exit", code);
    });

    void this.bootstrap(projectPath, options);
  }

  stop(): void {
    this.stopped = true;

    if (this.inputResolve) {
      this.inputResolve({ text: "" });
      this.inputResolve = null;
    }

    this.pendingApprovals.clear();
    this.pendingUserInputs.clear();
    this.rejectAllPending(new Error("stopped"));

    if (this.child) {
      this.child.kill("SIGTERM");
      this.child = null;
    }

    this.setStatus("idle");
    console.log("[codex-process] Stopped");
  }

  interrupt(): void {
    if (!this._threadId || !this.pendingTurnId) return;

    void this.request("turn/interrupt", {
      threadId: this._threadId,
      turnId: this.pendingTurnId,
    }).catch((err) => {
      if (!this.stopped) {
        console.warn(`[codex-process] turn/interrupt failed: ${err instanceof Error ? err.message : String(err)}`);
      }
    });
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

  sendInputWithImages(text: string, images: Array<{ base64: string; mimeType: string }>): void {
    if (!this.inputResolve) {
      console.error("[codex-process] No pending input resolver for sendInputWithImages");
      return;
    }
    const resolve = this.inputResolve;
    this.inputResolve = null;
    resolve({ text, images });
  }

  approve(toolUseId?: string, _updatedInput?: Record<string, unknown>): void {
    // Check if this is a plan completion approval
    if (this.pendingPlanCompletion && toolUseId === this.pendingPlanCompletion.toolUseId) {
      this.handlePlanApproved(_updatedInput);
      return;
    }

    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log("[codex-process] approve() called but no pending permission requests");
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(pending.requestId, {
      decision: "accept",
    });

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  approveAlways(toolUseId?: string): void {
    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log("[codex-process] approveAlways() called but no pending permission requests");
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(pending.requestId, {
      decision: "accept",
      acceptSettings: {
        forSession: true,
      },
    });

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  reject(toolUseId?: string, _message?: string): void {
    // Check if this is a plan completion rejection
    if (this.pendingPlanCompletion && toolUseId === this.pendingPlanCompletion.toolUseId) {
      this.handlePlanRejected(_message);
      return;
    }

    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log("[codex-process] reject() called but no pending permission requests");
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(pending.requestId, {
      decision: "decline",
    });

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  answer(toolUseId: string, result: string): void {
    const pending = this.resolvePendingUserInput(toolUseId);
    if (!pending) {
      console.log("[codex-process] answer() called but no pending AskUserQuestion");
      return;
    }

    this.pendingUserInputs.delete(pending.toolUseId);
    this.respondToServerRequest(pending.requestId, {
      answers: buildUserInputAnswers(pending.questions, result),
    });

    if (this.pendingApprovals.size === 0 && this.pendingUserInputs.size === 0) {
      this.setStatus("running");
    }
  }

  getPendingPermission(
    toolUseId?: string,
  ): { toolUseId: string; toolName: string; input: Record<string, unknown> } | undefined {
    // Check plan completion first
    if (this.pendingPlanCompletion) {
      if (!toolUseId || toolUseId === this.pendingPlanCompletion.toolUseId) {
        return {
          toolUseId: this.pendingPlanCompletion.toolUseId,
          toolName: "ExitPlanMode",
          input: { plan: this.pendingPlanCompletion.planText },
        };
      }
    }

    const pending = this.resolvePendingApproval(toolUseId);
    if (pending) {
      return {
        toolUseId: pending.toolUseId,
        toolName: pending.toolName,
        input: { ...pending.input },
      };
    }

    const pendingAsk = this.resolvePendingUserInput(toolUseId);
    if (!pendingAsk) return undefined;
    return {
      toolUseId: pendingAsk.toolUseId,
      toolName: "AskUserQuestion",
      input: { ...pendingAsk.input },
    };
  }

  private resolvePendingApproval(toolUseId?: string): PendingApproval | undefined {
    if (toolUseId) return this.pendingApprovals.get(toolUseId);
    const first = this.pendingApprovals.values().next();
    return first.done ? undefined : first.value;
  }

  private resolvePendingUserInput(toolUseId?: string): PendingUserInputRequest | undefined {
    if (toolUseId) return this.pendingUserInputs.get(toolUseId);
    const first = this.pendingUserInputs.values().next();
    return first.done ? undefined : first.value;
  }

  // ---------------------------------------------------------------------------
  // Plan completion handlers (native collaboration_mode)
  // ---------------------------------------------------------------------------

  /**
   * Plan approved → switch to Default mode and auto-start execution.
   */
  private handlePlanApproved(updatedInput?: Record<string, unknown>): void {
    const planText = (updatedInput?.plan as string) ?? this.pendingPlanCompletion?.planText ?? "";
    this.pendingPlanCompletion = null;
    this._collaborationMode = "default";
    console.log("[codex-process] Plan approved, switching to Default mode");

    // Resolve inputResolve to start the next turn (Default mode) automatically
    if (this.inputResolve) {
      const resolve = this.inputResolve;
      this.inputResolve = null;
      resolve({ text: `Execute the following plan:\n\n${planText}` });
    }
  }

  /**
   * Plan rejected → stay in Plan mode and re-plan with feedback.
   */
  private handlePlanRejected(feedback?: string): void {
    this.pendingPlanCompletion = null;
    console.log("[codex-process] Plan rejected, continuing in Plan mode");
    // Stay in Plan mode

    if (feedback && this.inputResolve) {
      const resolve = this.inputResolve;
      this.inputResolve = null;
      resolve({ text: feedback });
    } else {
      this.setStatus("idle");
    }
  }

  private async bootstrap(projectPath: string, options?: CodexStartOptions): Promise<void> {
    try {
      await this.request("initialize", {
        clientInfo: {
          name: "ccpocket_bridge",
          version: "1.0.0",
          title: "ccpocket bridge",
        },
        capabilities: {
          experimentalApi: true,
        },
      });
      this.notify("initialized", {});

      const threadParams: Record<string, unknown> = {
        cwd: projectPath,
        approvalPolicy: normalizeApprovalPolicy(options?.approvalPolicy ?? "never"),
        sandbox: normalizeSandboxMode(options?.sandboxMode ?? "workspace-write"),
      };
      if (options?.model) threadParams.model = options.model;
      if (options?.modelReasoningEffort) {
        threadParams.effort = normalizeReasoningEffort(options.modelReasoningEffort);
      }
      if (options?.networkAccessEnabled !== undefined) {
        threadParams.sandboxPolicy = {
          type: normalizeSandboxMode(options?.sandboxMode ?? "workspace-write"),
          networkAccess: options.networkAccessEnabled,
        };
      }
      if (options?.webSearchMode) {
        threadParams.webSearchMode = options.webSearchMode;
      }

      const method = options?.threadId ? "thread/resume" : "thread/start";
      if (options?.threadId) {
        threadParams.threadId = options.threadId;
      }

      const response = await this.request(method, threadParams) as Record<string, unknown>;
      const thread = response.thread as Record<string, unknown> | undefined;
      const threadId = typeof thread?.id === "string"
        ? thread.id
        : options?.threadId;
      if (!threadId) {
        throw new Error(`${method} returned no thread id`);
      }

      // Capture the resolved model name from thread response
      if (typeof thread?.model === "string" && thread.model) {
        this.startModel = thread.model;
      }

      this._threadId = threadId;
      this.emitMessage({
        type: "system",
        subtype: "init",
        sessionId: threadId,
        model: this.startModel ?? "codex",
      });
      this.setStatus("idle");

      await this.runInputLoop(options);
    } catch (err) {
      if (!this.stopped) {
        const message = err instanceof Error ? err.message : String(err);
        console.error("[codex-process] bootstrap error:", err);
        this.emitMessage({ type: "error", message: `Codex error: ${message}` });
        this.emitMessage({ type: "result", subtype: "error", error: message, sessionId: this._threadId ?? undefined });
      }
      this.setStatus("idle");
      this.emit("exit", 1);
    }
  }

  private async runInputLoop(options?: CodexStartOptions): Promise<void> {
    while (!this.stopped) {
      const pendingInput = await new Promise<PendingInput>((resolve) => {
        this.inputResolve = resolve;
      });
      if (this.stopped || !pendingInput.text) break;
      if (!this._threadId) {
        this.emitMessage({ type: "error", message: "Codex thread is not initialized" });
        continue;
      }

      const { input, tempPaths } = await this.toRpcInput(pendingInput);
      if (!input) {
        continue;
      }

      this.setStatus("running");
      this.lastTokenUsage = null;

      const completion = await new Promise<void>((resolve, reject) => {
        this.pendingTurnCompletion = { resolve, reject };

        const params: Record<string, unknown> = {
          threadId: this._threadId,
          input,
          approvalPolicy: normalizeApprovalPolicy(
            this._approvalPolicy as CodexStartOptions["approvalPolicy"],
          ),
        };
        if (options?.model) params.model = options.model;
        if (options?.modelReasoningEffort) {
          params.effort = normalizeReasoningEffort(options.modelReasoningEffort);
        }

        // Always send collaborationMode so the server switches modes correctly.
        // Omitting it causes the server to persist the previous turn's mode.
        const modeSettings: Record<string, unknown> = {
          model: options?.model || this.startModel || "gpt-5.3-codex",
        };
        if (this._collaborationMode === "plan") {
          modeSettings.reasoning_effort = "medium";
        }
        params.collaborationMode = {
          mode: this._collaborationMode,
          settings: modeSettings,
        };

        console.log(`[codex-process] turn/start: approval=${params.approvalPolicy}, collaboration=${this._collaborationMode}`);
        void this.request("turn/start", params)
          .then((result) => {
            const turn = (result as Record<string, unknown>).turn as Record<string, unknown> | undefined;
            if (typeof turn?.id === "string") {
              this.pendingTurnId = turn.id;
            }
          })
          .catch((err) => {
            this.pendingTurnCompletion = null;
            reject(err instanceof Error ? err : new Error(String(err)));
          });
      }).catch((err) => {
        if (!this.stopped) {
          const message = err instanceof Error ? err.message : String(err);
          this.emitMessage({ type: "error", message });
          this.emitMessage({
            type: "result",
            subtype: "error",
            error: message,
            sessionId: this._threadId ?? undefined,
          });
          this.setStatus("idle");
        }
      });

      await Promise.all(tempPaths.map((path) => rm(path, { force: true }).catch(() => {})));
      void completion;
    }
  }

  private handleStdoutChunk(chunk: string): void {
    this.stdoutBuffer += chunk;
    while (true) {
      const newlineIndex = this.stdoutBuffer.indexOf("\n");
      if (newlineIndex < 0) break;
      const line = this.stdoutBuffer.slice(0, newlineIndex).trim();
      this.stdoutBuffer = this.stdoutBuffer.slice(newlineIndex + 1);
      if (!line) continue;

      try {
        const envelope = JSON.parse(line) as JsonRpcEnvelope;
        this.handleRpcEnvelope(envelope);
      } catch (err) {
        console.warn(`[codex-process] failed to parse app-server JSON line: ${line.slice(0, 200)}`);
        if (!this.stopped) {
          this.emitMessage({
            type: "error",
            message: `Failed to parse codex app-server output: ${err instanceof Error ? err.message : String(err)}`,
          });
        }
      }
    }
  }

  private handleRpcEnvelope(envelope: JsonRpcEnvelope): void {
    if (envelope.id != null && envelope.method && envelope.result === undefined && envelope.error === undefined) {
      this.handleServerRequest(envelope.id, envelope.method, envelope.params ?? {});
      return;
    }

    if (envelope.id != null && (envelope.result !== undefined || envelope.error)) {
      this.handleRpcResponse(envelope as RpcSuccess | RpcError);
      return;
    }

    if (envelope.method) {
      this.handleNotification(envelope.method, envelope.params ?? {});
    }
  }

  private handleRpcResponse(envelope: RpcSuccess | RpcError): void {
    if (typeof envelope.id !== "number") {
      return;
    }
    const pending = this.pendingRpc.get(envelope.id);
    if (!pending) return;
    this.pendingRpc.delete(envelope.id);

    if ("error" in envelope && envelope.error) {
      const message = envelope.error.message ?? `RPC error ${envelope.error.code ?? ""}`;
      pending.reject(new Error(message));
      return;
    }

    pending.resolve((envelope as RpcSuccess).result);
  }

  private handleServerRequest(id: number | string, method: string, params: Record<string, unknown>): void {
    switch (method) {
      case "item/commandExecution/requestApproval": {
        const toolUseId = this.extractToolUseId(params, id);
        const input: Record<string, unknown> = {
          ...(typeof params.command === "string" ? { command: params.command } : {}),
          ...(typeof params.cwd === "string" ? { cwd: params.cwd } : {}),
          ...(params.commandActions ? { commandActions: params.commandActions } : {}),
          ...(params.networkApprovalContext ? { networkApprovalContext: params.networkApprovalContext } : {}),
          ...(typeof params.reason === "string" ? { reason: params.reason } : {}),
        };

        this.pendingApprovals.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "Bash",
          input,
        });
        this.emitMessage({
          type: "permission_request",
          toolUseId,
          toolName: "Bash",
          input,
        });
        this.setStatus("waiting_approval");
        break;
      }

      case "item/fileChange/requestApproval": {
        const toolUseId = this.extractToolUseId(params, id);
        const input: Record<string, unknown> = {
          ...(Array.isArray(params.changes) ? { changes: params.changes } : {}),
          ...(typeof params.reason === "string" ? { reason: params.reason } : {}),
        };

        this.pendingApprovals.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "FileChange",
          input,
        });
        this.emitMessage({
          type: "permission_request",
          toolUseId,
          toolName: "FileChange",
          input,
        });
        this.setStatus("waiting_approval");
        break;
      }

      case "item/tool/requestUserInput": {
        const toolUseId = this.extractToolUseId(params, id);
        const questions = normalizeUserInputQuestions(params.questions);
        const input: Record<string, unknown> = {
          questions: questions.map((q) => ({
            id: q.id,
            question: q.question,
            header: q.header,
            options: q.options,
            multiSelect: false,
            isOther: q.isOther,
            isSecret: q.isSecret,
          })),
        };

        this.pendingUserInputs.set(toolUseId, {
          requestId: id,
          toolUseId,
          questions: questions.map((q) => ({
            id: q.id,
            question: q.question,
          })),
          input,
        });
        this.emitMessage({
          type: "permission_request",
          toolUseId,
          toolName: "AskUserQuestion",
          input,
        });
        this.setStatus("waiting_approval");
        break;
      }

      default:
        this.respondToServerRequest(id, {});
        break;
    }
  }

  private handleNotification(method: string, params: Record<string, unknown>): void {
    switch (method) {
      case "thread/started": {
        const thread = params.thread as Record<string, unknown> | undefined;
        if (typeof thread?.id === "string") {
          this._threadId = thread.id;
        }
        break;
      }

      case "turn/started": {
        const turn = params.turn as Record<string, unknown> | undefined;
        if (typeof turn?.id === "string") {
          this.pendingTurnId = turn.id;
        }
        this.setStatus("running");
        break;
      }

      case "turn/completed": {
        this.handleTurnCompleted(params.turn as Record<string, unknown> | undefined);
        break;
      }

      case "thread/tokenUsage/updated": {
        const usage = params.usage as Record<string, unknown> | undefined;
        if (usage) {
          this.lastTokenUsage = {
            input: numberOrUndefined(usage.inputTokens ?? usage.input_tokens),
            cachedInput: numberOrUndefined(usage.cachedInputTokens ?? usage.cached_input_tokens),
            output: numberOrUndefined(usage.outputTokens ?? usage.output_tokens),
          };
        }
        break;
      }

      case "item/started": {
        this.processItemStarted(params.item as Record<string, unknown> | undefined);
        break;
      }

      case "item/completed": {
        this.processItemCompleted(params.item as Record<string, unknown> | undefined);
        break;
      }

      case "item/agentMessage/delta": {
        const delta = typeof params.delta === "string"
          ? params.delta
          : typeof params.textDelta === "string"
            ? params.textDelta
            : "";
        if (delta) {
          this.emitMessage({ type: "stream_delta", text: delta });
        }
        break;
      }

      case "item/reasoning/summaryTextDelta":
      case "item/reasoning/textDelta": {
        const delta = typeof params.delta === "string"
          ? params.delta
          : typeof params.textDelta === "string"
            ? params.textDelta
            : "";
        if (delta) {
          this.emitMessage({ type: "thinking_delta", text: delta });
        }
        break;
      }

      case "item/plan/delta": {
        const delta = typeof params.delta === "string" ? params.delta : "";
        if (delta) {
          this.emitMessage({ type: "thinking_delta", text: delta });
        }
        break;
      }

      case "turn/plan/updated": {
        // Default mode's update_plan tool output — always show as informational text
        const text = formatPlanUpdateText(params);
        if (!text) break;
        this.emitMessage({
          type: "assistant",
          message: {
            id: randomUUID(),
            role: "assistant",
            content: [{ type: "text", text }],
            model: "codex",
          },
        });
        break;
      }

      default:
        break;
    }
  }

  private handleTurnCompleted(turn: Record<string, unknown> | undefined): void {
    const status = String(turn?.status ?? "completed");

    const usage = this.lastTokenUsage;
    this.lastTokenUsage = null;

    if (status === "failed") {
      const errorObj = turn?.error as Record<string, unknown> | undefined;
      const message = typeof errorObj?.message === "string"
        ? errorObj.message
        : "Turn failed";
      this.emitMessage({
        type: "result",
        subtype: "error",
        error: message,
        sessionId: this._threadId ?? undefined,
      });
    } else if (status === "interrupted") {
      this.emitMessage({
        type: "result",
        subtype: "interrupted",
        sessionId: this._threadId ?? undefined,
      });
    } else {
      this.emitMessage({
        type: "result",
        subtype: "success",
        sessionId: this._threadId ?? undefined,
        ...(usage?.input != null ? { inputTokens: usage.input } : {}),
        ...(usage?.cachedInput != null ? { cachedInputTokens: usage.cachedInput } : {}),
        ...(usage?.output != null ? { outputTokens: usage.output } : {}),
      });
    }

    this.pendingTurnId = null;

    // Plan mode: emit synthetic plan approval and wait for user decision
    if (this._collaborationMode === "plan" && this.lastPlanItemText) {
      const toolUseId = `plan_${randomUUID()}`;
      this.pendingPlanCompletion = {
        toolUseId,
        planText: this.lastPlanItemText,
      };
      this.lastPlanItemText = null;

      this.emitMessage({
        type: "permission_request",
        toolUseId,
        toolName: "ExitPlanMode",
        input: { plan: this.pendingPlanCompletion.planText },
      });
      this.setStatus("waiting_approval");
      // Do NOT set idle — waiting for plan approval
    } else {
      this.lastPlanItemText = null;
      if (this.pendingApprovals.size === 0 && this.pendingUserInputs.size === 0) {
        this.setStatus("idle");
      }
    }

    if (this.pendingTurnCompletion) {
      this.pendingTurnCompletion.resolve();
      this.pendingTurnCompletion = null;
    }
  }

  private processItemStarted(item: Record<string, unknown> | undefined): void {
    if (!item || typeof item !== "object") return;
    const itemId = typeof item.id === "string" ? item.id : randomUUID();
    const itemType = normalizeItemType(item.type);

    switch (itemType) {
      case "commandexecution": {
        const commandText = typeof item.command === "string"
          ? item.command
          : Array.isArray(item.command)
            ? item.command.map((part) => String(part)).join(" ")
            : "";
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: itemId,
                name: "Bash",
                input: { command: commandText },
              },
            ],
            model: "codex",
          },
        });
        break;
      }

      case "filechange": {
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: itemId,
                name: "FileChange",
                input: {
                  changes: Array.isArray(item.changes) ? item.changes : [],
                },
              },
            ],
            model: "codex",
          },
        });
        break;
      }

      default:
        break;
    }
  }

  private processItemCompleted(item: Record<string, unknown> | undefined): void {
    if (!item || typeof item !== "object") return;
    const itemId = typeof item.id === "string" ? item.id : randomUUID();
    const itemType = normalizeItemType(item.type);

    switch (itemType) {
      case "agentmessage": {
        const text = extractAgentText(item);
        if (!text) return;
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [{ type: "text", text }],
            model: "codex",
          },
        });
        break;
      }

      case "reasoning": {
        const text = extractReasoningText(item);
        if (text) {
          this.emitMessage({ type: "thinking_delta", text });
        }
        break;
      }

      case "commandexecution": {
        const output = typeof item.aggregatedOutput === "string"
          ? item.aggregatedOutput
          : typeof item.output === "string"
            ? item.output
            : "";
        const exitCode = numberOrUndefined(item.exitCode ?? item.exit_code);
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content: output || `exit code: ${exitCode ?? "unknown"}`,
          toolName: "Bash",
        });
        break;
      }

      case "filechange": {
        const content = formatFileChangesWithDiff(item.changes);
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content,
          toolName: "FileChange",
        });
        break;
      }

      case "mcptoolcall": {
        const server = typeof item.server === "string" ? item.server : "mcp";
        const tool = typeof item.tool === "string" ? item.tool : "unknown";
        const toolName = `mcp:${server}/${tool}`;
        const result = item.result ?? item.error ?? "MCP call completed";
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: itemId,
                name: toolName,
                input: (item.arguments as Record<string, unknown>) ?? {},
              },
            ],
            model: "codex",
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content: typeof result === "string" ? result : JSON.stringify(result),
          toolName,
        });
        break;
      }

      case "websearch": {
        const query = typeof item.query === "string" ? item.query : "";
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: itemId,
                name: "WebSearch",
                input: { query },
              },
            ],
            model: "codex",
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content: query ? `Web search: ${query}` : "Web search completed",
          toolName: "WebSearch",
        });
        break;
      }

      case "plan": {
        // Plan item completed — save text for plan approval emission in handleTurnCompleted()
        const planText = typeof item.text === "string" ? item.text : "";
        this.lastPlanItemText = planText;
        break;
      }

      case "error": {
        const message = typeof item.message === "string" ? item.message : "Codex item error";
        this.emitMessage({ type: "error", message });
        break;
      }

      default:
        break;
    }
  }

  private async toRpcInput(
    pendingInput: PendingInput,
  ): Promise<{ input: Array<Record<string, unknown>> | null; tempPaths: string[] }> {
    const input: Array<Record<string, unknown>> = [{ type: "text", text: pendingInput.text }];
    const tempPaths: string[] = [];

    if (!pendingInput.images || pendingInput.images.length === 0) {
      return { input, tempPaths };
    }

    for (const image of pendingInput.images) {
      const ext = extensionFromMime(image.mimeType);
      if (!ext) {
        this.emitMessage({
          type: "error",
          message: `Unsupported image mime type for Codex: ${image.mimeType}`,
        });
        continue;
      }

      let buffer: Buffer;
      try {
        buffer = Buffer.from(image.base64, "base64");
      } catch {
        this.emitMessage({
          type: "error",
          message: "Invalid base64 image data for Codex input",
        });
        continue;
      }

      const tempPath = join(tmpdir(), `ccpocket-codex-image-${randomUUID()}.${ext}`);
      await writeFile(tempPath, buffer);
      tempPaths.push(tempPath);
      input.push({ type: "localImage", path: tempPath });
    }

    return { input, tempPaths };
  }

  private request(method: string, params: Record<string, unknown>): Promise<unknown> {
    const id = this.rpcSeq++;
    const envelope = { id, method, params };

    return new Promise<unknown>((resolve, reject) => {
      this.pendingRpc.set(id, { resolve, reject, method });
      try {
        this.writeEnvelope(envelope);
      } catch (err) {
        this.pendingRpc.delete(id);
        reject(err instanceof Error ? err : new Error(String(err)));
      }
    });
  }

  private notify(method: string, params: Record<string, unknown>): void {
    this.writeEnvelope({ method, params });
  }

  private respondToServerRequest(id: number | string, result: Record<string, unknown>): void {
    try {
      this.writeEnvelope({ id, result });
    } catch (err) {
      if (!this.stopped) {
        console.warn(`[codex-process] failed to respond to server request: ${err instanceof Error ? err.message : String(err)}`);
      }
    }
  }

  private writeEnvelope(envelope: Record<string, unknown>): void {
    if (!this.child || this.child.killed) {
      throw new Error("codex app-server is not running");
    }
    const line = `${JSON.stringify(envelope)}\n`;
    this.child.stdin.write(line);
  }

  private rejectAllPending(error: Error): void {
    for (const pending of this.pendingRpc.values()) {
      pending.reject(error);
    }
    this.pendingRpc.clear();

    if (this.pendingTurnCompletion) {
      this.pendingTurnCompletion.reject(error);
      this.pendingTurnCompletion = null;
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

  private extractToolUseId(params: Record<string, unknown>, requestId: number | string): string {
    if (typeof params.approvalId === "string") return params.approvalId;
    if (typeof params.itemId === "string") return params.itemId;
    if (typeof requestId === "string") return requestId;
    return `approval-${requestId}`;
  }
}

function normalizeApprovalPolicy(value: CodexStartOptions["approvalPolicy"]): string {
  switch (value) {
    case "on-request":
      return "on-request";
    case "on-failure":
      return "on-failure";
    case "untrusted":
      return "untrusted";
    case "never":
    default:
      return "never";
  }
}

function normalizeSandboxMode(value: CodexStartOptions["sandboxMode"]): string {
  switch (value) {
    case "read-only":
      return "read-only";
    case "danger-full-access":
      return "danger-full-access";
    case "workspace-write":
    default:
      return "workspace-write";
  }
}

function normalizeReasoningEffort(value: NonNullable<CodexStartOptions["modelReasoningEffort"]>): string {
  switch (value) {
    case "xhigh":
      return "high";
    default:
      return value;
  }
}

function normalizeItemType(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.replace(/[_\s-]/g, "").toLowerCase();
}

function numberOrUndefined(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function summarizeFileChanges(changes: unknown): string {
  if (!Array.isArray(changes) || changes.length === 0) {
    return "No file changes";
  }

  return changes
    .map((entry) => {
      if (!entry || typeof entry !== "object") return "changed";
      const record = entry as Record<string, unknown>;
      const kind = typeof record.kind === "string" ? record.kind : "changed";
      const path = typeof record.path === "string" ? record.path : "(unknown)";
      return `${kind}: ${path}`;
    })
    .join("\n");
}

/**
 * Format file changes including unified diff content for display in chat.
 * Falls back to `kind: path` summary when no diff is available.
 */
function formatFileChangesWithDiff(changes: unknown): string {
  if (!Array.isArray(changes) || changes.length === 0) {
    return "No file changes";
  }

  return changes
    .map((entry) => {
      if (!entry || typeof entry !== "object") return "changed";
      const record = entry as Record<string, unknown>;
      const kind = typeof record.kind === "string" ? record.kind : "changed";
      const path = typeof record.path === "string" ? record.path : "(unknown)";
      const diff = typeof record.diff === "string" ? record.diff.trim() : "";

      if (diff) {
        // If diff already has unified headers, use as-is; otherwise add them
        if (diff.startsWith("---") || diff.startsWith("@@")) {
          return `--- a/${path}\n+++ b/${path}\n${diff}`;
        }
        return diff;
      }
      return `${kind}: ${path}`;
    })
    .join("\n\n");
}

function extractAgentText(item: Record<string, unknown>): string {
  if (typeof item.text === "string") return item.text;

  const parts = item.content;
  if (Array.isArray(parts)) {
    const text = parts
      .filter((part) => part && typeof part === "object")
      .map((part) => {
        const record = part as Record<string, unknown>;
        if (record.type === "text" && typeof record.text === "string") {
          return record.text;
        }
        return "";
      })
      .filter((part) => part.length > 0)
      .join("\n");
    if (text) return text;
  }

  return "";
}

function extractReasoningText(item: Record<string, unknown>): string {
  if (typeof item.text === "string") return item.text;

  const summary = item.summary;
  if (Array.isArray(summary)) {
    const text = summary
      .map((entry) => {
        if (!entry || typeof entry !== "object") return "";
        const record = entry as Record<string, unknown>;
        return typeof record.text === "string" ? record.text : "";
      })
      .filter((part) => part.length > 0)
      .join("\n");
    if (text) return text;
  }

  return "";
}

function normalizeUserInputQuestions(raw: unknown): Array<{
  id: string;
  question: string;
  header: string;
  options: Array<{ label: string; description: string }>;
  isOther: boolean;
  isSecret: boolean;
}> {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === "object")
    .map((entry, index) => {
      const id = typeof entry.id === "string" ? entry.id : `question_${index + 1}`;
      const question = typeof entry.question === "string" ? entry.question : "";
      const header = typeof entry.header === "string" ? entry.header : `Question ${index + 1}`;
      const optionsRaw = Array.isArray(entry.options) ? entry.options : [];
      const options = optionsRaw
        .filter((option): option is Record<string, unknown> => !!option && typeof option === "object")
        .map((option) => ({
          label: typeof option.label === "string" ? option.label : "",
          description: typeof option.description === "string" ? option.description : "",
        }))
        .filter((option) => option.label.length > 0);
      return {
        id,
        question,
        header,
        options,
        isOther: Boolean(entry.isOther),
        isSecret: Boolean(entry.isSecret),
      };
    })
    .filter((question) => question.question.length > 0);
}

function buildUserInputAnswers(
  questions: PendingUserInputQuestion[],
  rawResult: string,
): Record<string, { answers: string[] }> {
  const parsed = parseResultObject(rawResult);
  const answerMap: Record<string, { answers: string[] }> = {};

  for (const question of questions) {
    const candidate = parsed.byId[question.id] ?? parsed.byQuestion[question.question];
    const answers = normalizeAnswerValues(candidate);
    if (answers.length > 0) {
      answerMap[question.id] = { answers };
    }
  }

  if (Object.keys(answerMap).length === 0 && questions.length > 0) {
    answerMap[questions[0].id] = { answers: normalizeAnswerValues(rawResult) };
  }

  return answerMap;
}

function parseResultObject(rawResult: string): {
  byId: Record<string, unknown>;
  byQuestion: Record<string, unknown>;
} {
  try {
    const parsed = JSON.parse(rawResult) as Record<string, unknown>;
    const byId: Record<string, unknown> = {};
    const byQuestion: Record<string, unknown> = {};

    if (parsed && typeof parsed === "object") {
      const answers = parsed.answers;
      if (answers && typeof answers === "object" && !Array.isArray(answers)) {
        for (const [key, value] of Object.entries(answers as Record<string, unknown>)) {
          byId[key] = value;
          byQuestion[key] = value;
        }
      }
    }

    return { byId, byQuestion };
  } catch {
    return { byId: {}, byQuestion: {} };
  }
}

function normalizeAnswerValues(value: unknown): string[] {
  if (typeof value === "string") {
    return value
      .split(",")
      .map((part) => part.trim())
      .filter((part) => part.length > 0);
  }

  if (Array.isArray(value)) {
    return value
      .map((entry) => String(entry).trim())
      .filter((entry) => entry.length > 0);
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (Array.isArray(record.answers)) {
      return record.answers
        .map((entry) => String(entry).trim())
        .filter((entry) => entry.length > 0);
    }
  }

  if (value == null) return [];
  const normalized = String(value).trim();
  return normalized ? [normalized] : [];
}

function formatPlanUpdateText(params: Record<string, unknown>): string {
  const stepsRaw = params.plan;
  if (!Array.isArray(stepsRaw) || stepsRaw.length === 0) return "";

  const explanation = typeof params.explanation === "string" ? params.explanation.trim() : "";
  const lines = stepsRaw
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === "object")
    .map((entry, index) => {
      const step = typeof entry.step === "string" ? entry.step : `Step ${index + 1}`;
      const status = normalizePlanStatus(entry.status);
      return `${index + 1}. [${status}] ${step}`;
    });

  if (lines.length === 0) return "";
  const header = explanation ? `Plan update: ${explanation}` : "Plan update:";
  return `${header}\n${lines.join("\n")}`;
}

function normalizePlanStatus(raw: unknown): string {
  switch (raw) {
    case "inProgress":
      return "in progress";
    case "completed":
      return "completed";
    case "pending":
    default:
      return "pending";
  }
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
