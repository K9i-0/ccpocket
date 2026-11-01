import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { BackgroundCompletionGate } from "./background-completion-gate.js";

describe("BackgroundCompletionGate", () => {
  let settled: boolean;
  let released: Array<[string, string]>;
  let gate: BackgroundCompletionGate<string>;

  beforeEach(() => {
    vi.useFakeTimers();
    settled = false;
    released = [];
    gate = new BackgroundCompletionGate<string>({
      settleMs: 2000,
      isSettled: () => settled,
      release: (sessionId, completion) => released.push([sessionId, completion]),
    });
  });

  afterEach(() => {
    gate.dispose();
    vi.useRealTimers();
  });

  it("does not hold a completion without background work", () => {
    expect(gate.hold("s1", "done", false)).toBe(false);
    expect(gate.isHolding("s1")).toBe(false);
  });

  it("releases the latest held completion once the session settles", () => {
    expect(gate.hold("s1", "launched", true)).toBe(true);
    expect(gate.hold("s1", "still waiting", true)).toBe(true);

    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(1999);
    expect(released).toEqual([]);
    vi.advanceTimersByTime(1);

    expect(released).toEqual([["s1", "still waiting"]]);
    expect(gate.isHolding("s1")).toBe(false);
  });

  it("keeps holding when work resumes within the settle window", () => {
    gate.hold("s1", "launched", true);

    // The task set empties for a moment before a subagent resumes.
    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(500);
    settled = false;
    gate.update("s1");
    vi.advanceTimersByTime(5000);

    expect(released).toEqual([]);
    expect(gate.isHolding("s1")).toBe(true);
  });

  it("drops the held completion when a later one is notified directly", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");

    // A follow-up turn finished with no background work left.
    expect(gate.hold("s1", "bg complete", false)).toBe(false);
    vi.advanceTimersByTime(5000);

    expect(released).toEqual([]);
  });

  it("does not release if the session is busy again when the timer fires", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    settled = false;
    vi.advanceTimersByTime(2000);

    expect(released).toEqual([]);
    expect(gate.isHolding("s1")).toBe(true);
  });

  it("discards held completions", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    gate.discard("s1");
    vi.advanceTimersByTime(5000);

    expect(released).toEqual([]);
  });
});
