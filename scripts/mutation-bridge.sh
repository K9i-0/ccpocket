#!/usr/bin/env bash
# Mutation testing for Bridge modules with Stryker (run on demand, not in CI).
# Stryker breaks the source in small ways ("mutants") and reruns the tests; a
# mutant that no test notices is a gap in the tests.
#
# Usage (from any directory inside the checkout):
#   bash scripts/mutation-bridge.sh path-utils cli-args     # src/<name>.ts
#   bash scripts/mutation-bridge.sh src/parser.ts:100-250   # only these lines
#
# Environment:
#   MUTATION_CONCURRENCY  test runner processes (default: Stryker's own choice)
#   MUTATION_REPORT       where to write the JSON report
#                         (default: a file in the scratch directory, printed at the end)
#
# The run is isolated on purpose, because a mutant can turn a guarded file or
# git operation into an unguarded one:
#   - the sandbox is a copy outside the repository, so a stray `git` or `rm`
#     from a mutant cannot reach this checkout
#   - HOME is an empty scratch directory and the environment is cleared, so
#     mutants see no credentials and no real ~/.codex, ~/.claude or ~/.ccpocket
#   - tests run in forked processes; in Stryker's default thread pool a test's
#     `process.env.HOME = ...` does not reach os.homedir(), and tests read the
#     real home
# Keep to modules without process spawning or network access. websocket.ts and
# the *-process.ts files are too large and too I/O-bound to be useful here.
set -euo pipefail

STRYKER_VERSION="10.1.1"

if [ "$#" -eq 0 ]; then
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

root="$(git rev-parse --show-toplevel)"
cd "$root"

scratch="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/ccpocket-mutation.XXXXXX")" && pwd -P)"
trap 'rm -rf "$scratch/sandbox" "$scratch/home"' EXIT
mkdir -p "$scratch/home"
printf '[user]\n\tname = Mutation\n\temail = mutation@example.invalid\n[init]\n\tdefaultBranch = main\n' \
  >"$scratch/home/.gitconfig"

report="${MUTATION_REPORT:-$scratch/report.json}"
npm_cache="$(npm config get cache)"

MUTATION_SCRATCH="$scratch" MUTATION_REPORT_PATH="$report" node - "$@" <<'EOF'
const fs = require("node:fs");
const path = require("node:path");

const mutate = process.argv.slice(2).map((arg) => {
  const [file, range] = arg.split(":");
  const rel = file.includes("/") ? file : `src/${file}`;
  const withExt = rel.endsWith(".ts") ? rel : `${rel}.ts`;
  const target = withExt.startsWith("packages/")
    ? withExt
    : path.posix.join("packages/bridge", withExt);
  if (!fs.existsSync(target)) {
    console.error(`No such module: ${target}`);
    process.exit(2);
  }
  return range ? `${target}:${range}` : target;
});

const concurrency = Number(process.env.MUTATION_CONCURRENCY);
const config = {
  testRunner: "vitest",
  vitest: {
    configFile: "packages/bridge/vitest.config.ts",
    dir: "packages/bridge",
    pool: "forks",
  },
  mutate,
  // Copy only what the Bridge tests read: the package itself plus the
  // fixtures under docs/, test/ and scripts/.
  ignorePatterns: [
    "/*",
    "!/packages",
    "/packages/*",
    "!/packages/bridge",
    "/packages/bridge/dist",
    "/packages/bridge/coverage",
    "!/docs",
    "!/test",
    "!/scripts",
    "!/package.json",
  ],
  reporters: ["json", "progress-append-only"],
  jsonReporter: { fileName: process.env.MUTATION_REPORT_PATH },
  coverageAnalysis: "perTest",
  // Stryker rewrites the tsconfig through an API that TypeScript 7 no longer
  // has. Vitest does not need the rewrite, so point it at a file that is not
  // there and it skips the step.
  tsconfigFile: "tsconfig.mutation-unused.json",
  tempDirName: path.join(process.env.MUTATION_SCRATCH, "sandbox"),
  cleanTempDir: "always",
  disableBail: true,
  ...(Number.isInteger(concurrency) && concurrency > 0 ? { concurrency } : {}),
};
fs.writeFileSync(
  path.join(process.env.MUTATION_SCRATCH, "stryker.json"),
  JSON.stringify(config, null, 2),
);
EOF

status=0
env -i PATH="$PATH" HOME="$scratch/home" TMPDIR="${TMPDIR:-/tmp}" LANG=en_US.UTF-8 \
  npm_config_cache="$npm_cache" \
  npx -y \
  -p "@stryker-mutator/core@$STRYKER_VERSION" \
  -p "@stryker-mutator/vitest-runner@$STRYKER_VERSION" \
  stryker run "$scratch/stryker.json" || status=$?

if [ -f "$report" ]; then
  node "$root/scripts/mutation-report.mjs" "$report"
  echo "Report: $report"
fi
exit "$status"
