import { execFileSync } from "node:child_process";
import { realpathSync, type Dir, type Dirent } from "node:fs";
import { opendir } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";

// ---- Types ----

export interface HunkRef {
  file: string;
  hunkIndex: number;
}

export interface CommitResult {
  hash: string;
  message: string;
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

export interface GitStatusResult {
  hasUncommittedChanges: boolean;
  stagedCount: number;
  unstagedCount: number;
  untrackedCount: number;
  remoteStatusIncluded: boolean;
  hasRemoteChanges: boolean;
  commitsAhead: number;
  commitsBehind: number;
  hasUpstream: boolean;
  branch?: string;
  remoteError?: string;
}

export interface FileSystemFileListOptions {
  maxDepth?: number;
  maxFiles?: number;
  excludedDirs?: ReadonlySet<string> | readonly string[];
}

export const DEFAULT_FILESYSTEM_FILE_LIST_MAX_DEPTH = 8;
export const DEFAULT_FILESYSTEM_FILE_LIST_MAX_FILES = 5000;
export const DEFAULT_FILESYSTEM_FILE_LIST_EXCLUDED_DIRS = new Set([
  ".git",
  ".hg",
  ".svn",
  ".dart_tool",
  ".next",
  ".nuxt",
  ".venv",
  "__pycache__",
  "build",
  "dist",
  "node_modules",
  "vendor",
]);

// ---- Helpers ----

function resolveProject(projectPath: string): string {
  return realpathSync(resolve(projectPath));
}

function withGitPathConfig(args: string[]): string[] {
  return ["-c", "core.quotePath=false", ...args];
}

function git(args: string[], cwd: string): string {
  return execFileSync("git", withGitPathConfig(args), {
    cwd,
    encoding: "utf-8",
  }).trim();
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
    includeUntracked?: boolean;
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
    let diffText = "";
    let addedIntentToAdd = false;

    if (options.includeUntracked) {
      const tracked = git(["ls-files", "--", file], cwd);
      if (!tracked) {
        execFileSync("git", ["add", "--intent-to-add", "--", file], {
          cwd,
          encoding: "utf-8",
        });
        addedIntentToAdd = true;
      }
    }

    try {
      diffText = git([...options.diffArgs, "--", file], cwd);
    } finally {
      if (addedIntentToAdd) {
        execFileSync("git", ["reset", "--", file], {
          cwd,
          encoding: "utf-8",
        });
      }
    }

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
    includeUntracked: true,
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

/** Return staged diff content for commit-message generation. */
export function getStagedDiff(projectPath: string): string {
  const cwd = resolveProject(projectPath);
  return execFileSync(
    "git",
    withGitPathConfig(["diff", "--cached", "--no-color"]),
    {
      cwd,
      encoding: "utf-8",
    },
  );
}

/** Return tracked and untracked project files for autocomplete/explorer views. */
export function listGitFiles(projectPath: string): string[] {
  const cwd = resolveProject(projectPath);
  const output = execFileSync(
    "git",
    withGitPathConfig([
      "ls-files",
      "-z",
      "--cached",
      "--others",
      "--exclude-standard",
    ]),
    {
      cwd,
      encoding: "utf-8",
      maxBuffer: 10 * 1024 * 1024,
    },
  );
  return output.split("\0").filter(Boolean);
}

/** Return project files, using Git when available and filesystem fallback otherwise. */
export async function listProjectFiles(
  projectPath: string,
  options: FileSystemFileListOptions = {},
): Promise<string[]> {
  try {
    return listGitFiles(projectPath);
  } catch (err) {
    if (!isGitFileListingUnavailable(err)) {
      throw err;
    }
    return listFileSystemFiles(projectPath, options);
  }
}

/** Return regular files under a non-Git project directory for explorer views. */
export async function listFileSystemFiles(
  projectPath: string,
  options: FileSystemFileListOptions = {},
): Promise<string[]> {
  const root = resolveProject(projectPath);
  const maxDepth =
    options.maxDepth ?? DEFAULT_FILESYSTEM_FILE_LIST_MAX_DEPTH;
  const maxFiles =
    options.maxFiles ?? DEFAULT_FILESYSTEM_FILE_LIST_MAX_FILES;
  const excludedDirs = toExcludedDirSet(
    options.excludedDirs ?? DEFAULT_FILESYSTEM_FILE_LIST_EXCLUDED_DIRS,
  );
  const files: string[] = [];

  async function visit(
    absDir: string,
    relDir: string,
    depth: number,
  ): Promise<void> {
    if (files.length >= maxFiles || depth >= maxDepth) return;

    let dir: Dir;
    try {
      dir = await opendir(absDir);
    } catch (err) {
      if (relDir === "") throw err;
      return;
    }

    const entries: Dirent[] = [];
    for await (const entry of dir) {
      entries.push(entry);
    }

    entries.sort((a, b) => a.name.localeCompare(b.name));

    for (const entry of entries) {
      if (files.length >= maxFiles) return;
      if (entry.name === "." || entry.name === "..") continue;

      const absPath = join(absDir, entry.name);
      const relPath = relDir ? `${relDir}/${entry.name}` : entry.name;

      if (entry.isSymbolicLink()) {
        continue;
      }

      if (entry.isDirectory()) {
        if (excludedDirs.has(entry.name)) continue;
        await visit(absPath, relPath, depth + 1);
        continue;
      }

      if (entry.isFile()) {
        files.push(toPosixRelativePath(relative(root, absPath)));
      }
    }
  }

  await visit(root, "", 0);
  return files.sort((a, b) => a.localeCompare(b));
}

function isGitFileListingUnavailable(err: unknown): boolean {
  const error = err as NodeJS.ErrnoException;
  if (error.code === "ENOENT") return true;
  const message = err instanceof Error ? err.message : String(err);
  return /not a git repository/i.test(message);
}

function toExcludedDirSet(
  dirs: ReadonlySet<string> | readonly string[],
): ReadonlySet<string> {
  return dirs instanceof Set ? dirs : new Set(dirs);
}

function toPosixRelativePath(path: string): string {
  return sep === "/" ? path : path.split(sep).join("/");
}

/** Push to remote. */
export function gitPush(projectPath: string): void {
  const cwd = resolveProject(projectPath);
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);
  execFileSync("git", ["push", "--set-upstream", "origin", branch], {
    cwd,
    encoding: "utf-8",
  });
}

// ---- Phase 3: Branch Operations ----

/** List branches and branches checked out by worktrees. */
export function listBranches(projectPath: string): BranchListResult {
  const cwd = resolveProject(projectPath);
  const current = git(["rev-parse", "--abbrev-ref", "HEAD"], cwd);

  const output = git([
    "branch",
    "--list",
    "--format=%(refname:short)%09%(upstream:short)%09%(upstream:track)",
  ], cwd);
  const branchRows = output
    ? output.split("\n").filter(Boolean).map((line) => {
        const [branch, upstream = "", track = ""] = line.split("\t");
        return {
          branch,
          remoteStatus: parseBranchRemoteStatus(upstream, track),
        };
      })
    : [];
  const branches = branchRows.map((row) => row.branch);

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

  const remoteStatusByBranch = Object.fromEntries(
    branchRows.map((row) => [row.branch, row.remoteStatus]),
  );

  return { current, branches, checkedOutBranches, remoteStatusByBranch };
}

function parseBranchRemoteStatus(
  upstream: string,
  track: string,
): BranchRemoteStatus {
  if (!upstream) {
    return { ahead: 0, behind: 0, hasUpstream: false };
  }

  const ahead = parseTrackCount(track, /ahead (\d+)/);
  const behind = parseTrackCount(track, /behind (\d+)/);

  return { ahead, behind, hasUpstream: true };
}

function parseTrackCount(track: string, pattern: RegExp): number {
  const match = track.match(pattern);
  return match ? parseInt(match[1], 10) || 0 : 0;
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
  if (files.length === 0) return;

  const trackedOutput = git(["ls-files", "--", ...files], cwd);
  const trackedFiles = trackedOutput ? trackedOutput.split("\n").filter(Boolean) : [];
  const trackedSet = new Set(trackedFiles);
  const untrackedFiles = files.filter((file) => !trackedSet.has(file));

  if (trackedFiles.length > 0) {
    execFileSync("git", ["checkout", "--", ...trackedFiles], {
      cwd,
      encoding: "utf-8",
    });
  }

  if (untrackedFiles.length > 0) {
    execFileSync("git", ["clean", "-fd", "--", ...untrackedFiles], {
      cwd,
      encoding: "utf-8",
    });
  }
}

/** Revert specific working-tree hunks, leaving the index intact. */
export function revertHunks(projectPath: string, hunks: HunkRef[]): void {
  applyHunks(projectPath, hunks, {
    diffArgs: ["diff", "--unified=0"],
    applyArgs: ["apply", "-R", "--unidiff-zero"],
    includeUntracked: true,
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

/** Get lightweight working tree/index status. Remote state is optional. */
export function gitStatus(
  projectPath: string,
  options: { includeRemote?: boolean } = {},
): GitStatusResult {
  const cwd = resolveProject(projectPath);
  const output = execFileSync(
    "git",
    withGitPathConfig([
      "status",
      "--porcelain=v1",
      "--untracked-files=normal",
    ]),
    {
      cwd,
      encoding: "utf-8",
    },
  );
  if (!output.trim()) {
    const cleanResult = {
      hasUncommittedChanges: false,
      stagedCount: 0,
      unstagedCount: 0,
      untrackedCount: 0,
    };
    return withOptionalRemoteStatus(projectPath, cleanResult, options);
  }

  let stagedCount = 0;
  let unstagedCount = 0;
  let untrackedCount = 0;

  for (const line of output.split("\n")) {
    if (!line) continue;
    const x = line[0];
    const y = line[1];

    if (x === "?" && y === "?") {
      untrackedCount++;
      continue;
    }
    if (x !== " ") stagedCount++;
    if (y !== " ") unstagedCount++;
  }

  return withOptionalRemoteStatus(
    projectPath,
    {
      hasUncommittedChanges: stagedCount + unstagedCount + untrackedCount > 0,
      stagedCount,
      unstagedCount,
      untrackedCount,
    },
    options,
  );
}

function withOptionalRemoteStatus(
  projectPath: string,
  local: Pick<
    GitStatusResult,
    | "hasUncommittedChanges"
    | "stagedCount"
    | "unstagedCount"
    | "untrackedCount"
  >,
  options: { includeRemote?: boolean },
): GitStatusResult {
  const base: GitStatusResult = {
    ...local,
    remoteStatusIncluded: false,
    hasRemoteChanges: false,
    commitsAhead: 0,
    commitsBehind: 0,
    hasUpstream: false,
  };

  if (!options.includeRemote) return base;

  try {
    gitFetch(projectPath);
    const remote = gitRemoteStatus(projectPath);
    return {
      ...base,
      remoteStatusIncluded: true,
      hasRemoteChanges: remote.ahead > 0 || remote.behind > 0,
      commitsAhead: remote.ahead,
      commitsBehind: remote.behind,
      hasUpstream: remote.hasUpstream,
      branch: remote.branch,
    };
  } catch (err) {
    return {
      ...base,
      remoteStatusIncluded: true,
      remoteError: String(err),
    };
  }
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
