import { describe, expect, it } from "vitest";
import {
  cleanClaudeCompactSummary,
  normalizeClaudeCompactMetadata,
  transcriptPageRange,
} from "./context-compaction.js";

describe("normalizeClaudeCompactMetadata", () => {
  it("reads the SDK stream casing", () => {
    expect(
      normalizeClaudeCompactMetadata({
        trigger: "manual",
        pre_tokens: 21935,
        post_tokens: 7722,
        duration_ms: 5995,
      }),
    ).toEqual({ trigger: "manual", preTokens: 21935, postTokens: 7722 });
  });

  it("reads the JSONL transcript casing", () => {
    expect(
      normalizeClaudeCompactMetadata({
        trigger: "auto",
        preTokens: 180000,
        postTokens: 9000,
      }),
    ).toEqual({ trigger: "auto", preTokens: 180000, postTokens: 9000 });
  });

  it("drops unknown or malformed fields", () => {
    expect(
      normalizeClaudeCompactMetadata({ trigger: "other", preTokens: "1" }),
    ).toEqual({});
    expect(normalizeClaudeCompactMetadata(null)).toEqual({});
  });

  it("omits token counts that are absent or not finite", () => {
    expect(normalizeClaudeCompactMetadata({ trigger: "auto" })).toStrictEqual({
      trigger: "auto",
    });
    expect(
      normalizeClaudeCompactMetadata({ preTokens: NaN, post_tokens: Infinity }),
    ).toStrictEqual({});
    expect(
      normalizeClaudeCompactMetadata({ pre_tokens: 0, postTokens: 12 }),
    ).toStrictEqual({ preTokens: 0, postTokens: 12 });
  });
});

describe("cleanClaudeCompactSummary", () => {
  it("keeps only the summary body", () => {
    const raw =
      "This session is being continued from a previous conversation that ran out of context. The summary below covers the earlier portion of the conversation.\n\n" +
      "<system-reminder>\n<tools-used-before-summary></tools-used-before-summary>\n</system-reminder>\n" +
      "Summary:\n1. Primary Request and Intent:\n   Reply with ok.";
    expect(cleanClaudeCompactSummary(raw)).toBe(
      "1. Primary Request and Intent:\n   Reply with ok.",
    );
  });

  it("drops the resume instructions appended for the model", () => {
    const raw =
      "Summary:\n9. Next step:\n   - None.\n\n" +
      "If you need specific details from before compaction (like exact code snippets), read the full transcript at: /tmp/x.jsonl\n" +
      "Continue the conversation from where it left off without asking the user any further questions.";
    expect(cleanClaudeCompactSummary(raw)).toBe("9. Next step:\n   - None.");
  });

  it("removes multi-line system reminders inside the summary body", () => {
    const raw =
      "Summary:\nBefore.<system-reminder>\nhidden one\n</system-reminder>\n" +
      "Between.<system-reminder>hidden two</system-reminder>\nAfter.";
    expect(cleanClaudeCompactSummary(raw)).toBe("Before.\nBetween.\nAfter.");
  });

  it.each([
    "If you need specific details from before compaction, read the transcript.",
    "Continue the conversation from where it left off without asking.",
  ])("cuts each model trailer on its own, indented or not: %s", (trailer) => {
    expect(cleanClaudeCompactSummary(`Summary:\nBody.\n${trailer}`)).toBe("Body.");
    expect(cleanClaudeCompactSummary(`Summary:\nBody.\n\n   ${trailer}`)).toBe("Body.");
  });

  it("returns the trimmed text when there is no heading", () => {
    expect(cleanClaudeCompactSummary("  plain summary \n")).toBe(
      "plain summary",
    );
  });
});

describe("transcriptPageRange", () => {
  const roles = ["user", "assistant", "compaction", "user", "assistant"];

  it("pages back from the end", () => {
    expect(transcriptPageRange(roles, { limit: 2 }, 200, 1000)).toEqual({
      start: 3,
      end: 5,
    });
  });

  it("ends the first page at the latest compaction marker", () => {
    expect(
      transcriptPageRange(
        roles,
        { untilLatestCompaction: true, limit: 2 },
        200,
        1000,
      ),
    ).toEqual({ start: 1, end: 3 });
  });

  it("ends the first page at a marker that is the first entry", () => {
    expect(
      transcriptPageRange(["compaction", "user", "assistant"], { untilLatestCompaction: true }, 200, 1000),
    ).toEqual({ start: 0, end: 1 });
  });

  it("falls back to the full transcript without a marker", () => {
    expect(
      transcriptPageRange(["user", "assistant"], { untilLatestCompaction: true }, 200, 1000),
    ).toEqual({ start: 0, end: 2 });
  });

  it("continues before an explicit index and clamps limits", () => {
    expect(
      transcriptPageRange(roles, { beforeIndex: 1, untilLatestCompaction: true }, 200, 1000),
    ).toEqual({ start: 0, end: 1 });
    expect(transcriptPageRange(roles, { beforeIndex: 99, limit: 5000 }, 200, 3)).toEqual({
      start: 2,
      end: 5,
    });
  });
});
