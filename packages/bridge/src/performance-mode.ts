type Message = Record<string, unknown>;
const record = (value: unknown): value is Message =>
  value !== null && typeof value === "object" && !Array.isArray(value);
const hasImages = (msg: Message): boolean =>
  Array.isArray(msg.images) && msg.images.length > 0;

/**
 * An Antigravity swarm's conversation: board posts, and the brief a worker is
 * given when it is added (the board's copy of a brief is never sent, so the
 * `swarm add` call is the only place a client reads it).
 */
const swarmConversation = (part: Message): boolean =>
  part.name === "SwarmPost" ||
  (part.name === "swarm" && record(part.input) && part.input.action === "add");

/** Delivery projection only: never mutate the agent's canonical history. */
export function performanceMessage(msg: Message): Message | null {
  if (msg.type === "tool_use_summary") return null;
  if (msg.type === "tool_result" || msg.role === "tool_result") {
    if (msg.toolName === "ImageGeneration") {
      const { rawContentBlocks: _raw, ...result } = msg;
      return result;
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
    const message = performanceMessage({ ...msg.message, role: "assistant" });
    if (message) return { ...msg, message };
    return hasImages(msg)
      ? { ...msg, message: { ...msg.message, content: [] } }
      : null;
  }
  if (msg.role === "assistant" && Array.isArray(msg.content)) {
    const content = msg.content.filter((part) => {
      if (!record(part)) return false;
      if (part.type === "text") return typeof part.text === "string" && part.text.trim() !== "";
      if (part.type === "thinking") return typeof part.thinking === "string" && part.thinking.trim() !== "";
      if (part.type !== "tool_use") return false;
      if (
        part.name === "ExitPlanMode" ||
        part.name === "AskUserQuestion" ||
        part.name === "ImageGeneration" ||
        swarmConversation(part)
      ) {
        return true;
      }
      // The mobile approval sheet derives plan text from these writes.
      return part.name === "Write" && record(part.input) &&
        typeof part.input.file_path === "string" &&
        part.input.file_path.replaceAll("\\", "/").includes("/.claude/plans/");
    });
    return content.length || hasImages(msg) ? { ...msg, content } : null;
  }
  if ((msg.type === "history" || msg.type === "past_history") && Array.isArray(msg.messages)) {
    return { ...msg, messages: msg.messages.flatMap((item) => {
      const projected = record(item) ? performanceMessage(item) : null;
      return projected ? [projected] : [];
    }) };
  }
  if ((msg.type === "history_delta" || msg.type === "history_snapshot") && Array.isArray(msg.messages)) {
    return { ...msg, filtered: true, messages: msg.messages.flatMap((entry) => {
      if (!record(entry) || !record(entry.message)) return [];
      const message = performanceMessage(entry.message);
      return message ? [{ ...entry, message }] : [];
    }) };
  }
  return msg;
}
