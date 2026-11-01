import { describe, expect, it } from "vitest";
import { CodexBackgroundTracker } from "./codex-background-tracker.js";

const OWN = "thread-main";

function tracker(): CodexBackgroundTracker {
  return new CodexBackgroundTracker(() => OWN);
}

function terminalItem(id: string, source = "unifiedExecStartup") {
  return {
    type: "commandExecution",
    id,
    command: "npm run dev",
    cwd: "/tmp",
    processId: "pty-1",
    source,
    status: "inProgress",
  };
}

describe("CodexBackgroundTracker", () => {
  it("reports a unified exec terminal only after its turn completes", () => {
    const t = tracker();
    t.observe("turn/started", { threadId: OWN, turn: { id: "turn-1" } });
    t.observe("item/started", {
      threadId: OWN,
      turnId: "turn-1",
      item: terminalItem("cmd-1"),
    });
    expect(t.tasks()).toEqual([]);

    t.observe("turn/completed", { threadId: OWN, turn: { id: "turn-1" } });
    expect(t.tasks()).toEqual([
      { taskId: "cmd-1", taskType: "codex_terminal", description: "npm run dev" },
    ]);

    // Still background while a later turn runs.
    t.observe("turn/started", { threadId: OWN, turn: { id: "turn-2" } });
    expect(t.tasks()).toHaveLength(1);

    t.observe("item/completed", {
      threadId: OWN,
      turnId: "turn-1",
      item: { ...terminalItem("cmd-1"), status: "completed" },
    });
    expect(t.tasks()).toEqual([]);
  });

  it("ignores synchronous commands and commands without a process", () => {
    const t = tracker();
    t.observe("turn/started", { threadId: OWN, turn: { id: "turn-1" } });
    t.observe("item/started", {
      threadId: OWN,
      turnId: "turn-1",
      item: terminalItem("cmd-1", "agent"),
    });
    t.observe("item/started", {
      threadId: OWN,
      turnId: "turn-1",
      item: { ...terminalItem("cmd-2"), processId: null },
    });
    t.observe("turn/completed", { threadId: OWN, turn: { id: "turn-1" } });

    expect(t.tasks()).toEqual([]);
  });

  it("tracks child agent threads and consumes their notifications", () => {
    const t = tracker();
    t.observe("turn/started", { threadId: OWN, turn: { id: "turn-1" } });
    expect(
      t.observe("thread/started", {
        thread: {
          id: "child-1",
          parentThreadId: OWN,
          agentNickname: "Scout",
          agentRole: "explorer",
        },
      }),
    ).toBe(true);
    // Spawned by the running turn: foreground.
    expect(t.tasks()).toEqual([]);

    t.observe("turn/completed", { threadId: OWN, turn: { id: "turn-1" } });
    expect(t.tasks()).toEqual([
      {
        taskId: "child-1",
        taskType: "codex_agent",
        description: "Scout",
        subagentType: "explorer",
      },
    ]);

    expect(
      t.observe("turn/completed", { threadId: "child-1", turn: { id: "c-1" } }),
    ).toBe(true);
    expect(t.tasks()).toEqual([]);

    t.observe("thread/status/changed", {
      threadId: "child-1",
      status: { type: "active", activeFlags: [] },
    });
    expect(t.tasks()).toHaveLength(1);

    t.observe("thread/status/changed", {
      threadId: "child-1",
      status: { type: "idle" },
    });
    expect(t.tasks()).toEqual([]);
  });

  it("leaves unrelated threads to the caller", () => {
    const t = tracker();
    expect(
      t.observe("thread/started", {
        thread: { id: "other", parentThreadId: "someone-else" },
      }),
    ).toBe(false);
    expect(t.observe("turn/started", { threadId: "other", turn: {} })).toBe(
      false,
    );
    expect(t.tasks()).toEqual([]);
  });

  it("does nothing before its own thread is known", () => {
    const t = new CodexBackgroundTracker(() => null);
    expect(
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      }),
    ).toBe(false);
    expect(t.tasks()).toEqual([]);
  });

  it("clears everything on reset", () => {
    const t = tracker();
    t.observe("item/started", { threadId: OWN, item: terminalItem("cmd-1") });
    expect(t.tasks()).toHaveLength(1);
    t.reset();
    expect(t.tasks()).toEqual([]);
  });
});
