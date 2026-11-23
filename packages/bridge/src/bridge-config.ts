import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { DEFAULT_BRIDGE_PORT, parseBridgePort } from "./bridge-port.js";
import { validatePublicWsUrl } from "./startup-info.js";

/**
 * Persisted Bridge settings (`~/.ccpocket/bridge-config.json`).
 *
 * Every setting is still read from an environment variable by the rest of the
 * Bridge. At startup the file fills in the variables that are not set, so the
 * precedence is: CLI flag > environment variable > config file > default.
 * See docs/design/local-bridge-management.md.
 */
export const BRIDGE_CONFIG_VERSION = 1;

export type BridgeSettingType =
  | "port"
  | "string"
  | "wsUrl"
  | "boolean"
  | "dirs"
  | "enum"
  | "secret";

export type BridgeSettingValue = string | number | boolean | string[];
export type BridgeSettings = Record<string, BridgeSettingValue>;
export type BridgeSettingSource = "env" | "file" | "default";

export interface BridgeSettingDefinition {
  key: string;
  env: string;
  type: BridgeSettingType;
  /** Allowed values of an `enum` setting. */
  values?: readonly string[];
  /** Env value that means `true` for a `boolean` setting (default `"1"`). */
  trueValue?: string;
}

export const BRIDGE_SETTINGS: readonly BridgeSettingDefinition[] = [
  { key: "port", env: "BRIDGE_PORT", type: "port" },
  { key: "host", env: "BRIDGE_HOST", type: "string" },
  { key: "publicWsUrl", env: "BRIDGE_PUBLIC_WS_URL", type: "wsUrl" },
  { key: "allowedDirs", env: "BRIDGE_ALLOWED_DIRS", type: "dirs" },
  { key: "readOnlyDirs", env: "BRIDGE_READONLY_DIRS", type: "dirs" },
  {
    key: "fileDownloadAllowAllPaths",
    env: "BRIDGE_FILE_DOWNLOAD_ALLOW_ALL_PATHS",
    type: "boolean",
  },
  { key: "insecureNoAuth", env: "BRIDGE_INSECURE_NO_AUTH", type: "boolean" },
  {
    key: "allowClaudeOAuth",
    env: "BRIDGE_ALLOW_CLAUDE_OAUTH",
    type: "boolean",
  },
  {
    key: "codexAppServerMode",
    env: "BRIDGE_CODEX_APP_SERVER_MODE",
    type: "enum",
    values: ["private", "managed", "external"],
  },
  {
    key: "codexSharedAppServerUrl",
    env: "BRIDGE_CODEX_SHARED_APP_SERVER_URL",
    type: "wsUrl",
  },
  { key: "codexAssistModel", env: "BRIDGE_CODEX_ASSIST_MODEL", type: "string" },
  {
    key: "codexAssistReasoningEffort",
    env: "BRIDGE_CODEX_ASSIST_REASONING_EFFORT",
    type: "string",
  },
  {
    key: "notifyGoalTurnCompleted",
    env: "BRIDGE_NOTIFY_GOAL_TURN_COMPLETED",
    type: "boolean",
    trueValue: "true",
  },
  {
    key: "antigravityApiKey",
    env: "CCPOCKET_ANTIGRAVITY_API_KEY",
    type: "secret",
  },
];

const SETTINGS_BY_KEY = new Map(BRIDGE_SETTINGS.map((def) => [def.key, def]));

/** `BRIDGE_CONFIG_FILE` overrides the path (tests, extra Bridges). */
export function bridgeConfigPath(
  env: NodeJS.ProcessEnv = process.env,
  home = homedir(),
): string {
  return (
    env.BRIDGE_CONFIG_FILE?.trim() ||
    join(home, ".ccpocket", "bridge-config.json")
  );
}

