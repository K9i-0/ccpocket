import { afterEach, describe, expect, it } from "vitest";
import { mkdtemp, mkdir, writeFile, readFile, rm, symlink, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { bootstrapProject, validProjectName } from "./project-bootstrap.js";
import { currentGitBranch, hasGitHead } from "./git-project-state.js";
import { listBranches, unstageFiles, gitRemoteStatus } from "./git-operations.js";
const dirs: string[] = [];
async function root() { const dir = await mkdtemp(join(tmpdir(), "ccpocket-bootstrap-")); dirs.push(dir); return dir; }
afterEach(async () => { for (const dir of dirs.splice(0)) await rm(dir, { recursive: true, force: true }); });
describe("new project setup", () => {
  it.each(["", ".", "..", "../other", "a/b", "a\\b", "a.", "CON", "NUL.txt", " white "])("rejects invalid folder name %s", (name) => expect(validProjectName(name)).toBe(false));
  it("creates an unborn repository with a usable branch and no upstream", async () => {
    const parentPath = await root();
    const { projectPath } = await bootstrapProject({ parentPath, name: "app", initializeGit: true, isAllowed: async () => true });
    expect(currentGitBranch(projectPath)).toBe("main");
    expect(hasGitHead(projectPath)).toBe(false);
    expect(listBranches(projectPath).branches).toContain("main");
    expect(gitRemoteStatus(projectPath)).toMatchObject({ branch: "main", hasUpstream: false });
    await writeFile(join(projectPath, "file.txt"), "staged");
    execFileSync("git", ["add", "file.txt"], { cwd: projectPath });
    await writeFile(join(projectPath, "file.txt"), "edited after staging");
    unstageFiles(projectPath, ["file.txt"]);
    expect(await readFile(join(projectPath, "file.txt"), "utf8")).toBe("edited after staging");
    expect(execFileSync("git", ["diff", "--cached", "--name-only"], { cwd: projectPath, encoding: "utf8" })).toBe("");
  });
  it("copies supported settings as inert drafts, excluding local settings and symlinks", async () => {
    const parentPath = await root(); const sourcePath = join(parentPath, "source");
    await mkdir(join(sourcePath, ".claude", "skills", "test"), { recursive: true });
    await writeFile(join(sourcePath, "CLAUDE.md"), "source instructions");
    await writeFile(join(sourcePath, ".claude", "settings.local.json"), "private");
    await writeFile(join(sourcePath, ".claude", "skills", "test", "SKILL.md"), "skill");
    if (process.platform !== "win32") await symlink(join(sourcePath, "CLAUDE.md"), join(sourcePath, "AGENTS.md"));
    const result = await bootstrapProject({ parentPath, name: "new", initializeGit: false, sourcePath, isAllowed: async () => true });
    expect(result.copiedFiles.sort()).toEqual([join(".claude", "skills", "test", "SKILL.md"), "CLAUDE.md"].sort());
    expect(await readFile(join(result.projectPath, ".ccpocket-bootstrap", "CLAUDE.md"), "utf8")).toBe("source instructions");
    await expect(access(join(result.projectPath, "CLAUDE.md"))).rejects.toThrow();
  });
  it("never overwrites an existing destination", async () => {
    const parentPath = await root(); await mkdir(join(parentPath, "app")); await writeFile(join(parentPath, "app", "keep"), "keep");
    await expect(bootstrapProject({ parentPath, name: "app", initializeGit: true, isAllowed: async () => true })).rejects.toThrow();
    expect(await readFile(join(parentPath, "app", "keep"), "utf8")).toBe("keep");
  });
  it("rejects canonical parent paths outside allowed roots", async () => {
    const parentPath = await root();
    await expect(bootstrapProject({ parentPath, name: "app", initializeGit: false, isAllowed: async () => false })).rejects.toThrow("not allowed");
    await expect(access(join(parentPath, "app"))).rejects.toThrow();
  });
  it("rolls back a new folder if there are no settings to inherit", async () => {
    const parentPath = await root();
    await expect(bootstrapProject({ parentPath, sourcePath: parentPath, name: "app", initializeGit: false, isAllowed: async () => true })).rejects.toThrow("No supported AI settings");
    await expect(access(join(parentPath, "app"))).rejects.toThrow();
  });
});
