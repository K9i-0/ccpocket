import type { BackgroundTaskInfo } from "./parser.js";

/**
 * Tracks Codex work that outlives the turn that started it.
 *
 * Codex app-server has no background-task signal: a thread goes idle when its
 * turn completes even while a unified-exec terminal keeps running or a child
 * agent thread is still working. Like the Codex TUI, this derives the set from
 * item and child-thread notifications. Work started by the turn in progress is
 * foreground and is left out until that turn ends.
 */
interface TrackedTerminal {
  turnId: string | null;
  command: string;
}

interface TrackedChildAgent {
  turnId: string | null;
  active: boolean;
  nickname?: string;
  role?: string;
}

const MAX_DESCRIPTION_LENGTH = 200;

export class CodexBackgroundTracker {
  private readonly terminals = new Map<string, TrackedTerminal>();
  private readonly children = new Map<string, TrackedChildAgent>();
  private activeTurnId: string | null = null;

  constructor(private readonly ownThreadId: () => string | null) {}

  /**
   * Observe a notification. Returns true when it belongs to a child agent
   * thread: the caller must not treat it as its own thread's activity.
   */
  observe(method: string, params: Record<string, unknown>): boolean {
    const ownThreadId = this.ownThreadId();
    if (!ownThreadId) return false;

    if (method === "thread/started") {
      const thread = asRecord(params.thread);
      const id = stringValue(thread?.id);
      if (!id || id === ownThreadId) return false;
      if (stringValue(thread?.parentThreadId) !== ownThreadId) {
        return this.children.has(id);
      }
      this.children.set(id, {
        turnId: this.activeTurnId,
        active: true,
        ...optionalString("nickname", thread?.agentNickname),
        ...optionalString("role", thread?.agentRole),
      });
      return true;
    }

    const threadId = notificationThreadId(params);
    if (threadId && threadId !== ownThreadId) {
      const child = this.children.get(threadId);
      if (!child) return false;
      this.observeChild(threadId, child, method, params);
      return true;
    }

    switch (method) {
      case "turn/started":
        this.activeTurnId = stringValue(asRecord(params.turn)?.id) ?? "";
        break;
      case "turn/completed":
        this.activeTurnId = null;
        break;
      case "item/started": {
        const item = asRecord(params.item);
        if (!isCommandExecution(item)) break;
        const itemId = stringValue(item?.id);
        if (!itemId) break;
        if (normalize(item?.source) !== "unifiedexecstartup") break;
        if (!stringValue(item?.processId)) break;
        this.terminals.set(itemId, {
          turnId: stringValue(params.turnId) ?? this.activeTurnId,
          command: stringValue(item?.command) ?? "",
        });
        break;
      }
      case "item/completed": {
        const item = asRecord(params.item);
        if (!isCommandExecution(item)) break;
        const itemId = stringValue(item?.id);
        if (itemId) this.terminals.delete(itemId);
        break;
      }
    }
    return false;
  }

  /** Live work that does not belong to the turn in progress. */
  tasks(): BackgroundTaskInfo[] {
    const tasks: BackgroundTaskInfo[] = [];
    for (const [itemId, terminal] of this.terminals) {
      if (this.isCurrentTurn(terminal.turnId)) continue;
      tasks.push({
        taskId: itemId,
        taskType: "codex_terminal",
        ...(terminal.command
          ? { description: truncate(terminal.command) }
          : {}),
      });
    }
    for (const [threadId, child] of this.children) {
      if (!child.active || this.isCurrentTurn(child.turnId)) continue;
      const label = child.nickname ?? child.role;
      tasks.push({
        taskId: threadId,
        taskType: "codex_agent",
        ...(label ? { description: truncate(label) } : {}),
        ...(child.role ? { subagentType: child.role } : {}),
      });
    }
    return tasks;
  }

  reset(): void {
    this.terminals.clear();
    this.children.clear();
    this.activeTurnId = null;
  }

  private isCurrentTurn(turnId: string | null): boolean {
    return this.activeTurnId !== null && turnId === this.activeTurnId;
  }

  private observeChild(
    threadId: string,
    child: TrackedChildAgent,
    method: string,
    params: Record<string, unknown>,
  ): void {
    switch (method) {
      case "thread/status/changed": {
        const status = normalize(asRecord(params.status)?.type);
        child.active = status === "active";
        break;
      }
      case "turn/started":
        child.active = true;
        break;
      case "turn/completed":
        child.active = false;
        break;
      case "thread/closed":
        this.children.delete(threadId);
        break;
    }
  }
}

function isCommandExecution(item: Record<string, unknown> | undefined): boolean {
  return normalize(item?.type) === "commandexecution";
}

function notificationThreadId(params: Record<string, unknown>): string | null {
  const direct = stringValue(params.threadId);
  if (direct) return direct;
  const thread = stringValue(asRecord(params.thread)?.id);
  if (thread) return thread;
  return stringValue(asRecord(params.turn)?.threadId);
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function optionalString<K extends string>(
  key: K,
  value: unknown,
): Partial<Record<K, string>> {
  const text = stringValue(value);
  return text ? ({ [key]: text } as Record<K, string>) : {};
}

function normalize(value: unknown): string {
  return typeof value === "string"
    ? value.replace(/[_\s-]/g, "").toLowerCase()
    : "";
}

function truncate(text: string): string {
  return text.length > MAX_DESCRIPTION_LENGTH
    ? `${text.slice(0, MAX_DESCRIPTION_LENGTH - 1)}…`
    : text;
}
