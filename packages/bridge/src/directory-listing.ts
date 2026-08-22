import { readdir, realpath, stat, lstat } from "node:fs/promises";

import {
  isPathWithinAllowedDirectory,
  resolvePlatformPath,
  resolvePlatformPathFrom,
} from "./path-utils.js";

export interface DirectoryListingEntry {
  name: string;
  path: string;
}

export class DirectoryListingError extends Error {
  constructor(
    readonly code:
      | "directory_not_allowed"
      | "directory_not_found"
      | "directory_not_readable"
      | "not_a_directory"
      | "directory_read_failed",
    message: string,
  ) {
    super(message);
    this.name = "DirectoryListingError";
  }
}

function classifyFilesystemError(error: unknown): DirectoryListingError {
  const code = (error as NodeJS.ErrnoException | undefined)?.code;
  if (code === "ENOENT" || code === "ENOTDIR") {
    return new DirectoryListingError(
      "directory_not_found",
      "Directory not found",
    );
  }
  if (code === "EACCES" || code === "EPERM") {
    return new DirectoryListingError(
      "directory_not_readable",
      "Directory is not readable",
    );
  }
  return new DirectoryListingError(
    "directory_read_failed",
    "Unable to read directory",
  );
}

async function canonicalAllowedRoots(
  allowedDirs: string[],
  platform: NodeJS.Platform,
): Promise<string[]> {
  const roots: string[] = [];
  for (const allowedDir of allowedDirs) {
    try {
      roots.push(await realpath(resolvePlatformPath(allowedDir, platform)));
    } catch {
      // A configured root that no longer exists cannot authorize a request.
    }
  }
  return roots;
}

function isWithinAnyRoot(
  targetPath: string,
  roots: string[],
  platform: NodeJS.Platform,
): boolean {
  return roots.some((root) =>
    isPathWithinAllowedDirectory(targetPath, root, platform),
  );
}

/**
 * List real child directories under a Bridge-allowed directory.
 *
 * The lexical check prevents traversal before filesystem access. The realpath
 * checks prevent a symlinked request or a raced child entry from escaping the
 * configured roots. Symlink child entries are intentionally omitted.
 */
export async function listAllowedDirectories(
  requestedPath: string,
  allowedDirs: string[],
  platform: NodeJS.Platform = process.platform,
  includeHidden = false,
): Promise<{ path: string; directories: DirectoryListingEntry[] }> {
  const resolvedRequestedPath = resolvePlatformPath(requestedPath, platform);

  if (
    allowedDirs.length > 0 &&
    !allowedDirs.some((allowedDir) =>
      isPathWithinAllowedDirectory(
        resolvedRequestedPath,
        allowedDir,
        platform,
      ),
    )
  ) {
    throw new DirectoryListingError(
      "directory_not_allowed",
      "Directory path is outside the allowed roots",
    );
  }

  let canonicalPath: string;
  try {
    canonicalPath = await realpath(resolvedRequestedPath);
    const info = await stat(canonicalPath);
    if (!info.isDirectory()) {
      throw new DirectoryListingError(
        "not_a_directory",
        "Selected path is not a directory",
      );
    }
  } catch (error) {
    if (error instanceof DirectoryListingError) throw error;
    throw classifyFilesystemError(error);
  }

  const roots = await canonicalAllowedRoots(allowedDirs, platform);
  if (allowedDirs.length > 0 && !isWithinAnyRoot(canonicalPath, roots, platform)) {
    throw new DirectoryListingError(
      "directory_not_allowed",
      "Directory path resolves outside the allowed roots",
    );
  }

  let entries: import("node:fs").Dirent[];
  try {
    entries = await readdir(canonicalPath, { withFileTypes: true });
  } catch (error) {
    throw classifyFilesystemError(error);
  }

  const directories: DirectoryListingEntry[] = [];
  for (const entry of entries) {
    if (
      !entry.isDirectory() ||
      (!includeHidden && entry.name.startsWith("."))
    )
      continue;

    const childPath = resolvePlatformPathFrom(
      canonicalPath,
      entry.name,
      platform,
    );
    try {
      const childStat = await lstat(childPath);
      if (!childStat.isDirectory() || childStat.isSymbolicLink()) continue;
      const canonicalChildPath = await realpath(childPath);
      const canonicalChildStat = await stat(canonicalChildPath);
      if (!canonicalChildStat.isDirectory()) continue;
      if (
        allowedDirs.length > 0 &&
        !isWithinAnyRoot(canonicalChildPath, roots, platform)
      ) {
        continue;
      }
      // Keep the path in the same lexical namespace as the request. The
      // canonical path is only used for authorization so configured roots
      // that are symlinks (for example /tmp -> /private/tmp on macOS) remain
      // navigable on subsequent requests.
      directories.push({
        name: entry.name,
        path: resolvePlatformPathFrom(
          resolvedRequestedPath,
          entry.name,
          platform,
        ),
      });
    } catch {
      // Entries may disappear or become unreadable while the directory is
      // being listed. Omit that entry rather than failing the whole listing.
    }
  }

  directories.sort((a, b) =>
    a.name.localeCompare(b.name, "en", {
      numeric: true,
      sensitivity: "base",
    }),
  );

  return { path: resolvedRequestedPath, directories };
}
