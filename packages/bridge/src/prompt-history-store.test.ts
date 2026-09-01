import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { describe, expect, it, afterEach } from "vitest";
import {
  detectPromptCommandKind,
  promptHistoryStoreFileForPort,
  promptHistoryId,
  PromptHistoryStore,
} from "./prompt-history-store.js";

let tempDir: string | undefined;

async function makeStore(): Promise<PromptHistoryStore> {
  tempDir = await mkdtemp(join(tmpdir(), "ccpocket-prompt-history-"));
  const store = new PromptHistoryStore(join(tempDir, "history.json"));
  await store.init();
  return store;
}

afterEach(async () => {
  if (tempDir) {
    await rm(tempDir, { recursive: true, force: true });
    tempDir = undefined;
  }
});

describe("PromptHistoryStore", () => {
  it("uses a separate default file for non-default bridge ports", () => {
    expect(promptHistoryStoreFileForPort(8765)).toContain(
      "prompt-history-v2.json",
    );
    expect(promptHistoryStoreFileForPort(8766)).toContain(
      "prompt-history-v2-8766.json",
    );
    expect(promptHistoryStoreFileForPort(8766, "/tmp/custom.json")).toBe(
      "/tmp/custom.json",
    );
  });

  it("keeps a stable bridge instance id in the store file", async () => {
    const store = await makeStore();
    const id = store.bridgeInstanceId;

    const reopened = new PromptHistoryStore(join(tempDir!, "history.json"));
    await reopened.init();

    expect(reopened.bridgeInstanceId).toBe(id);
  });

  it("records prompts by stable text and project key", async () => {
    const store = await makeStore();

    const first = await store.record({
      text: "  /test command  ",
      projectPath: "/repo",
      clientId: "phone",
      clientName: "iPhone",
      sessionId: "session-a",
      usedAt: "2026-01-01T00:00:00.000Z",
    });
    const second = await store.record({
      text: "/test command",
      projectPath: "/repo",
      clientId: "phone",
      sessionId: "session-a",
      usedAt: "2026-01-01T00:01:00.000Z",
    });

    expect(second.id).toBe(first.id);
    expect(store.list()).toHaveLength(1);
    expect(store.list()[0]).toMatchObject({
      totalUseCount: 2,
      commandKind: "slash",
    });
    expect(store.list()[0].clientStats.phone.useCount).toBe(2);
    expect(store.list()[0].sessionStats["session-a"].useCount).toBe(2);
  });

  it("keeps prompts separate for Projects sharing a primary path", async () => {
    const store = await makeStore();

    const first = await store.record({
      text: "same prompt",
      projectPath: "/shared/primary",
      projectId: "project-a",
      projectName: "Frontend",
      clientId: "phone",
    });
    const second = await store.record({
      text: "same prompt",
      projectPath: "/shared/primary",
      projectId: "project-b",
      projectName: "Backend",
      clientId: "phone",
    });

    expect(second.id).not.toBe(first.id);
    expect(store.list()).toHaveLength(2);
    expect(store.list().map((entry) => entry.projectName)).toEqual([
      "Frontend",
      "Backend",
    ]);
  });

  it("keeps favorite and deletion timestamps as field-level conflicts", async () => {
    const store = await makeStore();
    const entry = await store.record({
      text: "hello",
      projectPath: "/repo",
      clientId: "phone",
    });

    await store.mergeClientEntries(
      [
        {
          id: entry.id,
          text: "hello",
          projectPath: "/repo",
          totalUseCount: 3,
          isFavorite: true,
          favoriteUpdatedAt: "2026-01-02T00:00:00.000Z",
          updatedAt: "2026-01-02T00:00:00.000Z",
          deletedAt: "2026-01-03T00:00:00.000Z",
        },
      ],
    );

    const merged = store.list(true)[0];
    expect(merged.totalUseCount).toBe(4);
    expect(merged.isFavorite).toBe(true);
    expect(merged.deletedAt).toBe("2026-01-03T00:00:00.000Z");
    expect(store.list()).toHaveLength(0);
  });

  it("replaces entries when importing legacy v1 history", async () => {
    const store = await makeStore();
    await store.record({ text: "old", projectPath: "/repo", clientId: "phone" });

    await store.importEntries(
      [{ text: "new", projectPath: "/repo", useCount: 4 }],
      "phone",
    );

    expect(store.list()).toHaveLength(1);
    expect(store.list()[0]).toMatchObject({
      id: promptHistoryId("new", "/repo"),
      totalUseCount: 4,
    });
  });

  it("detects slash and skill command kinds", () => {
    expect(detectPromptCommandKind("/compact")).toBe("slash");
    expect(detectPromptCommandKind("$flutter-ui-design")).toBe("skill");
    expect(
      detectPromptCommandKind("<command-name>$skill</command-name>"),
    ).toBe("skill");
    expect(detectPromptCommandKind("plain text")).toBe("none");
  });
});
