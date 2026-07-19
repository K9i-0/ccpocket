#!/usr/bin/env node
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const bridgeDir = dirname(dirname(fileURLToPath(import.meta.url)));
const repoRoot = dirname(dirname(bridgeDir));
const tsxCli = join(repoRoot, "node_modules", "tsx", "dist", "cli.mjs");

const env = { ...process.env };
delete env.CLAUDECODE;

const child = spawn(process.execPath, [tsxCli, "src/index.ts"], {
  cwd: bridgeDir,
  env,
  stdio: "inherit",
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});
