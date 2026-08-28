import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { isClaudeBedrockModeEnabled } from "./claude-provider.js";

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
});
