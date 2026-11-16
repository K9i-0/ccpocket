import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { normalizeWorktreePath } from "./sessions-index.js";

const DEFAULT_HISTORY_FILE = join(homedir(), ".ccpocket", "project-history.json");
const MAX_PROJECTS = 20;

/** Minimum path depth to be considered a valid project path (e.g. /Users/name/project = 3). */
const MIN_PATH_SEGMENTS = 3;
const WINDOWS_DRIVE_PATH_RE = /^[A-Za-z]:[\\/]/;
const WINDOWS_UNC_PATH_RE = /^\\\\[^\\/]+[\\/][^\\/]+/;

function isValidProjectPath(path: string): boolean {
  if (path.startsWith("/")) {
    const segments = path.split("/").filter(Boolean);
    return segments.length >= MIN_PATH_SEGMENTS;
  }
  if (WINDOWS_DRIVE_PATH_RE.test(path) || WINDOWS_UNC_PATH_RE.test(path)) {
    const segments = path.split(/[\\/]+/).filter(Boolean);
    return segments.length >= MIN_PATH_SEGMENTS;
  }
  return false;
}

export class ProjectHistory {
  private projects: string[] = [];
  private readonly filePath: string;
  /** Serializes index writes so concurrent saves never interleave. */
  private saveChain: Promise<void> = Promise.resolve();

  constructor(filePath?: string) {
    this.filePath = filePath ?? DEFAULT_HISTORY_FILE;
  }

  async init(): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    try {
      const data = await readFile(this.filePath, "utf-8");
      const parsed = JSON.parse(data);
      if (Array.isArray(parsed)) {
        const raw = parsed.filter((p): p is string => typeof p === "string");
        // Normalize worktree paths and deduplicate (keep first occurrence)
        const seen = new Set<string>();
        this.projects = raw
          .map(normalizeWorktreePath)
          .filter(isValidProjectPath)
          .filter((p) => seen.has(p) ? false : (seen.add(p), true));
        // Persist cleaned data if invalid entries were removed
        if (this.projects.length < raw.length) {
          this.saveIndex().catch(() => {});
        }
      }
    } catch {
      // File doesn't exist or is corrupt — start fresh
      this.projects = [];
    }
  }

  addProject(path: string): void {
    const normalized = normalizeWorktreePath(path);
    if (!isValidProjectPath(normalized)) return;
    // Remove existing entry (if any) and add to front
    this.projects = this.projects.filter((p) => p !== normalized);
    this.projects.unshift(normalized);
    // Enforce max limit
    if (this.projects.length > MAX_PROJECTS) {
      this.projects = this.projects.slice(0, MAX_PROJECTS);
    }
    this.saveIndex().catch((err) => {
      console.error("[project-history] Failed to save:", err);
    });
  }

  getProjects(): string[] {
    return [...this.projects];
  }

  removeProject(path: string): void {
    const normalized = normalizeWorktreePath(path);
    this.projects = this.projects.filter(
      (p) => p !== path && p !== normalized,
    );
    this.saveIndex().catch((err) => {
      console.error("[project-history] Failed to save:", err);
    });
  }

  private saveIndex(): Promise<void> {
    const next = this.saveChain
      .catch(() => {})
      .then(() =>
        // Snapshot at write time so the last queued save persists the latest
        // list, whatever order the callers ran in.
        writeFile(this.filePath, JSON.stringify(this.projects, null, 2), "utf-8"),
      );
    this.saveChain = next;
    return next;
  }
}
