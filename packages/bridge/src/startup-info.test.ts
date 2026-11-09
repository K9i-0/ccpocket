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
  buildPairingInfo,
  printStartupInfo,
  renderPairingInfo,
  validatePublicWsUrl,
} = await import("./startup-info.js");

describe("startup-info", () => {
  const originalEnv = process.env;
  const logSpy = vi.spyOn(console, "log").mockImplementation(() => {});
  const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
  const printed = () => logSpy.mock.calls.map((call) => String(call[0])).join("\n");

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
    it("uses LAN address for deep link by default", async () => {
      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(printed()).toContain("● LAN");
      expect(printed()).toContain("ws://192.168.1.20:8765");
      expect(printed()).toContain(
        "LAN        ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
      );
      expect(mockQrToString).toHaveBeenCalledWith(
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
        expect.objectContaining({ type: "terminal", small: true }),
      );
    });

    it("uses public url for deep link and qr when configured", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.ngrok-free.app/ws";

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(printed()).toContain("● Public");
      expect(printed()).toContain("wss://example.ngrok-free.app/ws");
      expect(printed()).toContain(
        "Public     ccpocket://connect?url=wss%3A%2F%2Fexample.ngrok-free.app%2Fws&token=test-token",
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

      expect(printed()).toContain("[DEMO MODE]");
      expect(printed()).toContain(
        "ccpocket://connect?url=wss%3A%2F%2Fexample.ngrok-free.app",
      );
      expect(printed()).not.toContain("token=test-token");
      expect(printed()).not.toContain("100.64.0.2");
    });

    it("warns and falls back when public url is invalid", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "https://example.com";

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(warnSpy).toHaveBeenCalledWith(
        "[bridge] Warning: ignoring invalid BRIDGE_PUBLIC_WS_URL: https://example.com",
      );
      expect(mockQrToString).toHaveBeenCalledWith(
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
        expect.any(Object),
      );
    });

    it("still prints public deep link when no local addresses are available", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.com";
      mockNetworkInterfaces.mockReturnValue({});

      await printStartupInfo(8765, "0.0.0.0", "test-token");

      expect(printed()).toContain("wss://example.com");
      expect(mockQrToString).toHaveBeenCalled();
    });
  });

  describe("buildPairingInfo", () => {
    it("lists every address and prefers LAN for the deep link", () => {
      const info = buildPairingInfo(8765, "test-token");

      expect(info.auth).toBe("required");
      expect(info.connections).toEqual([
        {
          label: "LAN",
          wsUrl: "ws://192.168.1.20:8765",
          deepLink:
            "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
        },
        {
          label: "Tailscale",
          wsUrl: "ws://100.64.0.2:8765",
          deepLink:
            "ccpocket://connect?url=ws%3A%2F%2F100.64.0.2%3A8765&token=test-token",
        },
      ]);
      expect(info.deepLink).toBe(
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
      );
    });

    it("reports auth none without a key", () => {
      const info = buildPairingInfo(8765);

      expect(info.auth).toBe("none");
      expect(info.deepLink).toBe(
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765",
      );
    });

    it("hides Tailscale and the token in demo mode", () => {
      process.env.BRIDGE_DEMO_MODE = "1";

      const info = buildPairingInfo(8765, "test-token");

      expect(info.connections.map((c) => c.label)).toEqual(["LAN"]);
      expect(info.deepLink).not.toContain("token=");
    });
  });

  describe("QR codes per route", () => {
    it("prints one QR code for LAN and one for Tailscale", async () => {
      await printStartupInfo(8765, "0.0.0.0", "test-token");

      const qrInputs = mockQrToString.mock.calls.map((call) => call[0]);
      expect(qrInputs).toEqual([
        "ccpocket://connect?url=ws%3A%2F%2F192.168.1.20%3A8765&token=test-token",
        "ccpocket://connect?url=ws%3A%2F%2F100.64.0.2%3A8765&token=test-token",
      ]);
      expect(printed()).toContain("● Tailscale");
      expect(printed()).toContain("Anywhere on your tailnet");
    });

    it("puts the public URL first and still offers LAN and Tailscale", async () => {
      process.env.BRIDGE_PUBLIC_WS_URL = "wss://example.com";

      await printStartupInfo(8765, "0.0.0.0", "k");

      const qrInputs = mockQrToString.mock.calls.map((call) =>
        decodeURIComponent(String(call[0])),
      );
      expect(qrInputs).toHaveLength(3);
      expect(qrInputs[0]).toContain("wss://example.com");
    });

    it("skips link-local addresses and extra addresses of the same route", async () => {
      mockNetworkInterfaces.mockReturnValue({
        en0: [{ family: "IPv4", internal: false, address: "192.168.1.20" }],
        en1: [{ family: "IPv4", internal: false, address: "10.0.0.5" }],
        bridge0: [{ family: "IPv4", internal: false, address: "169.254.10.1" }],
      });

      const info = buildPairingInfo(8765, "k");
      expect(info.connections.map((c) => c.wsUrl)).toEqual([
        "ws://192.168.1.20:8765",
        "ws://10.0.0.5:8765",
      ]);

      await printStartupInfo(8765, "0.0.0.0", "k");
      expect(mockQrToString).toHaveBeenCalledTimes(1);
    });
  });

  describe("renderPairingInfo", () => {
    const qr = "QRLINE-1\nQRLINE-2\n";

    function render(columns: number, color = false) {
      const info = buildPairingInfo(8765, "k");
      const codes = new Map(info.connections.map((c) => [c.deepLink, qr]));
      return renderPairingInfo(info, codes, { color, columns });
    }

    it("places routes side by side when they fit", () => {
      const lines = render(200).split("\n");
      const heading = lines.find((line) => line.includes("● LAN"));
      expect(heading).toContain("● Tailscale");
      expect(lines.filter((line) => line.includes("QRLINE-1"))).toHaveLength(1);
    });

    it("stacks routes on narrow terminals", () => {
      const lines = render(30).split("\n");
      const heading = lines.find((line) => line.includes("● LAN"));
      expect(heading).not.toContain("Tailscale");
      expect(lines.filter((line) => line.includes("QRLINE-1"))).toHaveLength(2);
    });

    it("colors only when asked", () => {
      expect(render(200, false)).not.toContain("\x1b[");
      expect(render(200, true)).toContain("\x1b[32m");
      expect(render(200, true)).toContain("\x1b[36m");
    });

    it("lists additional addresses of the same route", () => {
      mockNetworkInterfaces.mockReturnValue({
        en0: [{ family: "IPv4", internal: false, address: "192.168.1.20" }],
        en1: [{ family: "IPv4", internal: false, address: "10.0.0.5" }],
      });
      const output = render(200);
      expect(output).toContain("Other addresses:");
      expect(output).toContain("ws://10.0.0.5:8765");
    });
  });
});
