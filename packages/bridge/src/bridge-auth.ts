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

/** Persisted API key used when none is configured explicitly. */
export function apiKeyPath(home = homedir()): string {
  return join(home, ".ccpocket", "bridge-api-key");
}

export type ApiKeySource = "configured" | "stored" | "generated" | "disabled";

export interface ResolvedApiKey {
  apiKey?: string;
  source: ApiKeySource;
}

/**
 * Decide which API key the Bridge requires.
 *
 * An explicit key (`BRIDGE_API_KEY` / `--api-key`) wins. Otherwise the key in
 * [path] is reused, or a new random key is generated and stored there with
 * mode `0600`, so plain `npx` runs and background services keep a stable key
 * across restarts. Authentication is disabled only when [insecureNoAuth] is
 * set explicitly.
 */
export async function resolveApiKey(opts: {
  configured?: string;
  insecureNoAuth: boolean;
  path?: string;
}): Promise<ResolvedApiKey> {
  const configured = opts.configured?.trim();
  if (configured) return { apiKey: configured, source: "configured" };
  if (opts.insecureNoAuth) return { source: "disabled" };

  const path = opts.path ?? apiKeyPath();
  const stored = await readPairingSecret(path);
  if (stored) return { apiKey: stored, source: "stored" };

  const apiKey = randomBytes(24).toString("base64url");
  await mkdir(join(path, ".."), { recursive: true, mode: 0o700 });
  // "wx" fails if another Bridge created the file meanwhile; reuse its key.
  try {
    await writeFile(path, `${apiKey}\n`, { mode: 0o600, flag: "wx" });
  } catch (err) {
    const raced = await readPairingSecret(path);
    if (raced) return { apiKey: raced, source: "stored" };
    throw err;
  }
  return { apiKey, source: "generated" };
}

/** Bearer token from an `Authorization` header, if any. */
export function bearerToken(req: IncomingMessage): string | null {
  const header = req.headers.authorization;
  if (typeof header !== "string") return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/**
 * HTTP endpoints that expose account data or change state and therefore
 * require the API key. `/health` and `/version` stay public for probing;
 * image, media and upload URLs are capability URLs with unguessable IDs.
 */
export function httpRouteRequiresAuth(
  method: string | undefined,
  rawUrl: string | undefined,
): boolean {
  const pathname = new URL(rawUrl ?? "/", "http://localhost").pathname;
  if (method === "GET" && (pathname === "/usage" || pathname === "/doctor")) {
    return true;
  }
  if (method === "POST" && pathname === "/api/gallery/upload") return true;
  if (method === "DELETE" && pathname.startsWith("/api/gallery/")) return true;
  return false;
}

/** Whether an HTTP request may use a route protected by [apiKey]. */
export function isAuthorizedHttpRequest(
  req: IncomingMessage,
  apiKey: string | undefined,
): boolean {
  if (!apiKey) return true;
  if (!httpRouteRequiresAuth(req.method, req.url)) return true;
  return tokensMatch(bearerToken(req), apiKey);
}
