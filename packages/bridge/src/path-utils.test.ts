import { describe, expect, it } from "vitest";
import {
  isPathWithinAllowedDirectory,
  normalizePlatformPath,
  parseAllowedDirectories,
  resolvePlatformPath,
  resolvePlatformPathFrom,
  stripWindowsExtendedPathPrefix,
} from "./path-utils.js";

describe("path-utils", () => {
  it("accepts Windows subdirectories under an allowed parent", () => {
    expect(
      isPathWithinAllowedDirectory(
        "D:\\Users\\alice\\src\\ccpocket",
        "D:\\Users\\alice",
        "win32",
      ),
    ).toBe(true);
  });

  it("normalizes extended Windows drive paths", () => {
    expect(stripWindowsExtendedPathPrefix("\\\\?\\D:\\Users\\alice\\project"))
      .toBe("D:\\Users\\alice\\project");
    expect(
      resolvePlatformPath("\\\\?\\D:\\Users\\alice\\project", "win32"),
    ).toBe("D:\\Users\\alice\\project");
  });

  it("normalizes extended Windows UNC paths", () => {
    expect(
      stripWindowsExtendedPathPrefix("\\\\?\\UNC\\server\\share\\project"),
    ).toBe("\\\\server\\share\\project");
  });

  it("rejects paths outside the allowed parent on Windows", () => {
    expect(
      isPathWithinAllowedDirectory(
        "E:\\Users\\alice\\src\\ccpocket",
        "D:\\Users\\alice",
        "win32",
      ),
    ).toBe(false);
  });

  it("keeps POSIX normalization behavior unchanged", () => {
    expect(normalizePlatformPath("/tmp/project/../repo", "linux")).toBe(
      "/tmp/repo",
    );
    expect(
      isPathWithinAllowedDirectory("/tmp/repo/src", "/tmp/repo", "linux"),
    ).toBe(true);
  });

  it("resolves relative paths against an explicit base path", () => {
    expect(resolvePlatformPathFrom("/tmp/repo", "../shared", "linux")).toBe(
      "/tmp/shared",
    );
    expect(
      resolvePlatformPathFrom("D:\\Users\\alice\\repo", "..\\shared", "win32"),
    ).toBe("D:\\Users\\alice\\shared");
  });

  it("uses default allowed directories when unset or empty", () => {
    expect(parseAllowedDirectories(undefined, "linux", ["/home/alice"]))
      .toEqual(["/home/alice"]);
    expect(parseAllowedDirectories("", "linux", ["/home/alice"]))
      .toEqual(["/home/alice"]);
  });

  it("allows explicit unrestricted mode with star", () => {
    expect(parseAllowedDirectories("*", "linux", ["/home/alice"]))
      .toEqual([]);
  });

  it("parses comma-separated allowed directories when configured", () => {
    expect(parseAllowedDirectories("/home/alice, /opt/project", "linux"))
      .toEqual(["/home/alice", "/opt/project"]);
  });
});
