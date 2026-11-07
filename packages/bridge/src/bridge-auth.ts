import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { chmod, mkdir, readFile, writeFile } from "node:fs/promises";
import type { IncomingMessage } from "node:http";
import { homedir } from "node:os";
import { join } from "node:path";

/** Header carrying the pairing secret for `GET /pairing`. */
export const PAIRING_SECRET_HEADER = "x-ccpocket-pairing-secret";

/** One file per port so several Bridges on one machine do not clash. */
export function pairingSecretPath(port: number, home = homedir()): string {
  return join(home, ".ccpocket", `pairing-secret-${port}`);
}

/**
 * Create a fresh per-start pairing secret readable only by the Bridge's user.
 * `/pairing` requires it, so other local users (shared Linux hosts) cannot read
 * the API key even though they can reach 127.0.0.1.
 */
export async function writePairingSecret(path: string): Promise<string> {
  const secret = randomBytes(32).toString("hex");
  await mkdir(join(path, ".."), { recursive: true, mode: 0o700 });
  await writeFile(path, `${secret}\n`, { mode: 0o600 });
  // writeFile keeps the mode of an existing file; enforce it.
  await chmod(path, 0o600);
  return secret;
}

export async function readPairingSecret(
  path: string,
): Promise<string | null> {
  try {
    const secret = (await readFile(path, "utf8")).trim();
    return secret || null;
  } catch {
    return null;
  }
}

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
 * The request must present the per-start pairing secret (readable only by the
 * Bridge's OS user), come from the loopback interface, address the Bridge by a
 * loopback host name (blocks DNS rebinding through a browser), and carry no
 * `Origin` header (browsers always send one for cross-origin fetches, so web
 * pages cannot read the token).
 */
export function isLocalPairingRequest(
  req: IncomingMessage,
  pairingSecret: string | null,
): boolean {
  if (!pairingSecret) return false;
  const provided = req.headers[PAIRING_SECRET_HEADER];
  if (typeof provided !== "string" || !tokensMatch(provided, pairingSecret)) {
    return false;
  }
  const remote = req.socket.remoteAddress;
  if (!remote || !LOOPBACK_ADDRESSES.has(remote)) return false;
  const host = req.headers.host;
  if (!host || !LOOPBACK_HOSTNAMES.has(hostnameOf(host))) return false;
  if (req.headers.origin !== undefined) return false;
  return true;
}
