import { hostname } from "node:os";

export type PushPlatform = "ios" | "android" | "web";

export interface PushNotifyPayload {
  eventType: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface PushRelayClientOptions {
  relayUrl?: string;
  relaySecret?: string;
  bridgeId?: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

type PushRelayOpPayload =
  | { op: "register"; token: string; platform: PushPlatform; bridgeId: string }
  | { op: "unregister"; token: string; bridgeId: string }
  | { op: "notify"; eventType: string; title: string; body: string; data?: Record<string, string>; bridgeId: string };

export class PushRelayClient {
  private readonly relayUrl: string | null;
  private readonly relaySecret: string | null;
  private readonly bridgeId: string;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: PushRelayClientOptions = {}) {
    const relayUrl = (options.relayUrl ?? process.env.PUSH_RELAY_URL ?? "").trim();
    const relaySecret = (options.relaySecret ?? process.env.PUSH_RELAY_SECRET ?? "").trim();
    const bridgeId = (options.bridgeId ?? process.env.PUSH_BRIDGE_ID ?? "").trim();
    this.relayUrl = relayUrl.length > 0 ? relayUrl : null;
    this.relaySecret = relaySecret.length > 0 ? relaySecret : null;
    this.bridgeId = bridgeId.length > 0 ? bridgeId : hostname();
    this.timeoutMs = options.timeoutMs ?? 10_000;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  get isConfigured(): boolean {
    return this.relayUrl != null && this.relaySecret != null;
  }

  async registerToken(token: string, platform: PushPlatform): Promise<void> {
    await this.post({ op: "register", token, platform, bridgeId: this.bridgeId });
  }

  async unregisterToken(token: string): Promise<void> {
    await this.post({ op: "unregister", token, bridgeId: this.bridgeId });
  }

  async notify(payload: PushNotifyPayload): Promise<void> {
    await this.post({
      op: "notify",
      bridgeId: this.bridgeId,
      eventType: payload.eventType,
      title: payload.title,
      body: payload.body,
      data: payload.data,
    });
  }

  private async post(payload: PushRelayOpPayload): Promise<void> {
    if (!this.isConfigured || this.relayUrl == null || this.relaySecret == null) return;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetchImpl(this.relayUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.relaySecret}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      if (!response.ok) {
        const text = (await response.text()).trim().slice(0, 200);
        throw new Error(`Push relay returned ${response.status}${text ? `: ${text}` : ""}`);
      }
    } finally {
      clearTimeout(timer);
    }
  }
}
