import type { FirebaseAuthClient } from "./firebase-auth.js";

export type PushPlatform = "ios" | "android" | "web";

export interface PushNotifyPayload {
  eventType: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushRelayClientOptions {
  relayUrl?: string;
  firebaseAuth?: FirebaseAuthClient | null;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

type PushRelayOpPayload =
  | { op: "register"; token: string; platform: PushPlatform; bridgeId: string }
  | { op: "unregister"; token: string; bridgeId: string }
  | { op: "notify"; eventType: string; title: string; body: string; data?: Record<string, string>; bridgeId: string };

const DEFAULT_RELAY_URL = "https://us-central1-ccpocket-ca33b.cloudfunctions.net/relay";

export class PushRelayClient {
  private readonly relayUrl: string;
  private readonly firebaseAuth: FirebaseAuthClient | null;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: PushRelayClientOptions = {}) {
    this.relayUrl = options.relayUrl ?? DEFAULT_RELAY_URL;
    this.firebaseAuth = options.firebaseAuth ?? null;
    this.timeoutMs = options.timeoutMs ?? 10_000;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  get isConfigured(): boolean {
    return this.firebaseAuth != null;
  }

  private get bridgeId(): string {
    return this.firebaseAuth!.uid;
  }

  async registerToken(token: string, platform: PushPlatform): Promise<void> {
    if (!this.isConfigured) return;
    await this.post({ op: "register", token, platform, bridgeId: this.bridgeId });
  }

  async unregisterToken(token: string): Promise<void> {
    if (!this.isConfigured) return;
    await this.post({ op: "unregister", token, bridgeId: this.bridgeId });
  }

  async notify(payload: PushNotifyPayload): Promise<void> {
    if (!this.isConfigured) return;
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
    if (!this.isConfigured || !this.firebaseAuth) return;

    console.log(`[push-relay] ${payload.op} → ${this.relayUrl} (bridgeId: ${payload.bridgeId})`);
    const idToken = await this.firebaseAuth.getIdToken();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetchImpl(this.relayUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${idToken}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });

      const responseText = (await response.text()).trim().slice(0, 200);
      if (!response.ok) {
        throw new Error(`Push relay returned ${response.status}${responseText ? `: ${responseText}` : ""}`);
      }
      console.log(`[push-relay] ${payload.op} OK: ${responseText}`);
    } finally {
      clearTimeout(timer);
    }
  }
}
