import { describe, it, expect, vi, beforeEach } from "vitest";

const fakeFiles = new Map<string, string>();

vi.mock("node:fs", () => ({
  existsSync: vi.fn((p: string) => fakeFiles.has(p)),
  readFileSync: vi.fn((p: string) => {
    const c = fakeFiles.get(p);
    if (!c) throw new Error("ENOENT");
    return c;
  }),
  mkdirSync: vi.fn(),
  writeFileSync: vi.fn(),
}));

vi.mock("node:os", () => ({
  homedir: () => "/mock-home",
}));

import { loadConfig, saveConfig, type Config } from "./config.js";

describe("config", () => {
  beforeEach(() => {
    fakeFiles.clear();
  });

  it("returns defaults when no config file exists", () => {
    const config = loadConfig();
    expect(config.bridgeUrl).toBeUndefined();
    expect(config.defaultProvider).toBe("claude");
  });

  it("reads existing config file", () => {
    fakeFiles.set(
      "/mock-home/.ccpocket/config.json",
      JSON.stringify({ bridgeUrl: "ws://10.0.0.1:8765", defaultProvider: "codex" }),
    );
    const config = loadConfig();
    expect(config.bridgeUrl).toBe("ws://10.0.0.1:8765");
    expect(config.defaultProvider).toBe("codex");
  });

  it("returns defaults on malformed JSON", () => {
    fakeFiles.set("/mock-home/.ccpocket/config.json", "not json");
    const config = loadConfig();
    expect(config.defaultProvider).toBe("claude");
  });
});
