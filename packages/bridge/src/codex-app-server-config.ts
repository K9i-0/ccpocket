const DEFAULT_CODEX_APP_SERVER_PORT = "8767";
const FALLBACK_CODEX_APP_SERVER_PORT = "8768";

export function defaultCodexAppServerPort(bridgePort?: string): string {
  return bridgePort?.trim() === DEFAULT_CODEX_APP_SERVER_PORT
    ? FALLBACK_CODEX_APP_SERVER_PORT
    : DEFAULT_CODEX_APP_SERVER_PORT;
}
