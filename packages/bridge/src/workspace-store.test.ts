import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { WorkspaceStore } from "./workspace-store.js";

describe("WorkspaceStore", () => {
  const tempDirectories: string[] = [];

  afterEach(async () => {
    await Promise.all(
      tempDirectories.splice(0).map((path) => rm(path, { recursive: true })),
    );
  });

  async function createStore() {
    const root = await mkdtemp(join(tmpdir(), "ccpocket-workspaces-"));
    tempDirectories.push(root);
    const statePath = join(root, "workspaces.json");
    const store = new WorkspaceStore({
      filePath: statePath,
      now: () => new Date("2026-09-01T10:00:00.000Z"),
    });
    await store.init();
    return { root, statePath, store };
  }

  it("persists ordered Project roots", async () => {
    const { statePath, store } = await createStore();
    const project = await store.createProject("App and API", [
      "/repo/app",
      "/repo/api",
    ]);

    expect(store.getProject(project.id)?.rootPaths).toEqual([
      "/repo/app",
      "/repo/api",
    ]);
    const raw = JSON.parse(await readFile(statePath, "utf-8"));
    expect(raw.projects[0].name).toBe("App and API");
  });

  it("restores a session from its root snapshot after Project edits", async () => {
    const { store } = await createStore();
    const project = await store.createProject("Workspace", ["/repo/a", "/repo/b"]);
    await store.assignSession("codex", "thread-1", {
      kind: "project",
      projectId: project.id,
      projectName: project.name,
      rootPaths: project.rootPaths,
    });
    await store.updateProject(project.id, "Changed", ["/repo/a", "/repo/c"]);

    expect(store.getAssignment("codex", "thread-1")?.rootPaths).toEqual([
      "/repo/a",
      "/repo/b",
    ]);
    expect(
      store.resolveRecentWorkspace("codex", "thread-1")?.projectName,
    ).toBe("Changed");
  });

  it("keeps the assigned Project name after the Project is removed", async () => {
    const { store } = await createStore();
    const project = await store.createProject("Workspace", ["/repo/a"]);
    await store.assignSession("codex", "thread-1", {
      kind: "project",
      projectId: project.id,
      projectName: project.name,
      rootPaths: project.rootPaths,
    });

    await store.removeProject(project.id);

    expect(store.resolveRecentWorkspace("codex", "thread-1")).toEqual({
      kind: "project",
      projectId: project.id,
      projectName: "Workspace",
      rootPaths: ["/repo/a"],
    });
  });

  it("does not infer Project identity from an unassigned primary cwd", async () => {
    const { store } = await createStore();
    await store.createProject("Only", ["/repo"]);

    expect(
      store.resolveRecentWorkspace("claude", "unassigned-session"),
    ).toBeUndefined();
  });
});
