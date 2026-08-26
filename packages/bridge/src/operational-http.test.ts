import { createServer, type Server } from "node:http";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { handleCoreBridgeHttpRequest } from "./operational-http.js";
import { getBridgeGeneration, getPackageVersion } from "./version.js";

const API_KEY = "synthetic-api-key-sentinel";
const PROTECTED_SENTINELS = [
  API_KEY,
  "https://protected.invalid",
  "/home/protected-user",
  "/protected/allowed-directory",
  "protected-session-id",
  "protected-message-body",
  "protected-approval-body",
];

const temporaryPaths: string[] = [];
const servers: Server[] = [];

afterEach(async () => {
  for (const server of servers.splice(0)) {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
  for (const path of temporaryPaths.splice(0)) {
    rmSync(path, { recursive: true, force: true });
  }
});

function writeManifest(overrides: Record<string, unknown> = {}): string {
  const dir = mkdtempSync(join(tmpdir(), "ccpocket-http-manifest-"));
  temporaryPaths.push(dir);
  const path = join(dir, "RUNTIME_MANIFEST.json");
  writeFileSync(
    path,
    JSON.stringify({
      schema: "ccpocket-bridge-runtime-manifest/v1",
      packageVersion: getPackageVersion(),
      upstreamVersion: getPackageVersion(),
      upstreamTag: `bridge/v${getPackageVersion()}`,
      upstreamCommit: "a".repeat(40),
      patchCommit: "b".repeat(40),
      patchTreeSha256: "c".repeat(64),
      releaseId: "release-1.72.1-test",
      protocolMode: "http+websocket",
      readinessSchema: "ccpocket-bridge-readiness/v1",
      ...overrides,
    }),
  );
  return path;
}

async function startTestServer(options?: {
  apiKey?: string;
  manifestPath?: string;
}): Promise<string> {
  const startedAt = Date.now() - 5_000;
  const server = createServer((req, res) => {
    if (
      handleCoreBridgeHttpRequest(req, res, {
        startedAt,
        apiKey: options?.apiKey,
        env: {
          BRIDGE_RUNTIME_MANIFEST: options?.manifestPath,
          BRIDGE_CODEX_APP_SERVER_MODE: "isolated",
          HOME: PROTECTED_SENTINELS[2],
          BRIDGE_ALLOWED_DIRS: PROTECTED_SENTINELS[3],
          PROTECTED_URL: PROTECTED_SENTINELS[1],
          PROTECTED_SESSION: PROTECTED_SENTINELS[4],
          PROTECTED_MESSAGE: PROTECTED_SENTINELS[5],
          PROTECTED_APPROVAL: PROTECTED_SENTINELS[6],
        },
        getSessionCount: () => 6,
        getClientCount: () => 2,
        getReadinessCounts: () => ({
          activeTurns: 1,
          pendingApprovals: 2,
          pendingQuestions: 3,
          busyWorkers: 4,
          clients: 2,
        }),
      })
    ) {
      return;
    }
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not Found");
  });
  servers.push(server);
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("No test port");
  return `http://127.0.0.1:${address.port}`;
}

describe("authenticated operational HTTP routes", () => {
  it.each(["/server-info", "/readiness"])(
    "returns 503 for %s when authentication is unconfigured",
    async (path) => {
      const baseUrl = await startTestServer({ manifestPath: writeManifest() });
      const response = await fetch(`${baseUrl}${path}`);
      expect(response.status).toBe(503);
      expect(response.headers.get("cache-control")).toBe("no-store");
      expect(await response.json()).toEqual({ code: "auth_unavailable" });
    },
  );

  it.each(["/server-info", "/readiness"])(
    "rejects missing, malformed, wrong, and query-only credentials for %s",
    async (path) => {
      const baseUrl = await startTestServer({
        apiKey: API_KEY,
        manifestPath: writeManifest(),
      });
      const attempts: Array<{ url: string; authorization?: string }> = [
        { url: `${baseUrl}${path}` },
        { url: `${baseUrl}${path}`, authorization: API_KEY },
        { url: `${baseUrl}${path}`, authorization: "Basic synthetic" },
        { url: `${baseUrl}${path}`, authorization: "Bearer wrong-token" },
        { url: `${baseUrl}${path}?token=${encodeURIComponent(API_KEY)}` },
      ];

      for (const attempt of attempts) {
        const response = await fetch(attempt.url, {
          headers: attempt.authorization
            ? { Authorization: attempt.authorization }
            : undefined,
        });
        expect(response.status).toBe(401);
        expect(response.headers.get("cache-control")).toBe("no-store");
        expect(await response.json()).toEqual({ code: "unauthorized" });
      }
    },
  );

  it("returns the exact allowlisted server identity with a correct Bearer", async () => {
    const manifestPath = writeManifest();
    const baseUrl = await startTestServer({ apiKey: API_KEY, manifestPath });
    const response = await fetch(`${baseUrl}/server-info`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(body).toEqual({
      schema: "ccpocket-bridge-server-info/v1",
      packageVersion: getPackageVersion(),
      protocolMode: "http+websocket",
      codexAppServerMode: "isolated",
      generation: getBridgeGeneration(),
      runtimeManifest: {
        schema: "ccpocket-bridge-runtime-manifest/v1",
        packageVersion: getPackageVersion(),
        upstreamVersion: getPackageVersion(),
        upstreamTag: `bridge/v${getPackageVersion()}`,
        upstreamCommit: "a".repeat(40),
        patchCommit: "b".repeat(40),
        patchTreeSha256: "c".repeat(64),
        releaseId: "release-1.72.1-test",
        protocolMode: "http+websocket",
        readinessSchema: "ccpocket-bridge-readiness/v1",
      },
    });
    const serialized = JSON.stringify(body);
    for (const sentinel of PROTECTED_SENTINELS) {
      expect(serialized).not.toContain(sentinel);
    }
    expect(serialized).not.toContain(manifestPath);
    expect(serialized).not.toContain("session_list");
  });

  it("fails server identity closed without exposing manifest errors or paths", async () => {
    const manifestPath = writeManifest({ patchCommit: "invalid" });
    const baseUrl = await startTestServer({ apiKey: API_KEY, manifestPath });
    const response = await fetch(`${baseUrl}/server-info`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    const bodyText = await response.text();

    expect(response.status).toBe(503);
    expect(JSON.parse(bodyText)).toEqual({ code: "identity_unavailable" });
    expect(bodyText).not.toContain(manifestPath);
    expect(bodyText).not.toContain("patchCommit");
  });

  it("returns separately constructed count-only readiness despite an invalid manifest", async () => {
    const baseUrl = await startTestServer({
      apiKey: API_KEY,
      manifestPath: writeManifest({ patchCommit: "invalid" }),
    });
    const before = Date.now();
    const response = await fetch(`${baseUrl}/readiness`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    const body = await response.json();
    const after = Date.now();

    expect(response.status).toBe(200);
    expect(body).toEqual({
      schema: "ccpocket-bridge-readiness/v1",
      sampledAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/),
      activeTurns: 1,
      pendingApprovals: 2,
      pendingQuestions: 3,
      busyWorkers: 4,
      clients: 2,
    });
    expect(Date.parse(body.sampledAt)).toBeGreaterThanOrEqual(before);
    expect(Date.parse(body.sampledAt)).toBeLessThanOrEqual(after);
    const serialized = JSON.stringify(body);
    for (const sentinel of PROTECTED_SENTINELS) {
      expect(serialized).not.toContain(sentinel);
    }
  });
});

describe("existing public HTTP routes", () => {
  it("keeps /health and /version public and adds Authorization to CORS", async () => {
    const baseUrl = await startTestServer({ apiKey: API_KEY });
    const health = await fetch(`${baseUrl}/health`);
    const version = await fetch(`${baseUrl}/version`);
    const preflight = await fetch(`${baseUrl}/server-info`, {
      method: "OPTIONS",
    });

    expect(health.status).toBe(200);
    expect(await health.json()).toEqual({
      status: "ok",
      uptime: expect.any(Number),
      sessions: 6,
      clients: 2,
    });
    expect(version.status).toBe(200);
    expect(await version.json()).toEqual(
      expect.objectContaining({ version: getPackageVersion() }),
    );
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get("access-control-allow-headers")).toBe(
      "Content-Type, Authorization",
    );
  });
});
