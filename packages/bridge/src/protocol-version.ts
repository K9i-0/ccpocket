export const BRIDGE_PROTOCOL_MIN_VERSION = 1;
export const BRIDGE_PROTOCOL_MAX_VERSION = 1;
export const LEGACY_PROTOCOL_VERSION = 1;

export interface ProtocolRange {
  min: number;
  max: number;
}

export interface ClientProtocolDeclaration {
  protocolVersion?: number;
  minimumProtocolVersion?: number;
}

/**
 * Resolve the range advertised by a client.
 *
 * Clients released before range negotiation either sent a singular
 * `protocolVersion` or omitted protocol metadata entirely. Both forms are
 * treated as supporting exactly one protocol version.
 */
export function clientProtocolRange(
  declaration: ClientProtocolDeclaration,
): ProtocolRange {
  const max = declaration.protocolVersion ?? LEGACY_PROTOCOL_VERSION;
  const min = declaration.minimumProtocolVersion ?? max;
  return { min, max };
}

/** Select the highest protocol version supported by both peers. */
export function negotiateProtocolVersion(
  client: ProtocolRange,
  server: ProtocolRange = {
    min: BRIDGE_PROTOCOL_MIN_VERSION,
    max: BRIDGE_PROTOCOL_MAX_VERSION,
  },
): number | null {
  const lowerBound = Math.max(client.min, server.min);
  const upperBound = Math.min(client.max, server.max);
  return lowerBound <= upperBound ? upperBound : null;
}
