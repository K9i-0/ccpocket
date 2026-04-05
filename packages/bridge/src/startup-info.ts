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

export async function printStartupInfo(
  port: number,
  _host: string,
  apiKey?: string,
): Promise<void> {
  const addresses = getReachableAddresses();
  const demoMode = !!process.env.BRIDGE_DEMO_MODE;
  const rawPublicWsUrl = process.env.BRIDGE_PUBLIC_WS_URL;
  const publicWsUrl = validatePublicWsUrl(rawPublicWsUrl);

  if (rawPublicWsUrl && !publicWsUrl) {
    console.warn(
      `[bridge] Warning: ignoring invalid BRIDGE_PUBLIC_WS_URL: ${rawPublicWsUrl}`,
    );
  }

  // Demo mode: exclude Tailscale addresses for video recording
  const displayAddresses = demoMode
    ? addresses.filter((a) => a.label !== "Tailscale")
    : addresses;

  if (displayAddresses.length === 0 && !publicWsUrl) return;

  const lines: string[] = [];
  lines.push("");
  if (demoMode) {
    lines.push("[bridge] ─── Connection Info [DEMO MODE] ────────────────");
  } else {
    lines.push("[bridge] ─── Connection Info ───────────────────────────");
  }

  // Group by label
  const grouped = new Map<string, string[]>();
  for (const addr of displayAddresses) {
    const list = grouped.get(addr.label) ?? [];
    list.push(addr.ip);
    grouped.set(addr.label, list);
  }

  for (const [label, ips] of grouped) {
    for (const ip of ips) {
      const padded = `${label}:`.padEnd(12);
      lines.push(`[bridge]   ${padded} ws://${ip}:${port}`);
    }
  }

  if (publicWsUrl) {
    lines.push(`[bridge]   ${"Public:".padEnd(12)} ${publicWsUrl}`);
  }

  const preferredAddress =
    displayAddresses.find((a) => a.label === "Tailscale") ??
    displayAddresses.find((a) => a.label === "LAN") ??
    displayAddresses[0];
  const fallbackWsUrl = preferredAddress
    ? `ws://${preferredAddress.ip}:${port}`
    : undefined;

  const connectWsUrl = publicWsUrl ?? fallbackWsUrl;
  if (!connectWsUrl) return;

  // Demo mode: omit API key from deep link
  const deepLink = buildConnectionUrl(connectWsUrl, demoMode ? undefined : apiKey);

  lines.push("");
  lines.push(`[bridge]   Deep Link: ${deepLink}`);
  lines.push("");
  lines.push("[bridge]   Scan QR code with ccpocket app:");

  // Print all non-QR lines
  console.log(lines.join("\n"));

  // Generate and print QR code
  try {
    const qrText = await QRCode.toString(deepLink, {
      type: "terminal",
      small: true,
    });
    // Indent QR code lines
    const indented = qrText
      .split("\n")
      .map((line) => `           ${line}`)
      .join("\n");
    console.log(indented);
  } catch {
    console.log("[bridge]   (QR code generation failed)");
  }

  console.log(
    "[bridge] ───────────────────────────────────────────────",
  );
}
