import { mkdtemp, readFile, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import {
  applyBridgeConfig,
  bridgeConfigPath,
  describeBridgeConfig,
  mergeBridgeSettings,
  readBridgeConfigFile,
  validateBridgeSettings,
  writeBridgeConfigFile,
} from "./bridge-config.js";

async function tempConfigPath(): Promise<string> {
  return join(await mkdtemp(join(tmpdir(), "bridge-config-")), "config.json");
}

describe("bridgeConfigPath", () => {
  it("defaults to ~/.ccpocket and honors BRIDGE_CONFIG_FILE", () => {
    expect(bridgeConfigPath({}, "/home/u")).toBe(
      join("/home/u", ".ccpocket", "bridge-config.json"),
    );
    expect(bridgeConfigPath({ BRIDGE_CONFIG_FILE: "/x/c.json" }, "/home/u"))
      .toBe("/x/c.json");
  });
});

describe("validateBridgeSettings", () => {
  it("normalizes valid settings", () => {
    const { settings, errors } = validateBridgeSettings({
      port: "8770",
      host: " 127.0.0.1 ",
      allowedDirs: ["/a", " /b "],
      allowClaudeOAuth: true,
      codexAppServerMode: "managed",
      publicWsUrl: "wss://example.test/bridge",
      readOnlyDirs: null,
    });
    expect(errors).toEqual({});
    expect(settings).toEqual({
      port: 8770,
      host: "127.0.0.1",
      allowedDirs: ["/a", "/b"],
      allowClaudeOAuth: true,
      codexAppServerMode: "managed",
      publicWsUrl: "wss://example.test/bridge",
    });
  });

  it("reports invalid and unknown settings", () => {
    const { settings, errors } = validateBridgeSettings({
      port: 70000,
      allowedDirs: ["*", "/a"],
      readOnlyDirs: ["*"],
      codexAppServerMode: "shared",
      publicWsUrl: "https://example.test",
      host: "a\nb",
      allowClaudeOAuth: "1",
      nope: 1,
    });
    expect(settings).toEqual({});
    expect(Object.keys(errors).sort()).toEqual([
      "allowClaudeOAuth",
      "allowedDirs",
      "codexAppServerMode",
      "host",
      "nope",
      "port",
      "publicWsUrl",
      "readOnlyDirs",
    ]);
  });

  it("rejects paths the comma-separated env format cannot carry", () => {
    expect(validateBridgeSettings({ allowedDirs: ["/a,b"] }).errors)
      .toHaveProperty("allowedDirs");
  });
});

describe("config file", () => {
  it("round-trips settings in a file only the user can read", async () => {
    const path = await tempConfigPath();
    await writeBridgeConfigFile({ port: 8770, allowedDirs: ["*"] }, path);
    expect((await stat(path)).mode & 0o777).toBe(0o600);
    expect(JSON.parse(await readFile(path, "utf8"))).toEqual({
      version: 1,
      settings: { port: 8770, allowedDirs: ["*"] },
    });
    expect(await readBridgeConfigFile(path)).toEqual({
      settings: { port: 8770, allowedDirs: ["*"] },
      warnings: [],
    });
  });

  it("treats a missing file as empty", async () => {
    expect(await readBridgeConfigFile(await tempConfigPath())).toEqual({
      settings: {},
      warnings: [],
    });
  });

  it("ignores broken JSON and invalid settings with a warning", async () => {
    const path = await tempConfigPath();
    await writeFile(path, "{nope");
    const broken = await readBridgeConfigFile(path);
    expect(broken.settings).toEqual({});
    expect(broken.warnings).toHaveLength(1);

    await writeFile(path, JSON.stringify({ settings: { port: -1, host: "h" } }));
    const partial = await readBridgeConfigFile(path);
    expect(partial.settings).toEqual({ host: "h" });
    expect(partial.warnings).toHaveLength(1);
  });
});

describe("applyBridgeConfig", () => {
  it("fills unset variables and lets the environment win", () => {
    const env: NodeJS.ProcessEnv = { BRIDGE_PORT: "9000", BRIDGE_HOST: "  " };
    const applied = applyBridgeConfig(
      {
        port: 8770,
        host: "127.0.0.1",
        allowedDirs: ["/a", "/b"],
        allowClaudeOAuth: true,
        fileDownloadAllowAllPaths: false,
        notifyGoalTurnCompleted: true,
        antigravityApiKey: "fixture-key",
      },
      env,
      "/home/u",
    );
    expect(env).toMatchObject({
      BRIDGE_PORT: "9000",
      BRIDGE_HOST: "127.0.0.1",
      BRIDGE_ALLOWED_DIRS: "/a,/b",
      BRIDGE_ALLOW_CLAUDE_OAUTH: "1",
      BRIDGE_NOTIFY_GOAL_TURN_COMPLETED: "true",
      CCPOCKET_ANTIGRAVITY_API_KEY: "fixture-key",
    });
    expect(env.BRIDGE_FILE_DOWNLOAD_ALLOW_ALL_PATHS).toBeUndefined();
    expect(applied.settings.port).toEqual({ value: 9000, source: "env" });
    expect(applied.settings.host).toEqual({
      value: "127.0.0.1",
      source: "file",
    });
    expect(applied.settings.readOnlyDirs).toEqual({
      value: null,
      source: "default",
    });
    expect(applied.settings.codexAppServerMode).toEqual({
      value: "private",
      source: "default",
    });
  });

  it("uses the home directory as the default allowed directory", () => {
    const applied = applyBridgeConfig({}, {}, "/home/u");
    expect(applied.settings.allowedDirs).toEqual({
      value: ["/home/u"],
      source: "default",
    });
    expect(applied.settings.port.value).toBe(8765);
  });
});

describe("describeBridgeConfig", () => {
  it("never returns secrets and flags pending file changes", () => {
    const applied = applyBridgeConfig(
      { antigravityApiKey: "fixture-key", host: "127.0.0.1" },
      { BRIDGE_PORT: "9000" },
      "/home/u",
    );
    const same = describeBridgeConfig(applied, applied.fileSettings, "/c.json");
    expect(same.restartRequired).toBe(false);
    expect(JSON.stringify(same)).not.toContain("fixture-key");
    const secret = same.settings.find((s) => s.key === "antigravityApiKey");
    expect(secret).toMatchObject({
      value: null,
      configured: true,
      fileConfigured: true,
      source: "file",
    });

    const changed = describeBridgeConfig(
      applied,
      { ...applied.fileSettings, host: "0.0.0.0" },
      "/c.json",
    );
    expect(changed.restartRequired).toBe(true);
    expect(changed.settings.find((s) => s.key === "host")).toMatchObject({
      value: "127.0.0.1",
      fileValue: "0.0.0.0",
    });

    // The environment overrides the port, so a saved port changes nothing.
    const overridden = describeBridgeConfig(
      applied,
      { ...applied.fileSettings, port: 8770 },
      "/c.json",
    );
    expect(overridden.restartRequired).toBe(false);
  });
});

describe("mergeBridgeSettings", () => {
  it("merges a patch and removes null settings", () => {
    expect(
      mergeBridgeSettings(
        { port: 8770, host: "127.0.0.1" },
        { host: null, allowClaudeOAuth: true },
      ),
    ).toEqual({ ok: true, settings: { port: 8770, allowClaudeOAuth: true } });
  });

  it("rejects the whole patch when a value is invalid", () => {
    expect(mergeBridgeSettings({}, { port: 0, host: "h" })).toMatchObject({
      ok: false,
      errors: { port: expect.any(String) },
    });
    expect(mergeBridgeSettings({}, "x")).toMatchObject({ ok: false });
  });

  it("requires a URL for the external Codex app-server mode", () => {
    expect(mergeBridgeSettings({}, { codexAppServerMode: "external" }))
      .toMatchObject({ ok: false });
    expect(
      mergeBridgeSettings(
        {},
        {
          codexAppServerMode: "external",
          codexSharedAppServerUrl: "ws://127.0.0.1:8767",
        },
      ),
    ).toMatchObject({ ok: true });
  });
});
