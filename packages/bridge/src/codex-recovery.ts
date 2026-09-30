/** Session-local recovery; never persists or grants permission to resume a goal. */
export interface CodexRecoveryState {
  enabled: boolean;
  phase: "off" | "armed" | "waiting" | "exhausted" | "blocked";
  attempts: number;
  maxAttempts: number;
  retryAt: number | null;
  reason: string | null;
}

export function rateLimitFailure(error: unknown): { reason: string; retryAt?: number } | null {
  let matched = false;
  let upstreamRetry = false;
  let retryAt: number | undefined;
  const messages: string[] = [];
  const visit = (value: unknown, depth: number): void => {
    if (!value || typeof value !== "object" || depth > 4) return;
    const record = value as Record<string, unknown>;
    if (record.willRetry === true) upstreamRetry = true;
    if (typeof record.message === "string") {
      messages.push(record.message);
      if (/\b(?:usage[ _-]?limit|rate[ _-]?limit|too many requests)\b/i.test(record.message) || /\b(?:HTTP|status(?: code)?)\s*[:=]?\s*429\b/i.test(record.message)) matched = true;
    }
    for (const key of ["code", "statusCode", "httpStatusCode", "type", "codexErrorInfo"]) {
      const v = record[key];
      if (v === 429 || v === "429" || v === "usageLimitExceeded" || v === "rateLimitExceeded" || v === "usage_limit" || v === "rate_limit") matched = true;
    }
    for (const key of ["retryAt", "resetsAt", "reset_at", "retry_at"]) {
      const raw = record[key];
      const timestamp = typeof raw === "number" ? (raw < 1e12 ? raw * 1000 : raw) : typeof raw === "string" ? Date.parse(raw) : NaN;
      if (Number.isFinite(timestamp) && timestamp > Date.now()) retryAt = Math.max(retryAt ?? 0, timestamp);
    }
    if (typeof record.retryAfterSeconds === "number" && Number.isFinite(record.retryAfterSeconds) && record.retryAfterSeconds > 0) {
      retryAt = Math.max(retryAt ?? 0, Date.now() + record.retryAfterSeconds * 1000);
    }
    for (const key of ["error", "data", "codexErrorInfo", "httpConnectionFailed", "responseStreamDisconnected"]) visit(record[key], depth + 1);
  };
  visit(error, 0);
  return matched && !upstreamRetry ? { reason: (messages[0] ?? "Codex usage limit").slice(0, 600), retryAt } : null;
}

export class CodexRecovery<T> {
  private value: CodexRecoveryState = { enabled: false, phase: "off", attempts: 0, maxAttempts: 5, retryAt: null, reason: null };
  private timer?: ReturnType<typeof setTimeout>;
  private generation = 0;

  constructor(private readonly hooks: {
    changed: (state: CodexRecoveryState) => void;
    canResume: () => Promise<boolean>;
    dispatch: (input: T) => boolean;
    resetAt?: () => Promise<number | undefined>;
  }) {}

  get state(): CodexRecoveryState { return { ...this.value }; }
  get version(): number { return this.generation; }

  private publish(patch: Partial<CodexRecoveryState>): void {
    if (Object.entries(patch).every(([key, value]) => this.value[key as keyof CodexRecoveryState] === value)) return;
    this.value = { ...this.value, ...patch };
    this.hooks.changed(this.state);
  }

  cancel(): void {
    this.generation++;
    clearTimeout(this.timer);
    this.timer = undefined;
    this.publish({ phase: this.value.enabled ? "armed" : "off", retryAt: null, reason: null });
  }

  setEnabled(enabled: boolean): void {
    this.cancel();
    this.publish({ enabled, phase: enabled ? "armed" : "off", attempts: 0 });
  }

  manualInput(): void {
    this.cancel();
    this.publish({ attempts: 0 });
  }

  schedule(error: unknown, input: T): boolean {
    const failure = rateLimitFailure(error);
    if (!this.value.enabled || !failure || this.value.phase === "waiting") return false;
    if (this.value.attempts >= this.value.maxAttempts) {
      this.publish({ phase: "exhausted", retryAt: null, reason: failure.reason });
      return false;
    }
    const generation = ++this.generation;
    const fallback = Date.now() + Math.min(300_000, 10_000 * 2 ** this.value.attempts);
    const retryAt = Math.max(fallback, failure.retryAt ?? 0);
    this.publish({ phase: "waiting", reason: failure.reason, retryAt });
    void this.prepare(generation, retryAt, input);
    return true;
  }

  private async prepare(generation: number, retryAt: number, input: T): Promise<void> {
    try { retryAt = Math.max(retryAt, (await this.hooks.resetAt?.()) ?? 0); } catch { /* Fall back to the error/reset policy. */ }
    if (generation !== this.generation) return;
    this.publish({ retryAt });
    this.arm(generation, retryAt, input);
  }

  private arm(generation: number, retryAt: number, input: T): void {
    // Node timers overflow above ~24.8 days. Long reset windows must not fire early.
    this.timer = setTimeout(() => {
      this.timer = undefined;
      if (generation !== this.generation) return;
      if (Date.now() < retryAt) { this.arm(generation, retryAt, input); return; }
      void this.fire(generation, input);
    }, Math.min(2_147_483_647, Math.max(0, retryAt - Date.now())));
    this.timer.unref?.();
  }

  private async fire(generation: number, input: T): Promise<void> {
    let allowed = false;
    try { allowed = await this.hooks.canResume(); } catch { /* Unknown goal/transport state must not execute work. */ }
    if (generation !== this.generation || !this.value.enabled) return;
    if (!allowed || !this.hooks.dispatch(input)) {
      this.publish({ phase: "blocked", retryAt: null, reason: "Automatic recovery stopped: session, goal, or approval state requires attention." });
      return;
    }
    this.publish({ phase: "armed", attempts: this.value.attempts + 1, retryAt: null });
  }
}
