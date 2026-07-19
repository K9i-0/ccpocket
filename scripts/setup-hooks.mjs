#!/usr/bin/env node
import { chmodSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const repoRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], {
  encoding: "utf8",
}).trim();
const hooksDir = join(repoRoot, ".git", "hooks");

if (!existsSync(hooksDir)) {
  mkdirSync(hooksDir, { recursive: true });
}

const hookPath = join(hooksDir, "pre-commit");
const scriptDir = dirname(fileURLToPath(import.meta.url));
const shellHook = `#!/usr/bin/env sh
# Auto-installed by scripts/setup-hooks.mjs
# Runs secret detection before every commit.

REPO_ROOT="$(git rev-parse --show-toplevel)"
exec "$REPO_ROOT/scripts/check-secrets.sh"
`;

writeFileSync(hookPath, shellHook, "utf8");

try {
  chmodSync(hookPath, 0o755);
} catch {
  // Windows may ignore POSIX mode bits; Git can still execute hooks through sh.
}

console.log(`Installed: ${hookPath}`);
console.log(`Done. Hooks are active. Source: ${scriptDir}`);