function normalizeValue(
  def: BridgeSettingDefinition,
  value: unknown,
): BridgeSettingValue {
  switch (def.type) {
    case "port": {
      if (typeof value !== "number" && typeof value !== "string") {
        throw new Error("expected a port number");
      }
      return parseBridgePort(String(value));
    }
    case "boolean":
      if (typeof value !== "boolean") throw new Error("expected true or false");
      return value;
    case "dirs": {
      if (
        !Array.isArray(value) ||
        value.some((dir) => typeof dir !== "string")
      ) {
        throw new Error("expected a list of paths");
      }
      const dirs = value.map((dir) => (dir as string).trim()).filter(Boolean);
      if (dirs.length === 0) throw new Error("expected at least one path");
      if (dirs.includes("*") && dirs.length > 1) {
        throw new Error('expected either ["*"] or a list of paths');
      }
      if (def.key !== "allowedDirs" && dirs.includes("*")) {
        throw new Error('"*" is only valid for allowedDirs');
      }
      // The env format separates paths with commas.
      if (dirs.some((dir) => dir.includes(","))) {
        throw new Error("paths must not contain a comma");
      }
      return dirs;
    }
    case "enum":
      if (typeof value !== "string" || !def.values?.includes(value)) {
        throw new Error(`expected one of: ${def.values?.join(", ")}`);
      }
      return value;
    case "wsUrl": {
      if (typeof value !== "string" || !validatePublicWsUrl(value)) {
        throw new Error("expected a ws:// or wss:// URL");
      }
      return value.trim();
    }
    case "string":
    case "secret": {
      if (typeof value !== "string" || !value.trim()) {
        throw new Error("expected a non-empty string");
      }
      if (/[\r\n]/.test(value)) throw new Error("must be a single line");
      return value.trim();
    }
  }
}

export interface SettingsValidation {
  settings: BridgeSettings;
  /** Setting key -> problem. Invalid and unknown settings are dropped. */
  errors: Record<string, string>;
}

/** Validate settings from a file or a request; `null` values are dropped. */
export function validateBridgeSettings(input: unknown): SettingsValidation {
  const settings: BridgeSettings = {};
  const errors: Record<string, string> = {};
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    return { settings, errors: { settings: "expected an object" } };
  }
  for (const [key, value] of Object.entries(input)) {
    const def = SETTINGS_BY_KEY.get(key);
    if (!def) {
      errors[key] = "unknown setting";
      continue;
    }
    if (value === null || value === undefined) continue;
    try {
      settings[key] = normalizeValue(def, value);
    } catch (err) {
      errors[key] = err instanceof Error ? err.message : String(err);
    }
  }
  return { settings, errors };
}

export interface LoadedBridgeConfig {
  settings: BridgeSettings;
  /** Problems that made the Bridge ignore a setting or the whole file. */
  warnings: string[];
}

/** Read the config file. A missing file is an empty config. */
export async function readBridgeConfigFile(
  path = bridgeConfigPath(),
): Promise<LoadedBridgeConfig> {
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      return { settings: {}, warnings: [] };
    }
    return { settings: {}, warnings: [`Could not read ${path}: ${String(err)}`] };
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { settings: {}, warnings: [`${path} is not valid JSON; ignored`] };
  }
  const body =
    parsed !== null && typeof parsed === "object"
      ? (parsed as { settings?: unknown }).settings ?? {}
      : null;
  const { settings, errors } = validateBridgeSettings(body);
  return {
    settings,
    warnings: Object.entries(errors).map(
      ([key, problem]) => `${path}: ignoring "${key}" (${problem})`,
    ),
  };
}

/** Write the config file atomically, readable only by the Bridge's user. */
export async function writeBridgeConfigFile(
  settings: BridgeSettings,
  path = bridgeConfigPath(),
): Promise<void> {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  const tmp = `${path}.${process.pid}.tmp`;
  const body = JSON.stringify(
    { version: BRIDGE_CONFIG_VERSION, settings },
    null,
    2,
  );
  await writeFile(tmp, `${body}\n`, { mode: 0o600 });
  await chmod(tmp, 0o600);
  await rename(tmp, path);
}

function toEnvValue(
  def: BridgeSettingDefinition,
  value: BridgeSettingValue,
): string | undefined {
  if (def.type === "boolean") {
    // `false` is the default of every boolean setting: leave the variable unset.
    return value === true ? def.trueValue ?? "1" : undefined;
  }
  if (Array.isArray(value)) return value.join(",");
  return String(value);
}

function fromEnvValue(
  def: BridgeSettingDefinition,
  raw: string,
): BridgeSettingValue {
  switch (def.type) {
    case "port": {
      const port = Number(raw.trim());
      return Number.isSafeInteger(port) ? port : raw;
    }
    case "boolean":
      return raw === (def.trueValue ?? "1");
    case "dirs":
      return raw.split(",").map((dir) => dir.trim()).filter(Boolean);
    default:
      return raw.trim();
  }
}

function defaultValue(
  def: BridgeSettingDefinition,
  home: string,
): BridgeSettingValue | null {
  switch (def.key) {
    case "port":
      return DEFAULT_BRIDGE_PORT;
    case "host":
      return "0.0.0.0";
    case "allowedDirs":
      return [home];
    case "codexAppServerMode":
      return "private";
    default:
      return def.type === "boolean" ? false : null;
  }
}

