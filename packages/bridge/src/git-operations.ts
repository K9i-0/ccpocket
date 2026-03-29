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

export interface PrResult {
  prNumber: number;
  url: string;
}

export interface GitStatusResult {
  staged: string[];
  unstaged: string[];
  untracked: string[];
}

export interface BranchListResult {
  current: string;
  branches: string[];
}

// ---- Helpers ----

function resolveProject(projectPath: string): string {
  return realpathSync(resolve(projectPath));
}

function git(args: string[], cwd: string): string {
  return execFileSync("git", args, { cwd, encoding: "utf-8" }).trim();
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
  const cwd = resolveProject(projectPath);

  // Group hunks by file
  const byFile = new Map<string, number[]>();
  for (const h of hunks) {
    const list = byFile.get(h.file) ?? [];
    list.push(h.hunkIndex);
    byFile.set(h.file, list);
  }

  for (const [file, indices] of byFile) {
    // Get the full diff for this file
    const fileDiff = git(["diff", "--", file], cwd);
    if (!fileDiff) continue;

    // Split into header + hunks
    const lines = fileDiff.split("\n");
    const hunkStarts: number[] = [];
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].startsWith("@@")) {
        hunkStarts.push(i);
      }
    }

    if (hunkStarts.length === 0) continue;

    // Build the header (everything before the first @@)
    const header = lines.slice(0, hunkStarts[0]).join("\n") + "\n";

    // Extract requested hunks
    const sortedIndices = [...new Set(indices)].sort((a, b) => a - b);
    let patch = header;
    for (const idx of sortedIndices) {
      if (idx < 0 || idx >= hunkStarts.length) {
        throw new Error(`Hunk index ${idx} out of range for file ${file} (${hunkStarts.length} hunks)`);
      }
      const start = hunkStarts[idx];
      const end = idx + 1 < hunkStarts.length ? hunkStarts[idx + 1] : lines.length;
      patch += lines.slice(start, end).join("\n") + "\n";
    }

    // Apply the patch to the index
    execFileSync("git", ["apply", "--cached", "--unidiff-zero", "-"], {
      cwd,
      encoding: "utf-8",
      input: patch,
    });
  }
}

/** Unstage files (remove from index, keep working tree changes). */
export function unstageFiles(projectPath: string, files: string[]): void {
  const cwd = resolveProject(projectPath);
  execFileSync("git", ["reset", "HEAD", "--", ...files], { cwd, encoding: "utf-8" });
}

// ---- Phase 2: Commit / Push / PR ----

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

/** Create a PR via `gh` CLI. */
export function ghPrCreate(
  projectPath: string,
  opts: { title?: string; body?: string; draft?: boolean },
): PrResult {
  const cwd = resolveProject(projectPath);

  const args = ["pr", "create"];
  if (opts.title) args.push("--title", opts.title);
  if (opts.body) args.push("--body", opts.body);
  if (opts.draft) args.push("--draft");

  const output = execFileSync("gh", args, { cwd, encoding: "utf-8" }).trim();

  // gh pr create outputs the PR URL as the last line
  const url = output.split("\n").pop() ?? output;

  // Extract PR number from URL (e.g., https://github.com/user/repo/pull/42)
  const match = url.match(/\/pull\/(\d+)/);
  const prNumber = match ? parseInt(match[1], 10) : 0;

  return { prNumber, url };
}

/** Get git status categorized into staged, unstaged, and untracked files. */
export function gitStatus(projectPath: string): GitStatusResult {
  const cwd = resolveProject(projectPath);
  // Do NOT use git() helper here — its trim() strips leading spaces from porcelain output
  const raw = execFileSync("git", ["status", "--porcelain"], { cwd, encoding: "utf-8" });
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

/** List branches, optionally filtered by query. */
export function listBranches(projectPath: string, query?: string): BranchListResult {
  const cwd = resolveProject(projectPath);
  const current = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);

  const output = git(["branch", "--list", "--format=%(refname:short)"], cwd);
  let branches = output ? output.split("\n").filter(Boolean) : [];

  if (query) {
    const q = query.toLowerCase();
    branches = branches.filter((b) => b.toLowerCase().includes(q));
  }

  return { current, branches };
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
  execFileSync("git", ["fetch", "--quiet"], { cwd, encoding: "utf-8", timeout: 30000 });
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
  } catch { /* ignore */ }
  try {
    const behindStr = git(["rev-list", "--count", `HEAD..@{upstream}`], cwd);
    behind = parseInt(behindStr, 10) || 0;
  } catch { /* ignore */ }

  return { ahead, behind, branch, hasUpstream };
}

/** Pull from remote (fetch + merge). */
export function gitPull(projectPath: string): { success: boolean; message: string } {
  const cwd = resolveProject(projectPath);
  try {
    const output = execFileSync("git", ["pull"], { cwd, encoding: "utf-8" }).trim();
    return { success: true, message: output };
  } catch (err) {
    return { success: false, message: String(err) };
  }
}
