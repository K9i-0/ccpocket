import { spawn, spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { chmod, mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import net from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import WebSocket from "ws";

const temporaryRoot = await mkdtemp(join(tmpdir(), "ccpocket-codex-auth-smoke-"));
const codexHome = join(temporaryRoot, "codex-home");
const authDirectory = join(temporaryRoot, "auth");
const tokenFilePath = join(authDirectory, "capability-token");
const token = randomBytes(32).toString("base64url");
const wrongToken = randomBytes(32).toString("base64url");
const version = spawnSync("codex", ["--version"], { encoding: "utf8" }).stdout.trim();

function reserveLoopbackPort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        server.close(() => reject(new Error("loopback port allocation failed")));
        return;
      }
      server.close((error) => (error ? reject(error) : resolve(address.port)));
    });
  });
}

function waitForTcp(port, timeoutMs = 5_000) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const attempt = () => {
      const socket = net.connect({ host: "127.0.0.1", port });
      socket.once("connect", () => socket.end(() => resolve()));
      socket.once("error", () => {
        socket.destroy();
        if (Date.now() >= deadline) reject(new Error("app-server readiness timeout"));
        else setTimeout(attempt, 50);
      });
    };
    attempt();
  });
}

function handshake(url, authorization) {
  return new Promise((resolve) => {
    const options = authorization === undefined
      ? undefined
      : { headers: { Authorization: authorization } };
    const socket = new WebSocket(url, options);
    const timeout = setTimeout(() => {
      socket.terminate();
      resolve("timeout");
    }, 3_000);
    socket.once("open", () => {
      clearTimeout(timeout);
      socket.close();
      resolve("open");
    });
    socket.once("unexpected-response", () => {
      clearTimeout(timeout);
      socket.terminate();
      resolve("rejected");
    });
    socket.once("error", () => {
      clearTimeout(timeout);
      resolve("rejected");
    });
  });
}

function terminate(child) {
  return new Promise((resolve, reject) => {
    if (child.exitCode !== null) return resolve();
    let forced = false;
    const forceTimeout = setTimeout(() => {
      forced = true;
      child.kill("SIGKILL");
    }, 3_000);
    const exitTimeout = setTimeout(() => {
      reject(new Error(forced ? "child did not exit after SIGKILL" : "child termination timeout"));
    }, 6_000);
    child.once("exit", () => {
      clearTimeout(forceTimeout);
      clearTimeout(exitTimeout);
      resolve();
    });
    child.kill("SIGTERM");
  });
}

let child;
let result = {
  version,
  readiness: false,
  missingBearerRejected: false,
  wrongBearerRejected: false,
  correctBearerHandshake: false,
  temporaryArtifactsRemoved: false,
};

try {
  await mkdir(codexHome, { mode: 0o700 });
  await mkdir(authDirectory, { mode: 0o700 });
  await chmod(authDirectory, 0o700);
  await writeFile(tokenFilePath, token, { encoding: "utf8", mode: 0o600, flag: "wx" });
  await chmod(tokenFilePath, 0o600);
  const port = await reserveLoopbackPort();
  const url = `ws://127.0.0.1:${port}`;
  child = spawn(
    "codex",
    [
      "app-server",
      "--listen",
      url,
      "--ws-auth",
      "capability-token",
      "--ws-token-file",
      tokenFilePath,
    ],
    {
      env: { ...process.env, CODEX_HOME: codexHome },
      stdio: "ignore",
    },
  );
  await waitForTcp(port);
  result.readiness = true;
  result.missingBearerRejected = (await handshake(url)) === "rejected";
  result.wrongBearerRejected = (await handshake(url, `Bearer ${wrongToken}`)) === "rejected";
  result.correctBearerHandshake = (await handshake(url, `Bearer ${token}`)) === "open";
} finally {
  let terminationError;
  if (child) {
    try {
      await terminate(child);
    } catch (error) {
      terminationError = error;
    }
  }
  await rm(temporaryRoot, {
    recursive: true,
    force: true,
    maxRetries: 10,
    retryDelay: 100,
  });
  result.temporaryArtifactsRemoved = true;
  if (terminationError) throw terminationError;
}

console.log(JSON.stringify(result));
if (!result.readiness || !result.missingBearerRejected || !result.wrongBearerRejected || !result.correctBearerHandshake) {
  process.exitCode = 1;
}
