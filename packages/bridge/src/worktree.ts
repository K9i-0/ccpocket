import { execFileSync, execSync } from "node:child_process";
import { existsSync, readFileSync, mkdirSync, cpSync, readdirSync, statSync, realpathSync } from "node:fs";
import { join, dirname, basename, relative, resolve } from "node:path";

// ---- Types ----

export interface WorktreeInfo {
  worktreePath: string;
  branch: string;
  projectPath: string;
  head?: string;
}

export interface GtrConfig {
  copy: {
    include: string[];
    exclude: string[];
    includeDirs: string[];
    excludeDirs: string[];
  };
  hook: {
    postCreate: string[];
    preRemove: string[];
  };
}

// ---- .gtrconfig Parser ----

/** Parse a .gtrconfig file (gitconfig format) from the given directory. */
export function parseGtrConfig(projectPath: string): GtrConfig {
  const config: GtrConfig = {
    copy: { include: [], exclude: [], includeDirs: [], excludeDirs: [] },
    hook: { postCreate: [], preRemove: [] },
  };

  const configPath = join(projectPath, ".gtrconfig");
  if (!existsSync(configPath)) return config;

  const content = readFileSync(configPath, "utf-8");
  let currentSection = "";

  for (const rawLine of content.split("\n")) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#") || line.startsWith(";")) continue;

    // Section header: [copy], [hook], etc.
    const sectionMatch = line.match(/^\[(\w+)\]$/);
    if (sectionMatch) {
      currentSection = sectionMatch[1].toLowerCase();
      continue;
    }

    // Key = value
    const kvMatch = line.match(/^(\w+)\s*=\s*(.+)$/);
    if (!kvMatch) continue;

    const key = kvMatch[1].toLowerCase();
    const value = kvMatch[2].trim();

    if (currentSection === "copy") {
      switch (key) {
        case "include": config.copy.include.push(value); break;
        case "exclude": config.copy.exclude.push(value); break;
        case "includedirs": config.copy.includeDirs.push(value); break;
        case "excludedirs": config.copy.excludeDirs.push(value); break;
      }
    } else if (currentSection === "hook" || currentSection === "hooks") {
      switch (key) {
        case "postcreate": config.hook.postCreate.push(value); break;
        case "preremove": config.hook.preRemove.push(value); break;
      }
    }
  }

  return config;
}

// ---- Glob Matching ----

const REGEX_SPECIAL = /[\\.+^$()|[\]]/g;

/**
 * Simple glob pattern matcher supporting:
 * - `*` matches any characters except `/`
 * - `**` or `*` followed by `*` matches any path segments (including none)
 * - `?` matches a single character except `/`
 */
export function matchGlob(pattern: string, filePath: string): boolean {
  let regex = "";
  let i = 0;
  while (i < pattern.length) {
    if (pattern[i] === "*" && pattern[i + 1] === "*") {
      if (pattern[i + 2] === "/") {
        // zero or more directory segments
        regex += "(.*/)?";
        i += 3;
      } else {
        // match everything
        regex += ".*";
        i += 2;
      }
    } else if (pattern[i] === "*") {
      regex += "[^/]*";
      i++;
    } else if (pattern[i] === "?") {
      regex += "[^/]";
      i++;
    } else {
      regex += pattern[i].replace(REGEX_SPECIAL, "\\$&");
      i++;
    }
  }
  return new RegExp("^" + regex + "$").test(filePath);
}

// ---- Worktree Path Computation ----

/** Compute the worktrees root directory for a project. */
export function worktreesRoot(projectPath: string): string {
  return join(dirname(projectPath), basename(projectPath) + "-worktrees");
}

/** Compute the full worktree path for a branch. Slashes in branch names are converted to dashes for the directory name. */
export function worktreePath(projectPath: string, branch: string): string {
  const dirName = branch.replace(/\//g, "-");
  return join(worktreesRoot(projectPath), dirName);
}

/** Generate a default branch name for a session. */
export function defaultBranch(sessionId: string): string {
  return "ccpocket/" + sessionId;
}

// ---- File Copy ----

/** Walk a directory recursively and return relative file paths. */
function walkFiles(dir: string, baseDir?: string): string[] {
  const base = baseDir ?? dir;
  const results: string[] = [];
  try {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        results.push(...walkFiles(fullPath, base));
      } else {
        results.push(relative(base, fullPath));
      }
    }
  } catch { /* skip unreadable directories */ }
  return results;
}

/** Copy files from source to destination based on .gtrconfig patterns. */
export function copyConfiguredFiles(
  projectPath: string,
  destPath: string,
  config: GtrConfig,
): void {
  const { include, exclude, includeDirs, excludeDirs } = config.copy;

  // Copy individual files matching include/exclude patterns
  if (include.length > 0) {
    const allFiles = walkFiles(projectPath);
    for (const file of allFiles) {
      const included = include.some((pat) => matchGlob(pat, file));
      const excluded = exclude.some((pat) => matchGlob(pat, file));
      if (included && !excluded) {
        const srcFile = join(projectPath, file);
        const destFile = join(destPath, file);
        mkdirSync(dirname(destFile), { recursive: true });
        cpSync(srcFile, destFile, { force: true });
      }
    }
  }

  // Copy entire directories matching includeDirs/excludeDirs
  if (includeDirs.length > 0) {
    try {
      const entries = readdirSync(projectPath, { withFileTypes: true });
      for (const entry of entries) {
        if (!entry.isDirectory()) continue;
        const included = includeDirs.some((pat) => matchGlob(pat, entry.name));
        const excluded = excludeDirs.some((pat) => matchGlob(pat, entry.name));
        if (included && !excluded) {
          const srcDir = join(projectPath, entry.name);
          const destDir = join(destPath, entry.name);
          cpSync(srcDir, destDir, { recursive: true, force: true });
        }
      }
    } catch { /* skip if project directory can't be listed */ }
  }
}

