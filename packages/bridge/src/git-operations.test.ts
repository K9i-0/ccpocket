import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { join } from "node:path";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";
import {
  stageFiles,
  stageHunks,
  unstageFiles,
  unstageHunks,
  gitCommit,
  gitStatus,
  listBranches,
  createBranch,
  checkoutBranch,
  revertHunks,
} from "./git-operations.js";

// ---- Test Helpers ----

/** Create a temporary git repository with an initial commit. */
function createTempRepo(): string {
  const dir = join(tmpdir(), `git-ops-test-${randomUUID().slice(0, 8)}`);
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init"], { cwd: dir });
  execFileSync("git", ["config", "user.email", "test@test.com"], { cwd: dir });
  execFileSync("git", ["config", "user.name", "Test"], { cwd: dir });
  writeFileSync(join(dir, "initial.txt"), "initial\n");
  execFileSync("git", ["add", "."], { cwd: dir });
  execFileSync("git", ["commit", "-m", "initial"], { cwd: dir });
  return dir;
}

function gitCmd(args: string[], cwd: string): string {
  return execFileSync("git", args, { cwd, encoding: "utf-8" }).trim();
}

function createBareRemote(): string {
  const dir = join(tmpdir(), `git-ops-remote-${randomUUID().slice(0, 8)}`);
  mkdirSync(dir, { recursive: true });
  execFileSync("git", ["init", "--bare"], { cwd: dir });
  return dir;
}

// ---- Phase 1: Staging ----

describe("stageFiles", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("stages specified files into the index", () => {
    writeFileSync(join(repo, "a.txt"), "aaa\n");
    writeFileSync(join(repo, "b.txt"), "bbb\n");

    stageFiles(repo, ["a.txt"]);

    const staged = gitCmd(["diff", "--cached", "--name-only"], repo);
    expect(staged).toBe("a.txt");
  });

  it("stages multiple files at once", () => {
    writeFileSync(join(repo, "a.txt"), "aaa\n");
    writeFileSync(join(repo, "b.txt"), "bbb\n");

    stageFiles(repo, ["a.txt", "b.txt"]);

    const staged = gitCmd(["diff", "--cached", "--name-only"], repo);
    expect(staged.split("\n").sort()).toEqual(["a.txt", "b.txt"]);
  });

  it("throws for non-existent file", () => {
    expect(() => stageFiles(repo, ["nonexistent.txt"])).toThrow();
  });
});

describe("stageHunks", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("stages only the specified hunk from a multi-hunk file", () => {
    // Create a file with multiple separated regions
    const lines: string[] = [];
    for (let i = 0; i < 20; i++) lines.push(`line ${i}`);
    writeFileSync(join(repo, "multi.txt"), lines.join("\n") + "\n");
    execFileSync("git", ["add", "multi.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add multi"], { cwd: repo });

    // Modify two separated regions to create two hunks
    const modified = [...lines];
    modified[2] = "CHANGED line 2";
    modified[17] = "CHANGED line 17";
    writeFileSync(join(repo, "multi.txt"), modified.join("\n") + "\n");

    // Stage only hunk 0
    stageHunks(repo, [{ file: "multi.txt", hunkIndex: 0 }]);

    // Verify only the first change is staged
    const cachedDiff = gitCmd(["diff", "--cached"], repo);
    expect(cachedDiff).toContain("CHANGED line 2");
    expect(cachedDiff).not.toContain("CHANGED line 17");

    // Verify the second change is still in working tree
    const workDiff = gitCmd(["diff"], repo);
    expect(workDiff).toContain("CHANGED line 17");
  });

  it("stages all requested hunks when multiple specified", () => {
    const lines: string[] = [];
    for (let i = 0; i < 20; i++) lines.push(`line ${i}`);
    writeFileSync(join(repo, "multi.txt"), lines.join("\n") + "\n");
    execFileSync("git", ["add", "multi.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add multi"], { cwd: repo });

    const modified = [...lines];
    modified[2] = "CHANGED line 2";
    modified[17] = "CHANGED line 17";
    writeFileSync(join(repo, "multi.txt"), modified.join("\n") + "\n");

    stageHunks(repo, [
      { file: "multi.txt", hunkIndex: 0 },
      { file: "multi.txt", hunkIndex: 1 },
    ]);

    const cachedDiff = gitCmd(["diff", "--cached"], repo);
    expect(cachedDiff).toContain("CHANGED line 2");
    expect(cachedDiff).toContain("CHANGED line 17");
  });

  it("throws for out-of-range hunk index", () => {
    writeFileSync(join(repo, "a.txt"), "changed\n");

    // a.txt is untracked, stage it first then modify
    execFileSync("git", ["add", "a.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add a"], { cwd: repo });
    writeFileSync(join(repo, "a.txt"), "modified\n");

    expect(() => stageHunks(repo, [{ file: "a.txt", hunkIndex: 5 }])).toThrow(
      /out of range/,
    );
  });
});

