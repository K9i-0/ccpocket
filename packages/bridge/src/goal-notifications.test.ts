import { afterEach, describe, expect, it, vi } from "vitest";
import { GoalNotifications } from "./goal-notifications.js";
import type { CodexGoal, CodexGoalStatus } from "./parser.js";

const goal = (status: CodexGoalStatus): CodexGoal => ({
  threadId: "thread", objective: "Ship", status, tokenBudget: null,
  tokensUsed: 0, timeUsedSeconds: 0, createdAt: 1, updatedAt: 2,
});

describe("GoalNotifications", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("suppresses active turns by default and permits explicit opt-in", () => {
    vi.stubEnv("BRIDGE_NOTIFY_GOAL_TURN_COMPLETED", "");
    const policy = new GoalNotifications();
    policy.baseline(goal("active"));
    expect(policy.result()).toBe("none");
    vi.stubEnv("BRIDGE_NOTIFY_GOAL_TURN_COMPLETED", "true");
    const enabled = new GoalNotifications();
    enabled.baseline(goal("active"));
    expect(enabled.result()).toBe("goal_progress");
  });

  it("does not treat unknown state as no goal", () => {
    const policy = new GoalNotifications();
    expect(policy.result()).toBe("none");
    policy.baseline(null);
    expect(policy.result()).toBeUndefined();
  });

  it.each(["before", "after"])("notifies completion once %s the result", (order) => {
    const policy = new GoalNotifications(false);
    policy.baseline(goal("active"));
    policy.beginTurn();
    if (order === "after") expect(policy.result()).toBe("none");
    expect(policy.update(goal("complete"))).toBe("goal_complete");
    if (order === "before") expect(policy.result()).toBe("none");
    expect(policy.update({ ...goal("complete"), tokensUsed: 100 })).toBe("none");
    policy.beginTurn();
    expect(policy.result()).toBeUndefined();
  });

  it.each([
    ["blocked", "goal_blocked"],
    ["budgetLimited", "goal_budget_limited"],
    ["usageLimited", "goal_usage_limited"],
    ["paused", "none"],
  ] as const)("handles %s without claiming success", (status, expected) => {
    const policy = new GoalNotifications(true);
    policy.baseline(goal("active"));
    expect(policy.update(goal(status))).toBe(expected);
    expect(policy.result()).toBe("none");
    expect(policy.update(goal(status))).toBe("none");
    policy.update(goal("active"));
    expect(policy.update(goal(status))).toBe(expected);
  });

  it("does not notify for restored terminal snapshots", () => {
    const policy = new GoalNotifications();
    policy.baseline(goal("complete"));
    expect(policy.update(goal("complete"))).toBe("none");
    expect(new GoalNotifications().update(goal("complete"))).toBe("none");
  });

  it("resumes ordinary notifications after a goal is cleared", () => {
    const policy = new GoalNotifications();
    policy.baseline(goal("active"));
    expect(policy.update(null)).toBe("none");
    policy.beginTurn();
    expect(policy.result()).toBeUndefined();
  });
});
