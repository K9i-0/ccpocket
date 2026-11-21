import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  SHARED_STATE_MAX_PER_NAMESPACE,
  SHARED_STATE_MAX_PLAIN_KEYS,
  SHARED_STATE_MAX_VALUE_BYTES,
  SharedStateStore,
  isValidSharedStateValue,
} from "./shared-state-store.js";

describe("SharedStateStore", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), "ccpocket-shared-state-"));
    file = join(dir, "nested", "shared-state.json");
  });

  afterEach(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  it("stores, deletes and reloads entries with the same store id", async () => {
    const store = new SharedStateStore(file);
    expect(await store.set("auto_rename.claude", true)).toBe(true);
    expect(await store.set("ns/a", { model: "opus" })).toEqual({ model: "opus" });
    expect(await store.set("ns/b", "x")).toBe("x");
    expect(await store.set("ns/b", null)).toBeNull();
    await store.flush();

    const reloaded = new SharedStateStore(file);
    await reloaded.init();
    expect(reloaded.storeId).toBe(store.storeId);
    expect(reloaded.snapshot()).toEqual({
      "auto_rename.claude": true,
      "ns/a": { model: "opus" },
    });
    expect(JSON.parse(readFileSync(file, "utf-8")).version).toBe(1);
  });

  it("writes a burst of changes once", async () => {
    const store = new SharedStateStore(file);
    for (let i = 0; i < 50; i++) await store.set(`ns/${i}`, i);
    expect(() => readFileSync(file)).toThrow();
    await store.flush();
    expect(Object.keys(JSON.parse(readFileSync(file, "utf-8")).entries)).toHaveLength(50);
  });

  it("max keeps a stored string that is not smaller", async () => {
    const store = new SharedStateStore(file);
    expect(await store.set("seen_at/s", "2026-02-01", { max: true })).toBe("2026-02-01");
    expect(await store.set("seen_at/s", "2026-01-01", { max: true })).toBe("2026-02-01");
    expect(await store.set("seen_at/s", "2026-03-01", { max: true })).toBe("2026-03-01");
    expect(await store.set("seen_at/s", "2026-01-01")).toBe("2026-01-01");
  });

  it("seeds only absent keys", async () => {
    const store = new SharedStateStore(file);
    await store.set("a", "bridge");
    expect(
      await store.seed({ a: "client", b: "client", c: null, "": "x" }),
    ).toEqual(["b"]);
    expect(store.snapshot()).toEqual({ a: "bridge", b: "client" });
  });

  it("evicts the oldest entry of a full namespace, never plain keys", async () => {
    const store = new SharedStateStore(file);
    await store.set("auto_rename.codex", false);
    for (let i = 0; i < SHARED_STATE_MAX_PER_NAMESPACE; i++) {
      await store.set(`ns/${i}`, i);
    }
    await store.set("ns/0", "touched");
    await store.set("ns/new", "new");
    expect(store.get("ns/1")).toBeNull();
    expect(store.get("ns/0")).toBe("touched");
    expect(store.get("ns/new")).toBe("new");
    expect(store.get("auto_rename.codex")).toBe(false);

    // A seed never evicts.
    expect(await store.seed({ "ns/seed": 1, "other/seed": 1 })).toEqual(["other/seed"]);

    for (let i = 0; i < SHARED_STATE_MAX_PLAIN_KEYS; i++) await store.set(`plain${i}`, i);
    expect(await store.set("one_too_many", 1)).toBeNull();
    expect(store.get("auto_rename.codex")).toBe(false);
  });

  it("starts empty with a new id when the file is unreadable", async () => {
    const first = new SharedStateStore(file);
    await first.set("a", 1);
    await first.flush();
    writeFileSync(file, "{broken");

    const store = new SharedStateStore(file);
    await store.init();
    expect(store.snapshot()).toEqual({});
    expect(store.storeId).not.toBe(first.storeId);
  });

  it("limits the value size", () => {
    expect(isValidSharedStateValue("x".repeat(SHARED_STATE_MAX_VALUE_BYTES))).toBe(false);
    expect(isValidSharedStateValue({ a: [1, "b", null] })).toBe(true);
    expect(isValidSharedStateValue(null)).toBe(false);
  });
});
