/**
 * Recent-session search helpers shared by the filesystem index and the
 * WebSocket listing (app-server `thread/list` results).
 *
 * This is a leaf module: it must not import `sessions-index.ts` (which imports
 * it) so the WebSocket tests can mock the index without losing these helpers.
 * See docs/recent-sessions-filters.md.
 */
import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";

export type RecentSessionSearchField =
  | "name"
  | "firstPrompt"
  | "lastPrompt"
  | "summary"
  | "project"
  | "branch"
  | "content";

export interface RecentSessionSearchMatch {
  field: RecentSessionSearchField;
  /** ~120 chars around the first transcript hit (`content` only). */
  snippet?: string;
}

interface SearchableRecentSession {
  name?: unknown;
  firstPrompt?: unknown;
  lastPrompt?: unknown;
  summary?: unknown;
  projectPath?: unknown;
  gitBranch?: unknown;
}

/** Last path segment of a project path (POSIX or Windows separators). */
export function projectFolderName(projectPath: string): string {
  const parts = projectPath.split(/[\\/]+/).filter((part) => part.length > 0);
  return parts[parts.length - 1] ?? "";
}

function includesLower(value: unknown, queryLower: string): boolean {
  return typeof value === "string" && value.toLowerCase().includes(queryLower);
}

/**
 * The first metadata field (name → firstPrompt → lastPrompt → summary →
 * project folder name → git branch) containing [searchQuery]
 * case-insensitively, or undefined when none matches.
 */
export function recentSessionMetadataSearchField(
  session: SearchableRecentSession,
  searchQuery: string,
): Exclude<RecentSessionSearchField, "content"> | undefined {
  const q = searchQuery.toLowerCase();
  if (q.length === 0) return undefined;
  if (includesLower(session.name, q)) return "name";
  if (includesLower(session.firstPrompt, q)) return "firstPrompt";
  if (includesLower(session.lastPrompt, q)) return "lastPrompt";
  if (includesLower(session.summary, q)) return "summary";
  if (
    typeof session.projectPath === "string" &&
    includesLower(projectFolderName(session.projectPath), q)
  ) {
    return "project";
  }
  if (includesLower(session.gitBranch, q)) return "branch";
  return undefined;
}

/**
 * Copy of [session] with `searchMatch` set from its metadata, or [session]
 * itself (without adding a field) when no metadata field matches.
 */
export function withRecentSessionMetadataSearchMatch<
  T extends SearchableRecentSession,
>(session: T, searchQuery: string | undefined): T {
  if (!searchQuery) return session;
  const field = recentSessionMetadataSearchField(session, searchQuery);
  return field ? { ...session, searchMatch: { field } } : session;
}

// ---------------------------------------------------------------------------
// Transcript (content) search
// ---------------------------------------------------------------------------

export const CONTENT_SEARCH_MAX_FILES = 400;
export const CONTENT_SEARCH_BUDGET_MS = 4000;
export const CONTENT_SEARCH_SNIPPET_LENGTH = 120;
const CONTENT_SEARCH_CONCURRENCY = 32;

const RE_CLAUDE_SYSTEM_INJECTED =
  /^<(?:local-command-caveat|local-command-std(?:err|out)|task-notification|teammate-message|bash-(?:input|stdout)|command-(?:name|message|args))>/;