describe("unstageFiles", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("removes staged files from the index", () => {
    writeFileSync(join(repo, "a.txt"), "aaa\n");
    execFileSync("git", ["add", "a.txt"], { cwd: repo });

    unstageFiles(repo, ["a.txt"]);

    const staged = gitCmd(["diff", "--cached", "--name-only"], repo);
    expect(staged).toBe("");
  });

  it("is safe when file is not staged", () => {
    // Should not throw for an already-unstaged tracked file
    expect(() => unstageFiles(repo, ["initial.txt"])).not.toThrow();
  });
});

describe("unstageHunks", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("unstages only the specified hunk", () => {
    const lines: string[] = [];
    for (let i = 0; i < 20; i++) lines.push(`line ${i}`);
    writeFileSync(join(repo, "multi.txt"), lines.join("\n") + "\n");
    execFileSync("git", ["add", "multi.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add multi"], { cwd: repo });

    const modified = [...lines];
    modified[2] = "CHANGED line 2";
    modified[17] = "CHANGED line 17";
    writeFileSync(join(repo, "multi.txt"), modified.join("\n") + "\n");
    execFileSync("git", ["add", "multi.txt"], { cwd: repo });

    unstageHunks(repo, [{ file: "multi.txt", hunkIndex: 0 }]);

    const cachedDiff = gitCmd(["diff", "--cached"], repo);
    expect(cachedDiff).not.toContain("CHANGED line 2");
    expect(cachedDiff).toContain("CHANGED line 17");

    const workDiff = gitCmd(["diff"], repo);
    expect(workDiff).toContain("CHANGED line 2");
    expect(workDiff).not.toContain("CHANGED line 17");
  });

  it("throws for out-of-range hunk index", () => {
    writeFileSync(join(repo, "a.txt"), "changed\n");
    execFileSync("git", ["add", "a.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add a"], { cwd: repo });
    writeFileSync(join(repo, "a.txt"), "modified\n");
    execFileSync("git", ["add", "a.txt"], { cwd: repo });

    expect(() => unstageHunks(repo, [{ file: "a.txt", hunkIndex: 5 }])).toThrow(
      /out of range/,
    );
  });
});

describe("revertHunks", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("reverts only the specified working-tree hunk", () => {
    const lines: string[] = [];
    for (let i = 0; i < 20; i++) lines.push(`line ${i}`);
    writeFileSync(join(repo, "multi.txt"), lines.join("\n") + "\n");
    execFileSync("git", ["add", "multi.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add multi"], { cwd: repo });

    const modified = [...lines];
    modified[2] = "CHANGED line 2";
    modified[17] = "CHANGED line 17";
    writeFileSync(join(repo, "multi.txt"), modified.join("\n") + "\n");

    revertHunks(repo, [{ file: "multi.txt", hunkIndex: 1 }]);

    const workDiff = gitCmd(["diff"], repo);
    expect(workDiff).toContain("CHANGED line 2");
    expect(workDiff).not.toContain("CHANGED line 17");
  });

  it("throws for out-of-range hunk index", () => {
    writeFileSync(join(repo, "a.txt"), "changed\n");
    execFileSync("git", ["add", "a.txt"], { cwd: repo });
    execFileSync("git", ["commit", "-m", "add a"], { cwd: repo });
    writeFileSync(join(repo, "a.txt"), "modified\n");

    expect(() => revertHunks(repo, [{ file: "a.txt", hunkIndex: 5 }])).toThrow(
      /out of range/,
    );
  });
});

// ---- Phase 2: Commit / Status ----

describe("gitCommit", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("creates a commit and returns hash + message", () => {
    writeFileSync(join(repo, "new.txt"), "hello\n");
    execFileSync("git", ["add", "new.txt"], { cwd: repo });

    const result = gitCommit(repo, "feat: add new file");

    expect(result.hash).toMatch(/^[0-9a-f]+$/);
    expect(result.message).toBe("feat: add new file");

    // Verify commit exists in log
    const log = gitCmd(["log", "--oneline", "-1"], repo);
    expect(log).toContain("feat: add new file");
  });

  it("throws when nothing is staged", () => {
    expect(() => gitCommit(repo, "empty commit")).toThrow(/Nothing to commit/);
  });
});

