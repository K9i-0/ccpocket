import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mockNetworkInterfaces = vi.fn();
const mockQrToString = vi.fn();

vi.mock("node:os", () => ({
  default: {
    networkInterfaces: () => mockNetworkInterfaces(),
  },
}));

vi.mock("qrcode", () => ({
  default: {
    toString: (...args: unknown[]) => mockQrToString(...args),
  },
}));

const {
  buildConnectionUrl,
  printStartupInfo,
  validatePublicWsUrl,
} = await import("./startup-info.js");

describe("startup-info", () => {
  const originalEnv = process.env;
  const logSpy = vi.spyOn(console, "log").mockImplementation(() => {});
  const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv };
    delete process.env.BRIDGE_PUBLIC_WS_URL;
    delete process.env.BRIDGE_DEMO_MODE;
    mockQrToString.mockResolvedValue("QR");
    mockNetworkInterfaces.mockReturnValue({
      en0: [{ family: "IPv4", internal: false, address: "192.168.1.20" }],
      utun4: [{ family: "IPv4", internal: false, address: "100.64.0.2" }],
      lo0: [{ family: "IPv4", internal: true, address: "127.0.0.1" }],
    });
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  describe("validatePublicWsUrl", () => {
    it("returns trimmed url for valid wss url", () => {
      expect(validatePublicWsUrl("  wss://example.com/path?x=1  ")).toBe(
        "wss://example.com/path?x=1",
      );
    });

    it("returns undefined for invalid protocol", () => {
      expect(validatePublicWsUrl("https://example.com")).toBeUndefined();
    });
  });

  describe("buildConnectionUrl", () => {
    it("includes token when api key is provided", () => {
      expect(buildConnectionUrl("wss://example.com/bridge", "secret")).toBe(
        "ccpocket://connect?url=wss%3A%2F%2Fexample.com%2Fbridge&token=secret",
      );
    });

    it("omits token when api key is empty", () => {
      expect(buildConnectionUrl("ws://192.168.1.20:8765")).toBe(
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765",
      );
    });
  });

  describe("printStartupInfo", () => {
    it("prefers tailscale address for deep link when available", async () => {
      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining("LAN:         ws://192.168.1.20:8765"),
      );
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining("Tailscale:   ws://100.64.0.2:8765"),
      );
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          "Deep Link: ccpocket://connect?url=ws%3A%2F%2F100.64.0.2%3A8765&token=test-token",
        ),
      );
      expect(mockQrToString).toHaveBeenCalledWith(
        "ccpocket://connect?url=ws%3A%2F%2F100.64.0.2%3A8765&token=test-token",
        expect.objectContaining({ type: "terminal", small: true }),
      );
    });

    it("uses public url for deep link and qr when configured", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.ngrok-free.app/ws";

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining("Public:      wss://example.ngrok-free.app/ws"),
      );
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          "Deep Link: ccpocket://connect?url=wss%3A%2F%2Fexample.ngrok-free.app%2Fws&token=test-token",
        ),
      );
      expect(mockQrToString).toHaveBeenCalledWith(
        "ccpocket://connect?url=wss%3A%2F%2Fexample.ngrok-free.app%2Fws&token=test-token",
        expect.any(Object),
      );
    });

    it("omits token from public deep link in demo mode", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.ngrok-free.app";
      process.env.BRIDGE_DEMO_MODE = "1";

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          "Deep Link: ccpocket://connect?url=wss%3A%2F%2Fexample.ngrok-free.app",
        ),
      );
      expect(logSpy).not.toHaveBeenCalledWith(expect.stringContaining("token=test-token"));
      expect(logSpy).not.toHaveBeenCalledWith(
        expect.stringContaining("Tailscale:   ws://100.64.0.2:8765"),
      );
    });

    it("warns and falls back when public url is invalid", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "https://example.com";

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(warnSpy).toHaveBeenCalledWith(
        "[bridge] Warning: ignoring invalid BRIDGE_PUBLIC_WS_URL: https://example.com",
      );
      expect(mockQrToString).toHaveBeenCalledWith(
        "ccpocket://connect?url=ws%3A%2F%2F100.64.0.2%3A8765&token=test-token",
        expect.any(Object),
      );
    });

    it("still prints public deep link when no local addresses are available", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.com";
      mockNetworkInterfaces.mockReturnValue({});

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining("Public:      wss://example.com"),
      );
      expect(mockQrToString).toHaveBeenCalled();
    });
  });
});
