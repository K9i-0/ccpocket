#!/usr/bin/env node
// Prints the mutants that survived a Stryker run, from its JSON report.
//
// Usage:
//   node scripts/mutation-report.mjs <report.json> [file-name-filter...]
//   node scripts/mutation-report.mjs <report.json> --summary
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const summaryOnly = args.includes("--summary");
const [reportPath, ...filters] = args.filter((arg) => arg !== "--summary");
if (!reportPath) {
  console.error(
    "Usage: node scripts/mutation-report.mjs <report.json> [filter...] [--summary]",
  );
  process.exit(2);
}

const report = JSON.parse(readFileSync(reportPath, "utf-8"));
const rows = [];

for (const [file, data] of Object.entries(report.files).sort()) {
  if (filters.length > 0 && !filters.some((filter) => file.includes(filter))) {
    continue;
  }
  const count = (status) =>
    data.mutants.filter((mutant) => mutant.status === status).length;
  const killed = count("Killed") + count("Timeout");
  const survived = count("Survived");
  const noCoverage = count("NoCoverage");
  const total = killed + survived + noCoverage;
  rows.push({ file, killed, survived, noCoverage, total });
  if (summaryOnly) continue;

  const lines = data.source.split("\n");
  const missed = data.mutants
    .filter(
      (mutant) => mutant.status === "Survived" || mutant.status === "NoCoverage",
    )
    .sort(
      (a, b) =>
        a.location.start.line - b.location.start.line ||
        a.location.start.column - b.location.start.column,
    );
  if (missed.length === 0) continue;

  console.log(`\n## ${file}`);
  for (const mutant of missed) {
    const { start, end } = mutant.location;
    const span = end.line === start.line ? "" : `-L${end.line}`;
    const tag = mutant.status === "Survived" ? "survived" : "untested";
    const source = lines[start.line - 1].trim().slice(0, 80);
    const replacement = (mutant.replacement ?? "")
      .replace(/\s+/g, " ")
      .slice(0, 60);
    console.log(
      `  L${start.line}:${start.column}${span} ${tag} ${mutant.mutatorName}: ${source}  =>  ${replacement}`,
    );
  }
}

console.log("\nscore   killed survived untested  file");
const score = ({ killed, total }) =>
  total === 0 ? "   n/a" : `${((100 * killed) / total).toFixed(1).padStart(5)}%`;
for (const row of [...rows].sort(
  (a, b) => a.killed / (a.total || 1) - b.killed / (b.total || 1),
)) {
  console.log(
    `${score(row)} ${String(row.killed).padStart(7)} ${String(row.survived).padStart(8)} ${String(row.noCoverage).padStart(8)}  ${row.file}`,
  );
}
if (rows.length > 1) {
  const sum = rows.reduce(
    (acc, row) => ({
      killed: acc.killed + row.killed,
      survived: acc.survived + row.survived,
      noCoverage: acc.noCoverage + row.noCoverage,
      total: acc.total + row.total,
    }),
    { killed: 0, survived: 0, noCoverage: 0, total: 0 },
  );
  console.log(
    `${score(sum)} ${String(sum.killed).padStart(7)} ${String(sum.survived).padStart(8)} ${String(sum.noCoverage).padStart(8)}  all`,
  );
}
