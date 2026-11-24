// packages/bridge の vitest を借りて、このディレクトリのテストだけを回す設定。
// キャッシュもこのディレクトリの中に置く (リポジトリの node_modules を汚さない)。
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

export default {
  root: join(here, "..", "..", "..", ".."),
  cacheDir: join(here, ".cache"),
  test: {
    environment: "node",
    experimental: { fsModuleCachePath: join(here, ".cache", "modules") },
    include: ["formal/permission-flow/quint/repro/*.test.ts"],
  },
};
