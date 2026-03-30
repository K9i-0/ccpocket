import { execFileSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { resolve } from "node:path";

// ---- Types ----

export interface HunkRef {
  file: string;
  hunkIndex: number;
}

export interface CommitResult {
  hash: string;
  message: string;
}

export interface PushResult {
  remote: string;
  branch: string;
}

export interface GitStatusResult {
  staged: string[];
  unstaged: string[];
  untracked: string[];
}

export interface BranchRemoteStatus {
  ahead: number;
  behind: number;
  hasUpstream: boolean;
}

export interface BranchListResult {
  current: string;
  branches: string[];
  /** Branches currently checked out by main repo or worktrees (cannot switch to). */
  checkedOutBranches: string[];
  remoteStatusByBranch: Record<string, BranchRemoteStatus>;
}

// ---- Helpers ----

function resolveProject(projectPath: string): string {
  return realpathSync(resolve(projectPath));
}

function git(args: string[], cwd: string): string {
  return execFileSync("git", args, { cwd, encoding: "utf-8" }).trim();
}

function buildHunkPatch(
  diffText: string,
  file: string,
  indices: number[],
): string | null {
  if (!diffText) return null;

  const lines = diffText.split("\n");
  const hunkStarts: number[] = [];
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith("@@")) {
      hunkStarts.push(i);
    }
  }

  if (hunkStarts.length === 0) return null;

  const header = lines.slice(0, hunkStarts[0]).join("\n") + "\n";
  const sortedIndices = [...new Set(indices)].sort((a, b) => a - b);
  let patch = header;

  for (const idx of sortedIndices) {
    if (idx < 0 || idx >= hunkStarts.length) {
      throw new Error(
        `Hunk index ${idx} out of range for file ${file} (${hunkStarts.length} hunks)`,
      );
    }
    const start = hunkStarts[idx];
    const end =
      idx + 1 < hunkStarts.length ? hunkStarts[idx + 1] : lines.length;
    patch += lines.slice(start, end).join("\n") + "\n";
  }

  return patch;
}

function applyHunks(
  projectPath: string,
  hunks: HunkRef[],
  options: {
    diffArgs: string[];
    applyArgs: string[];
  },
): void {
  const cwd = resolveProject(projectPath);
  const byFile = new Map<string, number[]>();

  for (const h of hunks) {
    const list = byFile.get(h.file) ?? [];
    list.push(h.hunkIndex);
    byFile.set(h.file, list);
  }

  for (const [file, indices] of byFile) {
    const diffText = git([...options.diffArgs, "--", file], cwd);
    const patch = buildHunkPatch(diffText, file, indices);
    if (!patch) continue;

    execFileSync("git", [...options.applyArgs, "-"], {
      cwd,
      encoding: "utf-8",
      input: patch,
    });
  }
}

// ---- Phase 1: Staging ----

/** Stage entire files. */
export function stageFiles(projectPath: string, files: string[]): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["add", "--", ...files], { cwd, encoding: "utf-8" });
}

/**
 * Stage specific hunks by extracting them from `git diff` and applying via `git apply --cached`.
 *
 * Groups hunks by file, extracts the diff header + requested hunks, then pipes through `git apply`.
 */
export function stageHunks(projectPath: string, hunks: HunkRef[]): void {
  applyHunks(projectPath, hunks, {
    diffArgs: ["diff", "--unified=0"],
    applyArgs: ["apply", "--cached", "--unidiff-zero"],
  });
}

/** Unstage files (remove from index, keep working tree changes). */
export function unstageFiles(projectPath: string, files: string[]): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["reset", "HEAD", "--", ...files], {
    cwd,
    encoding: "utf-8",
  });
}

/** Unstage specific hunks from the index, leaving the working tree intact. */
export function unstageHunks(projectPath: string, hunks: HunkRef[]): void {
  applyHunks(projectPath, hunks, {
    diffArgs: ["diff", "--cached", "--unified=0"],
    applyArgs: ["apply", "-R", "--cached", "--unidiff-zero"],
  });
}

// ---- Phase 2: Commit / Push ----

/** Create a commit with the given message. Throws if nothing is staged. */
export function gitCommit(projectPath: string, message: string): CommitResult {
  const cwd = resolveProject(projectPath);

  // Check if there's anything staged
  const staged = git(["diff", "--cached", "--name-only"], cwd);
  if (!staged) {
    throw new Error("Nothing to commit: no files are staged");
  }

  execFileSync("git", ["commit", "-m", message], { cwd, encoding: "utf-8" });

  const hash = git(["rev-parse", "--short", "HEAD"], cwd);
  return { hash, message };
}

/** Push to remote. */
export function gitPush(projectPath: string, forceLease?: boolean): PushResult {
  const cwd = resolveProject(projectPath);
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);

  const args = ["push", "--set-upstream", "origin", branch];
  if (forceLease) {
    args.splice(1, 0, "--force-with-lease");
  }

  execFileSync("git", args, { cwd, encoding: "utf-8" });
  return { remote: "origin", branch };
}

/** Get git status categorized into staged, unstaged, and untracked files. */
export function gitStatus(projectPath: string): GitStatusResult {
  const cwd = resolveProject(projectPath);
  // Do NOT use git() helper here — its trim() strips leading spaces from porcelain output
  const raw = execFileSync("git", ["status", "--porcelain"], {
    cwd,
    encoding: "utf-8",
  });
  const output = raw.trimEnd();

  const staged: string[] = [];
  const unstaged: string[] = [];
  const untracked: string[] = [];

  if (!output) return { staged, unstaged, untracked };

  for (const line of output.split("\n")) {
    if (!line || line.length < 3) continue;
    const x = line[0]; // index status
    const y = line[1]; // working tree status
    const file = line.slice(3);

    if (x === "?" && y === "?") {
      untracked.push(file);
    } else {
      if (x !== " " && x !== "?") staged.push(file);
      if (y !== " " && y !== "?") unstaged.push(file);
    }
  }

  return { staged, unstaged, untracked };
}

