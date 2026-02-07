import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { join } from "node:path";
import { mkdirSync, writeFileSync, rmSync, existsSync, realpathSync, readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";
import {
  parseGtrConfig,
  matchGlob,
  worktreesRoot,
  worktreePath,
  defaultBranch,
  createWorktree,
  listWorktrees,
  removeWorktree,
  worktreeExists,
  copyConfiguredFiles,
} from "./worktree.js";

// ---- parseGtrConfig ----

describe("parseGtrConfig", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = join(tmpdir(), `gtr-test-${randomUUID().slice(0, 8)}`);
    mkdirSync(tempDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("returns empty config when no .gtrconfig exists", () => {
    const config = parseGtrConfig(tempDir);
    expect(config.copy.include).toEqual([]);
    expect(config.copy.exclude).toEqual([]);
    expect(config.hook.postCreate).toEqual([]);
    expect(config.hook.preRemove).toEqual([]);
  });

  it("parses [copy] section with include/exclude patterns", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "[copy]",
        "include = **/.env.example",
        "include = *.md",
        "exclude = **/.env",
        "includeDirs = node_modules",
        "excludeDirs = node_modules/.cache",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.copy.include).toEqual(["**/.env.example", "*.md"]);
    expect(config.copy.exclude).toEqual(["**/.env"]);
    expect(config.copy.includeDirs).toEqual(["node_modules"]);
    expect(config.copy.excludeDirs).toEqual(["node_modules/.cache"]);
  });

  it("parses [hook] section with postCreate/preRemove commands", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "[hook]",
        "postCreate = npm install",
        "postCreate = cp .env.example .env",
        "preRemove = rm -rf node_modules",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.hook.postCreate).toEqual(["npm install", "cp .env.example .env"]);
    expect(config.hook.preRemove).toEqual(["rm -rf node_modules"]);
  });

  it("ignores comments and blank lines", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "# This is a comment",
        "",
        "; Another comment",
        "[copy]",
        "include = *.md",
        "",
        "# Another comment",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.copy.include).toEqual(["*.md"]);
  });

  it("parses multiple sections", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "[copy]",
        "include = .env.example",
        "[hook]",
        "postCreate = echo hello",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.copy.include).toEqual([".env.example"]);
    expect(config.hook.postCreate).toEqual(["echo hello"]);
  });

  it("parses [hooks] section (plural) for gtr CLI compatibility", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "[hooks]",
        "postCreate = npm install",
        "preRemove = echo cleanup",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.hook.postCreate).toEqual(["npm install"]);
    expect(config.hook.preRemove).toEqual(["echo cleanup"]);
  });

  it("ignores unknown sections and keys", () => {
    writeFileSync(
      join(tempDir, ".gtrconfig"),
      [
        "[unknown]",
        "foo = bar",
        "[copy]",
        "unknown_key = value",
        "include = *.md",
      ].join("\n"),
    );
    const config = parseGtrConfig(tempDir);
    expect(config.copy.include).toEqual(["*.md"]);
  });
});

// ---- matchGlob ----

describe("matchGlob", () => {
  it("matches exact file name", () => {
    expect(matchGlob("README.md", "README.md")).toBe(true);
    expect(matchGlob("README.md", "CHANGELOG.md")).toBe(false);
  });

  it("matches * wildcard (single segment)", () => {
    expect(matchGlob("*.md", "README.md")).toBe(true);
    expect(matchGlob("*.md", "docs/README.md")).toBe(false);
    expect(matchGlob("*.ts", "index.ts")).toBe(true);
  });

  it("matches ** wildcard (multi-segment)", () => {
    expect(matchGlob("**/.env.example", ".env.example")).toBe(true);
    expect(matchGlob("**/.env.example", "sub/.env.example")).toBe(true);
    expect(matchGlob("**/.env.example", "a/b/c/.env.example")).toBe(true);
  });

  it("matches ? wildcard (single character)", () => {
    expect(matchGlob("file?.txt", "file1.txt")).toBe(true);
    expect(matchGlob("file?.txt", "fileA.txt")).toBe(true);
    expect(matchGlob("file?.txt", "file12.txt")).toBe(false);
  });

  it("handles combined patterns", () => {
    expect(matchGlob("src/**/*.ts", "src/index.ts")).toBe(true);
    expect(matchGlob("src/**/*.ts", "src/utils/helper.ts")).toBe(true);
    expect(matchGlob("src/**/*.ts", "lib/index.ts")).toBe(false);
  });
});