// ---- Core Worktree Operations ----

/** Resolve a project path, following symlinks to get the real path. */
function resolveProject(projectPath: string): string {
  return realpathSync(resolve(projectPath));
}

/** Create a git worktree for a session. */
export function createWorktree(
  projectPath: string,
  sessionId: string,
  branch?: string,
): WorktreeInfo {
  const resolvedProject = resolveProject(projectPath);
  const branchName = branch || defaultBranch(sessionId);
  const wtPath = worktreePath(resolvedProject, branchName);

  // Ensure the worktrees root directory exists
  mkdirSync(worktreesRoot(resolvedProject), { recursive: true });

  // Check if the branch already exists
  let branchExists = false;
  try {
    execFileSync("git", ["rev-parse", "--verify", branchName], {
      cwd: resolvedProject,
      stdio: "ignore",
    });
    branchExists = true;
  } catch { /* branch does not exist */ }

  // Create worktree
  if (branchExists) {
    execFileSync("git", ["worktree", "add", wtPath, branchName], {
      cwd: resolvedProject,
      encoding: "utf-8",
    });
  } else {
    execFileSync("git", ["worktree", "add", "-b", branchName, wtPath], {
      cwd: resolvedProject,
      encoding: "utf-8",
    });
  }

  // Parse .gtrconfig and apply copy/hooks
  const config = parseGtrConfig(resolvedProject);
  copyConfiguredFiles(resolvedProject, wtPath, config);

  // Run postCreate hooks
  for (const cmd of config.hook.postCreate) {
    try {
      execSync(cmd, { cwd: wtPath, encoding: "utf-8", stdio: "pipe" });
    } catch (err) {
      console.error("[worktree] postCreate hook failed: " + cmd, err);
    }
  }

  // Get HEAD commit
  let head: string | undefined;
  try {
    head = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: wtPath,
      encoding: "utf-8",
    }).trim();
  } catch { /* ignore */ }

  return { worktreePath: wtPath, branch: branchName, projectPath: resolvedProject, head };
}

/** Remove a git worktree. */
export function removeWorktree(projectPath: string, wtPath: string): void {
  const resolvedProject = resolveProject(projectPath);

  // Run preRemove hooks
  const config = parseGtrConfig(resolvedProject);
  for (const cmd of config.hook.preRemove) {
    try {
      execSync(cmd, { cwd: wtPath, encoding: "utf-8", stdio: "pipe" });
    } catch (err) {
      console.error("[worktree] preRemove hook failed: " + cmd, err);
    }
  }

  execFileSync("git", ["worktree", "remove", wtPath, "--force"], {
    cwd: resolvedProject,
    encoding: "utf-8",
  });
}

/** List worktrees for a project (only those under <project>-worktrees/). */
export function listWorktrees(projectPath: string): WorktreeInfo[] {
  const resolvedProject = resolveProject(projectPath);
  const wtRoot = worktreesRoot(resolvedProject);

  let output: string;
  try {
    output = execFileSync("git", ["worktree", "list", "--porcelain"], {
      cwd: resolvedProject,
      encoding: "utf-8",
    });
  } catch {
    return [];
  }

  const worktrees: WorktreeInfo[] = [];
  let currentPath = "";
  let currentHead = "";
  let currentBranch = "";

  for (const line of output.split("\n")) {
    if (line.startsWith("worktree ")) {
      currentPath = line.slice("worktree ".length);
    } else if (line.startsWith("HEAD ")) {
      currentHead = line.slice("HEAD ".length);
    } else if (line.startsWith("branch ")) {
      // branch refs/heads/feature/x -> feature/x
      currentBranch = line.slice("branch ".length).replace(/^refs\/heads\//, "");
    } else if (line === "") {
      // End of entry
      if (currentPath && currentPath.startsWith(wtRoot)) {
        worktrees.push({
          worktreePath: currentPath,
          branch: currentBranch,
          projectPath: resolvedProject,
          head: currentHead || undefined,
        });
      }
      currentPath = "";
      currentHead = "";
      currentBranch = "";
    }
  }

  return worktrees;
}

/** Get the current branch of the main repo. */
export function getMainBranch(projectPath: string): string {
  const resolvedProject = resolveProject(projectPath);
  try {
    return execFileSync("git", ["branch", "--show-current"], {
      cwd: resolvedProject,
      encoding: "utf-8",
    }).trim();
  } catch {
    return "";
  }
}

/** Check if a worktree path exists on disk. */
export function worktreeExists(wtPath: string): boolean {
  return existsSync(wtPath);
}
