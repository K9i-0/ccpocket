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

  it("returns the same array when nothing is narration", () => {
    const content = [{ type: "text", text: "hi" }];
    expect(projectNarrationBlocks(content)).toBe(content);
  });
});
