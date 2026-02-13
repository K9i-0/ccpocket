import { readdir, readFile, stat } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";

export interface SessionIndexEntry {
  sessionId: string;
  provider: "claude" | "codex";
  summary?: string;
  firstPrompt: string;
  messageCount: number;
  created: string;
  modified: string;
  gitBranch: string;
  projectPath: string;
  /** Raw cwd used to resume this session (worktree path for codex, if any). */
  resumeCwd?: string;
  isSidechain: boolean;
  codexSettings?: {
    approvalPolicy?: string;
    sandboxMode?: string;
    model?: string;
    modelReasoningEffort?: string;
    networkAccessEnabled?: boolean;
    webSearchMode?: string;
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
  return p.replaceAll("/", "-").replaceAll("_", "-");
}

/**
 * Normalize a worktree cwd back to the main project path.
 * e.g. /path/to/project-worktrees/branch → /path/to/project
 */
export function normalizeWorktreePath(p: string): string {
  const match = p.match(/^(.+)-worktrees\/[^/]+$/);
  return match?.[1] ?? p;
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
        projectPath = normalizeWorktreePath(entry.cwd as string);
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
        provider: "claude",
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
    projectDirs = [];
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

      const indexedIds = new Set<string>();
      for (const entry of index.entries) {
        indexedIds.add(entry.sessionId);
        const mapped: SessionIndexEntry = {
          sessionId: entry.sessionId,
          provider: "claude",
          summary: entry.summary,
          firstPrompt: entry.firstPrompt ?? "",
          messageCount: entry.messageCount ?? 0,
          created: entry.created ?? "",
          modified: entry.modified ?? "",
          gitBranch: entry.gitBranch ?? "",
          projectPath: normalizeWorktreePath(entry.projectPath ?? ""),
          isSidechain: entry.isSidechain ?? false,
        };

        entries.push(mapped);
      }

      // Supplement: scan JSONL files not covered by the index.
      // Claude CLI may not register every session (e.g. `claude -r` resumes)
      // into sessions-index.json, so we pick up any orphaned JSONL files here.
      const scanned = await scanJsonlDir(dirPath);
      for (const s of scanned) {
        if (!indexedIds.has(s.sessionId)) {
          entries.push(s);
        }
      }
    } else {
      // No sessions-index.json: scan JSONL files directly.
      // Directories are already filtered above, so all remaining dirs are relevant.
      const scanned = await scanJsonlDir(dirPath);
      entries.push(...scanned);
    }
  }

  const codexEntries = await getAllRecentCodexSessions({
    projectPath: filterProjectPath,
  });
  entries.push(...codexEntries);

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

interface CodexRecentOptions {
  projectPath?: string;
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
    let children: string[];
    try {
      children = await readdir(dir);
    } catch {
      continue;
    }
    for (const child of children) {
      const p = join(dir, child);
      let st: Awaited<ReturnType<typeof stat>>;
      try {
        st = await stat(p);
      } catch {
        continue;
      }
      if (st.isDirectory()) {
        stack.push(p);
      } else if (st.isFile() && p.endsWith(".jsonl")) {
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
  let summary = "";
  let messageCount = 0;
  let lastAssistantText = "";
  // Settings extracted from the first turn_context entry
  let approvalPolicy: string | undefined;
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
      }
      continue;
    }

    // Extract codex settings from turn_context
    if (entry.type === "turn_context" && !approvalPolicy) {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (payload) {
        if (typeof payload.approval_policy === "string") {
          approvalPolicy = payload.approval_policy;
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
        messageCount += 1;
        if (!firstPrompt) firstPrompt = payload.message;
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
        messageCount += 1;
        lastAssistantText = text;
      }
    }
  }

  if (!projectPath || messageCount === 0) return null;
  summary = lastAssistantText || summary;

  const codexSettings = (
    approvalPolicy
    || sandboxMode
    || model
    || modelReasoningEffort
    || networkAccessEnabled !== undefined
    || webSearchMode
  )
    ? {
        approvalPolicy,
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
      summary: summary || undefined,
      firstPrompt,
      messageCount,
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

async function getAllRecentCodexSessions(options: CodexRecentOptions = {}): Promise<SessionIndexEntry[]> {
  const files = await listCodexSessionFiles();
  const entries: SessionIndexEntry[] = [];
  const normalizedProjectPath = options.projectPath
    ? normalizeWorktreePath(options.projectPath)
    : null;

  for (const filePath of files) {
    let raw: string;
    try {
      raw = await readFile(filePath, "utf-8");
    } catch {
      continue;
    }
    const fallbackSessionId = basename(filePath, ".jsonl");
    const parsed = parseCodexSessionJsonl(raw, fallbackSessionId);
    if (!parsed) continue;
    if (normalizedProjectPath && parsed.entry.projectPath !== normalizedProjectPath) {
      continue;
    }
    entries.push(parsed.entry);
  }

  return entries;
}

// ---- Session history from JSONL files ----

export interface SessionHistoryMessage {
  role: "user" | "assistant";
  uuid?: string;
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

async function findCodexSessionJsonlPath(threadId: string): Promise<string | null> {
  const files = await listCodexSessionFiles();
  for (const filePath of files) {
    const fallbackSessionId = basename(filePath, ".jsonl");
    if (fallbackSessionId === threadId) {
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
      const uuid = entry.uuid as string | undefined;
      messages.push({ role, content, ...(uuid ? { uuid } : {}) });
    }
  }

  return messages;
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

  for (const line of lines) {
    if (!line.trim()) continue;
    let entry: Record<string, unknown>;
    try {
      entry = JSON.parse(line) as Record<string, unknown>;
    } catch {
      continue;
    }

    if (entry.type === "event_msg") {
      const payload = entry.payload as Record<string, unknown> | undefined;
      if (payload?.type === "user_message" && typeof payload.message === "string") {
        messages.push({
          role: "user",
          content: [{ type: "text", text: payload.message }],
        });
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
        messages.push({
          role: "assistant",
          content: [{ type: "text", text }],
        });
      }
    }
  }

  return messages;
}
