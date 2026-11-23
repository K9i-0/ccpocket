import { mkdtemp, readFile } from "node:fs/promises";
import { createServer, request, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { handleAdminRequest, isSupervised } from "./admin-api.js";
import type { ApiKeySource } from "./bridge-auth.js";
import { applyBridgeConfig } from "./bridge-config.js";
import { LogBuffer } from "./log-buffer.js";

const PAIRING_FIXTURE = "fixture-pairing-value";

let server: Server | undefined;
afterEach(() => {
  server?.close();
  server = undefined;
});

async function startAdmin(opts: {
  env?: NodeJS.ProcessEnv;
  apiKeySource?: ApiKeySource;
} = {}) {
  const dir = await mkdtemp(join(tmpdir(), "bridge-admin-"));
  const configPath = join(dir, "config.json");
  const apiKeyFile = join(dir, "bridge-api-key");
  const restart = vi.fn();
  const logs = new LogBuffer();
  logs.add("info", "hello", 1);
  const env = opts.env ?? {};
  server = createServer((req, res) => {
    if (
      !handleAdminRequest(req, res, {
        pairingSecret: PAIRING_FIXTURE,
        port: 8765,
        version: "1.2.3",
        startedAt: 5,
        appliedConfig: applyBridgeConfig({}, {}, "/home/u"),
        apiKeySource: opts.apiKeySource ?? "stored",
        logs,
        counts: () => ({ sessions: 2, clients: 1 }),
        restart,
        env,
        configPath,
        apiKeyFile,
      })
    ) {
      res.writeHead(404);
      res.end("fallthrough");
    }
  });
  await new Promise<void>((resolve) => server!.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;

  function call(
    method: string,
    path: string,
    body?: unknown,
    headers: Record<string, string> = {
      "x-ccpocket-pairing-secret": PAIRING_FIXTURE,
    },
  ): Promise<{ status: number; body: string; json: () => any }> {
    return new Promise((resolve, reject) => {
      const req = request(
        { host: "127.0.0.1", port, method, path, headers },
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () =>
            resolve({
              status: res.statusCode ?? 0,
              body: data,
              json: () => JSON.parse(data),
            }),
          );
        },
      );
      req.on("error", reject);
      req.end(body === undefined ? undefined : JSON.stringify(body));
    });
  }
  return { call, restart, configPath, apiKeyFile };
}

describe("isSupervised", () => {
  it("is true for supervising launchers and the setup launchd service", () => {
    expect(isSupervised({})).toBe(false);
    expect(isSupervised({ CCPOCKET_BRIDGE_SUPERVISED: "1" })).toBe(true);
    expect(isSupervised({ XPC_SERVICE_NAME: "com.ccpocket.bridge" })).toBe(true);
    expect(isSupervised({ XPC_SERVICE_NAME: "0" })).toBe(false);
  });
});

describe("handleAdminRequest", () => {
  it("ignores other paths", async () => {
    const { call } = await startAdmin();
    expect((await call("GET", "/health")).body).toBe("fallthrough");
    expect((await call("GET", "/administrator")).body).toBe("fallthrough");
  });

  it("rejects requests without the pairing secret, from a browser, or by API key", async () => {
    const { call, configPath } = await startAdmin();
    expect((await call("GET", "/admin/status", undefined, {})).status).toBe(403);
    expect(
      (
        await call("GET", "/admin/status", undefined, {
          authorization: "Bearer some-api-key",
        })
      ).status,
    ).toBe(403);
    expect(
      (
        await call("PUT", "/admin/config", { settings: { allowedDirs: ["*"] } }, {
          "x-ccpocket-pairing-secret": PAIRING_FIXTURE,
          origin: "http://evil.test",
        })
      ).status,
    ).toBe(403);
    await expect(readFile(configPath, "utf8")).rejects.toThrow();
  });

  it("reports status", async () => {
    const { call } = await startAdmin();
    const res = await call("GET", "/admin/status");
    expect(res.status).toBe(200);
    expect(res.json()).toMatchObject({
      adminApiVersion: 1,
      version: "1.2.3",
      port: 8765,
      supervised: false,
      apiKeySource: "stored",
      safeMode: false,
      restartRequired: false,
      sessions: 2,
      clients: 1,
    });
  });

  it("saves settings and reports that a restart is needed", async () => {
    const { call, configPath } = await startAdmin();
    const saved = await call("PUT", "/admin/config", {
      settings: { allowedDirs: ["/a"], antigravityApiKey: "fixture-key" },
    });
    expect(saved.status).toBe(200);
    expect(saved.body).not.toContain("fixture-key");
    expect(saved.json().restartRequired).toBe(true);
    expect(JSON.parse(await readFile(configPath, "utf8")).settings).toEqual({
      allowedDirs: ["/a"],
      antigravityApiKey: "fixture-key",
    });

    const view = (await call("GET", "/admin/config")).json();
    const dirs = view.settings.find((s: any) => s.key === "allowedDirs");
    expect(dirs).toMatchObject({
      value: ["/home/u"],
      fileValue: ["/a"],
      source: "default",
    });
    expect((await call("GET", "/admin/status")).json().restartRequired).toBe(true);

    const cleared = await call("PUT", "/admin/config", {
      settings: { allowedDirs: null, antigravityApiKey: null },
    });
    expect(cleared.json().restartRequired).toBe(false);
  });

  it("rejects invalid settings without writing", async () => {
    const { call, configPath } = await startAdmin();
    const res = await call("PUT", "/admin/config", {
      settings: { port: 0, host: "ok" },
    });
    expect(res.status).toBe(400);
    expect(res.json().errors).toHaveProperty("port");
    await expect(readFile(configPath, "utf8")).rejects.toThrow();
    expect((await call("PUT", "/admin/config", undefined)).status).toBe(400);
  });

  it("restarts only when something will start the Bridge again", async () => {
    const manual = await startAdmin();
    const refused = await manual.call("POST", "/admin/restart");
    expect(refused.status).toBe(409);
    expect(refused.json()).toEqual({ error: "not_supervised" });
    expect(manual.restart).not.toHaveBeenCalled();
    server?.close();

    const supervised = await startAdmin({
      env: { CCPOCKET_BRIDGE_SUPERVISED: "1" },
    });
    expect((await supervised.call("POST", "/admin/restart")).status).toBe(202);
    await vi.waitFor(() => expect(supervised.restart).toHaveBeenCalledOnce());
  });

  it("replaces a stored API key but not a configured one", async () => {
    const stored = await startAdmin();
    const res = await stored.call("POST", "/admin/api-key/rotate");
    expect(res.json()).toEqual({ restartRequired: true });
    expect((await readFile(stored.apiKeyFile, "utf8")).trim().length)
      .toBeGreaterThan(20);
    server?.close();

    const configured = await startAdmin({ apiKeySource: "configured" });
    expect((await configured.call("POST", "/admin/api-key/rotate")).status)
      .toBe(409);
    await expect(readFile(configured.apiKeyFile, "utf8")).rejects.toThrow();
  });

  it("returns recent logs", async () => {
    const { call } = await startAdmin();
    expect((await call("GET", "/admin/logs?limit=10")).json()).toEqual({
      entries: [{ time: 1, level: "info", message: "hello" }],
    });
    expect((await call("GET", "/admin/nope")).status).toBe(404);
  });
});