// ---- Path computation ----

describe("worktreesRoot", () => {
  it("computes worktrees root directory", () => {
    expect(worktreesRoot("/Users/foo/projects/myapp")).toBe(
      "/Users/foo/projects/myapp-worktrees",
    );
  });
});

describe("worktreePath", () => {
  it("computes worktree path for simple branch", () => {
    expect(worktreePath("/Users/foo/projects/myapp", "feature-x")).toBe(
      "/Users/foo/projects/myapp-worktrees/feature-x",
    );
  });

  it("converts slashes in branch name to dashes", () => {
    expect(worktreePath("/Users/foo/projects/myapp", "ccpocket/abc123")).toBe(
      "/Users/foo/projects/myapp-worktrees/ccpocket-abc123",
    );
  });
});

describe("defaultBranch", () => {
  it("generates ccpocket/<sessionId> format", () => {
    expect(defaultBranch("abc12345")).toBe("ccpocket/abc12345");
  });
});

// ---- Integration tests (require git) ----

describe("createWorktree / listWorktrees / removeWorktree", () => {
  let projectDir: string;

  beforeEach(() => {
    const rawDir = join(tmpdir(), `wt-integ-${randomUUID().slice(0, 8)}`);
    mkdirSync(rawDir, { recursive: true });
    projectDir = realpathSync(rawDir);
    // Initialize a git repo with an initial commit
    execFileSync("git", ["init"], { cwd: projectDir });
    execFileSync("git", ["config", "user.email", "test@test.com"], { cwd: projectDir });
    execFileSync("git", ["config", "user.name", "Test"], { cwd: projectDir });
    writeFileSync(join(projectDir, "README.md"), "# Test");
    execFileSync("git", ["add", "."], { cwd: projectDir });
    execFileSync("git", ["commit", "-m", "initial"], { cwd: projectDir });
  });

  afterEach(() => {
    rmSync(projectDir, { recursive: true, force: true });
    // Also clean up the worktrees directory
    const wtRoot = worktreesRoot(projectDir);
    if (existsSync(wtRoot)) {
      rmSync(wtRoot, { recursive: true, force: true });
    }
  });

  it("creates a worktree with auto-generated branch", () => {
    const wt = createWorktree(projectDir, "test1234");
    expect(wt.branch).toBe("ccpocket/test1234");
    expect(wt.projectPath).toBe(projectDir);
    expect(existsSync(wt.worktreePath)).toBe(true);
    expect(existsSync(join(wt.worktreePath, "README.md"))).toBe(true);
    expect(wt.head).toBeTruthy();
  });

  it("creates a worktree with specified branch", () => {
    const wt = createWorktree(projectDir, "sess123", "feature/my-feature");
    expect(wt.branch).toBe("feature/my-feature");
    expect(existsSync(wt.worktreePath)).toBe(true);
  });

  it("lists created worktrees", () => {
    createWorktree(projectDir, "s1");
    createWorktree(projectDir, "s2");
    const list = listWorktrees(projectDir);
    expect(list).toHaveLength(2);
    expect(list.map((w) => w.branch).sort()).toEqual(["ccpocket/s1", "ccpocket/s2"]);
  });

  it("removes a worktree", () => {
    const wt = createWorktree(projectDir, "rm-test");
    expect(existsSync(wt.worktreePath)).toBe(true);
    removeWorktree(projectDir, wt.worktreePath);
    expect(existsSync(wt.worktreePath)).toBe(false);
    expect(listWorktrees(projectDir)).toHaveLength(0);
  });

  it("copies files when .gtrconfig has copy patterns", () => {
    // Create an untracked file matching the pattern
    writeFileSync(join(projectDir, ".env.example"), "DB_HOST=localhost");
    writeFileSync(
      join(projectDir, ".gtrconfig"),
      ["[copy]", "include = .env.example"].join("\n"),
    );

    const wt = createWorktree(projectDir, "copy-test");
    expect(existsSync(join(wt.worktreePath, ".env.example"))).toBe(true);
  });

  it("returns empty list for non-git directory", () => {
    const nonGitDir = join(tmpdir(), `nongit-${randomUUID().slice(0, 8)}`);
    mkdirSync(nonGitDir, { recursive: true });
    expect(listWorktrees(nonGitDir)).toEqual([]);
    rmSync(nonGitDir, { recursive: true, force: true });
  });
});

