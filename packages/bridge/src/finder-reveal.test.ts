import { mkdtemp, writeFile, rm, symlink, utimes } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { consumeFinderProof, revealInFinder } from "./finder-reveal.js";

const execMock = vi.hoisted(() => vi.fn((_file, _args, _options, callback) => callback(null, "", "")));
vi.mock("node:child_process", () => ({ execFile: execMock }));

const directories: string[] = [];
const token = "a".repeat(64);
async function proof() {
  const directory = await mkdtemp(join(tmpdir(), "ccpocket-finder-"));
  directories.push(directory);
  const path = join(directory, "proof");
  await writeFile(path, token, { mode: 0o600 });
  return path;
}

afterEach(async () => {
  await Promise.all(directories.splice(0).map(path => rm(path, { recursive: true, force: true })));
  vi.clearAllMocks();
});

describe("Finder locality proof", () => {
  it("consumes a matching local proof only once", async () => {
    const path = await proof();
    expect(await consumeFinderProof(path, token)).toBe(true);
    expect(await consumeFinderProof(path, token)).toBe(false);
  });

  it("rejects missing, mismatching and expired proofs", async () => {
    const path = await proof();
    expect(await consumeFinderProof(path + "missing", token)).toBe(false);
    expect(await consumeFinderProof(path, "b".repeat(64))).toBe(false);
    const old = new Date(Date.now() - 60_000);
    await utimes(path, old, old);
    expect(await consumeFinderProof(path, token)).toBe(false);
  });

  it("rejects symlinks and over-sized files", async () => {
    const path = await proof();
    const target = path + "-target";
    await writeFile(target, token);
    await rm(path);
    await symlink(target, path);
    expect(await consumeFinderProof(path, token)).toBe(false);
    await rm(path);
    await writeFile(path, token.repeat(2));
    expect(await consumeFinderProof(path, token)).toBe(false);
  });

  it("passes paths as a single reveal-only argument without a shell", async () => {
    await revealInFinder('/tmp/動画 $(touch unwanted).mp4');
    expect(execMock).toHaveBeenCalledWith('/usr/bin/open', ['-R', '/tmp/動画 $(touch unwanted).mp4'],
      { timeout: 5000 }, expect.any(Function));
  });
});
