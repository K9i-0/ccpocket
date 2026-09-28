import { describe, expect, it } from "vitest";
import { compactCodexHistoryItem } from "./codex-history.js";
import { codexThreadToSessionHistory } from "./sessions-index.js";

describe("compactCodexHistoryItem", () => {
  it("preserves normal tools and long conversation text", () => {
    for (const item of [
      { type: "commandExecution", command: "pwd", aggregatedOutput: "/repo" },
      { type: "agentMessage", text: "x".repeat(300_000) },
      { type: "userMessage", content: [{ type: "text", text: "x".repeat(300_000) }] },
    ]) {
      expect(compactCodexHistoryItem(item).item).toBe(item);
    }
  });

  it("bounds tool strings without mutating source history or losing identity", () => {
    const item = {
      type: "fileChange", id: "change", status: "completed",
      changes: [{ path: "asset.json", kind: { type: "update" }, diff: "x".repeat(300_000) }],
    };
    const compacted = compactCodexHistoryItem(item);
    expect(compacted.item).toMatchObject({ id: "change", status: "completed" });
    expect(compacted.chars).toBeLessThan(20_000);
    expect(JSON.stringify(compacted.item)).toContain("Truncated in Bridge history");
    expect(item.changes[0].diff).toHaveLength(300_000);
  });

  it("replaces large MCP images with readable notes instead of corrupt base64", () => {
    const item = {
      type: "mcpToolCall", id: "mcp", server: "test", tool: "screenshot",
      arguments: {}, result: { content: [{ type: "image", mimeType: "image/png", data: "A".repeat(300_000) }] },
    };
    const compacted = compactCodexHistoryItem(item).item;
    const messages = codexThreadToSessionHistory({ turns: [{ items: [compacted] }] });
    const result = messages.find((message) => message.role === "tool_result");
    expect(result?.content).toContain("Large tool detail omitted");
    expect(result?.imageBase64 ?? []).toEqual([]);
    expect(item.result.content[0].data).toHaveLength(300_000);
  });

  it("keeps dynamic image placeholders in the expected text content shape", () => {
    const compacted = compactCodexHistoryItem({
      type: "dynamicToolCall", tool: "screenshot", id: "dynamic", arguments: {},
      contentItems: [{ type: "inputImage", imageUrl: "data:image/png;base64," + "A".repeat(300_000) }],
    });
    expect(compacted.item.contentItems).toEqual([
      { type: "inputText", text: "[Large tool detail omitted from Bridge history]" },
    ]);
  });

  it("bounds deeply nested tool details without changing typed array shapes", () => {
    let value: unknown = "x".repeat(300_000);
    for (let i = 0; i < 25; i++) value = { nested: value };
    const compacted = compactCodexHistoryItem({
      type: "mcpToolCall", id: "deep", arguments: { value },
    });
    expect(compacted.chars).toBeLessThan(256 * 1024);
    expect(JSON.stringify(compacted.item)).toContain("omitted");
  });
});
