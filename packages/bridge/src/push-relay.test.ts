import { describe, it, expect, vi } from "vitest";
import { PushRelayClient } from "./push-relay.js";
import type { FirebaseAuthClient } from "./firebase-auth.js";

function createMockAuth(uid = "test-uid", idToken = "mock-id-token"): FirebaseAuthClient {
  return {
    uid,
    getIdToken: vi.fn(async () => idToken),
    initialize: vi.fn(async () => {}),
  } as unknown as FirebaseAuthClient;
}

describe("PushRelayClient", () => {
  it("is disabled when firebaseAuth is not provided", async () => {
    const fetchMock = vi.fn();
    const client = new PushRelayClient({
      firebaseAuth: null,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    expect(client.isConfigured).toBe(false);
    await client.registerToken("token-1", "ios");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("posts register payload with Firebase ID token", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    const mockAuth = createMockAuth("bridge-uid-123", "firebase-id-token-abc");
    const client = new PushRelayClient({
      relayUrl: "https://relay.example.com/push",
      firebaseAuth: mockAuth,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await client.registerToken("token-1", "ios");

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://relay.example.com/push");
    expect(init?.method).toBe("POST");
    expect(init?.headers).toEqual({
      "Content-Type": "application/json",
      "Authorization": "Bearer firebase-id-token-abc",
    });

    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    expect(body).toEqual({
      op: "register",
      bridgeId: "bridge-uid-123",
      token: "token-1",
      platform: "ios",
    });
  });

  it("throws on non-2xx relay response", async () => {
    const fetchMock = vi.fn(async () => new Response("boom", { status: 500 }));
    const mockAuth = createMockAuth("bridge-uid-123", "firebase-id-token-abc");
    const client = new PushRelayClient({
      relayUrl: "https://relay.example.com/push",
      firebaseAuth: mockAuth,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await expect(client.notify({
      eventType: "session_completed",
      title: "done",
      body: "ok",
    })).rejects.toThrow("Push relay returned 500");
  });

  it("uses default relay URL when not specified", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    const mockAuth = createMockAuth();
    const client = new PushRelayClient({
      firebaseAuth: mockAuth,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await client.registerToken("token-1", "android");

    const [url] = fetchMock.mock.calls[0];
    expect(url).toBe("https://us-central1-ccpocket-ca33b.cloudfunctions.net/relay");
  });

  it("fetches fresh ID token on each request", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    const mockAuth = createMockAuth();
    const client = new PushRelayClient({
      firebaseAuth: mockAuth,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await client.registerToken("t1", "ios");
    await client.unregisterToken("t1");

    expect(mockAuth.getIdToken).toHaveBeenCalledTimes(2);
  });
});
