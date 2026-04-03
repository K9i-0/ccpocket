import { describe, it, expect, vi, beforeEach } from "vitest";

const { mockWsInstances } = vi.hoisted(() => {
  const mockWsInstances: Array<{ send: (...args: unknown[]) => void; close: () => void; readyState: number; on: (event: string, cb: (...args: unknown[]) => void) => void; emit: (event: string, ...args: unknown[]) => boolean }> = [];
  return { mockWsInstances };
});

vi.mock("ws", () => {
  const { EventEmitter } = require("node:events");
  const OPEN = 1;
  class MockWebSocket extends EventEmitter {
    readyState = OPEN;
    send = vi.fn();
    close = vi.fn();
    static OPEN = OPEN;
    constructor() {
      super();
      mockWsInstances.push(this as any);
      setTimeout(() => (this as any).emit("open"), 0);
    }
  }
  return { WebSocket: MockWebSocket, default: { WebSocket: MockWebSocket } };
});

import { BridgeClient } from "./bridge-client.js";

describe("BridgeClient", () => {
  beforeEach(() => {
    mockWsInstances.length = 0;
  });

  it("connects to bridge URL", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    expect(mockWsInstances).toHaveLength(1);
    client.disconnect();
  });

  it("sends messages as JSON", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    client.send({ type: "list_sessions" });
    expect(mockWsInstances[0].send).toHaveBeenCalledWith(
      JSON.stringify({ type: "list_sessions" }),
    );
    client.disconnect();
  });

  it("emits parsed messages", async () => {
    const client = new BridgeClient("ws://localhost:8765");
    await new Promise((r) => setTimeout(r, 10));
    const messages: unknown[] = [];
    client.on("message", (msg) => messages.push(msg));
    (mockWsInstances[0] as any).emit("message", JSON.stringify({ type: "session_list", sessions: [] }));
    expect(messages).toHaveLength(1);
    expect((messages[0] as any).type).toBe("session_list");
    client.disconnect();
  });
});
