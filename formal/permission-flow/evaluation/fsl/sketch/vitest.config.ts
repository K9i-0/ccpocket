import { defineConfig } from "vitest/config";

// Sketch only: lets the tests in this directory import the real SdkProcess
// from packages/bridge without adding anything under packages/.
export default defineConfig({
  // keep vitest's cache inside this directory (node_modules here is a symlink
  // into packages/bridge, and the default cache would land there)
  cacheDir: "./.vite-cache",
  test: {
    environment: "node",
    include: ["*.test.ts"],
  },
});
