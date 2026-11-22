import { mkdtempSync, readdirSync, readFileSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  HANDOFF_MARKER,
  buildHandoffNoteRequest,
  buildHandoffPrompt,
  handoffSessionTitle,
  renderHandoffTranscript,
  writeHandoffTranscript,
} from "./session-handoff.js";
import type { SessionHistoryMessage } from "./sessions-index.js";

const user = (text: string): SessionHistoryMessage => ({
  role: "user",
  content: [{ type: "text", text }],
});
const assistant = (text: string): SessionHistoryMessage => ({
  role: "assistant",
  content: [{ type: "text", text }],
});

describe("buildHandoffNoteRequest", () => {
  it("names the target and forbids tools", () => {
    const text = buildHandoffNoteRequest("antigravity");
    expect(text.startsWith(HANDOFF_MARKER)).toBe(true);
    expect(text).toContain("handed over to Antigravity");
    expect(text).toContain("Do not use tools");
  });
});

describe("buildHandoffPrompt", () => {
  it("starts with the marker and names both agents", () => {
    const prompt = buildHandoffPrompt({
      source: "claude",
      target: "codex",
      history: [user("Add a login form"), assistant("Done with the markup.")],
      note: "Markup is done; validation remains.",
      transcriptPath: "/tmp/handoffs/t.md",
    });
    expect(prompt.split("\n")[0]).toBe("[ccpocket handoff: Claude Code → Codex]");
    expect(prompt).toContain("## Handoff note from Claude Code");
    expect(prompt).toContain("Markup is done; validation remains.");
    expect(prompt).toContain("### User\n\nAdd a login form");
    expect(prompt).toContain("### Claude Code\n\nDone with the markup.");
    expect(prompt).toContain("/tmp/handoffs/t.md");
    expect(prompt).toContain("Continue the task from where the previous agent stopped.");
    expect(prompt).toContain("git status");
    // The first request is already in the recent conversation.
    expect(prompt).not.toContain("## Original request");
  });

  it("uses the user's instruction instead of the default", () => {
    const prompt = buildHandoffPrompt({
      source: "codex",
      target: "antigravity",
      history: [user("hi")],
      instruction: "  Only polish the README.  ",
    });
    expect(prompt).toContain("## What to do now\n\nOnly polish the README.\n");
    expect(prompt).not.toContain("Continue the task from where");
  });

  it("works without a note, a transcript or any history", () => {
    const prompt = buildHandoffPrompt({
      source: "antigravity",
      target: "claude",
      history: [],
    });
    expect(prompt).not.toContain("## Handoff note");
    expect(prompt).not.toContain("## Full transcript");
    expect(prompt).toContain("No earlier conversation could be read");
  });

  it("leaves out tool calls, thinking, meta prompts and empty messages", () => {
    const prompt = buildHandoffPrompt({
      source: "claude",
      target: "codex",
      history: [
        user("real request"),
        { role: "user", isMeta: true, content: [{ type: "text", text: "skill body" }] },
        {
          role: "assistant",
          content: [
            { type: "thinking", thinking: "secret reasoning" },
            { type: "tool_use", id: "t1", name: "Bash", input: { command: "ls" } },
          ],
        },
        { role: "tool_result", toolUseId: "t1", content: "file-listing" },
        assistant("final answer"),
      ],
    });
    expect(prompt).toContain("real request");
    expect(prompt).toContain("final answer");
    expect(prompt).not.toContain("skill body");
    expect(prompt).not.toContain("secret reasoning");
    expect(prompt).not.toContain("file-listing");
    expect(prompt).toContain("The whole conversation, oldest first.");
  });

  it("keeps the newest messages within the budget and the first request", () => {
    const history: SessionHistoryMessage[] = [user("ORIGINAL-REQUEST")];
    for (let i = 0; i < 20; i += 1) {
      history.push(assistant(`reply-${i} ${"x".repeat(3000)}`));
      history.push(user(`follow-up-${i}`));
    }
    const prompt = buildHandoffPrompt({ source: "claude", target: "codex", history });
    expect(prompt).toContain("## Original request\n\nORIGINAL-REQUEST");
    expect(prompt).toContain("follow-up-19");
    expect(prompt).toContain("reply-19");
    expect(prompt).not.toContain("reply-0 ");
    expect(prompt).toMatch(/The last \d+ of 41 messages/);
    expect(prompt).toContain("more characters omitted");
    expect(prompt.length).toBeLessThan(20_000);
  });

  it("always includes the latest message even when it exceeds the budget", () => {
    const prompt = buildHandoffPrompt({
      source: "claude",
      target: "codex",
      history: [user("first"), assistant("y".repeat(50_000))],
    });
    expect(prompt).toContain("### Claude Code");
    expect(prompt.length).toBeLessThan(6_000);
  });

  it("does not repeat an earlier handoff prompt when there is a note", () => {
    const earlier = buildHandoffPrompt({
      source: "claude",
      target: "codex",
      history: [user("ORIGINAL"), assistant("first agent reply")],
      note: "EARLIER-NOTE",
    });
    const history = [user(earlier), assistant("second agent reply")];

    const withNote = buildHandoffPrompt({
      source: "codex",
      target: "antigravity",
      history,
      note: "LATER-NOTE",
    });
    expect(withNote).toContain("LATER-NOTE");
    expect(withNote).not.toContain("EARLIER-NOTE");
    expect(withNote).toContain("Codex itself took this task over");
    expect(withNote).toContain("second agent reply");
    expect(withNote).not.toContain("## Original request");

    const withoutNote = buildHandoffPrompt({
      source: "codex",
      target: "antigravity",
      history,
    });
    expect(withoutNote).toContain("EARLIER-NOTE");
    expect(handoffSessionTitle(history)).toBeUndefined();
  });

  it("caps a very long note", () => {
    const prompt = buildHandoffPrompt({
      source: "claude",
      target: "codex",
      history: [],
      note: "n".repeat(40_000),
    });
    expect(prompt.length).toBeLessThan(14_000);
    expect(prompt).toContain("more characters omitted");
  });
});

