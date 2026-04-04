import { EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import { createServer, type Server } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { rm, writeFile } from "node:fs/promises";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { WebSocket } from "ws";
import type { ServerMessage, ProcessStatus } from "./parser.js";
import type { IProcessTransport, ProcessStartOptions } from "./process-transport.js";

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
  skill?: { name: string; path: string };
}

/** Skill metadata returned by the Codex `skills/list` RPC. */
export interface CodexSkillMetadata {
  name: string;
  path: string;
  description: string;
  shortDescription?: string;
  enabled: boolean;
  scope: string;
  displayName?: string;
  defaultPrompt?: string;
  brandColor?: string;
}

export interface CodexThreadSummary {
  id: string;
  preview: string;
  createdAt: number;
  updatedAt: number;
  cwd: string;
  agentNickname: string | null;
  agentRole: string | null;
  gitBranch: string | null;
  name: string | null;
}

interface PendingApproval {
  requestId: string | number;
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
  kind: "command" | "file" | "permissions";
  requestedPermissions?: Record<string, unknown>;
}

interface PendingUserInputQuestion {
  id: string;
  question: string;
}

interface PendingUserInputRequest {
  requestId: string | number;
  toolUseId: string;
  toolName: string;
  questions: PendingUserInputQuestion[];
  input: Record<string, unknown>;
  kind: "questions" | "elicitation_form" | "elicitation_url";
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

interface CodexResolvedSettings {
  model?: string;
  approvalPolicy?: string;
  sandboxMode?: string;
  modelReasoningEffort?: string;
  networkAccessEnabled?: boolean;
  webSearchMode?: string;
}

export class CodexProcess extends EventEmitter<CodexProcessEvents> implements IProcessTransport {
  private child: ChildProcessWithoutNullStreams | null = null;
  private wsClient: WebSocket | null = null;
  private _appServerPort: number | null = null;
  private _status: ProcessStatus = "starting";
  private _threadId: string | null = null;
  private _agentNickname: string | null = null;
  private _agentRole: string | null = null;
  private stopped = false;
  private startModel: string | undefined;

  private inputResolve: ((input: PendingInput) => void) | null = null;
  private pendingTurnId: string | null = null;
  private pendingTurnCompletion: PendingTurnCompletion | null = null;
  private pendingApprovals = new Map<string, PendingApproval>();
  private pendingUserInputs = new Map<string, PendingUserInputRequest>();
  private lastTokenUsage: {
    input?: number;
    cachedInput?: number;
    output?: number;
  } | null = null;

  /** Full skill metadata from the last `skills/list` response. */
  private _skills: CodexSkillMetadata[] = [];
  /** Project path stored for re-fetching skills on `skills/changed`. */
  private _projectPath: string | null = null;

  /** Expose skill metadata so session/websocket can access it. */
  get skills(): CodexSkillMetadata[] {
    return this._skills;
  }

  private rpcSeq = 1;
  private pendingRpc = new Map<
    number,
    {
      resolve: (value: unknown) => void;
      reject: (error: Error) => void;
      method: string;
    }
  >();

  /** Port the Codex app-server WS is listening on (for sidecar --remote). */
  get appServerPort(): number | null {
    return this._appServerPort;
  }

  // Collaboration mode & plan completion state
  private _approvalPolicy: string = "never";
  private _collaborationMode: "plan" | "default" = "default";
  private lastPlanItemText: string | null = null;
  /** Last assistant text message — used as `result` in completion notification. */
  private lastResultText: string | null = null;
  private pendingPlanCompletion: {
    toolUseId: string;
    planText: string;
  } | null = null;
  /** Queued plan execution text when inputResolve wasn't ready at approval time. */
  private _pendingPlanInput: string | null = null;

  get status(): ProcessStatus {
    return this._status;
  }

  get isWaitingForInput(): boolean {
    return this.inputResolve !== null;
  }

  private getMessageModel(): string {
    return sanitizeCodexModel(this.startModel) ?? "";
  }

  get sessionId(): string | null {
    return this._threadId;
  }

  get agentNickname(): string | null {
    return this._agentNickname;
  }

  get agentRole(): string | null {
    return this._agentRole;
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

  /**
   * Rename a thread via the app-server RPC.
   * Sends thread/name/set which persists to ~/.codex/session_index.jsonl.
   */
  async renameThread(name: string): Promise<void> {
    if (!this._threadId) {
      throw new Error("No thread ID available for rename");
    }
    await this.request("thread/name/set", {
      threadId: this._threadId,
      name,
    });
  }

  /**
   * Archive a Codex thread via the app-server `thread/archive` RPC.
   * Accepts an explicit threadId so that historical (non-active) sessions
   * can be archived without requiring a running process.
   */
  async archiveThread(threadId: string): Promise<void> {
    await this.request("thread/archive", { threadId });
  }

  async listThreads(
    params: {
      limit?: number;
      cursor?: string | null;
      cwd?: string;
      searchTerm?: string;
    } = {},
  ): Promise<{ data: CodexThreadSummary[]; nextCursor: string | null }> {
    const result = (await this.request("thread/list", {
      sortKey: "updated_at",
      archived: false,
      ...(params.limit != null ? { limit: params.limit } : {}),
      ...(params.cursor !== undefined ? { cursor: params.cursor } : {}),
      ...(params.cwd ? { cwd: params.cwd } : {}),
      ...(params.searchTerm ? { searchTerm: params.searchTerm } : {}),
    })) as { data?: unknown[]; nextCursor?: unknown };

    const data = Array.isArray(result.data)
      ? result.data.map((entry) => toCodexThreadSummary(entry))
      : [];
    return {
      data,
      nextCursor:
        typeof result.nextCursor === "string" ? result.nextCursor : null,
    };
  }

  start(optsOrPath: ProcessStartOptions | string, options?: CodexStartOptions): void {
    if (typeof optsOrPath !== "string") {
      // IProcessTransport call — adapt to existing pattern
      const opts = optsOrPath;
      return this.start(opts.projectPath, {
        threadId: opts.sessionId,
        model: opts.model,
      });
    }
    const projectPath = optsOrPath;

    if (this.child) {
      this.stop();
    }

    this.prepareLaunch(projectPath, options);

    void this.launchAppServer(projectPath, options).then(() => {
      if (!this.stopped) {
        void this.bootstrap(projectPath, options);
      }
    }).catch((err) => {
      if (!this.stopped) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`[codex-process] Failed to launch app-server: ${message}`);
        this.emitMessage({ type: "error", message });
        this.setStatus("idle");
        this.emit("exit", 1);
      }
    });
  }

