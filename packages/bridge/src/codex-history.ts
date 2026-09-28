// These limits apply only to the Bridge's display copy, never to Codex's
// persisted history or the model's context.
const MAX_TOOL_ITEM_CHARS = 256 * 1024;
const MAX_TOOL_STRING_CHARS = 16 * 1024;
const OMITTED = "[Large tool detail omitted from Bridge history]";
const TRUNCATED = "\n[Truncated in Bridge history]";

const TOOL_TYPES = new Set([
  "commandExecution", "fileChange", "mcpToolCall", "dynamicToolCall",
  "functionCallOutput", "imageGeneration",
]);

/** Bound unusually large tool payloads before retaining all history pages. */
export function compactCodexHistoryItem(item: Record<string, unknown>): {
  item: Record<string, unknown>;
  chars: number;
} {
  const chars = JSON.stringify(item).length;
  if (!TOOL_TYPES.has(String(item.type)) || chars <= MAX_TOOL_ITEM_CHARS) {
    return { item, chars };
  }
  const compacted = compactValue(item, 0) as Record<string, unknown>;
  // Generated images use a bare base64 string. Never pass truncated base64 to
  // the image decoder; show an explicit text result instead.
  if (item.type === "imageGeneration") {
    delete compacted.result;
    compacted.revisedPrompt = `${compacted.revisedPrompt ?? ""}\n${OMITTED}`;
  }
  return { item: compacted, chars: JSON.stringify(compacted).length };
}

function compactValue(value: unknown, depth: number): unknown {
  if (typeof value === "string") {
    if (value.length <= MAX_TOOL_STRING_CHARS) return value;
    if (value.startsWith("data:image/")) return OMITTED;
    return value.slice(0, MAX_TOOL_STRING_CHARS) + TRUNCATED;
  }
  if (value == null || typeof value !== "object") return value;
  if (depth >= 20) return OMITTED;
  if (Array.isArray(value)) {
    return value.map((entry) => compactValue(entry, depth + 1));
  }
  const record = value as Record<string, unknown>;
  if (record.type === "image" && typeof record.data === "string"
      && record.data.length > MAX_TOOL_STRING_CHARS) {
    return { type: "text", text: OMITTED };
  }
  if (record.type === "inputImage" && typeof record.imageUrl === "string"
      && record.imageUrl.length > MAX_TOOL_STRING_CHARS) {
    return { type: "inputText", text: OMITTED };
  }
  return Object.fromEntries(Object.entries(record)
    .map(([key, entry]) => [key, compactValue(entry, depth + 1)]));
}
