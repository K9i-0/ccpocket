import { readdir, readFile, writeFile, appendFile, stat } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";

export interface SessionIndexEntry {
  sessionId: string;
  provider: "claude" | "codex";
  /** User-assigned session name (customTitle for Claude, thread_name for Codex). */
  name?: string;
  summary?: string;
  firstPrompt: string;
  lastPrompt?: string;
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
    let lastPrompt = "";
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

      if (type === "user") {
        const message = entry.message as
          | { content?: unknown }
          | undefined;
        if (message?.content) {
          let text = "";
          if (typeof message.content === "string") {
            text = message.content;
          } else if (Array.isArray(message.content)) {
            const textBlock = (
              message.content as Array<{ type: string; text?: string }>
            ).find((c) => c.type === "text" && c.text);
            if (textBlock?.text) {
              text = textBlock.text;
            }
          }
          if (text) {
            if (!firstPrompt) firstPrompt = text;
            lastPrompt = text;
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
        ...(lastPrompt && lastPrompt !== firstPrompt ? { lastPrompt } : {}),
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
          name: entry.customTitle || undefined,
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
  let lastPrompt = "";
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
        lastPrompt = payload.message;
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
      ...(lastPrompt && lastPrompt !== firstPrompt ? { lastPrompt } : {}),
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
  let messageCount = 0;
  let gitBranch = "";
  try {
    const raw = await readFile(jsonlPath, "utf-8");
    for (const line of raw.split("\n")) {
      if (!line.trim()) continue;
      try {
        const entry = JSON.parse(line) as Record<string, unknown>;
        const type = entry.type as string;
        if (type !== "user" && type !== "assistant") continue;
        messageCount++;
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
    messageCount,
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
  const normalizedProjectPath = options.projectPath
    ? normalizeWorktreePath(options.projectPath)
    : null;

  // Load thread names from session_index.jsonl
  const threadNames = await loadCodexSessionNames();

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
    // Attach thread name if available
    const threadName = threadNames.get(parsed.threadId);
    if (threadName) {
      parsed.entry.name = threadName;
    }
    entries.push(parsed.entry);
  }

  return entries;
}

// ---- Session history from JSONL files ----

export interface SessionHistoryMessage {
  role: "user" | "assistant";
  uuid?: string;
  timestamp?: string;
  /** Skill loading prompt or other meta message (rendered as a chip). */
  isMeta?: boolean;
  /** Number of images attached to this user message (for display indicator). */
  imageCount?: number;
  content: Array<{
    type: string;
    text?: string;
    id?: string;
    name?: string;
    input?: Record<string, unknown>;
  }>;
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
): void {
  const normalized = text.trim();
  if (!normalized) return;

  const last = messages.at(-1);
  if (
    last
    && last.role === role
    && last.content.length === 1
    && last.content[0].type === "text"
    && typeof last.content[0].text === "string"
    && last.content[0].text.trim() === normalized
  ) {
    return;
  }

  messages.push({
    role,
    content: [{ type: "text", text }],
    ...(timestamp ? { timestamp } : {}),
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

function isCodexInjectedUserContext(text: string): boolean {
  const normalized = text.trimStart();
  return (
    normalized.startsWith("# AGENTS.md instructions for ")
    || normalized.startsWith("<environment_context>")
    || normalized.startsWith("<permissions instructions>")
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
    const content: SessionHistoryMessage["content"] = [];
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

/**
 * Extract image base64 data from a Claude Code session JSONL for a specific message UUID.
 */
export async function extractMessageImages(
  sessionId: string,
  messageUuid: string,
): Promise<ExtractedImage[]> {
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
  const jsonlPath = await findCodexSessionJsonlPath(sessionId);
  if (!jsonlPath) return [];

  let raw: string;
  try {
    raw = await readFile(jsonlPath, "utf-8");
  } catch {
    return [];
  }

  // Codex doesn't have per-message UUIDs in the same way.
  // We scan for event_msg with user_message that has images and match by line index
  // encoded in the UUID (format: "codex-line-{index}").
  const lineIndex = messageUuid.startsWith("codex-line-")
    ? parseInt(messageUuid.slice("codex-line-".length), 10)
    : -1;
  if (lineIndex < 0) return [];

  const lines = raw.split("\n");
  if (lineIndex >= lines.length) return [];

  const line = lines[lineIndex];
  if (!line?.trim()) return [];

  let entry: Record<string, unknown>;
  try {
    entry = JSON.parse(line) as Record<string, unknown>;
  } catch {
    return [];
  }

  if (entry.type !== "event_msg") return [];
  const payload = asObject(entry.payload);
  if (!payload || payload.type !== "user_message") return [];

  const images: ExtractedImage[] = [];

  // Parse payload.images (Data URI format: "data:image/png;base64,...")
  if (Array.isArray(payload.images)) {
    for (const img of payload.images) {
      if (typeof img !== "string") continue;
      const match = (img as string).match(/^data:(image\/[^;]+);base64,(.+)$/);
      if (match) {
        images.push({ base64: match[2], mimeType: match[1] });
      }
    }
  }

  return images;
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
              content: [{ type: "text", text }],
              imageCount,
              ...(entryTimestamp ? { timestamp: entryTimestamp } : {}),
            });
          }
        } else {
          appendTextMessage(messages, "user", text, entryTimestamp);
        }
        continue;
      }

      if (payload.type === "agent_message" && typeof payload.message === "string") {
        appendTextMessage(messages, "assistant", payload.message, entryTimestamp);
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
          const text = content
            .filter((item) => item.type === "input_text" && typeof item.text === "string")
            .map((item) => item.text as string)
            .join("\n");
          if (!isCodexInjectedUserContext(text)) {
            appendTextMessage(messages, "user", text, entryTimestamp);
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
