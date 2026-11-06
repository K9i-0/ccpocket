/**
 * Holds a session's "completed" notification while background agents are
 * still running, and releases the latest held completion once the session
 * settles.
 *
 * Claude ends a turn with a result even when background agents are still
 * live, and starts a follow-up turn on its own when they report back.
 * Notifying on each of those results repeats the push for one piece of work.
 * Shells and monitors do not hold the push: they may run indefinitely. The
 * agent set can also empty for a moment before an agent resumes or a
 * follow-up turn starts, so the release waits for the session to stay
 * settled for `settleMs`.
 */
export interface BackgroundCompletionGateOptions<T> {
  settleMs: number;
  /** True when the session is idle with no background work. */
  isSettled: (sessionId: string) => boolean;
  release: (sessionId: string, completion: T) => void;
}

export class BackgroundCompletionGate<T> {
  private readonly held = new Map<string, T>();
  private readonly timers = new Map<string, ReturnType<typeof setTimeout>>();

  constructor(private readonly options: BackgroundCompletionGateOptions<T>) {}

  /**
   * Called for each successful completion. Returns true when it is held;
   * false when the caller should notify now (any older held one is dropped).
   */
  hold(sessionId: string, completion: T, hasBackgroundWork: boolean): boolean {
    this.cancelTimer(sessionId);
    if (!hasBackgroundWork) {
      this.held.delete(sessionId);
      return false;
    }
    this.held.set(sessionId, completion);
    return true;
  }

  /** Re-evaluate after the session's status or background tasks changed. */
  update(sessionId: string): void {
    if (!this.held.has(sessionId)) return;
    if (!this.options.isSettled(sessionId)) {
      this.cancelTimer(sessionId);
      return;
    }
    if (this.timers.has(sessionId)) return;
    const timer = setTimeout(() => {
      this.timers.delete(sessionId);
      if (!this.options.isSettled(sessionId)) return;
      const completion = this.held.get(sessionId);
      this.held.delete(sessionId);
      if (completion !== undefined) this.options.release(sessionId, completion);
    }, this.options.settleMs);
    timer.unref?.();
    this.timers.set(sessionId, timer);
  }

  /** Drop a held completion (error, stop, or session teardown). */
  discard(sessionId: string): void {
    this.cancelTimer(sessionId);
    this.held.delete(sessionId);
  }

  isHolding(sessionId: string): boolean {
    return this.held.has(sessionId);
  }

  dispose(): void {
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
    this.held.clear();
  }

  private cancelTimer(sessionId: string): void {
    const timer = this.timers.get(sessionId);
    if (timer === undefined) return;
    clearTimeout(timer);
    this.timers.delete(sessionId);
  }
}
