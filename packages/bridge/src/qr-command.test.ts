import { describe, expect, it, vi } from "vitest";
import { fetchLocalPairing } from "./qr-command.js";

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

    const result = await fetchLocalPairing(9000, fetchImpl as typeof fetch);

    expect(fetchImpl).toHaveBeenCalledWith(
      "http://127.0.0.1:9000/pairing",
      expect.any(Object),
    );
    expect(result).toEqual({ ok: true, pairing });
  });

  it("reports when no Bridge is running", async () => {
    const fetchImpl = vi.fn(async () => {
      throw new TypeError("fetch failed");
    });

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch);

    expect(result.ok).toBe(false);
    expect(!result.ok && result.message).toContain("port 8765");
  });

  it("asks to update an old Bridge without the endpoint", async () => {
    const fetchImpl = vi.fn(async () => new Response("Not Found", { status: 404 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch);

    expect(!result.ok && result.message).toContain("too old");
  });

  it("reports refused requests", async () => {
    const fetchImpl = vi.fn(async () => new Response("Forbidden", { status: 403 }));

    const result = await fetchLocalPairing(8765, fetchImpl as typeof fetch);

    expect(!result.ok && result.message).toContain("HTTP 403");
  });
});
