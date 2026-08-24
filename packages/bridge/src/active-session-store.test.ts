import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  ActiveSessionStore,
  activeSessionStoreFileForPort,
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
  it("scopes the default store by Bridge port", () => {
    expect(activeSessionStoreFileForPort(8765)).toBe(
      join(homedir(), ".ccpocket", "active-sessions.json"),
    );
    expect(activeSessionStoreFileForPort(8766)).toBe(
      join(homedir(), ".ccpocket", "active-sessions-8766.json"),
    );
    expect(activeSessionStoreFileForPort(8766, "/tmp/custom.json")).toBe(
      "/tmp/custom.json",
    );
  });

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

  it.skipIf(process.platform === "win32")(
    "keeps session metadata private on disk",
    () => {
      const { directory, file, store } = createStore();
      store.replace([session()]);

      expect(statSync(directory).mode & 0o777).toBe(0o700);
      expect(statSync(file).mode & 0o777).toBe(0o600);
    },
  );

  it.skipIf(process.platform === "win32")(
    "preserves permissions on an existing custom parent directory",
    () => {
      const directory = mkdtempSync(join(tmpdir(), "ccpocket-active-custom-"));
      temporaryDirectories.push(directory);
      chmodSync(directory, 0o750);
      const file = join(directory, "active-sessions.json");

      new ActiveSessionStore(file).replace([session()]);

      expect(statSync(directory).mode & 0o777).toBe(0o750);
      expect(statSync(file).mode & 0o777).toBe(0o600);
    },
  );

  it("retries the same update after a transient write failure", () => {
    const directory = mkdtempSync(join(tmpdir(), "ccpocket-active-retry-"));
    temporaryDirectories.push(directory);
    const blockedParent = join(directory, "blocked");
    writeFileSync(blockedParent, "not a directory", "utf-8");
    const file = join(blockedParent, "active-sessions.json");
    const store = new ActiveSessionStore(file);

    expect(() => store.replace([session()])).toThrow();
    rmSync(blockedParent);
    mkdirSync(blockedParent);
    expect(() => store.replace([session()])).not.toThrow();
    expect(new ActiveSessionStore(file).list()).toEqual([session()]);
  });
});
