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

// Repositories, worktrees and origins can change while the Bridge is running.
const CACHE_TTL_MS = 5 * 60 * 1000;

interface CachedValue {
  value: Promise<string | null>;
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
 * repository compare equal: `host/owner/repo` without `.git`. The host is
 * lowercased; the path is folded only for github.com, whose paths are
 * case-insensitive. Other hosts may treat path casing as significant.
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
  value = value.replace(/\/+$/, "").replace(/\.git$/, "").replace(/\/+$/, "");
  if (!value) return null;
  const separator = value.indexOf("/");
  if (separator < 0) return value.toLowerCase();
  const host = value.slice(0, separator).toLowerCase();
  const path = value.slice(separator);
  return `${host}${host === "github.com" ? path.toLowerCase() : path}`;
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
    // Cache the in-flight promise as well, since many sessions share a cwd.
    const pending: CachedValue = { value: load(), expiresAt: Infinity };
    cache.set(key, pending);
    try {
      const value = await pending.value;
      pending.expiresAt = now() + CACHE_TTL_MS;
      return value;
    } catch (error) {
      if (cache.get(key) === pending) cache.delete(key);
      throw error;
    }
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
    // The caller already limits concurrent resolutions. Avoid spawning one
    // process per repository here; shared origins reuse the in-flight cache.
    const origins: (string | null)[] = [];
    for (const candidate of candidates) origins.push(await originOf(candidate));
    const matches = candidates.filter((_, i) => origins[i] === wanted);
    return matches.length === 1 ? matches[0] : null;
  };

  return { resolvePath, resolveRepositoryUrl };
}
