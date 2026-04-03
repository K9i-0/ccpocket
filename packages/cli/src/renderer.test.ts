import { describe, it, expect } from "vitest";
import { renderMessage } from "./renderer.js";

describe("renderMessage", () => {
  it("renders assistant text", () => {
    const output = renderMessage({
      type: "assistant",
      message: {
        id: "1",
        role: "assistant",
        content: [{ type: "text", text: "Hello world" }],
        model: "claude-opus-4-6",
      },
    });
    expect(output).toContain("Hello world");
  });

  it("renders tool_use with name and indented input", () => {
    const output = renderMessage({
      type: "assistant",
      message: {
        id: "2",
        role: "assistant",
        content: [{
          type: "tool_use",
          id: "tu1",
          name: "Read",
          input: { file_path: "/src/main.ts" },
        }],
        model: "claude-opus-4-6",
      },
    });
    expect(output).toContain("Read");
    expect(output).toContain("/src/main.ts");
  });

  it("renders tool_result content", () => {
    const output = renderMessage({
      type: "tool_result",
      toolUseId: "tu1",
      content: "file contents here",
    });
    expect(output).toContain("file contents here");
  });

  it("renders permission_request", () => {
    const output = renderMessage({
      type: "permission_request",
      toolUseId: "tu1",
      toolName: "Edit",
      input: { file_path: "/src/app.ts" },
    });
    expect(output).toContain("Edit");
    expect(output).toContain("/src/app.ts");
  });

  it("renders status messages", () => {
    const output = renderMessage({ type: "status", status: "running" });
    expect(output).toContain("running");
  });

  it("renders errors", () => {
    const output = renderMessage({ type: "error", message: "Something broke" });
    expect(output).toContain("Something broke");
  });

  it("returns empty string for stream_delta (handled separately)", () => {
    const output = renderMessage({ type: "stream_delta", text: "partial" });
    expect(output).toBe("");
  });
});
