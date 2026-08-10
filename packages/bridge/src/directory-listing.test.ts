import {
  mkdtempSync,
  mkdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, resolve } from "node:path";

import { afterEach, describe, expect, it } from "vitest";

import {
  DirectoryListingError,
  listAllowedDirectories,
} from "./directory-listing.js";

const temporaryDirectories: string[] = [];

function makeTempDirectory(): string {
  const directory = mkdtempSync(resolve(tmpdir(), "ccpocket-directory-listing-"));
  temporaryDirectories.push(directory);
  return directory;
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe("listAllowedDirectories", () => {
  it("returns visible real directories in deterministic order", async () => {
    const root = makeTempDirectory();
    mkdirSync(resolve(root, "zeta"));
    mkdirSync(resolve(root, "alpha10"));
    mkdirSync(resolve(root, "alpha2"));
    mkdirSync(resolve(root, ".hidden"));
    writeFileSync(resolve(root, "not-a-directory.txt"), "file");

    const result = await listAllowedDirectories(root, [root]);

    expect(result.path).toBe(root);
    expect(result.directories).toEqual([
      { name: "alpha2", path: resolve(root, "alpha2") },
      { name: "alpha10", path: resolve(root, "alpha10") },
      { name: "zeta", path: resolve(root, "zeta") },
    ]);
  });

  it("returns an empty listing for an empty allowed directory", async () => {
    const root = makeTempDirectory();

    await expect(listAllowedDirectories(root, [root])).resolves.toEqual({
      path: root,
      directories: [],
    });
  });

  it("allows nested paths under an allowed root", async () => {
    const root = makeTempDirectory();
    const nested = resolve(root, "projects");
    mkdirSync(nested);
    mkdirSync(resolve(nested, "ccpocket"));

    const result = await listAllowedDirectories(nested, [root]);

    expect(result.directories).toEqual([
      { name: "ccpocket", path: resolve(nested, "ccpocket") },
    ]);
  });

  it("rejects lexical traversal outside the allowed root", async () => {
    const root = makeTempDirectory();
    const outside = makeTempDirectory();

    await expect(
      listAllowedDirectories(resolve(root, "..", basename(outside)), [root]),
    ).rejects.toMatchObject<Partial<DirectoryListingError>>({
      code: "directory_not_allowed",
    });
  });

  it("rejects a requested symlink that resolves outside the allowed root", async () => {
    const root = makeTempDirectory();
    const outside = makeTempDirectory();
    symlinkSync(outside, resolve(root, "outside-link"), "dir");

    await expect(
      listAllowedDirectories(resolve(root, "outside-link"), [root]),
    ).rejects.toMatchObject<Partial<DirectoryListingError>>({
      code: "directory_not_allowed",
    });
  });

  it("omits symlinked child directories", async () => {
    const root = makeTempDirectory();
    const outside = makeTempDirectory();
    mkdirSync(resolve(root, "real"));
    symlinkSync(outside, resolve(root, "outside-link"), "dir");

    const result = await listAllowedDirectories(root, [root]);

    expect(result.directories).toEqual([
      { name: "real", path: resolve(root, "real") },
    ]);
  });

  it("reports missing paths, files, and disallowed roots", async () => {
    const root = makeTempDirectory();
    const filePath = resolve(root, "file.txt");
    writeFileSync(filePath, "file");

    await expect(
      listAllowedDirectories(resolve(root, "missing"), [root]),
    ).rejects.toMatchObject({ code: "directory_not_found" });
    await expect(
      listAllowedDirectories(filePath, [root]),
    ).rejects.toMatchObject({ code: "not_a_directory" });
    await expect(
      listAllowedDirectories(makeTempDirectory(), [root]),
    ).rejects.toMatchObject({ code: "directory_not_allowed" });
  });
});
