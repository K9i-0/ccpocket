import { mkdtemp, rm, stat } from "node:fs/promises";
import type { IncomingMessage } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  bearerToken,
  httpRouteRequiresAuth,
  isAuthorizedHttpRequest,
  isLocalPairingRequest,
  resolveApiKey,
  pairingSecretPath,
  readPairingSecret,
  tokensMatch,
  writePairingSecret,
} from "./bridge-auth.js";

const PAIRING_FIXTURE = "fixture-pairing-value";

function fakeRequest(opts: {
  remoteAddress?: string;
  host?: string;
  origin?: string;
  secret?: string | null;
}): IncomingMessage {
  const headers: Record<string, string> = {};
  if (opts.secret !== null) {
    headers["x-ccpocket-pairing-secret"] = opts.secret ?? PAIRING_FIXTURE;
  }
  if (opts.host !== undefined) headers.host = opts.host;
  if (opts.origin !== undefined) headers.origin = opts.origin;
  return {
    socket: { remoteAddress: opts.remoteAddress },
    headers,
  } as unknown as IncomingMessage;
}

describe("tokensMatch", () => {
  it("accepts the exact key", () => {
    expect(tokensMatch("secret", "secret")).toBe(true);
  });

  it("rejects a missing, different or prefix token", () => {
    expect(tokensMatch(null, "secret")).toBe(false);
    expect(tokensMatch(undefined, "secret")).toBe(false);
    expect(tokensMatch("", "secret")).toBe(false);
    expect(tokensMatch("secre", "secret")).toBe(false);
    expect(tokensMatch("secret2", "secret")).toBe(false);
  });
});

describe("isLocalPairingRequest", () => {
  it("allows loopback requests addressed to a loopback host", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "127.0.0.1", host: "127.0.0.1:8765" }), PAIRING_FIXTURE,
      ),
    ).toBe(true);
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "::1", host: "[::1]:8765" }), PAIRING_FIXTURE,
      ),
    ).toBe(true);
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "::ffff:127.0.0.1", host: "localhost:8765" }), PAIRING_FIXTURE,
      ),
    ).toBe(true);
  });

  it("rejects requests from other machines", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "192.168.1.30", host: "127.0.0.1:8765" }), PAIRING_FIXTURE,
      ),
    ).toBe(false);
  });

  it("rejects DNS-rebinding style host headers", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "127.0.0.1", host: "evil.example:8765" }), PAIRING_FIXTURE,
      ),
    ).toBe(false);
    expect(
      isLocalPairingRequest(fakeRequest({ remoteAddress: "127.0.0.1" }), PAIRING_FIXTURE),
    ).toBe(false);
  });

  it("rejects browser requests carrying an Origin header", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({
          remoteAddress: "127.0.0.1",
          host: "localhost:8765",
          origin: "https://evil.example",
        }), PAIRING_FIXTURE,
      ),
    ).toBe(false);
  });
});

describe("pairing secret", () => {
  it("requires the matching secret", () => {
    const base = { remoteAddress: "127.0.0.1", host: "127.0.0.1:8765" };
    expect(
      isLocalPairingRequest(fakeRequest({ ...base, secret: null }), PAIRING_FIXTURE),
    ).toBe(false);
    expect(
      isLocalPairingRequest(fakeRequest({ ...base, secret: "wrong" }), PAIRING_FIXTURE),
    ).toBe(false);
    expect(isLocalPairingRequest(fakeRequest(base), null)).toBe(false);
  });

  it("writes a per-port secret readable only by the owner", async () => {
    const home = await mkdtemp(join(tmpdir(), "ccpocket-pairing-"));
    try {
      const path = pairingSecretPath(8766, home);
      expect(path).toBe(join(home, ".ccpocket", "pairing-secret-8766"));

      const secret = await writePairingSecret(path);

      expect(secret).toMatch(/^[0-9a-f]{64}$/);
      expect(await readPairingSecret(path)).toBe(secret);
      expect((await stat(path)).mode & 0o777).toBe(0o600);
      expect(await readPairingSecret(join(home, "missing"))).toBeNull();
    } finally {
      await rm(home, { recursive: true, force: true });
    }
  });
});

