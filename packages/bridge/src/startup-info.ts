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

const ROUTE_STYLE: Record<string, { hint: string; color: string }> = {
  LAN: { hint: "Same Wi-Fi or local network", color: "\x1b[32m" },
  Tailscale: { hint: "Anywhere on your tailnet", color: "\x1b[36m" },
  Public: { hint: "Public URL", color: "\x1b[33m" },
};
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";
const COLUMN_GAP = 6;
const INDENT = "  ";

export interface PairingRenderOptions {
  /** Use ANSI colors (TTY without NO_COLOR). */
  color: boolean;
  /** Terminal width; QR codes sit side by side when they fit. */
  columns: number;
}

function visibleLength(text: string): number {
  return text.replace(/\x1b\[[0-9;]*m/g, "").length;
}

function padVisible(text: string, width: number): string {
  return text + " ".repeat(Math.max(0, width - visibleLength(text)));
}

/**
 * Render the connection block shown when the Bridge starts and by
 * `ccpocket-bridge qr`: one column per route (LAN, Tailscale, Public) with a
 * colored heading, a short hint, its URL and its QR code.
 */
export function renderPairingInfo(
  info: PairingInfo,
  qrCodes: ReadonlyMap<string, string | null>,
  options: PairingRenderOptions,
): string {
  const paint = (code: string, text: string) =>
    options.color ? `${code}${text}${RESET}` : text;
  const targets = pairingQrTargets(info);

  const columns = targets.map((target) => {
    const style = ROUTE_STYLE[target.label] ?? {
      hint: "",
      color: "",
    };
    const qr = qrCodes.get(target.deepLink);
    const qrLines = qr
      ? qr.replace(/\n+$/, "").split("\n")
      : ["(QR code generation failed)"];
    return [
      paint(BOLD + style.color, `● ${target.label}`),
      paint(DIM, style.hint),
      target.wsUrl,
      "",
      ...qrLines,
    ];
  });

  const widths = columns.map((lines) =>
    Math.max(...lines.map(visibleLength)),
  );
  const sideBySide =
    INDENT.length +
      widths.reduce((sum, w) => sum + w, 0) +
      COLUMN_GAP * Math.max(0, columns.length - 1) <=
    options.columns;

  const title = info.demoMode
    ? "Connect from your phone [DEMO MODE]"
    : "Connect from your phone";
  const ruleWidth = Math.max(
    40,
    Math.min(
      options.columns - INDENT.length,
      sideBySide
        ? widths.reduce((sum, w) => sum + w, 0) +
            COLUMN_GAP * Math.max(0, columns.length - 1)
        : Math.max(...widths, 40),
    ),
  );
  const out: string[] = [
    "",
    INDENT + paint(BOLD, `━━ ${title} `) + paint(DIM, "━".repeat(Math.max(0, ruleWidth - title.length - 4))),
    INDENT + "Scan a QR code with the CC Pocket app.",
    "",
  ];

  if (sideBySide) {
    const height = Math.max(...columns.map((lines) => lines.length));
    for (let row = 0; row < height; row += 1) {
      const cells = columns.map((lines, index) => {
        const cell = lines[row] ?? "";
        return index === columns.length - 1
          ? cell
          : padVisible(cell, widths[index] + COLUMN_GAP);
      });
      out.push((INDENT + cells.join("")).trimEnd());
    }
  } else {
    columns.forEach((lines, index) => {
      if (index > 0) out.push("");
      for (const line of lines) out.push((INDENT + line).trimEnd());
    });
  }

  const shown = new Set(targets.map((target) => target.wsUrl));
  const others = info.connections.filter((c) => !shown.has(c.wsUrl));
  out.push("");
  if (others.length > 0) {
    out.push(INDENT + paint(DIM, "Other addresses:"));
    for (const other of others) {
      out.push(INDENT + `  ${`${other.label}`.padEnd(10)} ${other.wsUrl}`);
    }
  }
  out.push(INDENT + paint(DIM, "Deep links (open on this device or share):"));
  for (const target of targets) {
    out.push(INDENT + `  ${target.label.padEnd(10)} ${target.deepLink}`);
  }
  out.push(INDENT + paint(DIM, "━".repeat(ruleWidth)));
  return out.join("\n");
}

/** Print connection URLs and a terminal QR code per route. */
export async function printPairingInfo(info: PairingInfo): Promise<void> {
  if (info.invalidPublicWsUrl) {
    console.warn(
      `[bridge] Warning: ignoring invalid BRIDGE_PUBLIC_WS_URL: ${info.invalidPublicWsUrl}`,
    );
  }
  if (info.connections.length === 0 || !info.deepLink) return;

  const qrCodes = new Map<string, string | null>();
  for (const target of pairingQrTargets(info)) {
    try {
      qrCodes.set(
        target.deepLink,
        await QRCode.toString(target.deepLink, { type: "terminal", small: true }),
      );
    } catch {
      qrCodes.set(target.deepLink, null);
    }
  }

  console.log(
    renderPairingInfo(info, qrCodes, {
      color: !!process.stdout.isTTY && !process.env.NO_COLOR,
      columns: process.stdout.columns ?? 80,
    }),
  );
}

export async function printStartupInfo(
  port: number,
  _host: string,
  apiKey?: string,
): Promise<void> {
  await printPairingInfo(buildPairingInfo(port, apiKey));
}