describe("worktreeExists", () => {
  it("returns true for existing directory", () => {
    const dir = join(tmpdir(), `exists-${randomUUID().slice(0, 8)}`);
    mkdirSync(dir, { recursive: true });
    expect(worktreeExists(dir)).toBe(true);
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns false for non-existing directory", () => {
    expect(worktreeExists("/nonexistent/path/12345")).toBe(false);
  });
});

// ---- copyConfiguredFiles ----

describe("copyConfiguredFiles", () => {
  let srcDir: string;
  let destDir: string;

  beforeEach(() => {
    const rawSrc = join(tmpdir(), `cf-src-${randomUUID().slice(0, 8)}`);
    const rawDest = join(tmpdir(), `cf-dest-${randomUUID().slice(0, 8)}`);
    mkdirSync(rawSrc, { recursive: true });
    mkdirSync(rawDest, { recursive: true });
    srcDir = realpathSync(rawSrc);
    destDir = realpathSync(rawDest);
  });

  afterEach(() => {
    rmSync(srcDir, { recursive: true, force: true });
    rmSync(destDir, { recursive: true, force: true });
  });

  it("copies files matching include patterns with nested paths", () => {
    mkdirSync(join(srcDir, "sub", "dir"), { recursive: true });
    writeFileSync(join(srcDir, "sub", "dir", ".env.example"), "SECRET=abc");

    const config = parseGtrConfig(srcDir);
    config.copy.include = ["**/.env.example"];

    copyConfiguredFiles(srcDir, destDir, config);

    expect(existsSync(join(destDir, "sub", "dir", ".env.example"))).toBe(true);
    expect(readFileSync(join(destDir, "sub", "dir", ".env.example"), "utf-8")).toBe("SECRET=abc");
  });

  it("excludes files matching exclude patterns", () => {
    writeFileSync(join(srcDir, "other.txt"), "keep");
    writeFileSync(join(srcDir, "secret.txt"), "hidden");

    const config = parseGtrConfig(srcDir);
    config.copy.include = ["*.txt"];
    config.copy.exclude = ["secret.txt"];

    copyConfiguredFiles(srcDir, destDir, config);

    expect(existsSync(join(destDir, "other.txt"))).toBe(true);
    expect(existsSync(join(destDir, "secret.txt"))).toBe(false);
  });

  it("copies directories matching includeDirs", () => {
    mkdirSync(join(srcDir, "vendor"), { recursive: true });
    writeFileSync(join(srcDir, "vendor", "lib.js"), "module.exports = {};\n");
    writeFileSync(join(srcDir, "vendor", "data.json"), "{}");

    const config = parseGtrConfig(srcDir);
    config.copy.includeDirs = ["vendor"];

    copyConfiguredFiles(srcDir, destDir, config);

    expect(existsSync(join(destDir, "vendor", "lib.js"))).toBe(true);
    expect(existsSync(join(destDir, "vendor", "data.json"))).toBe(true);
  });

  it("excludes directories matching excludeDirs", () => {
    mkdirSync(join(srcDir, "vendor"), { recursive: true });
    writeFileSync(join(srcDir, "vendor", "lib.js"), "ok");
    mkdirSync(join(srcDir, "cache"), { recursive: true });
    writeFileSync(join(srcDir, "cache", "tmp.dat"), "cached");

    const config = parseGtrConfig(srcDir);
    config.copy.includeDirs = ["*"];
    config.copy.excludeDirs = ["cache"];

    copyConfiguredFiles(srcDir, destDir, config);

    expect(existsSync(join(destDir, "vendor", "lib.js"))).toBe(true);
    expect(existsSync(join(destDir, "cache"))).toBe(false);
  });
});

// ---- createWorktree - hooks ----

