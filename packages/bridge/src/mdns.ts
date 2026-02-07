import { Bonjour, type Service } from "bonjour-service";

export class MdnsAdvertiser {
  private bonjour: Bonjour | null = null;
  private service: Service | null = null;

  start(port: number, apiKey?: string): void {
    try {
      this.bonjour = new Bonjour();
      this.service = this.bonjour.publish({
        name: "ccpocket-bridge",
        type: "ccpocket",
        protocol: "tcp",
        port,
        probe: false, // Skip name collision check (same bridge restarting)
        txt: {
          version: "1",
          auth: apiKey ? "required" : "none",
        },
      });
      // Handle async errors (e.g. name already in use from a stale process)
      this.service.on("error", (err: Error) => {
        console.warn(`[bridge] mDNS: service error (non-fatal): ${err.message}`);
      });
      console.log(
        `[bridge] mDNS: advertising _ccpocket._tcp on port ${port}`,
      );
    } catch (err) {
      console.warn(`[bridge] mDNS: failed to advertise (non-fatal): ${err instanceof Error ? err.message : err}`);
      this.stop();
    }
  }

  stop(): void {
    if (this.service) {
      this.service.stop?.();
      this.service = null;
    }
    if (this.bonjour) {
      this.bonjour.destroy();
      this.bonjour = null;
    }
    console.log("[bridge] mDNS: stopped advertising");
  }
}
