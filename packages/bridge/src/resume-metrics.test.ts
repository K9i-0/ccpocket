import { describe, expect, it } from "vitest";
import {
  formatResumePerformanceLog,
  summarizeResumeHistory,
} from "./resume-metrics.js";

describe("summarizeResumeHistory", () => {
  it("counts inline, path, and hinted images without decoding base64", () => {
    const metrics = summarizeResumeHistory([
      {
        role: "user",
        content: "images",
        imageCount: 3,
        imageBase64: [
          {
            data: Buffer.from("inline image").toString("base64"),
            mimeType: "image/png",
          },
        ],
      },
      {
        role: "tool_result",
        content: "saved",
        imagePaths: ["/tmp/one.png", "/tmp/two.png"],
      },
    ]);

    expect(metrics).toEqual({
      messageCount: 2,
      imageCount: 5,
      inlineImageCount: 1,
      imagePathCount: 2,
      inlineImageBytes: 12,
    });
  });
});

describe("formatResumePerformanceLog", () => {
  it("formats a single searchable performance log line", () => {
    expect(
      formatResumePerformanceLog({
        provider: "codex",
        sourceSessionId: "thread-1",
        outcome: "success",
        messageCount: 42,
        imageCount: 4,
        inlineImageCount: 4,
        imagePathCount: 0,
        inlineImageBytes: 1024,
        historyLoadMs: 12.4,
        sessionCreateMs: 2.2,
        nameLoadMs: 1.5,
        totalMs: 17.9,
      }),
    ).toBe(
      "[ws][resume-perf] provider=codex sourceSessionId=thread-1 " +
        "outcome=success messages=42 images=4 inlineImages=4 imagePaths=0 " +
        "inlineImageBytes=1024 historyMs=12 createMs=2 nameMs=2 totalMs=18",
    );
  });
});
