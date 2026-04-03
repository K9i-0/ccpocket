import { existsSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";

export interface Config {
  bridgeUrl?: string;
  remoteBridgeUrl?: string;
  defaultProvider: "claude" | "codex";
  defaultPermissionMode: "default" | "acceptEdits" | "bypassPermissions" | "plan";
}

const CONFIG_PATH = join(homedir(), ".ccpocket", "config.json");

const DEFAULTS: Config = {
  defaultProvider: "claude",
  defaultPermissionMode: "default",
};

export function loadConfig(): Config {
  try {
    if (!existsSync(CONFIG_PATH)) return { ...DEFAULTS };
    const raw = readFileSync(CONFIG_PATH, "utf-8");
    const parsed = JSON.parse(raw) as Partial<Config>;
    return { ...DEFAULTS, ...parsed };
  } catch {
    return { ...DEFAULTS };
  }
}

export function saveConfig(config: Partial<Config>): void {
  const existing = loadConfig();
  const merged = { ...existing, ...config };
  const dir = dirname(CONFIG_PATH);
  mkdirSync(dir, { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(merged, null, 2) + "\n", "utf-8");
}

export function getConfigPath(): string {
  return CONFIG_PATH;
}
