import { readdir, readFile, writeFile, appendFile, stat, open } from "node:fs/promises";
import { createReadStream, type Dirent } from "node:fs";
import { createInterface } from "node:readline";
import { basename, extname, join } from "node:path";
import { homedir } from "node:os";
import { isAutoRenamePromptText } from "./auto-rename.js";
import { CODEX_ASSIST_MODEL } from "./codex-assist.js";

export interface SessionIndexEntry {
  sessionId: string;
  provider: "claude" | "codex";
  /** User-assigned session name (customTitle for Claude, thread_name for Codex). */
  name?: string;
  agentNickname?: string;
  agentRole?: string;
  summary?: string;
  firstPrompt: string;
  lastPrompt?: string;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  /** Raw cwd used to resume this session (worktree path for codex, if any). */
  resumeCwd?: string;
  /** Permission mode from the first user message (Claude sessions only). */
  permissionMode?: string;
  isSidechain: boolean;
  codexSettings?: {
    profile?: string;
    approvalPolicy?: string;
    approvalsReviewer?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
    additionalWritableRoots?: string[];
  };
}

interface RawSessionIndexFile {
  version: number;
  entries: RawSessionEntry[];
}

interface RawSessionEntry {
  sessionId: string;
  fullPath: string;
  fileMtime: number;
  firstPrompt: string;
  summary?: string;
  customTitle?: string;
  messageCount: number;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  isSidechain: boolean;
}

export interface GetRecentSessionsOptions {
  limit?: number;       // default 20
  offset?: number;      // default 0
  projectPath?: string; // filter by project
  /** Session IDs to exclude (archived sessions). */
  archivedSessionIds?: ReadonlySet<string>;
  /** Filter by provider (claude or codex). */
  provider?: "claude" | "codex";
  /** Show only sessions with a non-empty name. */
  namedOnly?: boolean;
  /** Free-text search across name, firstPrompt, lastPrompt and summary. */
  searchQuery?: string;
}

export interface GetRecentSessionsResult {
  sessions: SessionIndexEntry[];
  hasMore: boolean;
}

interface JsonlScanStats {
  filesTotal: number;
  filesExcluded: number;
  filesRead: number;
  entriesReturned: number;
}

interface RecentSessionsPerfStats {
  claudeProjectDirs: number;
  claudeIndexDirs: number;
  claudeJsonlOnlyDirs: number;
  claudeIndexEntries: number;
  claudeJsonlFilesTotal: number;
  claudeJsonlFilesExcluded: number;
  claudeJsonlFilesRead: number;
  claudeJsonlEntries: number;
  codexFilesTotal: number;
  codexFilesRead: number;
  codexEntries: number;
  claudeNamedOnlyFastPathUsed: boolean;
  counts: {
    beforeArchive: number;
    afterArchive: number;
    afterProvider: number;
    afterNamedOnly: number;
    afterSearch: number;
    returned: number;
  };
}

function createRecentSessionsPerfStats(): RecentSessionsPerfStats {
  return {
    claudeProjectDirs: 0,
    claudeIndexDirs: 0,
    claudeJsonlOnlyDirs: 0,
    claudeIndexEntries: 0,
    claudeJsonlFilesTotal: 0,
    claudeJsonlFilesExcluded: 0,
    claudeJsonlFilesRead: 0,
    claudeJsonlEntries: 0,
    codexFilesTotal: 0,
    codexFilesRead: 0,
    codexEntries: 0,
    claudeNamedOnlyFastPathUsed: false,
    counts: {
      beforeArchive: 0,
      afterArchive: 0,
      afterProvider: 0,
      afterNamedOnly: 0,
      afterSearch: 0,
      returned: 0,
    },
  };
}

function markDuration(
  durations: Record<string, number>,
  key: string,
  startedAt: bigint,
): void {
  const elapsedMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
  durations[key] = elapsedMs;
}

function shouldLogRecentSessionsPerf(): boolean {
  const v = process.env.BRIDGE_RECENT_SESSIONS_PROFILE;
  return v === "1" || v === "true";
}

function logRecentSessionsPerf(
  options: GetRecentSessionsOptions,
  durations: Record<string, number>,
  stats: RecentSessionsPerfStats,
): void {
  if (!shouldLogRecentSessionsPerf()) return;

  const projectPath = options.projectPath;
  const projectPathLabel = projectPath
    ? projectPath.length > 72
      ? `${projectPath.slice(0, 69)}...`
      : projectPath
    : "";

  const payload = {
    options: {
      limit: options.limit ?? 20,
      offset: options.offset ?? 0,
      projectPath: projectPathLabel || undefined,
      provider: options.provider ?? "all",
      namedOnly: options.namedOnly ?? false,
      searchQuery: options.searchQuery ? "<set>" : "<none>",
      archivedSessionIds: options.archivedSessionIds?.size ?? 0,
    },
    durationsMs: Object.fromEntries(
      Object.entries(durations).map(([k, v]) => [k, Number(v.toFixed(1))]),
    ),
    stats,
  };

  console.info(`[recent-sessions][perf] ${JSON.stringify(payload)}`);
}

interface ScanJsonlDirOptions {
  excludeSessionIds?: ReadonlySet<string>;
  stats?: JsonlScanStats;
}

/** Convert a filesystem path to Claude's project directory slug (e.g. /foo/bar → -foo-bar). */
export function pathToSlug(p: string): string {
  return p.replaceAll("\\", "-").replaceAll("/", "-").replaceAll("_", "-");
}

/**
 * Normalize a worktree cwd back to the main project path.
 * e.g. /path/to/project-worktrees/branch → /path/to/project
 */
export function normalizeWorktreePath(p: string): string {
  const match = p.match(/^(.+)-worktrees[\\/][^\\/]+$/);
  return match?.[1] ?? p;
}

/**
 * Check if a directory slug represents a worktree directory for a given project slug.
 * e.g. "-Users-x-proj-worktrees-branch" is a worktree dir for "-Users-x-proj".
 */
export function isWorktreeSlug(dirSlug: string, projectSlug: string): boolean {
  return dirSlug.startsWith(projectSlug + "-worktrees-");
}

/** Concurrency limit for parallel file reads to avoid fd exhaustion. */
const PARALLEL_FILE_READ_LIMIT = 32;

/** Head/Tail byte sizes for partial JSONL reads. */
const HEAD_BYTES = 16384; // 16KB — covers first user entry + metadata
const TAIL_BYTES = 8192;  // 8KB — covers last entries for modified/lastPrompt
const CODEX_HEAD_BYTES = 131072; // 128KB — Codex turn_context can be large
const CODEX_TAIL_BYTES = 16384;

/**
 * Run async tasks with a concurrency limit.
 * Returns results in the same order as the input tasks.
 */
async function parallelMap<T, R>(
  items: T[],
  concurrency: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let nextIndex = 0;

  async function worker(): Promise<void> {
    while (nextIndex < items.length) {
      const i = nextIndex++;
      results[i] = await fn(items[i]);
    }
  }

  const workers = Array.from(
    { length: Math.min(concurrency, items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}

// Regexes for fast field extraction without JSON.parse
const RE_TYPE_USER = /"type"\s*:\s*"user"/;
const RE_TYPE_ASSISTANT = /"type"\s*:\s*"assistant"/;
const RE_TIMESTAMP = /"timestamp"\s*:\s*"([^"]+)"/;
const RE_GIT_BRANCH = /"gitBranch"\s*:\s*"([^"]+)"/;
const RE_CWD = /"cwd"\s*:\s*"([^"]+)"/;
const RE_IS_SIDECHAIN = /"isSidechain"\s*:\s*true/;
const RE_PERMISSION_MODE = /"permissionMode"\s*:\s*"([^"]+)"/;
const RE_TYPE_CUSTOM_TITLE = /"type"\s*:\s*"custom-title"/;
const RE_CUSTOM_TITLE = /"customTitle"\s*:\s*"([^"]+)"/;
const RE_CODEX_PARTIAL_TIMESTAMP = /"timestamp"\s*:\s*"([^"]+)"/;
const RE_CODEX_PARTIAL_USER_MESSAGE =
  /"type"\s*:\s*"event_msg"[\s\S]*"payload"\s*:\s*\{[\s\S]*"type"\s*:\s*"user_message"[\s\S]*"message"\s*:\s*"((?:\\.|[^"\\])*)/;
const RE_CODEX_PARTIAL_AGENT_MESSAGE =
  /"type"\s*:\s*"event_msg"[\s\S]*"payload"\s*:\s*\{[\s\S]*"type"\s*:\s*"agent_message"[\s\S]*"message"\s*:\s*"((?:\\.|[^"\\])*)/;
const RE_CODEX_PARTIAL_OUTPUT_TEXT =
  /"type"\s*:\s*"response_item"[\s\S]*"role"\s*:\s*"assistant"[\s\S]*"type"\s*:\s*"output_text"[\s\S]*"text"\s*:\s*"((?:\\.|[^"\\])*)/;

/**
 * Detect system-injected messages that should be skipped when determining
 * the user's first/last prompt text (e.g. local-command-caveat, stderr/stdout
 * captures, team notifications, skill loading).
 */
const RE_SYSTEM_INJECTED =
  /^<(?:local-command-caveat|local-command-std(?:err|out)|task-notification|teammate-message|bash-(?:input|stdout))>/;

function isSystemInjectedText(text: string): boolean {
  return RE_SYSTEM_INJECTED.test(text) || text.startsWith("Base directory for this skill:");
}

function isCodexAutoRenameSession(firstPrompt: string, model?: string): boolean {
  return model === CODEX_ASSIST_MODEL && isAutoRenamePromptText(firstPrompt);
}

function decodeJsonStringPrefix(fragment: string): string {
  let candidate = fragment;
  while (candidate.length > 0) {
    try {
      return JSON.parse(`"${candidate}"`) as string;
    } catch {
      candidate = candidate.slice(0, -1);
    }
  }
  return "";
}

function parsePartialCodexLine(line: string): {
  timestamp?: string;
  userMessage?: string;
  assistantText?: string;
} {
  const timestamp = line.match(RE_CODEX_PARTIAL_TIMESTAMP)?.[1];
  const userMessage = line.match(RE_CODEX_PARTIAL_USER_MESSAGE)?.[1];
  if (userMessage !== undefined) {
    return {
      timestamp,
      userMessage: decodeJsonStringPrefix(userMessage),
    };
  }
  const agentMessage = line.match(RE_CODEX_PARTIAL_AGENT_MESSAGE)?.[1];
  if (agentMessage !== undefined) {
    return {
      timestamp,
      assistantText: decodeJsonStringPrefix(agentMessage),
    };
  }
  const outputText = line.match(RE_CODEX_PARTIAL_OUTPUT_TEXT)?.[1];
  if (outputText !== undefined) {
    return {
      timestamp,
      assistantText: decodeJsonStringPrefix(outputText),
    };
  }
  return timestamp ? { timestamp } : {};
}

/** Extract user prompt text from a parsed JSONL entry. */
function extractUserPromptText(entry: Record<string, unknown>): string {
  const message = entry.message as { content?: unknown } | undefined;
  if (!message?.content) return "";
  if (typeof message.content === "string") return message.content;
  if (Array.isArray(message.content)) {
    const textBlock = (
      message.content as Array<{ type: string; text?: string }>
    ).find((c) => c.type === "text" && c.text);
    return textBlock?.text ?? "";
  }
  return "";
}

/**
 * Parse head and optional tail text chunks to build a SessionIndexEntry.
 * Uses regex for most fields, JSON.parse only for first/last user lines.
 */
interface ParsedClaudeChunks {
  entry: SessionIndexEntry | null;
  headFoundFirstPrompt: boolean;
  headFoundProjectPath: boolean;
  headFoundGitBranch: boolean;
}

