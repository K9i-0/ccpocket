import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  buildContentSnippet,
  projectFolderName,
  recentSessionMetadataSearchField,
  searchRecentSessionContent,
  searchTranscriptFile,
  transcriptLineMessageTexts,
  withRecentSessionMetadataSearchMatch,
} from "./recent-session-search.js";

describe("recentSessionMetadataSearchField", () => {
  const session = {
    name: "Alpha name",
    firstPrompt: "beta first",
    lastPrompt: "gamma last",
    summary: "delta summary",
    projectPath: "/Users/me/Workspace/epsilon-app",
    gitBranch: "feat/zeta",
  };

  it("reports each field when only that field matches", () => {
    expect(recentSessionMetadataSearchField(session, "ALPHA")).toBe("name");
    expect(recentSessionMetadataSearchField(session, "beta")).toBe("firstPrompt");
    expect(recentSessionMetadataSearchField(session, "gamma")).toBe("lastPrompt");
    expect(recentSessionMetadataSearchField(session, "delta")).toBe("summary");
    expect(recentSessionMetadataSearchField(session, "epsilon")).toBe("project");
    expect(recentSessionMetadataSearchField(session, "zeta")).toBe("branch");
    expect(recentSessionMetadataSearchField(session, "nothing")).toBeUndefined();
  });

  it("follows name → firstPrompt → lastPrompt → summary → project → branch", () => {
    const all = {
      name: "x name",
      firstPrompt: "x first",
      lastPrompt: "x last",
      summary: "x summary",
      projectPath: "/tmp/x",
      gitBranch: "x",
    };
    expect(recentSessionMetadataSearchField(all, "x")).toBe("name");
    expect(recentSessionMetadataSearchField({ ...all, name: undefined }, "x")).toBe(
      "firstPrompt",
    );
    expect(
      recentSessionMetadataSearchField(
        { ...all, name: undefined, firstPrompt: "" },
        "x",
      ),
    ).toBe("lastPrompt");
    expect(
      recentSessionMetadataSearchField(
        { projectPath: "/tmp/x", gitBranch: "x" },
        "x",
      ),
    ).toBe("project");
  });

  it("matches only the project folder name, not parent directories", () => {
    expect(recentSessionMetadataSearchField(session, "workspace")).toBeUndefined();
    expect(projectFolderName("/tmp/repo/")).toBe("repo");
    expect(projectFolderName("C:\\src\\repo")).toBe("repo");
  });

  it("adds searchMatch without mutating the input", () => {
    const copy = withRecentSessionMetadataSearchMatch(session, "zeta");
    expect(copy).toEqual({ ...session, searchMatch: { field: "branch" } });
    expect(session).not.toHaveProperty("searchMatch");
    expect(withRecentSessionMetadataSearchMatch(session, "nope")).toBe(session);
    expect(withRecentSessionMetadataSearchMatch(session, undefined)).toBe(session);
  });

  it("matches nothing for an empty query", () => {
    expect(recentSessionMetadataSearchField(session, "")).toBeUndefined();
    expect(withRecentSessionMetadataSearchMatch(session, "")).toBe(session);
  });

  it("returns an empty folder name for a path without segments", () => {
    expect(projectFolderName("")).toBe("");
    expect(projectFolderName("/")).toBe("");
    expect(projectFolderName("repo")).toBe("repo");
    expect(projectFolderName("C:\\src\\\\repo\\")).toBe("repo");
  });
});

