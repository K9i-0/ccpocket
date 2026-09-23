import { mkdtemp, writeFile, rm, symlink, utimes } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createServer, type Server, type Socket } from "node:net";
import { afterEach, describe, expect, it, vi } from "vitest";
import { consumeFinderProof, verifyFinderSocketProof, revealInFinder } from "./finder-reveal.js";

const execMock = vi.hoisted(() => vi.fn((_file, _args, _options, callback) => callback(null, "", "")));
vi.mock("node:child_process", () => ({ execFile: execMock }));

const directories: string[] = [];
const token = "a".repeat(64);
const servers: Server[] = [];
const sockets = new Set<Socket>();
async function listener(respond: (socket: Socket) => void): Promise<number> {
  const server = createServer(socket => {
    sockets.add(socket);
    socket.on("error", () => {});
    socket.on("close", () => sockets.delete(socket));
    respond(socket);
  });
  servers.push(server);
  await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("No port");
  return address.port;
}
async function proof() {
  const directory = await mkdtemp(join(tmpdir(), "ccpocket-finder-"));
  directories.push(directory);
  const path = join(directory, "proof");
  await writeFile(path, token, { mode: 0o600 });
  return path;
}

afterEach(async () => {
  for (const socket of sockets) socket.destroy();
  await Promise.all(servers.splice(0).map(server => new Promise<void>(resolve => server.close(() => resolve()))));
  await Promise.all(directories.splice(0).map(path => rm(path, { recursive: true, force: true })));
  vi.clearAllMocks();
});

describe("Finder socket proof", () => {
  it("accepts an exact local token split across packets without sending requests", async () => {
    let received = 0;
    const port = await listener(socket => {
      socket.on("data", data => { received += data.length; });
      socket.write(token.slice(0, 10));
      socket.end(token.slice(10));
    });
    expect(await verifyFinderSocketProof(port, token)).toBe(true);
    expect(received).toBe(0);
  });

  it("rejects missing, wrong, truncated, oversized and non-ASCII replies", async () => {
    for (const reply of ["", "b".repeat(64), token.slice(1), token + "a", Buffer.alloc(64, 0xe1)]) {
      const port = await listener(socket => socket.end(reply));
      expect(await verifyFinderSocketProof(port, token)).toBe(false);
    }
    const port = await listener(socket => socket.destroy());
    expect(await verifyFinderSocketProof(port, token)).toBe(false);
  });

  it("bounds silent connections and rejects invalid ports or tokens", async () => {
    const port = await listener(() => {});
    expect(await verifyFinderSocketProof(port, token)).toBe(false);
    for (const invalidPort of [-1, 0, 80, 65536, 1024.5]) {
      expect(await verifyFinderSocketProof(invalidPort, token)).toBe(false);
    }
    expect(await verifyFinderSocketProof(port, "invalid")).toBe(false);
  });
});

describe.skipIf(process.platform === "win32")("Finder locality proof", () => {
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