function parseFromChunks(
  sessionId: string,
  head: string,
  tail: string | null,
): ParsedClaudeChunks {
  let firstPrompt = "";
  let lastPrompt = "";
  let created = "";
  let modified = "";
  let gitBranch = "";
  let rawCwd = "";
  let projectPath = "";
  let customTitle = "";
  let permissionMode = "";
  let isSidechain = false;
  let hasAnyMessage = false;
  let headFoundFirstPrompt = false;
  let headFoundProjectPath = false;
  let headFoundGitBranch = false;
  let isInternalAutoRename = false;

  // --- Scan head lines ---
  const headLines = head.split("\n");
  for (const line of headLines) {
    if (!line.trim()) continue;

    // Extract custom-title (typically the first line in the JSONL)
    if (!customTitle && RE_TYPE_CUSTOM_TITLE.test(line)) {
      const ctMatch = line.match(RE_CUSTOM_TITLE);
      if (ctMatch) customTitle = ctMatch[1];
      continue;
    }

    const isUser = RE_TYPE_USER.test(line);
    const isAssistant = !isUser && RE_TYPE_ASSISTANT.test(line);
    if (!isUser && !isAssistant) continue;
    hasAnyMessage = true;

    const tsMatch = line.match(RE_TIMESTAMP);
    if (tsMatch) {
      if (!created) created = tsMatch[1];
      modified = tsMatch[1];
    }

    if (!gitBranch) {
      const gbMatch = line.match(RE_GIT_BRANCH);
      if (gbMatch) {
        gitBranch = gbMatch[1];
        headFoundGitBranch = true;
      }
    }

    if (!projectPath) {
      const cwdMatch = line.match(RE_CWD);
      if (cwdMatch) {
        rawCwd = cwdMatch[1];
        projectPath = normalizeWorktreePath(rawCwd);
        headFoundProjectPath = true;
      }
    }

    if (!isSidechain && RE_IS_SIDECHAIN.test(line)) {
      isSidechain = true;
    }

    if (isUser && !permissionMode) {
      const pmMatch = line.match(RE_PERMISSION_MODE);
      if (pmMatch) permissionMode = pmMatch[1];
    }

    if (isUser && !firstPrompt) {
      // JSON.parse only user lines to extract prompt text, skipping
      // system-injected messages (e.g. <local-command-caveat>)
      try {
        const entry = JSON.parse(line) as Record<string, unknown>;
        const text = extractUserPromptText(entry);
        if (text && !isSystemInjectedText(text)) {
          if (isAutoRenamePromptText(text)) {
            isInternalAutoRename = true;
            break;
          }
          firstPrompt = text;
          headFoundFirstPrompt = true;
        }
      } catch { /* skip */ }
    }
  }

  if (isInternalAutoRename) {
    return {
      entry: null,
      headFoundFirstPrompt,
      headFoundProjectPath,
      headFoundGitBranch,
    };
  }

  // --- Scan tail lines (if separate from head) ---
  if (tail) {
    const tailLines = tail.split("\n");

    // Find last timestamp and last user prompt from tail (scan in reverse)
    let lastUserLine: string | null = null;
    for (let i = tailLines.length - 1; i >= 0; i--) {
      const line = tailLines[i];
      if (!line.trim()) continue;

      const isUser = RE_TYPE_USER.test(line);
      const isAssistant = !isUser && RE_TYPE_ASSISTANT.test(line);
      if (!isUser && !isAssistant) continue;
      hasAnyMessage = true;

      // Get the last modified timestamp
      if (!modified || true) {
        // Always update modified from tail (tail is later in file)
        const tsMatch = line.match(RE_TIMESTAMP);
        if (tsMatch) {
          modified = tsMatch[1];
          // We found the last message — we're done with timestamps
          if (isUser && !lastUserLine) lastUserLine = line;
          break;
        }
      }
    }

    // Also find last user line if not found in reverse timestamp scan
    if (!lastUserLine) {
      for (let i = tailLines.length - 1; i >= 0; i--) {
        const line = tailLines[i];
        if (!line.trim()) continue;
        if (RE_TYPE_USER.test(line)) {
          lastUserLine = line;
          break;
        }
      }
    }

    // JSON.parse only the last user line for lastPrompt
    if (lastUserLine) {
      try {
        const entry = JSON.parse(lastUserLine) as Record<string, unknown>;
        const text = extractUserPromptText(entry);
        if (text && !isSystemInjectedText(text)) lastPrompt = text;
      } catch { /* skip */ }
    }

    // Fill in metadata from tail if head didn't have it
    if (!gitBranch || !projectPath) {
      for (const line of tailLines) {
        if (!line.trim()) continue;
        if (!RE_TYPE_USER.test(line) && !RE_TYPE_ASSISTANT.test(line)) continue;
        if (!gitBranch) {
          const gbMatch = line.match(RE_GIT_BRANCH);
          if (gbMatch) gitBranch = gbMatch[1];
        }
        if (!projectPath) {
          const cwdMatch = line.match(RE_CWD);
          if (cwdMatch) {
            rawCwd = cwdMatch[1];
            projectPath = normalizeWorktreePath(rawCwd);
          }
        }
        if (gitBranch && projectPath) break;
      }
    }
  }

  if (!hasAnyMessage) {
    return {
      entry: null,
      headFoundFirstPrompt,
      headFoundProjectPath,
      headFoundGitBranch,
    };
  }

  if (isAutoRenamePromptText(firstPrompt)) {
    return {
      entry: null,
      headFoundFirstPrompt,
      headFoundProjectPath,
      headFoundGitBranch,
    };
  }

  return {
    entry: {
      sessionId,
      provider: "claude",
      firstPrompt,
      ...(lastPrompt && lastPrompt !== firstPrompt ? { lastPrompt } : {}),
      ...(customTitle ? { name: customTitle } : {}),
      created,
      modified,
      gitBranch,
      projectPath,
      ...(rawCwd && rawCwd !== projectPath ? { resumeCwd: rawCwd } : {}),
      ...(permissionMode ? { permissionMode } : {}),
      isSidechain,
    },
    headFoundFirstPrompt,
    headFoundProjectPath,
    headFoundGitBranch,
  };
}

/**
 * Fast parse a Claude JSONL file using partial (head+tail) reads.
 * Only reads the first 16KB and last 8KB of the file, avoiding full I/O.
 * JSON.parse is called at most twice (first + last user lines).
 */
async function parseClaudeJsonlFileFast(
  sessionId: string,
  filePath: string,
): Promise<SessionIndexEntry | null> {
  let fh;
  try {
    fh = await open(filePath, "r");
  } catch {
    return null;
  }

  let parsedChunks: ParsedClaudeChunks;
  try {
    const fileStat = await fh.stat();
    const fileSize = fileStat.size;
    if (fileSize === 0) return null;

    // Small files: read entirely (no benefit from partial reads)
    if (fileSize <= HEAD_BYTES + TAIL_BYTES) {
      const buf = Buffer.alloc(fileSize);
      await fh.read(buf, 0, fileSize, 0);
      return parseFromChunks(sessionId, buf.toString("utf-8"), null).entry;
    }

    // Head read
    const headBuf = Buffer.alloc(HEAD_BYTES);
    await fh.read(headBuf, 0, HEAD_BYTES, 0);
    const headStr = headBuf.toString("utf-8");

    // Tail read — discard the first partial line
    const tailBuf = Buffer.alloc(TAIL_BYTES);
    await fh.read(tailBuf, 0, TAIL_BYTES, fileSize - TAIL_BYTES);
    const tailRaw = tailBuf.toString("utf-8");
    const firstNewline = tailRaw.indexOf("\n");
    const cleanTail = firstNewline >= 0 ? tailRaw.slice(firstNewline + 1) : "";

    parsedChunks = parseFromChunks(sessionId, headStr, cleanTail);
  } finally {
    await fh.close();
  }

  const result = parsedChunks.entry;

  // If the first large JSONL line pushed early metadata outside HEAD_BYTES,
  // the tail supplement may incorrectly pick a later cwd/gitBranch. Stream
  // from the start whenever head parsing missed these fields so resume uses
  // the original session cwd rather than a later in-session directory.
  if (
    result
    && (
      !result.firstPrompt
      || !parsedChunks.headFoundProjectPath
      || !parsedChunks.headFoundGitBranch
    )
  ) {
    const missing = await extractMissingFieldsStreaming(
      filePath,
      !result.firstPrompt,
      !parsedChunks.headFoundProjectPath,
      !parsedChunks.headFoundGitBranch,
    );
    if (!result.firstPrompt && missing.firstPrompt) {
      result.firstPrompt = missing.firstPrompt;
    }
    if (isAutoRenamePromptText(result.firstPrompt)) {
      return null;
    }
    if (missing.projectPath) {
      result.projectPath = missing.projectPath;
      if (missing.rawCwd && missing.rawCwd !== missing.projectPath) {
        result.resumeCwd = missing.rawCwd;
      } else {
        delete result.resumeCwd;
      }
    }
    if (missing.gitBranch) {
      result.gitBranch = missing.gitBranch;
    }
  }

  return result;
}

async function hydrateClaudeIndexedEntry(
  dirPath: string,
  entry: RawSessionEntry,
): Promise<SessionIndexEntry | null> {
  if (isAutoRenamePromptText(entry.firstPrompt ?? "")) return null;

  const rawProjectPath = entry.projectPath ?? "";
  const normalizedPath = normalizeWorktreePath(rawProjectPath);
  const base: SessionIndexEntry = {
    sessionId: entry.sessionId,
    provider: "claude",
    ...(entry.customTitle ? { name: entry.customTitle } : {}),
    ...(entry.summary ? { summary: entry.summary } : {}),
    firstPrompt: entry.firstPrompt ?? "",
    created: entry.created ?? "",
    modified: entry.modified ?? "",
    gitBranch: entry.gitBranch ?? "",
    projectPath: normalizedPath,
    ...(rawProjectPath && rawProjectPath !== normalizedPath ? { resumeCwd: rawProjectPath } : {}),
    isSidechain: entry.isSidechain ?? false,
  };

  const needsJsonlRepair =
    !base.firstPrompt ||
    !base.projectPath ||
    !base.gitBranch ||
    !base.created ||
    !base.modified ||
    !base.permissionMode;

  if (!needsJsonlRepair) return base;

  const fallbackPath = entry.fullPath || join(dirPath, `${entry.sessionId}.jsonl`);
  const parsed = await parseClaudeJsonlFileFast(entry.sessionId, fallbackPath);
  if (!parsed) return base;
  if (isAutoRenamePromptText(parsed.firstPrompt)) return null;

  return {
    ...base,
    firstPrompt: base.firstPrompt || parsed.firstPrompt,
    created: base.created || parsed.created,
    modified: base.modified || parsed.modified,
    gitBranch: base.gitBranch || parsed.gitBranch,
    projectPath: base.projectPath || parsed.projectPath,
    isSidechain: base.isSidechain || parsed.isSidechain,
    ...(base.lastPrompt || !parsed.lastPrompt ? {} : { lastPrompt: parsed.lastPrompt }),
    ...(base.permissionMode || !parsed.permissionMode ? {} : { permissionMode: parsed.permissionMode }),
  };
}

/**
 * Fallback: stream a JSONL file line-by-line to find missing fields.
 * Called when the fast head-read could not extract firstPrompt/projectPath
 * (e.g. the first user message line is very large due to embedded images
 * and got truncated within HEAD_BYTES).
 * Reads only until all needed fields are found, then stops.
 */
async function extractMissingFieldsStreaming(
  filePath: string,
  needFirstPrompt: boolean,
  needProjectPath: boolean,
  needGitBranch: boolean,
): Promise<{ firstPrompt: string; projectPath: string; rawCwd: string; gitBranch: string }> {
  return new Promise((resolve) => {
    const stream = createReadStream(filePath, { encoding: "utf-8" });
    const rl = createInterface({ input: stream, crlfDelay: Infinity });
    let firstPrompt = "";
    let rawCwd = "";
    let projectPath = "";
    let gitBranch = "";
    let done = false;

    function checkDone(): void {
      const promptDone = !needFirstPrompt || firstPrompt !== "";
      const pathDone = !needProjectPath || projectPath !== "";
      const branchDone = !needGitBranch || gitBranch !== "";
      if (promptDone && pathDone && branchDone) {
        done = true;
        rl.close();
        stream.destroy();
        resolve({ firstPrompt, projectPath, rawCwd, gitBranch });
      }
    }

    rl.on("line", (line) => {
      if (done) return;
      const isUser = RE_TYPE_USER.test(line);
      const isAssistant = !isUser && RE_TYPE_ASSISTANT.test(line);
      if (!isUser && !isAssistant) return;

      // Extract projectPath/gitBranch from cwd field (available on any user/assistant line)
      if (needProjectPath && !projectPath) {
        const cwdMatch = line.match(RE_CWD);
        if (cwdMatch) {
          rawCwd = cwdMatch[1];
          projectPath = normalizeWorktreePath(rawCwd);
        }
      }
      if (needGitBranch && !gitBranch) {
        const gbMatch = line.match(RE_GIT_BRANCH);
        if (gbMatch) gitBranch = gbMatch[1];
      }

      // Extract firstPrompt from user lines
      if (needFirstPrompt && isUser && !firstPrompt) {
        try {
          const entry = JSON.parse(line) as Record<string, unknown>;
          const text = extractUserPromptText(entry);
          if (text && !isSystemInjectedText(text)) {
            firstPrompt = text;
          }
        } catch {
          // Line might be malformed — skip
        }
      }

      checkDone();
    });

    rl.on("close", () => {
      if (!done) resolve({ firstPrompt, projectPath, rawCwd, gitBranch });
    });

    stream.on("error", () => {
      if (!done) resolve({ firstPrompt, projectPath, rawCwd, gitBranch });
    });
  });
}

