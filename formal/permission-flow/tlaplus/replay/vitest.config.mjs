// Standalone vitest config for the trace replay.  It lives outside packages/
// on purpose (SCOPE.md: no edits under packages/).  Run through run.sh.
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

export default {
  root: here,
  cacheDir: join(tmpdir(), "ccpocket-tla-replay-vite"),
  test: {
    environment: "node",
    globals: true,
    include: ["*.test.ts"],
    cache: false,
  },
};
