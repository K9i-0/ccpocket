import { describe, expect, it } from "vitest";
import { performanceMessage } from "./performance-mode.js";
import { outputLinkCandidatesForMessage } from "./output-artifacts.js";

const image = { id: "review-screen", url: "/images/review-screen", mimeType: "image/png", thumbnailUrl: "/images/review-screen/thumbnail" };
const toolResult = {
  type: "tool_result", toolUseId: "review", toolName: "mcp:browser/screenshot",
  content: "Captured the review. [Release review](</workspace/reports/Release review.pdf>)\n" + "log output\n".repeat(100_000),
  images: [image], rawContentBlocks: [{ type: "image", source: { data: "large".repeat(100_000) } }],
};
const links = [{ href: "/workspace/reports/Release review.pdf", syntax: "markdown", label: "Release review" }];

describe("performance output artifacts", () => {
  it("keeps only image references and file destinations alongside the completion marker", () => {
    const projected = performanceMessage(toolResult)!;
    expect(projected).toEqual({ type: "tool_result", toolUseId: "review", content: "", images: [image], outputLinkCandidates: links });
    expect(Buffer.byteLength(JSON.stringify(projected))).toBeLessThan(1024);
    expect(projected.rawContentBlocks).toBeUndefined();
    expect(toolResult.content).toContain("log output");
    expect(toolResult.images).toEqual([image]);
  });

  it("retains the same artifact metadata in all restored-history envelopes", () => {
    const marker = { type: "tool_result", toolUseId: "review", content: "", images: [image], outputLinkCandidates: links };
    expect(performanceMessage({ type: "history", messages: [toolResult] })).toEqual({ type: "history", messages: [marker] });
    expect(performanceMessage({ type: "past_history", messages: [{ ...toolResult, type: undefined, role: "tool_result" }] })).toEqual({ type: "past_history", messages: [{ ...marker, type: undefined, role: "tool_result" }] });
    for (const type of ["history_snapshot", "history_delta"]) {
      expect(performanceMessage({ type, fromSeq: 7, toSeq: 7, messages: [{ seq: 7, message: toolResult }] })).toEqual({ type, fromSeq: 7, toSeq: 7, filtered: true, messages: [{ seq: 7, message: marker }] });
    }
  });

  it("retains explicit Markdown links while excluding incidental paths and code", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: [
      "Read `reports/summary.md` and README.md.",
      "[Source](lib/main.dart#L42)",
      "[External](https://example.org/report.pdf)",
      "`[Example](./sample.pdf)`",
      "```markdown\n[Example](./example.pdf)\n```",
    ].join("\n") })!;
    expect(projected.outputLinkCandidates).toEqual([
      { href: "lib/main.dart#L42", syntax: "markdown", label: "Source" },
    ]);
    expect(projected.content).toBe("");
  });

  it("does not promote plain file mentions to output link candidates", () => {
    const projected = performanceMessage({
      type: "tool_result",
      toolUseId: "report",
      content: "Command: cat README.md\nOutput: /workspace/reports/summary.md",
    })!;
    expect(projected.outputLinkCandidates).toBeUndefined();
  });

  it("omits oversized thumbnail destinations while retaining the original image reference", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "image", content: "", images: [{ ...image, thumbnailUrl: `/images/${"x".repeat(3000)}` }] })!;
    expect(projected.images).toEqual([{ id: image.id, url: image.url, mimeType: image.mimeType }]);
  });

  it("keeps bounded markdown labels while excluding code examples", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: [
      "    [Private code](./private.pdf)", "\t[Tab code](./tab.pdf)",
      "[Untrusted stdout label](./reports/review.pdf)",
    ].join("\n") })!;
    expect(projected.outputLinkCandidates).toEqual([{ href: "./reports/review.pdf", syntax: "markdown", label: "Untrusted stdout label" }]);
  });

  it("bounds and strips control characters from display labels", () => {
    const controlCharacter = performanceMessage({
      type: "tool_result",
      toolUseId: "control-character",
      content: "[A\t report](./reports/review.pdf)",
    })!;
    expect(controlCharacter.outputLinkCandidates).toEqual([
      {
        href: "./reports/review.pdf",
        syntax: "markdown",
        label: "A  report",
      },
    ]);

    const projected = performanceMessage({
      type: "tool_result",
      toolUseId: "report",
      content: `[${"x".repeat(300)}](./reports/review.pdf)`,
    })!;
    expect(projected.outputLinkCandidates).toEqual([
      {
        href: "./reports/review.pdf",
        syntax: "markdown",
        label: "x".repeat(256),
      },
    ]);
  });

  it("preserves links inside list items while excluding nested fenced and top-level indented code", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: [
      "- Documents:", "    [Review](./reports/review.pdf)",
      "    - More:", "        [Checklist](./reports/checklist.md)",
      "        ```markdown", "        [Code](./private.pdf)", "        ```",
      "", "Outside the list:", "    [Indented code](./example.pdf)",
    ].join("\n") })!;
    expect(projected.outputLinkCandidates).toEqual([
      { href: "./reports/review.pdf", syntax: "markdown", label: "Review" },
      { href: "./reports/checklist.md", syntax: "markdown", label: "Checklist" },
    ]);
  });

  it("bounds candidate count and metadata size without retaining oversized destinations", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: [
      `[Oversized](./${"x".repeat(300)}.pdf)`,
      ...Array.from({ length: 100 }, (_, index) => `[Report](./reports/${index}-${"x".repeat(220)}.pdf)`),
    ].join("\n") })!;
    const candidates = projected.outputLinkCandidates as Array<{ href: string }>;
    expect(candidates.length).toBeGreaterThan(0);
    expect(candidates.length).toBeLessThanOrEqual(32);
    expect(candidates.every((candidate) => candidate.href.length <= 256)).toBe(true);
    expect(Buffer.byteLength(JSON.stringify(candidates))).toBeLessThanOrEqual(8192);
  });

  it("finds a link after a normal large output and reuses extraction across delivery", () => {
    const message = { type: "tool_result", toolUseId: "report", content: `${"log output\n".repeat(100_000)}[Review](./reports/review.pdf)` };
    const first = outputLinkCandidatesForMessage(message);
    expect(first).toEqual([{ href: "./reports/review.pdf", syntax: "markdown", label: "Review" }]);
    expect(outputLinkCandidatesForMessage(message)).toBe(first);
    expect(performanceMessage(message)?.outputLinkCandidates).toBe(first);
  });
});
