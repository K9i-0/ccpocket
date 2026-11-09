import os from "node:os";
import QRCode from "qrcode";

interface NetworkAddress {
  ip: string;
  label: string;
}

export function validatePublicWsUrl(rawUrl?: string): string | undefined {
  const trimmed = rawUrl?.trim();
  if (!trimmed) return undefined;

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return undefined;
  }

  if ((parsed.protocol !== "ws:" && parsed.protocol !== "wss:") || !parsed.host) {
    return undefined;
  }

  return trimmed;
}

export function getReachableAddresses(): NetworkAddress[] {
  const interfaces = os.networkInterfaces();
  const addresses: NetworkAddress[] = [];

  for (const [name, ifaces] of Object.entries(interfaces)) {
    if (!ifaces) continue;
    for (const iface of ifaces) {
      if (iface.family !== "IPv4" || iface.internal) continue;
      // Link-local (APIPA) addresses are not reachable from other devices.
      if (iface.address.startsWith("169.254.")) continue;

      let label = "LAN";
      if (
        iface.address.startsWith("100.") ||
        name.startsWith("utun") ||
        name.toLowerCase().includes("tailscale")
      ) {
        label = "Tailscale";
      }

      addresses.push({ ip: iface.address, label });
    }
  }

  return addresses;
}

export function buildConnectionUrl(
  wsUrl: string,
  apiKey?: string,
): string {
  const params = new URLSearchParams({ url: wsUrl });
  if (apiKey) {
    params.set("token", apiKey);
  }
  return `ccpocket://connect?${params.toString()}`;
}

export interface PairingConnection {
  label: string;
  wsUrl: string;
  /** `ccpocket://connect` deep link for [wsUrl], including the token. */
  deepLink: string;
}

export interface PairingInfo {
  auth: "required" | "none";
  connections: PairingConnection[];
  /** Preferred URL encoded in the QR code. */
  wsUrl?: string;
  /** `ccpocket://connect` deep link for [wsUrl], including the token. */
  deepLink?: string;
  demoMode: boolean;
  /** Raw BRIDGE_PUBLIC_WS_URL value when it was rejected as invalid. */
  invalidPublicWsUrl?: string;
}

/**
 * Collect everything a client needs to pair with this Bridge.
 *
 * Used for the startup banner, `ccpocket-bridge qr`, and the loopback-only
 * `/pairing` endpoint. Demo mode hides Tailscale addresses and the token.
 */
export function buildPairingInfo(port: number, apiKey?: string): PairingInfo {
  const demoMode = !!process.env.BRIDGE_DEMO_MODE;
  const rawPublicWsUrl = process.env.BRIDGE_PUBLIC_WS_URL;
  const publicWsUrl = validatePublicWsUrl(rawPublicWsUrl);
  const addresses = getReachableAddresses();
  const displayAddresses = demoMode
    ? addresses.filter((a) => a.label !== "Tailscale")
    : addresses;

  const token = demoMode ? undefined : apiKey;
  const connections: PairingConnection[] = displayAddresses.map((addr) => {
    const wsUrl = `ws://${addr.ip}:${port}`;
    return {
      label: addr.label,
      wsUrl,
      deepLink: buildConnectionUrl(wsUrl, token),
    };
  });
  if (publicWsUrl) {
    connections.push({
      label: "Public",
      wsUrl: publicWsUrl,
      deepLink: buildConnectionUrl(publicWsUrl, token),
    });
  }

  const fallbackWsUrl = displayAddresses.length > 0
    ? `ws://${displayAddresses.find((a) => a.label === "LAN")?.ip ?? displayAddresses[0].ip}:${port}`
    : undefined;
  const wsUrl = publicWsUrl ?? fallbackWsUrl;

  return {
    auth: apiKey ? "required" : "none",
    connections,
    wsUrl,
    deepLink: wsUrl ? buildConnectionUrl(wsUrl, token) : undefined,
    demoMode,
    invalidPublicWsUrl: rawPublicWsUrl && !publicWsUrl ? rawPublicWsUrl : undefined,
  };
}

/**
 * One QR target per kind of route (LAN, Tailscale, Public): the first address
 * of each label, with the preferred URL's label first.
 */
export function pairingQrTargets(info: PairingInfo): PairingConnection[] {
  const targets = new Map<string, PairingConnection>();
  const preferred = info.connections.find((c) => c.wsUrl === info.wsUrl);
  if (preferred) targets.set(preferred.label, preferred);
  for (const connection of info.connections) {
    if (!targets.has(connection.label)) {
      targets.set(connection.label, connection);
    }
  }
  return [...targets.values()];
}

/** Print connection URLs and a terminal QR code per route. */
export async function printPairingInfo(info: PairingInfo): Promise<void> {
  if (info.invalidPublicWsUrl) {
    console.warn(
      `[bridge] Warning: ignoring invalid BRIDGE_PUBLIC_WS_URL: ${info.invalidPublicWsUrl}`,
    );
  }
  if (info.connections.length === 0 || !info.deepLink) return;

  const lines: string[] = [];
  lines.push("");
  if (info.demoMode) {
    lines.push("[bridge] ─── Connection Info [DEMO MODE] ────────────────");
  } else {
    lines.push("[bridge] ─── Connection Info ───────────────────────────");
  }

  // Group by label, keeping Public last.
  const grouped = new Map<string, string[]>();
  for (const connection of info.connections) {
    const list = grouped.get(connection.label) ?? [];
    list.push(connection.wsUrl);
    grouped.set(connection.label, list);
  }
  for (const [label, urls] of grouped) {
    for (const url of urls) {
      lines.push(`[bridge]   ${`${label}:`.padEnd(12)} ${url}`);
    }
  }

  // Print all non-QR lines
  console.log(lines.join("\n"));

  for (const target of pairingQrTargets(info)) {
    console.log(
      [
        "",
        `[bridge]   Scan with the ccpocket app (${target.label}: ${target.wsUrl}):`,
        `[bridge]   Deep Link: ${target.deepLink}`,
      ].join("\n"),
    );
    try {
      const qrText = await QRCode.toString(target.deepLink, {
        type: "terminal",
        small: true,
      });
      // Indent QR code lines
      console.log(
        qrText
          .split("\n")
          .map((line) => `           ${line}`)
          .join("\n"),
      );
    } catch {
      console.log("[bridge]   (QR code generation failed)");
    }
  }

  console.log(
    "[bridge] ───────────────────────────────────────────────",
  );
}

export async function printStartupInfo(
  port: number,
  _host: string,
  apiKey?: string,
): Promise<void> {
  await printPairingInfo(buildPairingInfo(port, apiKey));
}
