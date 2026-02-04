import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";

export interface SessionIndexEntry {
  sessionId: string;
  summary?: string;
  firstPrompt: string;
  messageCount: number;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  isSidechain: boolean;
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
}

export interface GetRecentSessionsResult {
  sessions: SessionIndexEntry[];
  hasMore: boolean;
}

/** Convert a filesystem path to Claude's project directory slug (e.g. /foo/bar → -foo-bar). */
export function pathToSlug(p: string): string {
  return p.replaceAll("/", "-");
}

/**
 * Check if a directory slug represents a worktree directory for a given project slug.
 * e.g. "-Users-x-proj-worktrees-branch" is a worktree dir for "-Users-x-proj".
 */
export function isWorktreeSlug(dirSlug: string, projectSlug: string): boolean {
  return dirSlug.startsWith(projectSlug + "-worktrees-");
}

/**
 * Scan a directory for JSONL session files and create SessionIndexEntry objects.
 * Used as a fallback when sessions-index.json is missing (common for worktree sessions).
 */
export async function scanJsonlDir(dirPath: string): Promise<SessionIndexEntry[]> {
  const entries: SessionIndexEntry[] = [];

  let files: string[];
  try {
    files = await readdir(dirPath);
  } catch {
    return entries;
  }

  for (const file of files) {
    if (!file.endsWith(".jsonl")) continue;

    const sessionId = basename(file, ".jsonl");
    const filePath = join(dirPath, file);

    let raw: string;
    try {
      raw = await readFile(filePath, "utf-8");
    } catch {
      continue;
    }

    const lines = raw.split("\n");
    let firstPrompt = "";
    let messageCount = 0;
    let created = "";
    let modified = "";
    let gitBranch = "";
    let projectPath = "";
    let isSidechain = false;
    let summary: string | undefined;

    for (const line of lines) {
      if (!line.trim()) continue;

      let entry: Record<string, unknown>;
      try {
        entry = JSON.parse(line) as Record<string, unknown>;
      } catch {
        continue;
      }

      const type = entry.type as string;

      if (type === "summary" && entry.summary) {
        summary = entry.summary as string;
      }

      if (type !== "user" && type !== "assistant") continue;
      messageCount++;

      const timestamp = entry.timestamp as string | undefined;
      if (timestamp) {
        if (!created) created = timestamp;
        modified = timestamp;
      }

      if (!gitBranch && entry.gitBranch) {
        gitBranch = entry.gitBranch as string;
      }

      if (!projectPath && entry.cwd) {
        projectPath = entry.cwd as string;
      }

      if (type === "user" && !firstPrompt) {
        const message = entry.message as
          | { content?: unknown }
          | undefined;
        if (message?.content) {
          if (typeof message.content === "string") {
            firstPrompt = message.content;
          } else if (Array.isArray(message.content)) {
            const textBlock = (
              message.content as Array<{ type: string; text?: string }>
            ).find((c) => c.type === "text" && c.text);
            if (textBlock?.text) {
              firstPrompt = textBlock.text;
            }
          }
        }
      }

      if (entry.isSidechain) {
        isSidechain = true;
      }
    }

    if (messageCount > 0) {
      entries.push({
        sessionId,
        summary,
        firstPrompt,
        messageCount,
        created,
        modified,
        gitBranch,
        projectPath,
        isSidechain,
      });
    }
  }

  return entries;
}

export async function getAllRecentSessions(
  options: GetRecentSessionsOptions = {},
): Promise<GetRecentSessionsResult> {
  const limit = options.limit ?? 20;
  const offset = options.offset ?? 0;
  const filterProjectPath = options.projectPath;

  const projectsDir = join(homedir(), ".claude", "projects");
  const entries: SessionIndexEntry[] = [];

  let projectDirs: string[];
  try {
    projectDirs = await readdir(projectsDir);
  } catch {
    // ~/.claude/projects doesn't exist
    return { sessions: [], hasMore: false };
  }

  // Compute worktree slug prefix for projectPath filtering
  const projectSlug = filterProjectPath
    ? pathToSlug(filterProjectPath)
    : null;

  for (const dirName of projectDirs) {
    // Skip hidden directories
    if (dirName.startsWith(".")) continue;

    // When filtering by project, skip unrelated directories early
    const isProjectDir = projectSlug ? dirName === projectSlug : false;
    const isWorktreeDir = projectSlug
      ? isWorktreeSlug(dirName, projectSlug)
      : false;
    if (filterProjectPath && !isProjectDir && !isWorktreeDir) continue;

    const dirPath = join(projectsDir, dirName);
    const indexPath = join(dirPath, "sessions-index.json");
    let raw: string | null = null;
    try {
      raw = await readFile(indexPath, "utf-8");
    } catch {
      // No sessions-index.json — will try JSONL scan for worktree dirs
    }

    if (raw !== null) {
      // Parse sessions-index.json
      let index: RawSessionIndexFile;
      try {
        index = JSON.parse(raw) as RawSessionIndexFile;
      } catch {
        console.error(`[sessions-index] Failed to parse ${indexPath}`);
        continue;
      }

      if (!Array.isArray(index.entries)) continue;

      for (const entry of index.entries) {
        const mapped: SessionIndexEntry = {
          sessionId: entry.sessionId,
          summary: entry.summary,
          firstPrompt: entry.firstPrompt ?? "",
          messageCount: entry.messageCount ?? 0,
          created: entry.created ?? "",
          modified: entry.modified ?? "",
          gitBranch: entry.gitBranch ?? "",
          projectPath: entry.projectPath ?? "",
          isSidechain: entry.isSidechain ?? false,
        };

        // Accept entries from the project dir or its worktree dirs
        if (filterProjectPath && !isProjectDir && !isWorktreeDir) {
          continue;
        }

        entries.push(mapped);
      }
    } else if (isWorktreeDir || !filterProjectPath) {
      // No sessions-index.json: scan JSONL files directly
      // This handles worktree sessions where Claude CLI didn't create an index
      const scanned = await scanJsonlDir(dirPath);
      entries.push(...scanned);
    }
  }

  // Sort by modified descending
  entries.sort((a, b) => {
    const ta = new Date(a.modified).getTime();
    const tb = new Date(b.modified).getTime();
    return tb - ta;
  });

  const sliced = entries.slice(offset, offset + limit);
  const hasMore = offset + limit < entries.length;

  return { sessions: sliced, hasMore };
}

// ---- Session history from JSONL files ----

export interface SessionHistoryMessage {
  role: "user" | "assistant";
  content: Array<{
    type: string;
    text?: string;
    id?: string;
    name?: string;
    input?: Record<string, unknown>;
  }>;
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

    const message = entry.message as
      | { role: string; content: unknown[] }
      | undefined;
    if (!message?.content || !Array.isArray(message.content)) continue;

    const role = message.role as "user" | "assistant";

    // Filter content to only text and tool_use (skip tool_result for cleaner display)
    const content: SessionHistoryMessage["content"] = [];
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
      }
    }

    if (content.length > 0) {
      messages.push({ role, content });
    }
  }

  return messages;
}
