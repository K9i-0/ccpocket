#!/usr/bin/env node
// Converts the counterexample in a raw TLC output file into JSON.
// tla2tools 1.7.4 (TLC 2.19) has no `-dumpTrace json`, so the text trace is parsed.
//   node trace2json.mjs out/P1a.txt out/trace-P1a.json
//   node trace2json.mjs --multi out/sim.txt out/sim-traces.json   (TLC -simulate -continue)
import { readFileSync, writeFileSync } from "node:fs";

const [inFile, outFile] = process.argv.slice(2).filter((a) => !a.startsWith("--"));
if (!inFile || !outFile) {
  console.error("usage: trace2json.mjs <tlc-output.txt> <trace.json>");
  process.exit(2);
}

// Minimal parser for the TLA+ values this spec uses.
function parseValue(src) {
  let i = 0;
  const ws = () => { while (/\s/.test(src[i] ?? "")) i++; };
  const eat = (s) => { ws(); if (src.startsWith(s, i)) { i += s.length; return true; } return false; };
  function value() {
    ws();
    if (eat("<<")) { const xs = []; while (!eat(">>")) { xs.push(value()); eat(","); } return xs; }
    if (eat("{")) { const xs = []; while (!eat("}")) { xs.push(value()); eat(","); } return xs; }
    if (eat("[")) {            // record [a |-> 1, b |-> 2]
      const rec = {};
      while (!eat("]")) { ws(); const k = /^\w+/.exec(src.slice(i))[0]; i += k.length; eat("|->"); rec[k] = value(); eat(","); }
      return rec;
    }
    if (eat("(")) {            // function (t1 :> "x" @@ t2 :> "y")
      const fn = {};
      while (!eat(")")) { const k = value(); eat(":>"); fn[String(k)] = value(); eat("@@"); }
      return fn;
    }
    if (src[i] === '"') { const end = src.indexOf('"', i + 1); const s = src.slice(i + 1, end); i = end + 1; return s; }
    const tok = /^[\w]+/.exec(src.slice(i))[0]; i += tok.length;
    if (tok === "TRUE") return true;
    if (tok === "FALSE") return false;
    return /^\d+$/.test(tok) ? Number(tok) : tok;   // number or model value
  }
  return value();
}

const multi = process.argv.includes("--multi");
const lines = readFileSync(inFile, "utf8").split("\n");
const traces = [];
let steps = null;
let cur = null;
let loop = null;
for (const line of lines) {
  const head = /^State (\d+): <?([A-Za-z ]+?)(?: line (\d+).*)?>?$/.exec(line);
  if (head) {
    if (Number(head[1]) === 1) { steps = []; traces.push(steps); }
    cur = { index: Number(head[1]), action: head[2].trim(), specLine: head[3] ? Number(head[3]) : null, raw: {} };
    if (cur.action === "Stuttering") { loop = "stuttering"; cur = null; continue; }
    steps.push(cur);
    continue;
  }
  const back = /^Back to state (\d+)/.exec(line);
  if (back) { loop = Number(back[1]); cur = null; continue; }
  if (!cur) continue;
  const v = /^\/\\ (\w+) = (.*)$/.exec(line);
  if (v) { cur.raw[v[1]] = v[2]; cur.last = v[1]; }
  else if (line.trim() === "") cur = null;
  else if (cur.last) cur.raw[cur.last] += " " + line.trim();   // wrapped value
}
for (const t of traces) {
  for (const s of t) {
    s.state = Object.fromEntries(Object.entries(s.raw).map(([k, x]) => [k, parseValue(x)]));
    delete s.raw; delete s.last;
  }
}
if (multi) {
  // Many traces in one file (TLC -simulate -continue): keep one per line.
  writeFileSync(outFile, "[\n" + traces.map((t) => JSON.stringify(t)).join(",\n") + "\n]\n");
  console.log(`${outFile}: ${traces.length} traces`);
} else {
  const last = traces[traces.length - 1] ?? [];
  writeFileSync(outFile, JSON.stringify({ source: inFile, loop, steps: last }, null, 1) + "\n");
  console.log(`${outFile}: ${last.length} states${loop ? `, loop: ${loop}` : ""}`);
}