describe("handoffSessionTitle", () => {
  it("uses the first line of the first request", () => {
    expect(
      handoffSessionTitle([
        { role: "user", isMeta: true, content: "meta" },
        user("\n  Add a login form\nwith validation"),
        user("second"),
      ]),
    ).toBe("Add a login form");
    expect(handoffSessionTitle([user("t".repeat(100))])).toBe(`${"t".repeat(60)}…`);
    expect(handoffSessionTitle([assistant("only the agent")])).toBeUndefined();
  });
});

describe("renderHandoffTranscript", () => {
  it("renders text, tool calls, tool results and compaction", () => {
    const text = renderHandoffTranscript("codex", [
      user("do it"),
      {
        role: "assistant",
        content: [
          { type: "thinking", thinking: "hidden" },
          { type: "text", text: "running" },
          { type: "tool_use", id: "t1", name: "shell", input: { command: "ls" } },
        ],
      },
      { role: "tool_result", toolUseId: "t1", toolName: "shell", content: "a.txt" },
      { role: "compaction", compaction: { summary: "earlier work" }, content: "" },
      { role: "user", isMeta: true, content: "meta" },
    ]);
    expect(text).toContain("# Codex session transcript");
    expect(text).toContain("### User\n\ndo it");
    expect(text).toContain("### Codex\n\nrunning");
    expect(text).toContain('### Tool call: shell\n\n{\n  "command": "ls"\n}');
    expect(text).toContain("### Tool result: shell\n\na.txt");
    expect(text).toContain("### Context compaction\n\nearlier work");
    expect(text).not.toContain("hidden");
    expect(text).not.toContain("meta");
  });

  it("shortens long tool output", () => {
    const text = renderHandoffTranscript("claude", [
      { role: "tool_result", toolUseId: "t", content: "z".repeat(10_000) },
    ]);
    expect(text.length).toBeLessThan(5_000);
  });
});

describe("writeHandoffTranscript", () => {
  let dir: string;
  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "handoff-test-"));
  });
  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("writes the transcript and removes files older than 30 days", async () => {
    const now = new Date("2026-11-22T10:00:00.000Z");
    const old = join(dir, "old.md");
    const fresh = join(dir, "fresh.md");
    const other = join(dir, "keep.txt");
    for (const path of [old, fresh, other]) writeFileSync(path, "x");
    const longAgo = new Date(now.getTime() - 31 * 24 * 60 * 60_000);
    utimesSync(old, longAgo, longAgo);
    utimesSync(other, longAgo, longAgo);
    utimesSync(fresh, now, now);

    const path = await writeHandoffTranscript({
      source: "claude",
      target: "codex",
      history: [user("hello")],
      dir,
      now,
    });

    expect(path.startsWith(join(dir, "2026-11-22T10-00-00-000Z-claude-to-codex-"))).toBe(true);
    expect(readFileSync(path, "utf8")).toContain("### User\n\nhello");
    const names = readdirSync(dir);
    expect(names).not.toContain("old.md");
    expect(names).toContain("fresh.md");
    expect(names).toContain("keep.txt");
  });
});
