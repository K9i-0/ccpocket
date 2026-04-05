import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("./config.js", () => ({
  loadConfig: vi.fn(() => ({})),
}));

let mockBonjourCallback: ((service: { addresses: string[]; port: number }) => void) | null = null;
let localBridgeReachable = false;

vi.mock("node:net", () => ({
  Socket: class {
    private handlers = new Map<string, Array<() => void>>();
    setTimeout() {}
    once(event: string, cb: () => void) {
      const existing = this.handlers.get(event) ?? [];
      existing.push(cb);
      this.handlers.set(event, existing);
    }
    connect() {
      setTimeout(() => {
        const event = localBridgeReachable ? "connect" : "error";
        const handler = this.handlers.get(event)?.[0];
        handler?.();
      }, 0);
    }
    destroy() {}
  },
}));

vi.mock("bonjour-service", () => ({
  Bonjour: class {
    find(opts: unknown, cb: (service: { addresses: string[]; port: number }) => void) {
      mockBonjourCallback = cb;
      return { stop: vi.fn() };
    }
    destroy() {}
  },
}));

import { discoverBridge } from "./discovery.js";
import { loadConfig } from "./config.js";

describe("discoverBridge", () => {
  beforeEach(() => {
    mockBonjourCallback = null;
    localBridgeReachable = false;
  });

  it("returns saved config URL first", async () => {
    vi.mocked(loadConfig).mockReturnValue({
      bridgeUrl: "ws://saved:8765",
      defaultProvider: "claude",
      defaultPermissionMode: "default",
    });
    const url = await discoverBridge();
    expect(url).toBe("ws://saved:8765");
  });

  it("prefers localhost when the bridge is listening locally", async () => {
    vi.mocked(loadConfig).mockReturnValue({
      defaultProvider: "claude",
      defaultPermissionMode: "default",
    });
    localBridgeReachable = true;
    const url = await discoverBridge();
    expect(url).toBe("ws://127.0.0.1:8765");
  });

  it("falls back to mDNS discovery", async () => {
    vi.mocked(loadConfig).mockReturnValue({
      defaultProvider: "claude",
      defaultPermissionMode: "default",
    });
    const promise = discoverBridge(2000);
    setTimeout(() => {
      mockBonjourCallback?.({ addresses: ["10.0.0.5"], port: 8765 });
    }, 50);
    const url = await promise;
    expect(url).toBe("ws://10.0.0.5:8765");
  });
});