  async initializeOnly(projectPath: string): Promise<void> {
    if (this.child) {
      this.stop();
    }
    this.prepareLaunch(projectPath);
    await this.launchAppServer(projectPath);
    await this.initializeRpcConnection();
    this.setStatus("idle");
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

    this.closeWs();

    if (this.child) {
      this.child.kill("SIGTERM");
      this.child = null;
    }

    this._appServerPort = null;
    this.setStatus("idle");
    console.log("[codex-process] Stopped");
  }

  private prepareLaunch(
    projectPath: string,
    options?: CodexStartOptions,
  ): void {
    this.stopped = false;
    this.closeWs();
    this._appServerPort = null;
    this._threadId = null;
    this._agentNickname = null;
    this._agentRole = null;
    this.pendingTurnId = null;
    this.pendingTurnCompletion = null;
    this.pendingApprovals.clear();
    this.pendingUserInputs.clear();
    this.lastTokenUsage = null;
    this.startModel = sanitizeCodexModel(options?.model);
    this._approvalPolicy = options?.approvalPolicy ?? "never";
    this._collaborationMode = options?.collaborationMode ?? "default";
    this.lastPlanItemText = null;
    this.lastResultText = null;
    this.pendingPlanCompletion = null;
    this._pendingPlanInput = null;
    this._projectPath = projectPath;
  }

