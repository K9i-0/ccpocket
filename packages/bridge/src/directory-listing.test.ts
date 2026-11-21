import {
  chmodSync,
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
  it("includes real files on request while preserving the directory-only contract", async () => {
    const root = makeTempDirectory();
    mkdirSync(resolve(root, "empty"));
    writeFileSync(resolve(root, "a.txt"), "hello");
    writeFileSync(resolve(root, ".hidden"), "hidden");
    symlinkSync(resolve(root, "a.txt"), resolve(root, "link.txt"));
    const legacy = await listAllowedDirectories(root, [root]);
    expect(legacy.files).toBeUndefined();
    const result = await listAllowedDirectories(root, [root], process.platform, true, true);
    expect(result.directories.map((entry) => entry.name)).toEqual(["empty"]);
    expect(result.files?.map((entry) => entry.name)).toEqual([".hidden", "a.txt"]);
    const visible = await listAllowedDirectories(root, [root], process.platform, false, true);
    expect(visible.files?.map((entry) => entry.name)).toEqual(["a.txt"]);
  });

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

  it("includes hidden directories when requested", async () => {
    const root = makeTempDirectory();
    mkdirSync(resolve(root, "visible"));
    mkdirSync(resolve(root, ".hidden"));

    const result = await listAllowedDirectories(
      root,
      [root],
      process.platform,
      true,
    );

    expect(result.directories).toEqual([
      { name: ".hidden", path: resolve(root, ".hidden") },
      { name: "visible", path: resolve(root, "visible") },
    ]);
  });

  it("still omits hidden symlinked directories when requested", async () => {
    const root = makeTempDirectory();
    const outside = makeTempDirectory();
    mkdirSync(resolve(root, ".real"));
    symlinkSync(outside, resolve(root, ".outside-link"), "dir");

    const result = await listAllowedDirectories(
      root,
      [root],
      process.platform,
      true,
    );

    expect(result.directories).toEqual([
      { name: ".real", path: resolve(root, ".real") },
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

  it("preserves the configured symlink root namespace", async () => {
    const root = makeTempDirectory();
    const aliases = makeTempDirectory();
    const alias = resolve(aliases, "allowed-link");
    symlinkSync(root, alias, "dir");
    mkdirSync(resolve(root, "project"));
    mkdirSync(resolve(root, "project", "nested"));

    const listing = await listAllowedDirectories(alias, [alias]);

    expect(listing).toEqual({
      path: alias,
      directories: [{ name: "project", path: resolve(alias, "project") }],
    });
    await expect(
      listAllowedDirectories(resolve(alias, "project"), [alias]),
    ).resolves.toEqual({
      path: resolve(alias, "project"),
      directories: [
        { name: "nested", path: resolve(alias, "project", "nested") },
      ],
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

  describe("allowed roots", () => {
    it("accepts a path under any one of several allowed roots", async () => {
      const first = makeTempDirectory();
      const second = makeTempDirectory();
      const outside = makeTempDirectory();
      mkdirSync(resolve(first, "one"));
      mkdirSync(resolve(second, "two"));
      const allowed = [first, second];

      await expect(listAllowedDirectories(first, allowed)).resolves.toEqual({
        path: first,
        directories: [{ name: "one", path: resolve(first, "one") }],
      });
      await expect(listAllowedDirectories(second, allowed)).resolves.toEqual({
        path: second,
        directories: [{ name: "two", path: resolve(second, "two") }],
      });
      await expect(
        listAllowedDirectories(outside, allowed),
      ).rejects.toMatchObject({ code: "directory_not_allowed" });
    });

    it("ignores a configured root that no longer exists", async () => {
      const root = makeTempDirectory();
      const missingRoot = resolve(makeTempDirectory(), "gone");
      mkdirSync(resolve(root, "child"));

      const result = await listAllowedDirectories(root, [missingRoot, root]);

      expect(result.directories.map((entry) => entry.name)).toEqual(["child"]);
      await expect(
        listAllowedDirectories(missingRoot, [missingRoot, root]),
      ).rejects.toMatchObject({ code: "directory_not_found" });
    });

    it("lists any directory when no allowed roots are configured", async () => {
      const root = makeTempDirectory();
      mkdirSync(resolve(root, "child"));
      writeFileSync(resolve(root, "note.txt"), "note");

      await expect(
        listAllowedDirectories(root, [], process.platform, false, true),
      ).resolves.toEqual({
        path: root,
        directories: [{ name: "child", path: resolve(root, "child") }],
        files: [{ name: "note.txt", path: resolve(root, "note.txt") }],
      });
    });

    it("explains whether the request or its symlink target is outside the roots", async () => {
      const root = makeTempDirectory();
      const outside = makeTempDirectory();
      symlinkSync(outside, resolve(root, "outside-link"), "dir");

      await expect(listAllowedDirectories(outside, [root])).rejects.toMatchObject({
        name: "DirectoryListingError",
        code: "directory_not_allowed",
        message: "Directory path is outside the allowed roots",
      });
      await expect(
        listAllowedDirectories(resolve(root, "outside-link"), [root]),
      ).rejects.toMatchObject({
        name: "DirectoryListingError",
        code: "directory_not_allowed",
        message: "Directory path resolves outside the allowed roots",
      });
    });
  });

  describe("files and symlinks", () => {
    it("omits files unless they are requested", async () => {
      const root = makeTempDirectory();
      mkdirSync(resolve(root, "dir"));
      writeFileSync(resolve(root, "file.txt"), "file");

      const withoutFiles = await listAllowedDirectories(root, [root]);
      expect(withoutFiles).toEqual({
        path: root,
        directories: [{ name: "dir", path: resolve(root, "dir") }],
      });

      const withFiles = await listAllowedDirectories(
        root,
        [root],
        process.platform,
        false,
        true,
      );
      expect(withFiles.directories).toEqual([
        { name: "dir", path: resolve(root, "dir") },
      ]);
      expect(withFiles.files).toEqual([
        { name: "file.txt", path: resolve(root, "file.txt") },
      ]);
    });

    it("omits symlinks to files and directories, inside or outside the roots", async () => {
      const root = makeTempDirectory();
      const outside = makeTempDirectory();
      mkdirSync(resolve(root, "real-dir"));
      writeFileSync(resolve(root, "real.txt"), "real");
      writeFileSync(resolve(outside, "secret.txt"), "secret");
      symlinkSync(resolve(root, "real-dir"), resolve(root, "inside-dir-link"), "dir");
      symlinkSync(outside, resolve(root, "outside-dir-link"), "dir");
      symlinkSync(resolve(root, "real.txt"), resolve(root, "inside-file-link.txt"));
      symlinkSync(
        resolve(outside, "secret.txt"),
        resolve(root, "outside-file-link.txt"),
      );

      for (const allowed of [[root], []]) {
        const result = await listAllowedDirectories(
          root,
          allowed,
          process.platform,
          true,
          true,
        );
        expect(result.directories.map((entry) => entry.name)).toEqual(["real-dir"]);
        expect(result.files?.map((entry) => entry.name)).toEqual(["real.txt"]);
      }
    });

    it("sorts files naturally and case-insensitively", async () => {
      const root = makeTempDirectory();
      for (const name of ["c.txt", "b10.txt", "b2.txt", "B.txt", "a.txt", "b1.txt"]) {
        writeFileSync(resolve(root, name), name);
      }

      const result = await listAllowedDirectories(
        root,
        [root],
        process.platform,
        false,
        true,
      );

      expect(result.files?.map((entry) => entry.name)).toEqual([
        "a.txt",
        "B.txt",
        "b1.txt",
        "b2.txt",
        "b10.txt",
        "c.txt",
      ]);
    });
  });

  describe("filesystem errors", () => {
    it("reports a path below a file as not found", async () => {
      const root = makeTempDirectory();
      writeFileSync(resolve(root, "file.txt"), "file");

      await expect(
        listAllowedDirectories(resolve(root, "file.txt", "sub"), [root]),
      ).rejects.toMatchObject({
        name: "DirectoryListingError",
        code: "directory_not_found",
        message: "Directory not found",
      });
    });

    it("reports a file with a dedicated message", async () => {
      const root = makeTempDirectory();
      writeFileSync(resolve(root, "file.txt"), "file");

      await expect(
        listAllowedDirectories(resolve(root, "file.txt"), [root]),
      ).rejects.toMatchObject({
        code: "not_a_directory",
        message: "Selected path is not a directory",
      });
    });

    it("reports an unresolvable path as a read failure", async () => {
      const root = makeTempDirectory();
      // A symlink loop fails with ELOOP, which is neither "missing" nor
      // "permission denied".
      symlinkSync(resolve(root, "b"), resolve(root, "a"));
      symlinkSync(resolve(root, "a"), resolve(root, "b"));

      await expect(
        listAllowedDirectories(resolve(root, "a"), [root]),
      ).rejects.toMatchObject({
        name: "DirectoryListingError",
        code: "directory_read_failed",
        message: "Unable to read directory",
      });
    });

    // Permission bits are not enforced for root or on Windows.
    describe.skipIf(process.platform === "win32" || process.getuid?.() === 0)(
      "permission denied",
      () => {
        const notReadable = {
          name: "DirectoryListingError",
          code: "directory_not_readable",
          message: "Directory is not readable",
        };

        it("reports a directory whose entries cannot be read", async () => {
          const root = makeTempDirectory();
          const locked = resolve(root, "locked");
          mkdirSync(locked);
          chmodSync(locked, 0o000);
          try {
            await expect(
              listAllowedDirectories(locked, [root]),
            ).rejects.toMatchObject(notReadable);
          } finally {
            chmodSync(locked, 0o700);
          }
        });

        it("reports a path below a directory that cannot be traversed", async () => {
          const root = makeTempDirectory();
          const locked = resolve(root, "locked");
          mkdirSync(resolve(locked, "child"), { recursive: true });
          chmodSync(locked, 0o000);
          try {
            await expect(
              listAllowedDirectories(resolve(locked, "child"), [root]),
            ).rejects.toMatchObject(notReadable);
          } finally {
            chmodSync(locked, 0o700);
          }
        });
      },
    );
  });
});
