import { mkdir, readdir, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { Provider } from "./parser.js";
import type {
  SessionHistoryContentItem,
  SessionHistoryMessage,
} from "./sessions-index.js";

/**
 * Text of a session handoff: the prompt that asks the source agent for a
 * note, the first prompt of the target session, and the transcript file the
 * target can read on demand. See docs/session-handoff.md.
 */

/** First characters of every handoff prompt. The app keys its card on it. */
export const HANDOFF_MARKER = "[ccpocket handoff";

const NOTE_LIMIT = 12_000;
const RECENT_TOTAL_LIMIT = 12_000;
const RECENT_MESSAGE_LIMIT = 2_000;
const ORIGINAL_REQUEST_LIMIT = 2_000;
const INSTRUCTION_LIMIT = 4_000;
const TRANSCRIPT_ITEM_LIMIT = 4_000;
const TRANSCRIPT_RETENTION_MS = 30 * 24 * 60 * 60_000;

export function handoffAgentName(provider: Provider): string {
  switch (provider) {
    case "codex":
      return "Codex";
    case "antigravity":
      return "Antigravity";
    default:
      return "Claude Code";
  }
}

function truncate(text: string, limit: number): string {
  if (text.length <= limit) return text;
  const omitted = text.length - limit;
  return `${text.slice(0, limit)}\n… (${omitted} more characters omitted)`;
}

function contentItems(
  content: SessionHistoryMessage["content"],
): SessionHistoryContentItem[] {
  if (typeof content === "string") return [{ type: "text", text: content }];
  return Array.isArray(content) ? content : [];
}

/** The prose of a message: text blocks only, no thinking and no tool calls. */
export function handoffMessageText(message: SessionHistoryMessage): string {
  return contentItems(message.content)
    .filter((item) => item.type === "text" && typeof item.text === "string")
    .map((item) => item.text as string)
    .join("\n")
    .trim();
}

function isConversationMessage(message: SessionHistoryMessage): boolean {
  if (message.role !== "user" && message.role !== "assistant") return false;
  if (message.isMeta === true) return false;
  return handoffMessageText(message).length > 0;
}

/** Prompt sent to the source agent to make it write the handoff note. */
export function buildHandoffNoteRequest(target: Provider): string {
  const name = handoffAgentName(target);
  return [
    `${HANDOFF_MARKER}] This session is being handed over to ${name}, another coding agent. It continues in the same working directory, and this session stops after your reply.`,
    "",
    `Write a handoff note for ${name}. Do not use tools and do not change files; write from what you already know. Cover:`,
    "- the goal, and the user's requirements and preferences",
    "- what is done, with the files that changed",
    "- what is in progress or left half-finished",
    "- what remains, in order",
    "- decisions made and why, and approaches that failed",
    "- how to build, run and verify the work",
    "",
    "Reply with the note only, in the language the user has been using.",
  ].join("\n");
}

export interface HandoffPromptInput {
  source: Provider;
  target: Provider;
  /** Conversation of the source session, without the note request. */
  history: readonly SessionHistoryMessage[];
  /** Note written by the source agent, when it could write one. */
  note?: string;
  /** What the user wants the target to do; defaults to "continue". */
  instruction?: string;
  /** Saved full transcript, when writing it succeeded. */
  transcriptPath?: string;
}

/** First prompt of the target session. */
export function buildHandoffPrompt(input: HandoffPromptInput): string {
  const sourceName = handoffAgentName(input.source);
  const targetName = handoffAgentName(input.target);
  const conversation = input.history.filter(isConversationMessage);
  const lines: string[] = [
    `${HANDOFF_MARKER}: ${sourceName} → ${targetName}]`,
    "",
    `You are taking over a task from another coding agent (${sourceName}). That session has been stopped. You work in the same directory, so every change it made is already on disk. Do not start over.`,
    "",
    "## What to do now",
    "",
    input.instruction?.trim()
      ? truncate(input.instruction.trim(), INSTRUCTION_LIMIT)
      : "Continue the task from where the previous agent stopped. If the next step is not clear from the context below, say what you understand and ask.",
    "",
    "Check the working tree yourself before you act (for example `git status` and `git diff`). The previous agent may have stopped in the middle of an edit, and the context below may not mention everything.",
  ];

  const note = input.note?.trim();
  if (note) {
    lines.push(
      "",
      `## Handoff note from ${sourceName}`,
      "",
      truncate(note, NOTE_LIMIT),
    );
  }

  // Newest first until the budget is used, then restored to reading order.
  const recent: SessionHistoryMessage[] = [];
  let used = 0;
  for (let index = conversation.length - 1; index >= 0; index -= 1) {
    const message = conversation[index];
    const length = Math.min(
      handoffMessageText(message).length,
      RECENT_MESSAGE_LIMIT,
    );
    if (recent.length > 0 && used + length > RECENT_TOTAL_LIMIT) break;
    recent.unshift(message);
    used += length;
  }

  const firstUser = conversation.find((message) => message.role === "user");
  if (firstUser && !recent.includes(firstUser)) {
    lines.push(
      "",
      "## Original request",
      "",
      truncate(handoffMessageText(firstUser), ORIGINAL_REQUEST_LIMIT),
    );
  }

  if (recent.length > 0) {
    lines.push(
      "",
      "## Recent conversation",
      "",
      recent.length < conversation.length
        ? `The last ${recent.length} of ${conversation.length} messages, oldest first. Tool calls are left out and long messages are shortened.`
        : "The whole conversation, oldest first. Tool calls are left out and long messages are shortened.",
    );
    for (const message of recent) {
      lines.push(
        "",
        `### ${message.role === "user" ? "User" : sourceName}`,
        "",
        truncate(handoffMessageText(message), RECENT_MESSAGE_LIMIT),
      );
    }
  } else if (!note) {
    lines.push(
      "",
      "No earlier conversation could be read from the previous session.",
    );
  }

  if (input.transcriptPath) {
    lines.push(
      "",
      "## Full transcript",
      "",
      "The whole conversation, including tool calls and their results, is saved here:",
      "",
      input.transcriptPath,
      "",
      "Read it when you need a detail that is not above.",
    );
  }
  return lines.join("\n");
}

function transcriptBlock(label: string, body: string): string[] {
  return ["", `### ${label}`, "", truncate(body, TRANSCRIPT_ITEM_LIMIT)];
}

/** Markdown of the whole conversation, for the target to read on demand. */
export function renderHandoffTranscript(
  source: Provider,
  history: readonly SessionHistoryMessage[],
): string {
  const sourceName = handoffAgentName(source);
  const lines: string[] = [
    `# ${sourceName} session transcript`,
    "",
    "Saved by ccpocket for a session handoff. Thinking is left out and long tool input and output are shortened.",
  ];
  for (const message of history) {
    if (message.role === "compaction") {
      const summary = message.compaction?.summary?.trim();
      lines.push(
        ...transcriptBlock(
          "Context compaction",
          summary || "Earlier context was compacted here.",
        ),
      );
      continue;
    }
    if (message.role === "recap") {
      const recap = message.recap?.content?.trim();
      if (recap) lines.push(...transcriptBlock("Recap", recap));
      continue;
    }
    if (message.role === "tool_result") {
      const text = handoffMessageText(message);
      lines.push(
        ...transcriptBlock(
          `Tool result${message.toolName ? `: ${message.toolName}` : ""}`,
          text || "(no text output)",
        ),
      );
      continue;
    }
    if (message.isMeta === true) continue;
    const label = message.role === "user" ? "User" : sourceName;
    for (const item of contentItems(message.content)) {
      if (item.type === "text" && item.text?.trim()) {
        lines.push(...transcriptBlock(label, item.text.trim()));
      } else if (item.type === "tool_use") {
        let input = "";
        try {
          input = JSON.stringify(item.input ?? {}, null, 2);
        } catch {
          input = "(input could not be shown)";
        }
        lines.push(
          ...transcriptBlock(`Tool call: ${item.name ?? "unknown"}`, input),
        );
      }
    }
  }
  return `${lines.join("\n")}\n`;
}

export function handoffTranscriptDir(): string {
  return join(homedir(), ".ccpocket", "handoffs");
}

/**
 * Save the transcript and return its path. Files older than 30 days are
 * removed on the way; they only matter while the target session is in use.
 */
export async function writeHandoffTranscript(options: {
  source: Provider;
  target: Provider;
  history: readonly SessionHistoryMessage[];
  dir?: string;
  now?: Date;
}): Promise<string> {
  const dir = options.dir ?? handoffTranscriptDir();
  const now = options.now ?? new Date();
  await mkdir(dir, { recursive: true, mode: 0o700 });
  await pruneHandoffTranscripts(dir, now);
  const stamp = now.toISOString().replace(/[:.]/g, "-");
  const suffix = Math.random().toString(36).slice(2, 8);
  const path = join(
    dir,
    `${stamp}-${options.source}-to-${options.target}-${suffix}.md`,
  );
  await writeFile(path, renderHandoffTranscript(options.source, options.history), {
    encoding: "utf8",
    mode: 0o600,
  });
  return path;
}

async function pruneHandoffTranscripts(dir: string, now: Date): Promise<void> {
  let names: string[];
  try {
    names = await readdir(dir);
  } catch {
    return;
  }
  await Promise.all(
    names
      .filter((name) => name.endsWith(".md"))
      .map(async (name) => {
        const path = join(dir, name);
        try {
          const info = await stat(path);
          if (now.getTime() - info.mtimeMs > TRANSCRIPT_RETENTION_MS) {
            await unlink(path);
          }
        } catch {
          // Another handoff may have removed it already.
        }
      }),
  );
}
