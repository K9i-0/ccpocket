import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  isClaudeBedrockModeEnabled,
  isClaudeBedrockRegionConfigured,
  isClaudeVertexModeEnabled,
} from "./claude-provider.js";

describe("isClaudeBedrockModeEnabled", () => {
  let configDir: string;

  // Every case points CLAUDE_CONFIG_DIR at a temporary directory so the result
  // never depends on the developer's real Claude Code settings.
  beforeEach(() => {
    configDir = mkdtempSync(join(tmpdir(), "ccpocket-claude-provider-"));
  });

  afterEach(() => {
    rmSync(configDir, { recursive: true, force: true });
  });

  function writeUserSettings(settings: unknown): void {
    writeFileSync(join(configDir, "settings.json"), JSON.stringify(settings));
  }

  it("is disabled when nothing is configured", () => {
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
  });

  it("accepts the environment values Claude Code treats as enabled", () => {
    for (const value of ["1", "true", "TRUE", "yes", "on", " 1 "]) {
      expect(
        isClaudeBedrockModeEnabled({
          CLAUDE_CONFIG_DIR: configDir,
          CLAUDE_CODE_USE_BEDROCK: value,
        }),
      ).toBe(true);
    }
  });

  it("rejects environment values Claude Code treats as disabled", () => {
    for (const value of ["", "0", "false", "no", "off", "bedrock"]) {
      expect(
        isClaudeBedrockModeEnabled({
          CLAUDE_CONFIG_DIR: configDir,
          CLAUDE_CODE_USE_BEDROCK: value,
        }),
      ).toBe(false);
    }
  });

  it("reads the flag from the Claude Code user settings env block", () => {
    writeUserSettings({ env: { CLAUDE_CODE_USE_BEDROCK: "1" } });
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(true);
  });

  it("stays enabled when the settings file opts in and the environment does not", () => {
    writeUserSettings({ env: { CLAUDE_CODE_USE_BEDROCK: "1" } });
    expect(
      isClaudeBedrockModeEnabled({
        CLAUDE_CONFIG_DIR: configDir,
        CLAUDE_CODE_USE_BEDROCK: "0",
      }),
    ).toBe(true);
  });

  it("ignores settings without an enabled Bedrock flag", () => {
    writeUserSettings({ env: { AWS_REGION: "us-west-2" }, model: "opus" });
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);

    writeUserSettings({ env: { CLAUDE_CODE_USE_BEDROCK: "0" } });
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
  });

  it("ignores unreadable or malformed settings files", () => {
    expect(
      isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: join(configDir, "missing") }),
    ).toBe(false);

    writeFileSync(join(configDir, "settings.json"), "{ not json");
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
  });

  it("ignores settings whose root or env block is not an object", () => {
    for (const settings of [null, "CLAUDE_CODE_USE_BEDROCK", 1, {}, { env: null }, { env: "1" }, { env: { CLAUDE_CODE_USE_BEDROCK: 1 } }]) {
      writeUserSettings(settings);
      expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
    }
  });

  it("trims CLAUDE_CONFIG_DIR before locating the settings file", () => {
    writeUserSettings({ env: { CLAUDE_CODE_USE_BEDROCK: "1" } });
    expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: ` ${configDir}\n` })).toBe(true);
  });

  it("falls back to ~/.claude/settings.json without a config directory", () => {
    // os.homedir() follows HOME (USERPROFILE on Windows).
    vi.stubEnv("HOME", configDir);
    vi.stubEnv("USERPROFILE", configDir);
    try {
      expect(isClaudeBedrockModeEnabled({})).toBe(false);
      mkdirSync(join(configDir, ".claude"));
      writeFileSync(
        join(configDir, ".claude", "settings.json"),
        JSON.stringify({ env: { CLAUDE_CODE_USE_BEDROCK: "1" } }),
      );
      // A settings file directly in the home directory is not the user settings.
      writeUserSettings({ env: { CLAUDE_CODE_USE_VERTEX: "1" } });
      expect(isClaudeBedrockModeEnabled({})).toBe(true);
      expect(isClaudeBedrockModeEnabled({ CLAUDE_CONFIG_DIR: "   " })).toBe(true);
      expect(isClaudeVertexModeEnabled({})).toBe(false);
    } finally {
      vi.unstubAllEnvs();
    }
  });

  it("detects AWS_REGION from the process environment or user settings", () => {
    expect(
      isClaudeBedrockRegionConfigured({
        CLAUDE_CONFIG_DIR: configDir,
        AWS_REGION: "us-west-2",
      }),
    ).toBe(true);

    writeUserSettings({ env: { AWS_REGION: "us-east-1" } });
    expect(
      isClaudeBedrockRegionConfigured({
        CLAUDE_CONFIG_DIR: configDir,
        AWS_REGION: "",
      }),
    ).toBe(true);
  });

  it("rejects an empty or missing AWS_REGION", () => {
    expect(isClaudeBedrockRegionConfigured({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
    expect(
      isClaudeBedrockRegionConfigured({
        CLAUDE_CONFIG_DIR: configDir,
        AWS_REGION: "  ",
      }),
    ).toBe(false);
  });
});

describe("isClaudeVertexModeEnabled", () => {
  let configDir: string;

  beforeEach(() => {
    configDir = mkdtempSync(join(tmpdir(), "ccpocket-claude-vertex-"));
  });

  afterEach(() => {
    rmSync(configDir, { recursive: true, force: true });
  });

  function writeUserSettings(settings: unknown): void {
    writeFileSync(join(configDir, "settings.json"), JSON.stringify(settings));
  }

  it("is disabled when nothing is configured", () => {
    expect(isClaudeVertexModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
  });

  it("accepts the environment values Claude Code treats as enabled", () => {
    for (const value of ["1", "true", "TRUE", "yes", "on", " 1 "]) {
      expect(
        isClaudeVertexModeEnabled({
          CLAUDE_CONFIG_DIR: configDir,
          CLAUDE_CODE_USE_VERTEX: value,
        }),
      ).toBe(true);
    }
  });

  it("rejects environment values Claude Code treats as disabled", () => {
    for (const value of ["", "0", "false", "no", "off", "vertex"]) {
      expect(
        isClaudeVertexModeEnabled({
          CLAUDE_CONFIG_DIR: configDir,
          CLAUDE_CODE_USE_VERTEX: value,
        }),
      ).toBe(false);
    }
  });

  it("reads the flag from the Claude Code user settings env block", () => {
    writeUserSettings({ env: { CLAUDE_CODE_USE_VERTEX: "1" } });
    expect(isClaudeVertexModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(true);
  });

  it("stays enabled when the settings file opts in and the environment does not", () => {
    writeUserSettings({ env: { CLAUDE_CODE_USE_VERTEX: "1" } });
    expect(
      isClaudeVertexModeEnabled({
        CLAUDE_CONFIG_DIR: configDir,
        CLAUDE_CODE_USE_VERTEX: "0",
      }),
    ).toBe(true);
  });

  it("keeps the Bedrock and Vertex flags independent", () => {
    expect(
      isClaudeVertexModeEnabled({
        CLAUDE_CONFIG_DIR: configDir,
        CLAUDE_CODE_USE_BEDROCK: "1",
      }),
    ).toBe(false);
    expect(
      isClaudeBedrockModeEnabled({
        CLAUDE_CONFIG_DIR: configDir,
        CLAUDE_CODE_USE_VERTEX: "1",
      }),
    ).toBe(false);
  });

  it("ignores unreadable or malformed settings files", () => {
    expect(
      isClaudeVertexModeEnabled({ CLAUDE_CONFIG_DIR: join(configDir, "missing") }),
    ).toBe(false);

    writeFileSync(join(configDir, "settings.json"), "{ not json");
    expect(isClaudeVertexModeEnabled({ CLAUDE_CONFIG_DIR: configDir })).toBe(false);
  });
});
