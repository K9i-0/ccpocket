type Message = Record<string, unknown>;
const record = (value: unknown): value is Message =>
  value !== null && typeof value === "object" && !Array.isArray(value);

/** Delivery projection only: never mutate the agent's canonical history. */
export function performanceMessage(msg: Message): Message | null {
  if (msg.type === "thinking_delta" || msg.type === "tool_use_summary") return null;
  if (msg.type === "tool_result" || msg.role === "tool_result") {
    if (msg.toolName === "ImageGeneration") {
      const { rawContentBlocks: _raw, ...result } = msg;
      return result;
    }
    // Completion IDs resolve questions/approvals, including answers from other clients.
    const images = Array.isArray(msg.images) ? msg.images.flatMap((image) => {
      if (!record(image) || typeof image.id !== "string" ||
          image.id.length > 256 || typeof image.url !== "string" || image.url.length > 2048 || !image.url.startsWith("/images/") ||
          typeof image.mimeType !== "string" || image.mimeType.length > 128) return [];
      return [{ id: image.id, url: image.url, mimeType: image.mimeType,
        ...(typeof image.thumbnailUrl === "string" && image.thumbnailUrl.length <= 2048 && image.thumbnailUrl.startsWith("/images/")
          ? { thumbnailUrl: image.thumbnailUrl } : {}),
      }];
    }) : [];
    return {
      ...(msg.role === "tool_result" ? { role: msg.role } : { type: msg.type }),
      toolUseId: msg.toolUseId, content: "",
      ...(msg.userMessageUuid != null ? { userMessageUuid: msg.userMessageUuid } : {}),
      ...(msg.permissionOutcome != null ? { permissionOutcome: msg.permissionOutcome } : {}),
      ...(msg.sessionId != null ? { sessionId: msg.sessionId } : {}),
      ...(msg.historySeq != null ? { historySeq: msg.historySeq } : {}),
      ...(images.length ? { images } : {}),
      ...(Array.isArray(msg.mcpResourceLinks) && msg.mcpResourceLinks.length
        ? { mcpResourceLinks: msg.mcpResourceLinks }
        : {}),
      ...(Array.isArray(msg.galleryImages) && msg.galleryImages.length
        ? { galleryImages: msg.galleryImages }
        : {}),
    };
  }
  if (msg.type === "assistant" && record(msg.message)) {
    const message = performanceMessage({ ...msg.message, role: "assistant" });
    return message ? { ...msg, message } : null;
  }
  if (msg.role === "assistant" && Array.isArray(msg.content)) {
    const content = msg.content.filter((part) => {
      if (!record(part)) return false;
      if (part.type === "text") return typeof part.text === "string" && part.text.trim() !== "";
      if (part.type !== "tool_use") return false;
      if (part.name === "ExitPlanMode" || part.name === "AskUserQuestion") return true;
      // The mobile approval sheet derives plan text from these writes.
      return part.name === "Write" && record(part.input) &&
        typeof part.input.file_path === "string" &&
        part.input.file_path.replaceAll("\\", "/").includes("/.claude/plans/");
    });
    return content.length ? { ...msg, content } : null;
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
