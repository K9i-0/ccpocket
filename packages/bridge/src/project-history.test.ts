import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { readFile, rm, mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { randomUUID } from "node:crypto";
import { ProjectHistory } from "./project-history.js";

let tempDir: string;
let historyFile: string;

beforeEach(async () => {
  tempDir = join(tmpdir(), `ph-test-${randomUUID().slice(0, 8)}`);
  await mkdir(tempDir, { recursive: true });
  historyFile = join(tempDir, "project-history.json");
});

afterEach(async () => {
  await rm(tempDir, { recursive: true, force: true });
});

describe("ProjectHistory", () => {
  it("init creates directory and starts with empty projects", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    expect(ph.getProjects()).toEqual([]);
  });

  it("addProject adds a project to the front", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a");
    ph.addProject("/path/b");
    expect(ph.getProjects()).toEqual(["/path/b", "/path/a"]);
  });

  it("addProject moves existing project to front", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a");
    ph.addProject("/path/b");
    ph.addProject("/path/a");
    expect(ph.getProjects()).toEqual(["/path/a", "/path/b"]);
  });

  it("addProject enforces max 20 projects", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    for (let i = 0; i < 25; i++) {
      ph.addProject(`/path/${i}`);
    }
    const projects = ph.getProjects();
    expect(projects.length).toBe(20);
    // Most recent should be first
    expect(projects[0]).toBe("/path/24");
    expect(projects[19]).toBe("/path/5");
  });

  it("removeProject removes a project", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a");
    ph.addProject("/path/b");
    ph.removeProject("/path/a");
    expect(ph.getProjects()).toEqual(["/path/b"]);
  });

  it("removeProject is a no-op for non-existent path", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a");
    ph.removeProject("/path/nonexistent");
    expect(ph.getProjects()).toEqual(["/path/a"]);
  });

  it("getProjects returns a copy (not a reference)", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a");
    const projects = ph.getProjects();
    projects.push("/path/mutated");
    expect(ph.getProjects()).toEqual(["/path/a"]);
  });

  it("persists to disk and reloads", async () => {
    const ph1 = new ProjectHistory(historyFile);
    await ph1.init();
    ph1.addProject("/path/a");
    ph1.addProject("/path/b");

    // Wait for async save to complete
    await new Promise((r) => setTimeout(r, 100));

    // Verify file exists and contains correct data
    const data = JSON.parse(await readFile(historyFile, "utf-8"));
    expect(data).toEqual(["/path/b", "/path/a"]);

    // New instance should load from disk
    const ph2 = new ProjectHistory(historyFile);
    await ph2.init();
    expect(ph2.getProjects()).toEqual(["/path/b", "/path/a"]);
  });

  it("handles corrupt file gracefully", async () => {
    await writeFile(historyFile, "not valid json", "utf-8");

    const ph = new ProjectHistory(historyFile);
    await ph.init();
    expect(ph.getProjects()).toEqual([]);
  });
});
