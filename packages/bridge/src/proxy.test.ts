import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock undici before importing
const mockSetGlobalDispatcher = vi.fn();
const MockProxyAgent = vi.fn();
const MockAgent = vi.fn();
vi.mock("undici", () => ({
  setGlobalDispatcher: (...args: unknown[]) => mockSetGlobalDispatcher(...args),
  ProxyAgent: class { constructor(opts: unknown) { MockProxyAgent(opts); } },
  Agent: class { constructor(opts: unknown) { MockAgent(opts); } },
}));

// Mock socks
const mockCreateConnection = vi.fn();
vi.mock("socks", () => ({
  SocksClient: {
    createConnection: (...args: unknown[]) => mockCreateConnection(...args),
  },
}));

const { setupProxy } = await import("./proxy.js");

// Save and restore env vars
const PROXY_VARS = [
  "HTTPS_PROXY", "https_proxy",
  "HTTP_PROXY", "http_proxy",
  "ALL_PROXY", "all_proxy",
] as const;

describe("setupProxy", () => {
  let savedEnv: Record<string, string | undefined>;

  beforeEach(() => {
    vi.clearAllMocks();
    savedEnv = {};
    for (const key of PROXY_VARS) {
      savedEnv[key] = process.env[key];
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const key of PROXY_VARS) {
      if (savedEnv[key] !== undefined) {
        process.env[key] = savedEnv[key];
      } else {
        delete process.env[key];
      }
    }
  });

  it("returns undefined when no proxy env var is set", () => {
    expect(setupProxy()).toBeUndefined();
    expect(mockSetGlobalDispatcher).not.toHaveBeenCalled();
  });

  it("configures ProxyAgent for http:// proxy", () => {
    process.env.HTTPS_PROXY = "http://proxy.local:3128";
    const result = setupProxy();
    expect(result).toBe("http://proxy.local:3128");
    expect(MockProxyAgent).toHaveBeenCalledWith({ uri: "http://proxy.local:3128" });
    expect(mockSetGlobalDispatcher).toHaveBeenCalledOnce();
  });

  it("configures ProxyAgent for https:// proxy", () => {
    process.env.HTTP_PROXY = "https://secure-proxy:8443";
    const result = setupProxy();
    expect(result).toBe("https://secure-proxy:8443");
    expect(MockProxyAgent).toHaveBeenCalledWith({ uri: "https://secure-proxy:8443" });
  });

  it("configures SOCKS Agent for socks5:// proxy", () => {
    process.env.HTTPS_PROXY = "socks5://socks.local:1080";
    const result = setupProxy();
    expect(result).toBe("socks5://socks.local:1080");
    expect(MockAgent).toHaveBeenCalledOnce();
    expect(mockSetGlobalDispatcher).toHaveBeenCalledOnce();
  });

  it("configures SOCKS Agent for socks4:// proxy", () => {
    process.env.ALL_PROXY = "socks4://socks.local:1080";
    const result = setupProxy();
    expect(result).toBe("socks4://socks.local:1080");
    expect(MockAgent).toHaveBeenCalledOnce();
  });

  it("returns undefined for unsupported protocol", () => {
    process.env.HTTPS_PROXY = "ftp://proxy:21";
    expect(setupProxy()).toBeUndefined();
    expect(mockSetGlobalDispatcher).not.toHaveBeenCalled();
  });

  it("returns undefined for invalid URL", () => {
    process.env.HTTPS_PROXY = "not a url";
    expect(setupProxy()).toBeUndefined();
    expect(mockSetGlobalDispatcher).not.toHaveBeenCalled();
  });

  // Env var priority: HTTPS_PROXY > HTTP_PROXY > ALL_PROXY

  it("prefers HTTPS_PROXY over HTTP_PROXY", () => {
    process.env.HTTPS_PROXY = "http://preferred:3128";
    process.env.HTTP_PROXY = "http://fallback:3128";
    const result = setupProxy();
    expect(result).toBe("http://preferred:3128");
  });

  it("falls back to HTTP_PROXY when HTTPS_PROXY is not set", () => {
    process.env.HTTP_PROXY = "http://fallback:3128";
    const result = setupProxy();
    expect(result).toBe("http://fallback:3128");
  });

  it("falls back to ALL_PROXY when others are not set", () => {
    process.env.ALL_PROXY = "socks5://all:1080";
    const result = setupProxy();
    expect(result).toBe("socks5://all:1080");
  });

  it("reads lowercase env vars", () => {
    process.env.https_proxy = "http://lower:3128";
    const result = setupProxy();
    expect(result).toBe("http://lower:3128");
  });

  it("handles socks5h:// protocol", () => {
    process.env.HTTPS_PROXY = "socks5h://socks.local:1080";
    const result = setupProxy();
    expect(result).toBe("socks5h://socks.local:1080");
    expect(MockAgent).toHaveBeenCalledOnce();
  });
});