describe("transcriptLineMessageTexts", () => {
  it("extracts Claude user and assistant text only", () => {
    expect(
      transcriptLineMessageTexts("claude", {
        type: "user",
        message: { role: "user", content: "plain text" },
      }),
    ).toEqual(["plain text"]);
    expect(
      transcriptLineMessageTexts("claude", {
        type: "user",
        message: {
          content: [
            { type: "tool_result", content: "tool output" },
            { type: "text", text: "typed" },
          ],
        },
      }),
    ).toEqual(["typed"]);
    expect(
      transcriptLineMessageTexts("claude", {
        type: "assistant",
        message: {
          content: [
            { type: "thinking", thinking: "hidden" },
            { type: "tool_use", input: { command: "ls" } },
            { type: "text", text: "answer" },
          ],
        },
      }),
    ).toEqual(["answer"]);
    expect(
      transcriptLineMessageTexts("claude", {
        type: "user",
        isMeta: true,
        message: { content: "meta" },
      }),
    ).toEqual([]);
  });

  it("extracts Codex messages and skips injected context and tools", () => {
    expect(
      transcriptLineMessageTexts("codex", {
        type: "event_msg",
        payload: { type: "user_message", message: "hello" },
      }),
    ).toEqual(["hello"]);
    expect(
      transcriptLineMessageTexts("codex", {
        type: "response_item",
        payload: {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "reply" }],
        },
      }),
    ).toEqual(["reply"]);
    expect(
      transcriptLineMessageTexts("codex", {
        type: "response_item",
        payload: {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text: "<environment_context>x" }],
        },
      }),
    ).toEqual([]);
    expect(
      transcriptLineMessageTexts("codex", {
        type: "response_item",
        payload: { type: "function_call_output", output: "secret" },
      }),
    ).toEqual([]);
  });

  it.each([null, undefined, "text", 42, true])(
    "returns nothing for a non-object line: %j",
    (line) => {
      expect(transcriptLineMessageTexts("claude", line)).toEqual([]);
      expect(transcriptLineMessageTexts("codex", line)).toEqual([]);
    },
  );

  describe("Claude", () => {
    it.each([
      ["no message", { type: "user" }],
      ["a null message", { type: "user", message: null }],
      ["a string message", { type: "user", message: "needle" }],
      ["no content", { type: "assistant", message: {} }],
      ["non-text content", { type: "assistant", message: { content: 42 } }],
      ["a compact summary", { type: "user", isCompactSummary: true, message: { content: "x" } }],
      ["a system entry", { type: "system", message: { content: "x" } }],
      ["a summary entry", { type: "summary", message: { content: "x" } }],
      ["an entry without type", { message: { content: "x" } }],
    ])("returns nothing for %s", (_label, line) => {
      expect(transcriptLineMessageTexts("claude", line)).toEqual([]);
    });

    it("keeps entries whose meta flags are false", () => {
      expect(
        transcriptLineMessageTexts("claude", {
          type: "user",
          isMeta: false,
          isCompactSummary: false,
          message: { content: "kept" },
        }),
      ).toEqual(["kept"]);
    });

    it("skips malformed content blocks", () => {
      expect(
        transcriptLineMessageTexts("claude", {
          type: "assistant",
          message: {
            content: [
              null,
              "bare string",
              ["text"],
              { text: "no type" },
              { type: 5, text: "numeric type" },
              { type: "text", text: 5 },
              { type: "text" },
              { type: "text", text: "ok" },
            ],
          },
        }),
      ).toEqual(["ok"]);
    });

    it.each([
      "<local-command-caveat>Caveat</local-command-caveat>",
      "<local-command-stdout>out</local-command-stdout>",
      "<local-command-stderr>err</local-command-stderr>",
      "<task-notification>done</task-notification>",
      "<teammate-message>hi</teammate-message>",
      "<bash-input>ls</bash-input>",
      "<bash-stdout>file</bash-stdout>",
      "<command-name>/clear</command-name>",
      "<command-message>clear</command-message>",
      "<command-args>x</command-args>",
      "\n  <command-name>/clear</command-name>",
    ])("drops system-injected user text %j", (text) => {
      expect(
        transcriptLineMessageTexts("claude", { type: "user", message: { content: text } }),
      ).toEqual([]);
    });

    it("keeps user text that only mentions an injected tag", () => {
      expect(
        transcriptLineMessageTexts("claude", {
          type: "user",
          message: {
            content: [
              { type: "text", text: "<bash-input>ls</bash-input>" },
              { type: "text", text: "what does <command-name> mean?" },
              { type: "text", text: "<unknown-tag>typed" },
            ],
          },
        }),
      ).toEqual(["what does <command-name> mean?", "<unknown-tag>typed"]);
    });

    it("does not filter assistant text that starts with an injected tag", () => {
      expect(
        transcriptLineMessageTexts("claude", {
          type: "assistant",
          message: { content: [{ type: "text", text: "<task-notification> is a tag" }] },
        }),
      ).toEqual(["<task-notification> is a tag"]);
    });
  });

  describe("Codex", () => {
    const injected = [
      "# AGENTS.md instructions for /repo",
      "<environment_context>",
      "<user_instructions>",
      "<permissions instructions>",
      "<collaboration_mode>",
      "<personality_spec>",
      "<skills_instructions>",
      "<plugins_instructions>",
      "<skill>",
    ];

    it.each(injected)("drops injected user context starting with %j", (prefix) => {
      const text = `\n  ${prefix}\nbody text`;
      expect(
        transcriptLineMessageTexts("codex", {
          type: "event_msg",
          payload: { type: "user_message", message: text },
        }),
      ).toEqual([]);
      expect(
        transcriptLineMessageTexts("codex", {
          type: "response_item",
          payload: {
            type: "message",
            role: "user",
            content: [
              { type: "input_text", text },
              { type: "input_text", text: "typed" },
            ],
          },
        }),
      ).toEqual(["typed"]);
    });

    it("keeps user text that only mentions injected context", () => {
      expect(
        transcriptLineMessageTexts("codex", {
          type: "event_msg",
          payload: { type: "user_message", message: "explain the <skill> tag" },
        }),
      ).toEqual(["explain the <skill> tag"]);
    });

    it("does not filter agent messages", () => {
      expect(
        transcriptLineMessageTexts("codex", {
          type: "event_msg",
          payload: { type: "agent_message", message: "<environment_context> is injected" },
        }),
      ).toEqual(["<environment_context> is injected"]);
    });

    it.each([
      ["an event without payload", { type: "event_msg" }],
      ["a response item without payload", { type: "response_item", payload: null }],
      [
        "another event type",
        { type: "event_msg", payload: { type: "token_count", message: "x" } },
      ],
      [
        "a non-string event message",
        { type: "event_msg", payload: { type: "user_message", message: 5 } },
      ],
      [
        "an event shaped like a response message",
        { type: "event_msg", payload: { type: "message", role: "assistant", content: "x" } },
      ],
      [
        "another entry type with a message payload",
        { type: "turn_context", payload: { type: "message", role: "assistant", content: "x" } },
      ],
      ["another top-level type", { type: "reasoning", role: "assistant", content: "x" }],
      [
        "a non-message response item",
        { type: "response_item", payload: { type: "reasoning", role: "assistant", content: "x" } },
      ],
      [
        "a developer message",
        { type: "response_item", payload: { type: "message", role: "developer", content: "x" } },
      ],
      [
        "a message without role",
        { type: "response_item", payload: { type: "message", content: "x" } },
      ],
    ])("returns nothing for %s", (_label, line) => {
      expect(transcriptLineMessageTexts("codex", line)).toEqual([]);
    });

    it("reads only the text blocks that belong to the role", () => {
      const content = [
        { type: "input_text", text: "in" },
        { type: "output_text", text: "out" },
        { type: "text", text: "plain" },
        { type: "input_image", image_url: "data:..." },
      ];
      expect(
        transcriptLineMessageTexts("codex", {
          type: "response_item",
          payload: { type: "message", role: "user", content },
        }),
      ).toEqual(["in", "plain"]);
      expect(
        transcriptLineMessageTexts("codex", {
          type: "response_item",
          payload: { type: "message", role: "assistant", content },
        }),
      ).toEqual(["out", "plain"]);
    });

    it("supports the legacy top-level message shape", () => {
      expect(
        transcriptLineMessageTexts("codex", {
          type: "message",
          role: "assistant",
          content: [{ type: "output_text", text: "legacy reply" }],
        }),
      ).toEqual(["legacy reply"]);
      expect(
        transcriptLineMessageTexts("codex", {
          type: "message",
          role: "user",
          content: [{ type: "input_text", text: "legacy prompt" }],
        }),
      ).toEqual(["legacy prompt"]);
    });
  });
});

