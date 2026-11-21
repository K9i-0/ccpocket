import { describe, expect, it } from "vitest";
import { isNarrationSignature, projectNarrationBlocks } from "./claude-narration.js";

// Signature headers captured from a real Claude Code transcript.
const NARRATION_SIGNATURE =
  "CAQSmAgKEQgTGAI4AUIJbmFycmF0aW9uEgwuh3SmO2yKTiIVkQgaDANmsfjWZPILaBgE9iIwjVeKmBQ2ZNJQ2OIyxdN4J/O9dCk/IR2n4/li8HiUvfHTLXUAPjTFQ3fdJO8BI45LKrQHsBSNHXk0B3V1fr8pFr4jxtyxUulhMQF0rZuzh15rayrZZZ42kr93hJn38D8J";
const THINKING_SIGNATURE =
  "CAQSpwYKEAgTGAI4AUIIdGhpbmtpbmcSDKet1CC8vZtTRUUgdxoMm2MUSgbLYGxHq4xMIjDGqRpzIxTmtTHZya+ee4JVkMyAxT7bVKZrY6zMKeVH4YCtO+v3a4XYxlVMd/pw0TwqxAXnCdxd78Tlv+dLMhFFisH2c+nE6BHSiAjK22fIZdjVvlA9KNxl5uwRxIlneo3j";

describe("isNarrationSignature", () => {
  it("detects the narration block kind", () => {
    expect(isNarrationSignature(NARRATION_SIGNATURE)).toBe(true);
  });

  it("rejects ordinary thinking and malformed values", () => {
    expect(isNarrationSignature(THINKING_SIGNATURE)).toBe(false);
    expect(isNarrationSignature("")).toBe(false);
    expect(isNarrationSignature(undefined)).toBe(false);
    expect(isNarrationSignature("not base64 !!")).toBe(false);
  });

  it("requires the block_kind field, not just the word narration", () => {
    const field = Buffer.concat([Buffer.from([0x42, 9]), Buffer.from("narration")]);
    const header = Buffer.from([0x08, 0x04, 0x12, 0x20]);
    expect(isNarrationSignature(Buffer.concat([header, field]).toString("base64"))).toBe(true);
    expect(
      isNarrationSignature(Buffer.concat([header, Buffer.from("xxnarrationxx")]).toString("base64")),
    ).toBe(false);
    // A different field tag or length prefix is another block kind.
    expect(
      isNarrationSignature(
        Buffer.concat([header, Buffer.from([0x3a, 9]), Buffer.from("narration")]).toString("base64"),
      ),
    ).toBe(false);
  });
});

describe("projectNarrationBlocks", () => {
  it("turns narration thinking into text and keeps real thinking", () => {
    const content = [
      { type: "thinking", thinking: "", signature: THINKING_SIGNATURE },
      { type: "thinking", thinking: "Checking the build first.\n\n", signature: NARRATION_SIGNATURE },
      { type: "thinking", thinking: "private reasoning", signature: THINKING_SIGNATURE },
      { type: "tool_use", id: "t1", name: "Bash", input: {} },
    ];
    expect(projectNarrationBlocks(content)).toEqual([
      content[0],
      { type: "text", text: "Checking the build first." },
      content[2],
      content[3],
    ]);
  });

  it("honours SDK narration_block_indexes without a signature", () => {
    const content = [{ type: "thinking", thinking: "Next I'll run tests." }];
    expect(projectNarrationBlocks(content, [0])).toEqual([
      { type: "text", text: "Next I'll run tests." },
    ]);
  });

  it("leaves non-thinking, malformed and empty blocks alone even at narration indexes", () => {
    const content = [
      null,
      "plain string",
      { type: "thinking" },
      { type: "redacted_thinking", thinking: "opaque" },
      { type: "thinking", thinking: "  \n", signature: NARRATION_SIGNATURE },
      { type: "text", text: "hi" },
    ];
    expect(projectNarrationBlocks(content, [0, 1, 2, 3, 4, 5])).toBe(content);
    expect(projectNarrationBlocks(content, "not-a-list")).toBe(content);
  });

  it("projects only the listed indexes when blocks carry no signature", () => {
    const content = [
      { type: "thinking", thinking: "reasoning" },
      { type: "thinking", thinking: "Running tests." },
    ];
    expect(projectNarrationBlocks(content, [1, "0", 0.5])).toEqual([
      content[0],
      { type: "text", text: "Running tests." },
    ]);
  });

  it("returns the same array when nothing is narration", () => {
    const content = [{ type: "text", text: "hi" }];
    expect(projectNarrationBlocks(content)).toBe(content);
  });
});
