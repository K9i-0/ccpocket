const DEFAULT_CODEX_APP_SERVER_PORT = "8767";
const FALLBACK_CODEX_APP_SERVER_PORT = "8768";

export type CodexAppServerMode = "private" | "managed" | "external";

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
  if (raw === "managed" || raw === "external") return raw;
  return "private";
}

export function resolveCodexSharedAppServerUrl(
  mode: CodexAppServerMode,
  env: NodeJS.ProcessEnv = process.env,
): string | undefined {
  const explicit = readCodexSharedAppServerUrl(env);
  if (explicit) return explicit;
  if (mode !== "managed") return undefined;

  const legacyPort = env.BRIDGE_CODEX_APP_SERVER_PORT?.trim();
  if (legacyPort) return `ws://127.0.0.1:${legacyPort}`;

  return defaultCodexSharedAppServerUrl(env.BRIDGE_PORT);
}

export function codexCliJoinTarget(
  threadId: string,
  env: NodeJS.ProcessEnv = process.env,
): { url: string; command: string } | undefined {
  const mode = readCodexAppServerMode(env);
  if (mode === "private") return undefined;

  const url = resolveCodexSharedAppServerUrl(mode, env);
  if (!url) return undefined;

  return {
    url,
    command: `codex resume ${threadId} --remote ${url}`,
  };
}
