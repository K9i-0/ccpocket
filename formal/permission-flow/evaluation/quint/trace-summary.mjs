#!/usr/bin/env node
// ITF トレース (quint run / quint verify の --out-itf) を 1 イベント 1 行に要約する。
// 使い方: node trace-summary.mjs <trace.itf.json>
import { readFileSync } from "node:fs";

const conv = (v) => {
  if (v === null || typeof v !== "object") return v;
  if (Array.isArray(v)) return v.map(conv);
  if ("#bigint" in v) return Number(v["#bigint"]);
  if ("#set" in v) return v["#set"].map(conv).sort();
  if ("#map" in v) return Object.fromEntries(v["#map"].map(([k, x]) => [conv(k), conv(x)]));
  if ("#tup" in v) return v["#tup"].map(conv);
  return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, conv(x)]));
};

const file = process.argv[2];
const itf = JSON.parse(readFileSync(file, "utf8"));
const set = (a) => `{${a.join(",")}}`;
const promises = (m) =>
  Object.entries(m)
    .filter(([, v]) => v !== "unused")
    .map(([k, v]) => `${k}:${v}`)
    .join(",");
const counts = (m) =>
  Object.entries(m)
    .filter(([, v]) => v > 0)
    .map(([k, v]) => `${k}:${v}`)
    .join(",");

let prev = null;
itf.states.forEach((raw, i) => {
  const key = Object.keys(raw).find((k) => k === "s" || k.endsWith("::s"));
  const s = conv(raw[key]);
  const ev = s.last.arg ? `${s.last.ev}(${s.last.arg})` : s.last.ev;
  const ops = s.ops.map((o) => `${o.mode}@gen${o.gen}${o.q >= 0 ? `/await-q${o.q}` : "/queued"}`);
  const line = [
    `status=${s.status}`,
    `pending=${set(s.pending)}`,
    `sdk=[${promises(s.sdkPromise)}]`,
    `resolveCalls=[${counts(s.settleCount)}]`,
    `client=${set(s.clientStrict)}`,
    `clientApp=${set(s.clientApp)}`,
    `queue=${s.queueLen}`,
    `waiter=${s.waiter < 0 ? "null" : `q${s.waiter}`}`,
    `query=${s.queryAlive ? `q${s.queryId}` : "null"}`,
    `stopped=${s.stopped}`,
    `mode=${s.mode}`,
    `gen=${s.gen}`,
    `ops=[${ops.join(",")}]`,
    `sdkTurn=${s.sdkTurn}`,
    ...(s.staleModeWrite ? ["STALE_MODE_WRITE"] : []),
    ...(s.lostInput ? ["LOST_INPUT"] : []),
    ...(s.postStopEffect ? ["POST_STOP_EFFECT"] : []),
    ...(s.announcedUnregistered.length ? [`announcedUnregistered=${set(s.announcedUnregistered)}`] : []),
  ];
  // 直前から変わった項目だけに印を付ける
  const shown = prev ? line.map((x, j) => (x !== prev[j] ? `*${x}` : x)) : line;
  console.log(`${String(i).padStart(2)} ${ev}\n     ${shown.join(" ")}`);
  prev = line;
});
