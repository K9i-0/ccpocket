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
