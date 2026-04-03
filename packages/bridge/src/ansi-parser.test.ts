import { describe, it, expect } from "vitest";
import { AnsiParser } from "./ansi-parser.js";
import type { ServerMessage } from "./parser.js";

function collectMessages(
  parser: AnsiParser,
  chunks: string[],
): ServerMessage[] {
  const msgs: ServerMessage[] = [];
  parser.on("message", (msg) => msgs.push(msg));
  for (const chunk of chunks) {
    parser.feed(chunk);
  }
  parser.flush();
  return msgs;
}

describe("AnsiParser", () => {
  describe("ANSI stripping", () => {
    it("strips SGR color codes", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\x1b[1m\x1b[34m\u23FA\x1b[0m Hello world\r\n",
      ]);
      const textMsgs = msgs.filter((m) => m.type === "assistant");
      expect(textMsgs.length).toBeGreaterThan(0);
    });

    it("strips cursor movement codes", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\x1b[2K\x1b[1G\u23FA Test\r\n",
      ]);
      const textMsgs = msgs.filter((m) => m.type === "assistant");
      expect(textMsgs.length).toBeGreaterThan(0);
    });
  });

  describe("Claude profile — assistant text", () => {
    it("emits stream_delta for text after \u23FA marker", () => {
      const parser = new AnsiParser("claude");
      const msgs: ServerMessage[] = [];
      parser.on("message", (msg) => msgs.push(msg));

      parser.feed("\u23FA Hello ");
      parser.feed("world\r\n");
      parser.flush();

      const deltas = msgs.filter((m) => m.type === "stream_delta");
      expect(deltas.length).toBeGreaterThan(0);

      const assistant = msgs.filter((m) => m.type === "assistant");
      expect(assistant.length).toBe(1);
    });

    it("emits assistant message with full accumulated text on flush", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\u23FA Line one\r\n",
        "  Line two\r\n",
      ]);

      const assistant = msgs.find((m) => m.type === "assistant") as Extract<
        ServerMessage,
        { type: "assistant" }
      >;
      expect(assistant).toBeDefined();
      expect(assistant.message.content[0]).toMatchObject({
        type: "text",
        text: expect.stringContaining("Line one"),
      });
    });
  });

  describe("Claude profile — tool calls", () => {
    it("detects tool call header and emits assistant with tool_use", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\u23FA I'll read the file.\r\n",
        "\r\n",
        "\u23BF Read(src/index.ts)\r\n",
        "  1 | import foo from 'bar'\r\n",
        "  2 | console.log(foo)\r\n",
        "\r\n",
      ]);

      const assistants = msgs.filter((m) => m.type === "assistant");
      expect(assistants.length).toBeGreaterThanOrEqual(1);

      const toolResults = msgs.filter((m) => m.type === "tool_result");
      expect(toolResults.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe("Claude profile — permission prompts", () => {
    it("emits permission_request on Allow? pattern", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\u23BF Write(src/foo.ts)\r\n",
        "  new content here\r\n",
        "\r\n",
        "  Allow? ([y]es, [n]o, [a]lways)\r\n",
      ]);

      const perms = msgs.filter((m) => m.type === "permission_request");
      expect(perms.length).toBe(1);
    });
  });

  describe("Claude profile — cost/result", () => {
    it("emits result on Cost: line", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "\u23FA Done!\r\n",
        "\r\n",
        "Cost: $0.05 \u00B7 Duration: 12s\r\n",
      ]);

      const results = msgs.filter((m) => m.type === "result");
      expect(results.length).toBe(1);
      const result = results[0] as Extract<ServerMessage, { type: "result" }>;
      expect(result.cost).toBeCloseTo(0.05);
      expect(result.duration).toBe(12);
    });
  });

  describe("Claude profile — session ID capture", () => {
    it("emits system init with session ID", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "Session: abc-123-def\r\n",
        "\u23FA Hello\r\n",
      ]);

      const system = msgs.find(
        (m) => m.type === "system" && m.subtype === "init",
      ) as Extract<ServerMessage, { type: "system" }>;
      expect(system).toBeDefined();
      expect(system.sessionId).toBe("abc-123-def");
    });
  });

  describe("graceful degradation", () => {
    it("emits generic assistant text for unrecognized output", () => {
      const parser = new AnsiParser("claude");
      const msgs = collectMessages(parser, [
        "some random unrecognized output\r\n",
      ]);

      // Should still emit something — never silently swallow output
      expect(msgs.length).toBeGreaterThan(0);
    });
  });
});
