/**
 * Convert skill triggers between Claude (`/name`) and Codex (`$name`).
 *
 * The mobile app converts chat input before sending it. The initial prompt of
 * a new session is sent before the app knows the session's skills, so the
 * Bridge applies the same rules here. Keep the rules in sync with
 * `apps/mobile/lib/utils/skill_invocation.dart`.
 */

export type SkillTriggerProvider = "claude" | "codex";

export interface SkillTriggerCatalog {
  provider: SkillTriggerProvider;
  /** Skill name -> SKILL.md path (Codex only; empty for Claude). */
  skills: Map<string, string>;
}

export interface ConvertedSkillTriggers {
  text: string;
  /** Codex structured skill inputs for every skill token in the text. */
  skills: Array<{ name: string; path: string }>;
}

/** Codex slash commands handled by the app, never rewritten to `$`. */
const CODEX_RESERVED_SLASH_NAMES = new Set([
  "goal",
  "plan",
  "skills",
  "permissions",
]);

/**
 * Claude builtin commands that must keep their `/` form. Mirrors
 * `knownCommands` in `apps/mobile/lib/widgets/slash_command_sheet.dart`.
 */
const CLAUDE_BUILTIN_COMMANDS = new Set([
  "compact",
  "plan",
  "goal",
  "clear",
  "help",
  "context",
  "cost",
  "init",
  "review",
  "model",
  "skills",
  "status",
  "memory",
  "config",
  "permissions",
  "pr-comments",
  "release-notes",
  "security-review",
  "resume",
  "rename",
  "doctor",
  "mcp",
  "export",
  "add-dir",
  "rewind",
  "vim",
  "login",
]);

const CLOSING_PUNCTUATION = new Set([")", "]", "}", ",", ";", "!", "?", '"', "'"]);

function nativeTrigger(provider: SkillTriggerProvider): "/" | "$" {
  return provider === "codex" ? "$" : "/";
}

/**
 * Build a catalog from the Bridge's cached completion entities. Returns null
 * while the provider has not reported its skills yet.
 */
export function catalogFromCachedCommands(
  provider: SkillTriggerProvider,
  cached:
    | {
        slashCommands: string[];
        skills: string[];
        skillMetadata?: Array<Record<string, unknown>>;
      }
    | undefined,
): SkillTriggerCatalog | null {
  if (!cached) return null;
  const skills = new Map<string, string>();
  if (provider === "codex") {
    if (!cached.skillMetadata) return null;
    for (const meta of cached.skillMetadata) {
      const name = typeof meta.name === "string" ? meta.name : "";
      const path = typeof meta.path === "string" ? meta.path : "";
      if (!name || meta.enabled === false) continue;
      if (CODEX_RESERVED_SLASH_NAMES.has(name)) continue;
      skills.set(name, path);
    }
  } else {
    if (cached.slashCommands.length === 0) return null;
    for (const name of cached.slashCommands) {
      if (name && !CLAUDE_BUILTIN_COMMANDS.has(name)) skills.set(name, "");
    }
  }
  return { provider, skills };
}

/** Whether the text may contain a skill typed with the other agent's trigger. */
export function hasForeignSkillTrigger(
  text: string,
  provider: SkillTriggerProvider,
): boolean {
  const foreign = nativeTrigger(provider) === "/" ? "$" : "/";
  for (let index = text.indexOf(foreign); index >= 0; index = text.indexOf(foreign, index + 1)) {
    if (
      isBoundaryBefore(text, index) &&
      index + 1 < text.length &&
      isNameChar(text.charCodeAt(index + 1))
    ) {
      return true;
    }
  }
  return false;
}

/**
 * Rewrite known skills typed with the other agent's trigger into the native
 * form. Unknown names, builtins, prices (`$5`), environment variables, paths
 * and Markdown code are left untouched.
 */
export function convertSkillTriggers(
  text: string,
  catalog: SkillTriggerCatalog,
): ConvertedSkillTriggers {
  const native = nativeTrigger(catalog.provider);
  const foreign = native === "/" ? "$" : "/";
  const skills: Array<{ name: string; path: string }> = [];
  const seen = new Set<string>();
  if (!text || catalog.skills.size === 0) return { text, skills };

  const protectedRanges = codeRanges(text);
  let output = "";
  let cursor = 0;
  let rangeIndex = 0;
  let index = 0;
  while (index < text.length) {
    while (rangeIndex < protectedRanges.length && protectedRanges[rangeIndex][1] <= index) {
      rangeIndex++;
    }
    if (rangeIndex < protectedRanges.length && protectedRanges[rangeIndex][0] <= index) {
      index = protectedRanges[rangeIndex][1];
      continue;
    }
    const char = text[index];
    if ((char !== foreign && char !== native) || !isBoundaryBefore(text, index)) {
      index++;
      continue;
    }
    let end = index + 1;
    while (end < text.length && isNameChar(text.charCodeAt(end))) end++;
    const name = trimTrailingSeparators(text.slice(index + 1, end));
    end = index + 1 + name.length;
    if (!name || !catalog.skills.has(name) || !isBoundaryAfter(text, end)) {
      index++;
      continue;
    }
    if (catalog.provider === "codex" && !seen.has(name)) {
      const path = catalog.skills.get(name);
      if (path) {
        seen.add(name);
        skills.push({ name, path });
      }
    }
    if (char === foreign) {
      output += text.slice(cursor, index) + native + name;
      cursor = end;
    }
    index = end;
  }
  if (cursor === 0) return { text, skills };
  return { text: output + text.slice(cursor), skills };
}

/** Skill names follow Codex's mention charset (`[A-Za-z0-9_:-]`). */
function isNameChar(c: number): boolean {
  return (
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a) ||
    c === 0x5f ||
    c === 0x2d ||
    c === 0x3a
  );
}

function isNonAscii(char: string): boolean {
  return char.charCodeAt(0) > 0x7f;
}

function trimTrailingSeparators(name: string): string {
  let end = name.length;
  while (end > 0 && (name[end - 1] === ":" || name[end - 1] === "-")) end--;
  return name.slice(0, end);
}

function isBoundaryBefore(text: string, index: number): boolean {
  if (index === 0) return true;
  const previous = text[index - 1];
  return isNonAscii(previous) || /[\s([{,;]/.test(previous);
}

function isBoundaryAfter(text: string, end: number): boolean {
  if (end >= text.length) return true;
  const next = text[end];
  if (/\s/.test(next) || isNonAscii(next) || CLOSING_PUNCTUATION.has(next)) {
    return true;
  }
  if (next === "." || next === ":") {
    if (end + 1 >= text.length) return true;
    const after = text[end + 1];
    return /\s/.test(after) || isNonAscii(after);
  }
  return false;
}

/** Ranges covered by fenced code blocks and inline code spans. */
function codeRanges(text: string): Array<[number, number]> {
  const ranges: Array<[number, number]> = [];
  let index = 0;
  while (index < text.length) {
    if (text.startsWith("```", index)) {
      const close = text.indexOf("```", index + 3);
      const end = close < 0 ? text.length : close + 3;
      ranges.push([index, end]);
      index = end;
      continue;
    }
    if (text[index] === "`") {
      const close = text.indexOf("`", index + 1);
      const newline = text.indexOf("\n", index + 1);
      if (close > 0 && (newline < 0 || close < newline)) {
        ranges.push([index, close + 1]);
        index = close + 1;
        continue;
      }
    }
    index++;
  }
  return ranges;
}
