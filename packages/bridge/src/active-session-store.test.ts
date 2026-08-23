import {
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  ActiveSessionStore,
  type PersistedActiveSession,
} from "./active-session-store.js";

const temporaryDirectories: string[] = [];

function createStore(): {
  directory: string;
  file: string;
  store: ActiveSessionStore;
} {
  const directory = mkdtempSync(join(tmpdir(), "ccpocket-active-sessions-"));
  temporaryDirectories.push(directory);
  const file = join(directory, "active-sessions.json");
  return { directory, file, store: new ActiveSessionStore(file) };
}

function session(
  overrides: Partial<PersistedActiveSession> = {},
): PersistedActiveSession {
  return {
    bridgeSessionId: "bridge-1",
    providerSessionId: "provider-1",
    provider: "claude",
    projectPath: "/workspace/project",
    createdAt: "2026-08-23T10:00:00.000Z",
    lastActivityAt: "2026-08-23T11:00:00.000Z",
    lastMessage: "Latest response",
    ...overrides,
  };
}

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

describe("ActiveSessionStore", () => {
  it("persists active session metadata across store instances", () => {
    const { file, store } = createStore();
    store.replace([
      session({
        permissionMode: "acceptEdits",
        sandboxEnabled: true,
        worktreePath: "/workspace/project-worktrees/fix",
        worktreeBranch: "fix/session-list",
      }),
    ]);

    expect(new ActiveSessionStore(file).list()).toEqual([
      session({
        permissionMode: "acceptEdits",
        sandboxEnabled: true,
        worktreePath: "/workspace/project-worktrees/fix",
        worktreeBranch: "fix/session-list",
      }),
    ]);
  });

  it("deduplicates a provider session using the latest record", () => {
    const { file, store } = createStore();
    store.replace([
      session({ lastMessage: "Older response" }),
      session({ bridgeSessionId: "bridge-2", lastMessage: "Latest response" }),
    ]);

    const parsed = JSON.parse(readFileSync(file, "utf-8")) as {
      sessions: PersistedActiveSession[];
    };
    expect(parsed.sessions).toEqual([
      session({ bridgeSessionId: "bridge-2", lastMessage: "Latest response" }),
    ]);
  });

  it("ignores malformed persisted records", () => {
    const { file } = createStore();
    writeFileSync(
      file,
      JSON.stringify({
        version: 1,
        sessions: [session(), { provider: "claude", projectPath: "/missing-id" }],
      }),
      "utf-8",
    );

    expect(new ActiveSessionStore(file).list()).toEqual([session()]);
  });
});
