import { execFile } from "node:child_process";
import { constants } from "node:fs";
import { open, realpath, stat, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, isAbsolute } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/** A short-lived, one-use proof that the app can write this Mac's local disk. */
export async function consumeFinderProof(path: string, token: string): Promise<boolean> {
  if (!isAbsolute(path) || basename(path) !== "proof" ||
      !/^ccpocket-finder-[A-Za-z0-9]+$/.test(basename(dirname(path))) ||
      !/^[a-f0-9]{64}$/.test(token)) return false;
  try {
    const handle = await open(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    try {
      const info = await handle.stat();
      const localDisk = await stat(await realpath(tmpdir()));
      const age = Date.now() - info.mtimeMs;
      if (!info.isFile() || info.size !== 64 || info.dev !== localDisk.dev ||
          info.uid !== process.getuid?.() || age < -1000 || age > 30_000) return false;
      const contents = Buffer.alloc(64);
      const { bytesRead } = await handle.read(contents, 0, 64, 0);
      if (bytesRead !== 64 || contents.toString("ascii") !== token) return false;
      await unlink(path);
      return true;
    } finally {
      await handle.close();
    }
  } catch {
    return false;
  }
}

/** Reveal only; never execute or open the file with its associated application. */
export async function revealInFinder(canonicalPath: string): Promise<void> {
  await execFileAsync("/usr/bin/open", ["-R", canonicalPath], { timeout: 5000 });
}
