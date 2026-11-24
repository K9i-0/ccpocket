#!/usr/bin/env node
// out/summary.tsv を性質 x インスタンスの表 (Markdown) にする。
// 使い方: node results.mjs > out/results.md
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const rows = readFileSync(join(here, "out", "summary.tsv"), "utf8")
  .trim()
  .split("\n")
  .slice(1)
  .map((l) => l.split("\t"))
  .map(([stage, instance, property, result, detail]) => ({ stage, instance, property, result, detail }));

const SAFETY = [
  "P1a", "P1b", "P2", "P3", "P4_resolved", "P4_view", "P4_userDecision", "P4_app",
  "P4_aux_registered", "P5_state", "P5_noEffect", "P6", "P8_noLostInput",
];
const CUR = [
  "cur_min", "cur_abort", "cur_bg", "cur_msgs", "cur_bgmsgs", "cur_end", "cur_reent",
  "cur_reab", "cur_dead", "cur_bgend", "cur_plaus", "cur_U",
];
const MUT = ["m1_min", "m1_U", "m2_min", "m2_U", "m3_min", "m3_U"];

const find = (stage, instance, property) =>
  rows.filter((r) => r.stage === stage && r.instance === instance && r.property === property).pop();

// 1 マス: シミュレーター (ID 3 個) と TLC (ID 2 個、全探索) の結果を合わせて書く
const cell = (inst, prop) => {
  const sim = find("sim", inst, prop);
  const tlc = find("tlc", `${inst}_s`, prop);
  if (!sim && !tlc) return "–";
  if (sim?.result === "violation") {
    const n = sim.detail.match(/trace states=(\d+)/)?.[1];
    return `✗ sim(${n})`;
  }
  if (tlc?.result === "violation") {
    const n = tlc.detail.match(/trace states=(\d+)/)?.[1];
    return `✗ **TLCのみ**(${n})`;
  }
  if (tlc?.result === "ok") {
    const n = tlc.detail.match(/(\d+) distinct states/)?.[1];
    return `✓ ${n}`;
  }
  return `? sim=${sim?.result ?? "-"} tlc=${tlc?.result ?? "-"}`;
};

const table = (title, instances, props) => {
  console.log(`### ${title}\n`);
  console.log(`| 性質 | ${instances.join(" | ")} |`);
  console.log(`|---|${instances.map(() => "---").join("|")}|`);
  for (const p of props) console.log(`| ${p} | ${instances.map((i) => cell(i, p)).join(" | ")} |`);
  console.log();
};

console.log("凡例: ✓ N = シミュレーター (ID 3 個, 20000 本 x 25 ステップ) で反例なし、かつ TLC が ID 2 個の全状態 N 個を探索して成立。");
console.log("✗ sim(k) = シミュレーターが反例を発見 (トレースの状態数 k)。✗ TLCのみ(k) = シミュレーターは見つけられず TLC が発見。\n");
table("現行コード (安全性)", CUR, SAFETY);
table("退行 (安全性)", MUT, SAFETY);

const LIVE = ["P7_sdkFairOnly", "P7_fair", "P7_table_fair", "P8_sdkFairOnly", "P8_fair", "P8_stoppedOnly_fair"];
const liveInst = [...new Set(rows.filter((r) => r.stage === "live").map((r) => r.instance))];
console.log("### 活性 (TLC の時相検査、ID 2 個)\n");
console.log(`| 性質 | ${liveInst.join(" | ")} |`);
console.log(`|---|${liveInst.map(() => "---").join("|")}|`);
for (const p of LIVE) {
  const cells = liveInst.map((i) => {
    const r = find("live", i, p);
    if (!r) return "–";
    if (r.result === "ok") return `✓ ${r.detail.match(/(\d+) distinct states/)?.[1] ?? ""}`;
    if (r.result === "violation") return `✗ (${r.detail.match(/trace states=(\d+)/)?.[1]})`;
    return "error";
  });
  console.log(`| ${p} | ${cells.join(" | ")} |`);
}
console.log();

console.log("### その他の段\n");
console.log("| 段 | インスタンス | 性質 | 結果 | 詳細 |");
console.log("|---|---|---|---|---|");
for (const r of rows.filter((x) => ["deep", "itf", "replay", "apalache", "traces"].includes(x.stage))) {
  console.log(`| ${r.stage} | ${r.instance} | ${r.property} | ${r.result} | ${r.detail} |`);
}