  private async launchAppServer(
    projectPath: string,
    options?: CodexStartOptions,
  ): Promise<void> {
    const port = await findFreePort();
    this._appServerPort = port;
    const listenUrl = `ws://0.0.0.0:${port}`;

    console.log(
      `[codex-process] Starting app-server (cwd: ${projectPath}, listen: ${listenUrl}, sandbox: ${options?.sandboxMode ?? "workspace-write"}, approval: ${options?.approvalPolicy ?? "never"}, model: ${options?.model ?? "default"}, collaboration: ${this._collaborationMode})`,
    );

    const child = spawn("codex", ["app-server", "--listen", listenUrl], {
      cwd: projectPath,
      stdio: "pipe",
      env: process.env,
    });
    this.child = child;

    // app-server still writes logs to stdout/stderr — drain them
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) console.log(`[codex-process] stdout: ${line}`);
    });

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      const line = chunk.trim();
      if (line) console.log(`[codex-process] stderr: ${line}`);
    });

    child.on("error", (err) => {
      if (this.stopped) return;
      console.error("[codex-process] app-server process error:", err);
      this.emitMessage({
        type: "error",
        message: `Failed to start codex app-server: ${err.message}`,
      });
      this.setStatus("idle");
      this.emit("exit", 1);
    });

    child.on("exit", (code) => {
      const exitCode = code ?? 0;
      this.child = null;
      this.closeWs();
      this.rejectAllPending(new Error("codex app-server exited"));
      if (!this.stopped && exitCode !== 0) {
        this.emitMessage({
          type: "error",
          message: `codex app-server exited with code ${exitCode}`,
        });
      }
      this.setStatus("idle");
      this.emit("exit", code);
    });

    // Connect WebSocket client to the app-server
    await this.connectWs(port);
  }

  /**
   * Connect a WebSocket client to the app-server.
   * Retries briefly to allow the server time to bind.
   */
  private connectWs(port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const url = `ws://127.0.0.1:${port}`;
      let attempts = 0;
      const maxAttempts = 30; // 30 × 200ms = 6s max wait

      const tryConnect = () => {
        if (this.stopped || !this.child) {
          reject(new Error("app-server stopped before WS connected"));
          return;
        }

        attempts++;
        const ws = new WebSocket(url);

        ws.on("open", () => {
          console.log(`[codex-process] WS connected to app-server on port ${port}`);
          this.wsClient = ws;
          resolve();
        });

        ws.on("message", (data: Buffer | string) => {
          const raw = typeof data === "string" ? data : data.toString("utf8");
          // Each WS message is one complete JSON-RPC envelope
          for (const line of raw.split("\n")) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            try {
              const envelope = JSON.parse(trimmed) as JsonRpcEnvelope;
              this.handleRpcEnvelope(envelope);
            } catch (err) {
              console.warn(
                `[codex-process] failed to parse app-server WS message: ${trimmed.slice(0, 200)}`,
              );
              if (!this.stopped) {
                this.emitMessage({
                  type: "error",
                  message: `Failed to parse codex app-server output: ${err instanceof Error ? err.message : String(err)}`,
                });
              }
            }
          }
        });

        ws.on("close", () => {
          if (!this.stopped && this.wsClient === ws) {
            console.log("[codex-process] WS connection closed by app-server");
            this.wsClient = null;
          }
        });

        ws.on("error", (err) => {
          ws.removeAllListeners();
          ws.terminate();
          if (attempts < maxAttempts) {
            setTimeout(tryConnect, 200);
          } else {
            const msg = `Failed to connect WS to app-server after ${maxAttempts} attempts: ${err.message}`;
            console.error(`[codex-process] ${msg}`);
            reject(new Error(msg));
          }
        });
      };

      // Small initial delay to let the process bind
      setTimeout(tryConnect, 50);
    });
  }

  private closeWs(): void {
    if (this.wsClient) {
      this.wsClient.removeAllListeners();
      this.wsClient.terminate();
      this.wsClient = null;
    }
  }

  interrupt(): void {
    if (!this._threadId || !this.pendingTurnId) return;

    void this.request("turn/interrupt", {
      threadId: this._threadId,
      turnId: this.pendingTurnId,
    }).catch((err) => {
      if (!this.stopped) {
        console.warn(
          `[codex-process] turn/interrupt failed: ${err instanceof Error ? err.message : String(err)}`,
        );
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

  sendInputWithImages(
    text: string,
    images: Array<{ base64: string; mimeType: string }>,
  ): void {
    if (!this.inputResolve) {
      console.error(
        "[codex-process] No pending input resolver for sendInputWithImages",
      );
      return;
    }
    const resolve = this.inputResolve;
    this.inputResolve = null;
    resolve({ text, images });
  }

  sendInputWithSkill(
    text: string,
    skill: { name: string; path: string },
  ): void {
    if (!this.inputResolve) {
      console.error(
        "[codex-process] No pending input resolver for sendInputWithSkill",
      );
      return;
    }
    const resolve = this.inputResolve;
    this.inputResolve = null;
    resolve({ text, skill });
  }

  approve(toolUseId?: string, _updatedInput?: Record<string, unknown>): void {
    // Check if this is a plan completion approval
    if (
      this.pendingPlanCompletion &&
      toolUseId === this.pendingPlanCompletion.toolUseId
    ) {
      this.handlePlanApproved(_updatedInput);
      return;
    }

    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log(
        "[codex-process] approve() called but no pending permission requests",
      );
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(
      pending.requestId,
      buildApprovalResponse(pending, "accept"),
    );
    this.emitToolResult(pending.toolUseId, "Approved");

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  approveAlways(toolUseId?: string): void {
    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log(
        "[codex-process] approveAlways() called but no pending permission requests",
      );
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(
      pending.requestId,
      buildApprovalResponse(pending, "acceptForSession"),
    );
    this.emitToolResult(pending.toolUseId, "Approved (always)");

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  reject(toolUseId?: string, _message?: string): void {
    // Check if this is a plan completion rejection
    if (
      this.pendingPlanCompletion &&
      toolUseId === this.pendingPlanCompletion.toolUseId
    ) {
      this.handlePlanRejected(_message);
      return;
    }

    const pending = this.resolvePendingApproval(toolUseId);
    if (!pending) {
      console.log(
        "[codex-process] reject() called but no pending permission requests",
      );
      return;
    }

    this.pendingApprovals.delete(pending.toolUseId);
    this.respondToServerRequest(
      pending.requestId,
      buildApprovalResponse(pending, "decline"),
    );
    this.emitToolResult(pending.toolUseId, "Rejected");

    if (this.pendingApprovals.size === 0) {
      this.setStatus("running");
    }
  }

  answer(toolUseId: string, result: string): void {
    const pending = this.resolvePendingUserInput(toolUseId);
    if (!pending) {
      console.log(
        "[codex-process] answer() called but no pending AskUserQuestion",
      );
      return;
    }

    this.pendingUserInputs.delete(pending.toolUseId);
    this.respondToServerRequest(
      pending.requestId,
      buildUserInputResponse(pending, result),
    );

    this.emitToolResult(pending.toolUseId, "Answered");

    if (this.pendingApprovals.size === 0 && this.pendingUserInputs.size === 0) {
      this.setStatus("running");
    }
  }

  getPendingPermission(
    toolUseId?: string,
  ):
    | { toolUseId: string; toolName: string; input: Record<string, unknown> }
    | undefined {
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

  /** Emit a synthetic tool_result so history replay can match it to a permission_request. */
  private emitToolResult(toolUseId: string, content: string): void {
    this.emitMessage({
      type: "tool_result",
      toolUseId,
      content,
    });
  }

  private resolvePendingApproval(
    toolUseId?: string,
  ): PendingApproval | undefined {
    if (toolUseId) return this.pendingApprovals.get(toolUseId);
    const first = this.pendingApprovals.values().next();
    return first.done ? undefined : first.value;
  }

  private resolvePendingUserInput(
    toolUseId?: string,
  ): PendingUserInputRequest | undefined {
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
    const planText =
      (updatedInput?.plan as string) ??
      this.pendingPlanCompletion?.planText ??
      "";
    const resolvedToolUseId = this.pendingPlanCompletion?.toolUseId;
    this.pendingPlanCompletion = null;
    this._collaborationMode = "default";
    console.log("[codex-process] Plan approved, switching to Default mode");

    // Emit synthetic tool_result so history replay knows this approval is resolved
    if (resolvedToolUseId) {
      this.emitToolResult(resolvedToolUseId, "Plan approved");
    }

    // Resolve inputResolve to start the next turn (Default mode) automatically
    if (this.inputResolve) {
      const resolve = this.inputResolve;
      this.inputResolve = null;
      resolve({ text: `Execute the following plan:\n\n${planText}` });
    } else {
      // inputResolve may not be ready yet if approval comes before the next
      // input loop iteration.  Queue the text so sendInput() can pick it up.
      console.warn(
        "[codex-process] Plan approved but inputResolve not ready, queuing as pending input",
      );
      this._pendingPlanInput = `Execute the following plan:\n\n${planText}`;
    }
  }

  /**
   * Plan rejected → stay in Plan mode and re-plan with feedback.
   */
  private handlePlanRejected(feedback?: string): void {
    const resolvedToolUseId = this.pendingPlanCompletion?.toolUseId;
    this.pendingPlanCompletion = null;
    console.log("[codex-process] Plan rejected, continuing in Plan mode");
    // Stay in Plan mode

    // Emit synthetic tool_result so history replay knows this approval is resolved
    if (resolvedToolUseId) {
      this.emitToolResult(resolvedToolUseId, "Plan rejected");
    }

    if (feedback) {
      if (this.inputResolve) {
        const resolve = this.inputResolve;
        this.inputResolve = null;
        resolve({ text: feedback });
      } else {
        console.warn(
          "[codex-process] Plan rejected but inputResolve not ready, queuing feedback",
        );
        this._pendingPlanInput = feedback;
      }
    } else {
      this.setStatus("idle");
    }
  }

  private async bootstrap(
    projectPath: string,
    options?: CodexStartOptions,
  ): Promise<void> {
    try {
      await this.initializeRpcConnection();

      const threadParams: Record<string, unknown> = {
        cwd: projectPath,
        approvalPolicy: normalizeApprovalPolicy(
          options?.approvalPolicy ?? "never",
        ),
        sandbox: normalizeSandboxMode(
          options?.sandboxMode ?? "workspace-write",
        ),
        experimentalRawEvents: false,
        persistExtendedHistory: true,
      };
      const requestedModel = sanitizeCodexModel(options?.model);
      if (requestedModel) threadParams.model = requestedModel;
      if (options?.modelReasoningEffort) {
        threadParams.effort = normalizeReasoningEffort(
          options.modelReasoningEffort,
        );
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
      } else {
        threadParams.experimentalRawEvents = false;
      }
      if (options?.threadId) {
        threadParams.persistExtendedHistory = true;
      }

      const response = (await this.request(method, threadParams)) as Record<
        string,
        unknown
      >;
      const thread = response.thread as Record<string, unknown> | undefined;
      const threadId =
        typeof thread?.id === "string" ? thread.id : options?.threadId;
      if (!threadId) {
        throw new Error(`${method} returned no thread id`);
      }

      // Capture the resolved model name from thread response
      if (typeof thread?.model === "string" && thread.model) {
        this.startModel = thread.model;
      }
      const resolvedSettings =
        extractResolvedSettingsFromThreadResponse(response);
      if (resolvedSettings.model) {
        this.startModel = resolvedSettings.model;
      }

      this._threadId = threadId;
      this.emitMessage({
        type: "system",
        subtype: "init",
        sessionId: threadId,
        provider: "codex",
        ...(sanitizeCodexModel(this.startModel)
          ? { model: sanitizeCodexModel(this.startModel) }
          : {}),
        ...(resolvedSettings.approvalPolicy
          ? { approvalPolicy: resolvedSettings.approvalPolicy }
          : {}),
        ...(resolvedSettings.sandboxMode
          ? { sandboxMode: resolvedSettings.sandboxMode }
          : {}),
        ...(resolvedSettings.modelReasoningEffort
          ? { modelReasoningEffort: resolvedSettings.modelReasoningEffort }
          : {}),
        ...(resolvedSettings.networkAccessEnabled !== undefined
          ? { networkAccessEnabled: resolvedSettings.networkAccessEnabled }
          : {}),
        ...(resolvedSettings.webSearchMode
          ? { webSearchMode: resolvedSettings.webSearchMode }
          : {}),
      });
      this.setStatus("idle");

      // Fetch skills in background (non-blocking)
      this._projectPath = projectPath;
      void this.fetchSkills(projectPath);

      await this.runInputLoop(options);
    } catch (err) {
      if (!this.stopped) {
        const message = err instanceof Error ? err.message : String(err);
        console.error("[codex-process] bootstrap error:", err);
        this.emitMessage({ type: "error", message: `Codex error: ${message}` });
        this.emitMessage({
          type: "result",
          subtype: "error",
          error: message,
          sessionId: this._threadId ?? undefined,
        });
      }
      this.setStatus("idle");
      this.emit("exit", 1);
    }
  }

  private async initializeRpcConnection(): Promise<void> {
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
  }

  /**
   * Fetch skills from Codex app-server via `skills/list` RPC and emit them
   * as a `supported_commands` system message so the Flutter client can display
   * skill entries alongside built-in slash commands.
   */
  private async fetchSkills(projectPath: string): Promise<void> {
    const TIMEOUT_MS = 10_000;
    try {
      interface SkillRaw {
        name: string;
        path: string;
        description: string;
        shortDescription?: string | null;
        enabled: boolean;
        scope: string;
        interface?: {
          displayName?: string | null;
          shortDescription?: string | null;
          defaultPrompt?: string | null;
          brandColor?: string | null;
        } | null;
      }
      const result = (await Promise.race([
        this.request("skills/list", { cwds: [projectPath] }),
        new Promise<null>((resolve) =>
          setTimeout(() => resolve(null), TIMEOUT_MS),
        ),
      ])) as { data?: Array<{ cwd: string; skills: SkillRaw[] }> } | null;

      if (this.stopped || !result?.data) return;

      const skills: string[] = [];
      const slashCommands: string[] = [];
      const skillMetadata: CodexSkillMetadata[] = [];
      for (const entry of result.data) {
        for (const skill of entry.skills) {
          if (skill.enabled) {
            skills.push(skill.name);
            slashCommands.push(skill.name);
            skillMetadata.push({
              name: skill.name,
              path: skill.path,
              description: skill.description,
              shortDescription:
                skill.shortDescription ??
                skill.interface?.shortDescription ??
                undefined,
              enabled: skill.enabled,
              scope: skill.scope,
              displayName: skill.interface?.displayName ?? undefined,
              defaultPrompt: skill.interface?.defaultPrompt ?? undefined,
              brandColor: skill.interface?.brandColor ?? undefined,
            });
          }
        }
      }
      this._skills = skillMetadata;
      if (slashCommands.length > 0) {
        console.log(
          `[codex-process] skills/list returned ${slashCommands.length} skills`,
        );
        this.emitMessage({
          type: "system",
          subtype: "supported_commands",
          slashCommands,
          skills,
          skillMetadata,
        });
      }
    } catch (err) {
      console.log(
        `[codex-process] skills/list failed (non-fatal): ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  private async runInputLoop(options?: CodexStartOptions): Promise<void> {
    while (!this.stopped) {
      const pendingInput = await new Promise<PendingInput>((resolve) => {
        this.inputResolve = resolve;
        // If plan approval arrived before inputResolve was ready, drain it now.
        if (this._pendingPlanInput) {
          const text = this._pendingPlanInput;
          this._pendingPlanInput = null;
          this.inputResolve = null;
          resolve({ text });
        }
      });
      if (this.stopped || !pendingInput.text) break;
      if (!this._threadId) {
        this.emitMessage({
          type: "error",
          message: "Codex thread is not initialized",
        });
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
        const requestedModel = sanitizeCodexModel(options?.model);
        if (requestedModel) params.model = requestedModel;
        if (options?.modelReasoningEffort) {
          params.effort = normalizeReasoningEffort(
            options.modelReasoningEffort,
          );
        }

        // Always send collaborationMode so the server switches modes correctly.
        // Omitting it causes the server to persist the previous turn's mode.
        const modeSettings: Record<string, unknown> = {
          model:
            requestedModel
            || sanitizeCodexModel(this.startModel)
            || "gpt-5.4",
        };
        if (this._collaborationMode === "plan") {
          modeSettings.reasoning_effort = "medium";
        }
        params.collaborationMode = {
          mode: this._collaborationMode,
          settings: modeSettings,
        };

        console.log(
          `[codex-process] turn/start: approval=${params.approvalPolicy}, collaboration=${this._collaborationMode}`,
        );
        void this.request("turn/start", params)
          .then((result) => {
            const turn = (result as Record<string, unknown>).turn as
              | Record<string, unknown>
              | undefined;
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

      await Promise.all(
        tempPaths.map((path) => rm(path, { force: true }).catch(() => {})),
      );
      void completion;
    }
  }

  private handleRpcEnvelope(envelope: JsonRpcEnvelope): void {
    if (
      envelope.id != null &&
      envelope.method &&
      envelope.result === undefined &&
      envelope.error === undefined
    ) {
      this.handleServerRequest(
        envelope.id,
        envelope.method,
        envelope.params ?? {},
      );
      return;
    }

    if (
      envelope.id != null &&
      (envelope.result !== undefined || envelope.error)
    ) {
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
      const message =
        envelope.error.message ?? `RPC error ${envelope.error.code ?? ""}`;
      pending.reject(new Error(message));
      return;
    }

    pending.resolve((envelope as RpcSuccess).result);
  }

  private handleServerRequest(
    id: number | string,
    method: string,
    params: Record<string, unknown>,
  ): void {
    switch (method) {
      case "item/commandExecution/requestApproval": {
        const toolUseId = this.extractToolUseId(params, id);
        const input: Record<string, unknown> = {
          ...(typeof params.command === "string"
            ? { command: params.command }
            : {}),
          ...(typeof params.cwd === "string" ? { cwd: params.cwd } : {}),
          ...(params.commandActions
            ? { commandActions: params.commandActions }
            : {}),
          ...(params.networkApprovalContext
            ? { networkApprovalContext: params.networkApprovalContext }
            : {}),
          ...(params.additionalPermissions
            ? { additionalPermissions: params.additionalPermissions }
            : {}),
          ...(params.skillMetadata
            ? { skillMetadata: params.skillMetadata }
            : {}),
          ...(params.proposedExecpolicyAmendment
            ? {
                proposedExecpolicyAmendment: params.proposedExecpolicyAmendment,
              }
            : {}),
          ...(params.proposedNetworkPolicyAmendments
            ? {
                proposedNetworkPolicyAmendments:
                  params.proposedNetworkPolicyAmendments,
              }
            : {}),
          ...(params.availableDecisions
            ? { availableDecisions: params.availableDecisions }
            : {}),
          ...(typeof params.reason === "string"
            ? { reason: params.reason }
            : {}),
        };

        this.pendingApprovals.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "Bash",
          input,
          kind: "command",
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
          ...(typeof params.grantRoot === "string"
            ? { grantRoot: params.grantRoot }
            : {}),
          ...(typeof params.reason === "string"
            ? { reason: params.reason }
            : {}),
        };

        this.pendingApprovals.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "FileChange",
          input,
          kind: "file",
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
          toolName: "AskUserQuestion",
          questions: questions.map((q) => ({
            id: q.id,
            question: q.question,
          })),
          input,
          kind: "questions",
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

      case "item/permissions/requestApproval": {
        const toolUseId = this.extractToolUseId(params, id);
        const requestedPermissions = asRecord(params.permissions) ?? {};
        const input: Record<string, unknown> = {
          permissions: requestedPermissions,
          ...(typeof params.reason === "string"
            ? { reason: params.reason }
            : {}),
        };

        this.pendingApprovals.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "Permissions",
          input,
          kind: "permissions",
          requestedPermissions,
        });
        this.emitMessage({
          type: "permission_request",
          toolUseId,
          toolName: "Permissions",
          input,
        });
        this.setStatus("waiting_approval");
        break;
      }

      case "mcpServer/elicitation/request": {
        const toolUseId = this.extractToolUseId(params, id);
        const elicitation = createElicitationInput(params);
        this.pendingUserInputs.set(toolUseId, {
          requestId: id,
          toolUseId,
          toolName: "McpElicitation",
          questions: elicitation.questions,
          input: elicitation.input,
          kind: elicitation.kind,
        });
        this.emitMessage({
          type: "permission_request",
          toolUseId,
          toolName: "McpElicitation",
          input: elicitation.input,
        });
        this.setStatus("waiting_approval");
        break;
      }

      default:
        this.respondToServerRequest(id, {});
        break;
    }
  }

  private handleNotification(
    method: string,
    params: Record<string, unknown>,
  ): void {
    switch (method) {
      case "thread/started": {
        const thread = params.thread as Record<string, unknown> | undefined;
        if (typeof thread?.id === "string") {
          this._threadId = thread.id;
        }
        this._agentNickname = stringOrNull(thread?.agentNickname);
        this._agentRole = stringOrNull(thread?.agentRole);
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
        this.handleTurnCompleted(
          params.turn as Record<string, unknown> | undefined,
        );
        break;
      }

      case "thread/name/updated": {
        // Name change notification — handled by session manager
        break;
      }

      case "thread/tokenUsage/updated": {
        const usage = params.usage as Record<string, unknown> | undefined;
        if (usage) {
          this.lastTokenUsage = {
            input: numberOrUndefined(usage.inputTokens ?? usage.input_tokens),
            cachedInput: numberOrUndefined(
              usage.cachedInputTokens ?? usage.cached_input_tokens,
            ),
            output: numberOrUndefined(
              usage.outputTokens ?? usage.output_tokens,
            ),
          };
        }
        break;
      }

      case "item/started": {
        this.processItemStarted(
          params.item as Record<string, unknown> | undefined,
        );
        break;
      }

      case "item/completed": {
        this.processItemCompleted(
          params.item as Record<string, unknown> | undefined,
        );
        break;
      }

      case "item/agentMessage/delta": {
        const delta =
          typeof params.delta === "string"
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
        const delta =
          typeof params.delta === "string"
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

      case "skills/changed": {
        // Re-fetch skills when Codex notifies us of changes
        if (this._projectPath) {
          void this.fetchSkills(this._projectPath);
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
            model: this.getMessageModel(),
          },
        });
        break;
      }

      case "serverRequest/resolved": {
        this.handleServerRequestResolved(params);
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
      const message =
        typeof errorObj?.message === "string"
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
        ...(this.lastResultText ? { result: this.lastResultText } : {}),
        ...(usage?.input != null ? { inputTokens: usage.input } : {}),
        ...(usage?.cachedInput != null
          ? { cachedInputTokens: usage.cachedInput }
          : {}),
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
      if (
        this.pendingApprovals.size === 0 &&
        this.pendingUserInputs.size === 0
      ) {
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
        const commandText =
          typeof item.command === "string"
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
            model: this.getMessageModel(),
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
            model: this.getMessageModel(),
          },
        });
        break;
      }

      case "dynamictoolcall": {
        const tool = typeof item.tool === "string" ? item.tool : "DynamicTool";
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [
              {
                type: "tool_use",
                id: itemId,
                name: tool,
                input: toToolUseInput(item.arguments),
              },
            ],
            model: this.getMessageModel(),
          },
        });
        break;
      }

      case "collabagenttoolcall": {
        const tool = typeof item.tool === "string" ? item.tool : "subagent";
        const toolName = "SubAgent";
        const input: Record<string, unknown> = {
          tool,
          ...(typeof item.prompt === "string" ? { prompt: item.prompt } : {}),
          ...(typeof item.senderThreadId === "string"
            ? { senderThreadId: item.senderThreadId }
            : {}),
          ...(Array.isArray(item.receiverThreadIds)
            ? { receiverThreadIds: item.receiverThreadIds }
            : {}),
          ...(typeof item.model === "string" ? { model: item.model } : {}),
          ...(typeof item.reasoningEffort === "string"
            ? { reasoningEffort: item.reasoningEffort }
            : {}),
          ...(item.agentsStates ? { agentsStates: item.agentsStates } : {}),
        };
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
                input,
              },
            ],
            model: this.getMessageModel(),
          },
        });
        break;
      }

      default:
        break;
    }
  }

  private processItemCompleted(
    item: Record<string, unknown> | undefined,
  ): void {
    if (!item || typeof item !== "object") return;
    const itemId = typeof item.id === "string" ? item.id : randomUUID();
    const itemType = normalizeItemType(item.type);

    switch (itemType) {
      case "agentmessage": {
        const text = extractAgentText(item);
        if (!text) return;
        this.lastResultText = text;
        this.emitMessage({
          type: "assistant",
          message: {
            id: itemId,
            role: "assistant",
            content: [{ type: "text", text }],
            model: this.getMessageModel(),
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
        const output =
          typeof item.aggregatedOutput === "string"
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
        const normalized = normalizeMcpToolResult(result);
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
            model: this.getMessageModel(),
          },
        });
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content: normalized.content,
          toolName,
          ...(normalized.rawContentBlocks.length > 0
            ? { rawContentBlocks: normalized.rawContentBlocks }
            : {}),
        });
        break;
      }

      case "dynamictoolcall": {
        const tool = typeof item.tool === "string" ? item.tool : "DynamicTool";
        const content = formatDynamicToolResult(item);
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content,
          toolName: tool,
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
            model: this.getMessageModel(),
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

      case "collabagenttoolcall": {
        const tool = typeof item.tool === "string" ? item.tool : "subagent";
        const status =
          typeof item.status === "string" ? item.status : "completed";
        const receiverThreadIds = Array.isArray(item.receiverThreadIds)
          ? item.receiverThreadIds.map((entry) => String(entry))
          : [];
        const content = [
          `tool: ${tool}`,
          `status: ${status}`,
          ...(receiverThreadIds.length > 0
            ? [`agents: ${receiverThreadIds.join(", ")}`]
            : []),
        ].join("\n");
        this.emitMessage({
          type: "tool_result",
          toolUseId: itemId,
          content,
          toolName: "SubAgent",
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
        const message =
          typeof item.message === "string" ? item.message : "Codex item error";
        this.emitMessage({ type: "error", message });
        break;
      }

      default:
        break;
    }
  }

  private async toRpcInput(pendingInput: PendingInput): Promise<{
    input: Array<Record<string, unknown>> | null;
    tempPaths: string[];
  }> {
    const input: Array<Record<string, unknown>> = [];
    const tempPaths: string[] = [];

    // Prepend SkillUserInput if a skill reference is attached
    if (pendingInput.skill) {
      input.push({
        type: "skill",
        name: pendingInput.skill.name,
        path: pendingInput.skill.path,
      });
    }
    input.push({ type: "text", text: pendingInput.text });

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

      const tempPath = join(
        tmpdir(),
        `ccpocket-codex-image-${randomUUID()}.${ext}`,
      );
      await writeFile(tempPath, buffer);
      tempPaths.push(tempPath);
      input.push({ type: "localImage", path: tempPath });
    }

    return { input, tempPaths };
  }

  private request(
    method: string,
    params: Record<string, unknown>,
  ): Promise<unknown> {
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

  private respondToServerRequest(
    id: number | string,
    result: Record<string, unknown>,
  ): void {
    try {
      this.writeEnvelope({ id, result });
    } catch (err) {
      if (!this.stopped) {
        console.warn(
          `[codex-process] failed to respond to server request: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
  }

  private writeEnvelope(envelope: Record<string, unknown>): void {
    if (!this.wsClient || this.wsClient.readyState !== WebSocket.OPEN) {
      throw new Error("codex app-server WebSocket is not connected");
    }
    const line = `${JSON.stringify(envelope)}\n`;
    this.wsClient.send(line);
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

  private extractToolUseId(
    params: Record<string, unknown>,
    requestId: number | string,
  ): string {
    if (typeof params.approvalId === "string") return params.approvalId;
    if (typeof params.elicitationId === "string") return params.elicitationId;
    if (typeof params.itemId === "string") return params.itemId;
    if (typeof requestId === "string") return requestId;
    return `approval-${requestId}`;
  }

  private handleServerRequestResolved(params: Record<string, unknown>): void {
    const requestId = params.requestId;
    if (requestId === undefined || requestId === null) return;

    const approval = [...this.pendingApprovals.values()].find(
      (entry) => entry.requestId === requestId,
    );
    if (approval) {
      this.pendingApprovals.delete(approval.toolUseId);
      this.emitMessage({
        type: "permission_resolved",
        toolUseId: approval.toolUseId,
      });
    }

    const inputRequest = [...this.pendingUserInputs.values()].find(
      (entry) => entry.requestId === requestId,
    );
    if (inputRequest) {
      this.pendingUserInputs.delete(inputRequest.toolUseId);
      this.emitMessage({
        type: "permission_resolved",
        toolUseId: inputRequest.toolUseId,
      });
    }

    if (
      !this.pendingPlanCompletion &&
      this.pendingApprovals.size === 0 &&
      this.pendingUserInputs.size === 0
    ) {
      this.setStatus(this.pendingTurnId ? "running" : "idle");
    }
  }

  // ── IProcessTransport compat ───────────────────────────────────────

  /** Raw PTY write — no-op for Codex process. */
  write(_data: string): void {
    // No PTY — raw write not supported
  }

  /** Not a PTY process. */
  get isPty(): boolean {
    return false;
  }

  /** Forceful termination — delegates to graceful stop for Codex. */
  kill(): void {
    this.stop();
  }

  /** IProcessTransport approval bridge. */
  sendApproval(id: string): void {
    this.approve(id);
  }

  /** IProcessTransport rejection bridge. */
  sendRejection(id: string, _reason?: string): void {
    this.reject(id);
  }
}

function buildApprovalResponse(
  pending: PendingApproval,
  decision: "accept" | "acceptForSession" | "decline",
): Record<string, unknown> {
  if (pending.kind === "permissions") {
    return {
      scope: decision === "acceptForSession" ? "session" : "turn",
      permissions:
        decision === "decline" ? {} : (pending.requestedPermissions ?? {}),
    };
  }

  return {
    decision,
  };
}

function buildUserInputResponse(
  pending: PendingUserInputRequest,
  rawResult: string,
): Record<string, unknown> {
  if (pending.kind === "questions") {
    return {
      answers: buildUserInputAnswers(pending.questions, rawResult),
    };
  }

  return buildElicitationResponse(pending, rawResult);
}

function normalizeApprovalPolicy(
  value: CodexStartOptions["approvalPolicy"],
): string {
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

function normalizeReasoningEffort(
  value: NonNullable<CodexStartOptions["modelReasoningEffort"]>,
): string {
  switch (value) {
    case "xhigh":
      return "high";
    default:
      return value;
  }
}

function sanitizeCodexModel(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.trim();
  if (!normalized || normalized === "codex") return undefined;
  return normalized;
}

function extractResolvedSettingsFromThreadResponse(
  response: Record<string, unknown>,
): CodexResolvedSettings {
  const thread = response.thread as Record<string, unknown> | undefined;
  const sandbox = response.sandbox as Record<string, unknown> | undefined;

  return {
    model: sanitizeCodexModel(response.model)
      ?? sanitizeCodexModel(thread?.model),
    approvalPolicy:
      typeof response.approvalPolicy === "string"
        ? response.approvalPolicy
        : undefined,
    sandboxMode: normalizeSandboxModeFromRpc(sandbox?.type),
    modelReasoningEffort:
      typeof response.reasoningEffort === "string"
        ? response.reasoningEffort
        : undefined,
    networkAccessEnabled:
      typeof sandbox?.networkAccess === "boolean"
        ? sandbox.networkAccess
        : undefined,
    webSearchMode:
      typeof response.webSearchMode === "string"
        ? response.webSearchMode
        : undefined,
  };
}

function normalizeSandboxModeFromRpc(value: unknown): string | undefined {
  switch (value) {
    case "dangerFullAccess":
      return "danger-full-access";
    case "workspaceWrite":
      return "workspace-write";
    case "readOnly":
      return "read-only";
    default:
      return typeof value === "string" && value.length > 0 ? value : undefined;
  }
}

function normalizeItemType(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.replace(/[_\s-]/g, "").toLowerCase();
}

function numberOrUndefined(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
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

function toToolUseInput(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  if (Array.isArray(value)) {
    return { items: value };
  }
  if (value === undefined || value === null) {
    return {};
  }
  return { value };
}

function formatDynamicToolResult(item: Record<string, unknown>): string {
  const status = typeof item.status === "string" ? item.status : "completed";
  const success = typeof item.success === "boolean" ? item.success : null;
  const contentItems = Array.isArray(item.contentItems)
    ? item.contentItems
    : null;
  const parts = [
    `status: ${status}`,
    ...(success != null ? [`success: ${success}`] : []),
  ];

  if (contentItems && contentItems.length > 0) {
    for (const entry of contentItems) {
      if (!entry || typeof entry !== "object") continue;
      const record = entry as Record<string, unknown>;
      const type = typeof record.type === "string" ? record.type : "item";
      if (type === "inputText" && typeof record.text === "string") {
        parts.push(record.text);
        continue;
      }
      if (type === "inputImage" && typeof record.imageUrl === "string") {
        parts.push(`image: ${record.imageUrl}`);
        continue;
      }
      parts.push(JSON.stringify(record));
    }
  }

  return parts.join("\n");
}

function normalizeMcpToolResult(result: unknown): {
  content: string;
  rawContentBlocks: Array<Record<string, unknown>>;
} {
  if (typeof result === "string") {
    return { content: result, rawContentBlocks: [] };
  }

  const record =
    result && typeof result === "object" && !Array.isArray(result)
      ? (result as Record<string, unknown>)
      : null;
  const contentItems = Array.isArray(record?.content) ? record.content : null;
  if (!contentItems) {
    return {
      content: result == null ? "MCP call completed" : JSON.stringify(result),
      rawContentBlocks: [],
    };
  }

  const textParts: string[] = [];
  const rawContentBlocks: Array<Record<string, unknown>> = [];

  for (const entry of contentItems) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    const type = typeof item.type === "string" ? item.type : "";

    if (type === "text" && typeof item.text === "string") {
      textParts.push(item.text);
      rawContentBlocks.push({ type: "text", text: item.text });
      continue;
    }

    if (type === "image" && typeof item.data === "string") {
      const mimeType =
        typeof item.mimeType === "string"
          ? item.mimeType
          : typeof item.mediaType === "string"
            ? item.mediaType
            : typeof item.media_type === "string"
              ? item.media_type
              : "image/png";
      rawContentBlocks.push({
        type: "image",
        source: {
          type: "base64",
          data: item.data,
          media_type: mimeType,
        },
      });
      continue;
    }

    rawContentBlocks.push(item);
    textParts.push(JSON.stringify(item));
  }

  const content = textParts.join("\n").trim();
  if (content.length > 0) {
    return { content, rawContentBlocks };
  }

  const imageCount = rawContentBlocks.filter(
    (entry) => entry.type === "image",
  ).length;
  if (imageCount > 0) {
    return {
      content:
        imageCount === 1
          ? "Generated 1 image"
          : `Generated ${imageCount} images`,
      rawContentBlocks,
    };
  }

  return {
    content: result == null ? "MCP call completed" : JSON.stringify(result),
    rawContentBlocks,
  };
}

function toCodexThreadSummary(entry: unknown): CodexThreadSummary {
  const record =
    entry && typeof entry === "object"
      ? (entry as Record<string, unknown>)
      : {};
  const gitInfo =
    record.gitInfo && typeof record.gitInfo === "object"
      ? (record.gitInfo as Record<string, unknown>)
      : {};
  return {
    id: typeof record.id === "string" ? record.id : "",
    preview: typeof record.preview === "string" ? record.preview : "",
    createdAt: numberOrUndefined(record.createdAt) ?? 0,
    updatedAt: numberOrUndefined(record.updatedAt) ?? 0,
    cwd: typeof record.cwd === "string" ? record.cwd : "",
    agentNickname: stringOrNull(record.agentNickname),
    agentRole: stringOrNull(record.agentRole),
    gitBranch: stringOrNull(gitInfo.branch),
    name: stringOrNull(record.name),
  };
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
    .filter(
      (entry): entry is Record<string, unknown> =>
        !!entry && typeof entry === "object",
    )
    .map((entry, index) => {
      const id =
        typeof entry.id === "string" ? entry.id : `question_${index + 1}`;
      const question = typeof entry.question === "string" ? entry.question : "";
      const header =
        typeof entry.header === "string"
          ? entry.header
          : `Question ${index + 1}`;
      const optionsRaw = Array.isArray(entry.options) ? entry.options : [];
      const options = optionsRaw
        .filter(
          (option): option is Record<string, unknown> =>
            !!option && typeof option === "object",
        )
        .map((option) => ({
          label: typeof option.label === "string" ? option.label : "",
          description:
            typeof option.description === "string" ? option.description : "",
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
    const candidate =
      parsed.byId[question.id] ?? parsed.byQuestion[question.question];
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
        for (const [key, value] of Object.entries(
          answers as Record<string, unknown>,
        )) {
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

function buildElicitationResponse(
  pending: PendingUserInputRequest,
  rawResult: string,
): Record<string, unknown> {
  if (pending.kind === "elicitation_url") {
    const action = parseElicitationAction(rawResult);
    return {
      action,
      content: null,
      _meta: null,
    };
  }

  const parsed = parseResultObject(rawResult);
  const content: Record<string, unknown> = {};

  for (const question of pending.questions) {
    const candidate =
      parsed.byId[question.id] ?? parsed.byQuestion[question.question];
    const answers = normalizeAnswerValues(candidate);
    if (answers.length === 1) {
      content[question.id] = answers[0];
    } else if (answers.length > 1) {
      content[question.id] = answers;
    }
  }

  if (Object.keys(content).length === 0 && pending.questions.length === 1) {
    const answers = normalizeAnswerValues(rawResult);
    if (answers.length === 1) {
      content[pending.questions[0].id] = answers[0];
    } else if (answers.length > 1) {
      content[pending.questions[0].id] = answers;
    }
  }

  return {
    action: "accept",
    content: Object.keys(content).length > 0 ? content : null,
    _meta: null,
  };
}

function parseElicitationAction(
  rawResult: string,
): "accept" | "decline" | "cancel" {
  const normalized = rawResult.trim().toLowerCase();
  if (normalized.includes("cancel")) return "cancel";
  if (normalized.includes("decline") || normalized.includes("deny"))
    return "decline";

  try {
    const parsed = JSON.parse(rawResult) as Record<string, unknown>;
    const answers = parsed.answers;
    if (answers && typeof answers === "object" && !Array.isArray(answers)) {
      const first = Object.values(answers as Record<string, unknown>)[0];
      const answer = normalizeAnswerValues(first).join(" ").toLowerCase();
      if (answer.includes("cancel")) return "cancel";
      if (answer.includes("decline") || answer.includes("deny"))
        return "decline";
    }
  } catch {
    // Fall through to accept.
  }

  return "accept";
}

function createElicitationInput(params: Record<string, unknown>): {
  input: Record<string, unknown>;
  questions: PendingUserInputQuestion[];
  kind: PendingUserInputRequest["kind"];
} {
  const serverName =
    typeof params.serverName === "string" ? params.serverName : "MCP";
  const message =
    typeof params.message === "string" ? params.message : "Provide input";

  if (params.mode === "url") {
    const url = typeof params.url === "string" ? params.url : "";
    const question = url ? `${message}\n${url}` : message;
    return {
      kind: "elicitation_url",
      questions: [{ id: "elicitation_action", question }],
      input: {
        mode: "url",
        serverName,
        url,
        message,
        questions: [
          {
            id: "elicitation_action",
            header: serverName,
            question,
            options: [
              { label: "Accept", description: "Continue with this request" },
              { label: "Decline", description: "Reject this request" },
              { label: "Cancel", description: "Cancel without accepting" },
            ],
            multiSelect: false,
            isOther: false,
            isSecret: false,
          },
        ],
      },
    };
  }

  const schema = asRecord(params.requestedSchema);
  const properties = asRecord(schema?.properties) ?? {};
  const requiredFields = new Set(
    Array.isArray(schema?.required)
      ? schema!.required!.map((entry) => String(entry))
      : [],
  );

  const questions = Object.entries(properties)
    .filter(([, value]) => value && typeof value === "object")
    .map(([key, value]) => {
      const field = value as Record<string, unknown>;
      const title = typeof field.title === "string" ? field.title : key;
      const description =
        typeof field.description === "string" ? field.description : message;
      const enumValues = Array.isArray(field.enum)
        ? field.enum.map((entry) => String(entry))
        : [];
      const type = typeof field.type === "string" ? field.type : "";
      const options =
        enumValues.length > 0
          ? enumValues.map((entry, index) => ({
              label: entry,
              description: index === 0 ? description : "",
            }))
          : type === "boolean"
            ? [
                { label: "true", description: description },
                { label: "false", description: "" },
              ]
            : [];

      return {
        id: key,
        question: requiredFields.has(key) ? `${title} (required)` : title,
        header: serverName,
        options,
        isOther: options.length === 0,
        isSecret: false,
      };
    });

  const normalizedQuestions =
    questions.length > 0
      ? questions
      : [
          {
            id: "value",
            question: message,
            header: serverName,
            options: [] as Array<{ label: string; description: string }>,
            isOther: true,
            isSecret: false,
          },
        ];

  return {
    kind: "elicitation_form",
    questions: normalizedQuestions.map((question) => ({
      id: question.id,
      question: question.question,
    })),
    input: {
      mode: "form",
      serverName,
      message,
      requestedSchema: schema,
      questions: normalizedQuestions.map((question) => ({
        id: question.id,
        header: question.header,
        question: question.question,
        options: question.options,
        multiSelect: false,
        isOther: question.isOther,
        isSecret: question.isSecret,
      })),
    },
  };
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function formatPlanUpdateText(params: Record<string, unknown>): string {
  const stepsRaw = params.plan;
  if (!Array.isArray(stepsRaw) || stepsRaw.length === 0) return "";

  const explanation =
    typeof params.explanation === "string" ? params.explanation.trim() : "";
  const lines = stepsRaw
    .filter(
      (entry): entry is Record<string, unknown> =>
        !!entry && typeof entry === "object",
    )
    .map((entry, index) => {
      const step =
        typeof entry.step === "string" ? entry.step : `Step ${index + 1}`;
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

/** Find an available TCP port by binding to :0 and reading the assigned port. */
function findFreePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = createServer();
    srv.listen(0, "127.0.0.1", () => {
      const addr = srv.address();
      if (addr && typeof addr === "object") {
        const port = addr.port;
        srv.close(() => resolve(port));
      } else {
        srv.close(() => reject(new Error("Failed to get port from server")));
      }
    });
    srv.on("error", reject);
  });
}
