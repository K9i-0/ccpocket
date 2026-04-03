import { Bonjour } from "bonjour-service";
import { loadConfig } from "./config.js";

export async function discoverBridge(timeoutMs = 5000): Promise<string | null> {
  const config = loadConfig();
  if (config.bridgeUrl) return config.bridgeUrl;

  return new Promise<string | null>((resolve) => {
    const bonjour = new Bonjour();
    let resolved = false;

    const browser = bonjour.find({ type: "ccpocket" }, (service) => {
      if (resolved) return;
      resolved = true;
      browser.stop();
      bonjour.destroy();

      const addr = service.addresses?.[0];
      const port = service.port ?? 8765;
      if (addr) {
        resolve(`ws://${addr}:${port}`);
      } else {
        resolve(null);
      }
    });

    setTimeout(() => {
      if (resolved) return;
      resolved = true;
      browser.stop();
      bonjour.destroy();

      if (config.remoteBridgeUrl) {
        resolve(config.remoteBridgeUrl);
      } else {
        resolve(null);
      }
    }, timeoutMs);
  });
}
