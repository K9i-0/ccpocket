import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import { access, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

export type WorkspaceProvider = "claude" | "codex";
export type WorkspaceKind = "project";

export interface WorkspaceProject {
  id: string;
  name: string;
  /** Ordered roots. Index zero is primary. */
  rootPaths: string[];
  createdAt: string;
  updatedAt: string;
}

export interface SessionWorkspaceAssignment {
  provider: WorkspaceProvider;
  providerSessionId: string;
  kind: WorkspaceKind;
  projectId?: string;
  /** Snapshot used for resume even if the Project is edited or removed. */
  rootPaths: string[];
  assignedAt: string;
}

interface WorkspaceStateV1 {
  version: 1;
  projects: WorkspaceProject[];
  assignments: Record<string, SessionWorkspaceAssignment>;
}

export interface ResolvedWorkspace {
  kind: WorkspaceKind;
  projectId?: string;
  projectName?: string;
  rootPaths: string[];
}

const DEFAULT_STATE_FILE = join(homedir(), ".ccpocket", "workspaces-v1.json");

function assignmentKey(
  provider: WorkspaceProvider,
  providerSessionId: string,
): string {
  return `${provider}:${providerSessionId}`;
}

function cloneProject(project: WorkspaceProject): WorkspaceProject {
  return { ...project, rootPaths: [...project.rootPaths] };
}

function cloneAssignment(
  assignment: SessionWorkspaceAssignment,
): SessionWorkspaceAssignment {
  return { ...assignment, rootPaths: [...assignment.rootPaths] };
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function validProject(value: unknown): value is WorkspaceProject {
  if (!value || typeof value !== "object") return false;
  const project = value as Partial<WorkspaceProject>;
  return (
    isNonEmptyString(project.id) &&
    isNonEmptyString(project.name) &&
    Array.isArray(project.rootPaths) &&
    project.rootPaths.length > 0 &&
    project.rootPaths.every(isNonEmptyString) &&
    isNonEmptyString(project.createdAt) &&
    isNonEmptyString(project.updatedAt)
  );
}

function validAssignment(value: unknown): value is SessionWorkspaceAssignment {
  if (!value || typeof value !== "object") return false;
  const assignment = value as Partial<SessionWorkspaceAssignment>;
  return (
    (assignment.provider === "claude" || assignment.provider === "codex") &&
    isNonEmptyString(assignment.providerSessionId) &&
    assignment.kind === "project" &&
    (assignment.projectId === undefined || isNonEmptyString(assignment.projectId)) &&
    Array.isArray(assignment.rootPaths) &&
    assignment.rootPaths.length > 0 &&
    assignment.rootPaths.every(isNonEmptyString) &&
    isNonEmptyString(assignment.assignedAt)
  );
}

export class WorkspaceStore {
  private readonly filePath: string;
  private readonly now: () => Date;
  private state: WorkspaceStateV1;
  private saveQueue: Promise<void> = Promise.resolve();
  private mutationQueue: Promise<void> = Promise.resolve();

  constructor(options?: {
    filePath?: string;
    now?: () => Date;
  }) {
    this.filePath = options?.filePath ?? DEFAULT_STATE_FILE;
    this.now = options?.now ?? (() => new Date());
    this.state = {
      version: 1,
      projects: [],
      assignments: {},
    };
  }

  async init(): Promise<void> {
    await mkdir(dirname(this.filePath), { recursive: true });
    try {
      const raw = await readFile(this.filePath, "utf-8");
      const parsed = JSON.parse(raw) as Partial<WorkspaceStateV1>;
      if (parsed.version !== 1) return;

      const projects = Array.isArray(parsed.projects)
        ? parsed.projects.filter(validProject).map(cloneProject)
        : [];
      const assignments = Object.fromEntries(
        Object.entries(parsed.assignments ?? {})
          .filter(([, value]) => validAssignment(value))
          .map(([key, value]) => [key, cloneAssignment(value)]),
      );
      this.state = {
        version: 1,
        projects,
        assignments,
      };
    } catch {
      // Missing or corrupt state starts clean. The first mutation rewrites it.
    }
  }

  listProjects(): WorkspaceProject[] {
    return this.state.projects.map(cloneProject);
  }

  getProject(projectId: string): WorkspaceProject | undefined {
    const project = this.state.projects.find((item) => item.id === projectId);
    return project ? cloneProject(project) : undefined;
  }

  async createProject(name: string, rootPaths: string[]): Promise<WorkspaceProject> {
    return this.mutate(async () => {
      const timestamp = this.now().toISOString();
      const project: WorkspaceProject = {
        id: randomUUID(),
        name: name.trim(),
        rootPaths: [...rootPaths],
        createdAt: timestamp,
        updatedAt: timestamp,
      };
      this.state.projects.push(project);
      try {
        await this.save();
      } catch (error) {
        this.state.projects = this.state.projects.filter(
          (item) => item.id !== project.id,
        );
        throw error;
      }
      return cloneProject(project);
    });
  }

  async updateProject(
    projectId: string,
    name: string,
    rootPaths: string[],
  ): Promise<WorkspaceProject | undefined> {
    return this.mutate(async () => {
      const project = this.state.projects.find((item) => item.id === projectId);
      if (!project) return undefined;
      const previous = cloneProject(project);
      project.name = name.trim();
      project.rootPaths = [...rootPaths];
      project.updatedAt = this.now().toISOString();
      try {
        await this.save();
      } catch (error) {
        Object.assign(project, previous);
        throw error;
      }
      return cloneProject(project);
    });
  }

  async removeProject(projectId: string): Promise<boolean> {
    return this.mutate(async () => {
      const next = this.state.projects.filter((item) => item.id !== projectId);
      if (next.length === this.state.projects.length) return false;
      const previous = this.state.projects;
      this.state.projects = next;
      try {
        await this.save();
      } catch (error) {
        this.state.projects = previous;
        throw error;
      }
      return true;
    });
  }

  async assignSession(
    provider: WorkspaceProvider,
    providerSessionId: string,
    workspace: ResolvedWorkspace,
  ): Promise<void> {
    await this.mutate(async () => {
      const assignment: SessionWorkspaceAssignment = {
        provider,
        providerSessionId,
        kind: workspace.kind,
        ...(workspace.projectId ? { projectId: workspace.projectId } : {}),
        rootPaths: [...workspace.rootPaths],
        assignedAt: this.now().toISOString(),
      };
      const key = assignmentKey(provider, providerSessionId);
      const previous = this.state.assignments[key];
      this.state.assignments[key] = assignment;
      try {
        await this.save();
      } catch (error) {
        if (previous) {
          this.state.assignments[key] = previous;
        } else {
          delete this.state.assignments[key];
        }
        throw error;
      }
    });
  }

  getAssignment(
    provider: WorkspaceProvider,
    providerSessionId: string,
  ): SessionWorkspaceAssignment | undefined {
    const assignment =
      this.state.assignments[assignmentKey(provider, providerSessionId)];
    return assignment ? cloneAssignment(assignment) : undefined;
  }

  resolveRecentWorkspace(
    provider: WorkspaceProvider,
    providerSessionId: string,
  ): ResolvedWorkspace | undefined {
    const assignment = this.getAssignment(provider, providerSessionId);
    if (!assignment) return undefined;
    const project = assignment.projectId
      ? this.getProject(assignment.projectId)
      : undefined;
    return {
      kind: assignment.kind,
      ...(assignment.projectId ? { projectId: assignment.projectId } : {}),
      ...(project ? { projectName: project.name } : {}),
      rootPaths: assignment.rootPaths,
    };
  }

  private save(): Promise<void> {
    const snapshot = JSON.stringify(this.state, null, 2);
    this.saveQueue = this.saveQueue.catch(() => undefined).then(async () => {
      const tmpPath = `${this.filePath}.tmp`;
      await writeFile(tmpPath, snapshot, "utf-8");
      await rename(tmpPath, this.filePath);
      await access(this.filePath, constants.R_OK);
    });
    return this.saveQueue;
  }

  private mutate<T>(operation: () => Promise<T>): Promise<T> {
    const result = this.mutationQueue
      .catch(() => undefined)
      .then(operation);
    this.mutationQueue = result.then(
      () => undefined,
      () => undefined,
    );
    return result;
  }
}
