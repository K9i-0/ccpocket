import type { IncomingMessage } from "node:http";
import { describe, expect, it } from "vitest";
import { isLocalPairingRequest, tokensMatch } from "./bridge-auth.js";

function fakeRequest(opts: {
  remoteAddress?: string;
  host?: string;
  origin?: string;
}): IncomingMessage {
  const headers: Record<string, string> = {};
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
        fakeRequest({ remoteAddress: "127.0.0.1", host: "127.0.0.1:8765" }),
      ),
    ).toBe(true);
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "::1", host: "[::1]:8765" }),
      ),
    ).toBe(true);
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "::ffff:127.0.0.1", host: "localhost:8765" }),
      ),
    ).toBe(true);
  });

  it("rejects requests from other machines", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "192.168.1.30", host: "127.0.0.1:8765" }),
      ),
    ).toBe(false);
  });

  it("rejects DNS-rebinding style host headers", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({ remoteAddress: "127.0.0.1", host: "evil.example:8765" }),
      ),
    ).toBe(false);
    expect(
      isLocalPairingRequest(fakeRequest({ remoteAddress: "127.0.0.1" })),
    ).toBe(false);
  });

  it("rejects browser requests carrying an Origin header", () => {
    expect(
      isLocalPairingRequest(
        fakeRequest({
          remoteAddress: "127.0.0.1",
          host: "localhost:8765",
          origin: "https://evil.example",
        }),
      ),
    ).toBe(false);
  });
});
