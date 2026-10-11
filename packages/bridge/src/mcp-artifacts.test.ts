import { describe, expect, it } from "vitest";
import { mcpUserResourceLinks } from "./mcp-artifacts.js";

describe("mcpUserResourceLinks", () => {
  it("returns bounded resource links addressed to the user", () => {
    expect(
      mcpUserResourceLinks([
        {
          type: "resource_link",
          uri: "file:///project/reports/review.pdf",
          name: "review.pdf",
          description: "Final review report",
          mimeType: "application/pdf",
          annotations: { audience: ["assistant", "user"] },
        },
      ]),
    ).toEqual([
      {
        uri: "file:///project/reports/review.pdf",
        name: "review.pdf",
        description: "Final review report",
        mimeType: "application/pdf",
      },
    ]);
  });

  it("ignores text, unannotated links, and assistant-only links", () => {
    expect(
      mcpUserResourceLinks([
        { type: "text", text: "file:///project/private.txt" },
        {
          type: "resource_link",
          uri: "file:///project/unannotated.txt",
          name: "unannotated.txt",
        },
        {
          type: "resource_link",
          uri: "file:///project/assistant.txt",
          name: "assistant.txt",
          annotations: { audience: ["assistant"] },
        },
      ]),
    ).toEqual([]);
  });

  it("rejects malformed links and deduplicates identical URIs", () => {
    expect(
      mcpUserResourceLinks([
        {
          type: "resource_link",
          uri: "file:///project/report.pdf",
          name: "report.pdf",
          annotations: { audience: ["user"] },
        },
        {
          type: "resource_link",
          uri: "file:///project/report.pdf",
          name: "duplicate.pdf",
          annotations: { audience: ["user"] },
        },
        {
          type: "resource_link",
          uri: "file:///project/" + "x".repeat(2048),
          name: "oversized.pdf",
          annotations: { audience: ["user"] },
        },
        {
          type: "resource_link",
          uri: "file:///project/missing-name.pdf",
          name: " ",
          annotations: { audience: ["user"] },
        },
      ]),
    ).toEqual([
      { uri: "file:///project/report.pdf", name: "report.pdf" },
    ]);
  });
});
