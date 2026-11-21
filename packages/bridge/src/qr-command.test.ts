import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { fetchLocalPairing, runQrCommand } from "./qr-command.js";
import { buildConnectionUrl } from "./startup-info.js";

describe("fetchLocalPairing", () => {
  it("requests the loopback pairing endpoint and returns its body", async () => {
    const pairing = {
      auth: "required",
      connections: [{ label: "LAN", wsUrl: "ws://192.168.1.20:8765" }],
      wsUrl: "ws://192.168.1.20:8765",
      deepLink: "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=k",
      token: "k",
    };
    const fetchImpl = vi.fn(async () => Response.json(pairing));

    const result = await fetchLocalPairing(9000, fetchImpl as typeof fetch, async () => "s");

    expect(fetchImpl).toHaveBeenCalledWith(
      "http://127.0.0.1:9000/pairing",
      expect.objectContaining({
        headers: { "x-ccpocket-pairing-secret": "s" },
      }),
    );
    expect(result).toEqual({ ok: true, pairing });
  });

  it("reports when no Bridge is running", async () => {
    const fetchImpl = vi.fn(async () => {
      throw new TypeError("fetch failed");
    });

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch, async () => "s");

    expect(result.ok).toBe(false);
    expect(!result.ok && result.message).toContain("port 8765");
  });

  it("asks to update an old Bridge without the endpoint", async () => {
    const fetchImpl = vi.fn(async () => new Response("Not Found", { status: 404 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch, async () => "s");

    expect(!result.ok && result.message).toContain("too old");
  });

  it("reports refused requests", async () => {
    const fetchImpl = vi.fn(async () => new Response("Forbidden", { status: 403 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch, async () => "s");

    expect(!result.ok && result.message).toContain("pairing secret");
  });

  it("explains a missing secret without calling the Bridge", async () => {
    const fetchImpl = vi.fn();

    const result = await fetchLocalPairing(
      8765,
      fetchImpl as unknown as typeof fetch,
      async () => null,
    );

    expect(fetchImpl).not.toHaveBeenCalled();
    expect(!result.ok && result.message).toContain("No pairing secret");
  });

  it("reports other HTTP failures with their status, even with a JSON body", async () => {
    const fetchImpl = vi.fn(async () => Response.json({ error: "boom" }, { status: 500 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch, async () => "s");

    expect(result).toEqual({ ok: false, message: expect.stringContaining("HTTP 500") });
  });

  it("reports a successful response that is not JSON", async () => {
    const fetchImpl = vi.fn(async () => new Response("<html>", { status: 200 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch, async () => "s");

    expect(result).toEqual({ ok: false, message: expect.stringContaining("invalid pairing info") });
  });
});

describe("runQrCommand", () => {
  const PORT = 9123;
  let home: string;
  let fetchMock: ReturnType<typeof vi.fn>;
  let log: ReturnType<typeof vi.spyOn>;
  let warn: ReturnType<typeof vi.spyOn>;
  let error: ReturnType<typeof vi.spyOn>;

  const printed = (spy: ReturnType<typeof vi.spyOn>): string =>
    spy.mock.calls.map((call) => call.join(" ")).join("\n");

  function writeSecret(secret: string): void {
    mkdirSync(join(home, ".ccpocket"), { recursive: true });
    writeFileSync(join(home, ".ccpocket", `pairing-secret-${PORT}`), `${secret}\n`);
  }

  // The pairing secret is read from the home directory, so point it at a
  // temporary one; the Bridge itself is replaced by a stubbed fetch.
  beforeEach(() => {
    home = mkdtempSync(join(tmpdir(), "ccpocket-qr-command-"));
    vi.stubEnv("HOME", home);
    vi.stubEnv("USERPROFILE", home);
    vi.stubEnv("NO_COLOR", "1");
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    log = vi.spyOn(console, "log").mockImplementation(() => {});
    warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    error = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    rmSync(home, { recursive: true, force: true });
  });

  it("fails with the reason when the pairing info cannot be fetched", async () => {
    expect(await runQrCommand(PORT)).toBe(1);

    expect(fetchMock).not.toHaveBeenCalled();
    expect(printed(error)).toContain("ERROR: No pairing secret found");
    expect(log).not.toHaveBeenCalled();
  });

  it("fails when the Bridge has no reachable address", async () => {
    writeSecret("file-secret");
    fetchMock.mockResolvedValue(
      Response.json({ auth: "required", connections: [], wsUrl: null, deepLink: null, token: "k" }),
    );

    expect(await runQrCommand(PORT)).toBe(1);

    expect(printed(error)).toContain("ERROR: No reachable network address found");
    expect(log).not.toHaveBeenCalled();
  });

  it("prints the routes, the preferred one first, and the API key", async () => {
    writeSecret("file-secret");
    const lan = "ws://192.168.1.20:9123";
    const tailscale = "ws://100.64.0.2:9123";
    const tailscaleLink = "ccpocket://connect?url=from-bridge&token=k";
    fetchMock.mockResolvedValue(
      Response.json({
        auth: "required",
        // Bridges before 1.104.0 return no per-connection deep link.
        connections: [
          { label: "LAN", wsUrl: lan },
          { label: "Tailscale", wsUrl: tailscale, deepLink: tailscaleLink },
        ],
        wsUrl: tailscale,
        deepLink: tailscaleLink,
        token: "k",
      }),
    );

    expect(await runQrCommand(PORT)).toBe(0);

    expect(fetchMock).toHaveBeenCalledWith(
      `http://127.0.0.1:${PORT}/pairing`,
      expect.objectContaining({ headers: { "x-ccpocket-pairing-secret": "file-secret" } }),
    );
    const output = printed(log);
    expect(output).toContain(buildConnectionUrl(lan, "k"));
    expect(output).toContain(tailscaleLink);
    expect(output).not.toContain(buildConnectionUrl(tailscale, "k"));
    expect(output.indexOf("● Tailscale")).toBeGreaterThanOrEqual(0);
    expect(output.indexOf("● Tailscale")).toBeLessThan(output.indexOf("● LAN"));
    expect(output).not.toContain("DEMO MODE");
    expect(output).toContain("API key for desktop apps: k");
    expect(warn).not.toHaveBeenCalled();
    expect(error).not.toHaveBeenCalled();
  });

  it("warns instead of printing a key when the Bridge has no API key", async () => {
    writeSecret("file-secret");
    const lan = "ws://192.168.1.20:9123";
    fetchMock.mockResolvedValue(
      Response.json({
        auth: "none",
        connections: [{ label: "LAN", wsUrl: lan }],
        wsUrl: lan,
        deepLink: buildConnectionUrl(lan),
        token: null,
      }),
    );

    expect(await runQrCommand(PORT)).toBe(0);

    const output = printed(log);
    expect(output).toContain(buildConnectionUrl(lan));
    expect(output).not.toContain("token=");
    expect(output).not.toContain("API key for desktop apps");
    expect(printed(warn)).toContain("WARNING: this Bridge has no API key");
  });
});