/**
 * Maximum bytes to read from file tail when searching for lastPrompt.
 * Claude sessions often have large tool-result lines (diffs, etc.) near the
 * end, so 8KB is rarely enough.  We grow the read window in steps up to this
 * cap to balance speed and coverage.
 */
const LAST_PROMPT_MAX_TAIL = 131072; // 128KB

/**
 * Fast tail-read to extract the last user prompt from a JSONL file.
 * Starts at TAIL_BYTES and doubles up to LAST_PROMPT_MAX_TAIL until a real
 * user text prompt is found.  No full-file scan is ever performed.
 * Used to supplement sessions-index.json entries that lack lastPrompt.
 */
async function extractLastPromptFromTail(
  filePath: string,
): Promise<string> {
  let fh;
  try {
    fh = await open(filePath, "r");
  } catch {
    return "";
  }
  try {
    const fileSize = (await fh.stat()).size;
    if (fileSize === 0) return "";

    // Grow tail window: 8KB → 16KB → 32KB → 64KB → 128KB
    for (
      let tailSize = TAIL_BYTES;
      tailSize <= LAST_PROMPT_MAX_TAIL;
      tailSize *= 2
    ) {
      const readSize = Math.min(fileSize, tailSize);
      const readOffset = fileSize - readSize;
      const buf = Buffer.alloc(readSize);
      await fh.read(buf, 0, readSize, readOffset);
      let raw = buf.toString("utf-8");

      // Discard the first partial line if reading from middle of file
      if (readOffset > 0) {
        const nl = raw.indexOf("\n");
        if (nl >= 0) raw = raw.slice(nl + 1);
      }

      // Scan in reverse to find the last user line with real text
      const lines = raw.split("\n");
      for (let i = lines.length - 1; i >= 0; i--) {
        const line = lines[i];
        if (!line.trim()) continue;
        if (!RE_TYPE_USER.test(line)) continue;
        try {
          const entry = JSON.parse(line) as Record<string, unknown>;
          const text = extractUserPromptText(entry);
          if (text && !isSystemInjectedText(text)) return text;
        } catch {
          // Truncated line — skip
        }
      }

      // If we already read the entire file, stop
      if (readSize >= fileSize) break;
    }
    return "";
  } finally {
    await fh.close();
  }
}

/**
 * Scan a directory for JSONL session files and create SessionIndexEntry objects.
 * Used as a fallback when sessions-index.json is missing (common for worktree sessions).
 * File reads are parallelized and use head+tail partial reads for performance.
 */
export async function scanJsonlDir(
  dirPath: string,
  options: ScanJsonlDirOptions = {},
): Promise<SessionIndexEntry[]> {
  const scanStats = options.stats;

  let files: string[];
  try {
    files = await readdir(dirPath);
  } catch {
    return [];
  }

  // Filter to JSONL files and apply exclusions
  const targets: Array<{ sessionId: string; filePath: string }> = [];
  for (const file of files) {
    if (!file.endsWith(".jsonl")) continue;
    scanStats && (scanStats.filesTotal += 1);

    const sessionId = basename(file, ".jsonl");
    if (options.excludeSessionIds?.has(sessionId)) {
      scanStats && (scanStats.filesExcluded += 1);
      continue;
    }
    targets.push({ sessionId, filePath: join(dirPath, file) });
  }

  // Read and parse files in parallel using fast head+tail reads
  const results = await parallelMap(
    targets,
    PARALLEL_FILE_READ_LIMIT,
    async ({ sessionId, filePath }) => {
      const entry = await parseClaudeJsonlFileFast(sessionId, filePath);
      if (entry) {
        scanStats && (scanStats.filesRead += 1);
        scanStats && (scanStats.entriesReturned += 1);
      } else {
        scanStats && (scanStats.filesRead += 1);
      }
      return entry;
    },
  );

  return results.filter((e): e is SessionIndexEntry => e !== null);
}

export async function getAllRecentSessions(
  options: GetRecentSessionsOptions = {},
): Promise<GetRecentSessionsResult> {
  const totalStartedAt = process.hrtime.bigint();
  const durations: Record<string, number> = {};
  const perfStats = createRecentSessionsPerfStats();

  const limit = options.limit ?? 20;
  const offset = options.offset ?? 0;
  const filterProjectPath = options.projectPath;
  const shouldLoadClaude = options.provider !== "codex";
  const shouldLoadCodex = options.provider !== "claude";
  const includeOnlyNamedClaude = options.namedOnly === true;

  const projectsDir = join(homedir(), ".claude", "projects");
  const entries: SessionIndexEntry[] = [];

  let projectDirs: string[];
  const loadProjectDirsStartedAt = process.hrtime.bigint();
  try {
    projectDirs = await readdir(projectsDir);
  } catch {
    // ~/.claude/projects doesn't exist
    projectDirs = [];
  }
  markDuration(durations, "loadClaudeProjectDirs", loadProjectDirsStartedAt);

  // Compute worktree slug prefix for projectPath filtering
  const projectSlug = filterProjectPath
    ? pathToSlug(filterProjectPath)
    : null;

  // --- Load Claude and Codex sessions in parallel ---

  const loadClaudeStartedAt = process.hrtime.bigint();
  const claudeEntriesPromise = (async (): Promise<SessionIndexEntry[]> => {
    if (!shouldLoadClaude) return [];

    // Filter directories first (sync), then process in parallel
    const relevantDirs: string[] = [];
    for (const dirName of projectDirs) {
      if (dirName.startsWith(".")) continue;
      const isProjectDir = projectSlug ? dirName === projectSlug : false;
      const isWorktreeDir = projectSlug
        ? isWorktreeSlug(dirName, projectSlug)
        : false;
      if (filterProjectPath && !isProjectDir && !isWorktreeDir) continue;
      relevantDirs.push(dirName);
    }
    perfStats.claudeProjectDirs = relevantDirs.length;

    // Process directories in parallel
    const dirResults = await parallelMap(
      relevantDirs,
      PARALLEL_FILE_READ_LIMIT,
      async (dirName) => {
        const dirPath = join(projectsDir, dirName);
        const indexPath = join(dirPath, "sessions-index.json");
        let raw: string | null = null;
        try {
          raw = await readFile(indexPath, "utf-8");
        } catch {
          // No sessions-index.json — will try JSONL scan for worktree dirs
        }

        const result: {
          entries: SessionIndexEntry[];
          indexDirs: number;
          indexEntries: number;
          jsonlOnlyDirs: number;
          jsonlStats: JsonlScanStats;
        } = {
          entries: [],
          indexDirs: 0,
          indexEntries: 0,
          jsonlOnlyDirs: 0,
          jsonlStats: { filesTotal: 0, filesExcluded: 0, filesRead: 0, entriesReturned: 0 },
        };

        if (raw !== null) {
          result.indexDirs = 1;

          let index: RawSessionIndexFile;
          try {
            index = JSON.parse(raw) as RawSessionIndexFile;
          } catch {
            console.error(`[sessions-index] Failed to parse ${indexPath}`);
            return result;
          }

          if (!Array.isArray(index.entries)) return result;

          const indexedIds = new Set<string>();
          for (const entry of index.entries) {
            const name = entry.customTitle || undefined;
            if (includeOnlyNamedClaude && (!name || name === "")) {
              continue;
            }

            indexedIds.add(entry.sessionId);
            const hydrated = await hydrateClaudeIndexedEntry(dirPath, entry);
            if (hydrated) {
              result.entries.push(hydrated);
              result.indexEntries += 1;
            }
          }

          if (!includeOnlyNamedClaude) {
            const scanned = await scanJsonlDir(dirPath, {
              excludeSessionIds: indexedIds,
              stats: result.jsonlStats,
            });
            result.entries.push(...scanned);
          } else {
            perfStats.claudeNamedOnlyFastPathUsed = true;
          }
        } else {
          if (includeOnlyNamedClaude) {
            perfStats.claudeNamedOnlyFastPathUsed = true;
            return result;
          }

          result.jsonlOnlyDirs = 1;
          const scanned = await scanJsonlDir(dirPath, { stats: result.jsonlStats });
          result.entries.push(...scanned);
        }

        return result;
      },
    );

    // Aggregate stats and entries
    const allEntries: SessionIndexEntry[] = [];
    for (const r of dirResults) {
      allEntries.push(...r.entries);
      perfStats.claudeIndexDirs += r.indexDirs;
      perfStats.claudeIndexEntries += r.indexEntries;
      perfStats.claudeJsonlOnlyDirs += r.jsonlOnlyDirs;
      perfStats.claudeJsonlFilesTotal += r.jsonlStats.filesTotal;
      perfStats.claudeJsonlFilesExcluded += r.jsonlStats.filesExcluded;
      perfStats.claudeJsonlFilesRead += r.jsonlStats.filesRead;
      perfStats.claudeJsonlEntries += r.jsonlStats.entriesReturned;
    }
    return allEntries;
  })();

  const loadCodexStartedAt = process.hrtime.bigint();
  const codexEntriesPromise = (async (): Promise<SessionIndexEntry[]> => {
    if (!shouldLoadCodex) return [];
    const codexPerf: CodexRecentPerfStats = {
      filesTotal: 0,
      filesRead: 0,
      entriesReturned: 0,
    };
    const codexEntries = await getAllRecentCodexSessions({
      projectPath: filterProjectPath,
      perfStats: codexPerf,
    });
    perfStats.codexFilesTotal = codexPerf.filesTotal;
    perfStats.codexFilesRead = codexPerf.filesRead;
    perfStats.codexEntries = codexPerf.entriesReturned;
    return codexEntries;
  })();

  // Wait for both Claude and Codex loading to complete in parallel
  const [claudeEntries, codexEntries] = await Promise.all([
    claudeEntriesPromise,
    codexEntriesPromise,
  ]);
  markDuration(durations, "loadClaudeSessions", loadClaudeStartedAt);
  markDuration(durations, "loadCodexSessions", loadCodexStartedAt);

  // Combine results and deduplicate by sessionId.
  // The same session can appear in both the main project dir and a worktree dir
  // (Claude CLI writes to both sessions-index.json files).  Keep the entry with
  // richer data (more non-empty fields) so the UI shows correct metadata.
  const combined = [...claudeEntries, ...codexEntries];
  const seen = new Map<string, SessionIndexEntry>();
  for (const entry of combined) {
    const existing = seen.get(entry.sessionId);
    if (!existing) {
      seen.set(entry.sessionId, entry);
    } else {
      // Pick the entry with more populated fields
      const score = (e: SessionIndexEntry): number =>
        (e.firstPrompt ? 1 : 0) +
        (e.gitBranch ? 1 : 0) +
        (e.created ? 1 : 0) +
        (e.modified ? 1 : 0) +
        (e.name ? 1 : 0) +
        (e.summary ? 1 : 0) +
        (e.lastPrompt ? 1 : 0);
      if (score(entry) > score(existing)) {
        seen.set(entry.sessionId, entry);
      }
    }
  }
  entries.push(...seen.values());

  // Filter out archived sessions
  const archivedIds = options.archivedSessionIds;
  let filtered = archivedIds
    ? entries.filter((e) => !archivedIds.has(e.sessionId))
    : [...entries];
  perfStats.counts.beforeArchive = entries.length;
  perfStats.counts.afterArchive = filtered.length;

  // Filter by provider
  if (options.provider) {
    filtered = filtered.filter((e) => e.provider === options.provider);
  }
  perfStats.counts.afterProvider = filtered.length;

  // Filter named only
  if (options.namedOnly) {
    filtered = filtered.filter((e) => e.name != null && e.name !== "");
  }
  perfStats.counts.afterNamedOnly = filtered.length;

  // Filter by search query (name, firstPrompt, lastPrompt, summary)
  if (options.searchQuery) {
    const q = options.searchQuery.toLowerCase();
    filtered = filtered.filter(
      (e) =>
        e.name?.toLowerCase().includes(q) ||
        e.firstPrompt?.toLowerCase().includes(q) ||
        e.lastPrompt?.toLowerCase().includes(q) ||
        e.summary?.toLowerCase().includes(q),
    );
  }
  perfStats.counts.afterSearch = filtered.length;

  // Sort by modified descending
  const sortStartedAt = process.hrtime.bigint();
  filtered.sort((a, b) => {
    const ta = new Date(a.modified).getTime();
    const tb = new Date(b.modified).getTime();
    return tb - ta;
  });
  markDuration(durations, "sortSessions", sortStartedAt);

  const paginateStartedAt = process.hrtime.bigint();
  const sliced = filtered.slice(offset, offset + limit);
  const hasMore = offset + limit < filtered.length;
  perfStats.counts.returned = sliced.length;
  markDuration(durations, "paginate", paginateStartedAt);

  // Supplement missing lastPrompt for Claude sessions (sessions-index.json
  // doesn't include lastPrompt).  Only the paginated page is processed so at
  // most `limit` tail reads are needed — lightweight enough to keep inline.
  const supplementStartedAt = process.hrtime.bigint();
  const needLastPrompt = sliced.filter(
    (e) => e.provider === "claude" && !e.lastPrompt && e.projectPath,
  );
  if (needLastPrompt.length > 0) {
    const projectsDir = join(homedir(), ".claude", "projects");
    await parallelMap(needLastPrompt, PARALLEL_FILE_READ_LIMIT, async (entry) => {
      const slug = pathToSlug(entry.projectPath);
      const jsonlPath = join(projectsDir, slug, `${entry.sessionId}.jsonl`);
      const lp = await extractLastPromptFromTail(jsonlPath);
      if (lp && lp !== entry.firstPrompt) {
        entry.lastPrompt = lp;
      }
    });
  }
  markDuration(durations, "supplementLastPrompt", supplementStartedAt);

  markDuration(durations, "total", totalStartedAt);
  logRecentSessionsPerf(options, durations, perfStats);

  return { sessions: sliced, hasMore };
}

