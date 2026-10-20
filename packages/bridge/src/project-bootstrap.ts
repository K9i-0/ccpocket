import { execFileSync } from "node:child_process";
import { constants } from "node:fs";
import { copyFile, lstat, mkdir, readdir, realpath, rm, writeFile } from "node:fs/promises";
import { basename, join, relative, isAbsolute, resolve } from "node:path";

// Explicit project artifacts only; never copy a user's entire agent home.
export const AI_SETTINGS = ["CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md", ".claude/settings.json", ".claude/skills", ".claude/agents", ".claude/commands", ".claude/hooks", ".codex/config.toml", ".codex/rules", ".codex/skills", ".codex/agents", ".codex/hooks", ".agents/skills"];
export function validProjectName(name: string): boolean {
  return name.length > 0 && name.length <= 100 && !/[<>:"/\\|?*\x00-\x1f]/.test(name) && !name.endsWith(".") && name.trim() === name && name !== "." && name !== ".." && !/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name);
}

export async function bootstrapProject(options: {
  parentPath: string; name: string; initializeGit: boolean; sourcePath?: string;
  isAllowed: (path: string) => Promise<boolean>;
}): Promise<{ projectPath: string; copiedFiles: string[] }> {
  if (!validProjectName(options.name)) throw new Error("Invalid project folder name");
  const parent = await realpath(options.parentPath);
  if (!await options.isAllowed(parent)) throw new Error("Parent directory is not allowed");
  const source = options.sourcePath ? await realpath(options.sourcePath) : undefined;
  if (source && !await options.isAllowed(source)) throw new Error("Source directory is not allowed");
  const projectPath = join(parent, options.name);
  if (!await options.isAllowed(projectPath)) throw new Error("Project directory is not allowed");
  // Exclusive creation: never merge into or remove an existing directory.
  await mkdir(projectPath);
  const copiedFiles: string[] = [];
  let bytes = 0;
  const copy = async (relativePath: string): Promise<void> => {
    const from = join(source!, relativePath);
    let info;
    try { info = await lstat(from); } catch (e) {
      if ((e as NodeJS.ErrnoException).code === "ENOENT") return;
      throw e;
    }
    if (info.isSymbolicLink()) return;
    const canonical = await realpath(from);
    if (isAbsolute(relative(source!, canonical)) || relative(source!, canonical).split(/[\\/]/).includes("..")) throw new Error("Settings path leaves source project");
    if (!await options.isAllowed(canonical)) throw new Error("Settings path is not allowed");
    const name = basename(from);
    if (name === "settings.local.json" || name.startsWith(".env") || /^(auth|credentials|secrets)(\.|$)/i.test(name)) return;
    const to = join(projectPath, ".ccpocket-bootstrap", relativePath);
    if (info.isDirectory()) {
      await mkdir(to, { recursive: true });
      for (const child of await readdir(from)) await copy(join(relativePath, child));
    } else if (info.isFile()) {
      bytes += info.size;
      if (bytes > 8 * 1024 * 1024 || copiedFiles.length >= 500) throw new Error("AI settings exceed the 500 file / 8 MB limit");
      await mkdir(join(to, ".."), { recursive: true });
      await copyFile(from, to, constants.COPYFILE_EXCL);
      copiedFiles.push(relativePath);
    }
  };
  try {
    if (source) for (const path of AI_SETTINGS) await copy(path);
    if (source && copiedFiles.length === 0) throw new Error("No supported AI settings found in the source project");
    if (copiedFiles.length) await writeFile(join(projectPath, ".gitignore"), ".ccpocket-bootstrap/\n", { flag: "wx" });
    if (options.initializeGit) execFileSync("git", ["init", "-b", "main"], { cwd: projectPath, timeout: 10_000, stdio: "pipe" });
    return { projectPath: resolve(options.parentPath, options.name), copiedFiles };
  } catch (error) {
    await rm(projectPath, { recursive: true, force: true });
    throw error;
  }
}
