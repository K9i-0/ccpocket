import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  findLatestCodexThreadForCwd,
  getTrackedCodexThread,
  resolveCodexThreadForCwd,
  saveTrackedCodexThread,
} from "./codex-handoff.js";

const tempRoots: string[] = [];

describe("codex-handoff", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("finds the latest rollout thread for a cwd", () => {
    vi.useFakeTimers();
    const root = mkdtempSync(join(tmpdir(), "ccpocket-codex-sessions-"));
    tempRoots.push(root);
    const sessionsRoot = join(root, ".codex", "sessions", "2026", "04", "05");
    mkdirSync(sessionsRoot, { recursive: true });

    const older = join(
      sessionsRoot,
      "rollout-2026-04-05T09-00-00-thread-old.jsonl",
    );
    writeFileSync(
      older,
      `${JSON.stringify({
        type: "session_meta",
        timestamp: "2026-04-05T13:00:00.000Z",
        payload: {
          id: "thread-old",
          cwd: "/tmp/project-a",
          timestamp: "2026-04-05T13:00:00.000Z",
        },
      })}\n`,
      "utf-8",
    );

    vi.advanceTimersByTime(1000);

    const newer = join(
      sessionsRoot,
      "rollout-2026-04-05T09-05-00-thread-new.jsonl",
    );
    writeFileSync(
      newer,
      `${JSON.stringify({
        type: "session_meta",
        timestamp: "2026-04-05T13:05:00.000Z",
        payload: {
          id: "thread-new",
          cwd: "/tmp/project-a",
          timestamp: "2026-04-05T13:05:00.000Z",
        },
      })}\n`,
      "utf-8",
    );

    const result = findLatestCodexThreadForCwd("/tmp/project-a", {
      sessionsRoot: join(root, ".codex", "sessions"),
    });

    expect(result?.threadId).toBe("thread-new");
  });

  it("saves and reloads tracked threads", () => {
    const root = mkdtempSync(join(tmpdir(), "ccpocket-codex-tracker-"));
    tempRoots.push(root);
    const trackerPath = join(root, ".ccpocket", "codex-tracker.json");

    saveTrackedCodexThread(
      {
        cwd: "/tmp/project-a",
        threadId: "thread-tracked",
        updatedAt: "2026-04-05T13:10:00.000Z",
      },
      trackerPath,
    );

    const result = getTrackedCodexThread("/tmp/project-a", trackerPath);
    expect(result?.threadId).toBe("thread-tracked");
  });

  it("prefers a newer scanned thread over an older tracked one", () => {
    const root = mkdtempSync(join(tmpdir(), "ccpocket-codex-merged-"));
    tempRoots.push(root);
    const trackerPath = join(root, ".ccpocket", "codex-tracker.json");
    const sessionsRoot = join(root, ".codex", "sessions", "2026", "04", "05");
    mkdirSync(sessionsRoot, { recursive: true });

    saveTrackedCodexThread(
      {
        cwd: "/tmp/project-a",
        threadId: "thread-tracked",
        updatedAt: "2026-04-05T13:10:00.000Z",
      },
      trackerPath,
    );

    const rollout = join(
      sessionsRoot,
      "rollout-2026-04-05T09-15-00-thread-scan.jsonl",
    );
    writeFileSync(
      rollout,
      `${JSON.stringify({
        type: "session_meta",
        timestamp: "2026-04-05T13:15:00.000Z",
        payload: {
          id: "thread-scan",
          cwd: "/tmp/project-a",
          timestamp: "2026-04-05T13:15:00.000Z",
        },
      })}\n`,
      "utf-8",
    );

    const result = resolveCodexThreadForCwd("/tmp/project-a", {
      trackerPath,
      sessionsRoot: join(root, ".codex", "sessions"),
    });

    expect(result?.threadId).toBe("thread-scan");
  });
});