interface CodexRecentOptions {
  projectPath?: string;
  perfStats?: CodexRecentPerfStats;
}

interface CodexRecentPerfStats {
  filesTotal: number;
  filesRead: number;
  entriesReturned: number;
}

export interface CodexSessionIndexMetadata {
  codexSettings?: SessionIndexEntry["codexSettings"];
  resumeCwd?: string;
}

interface CodexSessionParseResult {
  entry: SessionIndexEntry;
  threadId: string;
}

async function listCodexSessionFiles(): Promise<string[]> {
  const root = join(homedir(), ".codex", "sessions");
  const files: string[] = [];
  const stack = [root];

  while (stack.length > 0) {
    const dir = stack.pop()!;
    let children: Dirent[];
    try {
      children = await readdir(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const child of children) {
      const p = join(dir, child.name);
      if (child.isDirectory()) {
        stack.push(p);
      } else if (child.isFile() && p.endsWith(".jsonl")) {
        files.push(p);
      }
    }
  }

  return files;
}

function parseCodexSessionJsonl(raw: string, fallbackSessionId: string): CodexSessionParseResult | null {
  const lines = raw.split("\n");
  let threadId = fallbackSessionId;
  let projectPath = "";
  let resumeCwd = "";
  let gitBranch = "";
  let created = "";
  let modified = "";
  let firstPrompt = "";
  let lastPrompt = "";
  let summary = "";
  let hasMessages = false;
  let lastAssistantText = "";
  let agentNickname: string | undefined;
  let agentRole: string | undefined;
  // Settings extracted from the first turn_context entry
  let approvalPolicy: string | undefined;
  let approvalsReviewer: string | undefined;
  let sandboxMode: string | undefined;
  let model: string | undefined;
  let modelReasoningEffort: string | undefined;
  let networkAccessEnabled: boolean | undefined;
  let webSearchMode: string | undefined;

  for (const line of lines) {
    if (!line.trim()) continue;
    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      const partial = parsePartialCodexLine(line);
      if (partial.timestamp) {
        if (!created) created = partial.timestamp;
        modified = partial.timestamp;
      }
      if (partial.userMessage !== undefined) {
        hasMessages = true;
        if (!firstPrompt) firstPrompt = partial.userMessage;
        lastPrompt = partial.userMessage;
      }
      if (partial.assistantText) {
        hasMessages = true;
        lastAssistantText = partial.assistantText;
      }
      continue;
    }

    const timestamp = entry.timestamp as string | undefined;
    if (timestamp) {
      if (!created) created = timestamp;
      modified = timestamp;
    }

    if (entry.type === "session_meta") {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (payload) {
        if (isCodexInternalSessionSource(payload.source)) {
          return null;
        }
        if (typeof payload.id === "string" && payload.id.length > 0) {
          threadId = payload.id;
        }
        if (typeof payload.cwd === "string" && payload.cwd.length > 0) {
          resumeCwd = payload.cwd;
          projectPath = normalizeWorktreePath(payload.cwd);
        }
        const git = payload.git as Record<string, unknown> | undefined;
        if (git && typeof git.branch === "string") {
          gitBranch = git.branch;
        }
        if (typeof payload.agent_nickname === "string" && payload.agent_nickname.length > 0) {
          agentNickname = payload.agent_nickname;
        }
        if (typeof payload.agent_role === "string" && payload.agent_role.length > 0) {
          agentRole = payload.agent_role;
        }
      }
      continue;
    }

    // Extract codex settings from turn_context.
    // Always update (no guard) so the **last** turn_context wins — this is
    // important when sandbox mode or other settings change mid-session.
    if (entry.type === "turn_context") {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (payload) {
        if (typeof payload.approval_policy === "string") {
          approvalPolicy = payload.approval_policy;
        }
        if (typeof payload.approvals_reviewer === "string") {
          approvalsReviewer = payload.approvals_reviewer;
        }
        const sp = payload.sandbox_policy as Record<string, unknown> | undefined;
        if (sp && typeof sp.type === "string") {
          sandboxMode = sp.type;
        }
        if (typeof payload.model === "string") {
          model = payload.model;
        }
        const collaborationMode = payload.collaboration_mode as Record<string, unknown> | undefined;
        const collaborationSettings = collaborationMode?.settings as Record<string, unknown> | undefined;
        if (typeof collaborationSettings?.reasoning_effort === "string") {
          modelReasoningEffort = collaborationSettings.reasoning_effort;
        }
        if (typeof sp?.network_access === "boolean") {
          networkAccessEnabled = sp.network_access;
        }
        if (typeof payload.web_search === "string") {
          webSearchMode = payload.web_search;
        }
      }
      continue;
    }

    if (entry.type === "event_msg") {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (payload?.type === "user_message" && typeof payload.message === "string") {
        hasMessages = true;
        if (!firstPrompt) firstPrompt = payload.message;
        lastPrompt = payload.message;
      } else if (
        payload?.type === "agent_message"
        && typeof payload.message === "string"
        && payload.message.trim().length > 0
      ) {
        hasMessages = true;
        lastAssistantText = payload.message;
      }
      continue;
    }

    if (entry.type === "response_item") {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (!payload || payload.type !== "message" || payload.role !== "assistant") {
        continue;
      }
      const content = payload.content;
      if (!Array.isArray(content)) continue;
      const text = (content as Array<Record<string, unknown>>)
        .filter((item) => item.type === "output_text" && typeof item.text === "string")
        .map((item) => item.text as string)
        .join("\n")
        .trim();
      if (text.length > 0) {
        hasMessages = true;
        lastAssistantText = text;
      }
    }
  }

  if (model === "codex-auto-review") return null;
  if (isCodexAutoRenameSession(firstPrompt, model)) return null;
  if (!projectPath || !hasMessages) return null;
  summary = lastAssistantText || summary;

  const codexSettings = (
    approvalPolicy
    || approvalsReviewer
    || sandboxMode
    || model
    || modelReasoningEffort
    || networkAccessEnabled !== undefined
    || webSearchMode
  )
    ? {
        approvalPolicy,
        approvalsReviewer,
        sandboxMode,
        model,
        modelReasoningEffort,
        networkAccessEnabled,
        webSearchMode,
      }
    : undefined;

  return {
    threadId,
    entry: {
      sessionId: threadId,
      provider: "codex",
      ...(agentNickname ? { agentNickname } : {}),
      ...(agentRole ? { agentRole } : {}),
      summary: summary || undefined,
      firstPrompt,
      ...(lastPrompt && lastPrompt !== firstPrompt ? { lastPrompt } : {}),
      created,
      modified,
      gitBranch,
      projectPath,
      ...(resumeCwd && resumeCwd !== projectPath ? { resumeCwd } : {}),
      isSidechain: false,
      codexSettings,
    },
  };
}

/**
 * Fast parse a Codex JSONL file for recent-session list metadata.
 * The first chunk contains session_meta / first prompt; the tail chunk contains
 * the latest prompt, latest assistant summary, and modified timestamp.
 */
async function parseCodexSessionJsonlFast(
  filePath: string,
  fallbackSessionId: string,
): Promise<CodexSessionParseResult | null> {
  let fh;
  try {
    fh = await open(filePath, "r");
  } catch {
    return null;
  }

  try {
    const fileStat = await fh.stat();
    const fileSize = fileStat.size;
    if (fileSize === 0) return null;

    if (fileSize <= CODEX_HEAD_BYTES + CODEX_TAIL_BYTES) {
      const buf = Buffer.alloc(fileSize);
      await fh.read(buf, 0, fileSize, 0);
      return parseCodexSessionJsonl(buf.toString("utf-8"), fallbackSessionId);
    }

    const headBuf = Buffer.alloc(CODEX_HEAD_BYTES);
    await fh.read(headBuf, 0, CODEX_HEAD_BYTES, 0);

    const tailBuf = Buffer.alloc(CODEX_TAIL_BYTES);
    await fh.read(tailBuf, 0, CODEX_TAIL_BYTES, fileSize - CODEX_TAIL_BYTES);
    const tailRaw = tailBuf.toString("utf-8");
    const firstNewline = tailRaw.indexOf("\n");
    const cleanTail = firstNewline >= 0 ? tailRaw.slice(firstNewline + 1) : "";

    const partialRaw = `${headBuf.toString("utf-8")}\n${cleanTail}`;
    return parseCodexSessionJsonl(partialRaw, fallbackSessionId);
  } finally {
    await fh.close();
  }
}

function isCodexInternalSessionSource(source: unknown): boolean {
  const sourceObj = asObject(source);
  return sourceObj?.subagent !== undefined;
}

/**
 * Look up the saved name (customTitle) for a Claude Code session.
 * Returns the name if found, or undefined.
 */
export async function getClaudeSessionName(
  projectPath: string,
  claudeSessionId: string,
): Promise<string | undefined> {
  const slug = pathToSlug(projectPath);
  const indexPath = join(homedir(), ".claude", "projects", slug, "sessions-index.json");

  let raw: string;
  try {
    raw = await readFile(indexPath, "utf-8");
  } catch {
    return undefined;
  }

  let index: RawSessionIndexFile;
  try {
    index = JSON.parse(raw) as RawSessionIndexFile;
  } catch {
    return undefined;
  }

  if (!Array.isArray(index.entries)) return undefined;

  const entry = index.entries.find((e) => e.sessionId === claudeSessionId);
  return entry?.customTitle || undefined;
}

/**
 * Rename a Claude Code session by writing customTitle to sessions-index.json.
 * This is the same mechanism the CLI uses for /rename.
 */
export async function renameClaudeSession(
  projectPath: string,
  claudeSessionId: string,
  name: string | null,
): Promise<boolean> {
  const slug = pathToSlug(projectPath);
  const dirPath = join(homedir(), ".claude", "projects", slug);
  const indexPath = join(dirPath, "sessions-index.json");

  let index: RawSessionIndexFile | null = null;
  try {
    const raw = await readFile(indexPath, "utf-8");
    index = JSON.parse(raw) as RawSessionIndexFile;
  } catch {
    // File doesn't exist or is invalid — will create below if needed
  }

  if (index && Array.isArray(index.entries)) {
    const entry = index.entries.find((e) => e.sessionId === claudeSessionId);
    if (entry) {
      if (name) {
        entry.customTitle = name;
      } else {
        delete entry.customTitle;
      }
      await writeFile(indexPath, JSON.stringify(index, null, 2), "utf-8");
      return true;
    }
  }

  // Entry not found in index (or index doesn't exist yet).
  // The CLI may not have created the index entry for short-lived or new sessions.
  // Create a minimal entry so customTitle is persisted and picked up by
  // getAllRecentSessions() on next read.
  if (!name) return false; // Nothing to persist when clearing name

  if (!index || !Array.isArray(index.entries)) {
    index = { version: 1, entries: [] };
  }

  // Build a minimal entry from the JSONL file if available
  const jsonlPath = join(dirPath, `${claudeSessionId}.jsonl`);
  let firstPrompt = "";
  let created = new Date().toISOString();
  let modified = created;
  let gitBranch = "";
  try {
    const raw = await readFile(jsonlPath, "utf-8");
    for (const line of raw.split("\n")) {
      if (!line.trim()) continue;
      try {
        const entry = JSON.parse(line) as Record<string, unknown>;
        const type = entry.type as string;
        if (type !== "user" && type !== "assistant") continue;
        const ts = entry.timestamp as string | undefined;
        if (ts) {
          if (!firstPrompt) created = ts;
          modified = ts;
        }
        if (!gitBranch && entry.gitBranch) gitBranch = entry.gitBranch as string;
        if (type === "user" && !firstPrompt) {
          const msg = entry.message as { content?: unknown } | undefined;
          if (msg?.content) {
            if (typeof msg.content === "string") firstPrompt = msg.content;
            else if (Array.isArray(msg.content)) {
              const tb = (msg.content as Array<{ type: string; text?: string }>)
                .find((c) => c.type === "text" && c.text);
              if (tb?.text) firstPrompt = tb.text;
            }
          }
        }
      } catch { /* skip malformed lines */ }
    }
  } catch { /* JSONL not available */ }

  index.entries.push({
    sessionId: claudeSessionId,
    fullPath: jsonlPath,
    fileMtime: Date.now(),
    firstPrompt,
    customTitle: name,
    messageCount: 0,
    created,
    modified,
    gitBranch,
    projectPath,
    isSidechain: false,
  });

  // Ensure directory exists (may not for brand-new projects)
  const { mkdir } = await import("node:fs/promises");
  await mkdir(dirPath, { recursive: true });
  await writeFile(indexPath, JSON.stringify(index, null, 2), "utf-8");
  return true;
}

