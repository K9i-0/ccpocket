import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { existsSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { WorktreeStore } from "./worktree-store.js";

const STORE_DIR = join(homedir(), ".ccpocket");
const STORE_FILE = join(STORE_DIR, "worktree-sessions.json");

describe("WorktreeStore", () => {
  let backupData: string | null = null;

  beforeEach(() => {
    // Backup existing store file if it exists
    if (existsSync(STORE_FILE)) {
      backupData = readFileSync(STORE_FILE, "utf-8");
    }
    // Start with empty store
    mkdirSync(STORE_DIR, { recursive: true });
    writeFileSync(STORE_FILE, "{}", "utf-8");
  });

  afterEach(() => {
    // Restore original store file
    if (backupData !== null) {
      writeFileSync(STORE_FILE, backupData, "utf-8");
    } else if (existsSync(STORE_FILE)) {
      writeFileSync(STORE_FILE, "{}", "utf-8");
    }
  });

  it("returns undefined for unknown session ID", () => {
    const store = new WorktreeStore();
    expect(store.get("nonexistent")).toBeUndefined();
  });

  it("stores and retrieves a mapping", () => {
    const store = new WorktreeStore();
    const mapping = {
      worktreePath: "/tmp/project-worktrees/feature-x",
      worktreeBranch: "feature/x",
      projectPath: "/tmp/project",
    };
    store.set("claude-session-1", mapping);
    expect(store.get("claude-session-1")).toEqual(mapping);
  });

  it("persists data across instances", () => {
    const store1 = new WorktreeStore();
    store1.set("session-a", {
      worktreePath: "/path/a",
      worktreeBranch: "branch-a",
      projectPath: "/project",
    });

    const store2 = new WorktreeStore();
    expect(store2.get("session-a")).toEqual({
      worktreePath: "/path/a",
      worktreeBranch: "branch-a",
      projectPath: "/project",
    });
  });

  it("deletes a mapping by session ID", () => {
    const store = new WorktreeStore();
    store.set("to-delete", {
      worktreePath: "/path/x",
      worktreeBranch: "branch-x",
      projectPath: "/project",
    });
    expect(store.get("to-delete")).toBeDefined();
    store.delete("to-delete");
    expect(store.get("to-delete")).toBeUndefined();
  });

  it("deleteByWorktreePath removes all matching entries", () => {
    const store = new WorktreeStore();
    const wtPath = "/shared/worktree/path";
    store.set("session-1", {
      worktreePath: wtPath,
      worktreeBranch: "b1",
      projectPath: "/p1",
    });
    store.set("session-2", {
      worktreePath: wtPath,
      worktreeBranch: "b2",
      projectPath: "/p2",
    });
    store.set("session-3", {
      worktreePath: "/different/path",
      worktreeBranch: "b3",
      projectPath: "/p3",
    });

    store.deleteByWorktreePath(wtPath);

    expect(store.get("session-1")).toBeUndefined();
    expect(store.get("session-2")).toBeUndefined();
    expect(store.get("session-3")).toBeDefined();
  });

  it("findByWorktreePath returns the matching entry", () => {
    const store = new WorktreeStore();
    store.set("find-me", {
      worktreePath: "/find/this/path",
      worktreeBranch: "main",
      projectPath: "/project",
    });

    const result = store.findByWorktreePath("/find/this/path");
    expect(result).toBeDefined();
    expect(result!.claudeSessionId).toBe("find-me");
    expect(result!.mapping.worktreeBranch).toBe("main");
  });

  it("findByWorktreePath returns undefined when not found", () => {
    const store = new WorktreeStore();
    expect(store.findByWorktreePath("/nonexistent")).toBeUndefined();
  });

  it("handles corrupted store file gracefully", () => {
    writeFileSync(STORE_FILE, "not valid json!!!", "utf-8");
    const store = new WorktreeStore();
    expect(store.get("anything")).toBeUndefined();
    // Should still be able to write
    store.set("new", {
      worktreePath: "/p",
      worktreeBranch: "b",
      projectPath: "/proj",
    });
    expect(store.get("new")).toBeDefined();
  });

  it("handles missing store file gracefully", () => {
    if (existsSync(STORE_FILE)) {
      rmSync(STORE_FILE);
    }
    const store = new WorktreeStore();
    expect(store.get("anything")).toBeUndefined();
  });

  it("stores multiple independent mappings", () => {
    const store = new WorktreeStore();
    store.set("s1", { worktreePath: "/p1", worktreeBranch: "b1", projectPath: "/proj1" });
    store.set("s2", { worktreePath: "/p2", worktreeBranch: "b2", projectPath: "/proj2" });
    store.set("s3", { worktreePath: "/p3", worktreeBranch: "b3", projectPath: "/proj3" });

    expect(store.get("s1")!.worktreePath).toBe("/p1");
    expect(store.get("s2")!.worktreePath).toBe("/p2");
    expect(store.get("s3")!.worktreePath).toBe("/p3");
  });
});