export interface AppliedBridgeSetting {
  /** Value the running Bridge uses; `null` when unset without a default. */
  value: BridgeSettingValue | null;
  source: BridgeSettingSource;
}

/** What the Bridge resolved at startup. Captured once, before env is consumed. */
export interface AppliedBridgeConfig {
  /** File settings as they were at startup. */
  fileSettings: BridgeSettings;
  settings: Record<string, AppliedBridgeSetting>;
}

/**
 * Fill unset environment variables from [fileSettings] and record where each
 * setting came from. Variables that are already set (shell, service
 * definition, CLI flag) win over the file.
 */
export function applyBridgeConfig(
  fileSettings: BridgeSettings,
  env: NodeJS.ProcessEnv = process.env,
  home = homedir(),
): AppliedBridgeConfig {
  const settings: Record<string, AppliedBridgeSetting> = {};
  for (const def of BRIDGE_SETTINGS) {
    const fromEnv = env[def.env];
    if (fromEnv !== undefined && fromEnv.trim() !== "") {
      settings[def.key] = { value: fromEnvValue(def, fromEnv), source: "env" };
      continue;
    }
    const fromFile = fileSettings[def.key];
    if (fromFile !== undefined) {
      const envValue = toEnvValue(def, fromFile);
      if (envValue !== undefined) env[def.env] = envValue;
      settings[def.key] = { value: fromFile, source: "file" };
      continue;
    }
    settings[def.key] = { value: defaultValue(def, home), source: "default" };
  }
  return { fileSettings: { ...fileSettings }, settings };
}

export interface BridgeConfigSettingView {
  key: string;
  env: string;
  type: BridgeSettingType;
  values?: readonly string[];
  /** Value in use. Secrets are never returned: see [configured]. */
  value: BridgeSettingValue | null;
  source: BridgeSettingSource;
  /** Value saved in the config file; applies after a restart unless env wins. */
  fileValue: BridgeSettingValue | null;
  /** `secret` settings only: whether a value is in use / saved. */
  configured?: boolean;
  fileConfigured?: boolean;
}

export interface BridgeConfigView {
  version: number;
  path: string;
  settings: BridgeConfigSettingView[];
  /** The saved file differs from what the running Bridge loaded. */
  restartRequired: boolean;
}

function sameValue(
  a: BridgeSettingValue | undefined,
  b: BridgeSettingValue | undefined,
): boolean {
  return JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
}

/** Report for `GET /admin/config`: running values next to the saved file. */
export function describeBridgeConfig(
  applied: AppliedBridgeConfig,
  currentFileSettings: BridgeSettings,
  path = bridgeConfigPath(),
): BridgeConfigView {
  let restartRequired = false;
  const settings = BRIDGE_SETTINGS.map((def): BridgeConfigSettingView => {
    const running = applied.settings[def.key];
    const saved = currentFileSettings[def.key];
    // A changed file value only matters when env does not override it.
    if (
      running.source !== "env" &&
      !sameValue(applied.fileSettings[def.key], saved)
    ) {
      restartRequired = true;
    }
    const base = {
      key: def.key,
      env: def.env,
      type: def.type,
      ...(def.values ? { values: def.values } : {}),
      source: running.source,
    };
    if (def.type === "secret") {
      return {
        ...base,
        value: null,
        fileValue: null,
        configured: running.value !== null,
        fileConfigured: saved !== undefined,
      };
    }
    return { ...base, value: running.value, fileValue: saved ?? null };
  });
  return { version: BRIDGE_CONFIG_VERSION, path, settings, restartRequired };
}

export type BridgeConfigUpdate =
  | { ok: true; settings: BridgeSettings }
  | { ok: false; errors: Record<string, string> };

/**
 * Merge a partial update into the saved settings. `null` removes a setting
 * (back to env or default). Nothing is written when any value is invalid.
 */
export function mergeBridgeSettings(
  current: BridgeSettings,
  patch: unknown,
): BridgeConfigUpdate {
  const { settings, errors } = validateBridgeSettings(patch);
  if (Object.keys(errors).length > 0) return { ok: false, errors };
  const merged = { ...current, ...settings };
  for (const [key, value] of Object.entries(patch as Record<string, unknown>)) {
    if (value === null) delete merged[key];
  }
  if (
    merged.codexAppServerMode === "external" &&
    !merged.codexSharedAppServerUrl
  ) {
    return {
      ok: false,
      errors: {
        codexSharedAppServerUrl:
          "required when codexAppServerMode is external",
      },
    };
  }
  return { ok: true, settings: merged };
}
