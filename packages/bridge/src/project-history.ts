import { readFile, writeFile, mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import { homedir } from "node:os";

const DEFAULT_HISTORY_FILE = join(homedir(), ".ccpocket", "project-history.json");
const MAX_PROJECTS = 20;

export class ProjectHistory {
  private projects: string[] = [];
  private readonly filePath: string;

  constructor(filePath?: string) {
    this.filePath = filePath ?? DEFAULT_HISTORY_FILE;
  }

  async init(): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    try {
      const data = await readFile(this.filePath, "utf-8");
      const parsed = JSON.parse(data);
      if (Array.isArray(parsed)) {
        this.projects = parsed.filter((p): p is string => typeof p === "string");
      }
    } catch {
      // File doesn't exist or is corrupt — start fresh
      this.projects = [];
    }
  }

  addProject(path: string): void {
    // Remove existing entry (if any) and add to front
    this.projects = this.projects.filter((p) => p !== path);
    this.projects.unshift(path);
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
    this.projects = this.projects.filter((p) => p !== path);
    this.saveIndex().catch((err) => {
      console.error("[project-history] Failed to save:", err);
    });
  }

  private async saveIndex(): Promise<void> {
    await writeFile(this.filePath, JSON.stringify(this.projects, null, 2), "utf-8");
  }
}
