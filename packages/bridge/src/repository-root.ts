import { execFile } from "node:child_process";
import { realpath, stat } from "node:fs/promises";
import { basename, dirname } from "node:path";

/** Runs git in `cwd` and resolves with stdout; rejects on failure. */
export type RunGit = (cwd: string, args: string[]) => Promise<string>;

const defaultRunGit: RunGit = (cwd, args) =>
  new Promise((resolve, reject) => {
    execFile(
      "git",
      args,
      { cwd, encoding: "utf-8", timeout: 5000 },
      (error, stdout) => (error ? reject(error) : resolve(stdout)),
    );
  });

/**
 * Negative results (missing directory, not a git top-level) are retried after
 * this long, since a directory can be created or initialized later. Positive
 * results never change for a given path, so they are cached for the process.
 */
const NEGATIVE_CACHE_TTL_MS = 5 * 60 * 1000;

interface CachedValue {
  value: string | null;
  expiresAt: number;
}

export interface RepositoryRootResolver {
  /**
   * Resolve a session cwd that is the top level of a git checkout to its main
   * repository path. Linked worktrees resolve to the main worktree; the main
   * worktree resolves to itself. Returns null for missing directories,
   * non-git directories and subdirectories inside a checkout.
   */
  resolvePath(cwd: string): Promise<string | null>;
  /**
   * Map a remote repository URL to the one candidate checkout whose `origin`
   * points at the same repository. Returns null when none or several match.
   */
  resolveRepositoryUrl(
    url: string,
    candidatePaths: Iterable<string>,
  ): Promise<string | null>;
}

/**
 * Normalize a git remote URL so SSH, scp-like and HTTPS forms of the same
 * repository compare equal: `host/owner/repo`, lowercased, without `.git`.
 */
export function normalizeRepositoryUrl(url: string): string | null {
  let value = url.trim();
  if (!value) return null;
  const scpLike = value.match(/^[^@/:]+@([^:/]+):(.+)$/);
  if (scpLike) {
    value = `${scpLike[1]}/${scpLike[2]}`;
  } else {
    value = value.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").replace(/^[^@/]+@/, "");
  }
  value = value.replace(/\/+$/, "").replace(/\.git$/i, "").replace(/\/+$/, "");
  return value ? value.toLowerCase() : null;
}

export function createRepositoryRootResolver(
  options: { runGit?: RunGit; now?: () => number } = {},
): RepositoryRootResolver {
  const runGit = options.runGit ?? defaultRunGit;
  const now = options.now ?? Date.now;
  const rootCache = new Map<string, CachedValue>();
  const originCache = new Map<string, CachedValue>();

  const cached = async (
    cache: Map<string, CachedValue>,
    key: string,
    load: () => Promise<string | null>,
  ): Promise<string | null> => {
    const hit = cache.get(key);
    if (hit && hit.expiresAt > now()) return hit.value;
    const value = await load();
    cache.set(key, {
      value,
      expiresAt: value === null ? now() + NEGATIVE_CACHE_TTL_MS : Infinity,
    });
    return value;
  };

  const isDirectory = async (path: string): Promise<boolean> => {
    try {
      return (await stat(path)).isDirectory();
    } catch {
      return false;
    }
  };

  const resolvePath = (cwd: string): Promise<string | null> =>
    cached(rootCache, cwd, async () => {
      if (!cwd || !(await isDirectory(cwd))) return null;
      try {
        const [topLevel, commonDir] = (
          await runGit(cwd, [
            "rev-parse",
            "--path-format=absolute",
            "--show-toplevel",
            "--git-common-dir",
          ])
        )
          .split("\n")
          .map((line) => line.trim());
        if (!topLevel || !commonDir) return null;
        if (topLevel !== (await realpath(cwd))) return null;
        if (basename(commonDir) !== ".git") return null;
        return dirname(commonDir);
      } catch {
        return null;
      }
    });

  const originOf = (path: string): Promise<string | null> =>
    cached(originCache, path, async () => {
      if (!(await isDirectory(path))) return null;
      try {
        return normalizeRepositoryUrl(
          await runGit(path, ["remote", "get-url", "origin"]),
        );
      } catch {
        return null;
      }
    });

  const resolveRepositoryUrl = async (
    url: string,
    candidatePaths: Iterable<string>,
  ): Promise<string | null> => {
    const wanted = normalizeRepositoryUrl(url);
    if (!wanted) return null;
    const candidates = [...new Set(candidatePaths)];
    const origins = await Promise.all(candidates.map(originOf));
    const matches = candidates.filter((_, i) => origins[i] === wanted);
    return matches.length === 1 ? matches[0] : null;
  };

  return { resolvePath, resolveRepositoryUrl };
}