function isCodexInjectedUserContext(text: string): boolean {
  const normalized = text.trimStart();
  return (
    normalized.startsWith("# AGENTS.md instructions for ") ||
    normalized.startsWith("<environment_context>") ||
    normalized.startsWith("<user_instructions>") ||
    normalized.startsWith("<permissions instructions>") ||
    normalized.startsWith("<collaboration_mode>") ||
    normalized.startsWith("<personality_spec>") ||
    normalized.startsWith("<skills_instructions>") ||
    normalized.startsWith("<plugins_instructions>") ||
    normalized.startsWith("<skill>")
  );
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function textBlocks(content: unknown, blockTypes: readonly string[]): string[] {
  if (typeof content === "string") return [content];
  if (!Array.isArray(content)) return [];
  const texts: string[] = [];
  for (const block of content) {
    const record = asRecord(block);
    if (
      record &&
      typeof record.type === "string" &&
      blockTypes.includes(record.type) &&
      typeof record.text === "string"
    ) {
      texts.push(record.text);
    }
  }
  return texts;
}

/**
 * User / assistant message texts of one parsed transcript line. Tool input,
 * tool results, reasoning and injected context are excluded.
 */
export function transcriptLineMessageTexts(
  provider: "claude" | "codex",
  line: unknown,
): string[] {
  const entry = asRecord(line);
  if (!entry) return [];
  if (provider === "claude") {
    if (entry.type !== "user" && entry.type !== "assistant") return [];
    if (entry.isMeta === true || entry.isCompactSummary === true) return [];
    const message = asRecord(entry.message);
    if (!message) return [];
    const texts = textBlocks(message.content, ["text"]);
    return entry.type === "user"
      ? texts.filter((text) => !RE_CLAUDE_SYSTEM_INJECTED.test(text.trimStart()))
      : texts;
  }

  // Codex rollout: `event_msg` user/agent messages and `response_item`
  // messages (also the legacy top-level `{type: "message"}` shape).
  const payload =
    entry.type === "event_msg" || entry.type === "response_item"
      ? asRecord(entry.payload)
      : entry.type === "message"
        ? entry
        : undefined;
  if (!payload) return [];
  if (entry.type === "event_msg") {
    if (
      (payload.type === "user_message" || payload.type === "agent_message") &&
      typeof payload.message === "string"
    ) {
      return payload.type === "user_message" &&
        isCodexInjectedUserContext(payload.message)
        ? []
        : [payload.message];
    }
    return [];
  }
  if (payload.type !== "message") return [];
  if (payload.role === "assistant") {
    return textBlocks(payload.content, ["output_text", "text"]);
  }
  if (payload.role === "user") {
    return textBlocks(payload.content, ["input_text", "text"]).filter(
      (text) => !isCodexInjectedUserContext(text),
    );
  }
  return [];
}

/**
 * ~[maxLength] characters of [text] (whitespace collapsed) around the first
 * case-insensitive occurrence of [query], with ellipses where truncated.
 */
export function buildContentSnippet(
  text: string,
  query: string,
  maxLength = CONTENT_SEARCH_SNIPPET_LENGTH,
): string {
  const collapsed = text.replace(/\s+/g, " ").trim();
  if (collapsed.length <= maxLength) return collapsed;
  const needle = query.replace(/\s+/g, " ").trim().toLowerCase();
  const index = needle ? collapsed.toLowerCase().indexOf(needle) : -1;
  const center = index >= 0 ? index + needle.length / 2 : 0;
  let start = Math.max(0, Math.round(center - maxLength / 2));
  start = Math.min(start, collapsed.length - maxLength);
  const end = start + maxLength;
  return `${start > 0 ? "…" : ""}${collapsed.slice(start, end).trim()}${
    end < collapsed.length ? "…" : ""
  }`;
}

export type TranscriptSearchResult =
  | { status: "match"; snippet: string }
  | { status: "no_match" }
  | { status: "timeout" };

/**
 * Stream a JSONL transcript and return the first user / assistant message
 * text containing [query] (case-insensitive). Lines are pre-checked on the
 * raw (lowercased) text before JSON parsing. Missing or unreadable files are
 * a `no_match`; passing [deadline] (epoch ms) aborts with `timeout`.
 */
export async function searchTranscriptFile(
  provider: "claude" | "codex",
  filePath: string,
  query: string,
  options: { deadline?: number; now?: () => number } = {},
): Promise<TranscriptSearchResult> {
  const queryLower = query.toLowerCase();
  if (queryLower.length === 0) return { status: "no_match" };
  // JSON escapes quotes, backslashes and control characters, so also look
  // for the escaped form on the raw line.
  const escapedLower = JSON.stringify(query).slice(1, -1).toLowerCase();
  const rawNeedles =
    escapedLower === queryLower ? [queryLower] : [queryLower, escapedLower];
  const now = options.now ?? Date.now;

  const stream = createReadStream(filePath, { encoding: "utf-8" });
  const lines = createInterface({ input: stream, crlfDelay: Infinity });
  let result: TranscriptSearchResult = { status: "no_match" };
  try {
    for await (const line of lines) {
      if (options.deadline !== undefined && now() >= options.deadline) {
        result = { status: "timeout" };
        break;
      }
      const lower = line.toLowerCase();
      if (!rawNeedles.some((needle) => lower.includes(needle))) continue;
      let parsed: unknown;
      try {
        parsed = JSON.parse(line);
      } catch {
        continue;
      }
      const hit = transcriptLineMessageTexts(provider, parsed).find((text) =>
        text.toLowerCase().includes(queryLower),
      );
      if (hit !== undefined) {
        result = { status: "match", snippet: buildContentSnippet(hit, query) };
        break;
      }
    }
  } catch {
    // ENOENT / EACCES / decode errors: treat as no match.
  } finally {
    lines.close();
    stream.destroy();
  }
  return result;
}

export interface RecentSessionContentSearchOptions<T> {
  query: string;
  /** Stop once this many matches were found. */
  needed: number;
  /** Transcript files of a session (searched in order, first hit wins). */
  transcriptPaths: (session: T) => readonly string[];
  maxFiles?: number;
  budgetMs?: number;
  concurrency?: number;
  now?: () => number;
}

export interface RecentSessionContentSearchResult<T> {
  matches: Array<{ session: T; searchMatch: RecentSessionSearchMatch }>;
  /** A file or time bound stopped the walk before [needed] was reached. */
  incomplete: boolean;
  filesRead: number;
}

/**
 * Walk [sessions] (already filtered and sorted newest first) and collect the
 * ones matching [query] on metadata or, failing that, in their transcript.
 * Transcript reads run with bounded parallelism but results keep input
 * order. At most `maxFiles` files are read and the walk stops after
 * `budgetMs`; hitting either bound reports `incomplete`.
 */
export async function searchRecentSessionContent<
  T extends SearchableRecentSession & { provider: "claude" | "codex" },
>(
  sessions: readonly T[],
  options: RecentSessionContentSearchOptions<T>,
): Promise<RecentSessionContentSearchResult<T>> {
  const now = options.now ?? Date.now;
  const maxFiles = options.maxFiles ?? CONTENT_SEARCH_MAX_FILES;
  const deadline = now() + (options.budgetMs ?? CONTENT_SEARCH_BUDGET_MS);
  const concurrency = Math.max(
    1,
    options.concurrency ?? CONTENT_SEARCH_CONCURRENCY,
  );
  const matches: RecentSessionContentSearchResult<T>["matches"] = [];
  let filesRead = 0;
  let incomplete = false;
  let index = 0;

  type Pending =
    | { session: T; searchMatch: RecentSessionSearchMatch }
    | { session: T; paths: readonly string[] };

  while (index < sessions.length && matches.length < options.needed) {
    if (now() >= deadline) {
      incomplete = true;
      break;
    }
    const batch: Pending[] = [];
    let batchFiles = 0;
    let fileBoundHit = false;
    while (index < sessions.length && batchFiles < concurrency) {
      const session = sessions[index];
      const field = recentSessionMetadataSearchField(session, options.query);
      if (field) {
        batch.push({ session, searchMatch: { field } });
      } else {
        const paths = options.transcriptPaths(session);
        if (paths.length > 0) {
          if (filesRead + batchFiles + paths.length > maxFiles) {
            fileBoundHit = true;
            break;
          }
          batchFiles += paths.length;
          batch.push({ session, paths });
        }
      }
      index += 1;
    }

    const results = await Promise.all(
      batch.map(async (item): Promise<
        RecentSessionSearchMatch | "timeout" | undefined
      > => {
        if ("searchMatch" in item) return item.searchMatch;
        for (const path of item.paths) {
          const result = await searchTranscriptFile(
            item.session.provider,
            path,
            options.query,
            { deadline, now },
          );
          if (result.status === "timeout") return "timeout";
          if (result.status === "match") {
            return { field: "content", snippet: result.snippet };
          }
        }
        return undefined;
      }),
    );
    filesRead += batchFiles;

    for (let i = 0; i < batch.length; i++) {
      const result = results[i];
      if (result === "timeout") {
        // Later results are discarded to keep the newest-first order exact.
        incomplete = true;
        break;
      }
      if (result) {
        matches.push({ session: batch[i].session, searchMatch: result });
        if (matches.length >= options.needed) break;
      }
    }
    if (incomplete) break;
    if (fileBoundHit && matches.length < options.needed) {
      incomplete = true;
      break;
    }
  }

  return { matches, incomplete, filesRead };
}
