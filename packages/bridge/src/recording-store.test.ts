import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { RecordingStore, type RecordedEvent } from "./recording-store.js";
import type { ServerMessage, ClientMessage } from "./parser.js";

describe("RecordingStore", () => {
  let rootDir = "";

  beforeEach(async () => {
    rootDir = await mkdtemp(join(tmpdir(), "ccpocket-recording-store-"));
  });

  afterEach(async () => {
    if (rootDir) {
      await rm(rootDir, { recursive: true, force: true });
    }
  });

  it("records outgoing server messages as jsonl", async () => {
    const store = new RecordingStore(rootDir);
    await store.init();

    const msg: ServerMessage = {
      type: "status",
      status: "running",
    } as ServerMessage;
    store.record("s-1", "outgoing", msg);
    await store.flush();

    const filePath = store.getFilePath("s-1");
    const raw = await readFile(filePath, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(1);

    const event = JSON.parse(lines[0]) as RecordedEvent;
    expect(event.direction).toBe("outgoing");
    expect(event.message).toMatchObject({ type: "status", status: "running" });
    expect(event.ts).toBeDefined();
  });

  it("records incoming client messages", async () => {
    const store = new RecordingStore(rootDir);
    await store.init();

    const msg = {
      type: "approve",
      id: "tool-1",
      sessionId: "s-1",
    } as ClientMessage;
    store.record("s-1", "incoming", msg);
    await store.flush();

    const filePath = store.getFilePath("s-1");
    const raw = await readFile(filePath, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(1);

    const event = JSON.parse(lines[0]) as RecordedEvent;
    expect(event.direction).toBe("incoming");
    expect(event.message).toMatchObject({ type: "approve", id: "tool-1" });
  });

  it("appends multiple events in order", async () => {
    const store = new RecordingStore(rootDir);
    await store.init();

    store.record("s-1", "outgoing", { type: "status", status: "running" } as ServerMessage);
    store.record("s-1", "outgoing", { type: "assistant", message: { content: [] } } as unknown as ServerMessage);
    store.record("s-1", "incoming", { type: "approve", id: "t-1", sessionId: "s-1" } as ClientMessage);
    store.record("s-1", "outgoing", { type: "status", status: "idle" } as ServerMessage);
    await store.flush();

    const filePath = store.getFilePath("s-1");
    const raw = await readFile(filePath, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(4);

    const events = lines.map((l) => JSON.parse(l) as RecordedEvent);
    expect(events[0].direction).toBe("outgoing");
    expect(events[1].direction).toBe("outgoing");
    expect(events[2].direction).toBe("incoming");
    expect(events[3].direction).toBe("outgoing");
  });

  it("separates recordings by session id", async () => {
    const store = new RecordingStore(rootDir);
    await store.init();

    store.record("s-1", "outgoing", { type: "status", status: "running" } as ServerMessage);
    store.record("s-2", "outgoing", { type: "status", status: "idle" } as ServerMessage);
    await store.flush();

    const raw1 = await readFile(store.getFilePath("s-1"), "utf-8");
    const raw2 = await readFile(store.getFilePath("s-2"), "utf-8");
    expect(raw1.trim().split("\n")).toHaveLength(1);
    expect(raw2.trim().split("\n")).toHaveLength(1);
  });

  it("cleans up write chains after flush", async () => {
    const store = new RecordingStore(rootDir);
    await store.init();

    store.record("s-1", "outgoing", { type: "status", status: "running" } as ServerMessage);
    await store.flush();

    expect((store as any).writeChains.size).toBe(0);
  });
});
