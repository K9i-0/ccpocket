import { Bonjour, type Service } from "bonjour-service";

export class MdnsAdvertiser {
  private bonjour: Bonjour | null = null;
  private service: Service | null = null;
  private disabled = false;

  start(port: number, apiKey?: string): void {
    if (this.disabled) return;
    try {
      this.bonjour = new Bonjour({}, (err: Error) => {
        console.warn(
          `[bridge] mDNS: transport error (non-fatal): ${err.message}`,
        );
        this.disabled = true;
        this.stop();
      });
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
