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

  const OMITTED = "[Large tool detail omitted from Bridge history]";
  const TRUNCATED = "\n[Truncated in Bridge history]";
  const ITEM_LIMIT = 256 * 1024;
  const STRING_LIMIT = 16 * 1024;

  /** Compacts a tool item that is forced over the item limit by `pad`. */
  function compactOversized(fields: Record<string, unknown>, type = "commandExecution") {
    const item = { type, ...fields, pad: "p".repeat(300_000) };
    const compacted = compactCodexHistoryItem(item);
    expect(compacted.item).not.toBe(item);
    expect(compacted.chars).toBe(JSON.stringify(compacted.item).length);
    return compacted.item;
  }

  it("reports the serialized size of items it leaves alone", () => {
    const item = { type: "commandExecution", command: "pwd" };
    expect(compactCodexHistoryItem(item).chars).toBe(JSON.stringify(item).length);
  });

  it("compacts only tool items larger than the item limit", () => {
    const sized = (chars: number) => {
      const base = { type: "commandExecution", aggregatedOutput: "" };
      const fill = chars - JSON.stringify(base).length;
      return { ...base, aggregatedOutput: "x".repeat(fill) };
    };
    const atLimit = sized(ITEM_LIMIT);
    expect(compactCodexHistoryItem(atLimit)).toEqual({ item: atLimit, chars: ITEM_LIMIT });
    expect(compactCodexHistoryItem(atLimit).item).toBe(atLimit);

    const overLimit = sized(ITEM_LIMIT + 1);
    const compacted = compactCodexHistoryItem(overLimit);
    expect(compacted.item).toEqual({
      type: "commandExecution",
      aggregatedOutput: "x".repeat(STRING_LIMIT) + TRUNCATED,
    });
    expect(compacted.chars).toBe(JSON.stringify(compacted.item).length);
  });

  it.each([
    "commandExecution", "fileChange", "mcpToolCall", "dynamicToolCall",
    "functionCallOutput", "imageGeneration",
  ])("compacts oversized %s items", (type) => {
    const compacted = compactOversized({ id: "tool" }, type);
    expect(compacted).toMatchObject({ type, id: "tool", pad: "p".repeat(STRING_LIMIT) + TRUNCATED });
  });

  it("drops the base64 result of a large generated image and notes it in the prompt", () => {
    const item = {
      type: "imageGeneration", id: "img", revisedPrompt: "a cat",
      result: "A".repeat(300_000),
    };
    expect(compactCodexHistoryItem(item).item).toEqual({
      type: "imageGeneration", id: "img", revisedPrompt: `a cat\n${OMITTED}`,
    });
    expect(item.result).toHaveLength(300_000);

    const withoutPrompt = compactCodexHistoryItem({
      type: "imageGeneration", id: "img", result: "A".repeat(300_000),
    }).item;
    expect(withoutPrompt).toEqual({
      type: "imageGeneration", id: "img", revisedPrompt: `\n${OMITTED}`,
    });
  });

  it("keeps the result of other oversized tools", () => {
    const compacted = compactOversized({ result: "done" }, "mcpToolCall");
    expect(compacted.result).toBe("done");
    expect(compacted).not.toHaveProperty("revisedPrompt");
  });

  it("truncates only strings longer than the string limit", () => {
    const compacted = compactOversized({
      exact: "x".repeat(STRING_LIMIT),
      over: "y".repeat(STRING_LIMIT + 1),
    });
    expect(compacted.exact).toBe("x".repeat(STRING_LIMIT));
    expect(compacted.over).toBe("y".repeat(STRING_LIMIT) + TRUNCATED);
  });

  it("omits long data URLs instead of truncating them", () => {
    const compacted = compactOversized({
      url: "data:image/png;base64," + "A".repeat(STRING_LIMIT),
      shortUrl: "data:image/png;base64,AAAA",
      mention: "z".repeat(STRING_LIMIT) + "data:image/",
    });
    expect(compacted.url).toBe(OMITTED);
    expect(compacted.shortUrl).toBe("data:image/png;base64,AAAA");
    expect(compacted.mention).toBe("z".repeat(STRING_LIMIT) + TRUNCATED);
  });

  it("preserves non-string values", () => {
    const compacted = compactOversized({
      exitCode: 0, durationMs: 12.5, ok: true, failed: false, nothing: null,
      list: [1, null, "a"], empty: {},
    });
    expect(compacted).toMatchObject({
      exitCode: 0, durationMs: 12.5, ok: true, failed: false, nothing: null,
      list: [1, null, "a"], empty: {},
    });
  });

  it("replaces only large image blocks with a text note", () => {
    const large = "A".repeat(STRING_LIMIT + 1);
    const compacted = compactOversized({
      content: [
        { type: "image", mimeType: "image/png", data: large },
        { type: "image", mimeType: "image/png", data: "A".repeat(STRING_LIMIT) },
        { type: "resource", data: large },
        { type: "image", url: "https://example.com/a.png" },
        { type: "image", data: 42 },
      ],
    });
    expect(compacted.content).toEqual([
      { type: "text", text: OMITTED },
      { type: "image", mimeType: "image/png", data: "A".repeat(STRING_LIMIT) },
      { type: "resource", data: "A".repeat(STRING_LIMIT) + TRUNCATED },
      { type: "image", url: "https://example.com/a.png" },
      { type: "image", data: 42 },
    ]);
  });

  it("replaces only large input images with a text note", () => {
    const large = "https://example.com/" + "a".repeat(STRING_LIMIT);
    const exact = "h".repeat(STRING_LIMIT);
    const compacted = compactOversized({
      contentItems: [
        { type: "inputImage", imageUrl: large },
        { type: "inputImage", imageUrl: exact },
        { type: "link", imageUrl: large },
        { type: "inputImage" },
        { type: "inputImage", imageUrl: null },
      ],
    }, "dynamicToolCall");
    expect(compacted.contentItems).toEqual([
      { type: "inputText", text: OMITTED },
      { type: "inputImage", imageUrl: exact },
      { type: "link", imageUrl: large.slice(0, STRING_LIMIT) + TRUNCATED },
      { type: "inputImage" },
      { type: "inputImage", imageUrl: null },
    ]);
  });

  it("omits objects and arrays nested 20 levels deep but keeps shallower ones", () => {
    const nestObjects = (levels: number, leaf: unknown) => {
      let value = leaf;
      for (let i = 0; i < levels; i++) value = { n: value };
      return value;
    };
    const nestArrays = (levels: number, leaf: unknown) => {
      let value = leaf;
      for (let i = 0; i < levels; i++) value = [value];
      return value;
    };
    // The item is depth 0, so a field value sits at depth 1.
    const compacted = compactOversized({
      kept: nestObjects(18, { leaf: 1 }),
      omitted: nestObjects(19, { leaf: 1 }),
      keptList: nestArrays(18, [1]),
      omittedList: nestArrays(19, [1]),
      deepString: nestObjects(19, "text"),
    });
    expect(compacted.kept).toEqual(nestObjects(18, { leaf: 1 }));
    expect(compacted.omitted).toEqual(nestObjects(19, OMITTED));
    expect(compacted.keptList).toEqual(nestArrays(18, [1]));
    expect(compacted.omittedList).toEqual(nestArrays(19, OMITTED));
    expect(compacted.deepString).toEqual(nestObjects(19, "text"));
  });
});
