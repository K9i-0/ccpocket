import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
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

  for (const dirName of projectDirs) {
    // Skip hidden directories
    if (dirName.startsWith(".")) continue;

    const indexPath = join(projectsDir, dirName, "sessions-index.json");
    let raw: string;
    try {
      raw = await readFile(indexPath, "utf-8");
    } catch {
      // No sessions-index.json for this project
      continue;
    }

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

      // Apply projectPath filter if specified
      if (filterProjectPath && mapped.projectPath !== filterProjectPath) {
        continue;
      }

      entries.push(mapped);
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
 * Find the JSONL file path for a given sessionId by searching sessions-index.json files.
 */
async function findSessionJsonlPath(sessionId: string): Promise<string | null> {
  const projectsDir = join(homedir(), ".claude", "projects");

  let projectDirs: string[];
  try {
    projectDirs = await readdir(projectsDir);
  } catch {
    return null;
  }

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
