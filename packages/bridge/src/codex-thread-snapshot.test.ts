import { describe, expect, it, vi } from "vitest";
import type { CodexThreadSummary } from "./codex-process.js";
import { CodexThreadSnapshot, type CodexThreadLoader } from "./codex-thread-snapshot.js";

function thread(id: string, updatedAt: number): CodexThreadSummary {
  return {
    id,
    preview: `preview ${id}`,
    createdAt: updatedAt,
    updatedAt,
    cwd: "/repo",
    agentNickname: null,
    agentRole: null,
    gitBranch: null,
    name: null,
  };
}

function pagedLoader(pages: CodexThreadSummary[][]): CodexThreadLoader {
  return async (onPage) => {
    for (let i = 0; i < pages.length; i++) {
      onPage({ data: pages[i], nextCursor: i + 1 < pages.length ? `c${i}` : null });
    }
  };
}

describe("CodexThreadSnapshot", () => {
  it("collects every page sorted newest first", async () => {
    const snapshot = new CodexThreadSnapshot(
      pagedLoader([[thread("b", 2), thread("c", 3)], [thread("a", 1)]]),
    );
    expect(snapshot.isReady).toBe(false);
    const threads = await snapshot.get();
    expect(threads.map((t) => t.id)).toEqual(["c", "b", "a"]);
    expect(snapshot.isReady).toBe(true);
  });

  it("keeps the newest entry of a thread listed twice", async () => {
    const snapshot = new CodexThreadSnapshot(
      pagedLoader([[thread("a", 3), thread("b", 2)], [thread("a", 1)]]),
    );
    const threads = await snapshot.get();
    expect(threads.map((t) => [t.id, t.updatedAt])).toEqual([
      ["a", 3],
      ["b", 2],
    ]);
  });

  it("shares one load between concurrent callers", async () => {
    const loader = vi.fn(pagedLoader([[thread("a", 1)]]));
    const snapshot = new CodexThreadSnapshot(loader);
    snapshot.warm();
    await Promise.all([snapshot.get(), snapshot.get(), snapshot.get()]);
    expect(loader).toHaveBeenCalledTimes(1);
  });

  it("serves the stale snapshot while refreshing in the background", async () => {
    let now = 0;
    let generation = 0;
    const loader = vi.fn<CodexThreadLoader>(async (onPage) => {
      generation += 1;
      onPage({ data: [thread(`g${generation}`, generation)], nextCursor: null });
    });
    const snapshot = new CodexThreadSnapshot(loader, {
      ttlMs: 1000,
      now: () => now,
    });
    expect((await snapshot.get()).map((t) => t.id)).toEqual(["g1"]);

    now = 500;
    expect((await snapshot.get()).map((t) => t.id)).toEqual(["g1"]);
    expect(loader).toHaveBeenCalledTimes(1);

    now = 2000;
    // Stale: answered from the old copy, refreshed behind it.
    expect((await snapshot.get()).map((t) => t.id)).toEqual(["g1"]);
    await vi.waitFor(() => expect(loader).toHaveBeenCalledTimes(2));
    await vi.waitFor(async () =>
      expect((await snapshot.get()).map((t) => t.id)).toEqual(["g2"]),
    );
  });

  it("answers empty during the failure backoff, then retries", async () => {
    let now = 0;
    let fail = true;
    const loader = vi.fn<CodexThreadLoader>(async (onPage) => {
      if (fail) throw new Error("app-server down");
      onPage({ data: [thread("a", 1)], nextCursor: null });
    });
    const snapshot = new CodexThreadSnapshot(loader, {
      failureBackoffMs: 1000,
      now: () => now,
    });
    expect(await snapshot.get()).toEqual([]);
    fail = false;
    now = 500;
    snapshot.warm();
    expect(await snapshot.get()).toEqual([]);
    expect(loader).toHaveBeenCalledTimes(1);

    now = 1500;
    expect((await snapshot.get()).map((t) => t.id)).toEqual(["a"]);
    expect(loader).toHaveBeenCalledTimes(2);
  });
});
