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
    expect(gate.isHolding("s1")).toBe(false);
  });

  it("stops holding once a later completion is notified directly", () => {
    gate.hold("s1", "launched", true);
    expect(gate.hold("s1", "bg complete", false)).toBe(false);
    expect(gate.isHolding("s1")).toBe(false);

    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(5000);
    expect(released).toEqual([]);
  });

  it("restarts the settle window when a newer completion is held", () => {
    gate.hold("s1", "first", true);
    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(1500);

    // A follow-up turn ends with background work again.
    gate.hold("s1", "second", true);
    gate.update("s1");
    vi.advanceTimersByTime(1999);
    expect(released).toEqual([]);
    vi.advanceTimersByTime(1);

    expect(released).toEqual([["s1", "second"]]);
  });

  it("restarts the settle window after the session was busy in between", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(1500);

    settled = false;
    gate.update("s1");
    settled = true;
    gate.update("s1");

    // The first window would have ended here.
    vi.advanceTimersByTime(500);
    expect(released).toEqual([]);
    expect(gate.isHolding("s1")).toBe(true);

    vi.advanceTimersByTime(1500);
    expect(released).toEqual([["s1", "launched"]]);
  });

  it("releases on a later settle after a window ended while busy", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    settled = false;
    vi.advanceTimersByTime(2000);
    expect(released).toEqual([]);

    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(2000);

    expect(released).toEqual([["s1", "launched"]]);
    expect(gate.isHolding("s1")).toBe(false);
  });

  it("does not extend the window on repeated updates and releases once", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(1000);
    gate.update("s1");
    expect(vi.getTimerCount()).toBe(1);
    vi.advanceTimersByTime(1000);

    expect(released).toEqual([["s1", "launched"]]);
    vi.advanceTimersByTime(5000);
    expect(released).toHaveLength(1);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("schedules nothing for a session that holds no completion", () => {
    settled = true;
    gate.update("s1");
    expect(vi.getTimerCount()).toBe(0);
    vi.advanceTimersByTime(5000);
    expect(released).toEqual([]);
  });

  it("cancels the pending release when a completion is discarded", () => {
    gate.hold("s1", "launched", true);
    settled = true;
    gate.update("s1");
    gate.discard("s1");
    expect(vi.getTimerCount()).toBe(0);

    // A new completion gets a full window of its own.
    gate.hold("s1", "again", true);
    gate.update("s1");
    vi.advanceTimersByTime(1999);
    expect(released).toEqual([]);
    vi.advanceTimersByTime(1);
    expect(released).toEqual([["s1", "again"]]);
  });

  it("gates each session independently", () => {
    gate.hold("s1", "one", true);
    gate.hold("s2", "two", true);
    settled = true;
    gate.update("s1");
    vi.advanceTimersByTime(1000);
    gate.update("s2");
    gate.discard("s1");
    vi.advanceTimersByTime(2000);

    expect(released).toEqual([["s2", "two"]]);
    expect(gate.isHolding("s1")).toBe(false);
  });

  it("drops held completions and pending releases on dispose", () => {
    gate.hold("s1", "one", true);
    gate.hold("s2", "two", true);
    settled = true;
    gate.update("s1");
    gate.dispose();

    expect(gate.isHolding("s1")).toBe(false);
    expect(gate.isHolding("s2")).toBe(false);
    expect(vi.getTimerCount()).toBe(0);
    vi.advanceTimersByTime(5000);
    expect(released).toEqual([]);

    // The gate keeps working for completions held afterwards.
    gate.hold("s1", "later", true);
    gate.update("s1");
    vi.advanceTimersByTime(2000);
    expect(released).toEqual([["s1", "later"]]);
  });
});
