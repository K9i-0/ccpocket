const DEFAULT_CODEX_APP_SERVER_PORT = "8767";
const FALLBACK_CODEX_APP_SERVER_PORT = "8768";

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
