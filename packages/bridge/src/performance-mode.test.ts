import { describe, expect, it } from "vitest";
import {
  ALL_PERFORMANCE_FILTER,
  RECOMMENDED_PERFORMANCE_FILTER,
  performanceMessage,
  type PerformanceFilter,
} from "./performance-mode.js";
import { parseClientMessage } from "./parser.js";

const tool = { type: "tool_use", id: "t1", name: "mcp__simulator__screenshot", input: { huge: "x".repeat(1_000_000) } };
const assistant = { type: "assistant", message: { id: "a1", role: "assistant", content: [tool, { type: "thinking", thinking: "private" }, { type: "text", text: "Done" }] } };
const result = { type: "tool_result", toolUseId: "t1", content: "large".repeat(100_000), images: [{ data: "x".repeat(1_000_000) }], rawContentBlocks: ["raw"] };

describe("performance delivery projection", () => {
  it("keeps a swarm's board posts and worker briefs in live, history and delta delivery", () => {
    const post = { type: "tool_use", id: "swarm-post:s:2", name: "SwarmPost", input: { seq: 2, agent: "writer", agentIndex: 0, text: "@coordinator [done]" } };
    const add = { type: "tool_use", id: "c1", name: "swarm", input: { action: "add", name: "writer", brief: "Write a.txt" } };
    const status = { type: "tool_use", id: "c2", name: "swarm", input: { action: "status" } };
    const live = { type: "assistant", message: { id: "a1", role: "assistant", content: [post, add, status] } };
    const kept = { ...live, message: { ...live.message, content: [post, add] } };
    const postResult = { type: "tool_result", toolUseId: post.id, content: "@coordinator [done]", toolName: "SwarmPost" };
    const marker = { type: "tool_result", toolUseId: post.id, toolName: "SwarmPost", content: "" };

    expect(performanceMessage(live)).toEqual(kept);
    expect(performanceMessage(postResult)).toEqual(marker);
    expect(performanceMessage({ type: "history", messages: [live, postResult] })!.messages).toEqual([kept, marker]);
    expect(
      performanceMessage({ type: "history_delta", fromSeq: 1, toSeq: 2, messages: [{ seq: 1, message: live }, { seq: 2, message: postResult }] }),
    ).toEqual({
      type: "history_delta",
      filtered: true,
      fromSeq: 1,
      toSeq: 2,
      messages: [{ seq: 1, message: kept }, { seq: 2, message: marker }],
    });
  });

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

  it("keeps the routing metadata of a stripped tool result and drops absent fields", () => {
    expect(
      performanceMessage({
        role: "tool_result",
        toolUseId: "t1",
        content: "large output",
        userMessageUuid: "u1",
        permissionOutcome: "approved",
        sessionId: "s1",
        historySeq: 0,
        images: [{ data: "x" }],
      }),
    ).toStrictEqual({
      role: "tool_result",
      toolUseId: "t1",
      content: "",
      userMessageUuid: "u1",
      permissionOutcome: "approved",
      sessionId: "s1",
      historySeq: 0,
    });
    expect(
      performanceMessage({
        type: "tool_result",
        toolUseId: "t1",
        content: "large output",
        userMessageUuid: null,
        permissionOutcome: null,
        sessionId: null,
        historySeq: null,
      }),
    ).toStrictEqual({ type: "tool_result", toolUseId: "t1", content: "" });
  });

  it("does not forward non-text content of an answered question", () => {
    expect(
      performanceMessage({
        type: "tool_result",
        toolUseId: "t1",
        content: [{ type: "text", text: "structured" }],
        permissionOutcome: "answered",
      }),
    ).toEqual({ type: "tool_result", toolUseId: "t1", content: "", permissionOutcome: "answered" });
  });

  it("filters assistant content down to readable text, thinking and approval tools", () => {
    const kept = [
      { type: "text", text: "Visible" },
      { type: "thinking", thinking: "Reasoning" },
      { ...tool, name: "Write", input: { file_path: "C:\\Users\\me\\.claude\\plans\\a.md", content: "plan" } },
    ];
    const dropped = [
      null,
      "raw string",
      ["nested"],
      { type: "text", text: "   \n" },
      { type: "text" },
      { type: "text", text: 5 },
      { type: "thinking" },
      { type: "thinking", thinking: " " },
      { type: "image", source: "data" },
      // Only real tool_use blocks are matched by tool name.
      { type: "server_tool_use", name: "AskUserQuestion" },
      { ...tool, name: "Write", input: { file_path: "/repo/src/a.ts", content: "code" } },
      { ...tool, name: "Write", input: { file_path: 42 } },
      { ...tool, name: "Write", input: "/home/.claude/plans/a.md" },
      { ...tool, name: "Write", input: null },
      { ...tool, name: "Edit", input: { file_path: "/home/.claude/plans/a.md" } },
    ];
    expect(
      performanceMessage({ role: "assistant", content: [...dropped, ...kept] }),
    ).toEqual({ role: "assistant", content: kept });
    expect(performanceMessage({ role: "assistant", content: dropped })).toBeNull();
    // An empty image list does not keep an otherwise empty message alive.
    expect(performanceMessage({ role: "assistant", content: dropped, images: [] })).toBeNull();
    expect(
      performanceMessage({ type: "assistant", message: { role: "assistant", content: dropped }, images: [] }),
    ).toBeNull();
  });

  it("leaves messages that only resemble assistant or history frames untouched", () => {
    for (const msg of [
      { role: "user", content: [tool] },
      { role: "assistant", content: "plain string" },
      { type: "assistant", message: null },
      { type: "assistant", message: "text" },
      { type: "assistant", message: [tool] },
      { type: "stream_event", message: { content: [tool] } },
      { type: "session_list", messages: [{ message: result }] },
      { type: "history_delta", messages: "none" },
      { type: "history", messages: null },
    ]) expect(performanceMessage(msg)).toEqual(msg);
  });

  it("skips malformed entries in history frames", () => {
    expect(
      performanceMessage({ type: "history", messages: [null, "text", ["x"], result] }),
    ).toEqual({ type: "history", messages: [{ type: "tool_result", toolUseId: "t1", content: "" }] });
    expect(
      performanceMessage({
        type: "history_snapshot",
        fromSeq: 1,
        messages: [
          null,
          "text",
          { seq: 1 },
          { seq: 2, message: "text" },
          { seq: 3, message: [result] },
          { seq: 4, message: { type: "tool_use_summary", summary: "read" } },
          { seq: 5, message: result },
        ],
      }),
    ).toEqual({
      type: "history_snapshot",
      fromSeq: 1,
      filtered: true,
      messages: [{ seq: 5, message: { type: "tool_result", toolUseId: "t1", content: "" } }],
    });
  });

  it("validates preferences while accepting legacy capabilities", () => {
    expect(parseClientMessage(JSON.stringify({ type: "client_capabilities" }))).not.toBeNull();
    for (const patch of [
      { performanceMode: "yes" },
      { sessionPerformanceModes: [] },
      { sessionPerformanceModes: { a: 1 } },
      { deliveryRevision: -1 },
      { performanceFilter: null },
      { performanceFilter: { tasks: true } },
      { performanceFilter: { ...RECOMMENDED_PERFORMANCE_FILTER, tasks: "yes" } },
      { sessionPerformanceFilters: [] },
      { sessionPerformanceFilters: { s1: { tasks: true } } },
    ]) {
      expect(parseClientMessage(JSON.stringify({ type: "client_capabilities", ...patch }))).toBeNull();
    }
    expect(parseClientMessage(JSON.stringify({
      type: "client_capabilities",
      deliveryRevision: 2,
      performanceMode: true,
      sessionPerformanceModes: { a: false },
      performanceFilter: RECOMMENDED_PERFORMANCE_FILTER,
      sessionPerformanceFilters: { a: ALL_PERFORMANCE_FILTER },
    }))).not.toBeNull();
  });

  it("supports per-category v2 filters including tasks, thinking, subagents, code edits, other tools and results", () => {
    const todo = { type: "tool_use", id: "todo1", name: "TodoWrite", input: { todos: [{ content: "Ship", status: "in_progress" }] } };
    const updatePlan = { type: "tool_use", id: "plan1", name: "UpdatePlan", input: { todos: [{ content: "Check", status: "pending" }] } };
    const taskCreate = { type: "tool_use", id: "tc1", name: "TaskCreate", input: { subject: "Verify" } };
    const subagent = { type: "tool_use", id: "sub1", name: "Agent", input: { description: "Explore" } };
    const swarmPost = { type: "tool_use", id: "sp1", name: "SwarmPost", input: { seq: 1, text: "hi" } };
    const edit = { type: "tool_use", id: "ed1", name: "Edit", input: { file_path: "/repo/a.ts", old_string: "a", new_string: "b" } };
    const fileChange = { type: "tool_use", id: "fc1", name: "FileChange", input: { changes: [{ path: "a.ts" }] } };
    const bash = { type: "tool_use", id: "b1", name: "Bash", input: { command: "ls" } };
    const thinking = { type: "thinking", thinking: "Step by step" };
    const text = { type: "text", text: "Answer" };
    const mixed = {
      type: "assistant",
      message: {
        id: "m1",
        role: "assistant",
        content: [thinking, todo, updatePlan, taskCreate, subagent, swarmPost, edit, fileChange, bash, text],
      },
    };
    const summary = { type: "tool_use_summary", summary: "Read 4 files" };
    const thinkingDelta = { type: "thinking_delta", text: "hmm" };

    // Recommended preset keeps tasks, thinking, subagents/swarm, and summaries while dropping edits, other tools and results.
    expect(performanceMessage(mixed, RECOMMENDED_PERFORMANCE_FILTER)).toEqual({
      type: "assistant",
      message: {
        id: "m1",
        role: "assistant",
        content: [thinking, todo, updatePlan, taskCreate, subagent, swarmPost, text],
      },
    });
    expect(performanceMessage(summary, RECOMMENDED_PERFORMANCE_FILTER)).toEqual(summary);
    expect(performanceMessage(thinkingDelta, RECOMMENDED_PERFORMANCE_FILTER)).toEqual(thinkingDelta);
    expect(performanceMessage(result, RECOMMENDED_PERFORMANCE_FILTER)).toEqual({
      type: "tool_result",
      toolUseId: "t1",
      content: "",
    });

    // Disabling thinking drops both thinking blocks and thinking_delta streams.
    const noThinking: PerformanceFilter = { ...RECOMMENDED_PERFORMANCE_FILTER, thinking: false };
    expect(performanceMessage(thinkingDelta, noThinking)).toBeNull();
    expect(performanceMessage(mixed, noThinking)).toEqual({
      type: "assistant",
      message: {
        id: "m1",
        role: "assistant",
        content: [todo, updatePlan, taskCreate, subagent, swarmPost, text],
      },
    });

    // Disabling subagents removes SwarmPost, Agent and tool_use_summary.
    const noSubagents: PerformanceFilter = { ...RECOMMENDED_PERFORMANCE_FILTER, subagents: false };
    expect(performanceMessage(summary, noSubagents)).toBeNull();
    expect(performanceMessage(mixed, noSubagents)).toEqual({
      type: "assistant",
      message: {
        id: "m1",
        role: "assistant",
        content: [thinking, todo, updatePlan, taskCreate, text],
      },
    });

    // Enabling codeEdits keeps Edit & FileChange while still omitting Bash and tool results.
    const withEdits: PerformanceFilter = { ...RECOMMENDED_PERFORMANCE_FILTER, codeEdits: true };
    expect(performanceMessage(mixed, withEdits)).toEqual({
      type: "assistant",
      message: {
        id: "m1",
        role: "assistant",
        content: [thinking, todo, updatePlan, taskCreate, subagent, swarmPost, edit, fileChange, text],
      },
    });

    // Enabling otherTools without toolResults keeps one-line tool calls while stripping heavy outputs.
    const callsOnly: PerformanceFilter = { ...ALL_PERFORMANCE_FILTER, toolResults: false };
    expect(performanceMessage(mixed, callsOnly)).toEqual(mixed);
    expect(performanceMessage(result, callsOnly)).toEqual({
      type: "tool_result",
      toolUseId: "t1",
      content: "",
    });

    // Enabling toolResults preserves full tool output and images.
    const withResults: PerformanceFilter = { ...RECOMMENDED_PERFORMANCE_FILTER, toolResults: true };
    expect(performanceMessage(result, withResults)).toEqual(result);

    // All-enabled filter is a no-op and does not mark history_delta as filtered.
    const delta = { type: "history_delta", fromSeq: 1, toSeq: 1, messages: [{ seq: 1, message: mixed }] };
    expect(performanceMessage(delta, ALL_PERFORMANCE_FILTER)).toBe(delta);
  });
});
