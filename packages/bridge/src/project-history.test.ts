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
    ph.addProject("/Users/test/project-a");
    ph.addProject("/Users/test/project-b");
    expect(ph.getProjects()).toEqual(["/Users/test/project-b", "/Users/test/project-a"]);
  });

  it("addProject moves existing project to front", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/Users/test/project-a");
    ph.addProject("/Users/test/project-b");
    ph.addProject("/Users/test/project-a");
    expect(ph.getProjects()).toEqual(["/Users/test/project-a", "/Users/test/project-b"]);
  });

  it("addProject enforces max 20 projects", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    for (let i = 0; i < 25; i++) {
      ph.addProject(`/Users/test/project-${i}`);
    }
    const projects = ph.getProjects();
    expect(projects.length).toBe(20);
    // Most recent should be first
    expect(projects[0]).toBe("/Users/test/project-24");
    expect(projects[19]).toBe("/Users/test/project-5");
  });

  it("removeProject removes a project", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/Users/test/project-a");
    ph.addProject("/Users/test/project-b");
    ph.removeProject("/Users/test/project-a");
    expect(ph.getProjects()).toEqual(["/Users/test/project-b"]);
  });

  it("removeProject is a no-op for non-existent path", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/Users/test/project-a");
    ph.removeProject("/Users/test/nonexistent");
    expect(ph.getProjects()).toEqual(["/Users/test/project-a"]);
  });

  it("getProjects returns a copy (not a reference)", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/Users/test/project-a");
    const projects = ph.getProjects();
    projects.push("/Users/test/mutated");
    expect(ph.getProjects()).toEqual(["/Users/test/project-a"]);
  });

  it("persists to disk and reloads", async () => {
    const ph1 = new ProjectHistory(historyFile);
    await ph1.init();
    ph1.addProject("/Users/test/project-a");
    ph1.addProject("/Users/test/project-b");

    // Wait for async save to complete
    await new Promise((r) => setTimeout(r, 100));

    // Verify file exists and contains correct data
    const data = JSON.parse(await readFile(historyFile, "utf-8"));
    expect(data).toEqual(["/Users/test/project-b", "/Users/test/project-a"]);

    // New instance should load from disk
    const ph2 = new ProjectHistory(historyFile);
    await ph2.init();
    expect(ph2.getProjects()).toEqual(["/Users/test/project-b", "/Users/test/project-a"]);
  });

  it("rejects invalid project paths", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    ph.addProject("/path/a"); // too shallow
    ph.addProject("relative/path/project"); // not absolute
    ph.addProject(""); // empty
    ph.addProject("/Users/test/valid-project"); // valid
    expect(ph.getProjects()).toEqual(["/Users/test/valid-project"]);
  });

  it("filters out invalid paths on init", async () => {
    // Write a file with mixed valid and invalid paths
    await writeFile(
      historyFile,
      JSON.stringify(["/path/bad", "/Users/test/good-project", "/also/bad"]),
      "utf-8",
    );
    const ph = new ProjectHistory(historyFile);
    await ph.init();
    expect(ph.getProjects()).toEqual(["/Users/test/good-project"]);
  });

  it("handles corrupt file gracefully", async () => {
    await writeFile(historyFile, "not valid json", "utf-8");

    const ph = new ProjectHistory(historyFile);
    await ph.init();
    expect(ph.getProjects()).toEqual([]);
  });
});
