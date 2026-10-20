import { execFileSync } from "node:child_process";

export function currentGitBranch(cwd: string): string {
  try {
    return execFileSync("git", ["symbolic-ref", "--quiet", "--short", "HEAD"], { cwd, encoding: "utf8", stdio: "pipe" }).trim();
  } catch {
    try { return execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd, encoding: "utf8", stdio: "pipe" }).trim(); }
    catch { return ""; }
  }
}

export function hasGitHead(cwd: string): boolean {
  try { execFileSync("git", ["rev-parse", "--verify", "HEAD"], { cwd, stdio: "pipe" }); return true; }
  catch { return false; }
}
