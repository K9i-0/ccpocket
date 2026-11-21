import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { PinStore } from "./pin-store.js";

describe("PinStore", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "ccpocket-pins-"));
    file = join(dir, "nested", "pins.json");
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  const pin = (sessionId: string, projectPath = "/p") =>
    ({ provider: "claude", sessionId, projectPath }) as const;

  it("adopts the first non-empty seed only", async () => {
    const store = new PinStore(file);
    await store.init();
    expect(store.isSeeded).toBe(false);

    expect(await store.seed({ sessions: [], projects: [] })).toBe(false);
    expect(store.isSeeded).toBe(false);

    expect(
      await store.seed({ sessions: [pin("a"), pin("a", "/other")], projects: ["/p"] }),
    ).toBe(true);
    expect(store.snapshot()).toEqual({ sessions: [pin("a")], projects: ["/p"] });

    expect(await store.seed({ sessions: [pin("b")] })).toBe(false);
    expect(store.snapshot().sessions).toEqual([pin("a")]);
  });

  it("persists changes and reloads them", async () => {
    const store = new PinStore(file);
    expect(await store.setSessionPin(pin("a"), true)).toBe(true);
    expect(await store.setSessionPin(pin("a", "/other"), true)).toBe(false);
    expect(await store.setProjectPin("/p", true)).toBe(true);
    expect(await store.setSessionPin({ ...pin("b"), provider: "codex" }, true)).toBe(true);
    expect(await store.setSessionPin(pin("a", "/other"), false)).toBe(true);

    const reloaded = new PinStore(file);
    await reloaded.init();
    expect(reloaded.isSeeded).toBe(true);
    expect(reloaded.snapshot()).toEqual({
      sessions: [{ provider: "codex", sessionId: "b", projectPath: "/p" }],
      projects: ["/p"],
    });
    expect(JSON.parse(readFileSync(file, "utf-8")).version).toBe(1);
  });

  it("a change seeds the store, so unpinning everything is kept", async () => {
    const store = new PinStore(file);
    await store.setProjectPin("/p", true);
    await store.setProjectPin("/p", false);

    const reloaded = new PinStore(file);
    expect(await reloaded.seed({ sessions: [pin("stale")] })).toBe(false);
    expect(reloaded.snapshot()).toEqual({ sessions: [], projects: [] });
  });

  it("treats a corrupted file as unseeded and drops malformed entries", async () => {
    const corrupted = join(dir, "pins.json");
    writeFileSync(corrupted, "{not json");
    const store = new PinStore(corrupted);
    await store.init();
    expect(store.isSeeded).toBe(false);

    writeFileSync(
      corrupted,
      JSON.stringify({
        version: 1,
        sessions: [pin("ok"), { provider: "other", sessionId: "x" }, null],
        projects: ["/p", "", 3],
      }),
    );
    const valid = new PinStore(corrupted);
    await valid.init();
    expect(valid.snapshot()).toEqual({ sessions: [pin("ok")], projects: ["/p"] });
  });
});