// ---- Phase 3: Branch Operations ----

/** List branches, optionally filtered by query. Also returns branches checked out by worktrees. */
export function listBranches(
  projectPath: string,
  query?: string,
): BranchListResult {
  const cwd = resolveProject(projectPath);
  const current = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);

  const output = git(["branch", "--list", "--format=%(refname:short)"], cwd);
  let branches = output ? output.split("\n").filter(Boolean) : [];

  // Collect branches checked out by worktrees (+ main repo)
  const checkedOutBranches: string[] = [];
  try {
    const wtOutput = execFileSync("git", ["worktree", "list", "--porcelain"], {
      cwd,
      encoding: "utf-8",
    });
    for (const line of wtOutput.split("\n")) {
      if (line.startsWith("branch ")) {
        const branch = line
          .slice("branch ".length)
          .replace(/^refs\/heads\//, "");
        checkedOutBranches.push(branch);
      }
    }
  } catch {
    /* ignore if worktree command fails */
  }

  if (query) {
    const q = query.toLowerCase();
    branches = branches.filter((b) => b.toLowerCase().includes(q));
  }

  const remoteStatusByBranch = Object.fromEntries(
    branches.map((branch) => [branch, getBranchRemoteStatus(cwd, branch)]),
  );

  return { current, branches, checkedOutBranches, remoteStatusByBranch };
}

function getBranchRemoteStatus(
  cwd: string,
  branch: string,
): BranchRemoteStatus {
  const upstream = execFileSync(
    "git",
    ["for-each-ref", "--format=%(upstream:short)", `refs/heads/${branch}`],
    { cwd, encoding: "utf-8" },
  ).trim();

  if (!upstream) {
    return { ahead: 0, behind: 0, hasUpstream: false };
  }

  let ahead = 0;
  let behind = 0;

  try {
    ahead =
      parseInt(git(["rev-list", "--count", `${upstream}..${branch}`], cwd), 10) || 0;
  } catch {
    ahead = 0;
  }

  try {
    behind =
      parseInt(git(["rev-list", "--count", `${branch}..${upstream}`], cwd), 10) || 0;
  } catch {
    behind = 0;
  }

  return { ahead, behind, hasUpstream: true };
}

/** Create a new branch, optionally checking it out. */
export function createBranch(
  projectPath: string,
  name: string,
  checkout?: boolean,
): void {
  const cwd = resolveProject(projectPath);
  if (checkout) {
    execFileSync("git", ["checkout", "-b", name], { cwd, encoding: "utf-8" });
  } else {
    execFileSync("git", ["branch", name], { cwd, encoding: "utf-8" });
  }
}

/** Checkout an existing branch. */
export function checkoutBranch(projectPath: string, branch: string): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["checkout", branch], { cwd, encoding: "utf-8" });
}

/** Revert (discard) unstaged changes for specific files. */
export function revertFiles(projectPath: string, files: string[]): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["checkout", "--", ...files], { cwd, encoding: "utf-8" });
}

/** Revert specific working-tree hunks, leaving the index intact. */
export function revertHunks(projectPath: string, hunks: HunkRef[]): void {
  applyHunks(projectPath, hunks, {
    diffArgs: ["diff", "--unified=0"],
    applyArgs: ["apply", "-R", "--unidiff-zero"],
  });
}

// ---- Remote Operations ----

export interface RemoteStatusResult {
  ahead: number;
  behind: number;
  branch: string;
  hasUpstream: boolean;
}

/** Fetch from remote (non-blocking, returns when done). */
export function gitFetch(projectPath: string): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["fetch", "--quiet"], {
    cwd,
    encoding: "utf-8",
    timeout: 30000,
  });
}

/** Get ahead/behind counts relative to upstream. */
export function gitRemoteStatus(projectPath: string): RemoteStatusResult {
  const cwd = resolveProject(projectPath);
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);

  // Check if upstream is configured
  let hasUpstream = false;
  try {
    git(["rev-parse", "--abbrev-ref", `${branch}@{upstream}`], cwd);
    hasUpstream = true;
  } catch {
    return { ahead: 0, behind: 0, branch, hasUpstream: false };
  }

  let ahead = 0;
  let behind = 0;
  try {
    const aheadStr = git(["rev-list", "--count", `@{upstream}..HEAD`], cwd);
    ahead = parseInt(aheadStr, 10) || 0;
  } catch {
    /* ignore */
  }
  try {
    const behindStr = git(["rev-list", "--count", `HEAD..@{upstream}`], cwd);
    behind = parseInt(behindStr, 10) || 0;
  } catch {
    /* ignore */
  }

  return { ahead, behind, branch, hasUpstream };
}

/** Pull from remote (fetch + merge). */
export function gitPull(projectPath: string): {
  success: boolean;
  message: string;
} {
  const cwd = resolveProject(projectPath);
  try {
    const output = execFileSync("git", ["pull"], {
      cwd,
      encoding: "utf-8",
    }).trim();
    return { success: true, message: output };
  } catch (err) {
    return { success: false, message: String(err) };
  }
}
