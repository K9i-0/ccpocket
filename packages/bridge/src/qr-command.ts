import {
  PAIRING_SECRET_HEADER,
  pairingSecretPath,
  readPairingSecret,
} from "./bridge-auth.js";
import { printPairingInfo, type PairingConnection } from "./startup-info.js";

export interface PairingResponse {
  auth: "required" | "none";
  connections: PairingConnection[];
  wsUrl: string | null;
  deepLink: string | null;
  token: string | null;
}

export type FetchPairingResult =
  | { ok: true; pairing: PairingResponse }
  | { ok: false; message: string };

/** Fetch pairing info from a Bridge running on this machine. */
export async function fetchLocalPairing(
  port: number,
  fetchImpl: typeof fetch = fetch,
  readSecret: () => Promise<string | null> = () =>
    readPairingSecret(pairingSecretPath(port)),
): Promise<FetchPairingResult> {
  const secret = await readSecret();
  if (!secret) {
    return {
      ok: false,
      message:
        "No pairing secret found in ~/.ccpocket. Run this command as the user that runs the Bridge, after restarting it with the latest version.",
    };
  }

  let response: Response;
  try {
    response = await fetchImpl(`http://127.0.0.1:${port}/pairing`, {
      headers: { [PAIRING_SECRET_HEADER]: secret },
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    return {
      ok: false,
      message:
        `No Bridge is responding on port ${port}. Start it first, or pass --port <port>.`,
    };
  }

  if (response.status === 404) {
    return {
      ok: false,
      message:
        "The running Bridge is too old to report pairing info. Restart it with the latest version and try again.",
    };
  }
  if (response.status === 403) {
    return {
      ok: false,
      message:
        "The running Bridge rejected the pairing secret. Run this command as the user that runs the Bridge, or restart the Bridge if another Bridge was started since.",
    };
  }
  if (!response.ok) {
    return {
      ok: false,
      message: `The running Bridge refused the pairing request (HTTP ${response.status}).`,
    };
  }

  try {
    return { ok: true, pairing: (await response.json()) as PairingResponse };
  } catch {
    return { ok: false, message: "The running Bridge returned invalid pairing info." };
  }
}

export async function runQrCommand(port: number): Promise<number> {
  const result = await fetchLocalPairing(port);
  if (!result.ok) {
    console.error(`ERROR: ${result.message}`);
    return 1;
  }

  const { pairing } = result;
  if (!pairing.deepLink) {
    console.error(
      "ERROR: No reachable network address found. Connect to a LAN or Tailscale, or set BRIDGE_PUBLIC_WS_URL.",
    );
    return 1;
  }

  await printPairingInfo({
    auth: pairing.auth,
    connections: pairing.connections,
    wsUrl: pairing.wsUrl ?? undefined,
    deepLink: pairing.deepLink,
    demoMode: false,
  });

  if (pairing.auth === "none") {
    console.warn(
      "[bridge] WARNING: this Bridge has no API key. Anyone who can reach it can control your agents.",
    );
  }
  return 0;
}
