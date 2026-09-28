import type { CodexGoal } from "./parser.js";

export type GoalNotification = "none" | "goal_progress" | "goal_complete" | "goal_blocked" | "goal_budget_limited" | "goal_usage_limited";

/** Per-session live state; snapshots establish a baseline without notifying. */
export class GoalNotifications {
  goal: CodexGoal | null | undefined;
  private turnHadGoal = false;

  constructor(private readonly notifyTurns = process.env.BRIDGE_NOTIFY_GOAL_TURN_COMPLETED === "true") {}

  baseline(goal: CodexGoal | null): void {
    this.goal = goal;
    this.turnHadGoal = goal?.status === "active";
  }

  beginTurn(): void {
    this.turnHadGoal = this.goal != null && this.goal.status !== "complete";
  }

  update(goal: CodexGoal | null): GoalNotification {
    const previous = this.goal;
    this.goal = goal;
    if (goal?.status === "active") this.turnHadGoal = true;
    if (!goal || (previous?.createdAt === goal.createdAt && previous.status === goal.status)) return "none";
    // A first snapshot of a stopped goal must not replay an old notification.
    if (previous === undefined && goal.status !== "active") return "none";
    switch (goal.status) {
      case "complete": return "goal_complete";
      case "blocked": return "goal_blocked";
      case "budgetLimited": return "goal_budget_limited";
      case "usageLimited": return "goal_usage_limited";
      default: return "none";
    }
  }

  result(): GoalNotification | undefined {
    if (this.goal === undefined) return "none";
    if (this.goal?.status === "active") return this.notifyTurns ? "goal_progress" : "none";
    if (this.turnHadGoal || (this.goal != null && this.goal.status !== "complete")) return "none";
    return undefined;
  }
}
