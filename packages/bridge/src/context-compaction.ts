/**
 * Context compaction boundaries shared by live streams and history readers.
 * See docs/context-compaction.md.
 */

export interface SessionHistoryCompaction {
  trigger?: "manual" | "auto";
  preTokens?: number;
  postTokens?: number;
  /** Claude compaction summary. Codex summaries are encrypted. */
  summary?: string;
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

/**
 * Normalizes Claude compaction metadata. The SDK stream uses snake_case
 * (`compact_metadata.pre_tokens`); the JSONL transcript uses camelCase
 * (`compactMetadata.preTokens`).
 */
export function normalizeClaudeCompactMetadata(
  raw: unknown,
): SessionHistoryCompaction {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const meta = raw as Record<string, unknown>;
  const trigger = meta.trigger;
  const preTokens = finiteNumber(meta.preTokens ?? meta.pre_tokens);
  const postTokens = finiteNumber(meta.postTokens ?? meta.post_tokens);
  return {
    ...(trigger === "manual" || trigger === "auto" ? { trigger } : {}),
    ...(preTokens !== undefined ? { preTokens } : {}),
    ...(postTokens !== undefined ? { postTokens } : {}),
  };
}

const SUMMARY_HEADING = /(?:^|\n)Summary:\n/;

/**
 * Extracts the readable part of a Claude compaction summary prompt: drops the
 * continuation preamble and injected system reminders.
 */
export function cleanClaudeCompactSummary(raw: string): string {
  let text = raw.replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "");
  const heading = SUMMARY_HEADING.exec(text);
  if (heading) text = text.slice(heading.index + heading[0].length);
  return text.trim();
}

export interface TranscriptPageRequest {
  beforeIndex?: number;
  untilLatestCompaction?: boolean;
  limit?: number;
}

/**
 * Selects one transcript page, counting back from its exclusive end.
 * `untilLatestCompaction` ends the first page at (and including) the latest
 * compaction marker so the reader starts at the summarized part.
 */
export function transcriptPageRange(
  roles: readonly string[],
  request: TranscriptPageRequest,
  defaultLimit: number,
  maxLimit: number,
): { start: number; end: number } {
  const total = roles.length;
  let end = total;
  if (request.beforeIndex !== undefined) {
    end = Math.min(Math.max(request.beforeIndex, 0), total);
  } else if (request.untilLatestCompaction) {
    const latest = roles.lastIndexOf("compaction");
    if (latest >= 0) end = latest + 1;
  }
  const limit = Math.min(Math.max(request.limit ?? defaultLimit, 1), maxLimit);
  return { start: Math.max(0, end - limit), end };
}
