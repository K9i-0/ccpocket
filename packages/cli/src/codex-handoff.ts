import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

export interface CodexThreadRecord {
  cwd: string;
  threadId: string;
  updatedAt: string;
  rolloutPath?: string;
}

interface TrackerFile {
  codexThreads?: Record<string, CodexThreadRecord>;
}

export function getCodexTrackerPath(): string {
  return join(homedir(), ".ccpocket", "codex-tracker.json");
}

export function getCodexSessionsRoot(): string {
  return join(homedir(), ".codex", "sessions");
}

export function normalizeCwd(cwd: string): string {
  return resolve(cwd);
}

export function loadTrackedCodexThreads(
  trackerPath: string = getCodexTrackerPath(),
): Record<string, CodexThreadRecord> {
  try {
    if (!existsSync(trackerPath)) return {};
    const raw = readFileSync(trackerPath, "utf-8");
    const parsed = JSON.parse(raw) as TrackerFile;
    return parsed.codexThreads ?? {};
  } catch {
    return {};
  }
}

export function saveTrackedCodexThread(
  record: CodexThreadRecord,
  trackerPath: string = getCodexTrackerPath(),
): void {
  const cwd = normalizeCwd(record.cwd);
  const existing = loadTrackedCodexThreads(trackerPath);
  existing[cwd] = {
    ...record,
    cwd,
  };
  mkdirSync(dirname(trackerPath), { recursive: true });
  writeFileSync(
    trackerPath,
    JSON.stringify({ codexThreads: existing }, null, 2) + "\n",
    "utf-8",
  );
}

export function getTrackedCodexThread(
  cwd: string,
  trackerPath: string = getCodexTrackerPath(),
): CodexThreadRecord | null {
  const normalized = normalizeCwd(cwd);
  return loadTrackedCodexThreads(trackerPath)[normalized] ?? null;
}

export function resolveCodexThreadForCwd(
  cwd: string,
  options?: {
    trackerPath?: string;
    sessionsRoot?: string;
    sinceMs?: number;
  },
): CodexThreadRecord | null {
  const tracked = getTrackedCodexThread(cwd, options?.trackerPath);
  const scanned = findLatestCodexThreadForCwd(cwd, {
    sessionsRoot: options?.sessionsRoot,
    sinceMs: options?.sinceMs,
  });

  if (!tracked) return scanned;
  if (!scanned) return tracked;

  return new Date(scanned.updatedAt).getTime() >=
    new Date(tracked.updatedAt).getTime()
    ? scanned
    : tracked;
}

export function findLatestCodexThreadForCwd(
  cwd: string,
  options?: {
    sessionsRoot?: string;
    sinceMs?: number;
  },
): CodexThreadRecord | null {
  const normalized = normalizeCwd(cwd);
  const sessionsRoot = options?.sessionsRoot ?? getCodexSessionsRoot();
  if (!existsSync(sessionsRoot)) return null;

  const rolloutFiles = listRolloutFiles(sessionsRoot)
    .map((rolloutPath) => {
      try {
        const stats = statSync(rolloutPath);
        return { rolloutPath, mtimeMs: stats.mtimeMs };
      } catch {
        return null;
      }
    })
    .filter((entry): entry is { rolloutPath: string; mtimeMs: number } => {
      return entry !== null;
    })
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  for (const entry of rolloutFiles) {
    if (options?.sinceMs && entry.mtimeMs < options.sinceMs) continue;
    const record = parseSessionMeta(entry.rolloutPath);
    if (!record) continue;
    if (record.cwd !== normalized) continue;
    return {
      ...record,
      rolloutPath: entry.rolloutPath,
    };
  }

  return null;
}

function listRolloutFiles(dir: string): string[] {
  const results: string[] = [];
  const stack = [dir];

  while (stack.length > 0) {
    const current = stack.pop();
    if (!current) continue;

    let entries: Array<{
      name: string;
      isDirectory(): boolean;
      isFile(): boolean;
    }>;
    try {
      entries = readdirSync(current, {
        withFileTypes: true,
      }) as typeof entries;
    } catch {
      continue;
    }

    for (const entry of entries) {
      const fullPath = join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
      } else if (
        entry.isFile() &&
        entry.name.startsWith("rollout-") &&
        entry.name.endsWith(".jsonl")
      ) {
        results.push(fullPath);
      }
    }
  }

  return results;
}

function parseSessionMeta(rolloutPath: string): CodexThreadRecord | null {
  try {
    const raw = readFileSync(rolloutPath, "utf-8");
    const firstLine = raw.split("\n", 1)[0];
    if (!firstLine) return null;

    const parsed = JSON.parse(firstLine) as {
      type?: string;
      timestamp?: string;
      payload?: {
        id?: string;
        cwd?: string;
        timestamp?: string;
      };
    };

    if (parsed.type !== "session_meta") return null;
    if (!parsed.payload?.id || !parsed.payload?.cwd) return null;

    return {
      cwd: normalizeCwd(parsed.payload.cwd),
      threadId: parsed.payload.id,
      updatedAt:
        parsed.payload.timestamp ??
        parsed.timestamp ??
        new Date(0).toISOString(),
    };
  } catch {
    return null;
  }
}
