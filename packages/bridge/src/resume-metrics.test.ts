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

  it.each([
    ["", 0],
    ["QQ==", 1],
    ["QUI=", 2],
    ["QUJD", 3],
    ["QUJDRA==", 4],
  ])("estimates the decoded size of %j as %i bytes", (data, bytes) => {
    const metrics = summarizeResumeHistory([
      { role: "user", content: "", imageBase64: [{ data, mimeType: "image/png" }] },
    ]);
    expect(metrics.inlineImageBytes).toBe(bytes);
  });

  it.each([
    [NaN, 1],
    [Infinity, 1],
    [-3, 1],
    [2.9, 2],
    [0, 1],
  ])("uses an image count hint of %s only when it is a larger whole number", (imageCount, expected) => {
    const metrics = summarizeResumeHistory([
      { role: "user", content: "", imageCount, imagePaths: ["/tmp/one.png"] },
    ]);
    expect(metrics.imageCount).toBe(expected);
  });

  it("returns zeroes for an empty history", () => {
    expect(summarizeResumeHistory([])).toEqual({
      messageCount: 0,
      imageCount: 0,
      inlineImageCount: 0,
      imagePathCount: 0,
      inlineImageBytes: 0,
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
