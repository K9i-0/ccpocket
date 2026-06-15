import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("ccpocket-bridge CLI", () => {
  it("rejects an invalid --port value before server startup", () => {
    const tsxBin = resolve(
      process.cwd(),
      "../../node_modules/.bin",
      process.platform === "win32" ? "tsx.cmd" : "tsx",
    );
    const env = { ...process.env };
    delete env.BRIDGE_PORT;

    const result = spawnSync(tsxBin, ["src/cli.ts", "--port", "abc"], {
      cwd: process.cwd(),
      encoding: "utf8",
      env,
    });

    expect(result.status).toBe(1);
    expect(result.stderr).toContain(
      '[bridge] Failed to start: Invalid BRIDGE_PORT "abc"',
    );
  });
});
