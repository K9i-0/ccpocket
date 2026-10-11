import { describe, expect, it } from "vitest";
import { performanceMessage } from "./performance-mode.js";

const resourceLink = {
  uri: "file:///project/reports/review.pdf",
  name: "review.pdf",
  mimeType: "application/pdf",
};
const galleryImage = {
  id: "gallery-image-1",
  url: "/api/gallery/gallery-image-1",
  mimeType: "image/png",
  projectPath: "/project",
  projectName: "project",
  sessionId: "session",
  addedAt: "2026-10-11T00:00:00.000Z",
  sizeBytes: 128,
};

describe("performance MCP artifacts", () => {
  it("retains explicitly user-addressed MCP resource links", () => {
    expect(
      performanceMessage({
        type: "tool_result",
        toolUseId: "review",
        toolName: "mcp:reports/export",
        content: "",
        mcpResourceLinks: [resourceLink],
        rawContentBlocks: [{ type: "resource_link", uri: resourceLink.uri }],
      }),
    ).toEqual({
      type: "tool_result",
      toolUseId: "review",
      content: "",
      mcpResourceLinks: [resourceLink],
    });
  });

  it("does not infer artifacts from command output text", () => {
    expect(
      performanceMessage({
        type: "tool_result",
        toolUseId: "command",
        toolName: "Bash",
        content: "[report](file:///project/reports/review.pdf)",
      }),
    ).toEqual({ type: "tool_result", toolUseId: "command", content: "" });
  });

  it("keeps artifact metadata when projecting restored histories", () => {
    const message = {
      type: "tool_result",
      toolUseId: "review",
      content: "Full tool output",
      mcpResourceLinks: [resourceLink],
    };
    expect(
      performanceMessage({ type: "history", messages: [message] }),
    ).toEqual({
      type: "history",
      messages: [
        {
          type: "tool_result",
          toolUseId: "review",
          content: "",
          mcpResourceLinks: [resourceLink],
        },
      ],
    });
  });

  it("retains gallery IDs for image cards while hiding image payloads", () => {
    expect(
      performanceMessage({
        type: "tool_result",
        toolUseId: "screenshot",
        content: "",
        images: [{ id: "hash", url: "/images/hash", mimeType: "image/png" }],
        galleryImages: [galleryImage],
      }),
    ).toEqual({
      type: "tool_result",
      toolUseId: "screenshot",
      content: "",
      images: [{ id: "hash", url: "/images/hash", mimeType: "image/png" }],
      galleryImages: [galleryImage],
    });
  });
});
