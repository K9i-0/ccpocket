import { describe, it, expect } from "vitest";
import { ReplayBuffer } from "./replay-buffer.js";

describe("ReplayBuffer", () => {
  it("appends events with incrementing sequence numbers", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "status", status: "running" });
    buf.append({ type: "stream_delta", text: "hello" });

    const events = buf.replayFrom(0);
    expect(events).toHaveLength(2);
    expect(events[0].seq).toBe(1);
    expect(events[1].seq).toBe(2);
    expect(events[1].msg).toEqual({ type: "stream_delta", text: "hello" });
  });

  it("replays only events after lastSeq", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" });
    buf.append({ type: "stream_delta", text: "b" });
    buf.append({ type: "stream_delta", text: "c" });

    const events = buf.replayFrom(2);
    expect(events).toHaveLength(1);
    expect(events[0].seq).toBe(3);
    expect(events[0].msg).toEqual({ type: "stream_delta", text: "c" });
  });

  it("returns all events when lastSeq is 0", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" });
    buf.append({ type: "stream_delta", text: "b" });

    expect(buf.replayFrom(0)).toHaveLength(2);
  });

  it("evicts oldest events when max count exceeded", () => {
    const buf = new ReplayBuffer({ maxCount: 3 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const events = buf.replayFrom(0);
    expect(events).toHaveLength(3);
    expect(events[0].seq).toBe(3); // oldest surviving
    expect(events[2].seq).toBe(5);
  });

  it("detects gap when lastSeq is older than buffer start", () => {
    const buf = new ReplayBuffer({ maxCount: 2 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const result = buf.replayWithGapInfo(1); // seq 1 is long gone
    expect(result.gap).toBe(true);
    expect(result.events).toHaveLength(2); // sends full buffer
  });

  it("no gap when lastSeq is within buffer range", () => {
    const buf = new ReplayBuffer({ maxCount: 10 });
    for (let i = 1; i <= 5; i++) {
      buf.append({ type: "stream_delta", text: `msg-${i}` });
    }

    const result = buf.replayWithGapInfo(3);
    expect(result.gap).toBe(false);
    expect(result.events).toHaveLength(2); // seq 4 and 5
  });

  it("evicts when total size exceeds maxBytes", () => {
    const buf = new ReplayBuffer({ maxCount: 1000, maxBytes: 100 });
    // Each event is roughly ~40 bytes when serialized
    for (let i = 0; i < 10; i++) {
      buf.append({ type: "stream_delta", text: "x".repeat(20) });
    }

    // Should have evicted to stay under 100 bytes
    expect(buf.length).toBeLessThan(10);
    expect(buf.length).toBeGreaterThan(0);
  });

  it("returns empty array when empty", () => {
    const buf = new ReplayBuffer();
    expect(buf.replayFrom(0)).toEqual([]);
    expect(buf.replayFrom(99)).toEqual([]);
  });

  it("clear removes all events but preserves nextSeq for gap detection", () => {
    const buf = new ReplayBuffer();
    buf.append({ type: "stream_delta", text: "a" }); // seq 1
    buf.clear();
    expect(buf.replayFrom(0)).toEqual([]);
    expect(buf.length).toBe(0);

    // After clear, new events continue from where nextSeq left off
    const seq = buf.append({ type: "stream_delta", text: "b" });
    expect(seq).toBe(2); // Not 1 — nextSeq was preserved

    // A client reconnecting with lastSeq=1 correctly detects a gap
    // (the cleared event at seq 1 is gone — client knows data was lost)
    const result = buf.replayWithGapInfo(1);
    expect(result.gap).toBe(true);
    expect(result.events).toHaveLength(1); // full buffer on gap
    expect(result.events[0].seq).toBe(2);

    // A client with lastSeq=0 (first connect) gets everything, no gap
    const fresh = buf.replayWithGapInfo(0);
    expect(fresh.gap).toBe(false);
    expect(fresh.events).toHaveLength(1);
  });
});
