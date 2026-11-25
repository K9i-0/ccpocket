type Message = Record<string, unknown>;

export type PerformanceFilter = {
  tasks: boolean;
  thinking: boolean;
  subagents: boolean;
  codeEdits: boolean;
  otherTools: boolean;
  toolResults: boolean;
};

export const ALL_PERFORMANCE_FILTER: PerformanceFilter = {
  tasks: true,
  thinking: true,
  subagents: true,
  codeEdits: true,
  otherTools: true,
  toolResults: true,
};

export const RECOMMENDED_PERFORMANCE_FILTER: PerformanceFilter = {
  tasks: true,
  thinking: true,
  subagents: true,
  codeEdits: false,
  otherTools: false,
  toolResults: false,
};

/**
 * Legacy v1 behavior used when an older client sends only `performanceMode: true`
 * without a `performanceFilter`. Preserves thinking and Swarm conversation while
 * hiding other tools, summaries, and tool results.
 */
export const LEGACY_V1_PERFORMANCE_FILTER: PerformanceFilter = {
  tasks: false,
  thinking: true,
  subagents: false,
  codeEdits: false,
  otherTools: false,
  toolResults: false,
};

const TASK_TOOLS = new Set([
  "TodoWrite",
  "UpdatePlan",
  "TaskCreate",
  "TaskUpdate",
]);

const SUBAGENT_TOOLS = new Set([
  "Task",
  "Agent",
  "SubAgent",
  "invoke_subagent",
]);

const CODE_EDIT_TOOLS = new Set([
  "Edit",
  "Write",
  "MultiEdit",
  "NotebookEdit",
  "FileChange",
  "FileEdit",
  "apply_patch",
]);

const record = (value: unknown): value is Message =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const hasImages = (msg: Message): boolean =>
  Array.isArray(msg.images) && msg.images.length > 0;

export function isPerformanceFilterActive(filter: PerformanceFilter): boolean {
  return (
    !filter.tasks ||
    !filter.thinking ||
    !filter.subagents ||
    !filter.codeEdits ||
    !filter.otherTools ||
    !filter.toolResults
  );
}

export function isPerformanceFilter(value: unknown): value is PerformanceFilter {
  if (!record(value)) return false;
  return (
    typeof value.tasks === "boolean" &&
    typeof value.thinking === "boolean" &&
    typeof value.subagents === "boolean" &&
    typeof value.codeEdits === "boolean" &&
    typeof value.otherTools === "boolean" &&
    typeof value.toolResults === "boolean"
  );
}

/**
 * An Antigravity swarm's conversation: board posts, and the brief a worker is
 * given when it is added (the board's copy of a brief is never sent, so the
 * `swarm add` call is the only place a client reads it).
 */
const isSwarmConversation = (part: Message): boolean =>
  part.name === "SwarmPost" ||
  (part.name === "swarm" && record(part.input) && part.input.action === "add");

const isPlanWrite = (part: Message): boolean =>
  part.name === "Write" &&
  record(part.input) &&
  typeof part.input.file_path === "string" &&
  part.input.file_path.replaceAll("\\", "/").includes("/.claude/plans/");

const isEssentialTool = (part: Message): boolean =>
  part.name === "ExitPlanMode" ||
  part.name === "AskUserQuestion" ||
  part.name === "ImageGeneration" ||
  isPlanWrite(part);

function shouldKeepToolUse(
  part: Message,
  filter: PerformanceFilter,
  legacyV1: boolean,
): boolean {
  if (isEssentialTool(part)) return true;
  const name = typeof part.name === "string" ? part.name : "";
  if (isSwarmConversation(part)) {
    // Legacy v1 always kept Swarm posts and briefs; v2 controls them via `subagents`.
    return legacyV1 ? true : filter.subagents;
  }
  if (TASK_TOOLS.has(name)) return filter.tasks;
  if (SUBAGENT_TOOLS.has(name)) return filter.subagents;
  if (CODE_EDIT_TOOLS.has(name)) return filter.codeEdits;
  return filter.otherTools;
}

/** Delivery projection only: never mutate the agent's canonical history. */
export function performanceMessage(
  msg: Message,
  filter?: PerformanceFilter,
): Message | null {
  const legacyV1 = filter === undefined;
  const effective = filter ?? LEGACY_V1_PERFORMANCE_FILTER;
  if (!isPerformanceFilterActive(effective)) return msg;

  if (msg.type === "thinking_delta") {
    return effective.thinking ? msg : null;
  }
  if (msg.type === "tool_use_summary") {
    return effective.subagents ? msg : null;
  }
  if (msg.type === "tool_result" || msg.role === "tool_result") {
    if (msg.toolName === "ImageGeneration") {
      const { rawContentBlocks: _raw, ...result } = msg;
      return result;
    }
    if (effective.toolResults) {
      return msg;
    }
    const isQuestionAnswer = msg.permissionOutcome === "answered";
    // Preserve question answers so the transcript can be restored after reconnect.
    return {
      ...(msg.role === "tool_result" ? { role: msg.role } : { type: msg.type }),
      toolUseId: msg.toolUseId,
      // Lets a client tell a board post's result, which it never shows, from other results.
      ...(msg.toolName === "SwarmPost" ? { toolName: msg.toolName } : {}),
      content: isQuestionAnswer && typeof msg.content === "string" ? msg.content : "",
      ...(msg.userMessageUuid != null ? { userMessageUuid: msg.userMessageUuid } : {}),
      ...(msg.permissionOutcome != null ? { permissionOutcome: msg.permissionOutcome } : {}),
      ...(msg.sessionId != null ? { sessionId: msg.sessionId } : {}),
      ...(msg.historySeq != null ? { historySeq: msg.historySeq } : {}),
    };
  }
  if (msg.type === "assistant" && record(msg.message)) {
    const message = performanceMessage({ ...msg.message, role: "assistant" }, filter);
    if (message) return { ...msg, message };
    return hasImages(msg)
      ? { ...msg, message: { ...msg.message, content: [] } }
      : null;
  }
  if (msg.role === "assistant" && Array.isArray(msg.content)) {
    const content = msg.content.filter((part) => {
      if (!record(part)) return false;
      if (part.type === "text") return typeof part.text === "string" && part.text.trim() !== "";
      if (part.type === "thinking") {
        return effective.thinking && typeof part.thinking === "string" && part.thinking.trim() !== "";
      }
      if (part.type !== "tool_use") return false;
      return shouldKeepToolUse(part, effective, legacyV1);
    });
    return content.length || hasImages(msg) ? { ...msg, content } : null;
  }
  if ((msg.type === "history" || msg.type === "past_history") && Array.isArray(msg.messages)) {
    return {
      ...msg,
      messages: msg.messages.flatMap((item) => {
        const projected = record(item) ? performanceMessage(item, filter) : null;
        return projected ? [projected] : [];
      }),
    };
  }
  if ((msg.type === "history_delta" || msg.type === "history_snapshot") && Array.isArray(msg.messages)) {
    return {
      ...msg,
      filtered: true,
      messages: msg.messages.flatMap((entry) => {
        if (!record(entry) || !record(entry.message)) return [];
        const message = performanceMessage(entry.message, filter);
        return message ? [{ ...entry, message }] : [];
      }),
    };
  }
  return msg;
}
