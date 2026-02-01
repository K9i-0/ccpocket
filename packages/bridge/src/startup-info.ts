import os from "node:os";
import QRCode from "qrcode";

interface NetworkAddress {
  ip: string;
  label: string;
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
  ip: string,
  port: number,
  apiKey?: string,
): string {
  const wsUrl = `ws://${ip}:${port}`;
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
  if (addresses.length === 0) return;

  const lines: string[] = [];
  lines.push("");
  lines.push("[bridge] ─── Connection Info ───────────────────────────");

  // Group by label
  const grouped = new Map<string, string[]>();
  for (const addr of addresses) {
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

  // Use first LAN address, fallback to first address
  const primaryAddr =
    addresses.find((a) => a.label === "LAN")?.ip ?? addresses[0].ip;
  const deepLink = buildConnectionUrl(primaryAddr, port, apiKey);

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
