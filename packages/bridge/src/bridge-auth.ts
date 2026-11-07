import { createHash, timingSafeEqual } from "node:crypto";
import type { IncomingMessage } from "node:http";

/**
 * Compare a client-supplied token with the configured API key in constant
 * time. Both values are hashed first so differing lengths do not leak through
 * an early return.
 */
export function tokensMatch(
  provided: string | null | undefined,
  expected: string,
): boolean {
  if (typeof provided !== "string") return false;
  const a = createHash("sha256").update(provided).digest();
  const b = createHash("sha256").update(expected).digest();
  return timingSafeEqual(a, b);
}

const LOOPBACK_ADDRESSES = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);
const LOOPBACK_HOSTNAMES = new Set(["localhost", "127.0.0.1", "[::1]", "::1"]);

function hostnameOf(hostHeader: string): string {
  // "[::1]:8765" -> "[::1]", "localhost:8765" -> "localhost"
  if (hostHeader.startsWith("[")) {
    const end = hostHeader.indexOf("]");
    return end === -1 ? hostHeader : hostHeader.slice(0, end + 1);
  }
  const colon = hostHeader.indexOf(":");
  return (colon === -1 ? hostHeader : hostHeader.slice(0, colon)).toLowerCase();
}

/**
 * Whether a request may read pairing secrets (`GET /pairing`).
 *
 * The request must come from the loopback interface, address the Bridge by a
 * loopback host name (blocks DNS rebinding through a browser), and carry no
 * `Origin` header (browsers always send one for cross-origin fetches, so web
 * pages cannot read the token).
 */
export function isLocalPairingRequest(req: IncomingMessage): boolean {
  const remote = req.socket.remoteAddress;
  if (!remote || !LOOPBACK_ADDRESSES.has(remote)) return false;
  const host = req.headers.host;
  if (!host || !LOOPBACK_HOSTNAMES.has(hostnameOf(host))) return false;
  if (req.headers.origin !== undefined) return false;
  return true;
}