/**
 * Read the Codex session_index.jsonl and build a threadId → name map.
 */
export async function loadCodexSessionNames(): Promise<Map<string, string>> {
  const indexPath = join(homedir(), ".codex", "session_index.jsonl");
  const names = new Map<string, string>();

  let raw: string;
  try {
    raw = await readFile(indexPath, "utf-8");
  } catch {
    return names;
  }

  // Append-only: later entries override earlier ones for the same id
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      const entry = JSON.parse(line) as { id?: string; thread_name?: string };
      if (entry.id && entry.thread_name) {
        names.set(entry.id, entry.thread_name);
      }
    } catch {
      // skip malformed
    }
  }

  return names;
}

export async function loadCodexSessionProfiles(): Promise<Map<string, string>> {
  const path = join(homedir(), ".codex", "ccpocket-session-profiles.json");
  let raw: string;
  try {
    raw = await readFile(path, "utf-8");
  } catch {
    return new Map();
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    return new Map();
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return new Map();
  }

  const profiles = new Map<string, string>();
  for (const [threadId, profile] of Object.entries(
    parsed as Record<string, unknown>,
  )) {
    if (typeof profile === "string" && profile.trim().length > 0) {
      profiles.set(threadId, profile.trim());
    }
  }
  return profiles;
}

export async function saveCodexSessionProfile(
  threadId: string,
  profile: string | null,
): Promise<void> {
  const path = join(homedir(), ".codex", "ccpocket-session-profiles.json");
  const existing = await loadCodexSessionProfiles();
  if (profile && profile.trim().length > 0) {
    existing.set(threadId, profile.trim());
  } else {
    existing.delete(threadId);
  }
  const next = Object.fromEntries(existing.entries());
  await writeFile(path, JSON.stringify(next, null, 2), "utf-8");
}

export async function loadCodexSessionAdditionalWritableRoots(): Promise<
  Map<string, string[]>
> {
  const path = join(
    homedir(),
    ".codex",
    "ccpocket-session-additional-writable-roots.json",
  );
  let raw: string;
  try {
    raw = await readFile(path, "utf-8");
  } catch {
    return new Map();
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    return new Map();
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return new Map();
  }

  const rootsByThread = new Map<string, string[]>();
  for (const [threadId, roots] of Object.entries(
    parsed as Record<string, unknown>,
  )) {
    const normalized = sanitizeAdditionalWritableRoots(roots);
    if (normalized.length > 0) {
      rootsByThread.set(threadId, normalized);
    }
  }
  return rootsByThread;
}

export async function saveCodexSessionAdditionalWritableRoots(
  threadId: string,
  roots: string[] | null,
): Promise<void> {
  const path = join(
    homedir(),
    ".codex",
    "ccpocket-session-additional-writable-roots.json",
  );
  const existing = await loadCodexSessionAdditionalWritableRoots();
  const normalized = sanitizeAdditionalWritableRoots(roots);
  if (normalized.length > 0) {
    existing.set(threadId, normalized);
  } else {
    existing.delete(threadId);
  }
  const next = Object.fromEntries(existing.entries());
  await writeFile(path, JSON.stringify(next, null, 2), "utf-8");
}

function sanitizeAdditionalWritableRoots(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const roots = new Map<string, string>();
  for (const root of value) {
    if (typeof root !== "string") continue;
    const trimmed = root.trim();
    if (!trimmed) continue;
    if (!roots.has(trimmed)) {
      roots.set(trimmed, trimmed);
    }
  }
  return [...roots.values()];
}

/**
 * Rename a Codex session by appending to ~/.codex/session_index.jsonl.
 * Passing `null` or empty name writes an empty thread_name to effectively clear it.
 */
export async function renameCodexSession(
  threadId: string,
  name: string | null,
): Promise<boolean> {
  try {
    const indexPath = join(homedir(), ".codex", "session_index.jsonl");
    const entry = JSON.stringify({
      id: threadId,
      thread_name: name ?? "",
      updated_at: new Date().toISOString(),
    });
    await appendFile(indexPath, entry + "\n");
    return true;
  } catch {
    return false;
  }
}

async function getAllRecentCodexSessions(options: CodexRecentOptions = {}): Promise<SessionIndexEntry[]> {
  const files = await listCodexSessionFiles();
  const entries: SessionIndexEntry[] = [];
  options.perfStats && (options.perfStats.filesTotal = files.length);
  const normalizedProjectPath = options.projectPath
    ? normalizeWorktreePath(options.projectPath)
    : null;

  // Load thread names from session_index.jsonl
  const threadNames = await loadCodexSessionNames();
  const threadProfiles = await loadCodexSessionProfiles();
  const threadAdditionalWritableRoots =
    await loadCodexSessionAdditionalWritableRoots();

  const parsedResults = await parallelMap(
    files,
    PARALLEL_FILE_READ_LIMIT,
    async (filePath) => {
      const fallbackSessionId = basename(filePath, ".jsonl");
      return parseCodexSessionJsonlFast(filePath, fallbackSessionId);
    },
  );

  for (const parsed of parsedResults) {
    options.perfStats && (options.perfStats.filesRead += 1);
    if (!parsed) continue;
    if (normalizedProjectPath && parsed.entry.projectPath !== normalizedProjectPath) {
      continue;
    }
    // Attach thread name if available
    const threadName = threadNames.get(parsed.threadId);
    if (threadName) {
      parsed.entry.name = threadName;
    }
    const threadProfile = threadProfiles.get(parsed.threadId);
    if (threadProfile) {
      parsed.entry.codexSettings = {
        ...(parsed.entry.codexSettings ?? {}),
        profile: threadProfile,
      };
    }
    const additionalWritableRoots = threadAdditionalWritableRoots.get(
      parsed.threadId,
    );
    if (additionalWritableRoots) {
      parsed.entry.codexSettings = {
        ...(parsed.entry.codexSettings ?? {}),
        additionalWritableRoots,
      };
    }
    entries.push(parsed.entry);
    options.perfStats && (options.perfStats.entriesReturned += 1);
  }

  return entries;
}

function matchingCodexThreadIdFromFilePath(
  filePath: string,
  wantedThreadIds: ReadonlySet<string>,
): string | null {
  const fallbackSessionId = basename(filePath, ".jsonl");
  if (wantedThreadIds.has(fallbackSessionId)) return fallbackSessionId;
  for (const threadId of wantedThreadIds) {
    if (fallbackSessionId.endsWith(`-${threadId}`)) return threadId;
  }
  return null;
}

export async function getCodexSessionIndexMetadata(
  threadIds: readonly string[],
): Promise<Map<string, CodexSessionIndexMetadata>> {
  const wantedThreadIds = new Set(threadIds.filter((id) => id.length > 0));
  const result = new Map<string, CodexSessionIndexMetadata>();
  if (wantedThreadIds.size === 0) return result;

  const files = await listCodexSessionFiles();
  const targets: string[] = [];
  const matchedThreadIds = new Set<string>();
  for (const filePath of files) {
    const threadId = matchingCodexThreadIdFromFilePath(filePath, wantedThreadIds);
    if (!threadId || matchedThreadIds.has(threadId)) continue;
    targets.push(filePath);
    matchedThreadIds.add(threadId);
    if (matchedThreadIds.size === wantedThreadIds.size) break;
  }

  const parsedResults = await parallelMap(
    targets,
    PARALLEL_FILE_READ_LIMIT,
    async (filePath) => {
      const fallbackSessionId = basename(filePath, ".jsonl");
      return parseCodexSessionJsonlFast(filePath, fallbackSessionId);
    },
  );

  for (const parsed of parsedResults) {
    if (!parsed || !wantedThreadIds.has(parsed.threadId)) continue;
    result.set(parsed.threadId, {
      ...(parsed.entry.codexSettings
        ? { codexSettings: parsed.entry.codexSettings }
        : {}),
      ...(parsed.entry.resumeCwd ? { resumeCwd: parsed.entry.resumeCwd } : {}),
    });
  }

  return result;
}

// ---- Session history from JSONL files ----

type SessionHistoryContentItem = {
  type: string;
  text?: string;
  thinking?: string;
  id?: string;
  name?: string;
  input?: Record<string, unknown>;
};

export interface SessionHistoryMessage {
  role: "user" | "assistant" | "tool_result";
  uuid?: string;
  timestamp?: string;
  /** Skill loading prompt or other meta message (rendered as a chip). */
  isMeta?: boolean;
  /** Number of images attached to this user message (for display indicator). */
  imageCount?: number;
  toolUseId?: string;
  toolName?: string;
  imagePaths?: string[];
  imageBase64?: Array<{ data: string; mimeType: string }>;
  content: string | SessionHistoryContentItem[];
}

export function codexUserTurnUuid(ordinal: number): string {
  return `codex:user-turn:${ordinal}`;
}

export function isCodexUserTurnUuid(uuid: string | undefined): uuid is string {
  return typeof uuid === "string" && /^codex:user-turn:\d+$/.test(uuid);
}

