import { describe, expect, it } from "vitest";
import { textPreview } from "./text-preview.js";

describe("textPreview", () => {
  it("preserves the existing split/slice semantics including trailing empty lines", () => {
    for (const raw of ["", "one", "one\n", "\n\n", "a\r\nb\r\nc", "日本語\n😀\nlast"]) {
      for (const maxLines of [0.5, 1, 1.5, 2, 3, 5000]) {
        const lines = raw.split("\n");
        const truncated = lines.length > maxLines;
        expect(textPreview(raw, maxLines)).toEqual({
          content: truncated ? lines.slice(0, maxLines).join("\n") : raw,
          totalLines: lines.length,
          truncated,
        });
      }
    }
  });

  it("counts all omitted lines while returning only the requested prefix", () => {
    const raw = "日本語\n".repeat(100_000);
    expect(textPreview(raw, 5000)).toEqual({
      content: "日本語\n".repeat(4999) + "日本語",
      totalLines: 100_001,
      truncated: true,
    });
  });
});
