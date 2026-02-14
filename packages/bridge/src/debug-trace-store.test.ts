import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { DebugTraceStore } from "./debug-trace-store.js";

describe("DebugTraceStore", () => {
  let rootDir = "";

  beforeEach(async () => {
    rootDir = await mkdtemp(join(tmpdir(), "ccpocket-debug-trace-store-"));
  });

  afterEach(async () => {
    if (rootDir) {
      await rm(rootDir, { recursive: true, force: true });
    }
  });

  it("persists trace events as jsonl", async () => {
    const store = new DebugTraceStore(rootDir);
    await store.init();

    store.record({
      ts: "2026-02-13T00:00:00.000Z",
      sessionId: "s-1",
      direction: "incoming",
      channel: "ws",
      type: "input",
      detail: "text=\"hello\" image=false",
    });
    await store.flush();

    const tracePath = store.getTraceFilePath("s-1");
    const raw = await readFile(tracePath, "utf-8");
    const lines = raw.trim().split("\n");
    expect(lines).toHaveLength(1);
    expect(JSON.parse(lines[0])).toMatchObject({
      sessionId: "s-1",
      type: "input",
    });
    expect((store as any).writeChains.size).toBe(0);
  });

  it("saves bundle snapshots to disk", async () => {
    const store = new DebugTraceStore(rootDir);
    await store.init();

    const bundlePath = store.saveBundle("s-2", "2026-02-13T01:02:03.456Z", {
      type: "debug_bundle",
      sessionId: "s-2",
    });
    await store.flush();

    const bundleRaw = await readFile(bundlePath, "utf-8");
    const parsed = JSON.parse(bundleRaw) as { type: string; sessionId: string };
    expect(parsed).toEqual({
      type: "debug_bundle",
      sessionId: "s-2",
    });
    expect((store as any).writeChains.size).toBe(0);
  });
});