function numberToIsoTimestamp(value: unknown): string | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? new Date(value * 1000).toISOString()
    : undefined;
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function arrayValue(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function codexToolResultContent(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string") return value;
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

function codexUserInputTextAndImages(content: unknown): {
  text: string;
  imageCount: number;
} {
  const textParts: string[] = [];
  let imageCount = 0;

  for (const entry of arrayValue(content)) {
    const item = asObject(entry);
    if (!item) continue;
    if (item.type === "text" && typeof item.text === "string") {
      textParts.push(item.text);
    } else if (item.type === "image" || item.type === "localImage") {
      imageCount += 1;
    }
  }

  return { text: textParts.join("\n"), imageCount };
}

function appendCodexThinkingMessage(
  messages: SessionHistoryMessage[],
  text: string,
  timestamp?: string,
): void {
  const normalized = text.trim();
  if (!normalized) return;
  messages.push({
    role: "assistant",
    content: [{ type: "thinking", thinking: normalized }],
    ...(timestamp ? { timestamp } : {}),
  });
}

function appendCodexOfficialToolResult(
  messages: SessionHistoryMessage[],
  id: string,
  name: string | undefined,
  content: string,
  timestamp?: string,
): void {
  appendToolResultMessage(messages, id, name, content, {
    ...(timestamp ? { timestamp } : {}),
  });
}

export function codexThreadToSessionHistory(
  thread: unknown,
): SessionHistoryMessage[] {
  const messages: SessionHistoryMessage[] = [];
  const turns = arrayValue(asObject(thread)?.turns);
  let userTurnOrdinal = 0;

  for (const rawTurn of turns) {
    const turn = asObject(rawTurn);
    if (!turn) continue;
    const turnStartedAt = numberToIsoTimestamp(turn.startedAt);
    const turnCompletedAt = numberToIsoTimestamp(turn.completedAt);

    for (const rawItem of arrayValue(turn.items)) {
      const item = asObject(rawItem);
      if (!item || typeof item.type !== "string") continue;
      const itemId = stringValue(item.id) ?? `codex-item-${messages.length}`;
      const itemTimestamp = turnCompletedAt ?? turnStartedAt;

      switch (item.type) {
        case "userMessage": {
          const { text, imageCount } = codexUserInputTextAndImages(
            item.content,
          );
          const displayText =
            text.trim().length > 0
              ? text
              : imageCount > 0
                ? `[Image attached${imageCount > 1 ? ` x${imageCount}` : ""}]`
                : "";
          if (displayText.trim().length === 0) break;
          userTurnOrdinal += 1;
          messages.push({
            role: "user",
            uuid: codexUserTurnUuid(userTurnOrdinal),
            content: [{ type: "text", text: displayText }],
            ...(imageCount > 0 ? { imageCount } : {}),
            ...(turnStartedAt ? { timestamp: turnStartedAt } : {}),
          });
          break;
        }

        case "agentMessage": {
          appendTextMessage(
            messages,
            "assistant",
            stringValue(item.text) ?? "",
            itemTimestamp,
          );
          break;
        }

        case "plan": {
          appendTextMessage(
            messages,
            "assistant",
            stringValue(item.text) ?? "",
            itemTimestamp,
          );
          break;
        }

        case "reasoning": {
          const summary = arrayValue(item.summary)
            .filter((value): value is string => typeof value === "string");
          const content = arrayValue(item.content)
            .filter((value): value is string => typeof value === "string");
          appendCodexThinkingMessage(
            messages,
            [...summary, ...content].join("\n"),
            itemTimestamp,
          );
          break;
        }

        case "commandExecution": {
          const command = stringValue(item.command) ?? "";
          appendToolUseMessage(messages, itemId, "Bash", {
            command,
            ...(typeof item.cwd === "string" ? { cwd: item.cwd } : {}),
          });
          const outputParts: string[] = [];
          if (typeof item.status === "string") {
            outputParts.push(`status: ${item.status}`);
          }
          if (typeof item.exitCode === "number") {
            outputParts.push(`exitCode: ${item.exitCode}`);
          }
          if (typeof item.aggregatedOutput === "string") {
            outputParts.push(item.aggregatedOutput);
          }
          appendCodexOfficialToolResult(
            messages,
            itemId,
            "Bash",
            outputParts.join("\n").trim(),
            itemTimestamp,
          );
          break;
        }

        case "fileChange": {
          appendToolUseMessage(messages, itemId, "FileChange", {
            changes: Array.isArray(item.changes) ? item.changes : [],
            ...(typeof item.status === "string" ? { status: item.status } : {}),
          });
          break;
        }

        case "mcpToolCall": {
          const server = stringValue(item.server) ?? "mcp";
          const tool = stringValue(item.tool) ?? "tool";
          appendToolUseMessage(messages, itemId, `mcp:${server}/${tool}`, {
            arguments: item.arguments ?? {},
            ...(typeof item.status === "string" ? { status: item.status } : {}),
          });
          if (item.result != null || item.error != null) {
            const normalized = normalizeCodexMcpResult(item.result ?? item.error);
            appendToolResultMessage(
              messages,
              itemId,
              `mcp:${server}/${tool}`,
              normalized.content,
              {
                imageBase64: normalized.imageBase64,
                ...(itemTimestamp ? { timestamp: itemTimestamp } : {}),
              },
            );
          }
          break;
        }

        case "dynamicToolCall": {
          const tool = stringValue(item.tool) ?? "tool";
          appendToolUseMessage(messages, itemId, tool, {
            arguments: item.arguments ?? {},
            ...(typeof item.status === "string" ? { status: item.status } : {}),
          });
          const contentItems = arrayValue(item.contentItems);
          const resultText = contentItems
            .map((entry) => {
              const contentItem = asObject(entry);
              if (!contentItem) return "";
              if (
                contentItem.type === "inputText" &&
                typeof contentItem.text === "string"
              ) {
                return contentItem.text;
              }
              if (
                contentItem.type === "inputImage" &&
                typeof contentItem.imageUrl === "string"
              ) {
                return contentItem.imageUrl;
              }
              return codexToolResultContent(contentItem);
            })
            .filter(Boolean)
            .join("\n");
          appendCodexOfficialToolResult(
            messages,
            itemId,
            tool,
            resultText,
            itemTimestamp,
          );
          break;
        }

        case "webSearch": {
          appendToolUseMessage(messages, itemId, "WebSearch", {
            query: stringValue(item.query) ?? "",
            ...(item.action != null ? { action: item.action } : {}),
          });
          break;
        }

        case "imageGeneration": {
          appendToolUseMessage(messages, itemId, "ImageGeneration", {
            ...(typeof item.status === "string" ? { status: item.status } : {}),
            ...(typeof item.revisedPrompt === "string"
              ? { revisedPrompt: item.revisedPrompt }
              : {}),
          });
          appendImageGenerationResult(
            messages,
            {
              id: itemId,
              status: item.status,
              revisedPrompt: item.revisedPrompt,
              savedPath: item.savedPath,
              result: item.result,
            },
            itemId,
            itemTimestamp,
          );
          break;
        }

        case "enteredReviewMode":
        case "exitedReviewMode": {
          appendTextMessage(
            messages,
            "assistant",
            stringValue(item.review) ?? "",
            itemTimestamp,
          );
          break;
        }

        default:
          break;
      }
    }
  }

  return messages;
}

function asObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function parseObjectLike(value: unknown): Record<string, unknown> {
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value) as unknown;
      return asObject(parsed) ?? { value: parsed };
    } catch {
      return { value };
    }
  }
  return asObject(value) ?? {};
}

function appendTextMessage(
  messages: SessionHistoryMessage[],
  role: "user" | "assistant",
  text: string,
  timestamp?: string,
  uuid?: string,
): boolean {
  const normalized = text.trim();
  if (!normalized) return false;

  const last = messages.at(-1);
  if (
    last
    && last.role === role
    && Array.isArray(last.content)
    && last.content.length === 1
    && last.content[0].type === "text"
    && typeof last.content[0].text === "string"
    && last.content[0].text.trim() === normalized
  ) {
    return false;
  }

  messages.push({
    role,
    ...(uuid ? { uuid } : {}),
    content: [{ type: "text", text }],
    ...(timestamp ? { timestamp } : {}),
  });
  return true;
}

function countCodexUserTurns(messages: SessionHistoryMessage[]): number {
  return messages.filter((message) => message.role === "user" && !message.isMeta)
    .length;
}

function applyCodexThreadRollback(
  messages: SessionHistoryMessage[],
  numTurns: number,
): void {
  if (!Number.isFinite(numTurns) || numTurns <= 0) return;

  const userIndices = messages
    .map((message, index) =>
      message.role === "user" && !message.isMeta ? index : -1,
    )
    .filter((index) => index >= 0);
  if (userIndices.length === 0) return;
  if (numTurns >= userIndices.length) {
    messages.length = 0;
    return;
  }

  const keepUserTurns = userIndices.length - numTurns;
  const cutIndex = userIndices[keepUserTurns];
  messages.splice(cutIndex);
}

function appendImageGenerationResult(
  messages: SessionHistoryMessage[],
  payload: Record<string, unknown>,
  fallbackId: string,
  timestamp?: string,
): void {
  const id =
    typeof payload.call_id === "string"
      ? payload.call_id
      : typeof payload.id === "string"
        ? payload.id
        : fallbackId;
  if (messages.some((m) => m.role === "tool_result" && m.toolUseId === id)) {
    return;
  }

  const status = typeof payload.status === "string" ? payload.status : undefined;
  const revisedPrompt =
    typeof payload.revised_prompt === "string"
      ? payload.revised_prompt
      : typeof payload.revisedPrompt === "string"
        ? payload.revisedPrompt
        : undefined;
  const savedPath =
    typeof payload.saved_path === "string"
      ? payload.saved_path
      : typeof payload.savedPath === "string"
        ? payload.savedPath
        : undefined;
  const result = typeof payload.result === "string" ? payload.result : undefined;
  const base64Image =
    !savedPath && result
      ? { data: stripImageDataUrlPrefix(result), mimeType: "image/png" }
      : undefined;

  const contentLines: string[] = [];
  if (status) contentLines.push(`status: ${status}`);
  if (revisedPrompt) contentLines.push(`revisedPrompt: ${revisedPrompt}`);
  if (savedPath) contentLines.push(`savedPath: ${savedPath}`);

  messages.push({
    role: "tool_result",
    toolUseId: id,
    toolName: "ImageGeneration",
    content: contentLines.join("\n"),
    ...(savedPath ? { imagePaths: [savedPath] } : {}),
    ...(base64Image ? { imageBase64: [base64Image] } : {}),
    ...(timestamp ? { timestamp } : {}),
  });
}

function stripImageDataUrlPrefix(value: string): string {
  const match = value.match(/^data:image\/[a-z0-9.+-]+;base64,(.*)$/i);
  return match?.[1] ?? value;
}

function appendToolResultMessage(
  messages: SessionHistoryMessage[],
  id: string,
  name: string | undefined,
  content: string,
  options?: {
    imageBase64?: Array<{ data: string; mimeType: string }>;
    timestamp?: string;
  },
): void {
  if (messages.some((m) => m.role === "tool_result" && m.toolUseId === id)) {
    return;
  }

  const imageBase64 = options?.imageBase64 ?? [];
  if (!content.trim() && imageBase64.length === 0) return;

  messages.push({
    role: "tool_result",
    toolUseId: id,
    ...(name ? { toolName: name } : {}),
    content,
    ...(imageBase64.length > 0 ? { imageBase64 } : {}),
    ...(options?.timestamp ? { timestamp: options.timestamp } : {}),
  });
}

function appendToolUseMessage(
  messages: SessionHistoryMessage[],
  id: string,
  name: string,
  input: Record<string, unknown>,
): void {
  const normalizedName = name.trim();
  if (!normalizedName) return;

  const last = messages.at(-1);
  if (
    last
    && last.role === "assistant"
    && Array.isArray(last.content)
    && last.content.length === 1
    && last.content[0].type === "tool_use"
    && last.content[0].id === id
    && last.content[0].name === normalizedName
  ) {
    return;
  }

  messages.push({
    role: "assistant",
    content: [
      {
        type: "tool_use",
        id,
        name: normalizedName,
        input,
      },
    ],
  });
}

function normalizeCodexToolName(name: string): string {
  if (name === "exec_command" || name === "write_stdin") {
    return "Bash";
  }

  // Codex function names for MCP tools look like: mcp__server__tool_name
  if (name.startsWith("mcp__")) {
    const [server, ...toolParts] = name.slice("mcp__".length).split("__");
    if (server && toolParts.length > 0) {
      return `mcp:${server}/${toolParts.join("__")}`;
    }
  }

  return name;
}

function normalizeCodexMcpResult(result: unknown): {
  content: string;
  imageBase64: Array<{ data: string; mimeType: string }>;
} {
  const wrapper = asObject(result);
  let value = result;
  if (wrapper && Object.prototype.hasOwnProperty.call(wrapper, "Ok")) {
    value = wrapper.Ok;
  } else if (wrapper && Object.prototype.hasOwnProperty.call(wrapper, "Err")) {
    value = wrapper.Err;
  }

  if (typeof value === "string") {
    return { content: value, imageBase64: [] };
  }

  const record = asObject(value);
  const contentItems = Array.isArray(record?.content) ? record.content : null;
  if (!contentItems) {
    return {
      content: value == null ? "MCP call completed" : JSON.stringify(value),
      imageBase64: [],
    };
  }

  const textParts: string[] = [];
  const imageBase64: Array<{ data: string; mimeType: string }> = [];

  for (const entry of contentItems) {
    const item = asObject(entry);
    if (!item) continue;
    const type = typeof item.type === "string" ? item.type : "";

    if (type === "text" && typeof item.text === "string") {
      textParts.push(item.text);
      continue;
    }

    if (type === "image") {
      const source = asObject(item.source);
      const rawData =
        typeof item.data === "string"
          ? item.data
          : source?.type === "base64" && typeof source.data === "string"
            ? source.data
            : undefined;
      if (rawData) {
        const mimeType =
          typeof item.mimeType === "string"
            ? item.mimeType
            : typeof item.mediaType === "string"
              ? item.mediaType
              : typeof item.media_type === "string"
                ? item.media_type
                : typeof source?.media_type === "string"
                  ? source.media_type
                  : "image/png";
        imageBase64.push({
          data: stripImageDataUrlPrefix(rawData),
          mimeType,
        });
      }
      continue;
    }

    textParts.push(JSON.stringify(item));
  }

  const content = textParts.join("\n").trim();
  if (content) return { content, imageBase64 };

  if (imageBase64.length > 0) {
    return {
      content:
        imageBase64.length === 1
          ? "Generated 1 image"
          : `Generated ${imageBase64.length} images`,
      imageBase64,
    };
  }

  return {
    content: value == null ? "MCP call completed" : JSON.stringify(value),
    imageBase64,
  };
}