describe("buildContentSnippet", () => {
  it("collapses whitespace and returns short text whole", () => {
    expect(buildContentSnippet("a\n\n  b\tc", "b")).toBe("a b c");
  });

  it("centers about 120 characters around the hit", () => {
    const text = `${"x".repeat(300)} needle ${"y".repeat(300)}`;
    const snippet = buildContentSnippet(text, "NEEDLE");
    expect(snippet).toContain("needle");
    expect(snippet.startsWith("…")).toBe(true);
    expect(snippet.endsWith("…")).toBe(true);
    expect(snippet.length).toBeLessThanOrEqual(122);
  });

  it("starts at the beginning when the hit is near the start", () => {
    const snippet = buildContentSnippet(`needle ${"z".repeat(300)}`, "needle");
    expect(snippet.startsWith("needle")).toBe(true);
    expect(snippet.endsWith("…")).toBe(true);
  });

  it("trims short text", () => {
    expect(buildContentSnippet("  hi there \n", "hi")).toBe("hi there");
  });

  it("centers the window on the hit", () => {
    const text = `${"a".repeat(10)} needle ${"b".repeat(10)}`;
    expect(buildContentSnippet(text, "needle", 10)).toBe("…a needle b…");
  });

  it("ends at the end of the text when the hit is near the end", () => {
    const text = `${"a".repeat(20)} needle`;
    expect(buildContentSnippet(text, "needle", 10)).toBe("…aaa needle");
  });

  it("starts at the beginning when the query is not in the text", () => {
    expect(buildContentSnippet("abcdefghijklmnopqrstuvwxyz", "0000", 10)).toBe(
      "abcdefghij…",
    );
  });

  it("normalizes whitespace in the query like in the text", () => {
    // Runs of whitespace match a single collapsed space.
    expect(
      buildContentSnippet(`${"a".repeat(10)} \n  needle ${"b".repeat(10)}`, "a \n needle", 10),
    ).toBe("…aa needle…");
    // Leading / trailing whitespace of the query is ignored.
    expect(buildContentSnippet(`${"a".repeat(20)} needle`, " needle  ", 10)).toBe(
      "…aaa needle",
    );
  });
});

