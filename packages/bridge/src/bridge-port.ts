export const DEFAULT_BRIDGE_PORT = 8765;

const MIN_BRIDGE_PORT = 1;
const MAX_BRIDGE_PORT = 65535;

function invalidBridgePortMessage(rawPort: string): string {
  return `Invalid BRIDGE_PORT "${rawPort}": expected an integer between ${MIN_BRIDGE_PORT} and ${MAX_BRIDGE_PORT}.`;
}

export function parseBridgePort(
  rawPort = process.env.BRIDGE_PORT ?? String(DEFAULT_BRIDGE_PORT),
): number {
  const normalized = rawPort.trim();
  if (!/^\d+$/.test(normalized)) {
    throw new Error(invalidBridgePortMessage(rawPort));
  }

  const port = Number(normalized);
  if (
    !Number.isSafeInteger(port) ||
    port < MIN_BRIDGE_PORT ||
    port > MAX_BRIDGE_PORT
  ) {
    throw new Error(invalidBridgePortMessage(rawPort));
  }
  return port;
}