describe("gitStatus", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("categorizes files correctly", () => {
    // Create staged, unstaged, and untracked files
    writeFileSync(join(repo, "staged.txt"), "staged\n");
    execFileSync("git", ["add", "staged.txt"], { cwd: repo });

    writeFileSync(join(repo, "initial.txt"), "modified\n"); // unstaged (tracked, modified)

    writeFileSync(join(repo, "untracked.txt"), "new\n"); // untracked

    const status = gitStatus(repo);

    expect(status.staged).toContain("staged.txt");
    expect(status.unstaged).toContain("initial.txt");
    expect(status.untracked).toContain("untracked.txt");
  });

  it("returns empty arrays for clean repo", () => {
    const status = gitStatus(repo);
    expect(status.staged).toEqual([]);
    expect(status.unstaged).toEqual([]);
    expect(status.untracked).toEqual([]);
  });
});

// ---- Phase 3: Branch Operations ----

describe("listBranches", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
    // Create some branches
    execFileSync("git", ["branch", "feat/login"], { cwd: repo });
    execFileSync("git", ["branch", "feat/signup"], { cwd: repo });
    execFileSync("git", ["branch", "fix/bug"], { cwd: repo });
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("returns current branch and all branches", () => {
    const result = listBranches(repo);

    expect(result.current).toMatch(/^(main|master)$/);
    expect(result.branches).toContain("feat/login");
    expect(result.branches).toContain("feat/signup");
    expect(result.branches).toContain("fix/bug");
    expect(result.branches.length).toBeGreaterThanOrEqual(4); // main + 3 created
  });

  it("filters branches by query", () => {
    const result = listBranches(repo, "feat");

    expect(result.branches).toContain("feat/login");
    expect(result.branches).toContain("feat/signup");
    expect(result.branches).not.toContain("fix/bug");
  });

  it("query is case-insensitive", () => {
    const result = listBranches(repo, "FEAT");

    expect(result.branches).toContain("feat/login");
    expect(result.branches).toContain("feat/signup");
  });

  it("returns empty branches for no match", () => {
    const result = listBranches(repo, "nonexistent");

    expect(result.branches).toEqual([]);
  });

  it("includes ahead/behind status for branches with upstream", () => {
    const remote = createBareRemote();
    try {
      execFileSync("git", ["remote", "add", "origin", remote], { cwd: repo });
      const current = gitCmd(["rev-parse", "--abbrev-ref", "HEAD"], repo);
      execFileSync("git", ["push", "-u", "origin", current], { cwd: repo });

      execFileSync("git", ["checkout", "feat/login"], { cwd: repo });
      execFileSync("git", ["push", "-u", "origin", "feat/login"], { cwd: repo });

      writeFileSync(join(repo, "ahead.txt"), "ahead\n");
      execFileSync("git", ["add", "ahead.txt"], { cwd: repo });
      execFileSync("git", ["commit", "-m", "ahead commit"], { cwd: repo });

      const result = listBranches(repo);
      expect(result.remoteStatusByBranch["feat/login"]).toMatchObject({
        ahead: 1,
        behind: 0,
        hasUpstream: true,
      });
    } finally {
      rmSync(remote, { recursive: true, force: true });
    }
  });

  it("reports no upstream for branches without tracking", () => {
    const result = listBranches(repo);
    expect(result.remoteStatusByBranch["feat/login"]).toMatchObject({
      ahead: 0,
      behind: 0,
      hasUpstream: false,
    });
  });
});

describe("createBranch", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("creates a branch without checkout", () => {
    createBranch(repo, "new-branch", false);

    const branches = gitCmd(["branch", "--list"], repo);
    expect(branches).toContain("new-branch");

    // Should still be on the original branch
    const current = gitCmd(["rev-parse", "--abbrev-ref", "HEAD"], repo);
    expect(current).toMatch(/^(main|master)$/);
  });

  it("creates and checks out a branch when checkout=true", () => {
    createBranch(repo, "new-branch", true);

    const current = gitCmd(["rev-parse", "--abbrev-ref", "HEAD"], repo);
    expect(current).toBe("new-branch");
  });

  it("throws for duplicate branch name", () => {
    createBranch(repo, "dup-branch", false);
    expect(() => createBranch(repo, "dup-branch", false)).toThrow();
  });
});

describe("checkoutBranch", () => {
  let repo: string;

  beforeEach(() => {
    repo = createTempRepo();
    execFileSync("git", ["branch", "other"], { cwd: repo });
  });
  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  it("switches to the specified branch", () => {
    checkoutBranch(repo, "other");

    const current = gitCmd(["rev-parse", "--abbrev-ref", "HEAD"], repo);
    expect(current).toBe("other");
  });

  it("throws for non-existent branch", () => {
    expect(() => checkoutBranch(repo, "nonexistent")).toThrow();
  });
});
