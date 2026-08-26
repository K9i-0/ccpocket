import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname } from "node:path";
import { describe, expect, it } from "vitest";
import { createCodexAppServerAuth } from "./codex-app-server-auth.js";

describe("Codex app-server capability credentials", () => {
  it("creates distinct private token files and removes them idempotently", () => {
    const first = createCodexAppServerAuth();
    const second = createCodexAppServerAuth();

    try {
      expect(first.token).not.toBe(second.token);
      expect(first.tokenFilePath).toMatch(/^\//);
      expect(statSync(dirname(first.tokenFilePath)).mode & 0o777).toBe(0o700);
      expect(statSync(first.tokenFilePath).mode & 0o777).toBe(0o600);
      expect(readFileSync(first.tokenFilePath, "utf8")).toBe(first.token);
    } finally {
      first.cleanup();
      first.cleanup();
      second.cleanup();
    }

    expect(existsSync(first.tokenFilePath)).toBe(false);
    expect(existsSync(dirname(first.tokenFilePath))).toBe(false);
    expect(existsSync(second.tokenFilePath)).toBe(false);
    expect(existsSync(dirname(second.tokenFilePath))).toBe(false);
  });
});
