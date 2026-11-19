import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { rm, mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { randomUUID } from "node:crypto";
import { ProjectHistory } from "./project-history.js";

/** Holds one index write open so a second write can race it. */
const writeGate = vi.hoisted(() => ({
  armed: false,
  path: "",
  calls: 0,
  waiters: [] as Array<() => void>,
}));

vi.mock("node:fs/promises", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:fs/promises")>();
  return {
    ...actual,
    writeFile: async (
      path: Parameters<typeof actual.writeFile>[0],
      data: Parameters<typeof actual.writeFile>[1],
      options?: Parameters<typeof actual.writeFile>[2],
    ) => {
      if (String(path) === writeGate.path) {
        writeGate.calls += 1;
        if (writeGate.armed) {
          writeGate.armed = false;
          await new Promise<void>((resolve) => writeGate.waiters.push(resolve));
        }
      }
      return actual.writeFile(path, data, options);
    },
  };
});

let tempDir: string;
let historyFile: string;

beforeEach(async () => {
  tempDir = join(tmpdir(), `ph-test-${randomUUID().slice(0, 8)}`);
  await mkdir(tempDir, { recursive: true });
  historyFile = join(tempDir, "project-history.json");
});

afterEach(async () => {
  // The store saves without blocking its caller; let those writes land before
  // the temp directory goes away.
  await new Promise((resolve) => setTimeout(resolve, 10));
  // A write that lands while the directory is being removed fails the
  // removal with ENOTEMPTY; retrying lets it finish first.
  await rm(tempDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 20 });
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

  it("accepts Windows drive and UNC project paths and normalizes worktrees on add/remove", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();

    ph.addProject("C:\\Users\\alice\\project-a");
    ph.addProject("\\\\fileserver\\share\\project-b");
    ph.addProject("C:\\shallow"); // too shallow (2 segments)
    ph.addProject("D:\\Users\\alice\\project-c-worktrees\\feat");
    expect(ph.getProjects()).toEqual([
      "D:\\Users\\alice\\project-c",
      "\\\\fileserver\\share\\project-b",
      "C:\\Users\\alice\\project-a",
    ]);

    ph.removeProject("D:\\Users\\alice\\project-c-worktrees\\feat");
    expect(ph.getProjects()).toEqual([
      "\\\\fileserver\\share\\project-b",
      "C:\\Users\\alice\\project-a",
    ]);
  });

  it("does not let an in-flight save overwrite a newer one", async () => {
    const ph = new ProjectHistory(historyFile);
    await ph.init();

    writeGate.path = historyFile;
    writeGate.calls = 0;
    writeGate.armed = true;

    // Two quick project switches: the second save must queue behind the first
    // instead of writing the file at the same time.
    ph.addProject("/Users/test/project-a");
    ph.addProject("/Users/test/project-b");
    await new Promise((resolve) => setImmediate(resolve));
    expect(writeGate.calls).toBe(1);

    writeGate.waiters.shift()?.();
    await waitFor(async () => {
      try {
        const saved = JSON.parse(await readFile(historyFile, "utf-8"));
        return Array.isArray(saved) && saved.length === 2;
      } catch {
        return false;
      }
    });

    expect(JSON.parse(await readFile(historyFile, "utf-8"))).toEqual([
      "/Users/test/project-b",
      "/Users/test/project-a",
    ]);
  });
});

async function waitFor(check: () => Promise<boolean> | boolean): Promise<void> {
  const deadline = Date.now() + 2000;
  while (!(await check())) {
    if (Date.now() > deadline) throw new Error("timed out waiting for the saved file");
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
}
