const DEFAULT_CODEX_APP_SERVER_PORT = "8767";
const FALLBACK_CODEX_APP_SERVER_PORT = "8768";
const DEFAULT_CODEX_CLI_AUTH_TOKEN_ENV = "CODEX_REMOTE_TOKEN";
const ENVIRONMENT_VARIABLE_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

import type { CodexCliJoinTarget } from "./parser.js";

export type CodexAppServerMode =
  | "private"
  | "managed"
  | "external"
  | "isolated";

export function defaultCodexAppServerPort(bridgePort?: string): string {
  return bridgePort?.trim() === DEFAULT_CODEX_APP_SERVER_PORT
    ? FALLBACK_CODEX_APP_SERVER_PORT
    : DEFAULT_CODEX_APP_SERVER_PORT;
}

export function defaultCodexSharedAppServerUrl(bridgePort?: string): string {
  return `ws://127.0.0.1:${defaultCodexAppServerPort(bridgePort)}`;
}

export function readCodexSharedAppServerUrl(
  env: NodeJS.ProcessEnv = process.env,
): string | undefined {
  return (
    env.BRIDGE_CODEX_SHARED_APP_SERVER_URL?.trim() ||
    env.BRIDGE_CODEX_APP_SERVER_URL?.trim() ||
    undefined
  );
}

export function readCodexAppServerMode(
  env: NodeJS.ProcessEnv = process.env,
): CodexAppServerMode {
  const raw = env.BRIDGE_CODEX_APP_SERVER_MODE;
  if (raw === "managed" || raw === "external" || raw === "isolated") {
    return raw;
  }
  return "private";
}

export function resolveCodexSharedAppServerUrl(
  mode: CodexAppServerMode,
  env: NodeJS.ProcessEnv = process.env,
): string | undefined {
  if (mode === "isolated") return undefined;

  const explicit = readCodexSharedAppServerUrl(env);
  if (explicit) return explicit;
  if (mode !== "managed") return undefined;

  const legacyPort = env.BRIDGE_CODEX_APP_SERVER_PORT?.trim();
  if (legacyPort) return `ws://127.0.0.1:${legacyPort}`;

  return defaultCodexSharedAppServerUrl(env.BRIDGE_PORT);
}

function readValidatedEnvironmentVariableName(
  value: string | undefined,
  key: string,
): string {
  const name = value?.trim();
  if (!name || !ENVIRONMENT_VARIABLE_NAME.test(name)) {
    throw new Error(`${key} must be a valid environment-variable name`);
  }
  return name;
}

export function readExternalCodexAuthToken(
  env: NodeJS.ProcessEnv = process.env,
): { token: string; envName: string } {
  const envName = readValidatedEnvironmentVariableName(
    env.BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV,
    "BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV",
  );
  const token = env[envName];
  if (!token?.trim()) {
    throw new Error(
      `BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV points to ${envName}, but it is empty or unset`,
    );
  }
  return { token, envName };
}

function readCodexCliAuthTokenEnv(
  mode: CodexAppServerMode,
  env: NodeJS.ProcessEnv,
): string {
  if (mode === "external") return readExternalCodexAuthToken(env).envName;
  return readValidatedEnvironmentVariableName(
    env.BRIDGE_CODEX_CLI_AUTH_TOKEN_ENV ?? DEFAULT_CODEX_CLI_AUTH_TOKEN_ENV,
    "BRIDGE_CODEX_CLI_AUTH_TOKEN_ENV",
  );
}

export function codexCliJoinTarget(
  threadId: string,
  env: NodeJS.ProcessEnv = process.env,
): CodexCliJoinTarget | undefined {
  const mode = readCodexAppServerMode(env);
  if (mode === "private" || mode === "isolated") return undefined;

  const url = resolveCodexSharedAppServerUrl(mode, env);
  if (!url) return undefined;
  const remoteAuthTokenEnv = readCodexCliAuthTokenEnv(mode, env);

  return {
    url,
    command: `codex resume ${threadId} --remote ${url} --remote-auth-token-env ${remoteAuthTokenEnv}`,
    remoteAuthTokenEnv,
  };
}
