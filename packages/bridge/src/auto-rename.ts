import { execFile } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, win32 } from "node:path";
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

/** Opening line of a fenced code block: the fence plus an optional language tag. */
const CODE_FENCE_OPEN_RE = /^(`{3,}|~{3,})[\w+.#-]*$/;
/** Closing line of a fenced code block: the fence alone. */
const CODE_FENCE_CLOSE_RE = /^(`{3,}|~{3,})$/;

/** Index of the last non-blank line, or -1 when every line is blank. */
function lastNonEmptyIndex(lines: readonly string[]): number {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    if (lines[index]) return index;
  }
  return -1;
}

/**
 * Drops a markdown code fence that wraps the whole answer.
 *
 * The prompt forbids markdown, but a model may still answer with a fenced
 * block: either three lines (open / name / close) or one line holding all
 * three. Both shapes must unwrap to the bare name; only the single-line shape
 * was handled before, and it also swallowed the name's first word as a
 * language tag.
 */
function unwrapCodeFence(output: string): string {
  // Blank lines stay in the list. Removing them early turns an opening fence
  // with no body (`` ```text `` and then blank lines) into a one-line answer,
  // which would hand the language tag back as the name.
  const lines = output.split("\n").map((part) => part.trim());
  const first = lines.findIndex(Boolean);
  if (first === -1) return "";
  const last = lastNonEmptyIndex(lines);

  // A single-line fence such as ```Name``` is not an opening line; it is
  // unwrapped later together with the rest of the name line.
  const opening = CODE_FENCE_OPEN_RE.exec(lines[first]);
  if (!opening) return lines.slice(first, last + 1).join("\n");

  const fence = opening[1];
  const closing = CODE_FENCE_CLOSE_RE.exec(lines[last]);
  const closed = closing !== null && closing[1] === fence;
  // An unterminated fence still drops its opening line, which carries the
  // language tag as well as the backticks. A fence with no body unwraps to
  // nothing, so the tag is never returned as the name.
  return lines.slice(first + 1, closed ? last : undefined).join("\n");
}

export function sanitizeAutoRenameName(output: string): string | null {
  const line = unwrapCodeFence(output)
    .split("\n")
    .map((part) => part.trim())
    .find(Boolean);
  if (!line) return null;

  let name = line
    .replace(/^(`{3,}|~{3,})\s*/, "")
    .replace(/\s*(`{3,}|~{3,})$/, "")
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

/** Upper bound for a single auto-rename CLI invocation. */
export const AUTO_RENAME_TIMEOUT_MS = 45_000;

export async function generateAutoRenameName(
  options: AutoRenameOptions,
): Promise<string | null> {
  const cwd = resolve(options.projectPath);
  const prompt = buildAutoRenamePrompt(options.transcript);
  const output =
    options.provider === "codex"
      ? await runCodexAutoRename(cwd, prompt)
      : await runCli(
          "claude",
          ["-p", ...(options.model ? ["--model", options.model] : []), prompt],
          cwd,
        );
  return sanitizeAutoRenameName(output);
}

/**
 * Run a CLI asynchronously so a slow or stalled helper never blocks the
 * Bridge event loop. The child is killed once AUTO_RENAME_TIMEOUT_MS elapses.
 */
function runCli(
  command: string,
  args: string[],
  cwd: string,
  input?: string,
): Promise<string> {
  return new Promise((resolvePromise, reject) => {
    const child = execFile(
      command,
      args,
      {
        cwd,
        encoding: "utf-8",
        maxBuffer: 1024 * 1024,
        timeout: AUTO_RENAME_TIMEOUT_MS,
        killSignal: "SIGKILL",
        windowsHide: true,
      },
      (err, stdout) => {
        if (err) {
          reject(err);
          return;
        }
        resolvePromise(stdout);
      },
    );
    if (child.stdin) {
      child.stdin.on("error", () => {
        // The child may exit before consuming stdin; the exec callback
        // reports the real failure.
      });
      child.stdin.end(input ?? "");
    }
  });
}

async function runCodexAutoRename(
  cwd: string,
  prompt: string,
): Promise<string> {
  const outputDir = mkdtempSync(join(tmpdir(), "ccpocket-auto-rename-"));
  const outputPath = join(outputDir, "session-name.txt");

  try {
    const cli = resolveCodexAutoRenameCommand(
      [
        "exec",
        "--skip-git-repo-check",
        "-m",
        getCodexAssistModel(),
        "-c",
        getCodexAssistReasoningConfig(),
        "-o",
        outputPath,
        "-",
      ],
      cwd,
    );
    await runCli(cli.command, cli.args, cwd, prompt);
    return readFileSync(outputPath, "utf-8");
  } finally {
    rmSync(outputDir, { recursive: true, force: true });
  }
}

export function resolveCodexAutoRenameCommand(
  args: string[],
  cwd: string,
  platform = process.platform,
  searchPath = process.env.PATH ?? "",
): { command: string; args: string[] } {
  if (platform === "win32") {
    // Windows resolves relative PATH entries from the child's working directory.
    for (const entry of [cwd, ...searchPath.split(";")]) {
      const dir = win32.resolve(cwd, entry.trim().replace(/^"(.*)"$/, "$1"));
      const executable = win32.join(dir, "codex.exe");
      if (existsSync(executable)) return { command: executable, args };
      const script = win32.join(
        dir, "node_modules", "@openai", "codex", "bin", "codex.js",
      );
      if (existsSync(win32.join(dir, "codex.cmd")) && existsSync(script)) {
        // execFile cannot execute npm's .cmd shim. Use its JS entry point
        // with the current Node runtime, keeping arguments out of a shell.
        return { command: process.execPath, args: [script, ...args] };
      }
    }
  }
  return { command: "codex", args };
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