describe("createWorktree - hooks", () => {
  let projectDir: string;

  beforeEach(() => {
    const rawDir = join(tmpdir(), `wt-hook-${randomUUID().slice(0, 8)}`);
    mkdirSync(rawDir, { recursive: true });
    projectDir = realpathSync(rawDir);
    execFileSync("git", ["init"], { cwd: projectDir });
    execFileSync("git", ["config", "user.email", "test@test.com"], { cwd: projectDir });
    execFileSync("git", ["config", "user.name", "Test"], { cwd: projectDir });
    writeFileSync(join(projectDir, "README.md"), "# Test");
    execFileSync("git", ["add", "."], { cwd: projectDir });
    execFileSync("git", ["commit", "-m", "initial"], { cwd: projectDir });
  });

  afterEach(() => {
    rmSync(projectDir, { recursive: true, force: true });
    const wtRoot = worktreesRoot(projectDir);
    if (existsSync(wtRoot)) {
      rmSync(wtRoot, { recursive: true, force: true });
    }
  });

  it("runs postCreate hooks in worktree directory", () => {
    writeFileSync(
      join(projectDir, ".gtrconfig"),
      ["[hook]", "postCreate = touch hook-ran.txt"].join("\n"),
    );

    const wt = createWorktree(projectDir, "hook-post");
    expect(existsSync(join(wt.worktreePath, "hook-ran.txt"))).toBe(true);
  });

  it("runs preRemove hooks before removal", () => {
    writeFileSync(
      join(projectDir, ".gtrconfig"),
      [
        "[hook]",
        "postCreate = touch marker.txt",
        "preRemove = cp marker.txt ../preremove-ran.txt",
      ].join("\n"),
    );

    const wt = createWorktree(projectDir, "hook-pre");
    expect(existsSync(join(wt.worktreePath, "marker.txt"))).toBe(true);

    removeWorktree(projectDir, wt.worktreePath);

    const wtRoot = worktreesRoot(projectDir);
    expect(existsSync(join(wtRoot, "preremove-ran.txt"))).toBe(true);
  });

  it("continues if postCreate hook fails", () => {
    writeFileSync(
      join(projectDir, ".gtrconfig"),
      ["[hook]", "postCreate = false"].join("\n"),
    );

    const wt = createWorktree(projectDir, "hook-fail");
    expect(existsSync(wt.worktreePath)).toBe(true);
    expect(existsSync(join(wt.worktreePath, "README.md"))).toBe(true);
  });
});

// ---- createWorktree - edge cases ----

describe("createWorktree - edge cases", () => {
  let projectDir: string;

  beforeEach(() => {
    const rawDir = join(tmpdir(), `wt-edge-${randomUUID().slice(0, 8)}`);
    mkdirSync(rawDir, { recursive: true });
    projectDir = realpathSync(rawDir);
    execFileSync("git", ["init"], { cwd: projectDir });
    execFileSync("git", ["config", "user.email", "test@test.com"], { cwd: projectDir });
    execFileSync("git", ["config", "user.name", "Test"], { cwd: projectDir });
    writeFileSync(join(projectDir, "README.md"), "# Test");
    execFileSync("git", ["add", "."], { cwd: projectDir });
    execFileSync("git", ["commit", "-m", "initial"], { cwd: projectDir });
  });

  afterEach(() => {
    rmSync(projectDir, { recursive: true, force: true });
    const wtRoot = worktreesRoot(projectDir);
    if (existsSync(wtRoot)) {
      rmSync(wtRoot, { recursive: true, force: true });
    }
  });

  it("creates worktree when branch already exists from previous worktree", () => {
    const wt1 = createWorktree(projectDir, "reuse-branch");
    const branchName = wt1.branch;
    removeWorktree(projectDir, wt1.worktreePath);

    const wt2 = createWorktree(projectDir, "reuse-branch");
    expect(wt2.branch).toBe(branchName);
    expect(existsSync(wt2.worktreePath)).toBe(true);
    expect(existsSync(join(wt2.worktreePath, "README.md"))).toBe(true);
  });

  it("multiple worktrees have independent file systems", () => {
    const wt1 = createWorktree(projectDir, "indep1");
    const wt2 = createWorktree(projectDir, "indep2");

    writeFileSync(join(wt1.worktreePath, "only-in-wt1.txt"), "hello");

    expect(existsSync(join(wt1.worktreePath, "only-in-wt1.txt"))).toBe(true);
    expect(existsSync(join(wt2.worktreePath, "only-in-wt1.txt"))).toBe(false);
  });

  it("worktree HEAD matches project HEAD on creation", () => {
    const projectHead = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: projectDir,
      encoding: "utf-8",
    }).trim();

    const wt = createWorktree(projectDir, "head-check");
    expect(wt.head).toBe(projectHead);
  });

  it("listWorktrees includes head commit for each worktree", () => {
    createWorktree(projectDir, "list-head1");
    createWorktree(projectDir, "list-head2");

    const list = listWorktrees(projectDir);
    expect(list).toHaveLength(2);
    for (const wt of list) {
      expect(wt.head).toBeTruthy();
      expect(typeof wt.head).toBe("string");
      expect(wt.head).toMatch(/^[0-9a-f]{40}$/);
    }
  });
});
