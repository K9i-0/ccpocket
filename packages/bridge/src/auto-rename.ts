import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import type { Provider, ServerMessage } from "./parser.js";
import {
  CODEX_ASSIST_MODEL,
  CODEX_ASSIST_REASONING_EFFORT,
} from "./codex-assist.js";

export const AUTO_RENAME_PROMPT_PREFIX =
  "Write a concise name for this coding-agent session.";

const AUTO_RENAME_PROMPT = `${AUTO_RENAME_PROMPT_PREFIX}

Rules:
- Output only the name. No quotes, JSON, markdown, or explanation.
- Use the same language as the user's request when natural.
- Prefer the user's actual goal over implementation details.
- Use assistant text only to disambiguate the goal or target area.
- Keep it short: 2-8 English words or about 8-24 Japanese/Chinese/Korean characters.
- Avoid generic words such as Session, Chat, Task, Discussion.
- Avoid trailing punctuation.`;

const MAX_TRANSCRIPT_CHARS = 2400;
const MAX_ASSISTANT_CHARS = 1200;
const MAX_NAME_CHARS = 60;

export interface AutoRenameTranscript {
  userText: string;
  assistantText?: string;
}

export interface AutoRenameOptions {
  provider: Provider;
  projectPath: string;
  model?: string;
  transcript: AutoRenameTranscript;
}

export function buildAutoRenameTranscript(
  history: readonly ServerMessage[],
): AutoRenameTranscript | null {
  const userText = history
    .filter((msg) => msg.type === "user_input")
    .map((msg) => msg.text.trim())
    .find(Boolean);
  if (!userText) return null;

  const assistantText = history
    .filter((msg) => msg.type === "assistant")
    .map((msg) =>
      msg.message.content
        .filter((content) => content.type === "text")
        .map((content) => ("text" in content ? content.text : ""))
        .join("\n")
        .trim(),
    )
    .find(Boolean);

  return {
    userText: limitText(userText, MAX_TRANSCRIPT_CHARS),
    ...(assistantText
      ? { assistantText: limitText(assistantText, MAX_ASSISTANT_CHARS) }
      : {}),
  };
}

export function buildAutoRenamePrompt(
  transcript: AutoRenameTranscript,
): string {
  const sections = [`USER:\n${transcript.userText}`];
  if (transcript.assistantText) {
    sections.push(`ASSISTANT:\n${transcript.assistantText}`);
  }
  return `${AUTO_RENAME_PROMPT}\n\nTranscript:\n${sections.join("\n\n")}`;
}

export function isAutoRenamePromptText(text: string): boolean {
  return text.trimStart().startsWith(AUTO_RENAME_PROMPT_PREFIX);
}

export function sanitizeAutoRenameName(output: string): string | null {
  const line = output
    .split("\n")
    .map((part) => part.trim())
    .find(Boolean);
  if (!line) return null;

  let name = line
    .replace(/^```(?:\w+)?\s*/, "")
    .replace(/\s*```$/, "")
    .trim();
  name = stripWrapping(name, '"');
  name = stripWrapping(name, "'");
  name = stripWrapping(name, "`");
  name = stripWrapping(name, "「", "」");
  name = stripWrapping(name, "『", "』");
  name = name
    .replace(/^[-*#\s]+/, "")
    .replace(/[。．.!！?？、,，:：;；]+$/u, "")
    .replace(/\s+/g, " ")
    .trim();

  if (!name) return null;
  if (/^[{[]/.test(name)) return null;
  if (/^name\s*[:=]/i.test(name)) return null;

  const chars = Array.from(name);
  if (chars.length > MAX_NAME_CHARS) {
    name = chars.slice(0, MAX_NAME_CHARS).join("").trim();
  }
  return name || null;
}

export function generateAutoRenameName(
  options: AutoRenameOptions,
): string | null {
  const cwd = resolve(options.projectPath);
  const prompt = buildAutoRenamePrompt(options.transcript);
  const output =
    options.provider === "codex"
      ? runCodexAutoRename(cwd, prompt)
      : execFileSync(
          "claude",
          ["-p", ...(options.model ? ["--model", options.model] : []), prompt],
          {
            cwd,
            encoding: "utf-8",
            maxBuffer: 1024 * 1024,
          },
        );
  return sanitizeAutoRenameName(output);
}

function runCodexAutoRename(cwd: string, prompt: string): string {
  const outputDir = mkdtempSync(join(tmpdir(), "ccpocket-auto-rename-"));
  const outputPath = join(outputDir, "session-name.txt");

  try {
    execFileSync(
      "codex",
      [
        "exec",
        "-m",
        CODEX_ASSIST_MODEL,
        "-c",
        `model_reasoning_effort="${CODEX_ASSIST_REASONING_EFFORT}"`,
        "-o",
        outputPath,
        "-",
      ],
      {
        cwd,
        encoding: "utf-8",
        input: prompt,
        maxBuffer: 1024 * 1024,
      },
    );
    return readFileSync(outputPath, "utf-8");
  } finally {
    rmSync(outputDir, { recursive: true, force: true });
  }
}

function limitText(text: string, maxChars: number): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  const chars = Array.from(normalized);
  if (chars.length <= maxChars) return normalized;
  return `${chars.slice(0, maxChars).join("").trim()}...`;
}

function stripWrapping(
  value: string,
  open: string,
  close: string = open,
): string {
  if (value.startsWith(open) && value.endsWith(close)) {
    return value.slice(open.length, value.length - close.length).trim();
  }
  return value;
}
