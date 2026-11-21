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
    t.observe("thread/started", {
      thread: { id: "child-1", parentThreadId: OWN },
    });
    expect(t.tasks()).toHaveLength(2);
    t.reset();
    expect(t.tasks()).toEqual([]);
    // A forgotten child is no longer consumed.
    expect(t.observe("turn/started", { threadId: "child-1", turn: {} })).toBe(
      false,
    );
  });

  it("resets the active turn so later work is not treated as foreground", () => {
    const t = tracker();
    t.observe("turn/started", { threadId: OWN, turn: { id: "turn-1" } });
    t.reset();
    t.observe("item/started", {
      threadId: OWN,
      turnId: "turn-1",
      item: terminalItem("cmd-1"),
    });
    expect(t.tasks()).toHaveLength(1);
  });

  it("does not observe own-thread notifications before its thread is known", () => {
    let own: string | null = null;
    const t = new CodexBackgroundTracker(() => own);
    expect(t.observe("item/started", { item: terminalItem("cmd-1") })).toBe(
      false,
    );
    own = OWN;
    expect(t.tasks()).toEqual([]);
  });

  describe("thread/started", () => {
    it.each([
      ["its own thread", { thread: { id: OWN, parentThreadId: OWN } }],
      ["a thread without an id", { thread: { parentThreadId: OWN } }],
      ["an empty id", { thread: { id: "", parentThreadId: OWN } }],
      ["a non-string id", { thread: { id: 7, parentThreadId: OWN } }],
      ["a missing thread", {}],
      ["an array in place of the thread", { thread: [{ id: "x" }] }],
      ["a string in place of the thread", { thread: "child-1" }],
    ])("does not track %s as a child", (_label, params) => {
      const t = tracker();
      expect(t.observe("thread/started", params)).toBe(false);
      expect(t.tasks()).toEqual([]);
    });

    it("keeps consuming a known child that is announced again without a parent", () => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      expect(t.observe("thread/started", { thread: { id: "child-1" } })).toBe(
        true,
      );
    });

    it("omits the description and type when the child has no nickname or role", () => {
      const t = tracker();
      t.observe("thread/started", {
        thread: {
          id: "child-1",
          parentThreadId: OWN,
          agentNickname: "",
          agentRole: 3,
        },
      });
      expect(t.tasks()).toEqual([{ taskId: "child-1", taskType: "codex_agent" }]);
    });

    it("describes a child by its role when it has no nickname", () => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN, agentRole: "explorer" },
      });
      expect(t.tasks()).toEqual([
        {
          taskId: "child-1",
          taskType: "codex_agent",
          description: "explorer",
          subagentType: "explorer",
        },
      ]);
    });
  });

  describe("child agent notifications", () => {
    function withIdleChild(): CodexBackgroundTracker {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      t.observe("turn/completed", { threadId: "child-1", turn: { id: "c-1" } });
      expect(t.tasks()).toEqual([]);
      return t;
    }

    it("marks the child active again when it starts a turn", () => {
      const t = withIdleChild();
      expect(
        t.observe("turn/started", { threadId: "child-1", turn: { id: "c-2" } }),
      ).toBe(true);
      expect(t.tasks()).toHaveLength(1);
    });

    it("does not let a child's turn change the parent's active turn", () => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      t.observe("turn/started", { threadId: "child-1", turn: { id: "c-1" } });
      t.observe("item/started", {
        threadId: OWN,
        turnId: "c-1",
        item: terminalItem("cmd-1"),
      });
      // No own turn is running, so the terminal is background.
      expect(t.tasks().map((task) => task.taskId)).toEqual(["cmd-1", "child-1"]);
    });

    it("forgets a closed child and stops consuming its notifications", () => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      expect(t.observe("thread/closed", { threadId: "child-1" })).toBe(true);
      expect(t.tasks()).toEqual([]);
      expect(
        t.observe("turn/started", { threadId: "child-1", turn: { id: "c-2" } }),
      ).toBe(false);
      expect(t.tasks()).toEqual([]);
    });

    it("ignores other notifications of a child", () => {
      const t = withIdleChild();
      expect(
        t.observe("item/started", {
          threadId: "child-1",
          item: terminalItem("cmd-1"),
        }),
      ).toBe(true);
      expect(t.observe("", { threadId: "child-1" })).toBe(true);
      expect(t.tasks()).toEqual([]);
    });

    it.each([
      ["a missing status", {}],
      ["a status without a type", { status: {} }],
      ["a non-string type", { status: { type: 1 } }],
      ["an array status", { status: ["active"] }],
    ])("treats %s as not active", (_label, extra) => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      t.observe("thread/status/changed", { threadId: "child-1", ...extra });
      expect(t.tasks()).toEqual([]);
    });

    it.each([
      ["thread.id", { thread: { id: "child-1" } }],
      ["turn.threadId", { turn: { id: "c-1", threadId: "child-1" } }],
      [
        "threadId over thread.id",
        { threadId: "child-1", thread: { id: OWN } },
      ],
      [
        "thread.id over turn.threadId",
        { thread: { id: "child-1" }, turn: { threadId: OWN } },
      ],
    ])("finds the child thread in %s", (_label, params) => {
      const t = tracker();
      t.observe("thread/started", {
        thread: { id: "child-1", parentThreadId: OWN },
      });
      expect(t.observe("turn/completed", params)).toBe(true);
      expect(t.tasks()).toEqual([]);
    });
  });

  describe("terminals", () => {
    it("treats notifications without a thread id as its own", () => {
      const t = tracker();
      expect(t.observe("item/started", { item: terminalItem("cmd-1") })).toBe(
        false,
      );
      expect(t.tasks()).toHaveLength(1);
    });

    it("accepts differently cased and separated type and source names", () => {
      const t = tracker();
      t.observe("item/started", {
        item: {
          ...terminalItem("cmd-1"),
          type: "command_execution",
          source: "unified-exec startup",
        },
      });
      expect(t.tasks()).toHaveLength(1);
      t.observe("item/completed", {
        item: { type: "Command Execution", id: "cmd-1" },
      });
      expect(t.tasks()).toEqual([]);
    });

    it.each([
      ["another item type", { ...terminalItem("cmd-1"), type: "fileChange" }],
      ["a non-string type", { ...terminalItem("cmd-1"), type: 5 }],
      ["an item without an id", { ...terminalItem(""), id: undefined }],
      ["an empty id", terminalItem("")],
      ["a non-string source", { ...terminalItem("cmd-1"), source: 1 }],
      ["an empty process id", { ...terminalItem("cmd-1"), processId: "" }],
    ])("does not track %s", (_label, item) => {
      const t = tracker();
      t.observe("item/started", { item });
      expect(t.tasks()).toEqual([]);
    });

    it.each([
      ["a missing item", {}],
      ["an array item", { item: [terminalItem("cmd-1")] }],
      ["a null item", { item: null }],
    ])("ignores %s on start and completion", (_label, params) => {
      const t = tracker();
      expect(t.observe("item/started", params)).toBe(false);
      expect(t.observe("item/completed", params)).toBe(false);
      expect(t.tasks()).toEqual([]);
    });

    it("keeps the terminal when a different item completes", () => {
      const t = tracker();
      t.observe("item/started", { item: terminalItem("cmd-1") });
      t.observe("item/completed", {
        item: { type: "fileChange", id: "cmd-1" },
      });
      t.observe("item/completed", { item: { type: "commandExecution" } });
      t.observe("item/completed", {
        item: { type: "commandExecution", id: "cmd-2" },
      });
      expect(t.tasks().map((task) => task.taskId)).toEqual(["cmd-1"]);
    });

    it("omits the description when the command is missing", () => {
      const t = tracker();
      t.observe("item/started", {
        item: { ...terminalItem("cmd-1"), command: undefined },
      });
      expect(t.tasks()).toEqual([{ taskId: "cmd-1", taskType: "codex_terminal" }]);
    });

    it("attributes a terminal to the notification's turn over the active turn", () => {
      const t = tracker();
      t.observe("turn/started", { threadId: OWN, turn: { id: "turn-2" } });
      // A late notification from an earlier turn is already background.
      t.observe("item/started", {
        turnId: "turn-1",
        item: terminalItem("cmd-1"),
      });
      // Without a turn id it belongs to the turn in progress.
      t.observe("item/started", { item: terminalItem("cmd-2") });
      expect(t.tasks().map((task) => task.taskId)).toEqual(["cmd-1"]);
    });

    it("treats work as foreground during a turn that has no id", () => {
      const t = tracker();
      t.observe("turn/started", { threadId: OWN });
      t.observe("item/started", { item: terminalItem("cmd-1") });
      t.observe("item/started", {
        turnId: "turn-9",
        item: terminalItem("cmd-2"),
      });
      expect(t.tasks().map((task) => task.taskId)).toEqual(["cmd-2"]);

      t.observe("turn/completed", { threadId: OWN });
      expect(t.tasks().map((task) => task.taskId)).toEqual(["cmd-1", "cmd-2"]);
    });

    it("truncates descriptions longer than 200 characters", () => {
      const t = tracker();
      t.observe("item/started", {
        item: { ...terminalItem("exact"), command: "x".repeat(200) },
      });
      t.observe("item/started", {
        item: { ...terminalItem("long"), command: "y".repeat(201) },
      });
      const [exact, long] = t.tasks();
      expect(exact.description).toBe("x".repeat(200));
      expect(long.description).toBe(`${"y".repeat(199)}…`);
    });
  });
});
