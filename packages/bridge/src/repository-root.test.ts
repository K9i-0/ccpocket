import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  createRepositoryRootResolver,
  normalizeRepositoryUrl,
} from "./repository-root.js";

function git(cwd: string, args: string[]): void {
  execFileSync("git", args, { cwd, stdio: "ignore" });
}

describe("normalizeRepositoryUrl", () => {
  it("treats SSH, scp-like and HTTPS remotes of the same repository as equal", () => {
    const expected = "github.com/owner/repo";
    expect(normalizeRepositoryUrl("git@github.com:owner/repo.git")).toBe(expected);
    expect(normalizeRepositoryUrl("https://github.com/owner/repo")).toBe(expected);
    expect(normalizeRepositoryUrl("https://github.com/Owner/Repo.git/")).toBe(expected);
    expect(normalizeRepositoryUrl("ssh://git@github.com/owner/repo.git")).toBe(expected);
    expect(normalizeRepositoryUrl("https://user:token@github.com/owner/repo.git")).toBe(expected);
  });

  it("keeps path casing for non-GitHub hosts, which may be case-sensitive", () => {
    expect(normalizeRepositoryUrl("git@Git.Example.com:Team/Repo.git")).toBe(
      "git.example.com/Team/Repo",
    );
    expect(normalizeRepositoryUrl("https://git.example.com/team/repo")).not.toBe(
      normalizeRepositoryUrl("https://git.example.com/Team/Repo"),
    );
  });

  it("strips only a lowercase .git suffix", () => {
    expect(normalizeRepositoryUrl("https://git.example.com/team/repo.GIT")).toBe(
      "git.example.com/team/repo.GIT",
    );
  });

  it("returns null for empty input", () => {
    expect(normalizeRepositoryUrl("")).toBeNull();
    expect(normalizeRepositoryUrl("   ")).toBeNull();
  });
});

describe("createRepositoryRootResolver", () => {
  let root: string;
  let repo: string;

  beforeEach(() => {
    root = realpathSync(mkdtempSync(join(tmpdir(), "repo-root-")));
    repo = join(root, "app");
    mkdirSync(repo);
    git(repo, ["init", "-q", "-b", "main"]);
    git(repo, ["config", "user.email", "test@example.com"]);
    git(repo, ["config", "user.name", "Test"]);
    writeFileSync(join(repo, "README.md"), "hello\n");
    git(repo, ["add", "."]);
    git(repo, ["commit", "-q", "-m", "init"]);
    git(repo, ["remote", "add", "origin", "git@github.com:owner/app.git"]);
  });

  afterEach(() => {
    rmSync(root, { recursive: true, force: true });
  });

  it("resolves a sibling git worktree to the main repository", async () => {
    const worktree = join(root, "app-feature-1");
    git(repo, ["worktree", "add", "-q", "-b", "feature-1", worktree]);

    const resolver = createRepositoryRootResolver();
    expect(await resolver.resolvePath(worktree)).toBe(repo);
  });

  it("resolves the main repository to itself", async () => {
    const resolver = createRepositoryRootResolver();
    expect(await resolver.resolvePath(repo)).toBe(repo);
  });

  it("does not treat a subdirectory as a separate repository", async () => {
    const sub = join(repo, "packages");
    mkdirSync(sub);
    const resolver = createRepositoryRootResolver();
    expect(await resolver.resolvePath(sub)).toBeNull();
  });

  it("returns null for missing directories and non-git directories", async () => {
    const plain = join(root, "plain");
    mkdirSync(plain);
    const resolver = createRepositoryRootResolver();
    expect(await resolver.resolvePath(join(root, "missing"))).toBeNull();
    expect(await resolver.resolvePath(plain)).toBeNull();
  });

  it("caches git lookups per path", async () => {
    const runGit = vi.fn(async () => `${repo}/.git\n`);
    const resolver = createRepositoryRootResolver({ runGit });
    await resolver.resolvePath(repo);
    await resolver.resolvePath(repo);
    expect(runGit).toHaveBeenCalledTimes(1);
  });

  it("maps a repository URL to the single local checkout with that origin", async () => {
    const other = join(root, "other");
    mkdirSync(other);
    git(other, ["init", "-q"]);
    git(other, ["remote", "add", "origin", "https://github.com/owner/other.git"]);

    const resolver = createRepositoryRootResolver();
    expect(
      await resolver.resolveRepositoryUrl("https://github.com/owner/app", [repo, other]),
    ).toBe(repo);
    expect(
      await resolver.resolveRepositoryUrl("git@github.com:owner/unknown.git", [repo, other]),
    ).toBeNull();
  });

  it("does not guess when several checkouts share the same origin", async () => {
    const clone = join(root, "app-clone");
    mkdirSync(clone);
    git(clone, ["init", "-q"]);
    git(clone, ["remote", "add", "origin", "https://github.com/owner/app.git"]);

    const resolver = createRepositoryRootResolver();
    expect(
      await resolver.resolveRepositoryUrl("git@github.com:owner/app.git", [repo, clone]),
    ).toBeNull();
  });
});
