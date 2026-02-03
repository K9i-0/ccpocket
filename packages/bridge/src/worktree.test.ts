import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { join } from "node:path";
import { mkdirSync, writeFileSync, rmSync, existsSync, realpathSync } from "node:fs";
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
