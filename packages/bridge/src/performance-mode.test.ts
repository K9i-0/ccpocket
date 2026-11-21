import { describe, expect, it } from "vitest";
import { performanceMessage } from "./performance-mode.js";
import { parseClientMessage } from "./parser.js";

const tool = { type: "tool_use", id: "t1", name: "mcp__simulator__screenshot", input: { huge: "x".repeat(1_000_000) } };
const assistant = { type: "assistant", message: { id: "a1", role: "assistant", content: [tool, { type: "thinking", thinking: "private" }, { type: "text", text: "Done" }] } };
const result = { type: "tool_result", toolUseId: "t1", content: "large".repeat(100_000), images: [{ data: "x".repeat(1_000_000) }], rawContentBlocks: ["raw"] };

describe("performance delivery projection", () => {
  it("removes large tool inputs, outputs and screenshot payloads while keeping thinking without mutating history", () => {
    const history = { type: "history", messages: [assistant, result] };
    const projected = performanceMessage(history)!;
    const bytes = Buffer.byteLength(JSON.stringify(projected));
    expect(bytes).toBeLessThan(400);
    expect(bytes / Buffer.byteLength(JSON.stringify(history))).toBeLessThan(0.001);
    expect(projected.messages).toEqual([
      {
        ...assistant,
        message: {
          ...assistant.message,
          content: [
            { type: "thinking", thinking: "private" },
            { type: "text", text: "Done" },
          ],
        },
      },
      { type: "tool_result", toolUseId: "t1", content: "" },
    ]);
    expect(assistant.message.content).toHaveLength(3);
    expect(result.images[0].data).toHaveLength(1_000_000);
  });

  it("preserves generated images, embedded assistant images, thinking deltas, user attachments, Explorer files, errors and approvals", () => {
    const assistantImages = [{ id: "img1", url: "/images/img1", mimeType: "image/png" }];
    for (const msg of [
      { ...result, toolName: "ImageGeneration", rawContentBlocks: undefined },
      { type: "thinking_delta", text: "reasoning" },
      { type: "user_input", images: [{ url: "/image/user" }], text: "look" },
      { type: "file_content", content: "image", path: "a.png" },
      { type: "error", message: "failed" },
      { type: "permission_request", toolUseId: "t1", input: { command: "rm" } },
      {
        ...assistant,
        message: {
          ...assistant.message,
          content: [{ type: "thinking", thinking: "plan" }, { type: "text", text: "![art](art.png)" }],
        },
        images: assistantImages,
      },
    ]) expect(performanceMessage(msg)).toEqual(msg);
    const content = [
      { ...tool, name: "AskUserQuestion" },
      { ...tool, name: "ExitPlanMode" },
      { type: "tool_use", id: "ig1", name: "ImageGeneration", input: { status: "generating", revisedPrompt: "apple" } },
      { ...tool, name: "Write", input: { file_path: "/home/.claude/plans/a.md", content: "plan" } },
    ];
    const msg = { ...assistant, message: { ...assistant.message, content } };
    expect(performanceMessage(msg)).toEqual(msg);

    // Keep assistant messages with embedded images even when all content blocks are stripped.
    expect(
      performanceMessage({
        type: "assistant",
        message: { id: "a2", role: "assistant", content: [tool, { type: "thinking", thinking: "   " }] },
        images: assistantImages,
      }),
    ).toEqual({
      type: "assistant",
      message: { id: "a2", role: "assistant", content: [] },
      images: assistantImages,
    });
    expect(
      performanceMessage({
        type: "past_history",
        messages: [
          { role: "assistant", content: [tool], images: assistantImages },
        ],
      }),
    ).toEqual({
      type: "past_history",
      messages: [
        { role: "assistant", content: [], images: assistantImages },
      ],
    });
  });

  it("keeps resolved question answers in live and past history", () => {
    expect(
      performanceMessage({
        ...result,
        content: "Forest birdsong",
        permissionOutcome: "answered",
      }),
    ).toEqual({
      type: "tool_result",
      toolUseId: "t1",
      content: "Forest birdsong",
      permissionOutcome: "answered",
    });
    expect(
      performanceMessage({
        type: "past_history",
        messages: [
          { role: "assistant", content: [tool] },
          {
            role: "tool_result",
            toolUseId: "t1",
            content: "Forest birdsong",
            permissionOutcome: "answered",
          },
        ],
      }),
    ).toEqual({
      type: "past_history",
      messages: [
        {
          role: "tool_result",
          toolUseId: "t1",
          content: "Forest birdsong",
          permissionOutcome: "answered",
        },
      ],
    });
  });

  it("preserves sparse history sequence bounds and marks intentional gaps", () => {
    const msg = { type: "history_delta", fromSeq: 1, toSeq: 3, messages: [
      { seq: 1, message: { ...assistant, message: { ...assistant.message, content: [tool] } } },
      { seq: 2, message: result },
      { seq: 3, message: assistant },
    ] };
    expect(performanceMessage(msg)).toMatchObject({ filtered: true, fromSeq: 1, toSeq: 3, messages: [{ seq: 2 }, { seq: 3 }] });
    expect(performanceMessage({ type: "tool_use_summary", summary: "read 3 files" })).toBeNull();
    expect(performanceMessage({ type: "thinking_delta", text: "x" })).toEqual({ type: "thinking_delta", text: "x" });
  });

  it("validates preferences while accepting legacy capabilities", () => {
    expect(parseClientMessage(JSON.stringify({ type: "client_capabilities" }))).not.toBeNull();
    for (const patch of [{ performanceMode: "yes" }, { sessionPerformanceModes: [] }, { sessionPerformanceModes: { a: 1 } }, { deliveryRevision: -1 }]) {
      expect(parseClientMessage(JSON.stringify({ type: "client_capabilities", ...patch }))).toBeNull();
    }
    expect(parseClientMessage(JSON.stringify({ type: "client_capabilities", deliveryRevision: 2, performanceMode: true, sessionPerformanceModes: { a: false } }))).not.toBeNull();
  });
});
