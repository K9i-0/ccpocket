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