describe("transcript content search", () => {
  let dir: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "ccpocket-content-search-"));
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  function writeJsonl(name: string, lines: unknown[]): string {
    const path = join(dir, name);
    writeFileSync(path, lines.map((line) => JSON.stringify(line)).join("\n"));
    return path;
  }

  const claudeUser = (text: string) => ({
    type: "user",
    message: { role: "user", content: text },
  });
  const claudeAssistant = (text: string) => ({
    type: "assistant",
    message: { role: "assistant", content: [{ type: "text", text }] },
  });
  const claudeToolResult = (text: string) => ({
    type: "user",
    message: {
      role: "user",
      content: [{ type: "tool_result", tool_use_id: "t", content: text }],
    },
  });

  it("finds a match in user text", async () => {
    const path = writeJsonl("u.jsonl", [claudeUser("Please fix the Flaky Test")]);
    await expect(searchTranscriptFile("claude", path, "flaky test")).resolves.toEqual({
      status: "match",
      snippet: "Please fix the Flaky Test",
    });
  });

  it("finds a match in assistant text", async () => {
    const path = writeJsonl("a.jsonl", [
      claudeUser("hi"),
      claudeAssistant("The root cause is a race"),
    ]);
    await expect(searchTranscriptFile("claude", path, "race")).resolves.toMatchObject({
      status: "match",
      snippet: "The root cause is a race",
    });
  });

  it("does not match tool_result or tool_use content", async () => {
    const path = writeJsonl("t.jsonl", [
      claudeUser("run it"),
      {
        type: "assistant",
        message: {
          content: [{ type: "tool_use", name: "Bash", input: { command: "grep secretword" } }],
        },
      },
      claudeToolResult("secretword found"),
    ]);
    await expect(
      searchTranscriptFile("claude", path, "secretword"),
    ).resolves.toEqual({ status: "no_match" });
  });

  it("matches text containing JSON-escaped characters", async () => {
    const path = writeJsonl("q.jsonl", [claudeUser('say "hello" now')]);
    await expect(
      searchTranscriptFile("claude", path, '"hello"'),
    ).resolves.toMatchObject({ status: "match" });
  });

  it("matches Codex rollout messages", async () => {
    const path = writeJsonl("rollout.jsonl", [
      { type: "session_meta", payload: { id: "t1", cwd: "/tmp" } },
      { type: "event_msg", payload: { type: "agent_message", message: "Deployed to staging" } },
    ]);
    await expect(
      searchTranscriptFile("codex", path, "staging"),
    ).resolves.toMatchObject({ status: "match", snippet: "Deployed to staging" });
  });

  it("treats a missing file as no match", async () => {
    await expect(
      searchTranscriptFile("claude", join(dir, "missing.jsonl"), "x"),
    ).resolves.toEqual({ status: "no_match" });
  });

  it("matches nothing for an empty query", async () => {
    const path = writeJsonl("e.jsonl", [claudeUser("anything")]);
    await expect(searchTranscriptFile("claude", path, "")).resolves.toEqual({
      status: "no_match",
    });
  });

  it("returns the first matching message", async () => {
    const path = writeJsonl("first.jsonl", [
      claudeUser("unrelated"),
      claudeAssistant("first needle"),
      claudeUser("second needle"),
    ]);
    await expect(searchTranscriptFile("claude", path, "needle")).resolves.toEqual({
      status: "match",
      snippet: "first needle",
    });
  });

  it("keeps scanning after a tool line that contains the query", async () => {
    const path = writeJsonl("tool-then-text.jsonl", [
      claudeToolResult("needle in tool output"),
      claudeUser("typed needle"),
    ]);
    await expect(searchTranscriptFile("claude", path, "needle")).resolves.toEqual({
      status: "match",
      snippet: "typed needle",
    });
  });

  it("keeps scanning after a corrupt line that contains the query", async () => {
    const path = join(dir, "corrupt.jsonl");
    writeFileSync(
      path,
      `{"type":"user","message":{"content":"needle\n${JSON.stringify(claudeUser("valid needle"))}\n`,
    );
    await expect(searchTranscriptFile("claude", path, "needle")).resolves.toEqual({
      status: "match",
      snippet: "valid needle",
    });
  });

  it("keeps scanning a Codex rollout after a non-message line with the query", async () => {
    const path = writeJsonl("codex-tool.jsonl", [
      { type: "response_item", payload: { type: "function_call_output", output: "needle" } },
      { type: "event_msg", payload: { type: "agent_message", message: "reply needle" } },
    ]);
    await expect(searchTranscriptFile("codex", path, "needle")).resolves.toEqual({
      status: "match",
      snippet: "reply needle",
    });
  });

  it("matches Codex lines serialized with whitespace after colons", async () => {
    const path = join(dir, "spaced.jsonl");
    writeFileSync(
      path,
      '{"type": "event_msg", "payload": {"type": "user_message", "message": "spaced needle"}}\n',
    );
    await expect(searchTranscriptFile("codex", path, "needle")).resolves.toEqual({
      status: "match",
      snippet: "spaced needle",
    });
  });

  it("matches non-ASCII letters case-insensitively in both directions", async () => {
    const upper = writeJsonl("upper.jsonl", [claudeUser("Meet at the CAFÉ")]);
    const lower = writeJsonl("lower.jsonl", [claudeUser("meet at the café")]);
    expect((await searchTranscriptFile("claude", upper, "café")).status).toBe("match");
    expect((await searchTranscriptFile("claude", lower, "CAFÉ")).status).toBe("match");
  });

  it("times out once the deadline is reached", async () => {
    const path = writeJsonl("deadline.jsonl", [claudeUser("needle")]);
    await expect(
      searchTranscriptFile("claude", path, "needle", { deadline: 100, now: () => 100 }),
    ).resolves.toEqual({ status: "timeout" });
    await expect(
      searchTranscriptFile("claude", path, "needle", { deadline: 100, now: () => 99 }),
    ).resolves.toMatchObject({ status: "match" });
  });

  it("walks newest first and keeps order with metadata and content matches", async () => {
    const sessions = Array.from({ length: 6 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: i === 3 ? "needle in prompt" : `prompt ${i}`,
      path: writeJsonl(`s${i}.jsonl`, [
        claudeUser(i % 2 === 0 ? "contains needle" : "nothing"),
      ]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 10,
      transcriptPaths: (session) => [session.path],
      concurrency: 2,
    });
    expect(result.matches.map((m) => [m.session.sessionId, m.searchMatch.field])).toEqual([
      ["s0", "content"],
      ["s2", "content"],
      ["s3", "firstPrompt"],
      ["s4", "content"],
    ]);
    expect(result.matches[0].searchMatch.snippet).toBe("contains needle");
    expect(result.incomplete).toBe(false);
    // The metadata match does not read its transcript.
    expect(result.filesRead).toBe(5);
  });

  it("stops once enough matches are found", async () => {
    const sessions = Array.from({ length: 10 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: "",
      path: writeJsonl(`n${i}.jsonl`, [claudeUser("needle")]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 2,
      transcriptPaths: (session) => [session.path],
      concurrency: 1,
    });
    expect(result.matches.map((m) => m.session.sessionId)).toEqual(["s0", "s1"]);
    expect(result.filesRead).toBe(2);
    expect(result.incomplete).toBe(false);
  });

  it("reports incomplete when the file bound is hit", async () => {
    const sessions = Array.from({ length: 5 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: "",
      path: writeJsonl(`b${i}.jsonl`, [claudeUser(i === 4 ? "needle" : "miss")]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 5,
      transcriptPaths: (session) => [session.path],
      maxFiles: 3,
    });
    expect(result.matches).toEqual([]);
    expect(result.filesRead).toBe(3);
    expect(result.incomplete).toBe(true);
  });

  it("reports incomplete when the time budget is exhausted", async () => {
    let clock = 0;
    const sessions = Array.from({ length: 3 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: "",
      path: writeJsonl(`c${i}.jsonl`, [claudeUser("needle")]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 3,
      transcriptPaths: (session) => {
        clock += 1000;
        return [session.path];
      },
      budgetMs: 1500,
      concurrency: 1,
      now: () => clock,
    });
    expect(result.matches.map((m) => m.session.sessionId)).toEqual(["s0"]);
    expect(result.incomplete).toBe(true);
  });

  it("reads nothing when the budget is already spent", async () => {
    const result = await searchRecentSessionContent(
      [
        { provider: "claude" as const, firstPrompt: "needle in metadata", path: "" },
        {
          provider: "claude" as const,
          firstPrompt: "",
          path: writeJsonl("z.jsonl", [claudeUser("needle")]),
        },
      ],
      {
        query: "needle",
        needed: 2,
        transcriptPaths: (session) => [session.path],
        budgetMs: 0,
        now: () => 0,
      },
    );
    expect(result).toEqual({ matches: [], incomplete: true, filesRead: 0 });
  });

  it("reports incomplete when the last transcript read times out", async () => {
    // The clock passes the deadline only once the transcript is being read.
    let calls = 0;
    const result = await searchRecentSessionContent(
      [
        {
          provider: "claude" as const,
          firstPrompt: "",
          path: writeJsonl("slow.jsonl", [claudeUser("needle")]),
        },
      ],
      {
        query: "needle",
        needed: 1,
        transcriptPaths: (session) => [session.path],
        budgetMs: 10,
        now: () => (calls++ < 2 ? 0 : 100),
      },
    );
    expect(result).toEqual({ matches: [], incomplete: true, filesRead: 1 });
  });

  it("returns only the needed matches from a parallel batch", async () => {
    const sessions = Array.from({ length: 3 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: "",
      path: writeJsonl(`p${i}.jsonl`, [claudeUser("needle")]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 1,
      transcriptPaths: (session) => [session.path],
      concurrency: 3,
    });
    expect(result.matches.map((m) => m.session.sessionId)).toEqual(["s0"]);
    expect(result.filesRead).toBe(3);
    expect(result.incomplete).toBe(false);
  });

  it("is complete when the needed matches are found right at the file bound", async () => {
    const sessions = Array.from({ length: 3 }, (_, i) => ({
      provider: "claude" as const,
      sessionId: `s${i}`,
      firstPrompt: "",
      path: writeJsonl(`f${i}.jsonl`, [claudeUser("needle")]),
    }));
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 2,
      transcriptPaths: (session) => [session.path],
      maxFiles: 2,
    });
    expect(result.matches.map((m) => m.session.sessionId)).toEqual(["s0", "s1"]);
    expect(result).toMatchObject({ incomplete: false, filesRead: 2 });
  });

  it("searches every transcript of a session and skips sessions without one", async () => {
    const sessions = [
      { provider: "claude" as const, sessionId: "none", firstPrompt: "", paths: [] },
      {
        provider: "claude" as const,
        sessionId: "two",
        firstPrompt: "",
        paths: [
          writeJsonl("m0.jsonl", [claudeUser("miss")]),
          writeJsonl("m1.jsonl", [claudeUser("second file needle")]),
        ],
      },
    ];
    const result = await searchRecentSessionContent(sessions, {
      query: "needle",
      needed: 5,
      transcriptPaths: (session) => session.paths,
    });
    expect(result).toEqual({
      matches: [
        {
          session: sessions[1],
          searchMatch: { field: "content", snippet: "second file needle" },
        },
      ],
      incomplete: false,
      filesRead: 2,
    });
  });

  it("is complete when every session was checked", async () => {
    const result = await searchRecentSessionContent(
      [{ provider: "claude" as const, firstPrompt: "", path: join(dir, "none") }],
      {
        query: "needle",
        needed: 1,
        transcriptPaths: (session) => [session.path],
      },
    );
    expect(result).toEqual({ matches: [], incomplete: false, filesRead: 1 });
  });
});

describe("searchTranscriptFile byte scan", () => {
  let dir: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "ccpocket-bytescan-"));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  const userLine = (text: string) =>
    JSON.stringify({
      type: "event_msg",
      payload: { type: "user_message", message: text },
    });

  it("matches ASCII case-insensitively and Japanese exactly", async () => {
    const path = join(dir, "a.jsonl");
    writeFileSync(path, `${userLine("Fixed the iPhone クラッシュ")}\n`);
    expect((await searchTranscriptFile("codex", path, "IPHONE")).status).toBe("match");
    expect((await searchTranscriptFile("codex", path, "クラッシュ")).status).toBe("match");
    expect((await searchTranscriptFile("codex", path, "android")).status).toBe("no_match");
  });

  it("finds a match in a line that spans read chunks", async () => {
    const path = join(dir, "big.jsonl");
    const filler = "x".repeat(4 * 1024 * 1024 - 20);
    writeFileSync(
      path,
      [
        JSON.stringify({ type: "event_msg", payload: { type: "token_count", details: filler } }),
        userLine(`${"y".repeat(4 * 1024 * 1024)} boundary-needle`),
        "",
      ].join("\n"),
    );
    const result = await searchTranscriptFile("codex", path, "boundary-needle");
    expect(result.status).toBe("match");
  });

  it("matches the last line without a trailing newline", async () => {
    const path = join(dir, "c.jsonl");
    writeFileSync(path, `${userLine("first")}\n${userLine("tail needle")}`);
    expect((await searchTranscriptFile("codex", path, "needle")).status).toBe("match");
  });

  it("treats regex characters in the query literally", async () => {
    const path = join(dir, "d.jsonl");
    writeFileSync(path, `${userLine("compute (a+b) now")}\n`);
    expect((await searchTranscriptFile("codex", path, "(a+b)")).status).toBe("match");
    expect((await searchTranscriptFile("codex", path, "a.b")).status).toBe("no_match");
  });
});
