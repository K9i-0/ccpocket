import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import type { Provider, ServerMessage } from "./parser.js";
import {
  getCodexAssistModel,
  getCodexAssistReasoningConfig,
} from "./codex-assist.js";

export const AUTO_RENAME_PROMPT_PREFIX =
  "Write a concise name for this coding-agent session.";

const AUTO_RENAME_PROMPT = `${AUTO_RENAME_PROMPT_PREFIX}

Rules:
- Output only the name. No quotes, JSON, markdown, or explanation.
- Match the primary language of the USER text. Never translate it. If USER is Japanese, the name must be Japanese.
- Write a natural, specific noun phrase rather than a sentence or a list of keywords.
- Prefer the user's intended outcome over implementation details.
- Use only the USER text to choose the name's language and subject.
- Keep it short: 2-8 English words or about 6-20 Japanese/Chinese/Korean characters when practical.
- For Japanese, use particles such as の when they improve readability; avoid unnatural keyword concatenation.
- Preserve meaningful product, library, and feature names.
- Avoid generic words such as Session, Chat, Task, Discussion, 作業, タスク, or 対応.
- Avoid trailing punctuation.`;

const AUTO_RENAME_PROMPT_SIGNATURE = `${AUTO_RENAME_PROMPT_PREFIX}

Rules:
- Output only the name. No quotes, JSON, markdown, or explanation.`;

const MAX_TRANSCRIPT_CHARS = 2400;
const MAX_NAME_CHARS = 60;

export interface AutoRenameTranscript {
  userText: string;
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

  return {
    userText: limitText(userText, MAX_TRANSCRIPT_CHARS),
  };
}

export function buildAutoRenamePrompt(
  transcript: AutoRenameTranscript,
): string {
  return `${AUTO_RENAME_PROMPT}\n\nUSER:\n${transcript.userText}`;
}

export function isAutoRenamePromptText(text: string): boolean {
  return text.trimStart().startsWith(AUTO_RENAME_PROMPT_SIGNATURE);
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
        getCodexAssistModel(),
        "-c",
        getCodexAssistReasoningConfig(),
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
