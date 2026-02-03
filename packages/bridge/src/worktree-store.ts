import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

export interface WorktreeMapping {
  worktreePath: string;
  worktreeBranch: string;
  projectPath: string;
}

type StorageData = Record<string, WorktreeMapping>;

const STORE_DIR = join(homedir(), ".ccpocket");
const STORE_FILE = join(STORE_DIR, "worktree-sessions.json");

/** Persistent mapping between Claude session IDs and worktree paths. */
export class WorktreeStore {
  private data: StorageData;

  constructor() {
    this.data = this.load();
  }

  /** Get worktree mapping for a Claude session ID. */
  get(claudeSessionId: string): WorktreeMapping | undefined {
    return this.data[claudeSessionId];
  }

  /** Save a worktree mapping for a Claude session ID. */
  set(claudeSessionId: string, mapping: WorktreeMapping): void {
    this.data[claudeSessionId] = mapping;
    this.save();
  }

  /** Remove a worktree mapping by Claude session ID. */
  delete(claudeSessionId: string): void {
    delete this.data[claudeSessionId];
    this.save();
  }

  /** Remove all mappings that reference the given worktree path. */
  deleteByWorktreePath(worktreePath: string): void {
    for (const [id, mapping] of Object.entries(this.data)) {
      if (mapping.worktreePath === worktreePath) {
        delete this.data[id];
      }
    }
    this.save();
  }

  /** Find a mapping by worktree path. */
  findByWorktreePath(worktreePath: string): { claudeSessionId: string; mapping: WorktreeMapping } | undefined {
    for (const [id, mapping] of Object.entries(this.data)) {
      if (mapping.worktreePath === worktreePath) {
        return { claudeSessionId: id, mapping };
      }
    }
    return undefined;
  }

  private load(): StorageData {
    if (!existsSync(STORE_FILE)) return {};
    try {
      return JSON.parse(readFileSync(STORE_FILE, "utf-8")) as StorageData;
    } catch {
      return {};
    }
  }

  private save(): void {
    mkdirSync(STORE_DIR, { recursive: true });
    writeFileSync(STORE_FILE, JSON.stringify(this.data, null, 2), "utf-8");
  }
}