describe("resolveApiKey", () => {
  async function withHome<T>(fn: (path: string) => Promise<T>): Promise<T> {
    const home = await mkdtemp(join(tmpdir(), "ccpocket-key-"));
    try {
      return await fn(join(home, ".ccpocket", "bridge-api-key"));
    } finally {
      await rm(home, { recursive: true, force: true });
    }
  }

  it("prefers an explicitly configured key without touching disk", () =>
    withHome(async (path) => {
      expect(
        await resolveApiKey({ configured: " mine ", insecureNoAuth: false, path }),
      ).toEqual({ apiKey: "mine", source: "configured" });
      expect(await readPairingSecret(path)).toBeNull();
    }));

  it("disables auth only when explicitly requested", () =>
    withHome(async (path) => {
      expect(await resolveApiKey({ insecureNoAuth: true, path })).toEqual({
        source: "disabled",
      });
      expect(await readPairingSecret(path)).toBeNull();
    }));

  it("generates, persists and then reuses a key", () =>
    withHome(async (path) => {
      const first = await resolveApiKey({ insecureNoAuth: false, path });
      expect(first.source).toBe("generated");
      expect(first.apiKey).toMatch(/^[A-Za-z0-9_-]{32}$/);
      expect((await stat(path)).mode & 0o777).toBe(0o600);

      const second = await resolveApiKey({ insecureNoAuth: false, path });
      expect(second).toEqual({ apiKey: first.apiKey, source: "stored" });
    }));
});

describe("HTTP auth", () => {
  function request(
    method: string,
    url: string,
    authorization?: string,
  ): IncomingMessage {
    return {
      method,
      url,
      headers: authorization ? { authorization } : {},
    } as unknown as IncomingMessage;
  }

  it("protects account data and gallery writes only", () => {
    expect(httpRouteRequiresAuth("GET", "/usage")).toBe(true);
    expect(httpRouteRequiresAuth("GET", "/doctor")).toBe(true);
    expect(httpRouteRequiresAuth("POST", "/api/gallery/upload")).toBe(true);
    expect(httpRouteRequiresAuth("POST", "/api/gallery/upload?x=1")).toBe(true);
    expect(httpRouteRequiresAuth("DELETE", "/api/gallery/abc")).toBe(true);

    expect(httpRouteRequiresAuth("GET", "/health")).toBe(false);
    expect(httpRouteRequiresAuth("GET", "/version")).toBe(false);
    expect(httpRouteRequiresAuth("GET", "/api/gallery/abc")).toBe(false);
    expect(httpRouteRequiresAuth("OPTIONS", "/api/gallery/upload")).toBe(false);
  });

  it("reads bearer tokens", () => {
    expect(bearerToken(request("GET", "/usage", "Bearer abc"))).toBe("abc");
    expect(bearerToken(request("GET", "/usage", "bearer  abc "))).toBe("abc");
    expect(bearerToken(request("GET", "/usage", "Basic abc"))).toBeNull();
    expect(bearerToken(request("GET", "/usage"))).toBeNull();
  });

  it("requires the key on protected routes", () => {
    expect(isAuthorizedHttpRequest(request("GET", "/usage"), "k")).toBe(false);
    expect(
      isAuthorizedHttpRequest(request("GET", "/usage", "Bearer wrong"), "k"),
    ).toBe(false);
    expect(
      isAuthorizedHttpRequest(request("GET", "/usage", "Bearer k"), "k"),
    ).toBe(true);
    expect(isAuthorizedHttpRequest(request("GET", "/health"), "k")).toBe(true);
    expect(isAuthorizedHttpRequest(request("GET", "/usage"), undefined)).toBe(
      true,
    );
  });
});
