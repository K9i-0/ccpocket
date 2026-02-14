import { describe, it, expect, vi } from "vitest";
import { PushRelayClient } from "./push-relay.js";

describe("PushRelayClient", () => {
  it("is disabled when relay env is missing", async () => {
    const fetchMock = vi.fn();
    const client = new PushRelayClient({
      relayUrl: "",
      relaySecret: "",
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    expect(client.isConfigured).toBe(false);
    await client.registerToken("token-1", "ios");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("posts register payload with auth header", async () => {
    const fetchMock = vi.fn(async () => new Response("", { status: 200 }));
    const client = new PushRelayClient({
      relayUrl: "https://relay.example.com/push",
      relaySecret: "dummy",
      bridgeId: "bridge-123",
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await client.registerToken("token-1", "ios");

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://relay.example.com/push");
    expect(init?.method).toBe("POST");
    expect(init?.headers).toEqual({
      "Content-Type": "application/json",
      "Authorization": "Bearer dummy",
    });

    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    expect(body).toEqual({
      op: "register",
      bridgeId: "bridge-123",
      token: "token-1",
      platform: "ios",
    });
  });

  it("throws on non-2xx relay response", async () => {
    const fetchMock = vi.fn(async () => new Response("boom", { status: 500 }));
    const client = new PushRelayClient({
      relayUrl: "https://relay.example.com/push",
      relaySecret: "dummy",
      bridgeId: "bridge-123",
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await expect(client.notify({
      eventType: "session_completed",
      title: "done",
      body: "ok",
    })).rejects.toThrow("Push relay returned 500");
  });
});
