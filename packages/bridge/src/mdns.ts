import { Bonjour, type Service } from "bonjour-service";

export class MdnsAdvertiser {
  private bonjour: Bonjour | null = null;
  private service: Service | null = null;

  start(port: number, apiKey?: string): void {
    this.bonjour = new Bonjour();
    this.service = this.bonjour.publish({
      name: "ccpocket-bridge",
      type: "ccpocket",
      protocol: "tcp",
      port,
      txt: {
        version: "1",
        auth: apiKey ? "required" : "none",
      },
    });
    console.log(
      `[bridge] mDNS: advertising _ccpocket._tcp on port ${port}`,
    );
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