function isCodexInjectedUserContext(text: string): boolean {
  const normalized = text.trimStart();
  return (
    normalized.startsWith("# AGENTS.md instructions for ")
    || normalized.startsWith("<environment_context>")
    || normalized.startsWith("<permissions instructions>")
    || normalized.startsWith("<collaboration_mode>")
    || normalized.startsWith("<personality_spec>")
    || normalized.startsWith("<skills_instructions>")
    || normalized.startsWith("<plugins_instructions>")
    || normalized.startsWith("<skill>")
  );
}

function getCodexSearchInput(payload: Record<string, unknown>): Record<string, unknown> {
  const action = asObject(payload.action);
  const input: Record<string, unknown> = {};
  if (typeof action?.query === "string") {
    input.query = action.query;
  }
  if (Array.isArray(action?.queries)) {
    const queries = (action.queries as unknown[]).filter(
      (q): q is string => typeof q === "string" && q.length > 0,
    );
    if (queries.length > 0) {
      input.queries = queries;
    }
  }
  return input;
}

/**
 * Find the JSONL file path for a given sessionId by searching sessions-index.json files,
 * then falling back to scanning directories for the JSONL file directly.
 */
async function findSessionJsonlPath(sessionId: string): Promise<string | null> {
  const projectsDir = join(homedir(), ".claude", "projects");

  let projectDirs: string[];
  try {
    projectDirs = await readdir(projectsDir);
  } catch {
    return null;
  }

  // First pass: check sessions-index.json files
  for (const dirName of projectDirs) {
    if (dirName.startsWith(".")) continue;

    const indexPath = join(projectsDir, dirName, "sessions-index.json");
    let raw: string;
    try {
      raw = await readFile(indexPath, "utf-8");
    } catch {
      continue;
    }

    let index: RawSessionIndexFile;
    try {
      index = JSON.parse(raw) as RawSessionIndexFile;
    } catch {
      continue;
    }

    if (!Array.isArray(index.entries)) continue;

    const entry = index.entries.find((e) => e.sessionId === sessionId);
    if (entry?.fullPath) {
      return entry.fullPath;
    }
  }

  // Fallback: scan directories for the JSONL file directly
  // This handles worktree sessions without sessions-index.json
  const jsonlFileName = `${sessionId}.jsonl`;
  for (const dirName of projectDirs) {
    if (dirName.startsWith(".")) continue;

    const candidatePath = join(projectsDir, dirName, jsonlFileName);
    try {
      await stat(candidatePath);
      return candidatePath;
    } catch {
      continue;
    }
  }

  return null;
}

async function findCodexSessionJsonlPath(threadId: string): Promise<string | null> {
  const files = await listCodexSessionFiles();
  for (const filePath of files) {
    const fallbackSessionId = basename(filePath, ".jsonl");
    if (
      fallbackSessionId === threadId ||
      fallbackSessionId.endsWith(`-${threadId}`)
    ) {
      return filePath;
    }
    let raw: string;
    try {
      raw = await readFile(filePath, "utf-8");
    } catch {
      continue;
    }
    const parsed = parseCodexSessionJsonl(raw, fallbackSessionId);
    if (parsed?.threadId === threadId) {
      return filePath;
    }
  }
  return null;
}

/**
 * Read past conversation messages from a session's JSONL file.
 * Returns user and assistant messages suitable for display.
 */
export async function getSessionHistory(
  sessionId: string,
): Promise<SessionHistoryMessage[]> {
  const jsonlPath = await findSessionJsonlPath(sessionId);
  if (!jsonlPath) return [];

  let raw: string;
  try {
    raw = await readFile(jsonlPath, "utf-8");
  } catch {
    return [];
  }

  const messages: SessionHistoryMessage[] = [];
  const lines = raw.split("\n");

  for (const line of lines) {
    if (!line.trim()) continue;

    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }

    const type = entry.type as string;
    if (type !== "user" && type !== "assistant") continue;

    // Skip context compaction and transcript-only messages (not real user input)
    if (type === "user") {
      if (entry.isCompactSummary === true || entry.isVisibleInTranscriptOnly === true) {
        continue;
      }
    }

    const message = entry.message as
      | { role: string; content: unknown[] | string }
      | undefined;
    if (!message?.content) continue;

    const role = message.role as "user" | "assistant";
    const isMeta = role === "user" && entry.isMeta === true ? true : undefined;

    // Handle string content (e.g. user message after interrupt)
    if (typeof message.content === "string") {
      if (message.content) {
        const uuid = entry.uuid as string | undefined;
        const ts = entry.timestamp as string | undefined;
        messages.push({
          role,
          content: [{ type: "text" as const, text: message.content }],
          ...(uuid ? { uuid } : {}),
          ...(ts ? { timestamp: ts } : {}),
          ...(isMeta ? { isMeta } : {}),
        });
      }
      continue;
    }

    if (!Array.isArray(message.content)) continue;

    // Filter content to only text and tool_use (skip tool_result for cleaner display)
    const content: SessionHistoryContentItem[] = [];
    let imageCount = 0;
    for (const c of message.content) {
      if (typeof c !== "object" || c === null) continue;
      const item = c as Record<string, unknown>;
      const contentType = item.type as string;

      if (contentType === "text" && item.text) {
        content.push({ type: "text", text: item.text as string });
      } else if (contentType === "tool_use") {
        content.push({
          type: "tool_use",
          id: item.id as string,
          name: item.name as string,
          input: (item.input as Record<string, unknown>) ?? {},
        });
      } else if (contentType === "image") {
        imageCount++;
      }
    }

    if (content.length > 0 || imageCount > 0) {
      const uuid = entry.uuid as string | undefined;
      const ts = entry.timestamp as string | undefined;
      // If there are only images and no text, add a placeholder
      if (content.length === 0 && imageCount > 0) {
        content.push({
          type: "text",
          text: `[Image attached${imageCount > 1 ? ` x${imageCount}` : ""}]`,
        });
      }
      messages.push({
        role,
        content,
        ...(uuid ? { uuid } : {}),
        ...(ts ? { timestamp: ts } : {}),
        ...(isMeta ? { isMeta } : {}),
        ...(imageCount > 0 ? { imageCount } : {}),
      });
    }
  }

  return messages;
}

// ---- Extract full image data from JSONL for a specific message ----

export interface ExtractedImage {
  base64: string;
  mimeType: string;
}

interface CodexMessageImageIndex {
  jsonlPath: string;
  size: number;
  mtimeMs: number;
  imagesByUuid: Map<string, ExtractedImage[]>;
}

const CODEX_IMAGE_INDEX_CACHE_LIMIT = 8;
const codexMessageImageIndexCache = new Map<
  string,
  Promise<CodexMessageImageIndex | null>
>();

/**
 * Extract image base64 data from a Claude Code session JSONL for a specific message UUID.
 */
export async function extractMessageImages(
  sessionId: string,
  messageUuid: string,
): Promise<ExtractedImage[]> {
  if (isCodexMessageImageUuid(messageUuid)) {
    return extractCodexMessageImages(sessionId, messageUuid);
  }

  // Try Claude Code first, then Codex
  const claudeImages = await extractClaudeMessageImages(sessionId, messageUuid);
  if (claudeImages.length > 0) return claudeImages;

  return extractCodexMessageImages(sessionId, messageUuid);
}

async function extractClaudeMessageImages(
  sessionId: string,
  messageUuid: string,
): Promise<ExtractedImage[]> {
  const jsonlPath = await findSessionJsonlPath(sessionId);
  if (!jsonlPath) return [];

  let raw: string;
  try {
    raw = await readFile(jsonlPath, "utf-8");
  } catch {
    return [];
  }

  const lines = raw.split("\n");
  for (const line of lines) {
    if (!line.trim()) continue;

    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }

    if (entry.type !== "user") continue;
    if (entry.uuid !== messageUuid) continue;

    const message = entry.message as { content: unknown[] | string } | undefined;
    if (!message?.content || !Array.isArray(message.content)) continue;

    const images: ExtractedImage[] = [];
    for (const c of message.content) {
      if (typeof c !== "object" || c === null) continue;
      const item = c as Record<string, unknown>;
      if (item.type !== "image") continue;

      const source = item.source as Record<string, unknown> | undefined;
      if (!source || source.type !== "base64") continue;

      const data = source.data as string | undefined;
      const mediaType = source.media_type as string | undefined;
      if (data && mediaType) {
        images.push({ base64: data, mimeType: mediaType });
      }
    }
    return images;
  }

  return [];
}

async function extractCodexMessageImages(
  sessionId: string,
  messageUuid: string,
): Promise<ExtractedImage[]> {
  const index = await getCodexMessageImageIndex(sessionId);
  return index?.imagesByUuid.get(messageUuid) ?? [];
}

function isCodexMessageImageUuid(messageUuid: string): boolean {
  return (
    messageUuid.startsWith("codex:user-turn:") ||
    messageUuid.startsWith("codex-line-")
  );
}

async function getCodexMessageImageIndex(
  threadId: string,
): Promise<CodexMessageImageIndex | null> {
  const cached = codexMessageImageIndexCache.get(threadId);
  if (cached) {
    const index = await cached;
    if (index && (await isFreshCodexMessageImageIndex(index))) {
      return index;
    }
    codexMessageImageIndexCache.delete(threadId);
  }

  const promise = buildCodexMessageImageIndex(threadId);
  codexMessageImageIndexCache.set(threadId, promise);
  trimCodexMessageImageIndexCache();
  return promise;
}

async function isFreshCodexMessageImageIndex(
  index: CodexMessageImageIndex,
): Promise<boolean> {
  try {
    const current = await stat(index.jsonlPath);
    return current.size === index.size && current.mtimeMs === index.mtimeMs;
  } catch {
    return false;
  }
}

function trimCodexMessageImageIndexCache() {
  while (codexMessageImageIndexCache.size > CODEX_IMAGE_INDEX_CACHE_LIMIT) {
    const oldest = codexMessageImageIndexCache.keys().next().value;
    if (!oldest) return;
    codexMessageImageIndexCache.delete(oldest);
  }
}

async function buildCodexMessageImageIndex(
  threadId: string,
): Promise<CodexMessageImageIndex | null> {
  const jsonlPath = await findCodexSessionJsonlPath(threadId);
  if (!jsonlPath) return null;

  let fileStat;
  let raw: string;
  try {
    fileStat = await stat(jsonlPath);
    raw = await readFile(jsonlPath, "utf-8");
  } catch {
    return null;
  }

  const imagesByUuid = await collectCodexMessageImages(raw.split("\n"));
  return {
    jsonlPath,
    size: fileStat.size,
    mtimeMs: fileStat.mtimeMs,
    imagesByUuid,
  };
}

async function collectCodexMessageImages(
  lines: string[],
): Promise<Map<string, ExtractedImage[]>> {
  const imagesByUuid = new Map<string, ExtractedImage[]>();
  const responseItemImagesByOrdinal =
    collectCodexUserResponseItemImagesByOrdinal(lines);
  let ordinal = 0;

  for (const [lineIndex, line] of lines.entries()) {
    if (!line.trim()) continue;

    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }

    if (entry.type !== "event_msg") continue;
    const payload = asObject(entry.payload);
    if (!payload || payload.type !== "user_message") continue;

    const lineImages = await extractCodexUserMessagePayloadImages(payload);
    imagesByUuid.set(`codex-line-${lineIndex}`, lineImages);

    if (!codexUserMessagePayloadHasDisplayContent(payload)) continue;
    ordinal += 1;
    imagesByUuid.set(
      `codex:user-turn:${ordinal}`,
      lineImages.length > 0
        ? lineImages
        : (responseItemImagesByOrdinal.get(ordinal) ?? []),
    );
  }

  return imagesByUuid;
}

async function extractCodexUserMessagePayloadImages(
  payload: Record<string, unknown>,
): Promise<ExtractedImage[]> {
  const images: ExtractedImage[] = [];
  if (Array.isArray(payload.images)) {
    for (const img of payload.images) {
      if (typeof img === "string") {
        const match = img.match(/^data:(image\/[^;]+);base64,(.+)$/);
        if (match) {
          images.push({ base64: match[2], mimeType: match[1] });
        }
        continue;
      }
      const item = asObject(img);
      if (!item) continue;
      const base64 =
        typeof item.base64 === "string"
          ? item.base64
          : typeof item.data === "string"
            ? item.data
            : undefined;
      const mimeType =
        typeof item.mimeType === "string"
          ? item.mimeType
          : typeof item.mime_type === "string"
            ? item.mime_type
            : typeof item.media_type === "string"
              ? item.media_type
              : undefined;
      if (base64 && mimeType) {
        images.push({ base64, mimeType });
      }
    }
  }
  if (Array.isArray(payload.local_images)) {
    for (const imagePath of payload.local_images) {
      if (typeof imagePath !== "string" || imagePath.length === 0) continue;
      const image = await readLocalImageAsBase64(imagePath);
      if (image) images.push(image);
    }
  }
  return images;
}

