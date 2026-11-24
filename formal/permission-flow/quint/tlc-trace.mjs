#!/usr/bin/env node
// TLC の反例 (quint verify --backend tlc のログ) を 1 イベント 1 行に要約する。
// TLC バックエンドは --out-itf を書かないので、ログの文字列から拾う。
// 使い方: node tlc-trace.mjs <out/tlc/xxx.txt>
import { readFileSync } from "node:fs";

const text = readFileSync(process.argv[2], "utf8");
const blocks = text.split(/^(?=State \d+: )/m).filter((b) => /^State \d+: /.test(b));
const field = (b, name) => {
  const m = b.match(new RegExp(`\\b${name} \\|-> ([\\s\\S]*?),?\\n  \\w+ \\|->`));
  return m ? m[1].replace(/\s+/g, " ") : "?";
};
let prev = null;
for (const b of blocks) {
  const head = b.match(/^State (\d+): (.*)/);
  let action = head[2];
  const named = action.match(/<\w+?_permflow_(\w+(?:\([^)]*\))?) line/);
  if (named) action = named[1];
  else if (action.includes("Initial predicate")) action = "init";
  if (/Stuttering/.test(action)) {
    console.log(`${head[1].padStart(2)} (ここから足踏み: 以後なにも起きない)`);
    continue;
  }
  const line = [
    `status=${field(b, "status")}`,
    `pending=${field(b, "pending")}`,
    `sdk=${field(b, "sdkPromise")}`,
    `resolveCalls=${field(b, "settleCount")}`,
    `client=${field(b, "clientStrict")}`,
    `clientApp=${field(b, "clientApp")}`,
    `queue=${field(b, "queueLen")}`,
    `headSeq=${field(b, "headSeq")}`,
    `waiter=${field(b, "waiter")}`,
    `queryAlive=${field(b, "queryAlive")}`,
    `queryId=${field(b, "queryId")}`,
    `stopped=${field(b, "stopped")}`,
    `mode=${field(b, "mode")}`,
    `gen=${field(b, "gen")}`,
    `ops=${field(b, "ops")}`,
    `sdkTurn=${field(b, "sdkTurn")}`,
    `pullPending=${field(b, "pullPending")}`,
    `staleModeWrite=${field(b, "staleModeWrite")}`,
    `lostInput=${field(b, "lostInput")}`,
  ];
  const shown = prev ? line.filter((x, j) => x !== prev[j]) : line;
  console.log(`${head[1].padStart(2)} ${action}\n     ${shown.join(" ") || "(変化なし)"}`);
  prev = line;
}
const back = text.match(/^Back to state (\d+)/m);
if (back) console.log(`   → 状態 ${back[1]} に戻って繰り返す`);
