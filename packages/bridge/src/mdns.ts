import BonjourModule from "bonjour-service";

interface PublishedService {
  on(event: "error", listener: (err: Error) => void): void;
  stop?: () => void;
}

interface BonjourClient {
  publish(opts: {
    name: string;
    type: string;
    protocol: "tcp";
    port: number;
    probe: boolean;
    txt: Record<string, string>;
  }): PublishedService;
  destroy(): void;
}

type BonjourConstructor = new (
  opts?: Record<string, unknown>,
  errorCallback?: (err: Error) => void,
) => BonjourClient;

function readExport(value: unknown, key: string): unknown {
  if (typeof value !== "object" || value === null) return undefined;
  return (value as Record<string, unknown>)[key];
}

export function resolveBonjourConstructor(
  moduleExport: unknown,
): BonjourConstructor {
  const defaultExport = readExport(moduleExport, "default");
  const candidates = [
    moduleExport,
    readExport(moduleExport, "Bonjour"),
    defaultExport,
    readExport(defaultExport, "Bonjour"),
    readExport(defaultExport, "default"),
  ];
  const constructor = candidates.find(
    (candidate): candidate is BonjourConstructor =>
      typeof candidate === "function",
  );

  if (!constructor) {
    throw new TypeError("Unsupported bonjour-service export shape");
  }

  return constructor;
}

export class MdnsAdvertiser {
  private bonjour: BonjourClient | null = null;
  private service: PublishedService | null = null;
  private disabled = false;

  start(port: number, apiKey?: string): void {
    if (this.disabled) return;
    try {
      const Bonjour = resolveBonjourConstructor(BonjourModule);
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