function collectCodexUserResponseItemImagesByOrdinal(
  lines: string[],
): Map<number, ExtractedImage[]> {
  const imagesByOrdinal = new Map<number, ExtractedImage[]>();
  let ordinal = 0;

  for (const line of lines) {
    if (!line.trim()) continue;
    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }
    if (entry.type !== "response_item") continue;
    const payload = asObject(entry.payload);
    if (
      !payload ||
      payload.type !== "message" ||
      payload.role !== "user" ||
      !codexUserResponseItemHasDisplayContent(payload)
    ) {
      continue;
    }
    ordinal += 1;
    const images = extractCodexUserResponseItemImages(payload);
    if (images.length > 0) {
      imagesByOrdinal.set(ordinal, images);
    }
  }

  return imagesByOrdinal;
}

function codexUserResponseItemHasDisplayContent(
  payload: Record<string, unknown>,
): boolean {
  const texts: string[] = [];
  let hasImage = false;
  for (const item of arrayValue(payload.content)) {
    const content = asObject(item);
    if (!content) continue;
    if (content.type === "input_image") {
      hasImage = true;
      continue;
    }
    if (content.type !== "input_text" || typeof content.text !== "string") {
      continue;
    }
    texts.push(content.text);
  }
  const userText = texts
    .filter((text) => !isCodexImageWrapperText(text.trim()))
    .join("\n")
    .trim();
  if (userText && isCodexInjectedUserContext(userText)) return false;
  return userText.length > 0 || hasImage;
}

function extractCodexUserResponseItemImages(
  payload: Record<string, unknown>,
): ExtractedImage[] {
  const images: ExtractedImage[] = [];
  for (const item of arrayValue(payload.content)) {
    const content = asObject(item);
    if (!content || content.type !== "input_image") continue;
    const imageUrl =
      typeof content.image_url === "string"
        ? content.image_url
        : typeof content.url === "string"
          ? content.url
          : undefined;
    const image = extractDataUriImage(imageUrl);
    if (image) images.push(image);
  }
  return images;
}

function extractDataUriImage(value: string | undefined): ExtractedImage | null {
  const match = value?.match(/^data:(image\/[^;]+);base64,(.+)$/);
  return match ? { base64: match[2], mimeType: match[1] } : null;
}

function isCodexImageWrapperText(text: string): boolean {
  return /^<image(?:\s[^>]*)?>$/.test(text) || text === "</image>";
}

async function readLocalImageAsBase64(
  imagePath: string,
): Promise<ExtractedImage | null> {
  const mimeType = mimeTypeForLocalImagePath(imagePath);
  if (!mimeType) return null;
  try {
    const buffer = await readFile(imagePath);
    return { base64: buffer.toString("base64"), mimeType };
  } catch {
    return null;
  }
}

function mimeTypeForLocalImagePath(imagePath: string): string | null {
  switch (extname(imagePath).toLowerCase()) {
    case ".png":
      return "image/png";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".gif":
      return "image/gif";
    case ".webp":
      return "image/webp";
    default:
      return null;
  }
}

function codexUserMessagePayloadHasDisplayContent(
  payload: Record<string, unknown>,
): boolean {
  const message = typeof payload.message === "string" ? payload.message : "";
  const images = Array.isArray(payload.images) ? payload.images.length : 0;
  const localImages = Array.isArray(payload.local_images)
    ? payload.local_images.length
    : 0;
  return message.trim().length > 0 || images + localImages > 0;
}

export async function getCodexSessionHistory(
  threadId: string,
): Promise<SessionHistoryMessage[]> {
  const jsonlPath = await findCodexSessionJsonlPath(threadId);
  if (!jsonlPath) return [];

  let raw: string;
  try {
    raw = await readFile(jsonlPath, "utf-8");
  } catch {
    return [];
  }

  const messages: SessionHistoryMessage[] = [];
  const lines = raw.split("\n");
  let userTurnOrdinal = 0;

  for (const [index, line] of lines.entries()) {
    if (!line.trim()) continue;
    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }

    const entryTimestamp = entry.timestamp as string | undefined;

    if (entry.type === "event_msg") {
      const payload = asObject(entry.payload);
      if (!payload) continue;

      if (payload.type === "thread_rolled_back") {
        const rawNumTurns = payload.num_turns ?? payload.numTurns;
        const numTurns =
          typeof rawNumTurns === "number" ? rawNumTurns : Number(rawNumTurns);
        applyCodexThreadRollback(messages, numTurns);
        userTurnOrdinal = countCodexUserTurns(messages);
        continue;
      }

      if (payload.type === "user_message") {
        const rawMessage = typeof payload.message === "string" ? payload.message : "";
        const images = Array.isArray(payload.images) ? payload.images.length : 0;
        const localImages = Array.isArray(payload.local_images)
          ? payload.local_images.length
          : 0;
        const imageCount = images + localImages;

        const text = rawMessage.trim().length > 0
          ? rawMessage
          : imageCount > 0
            ? `[Image attached${imageCount > 1 ? ` x${imageCount}` : ""}]`
            : "";
        if (imageCount > 0) {
          // Push directly to include imageCount metadata
          const normalized = text.trim();
          if (normalized) {
            messages.push({
              role: "user",
              uuid: codexUserTurnUuid(++userTurnOrdinal),
              content: [{ type: "text", text }],
              imageCount,
              ...(entryTimestamp ? { timestamp: entryTimestamp } : {}),
            });
          }
        } else {
          if (appendTextMessage(
            messages,
            "user",
            text,
            entryTimestamp,
            codexUserTurnUuid(userTurnOrdinal + 1),
          )) {
            userTurnOrdinal += 1;
          }
        }
        continue;
      }

      if (payload.type === "agent_message" && typeof payload.message === "string") {
        appendTextMessage(messages, "assistant", payload.message, entryTimestamp);
      }

      if (payload.type === "image_generation_end") {
        appendImageGenerationResult(
          messages,
          payload,
          `image-generation-${index}`,
          entryTimestamp,
        );
      }

      if (payload.type === "mcp_tool_call_end") {
        const invocation = asObject(payload.invocation);
        const id =
          typeof payload.call_id === "string"
            ? payload.call_id
            : `mcp-result-${index}`;
        const server =
          typeof invocation?.server === "string" ? invocation.server : "mcp";
        const tool =
          typeof invocation?.tool === "string" ? invocation.tool : "tool";
        const normalized = normalizeCodexMcpResult(payload.result);
        appendToolResultMessage(
          messages,
          id,
          `mcp:${server}/${tool}`,
          normalized.content,
          {
            imageBase64: normalized.imageBase64,
            ...(entryTimestamp ? { timestamp: entryTimestamp } : {}),
          },
        );
      }
      continue;
    }

    if (entry.type === "response_item") {
      const payload = asObject(entry.payload);
      if (!payload) continue;

      if (payload.type === "message") {
        const content = Array.isArray(payload.content)
          ? (payload.content as Array<Record<string, unknown>>)
          : [];

        if (payload.role === "assistant") {
          const text = content
            .filter((item) => item.type === "output_text" && typeof item.text === "string")
            .map((item) => item.text as string)
            .join("\n");
          appendTextMessage(messages, "assistant", text, entryTimestamp);
          continue;
        }

        if (payload.role === "user") {
          if (content.some((item) => item.type === "input_image")) {
            continue;
          }
          const text = content
            .filter((item) => item.type === "input_text" && typeof item.text === "string")
            .map((item) => item.text as string)
            .join("\n");
          if (!isCodexInjectedUserContext(text)) {
            if (appendTextMessage(
              messages,
              "user",
              text,
              entryTimestamp,
              codexUserTurnUuid(userTurnOrdinal + 1),
            )) {
              userTurnOrdinal += 1;
            }
          }
          continue;
        }
      }

      if (payload.type === "function_call") {
        const id = typeof payload.call_id === "string" ? payload.call_id : `tool-${index}`;
        const rawName = typeof payload.name === "string" ? payload.name : "tool";
        appendToolUseMessage(
          messages,
          id,
          normalizeCodexToolName(rawName),
          parseObjectLike(payload.arguments),
        );
        continue;
      }

      if (payload.type === "custom_tool_call") {
        const id = typeof payload.call_id === "string" ? payload.call_id : `tool-${index}`;
        const rawName = typeof payload.name === "string" ? payload.name : "custom_tool";
        appendToolUseMessage(
          messages,
          id,
          normalizeCodexToolName(rawName),
          parseObjectLike(payload.input),
        );
        continue;
      }

      if (payload.type === "web_search_call") {
        appendToolUseMessage(
          messages,
          typeof payload.call_id === "string" ? payload.call_id : `web-search-${index}`,
          "WebSearch",
          getCodexSearchInput(payload),
        );
        continue;
      }

      if (payload.type === "image_generation_call") {
        appendImageGenerationResult(
          messages,
          payload,
          `image-generation-${index}`,
          entryTimestamp,
        );
        continue;
      }

      // Backward/forward compatibility with older/newer Codex JSONL schemas.
      if (payload.type === "command_execution") {
        const id = typeof payload.id === "string"
          ? payload.id
          : typeof payload.call_id === "string"
            ? payload.call_id
            : `cmd-${index}`;
        const input = typeof payload.command === "string"
          ? { command: payload.command }
          : parseObjectLike(payload);
        appendToolUseMessage(messages, id, "Bash", input);
        continue;
      }

      if (payload.type === "mcp_tool_call") {
        const id = typeof payload.id === "string"
          ? payload.id
          : typeof payload.call_id === "string"
            ? payload.call_id
            : `mcp-${index}`;
        const server = typeof payload.server === "string" ? payload.server : "unknown";
        const tool = typeof payload.tool === "string" ? payload.tool : "tool";
        appendToolUseMessage(
          messages,
          id,
          `mcp:${server}/${tool}`,
          parseObjectLike(payload.arguments),
        );
        continue;
      }

      if (payload.type === "file_change") {
        const id = typeof payload.id === "string"
          ? payload.id
          : typeof payload.call_id === "string"
            ? payload.call_id
            : `file-change-${index}`;
        const input = Array.isArray(payload.changes)
          ? { changes: payload.changes as unknown[] }
          : parseObjectLike(payload.changes);
        appendToolUseMessage(messages, id, "FileChange", input);
        continue;
      }

      if (payload.type === "web_search") {
        const id = typeof payload.id === "string"
          ? payload.id
          : typeof payload.call_id === "string"
            ? payload.call_id
            : `web-search-${index}`;
        const input = typeof payload.query === "string"
          ? { query: payload.query }
          : getCodexSearchInput(payload);
        appendToolUseMessage(messages, id, "WebSearch", input);
      }
    }
  }

  return messages;
}

/**
 * Look up session metadata for a set of Claude CLI sessionIds.
 * Returns a map from sessionId to a subset of session metadata.
 * More efficient than getAllRecentSessions when you only need a few entries.
 */
export async function findSessionsByClaudeIds(
  ids: Set<string>,
): Promise<Map<string, Pick<SessionIndexEntry, "summary" | "firstPrompt" | "lastPrompt" | "projectPath">>> {
  if (ids.size === 0) return new Map();

  const result = new Map<string, Pick<SessionIndexEntry, "summary" | "firstPrompt" | "lastPrompt" | "projectPath">>();
  const remaining = new Set(ids);

  const projectsDir = join(homedir(), ".claude", "projects");
  let projectDirs: string[];
  try {
    projectDirs = await readdir(projectsDir);
  } catch {
    return result;
  }

  for (const dirName of projectDirs) {
    if (remaining.size === 0) break;
    if (dirName.startsWith(".")) continue;

    const indexPath = join(projectsDir, dirName, "sessions-index.json");
    let raw: string;
    try {
      raw = await readFile(indexPath, "utf-8");
    } catch {
      continue;
    }

    let index: { entries?: Array<Record<string, unknown>> };
    try {
      index = JSON.parse(raw) as { entries?: Array<Record<string, unknown>> };
    } catch {
      continue;
    }

    if (!Array.isArray(index.entries)) continue;

    for (const entry of index.entries) {
      const sid = entry.sessionId as string | undefined;
      if (!sid || !remaining.has(sid)) continue;

      result.set(sid, {
        summary: entry.summary as string | undefined,
        firstPrompt: (entry.firstPrompt as string) ?? "",
        lastPrompt: entry.lastPrompt as string | undefined,
        projectPath: normalizeWorktreePath((entry.projectPath as string) ?? ""),
      });
      remaining.delete(sid);
    }
  }

  return result;
}
