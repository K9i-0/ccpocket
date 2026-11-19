#!/usr/bin/env node
// エージェント検証用の agy acp ランチャー（APIキー認証を強制する）。
// ルール: docs/antigravity-acp-integration.md
// 使い方: node scripts/antigravity-acp-probe.mjs --cwd <作業ディレクトリ> [--trace <出力.ndjson>]
//           [--model <modelId>（既定 gemini-3.8-flash-high）] [--mode <modeId>] [--allow] [--caps <clientCapabilities に足す JSON>]
//           [--load <sessionId> | --resume <sessionId>] [--wait <プロンプト完了後に待つミリ秒>] --prompt "..." [--prompt "..."]
// APIキー用プロファイルで起動し、authenticate(gemini-api-key) のあとモデル一覧が
// Gemini のみであることを確認できなければ、プロンプトを送らずに終了する。
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { appendFileSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const PROFILE = "antigravity-cli-apikey"; // ~/.gemini 配下。既定の antigravity-cli は使わない
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const argv = process.argv.slice(2);
const opt = (n) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
const prompts = argv.flatMap((a, i) => (a === "--prompt" ? [argv[i + 1]] : []));
const die = (msg) => { console.error(`中止: ${msg}`); process.exit(1); };

const cwd = opt("--cwd") ? resolve(opt("--cwd")) : die("--cwd を指定してください");
const envText = readFileSync(join(root, ".env.antigravity.local"), "utf8");
const key = envText.split("\n").find((l) => l.startsWith("GEMINI_API_KEY="))?.slice(15).trim();
if (!key) die(".env.antigravity.local の GEMINI_API_KEY が空です");

const traceFile = opt("--trace");
if (traceFile) writeFileSync(traceFile, "");
const t0 = Date.now();
const trace = (o) => traceFile && appendFileSync(traceFile, JSON.stringify({ t: Date.now() - t0, ...o }) + "\n");

const child = spawn("agy", ["acp", "--app-data-dir", PROFILE], {
  cwd, stdio: ["pipe", "pipe", "pipe"],
  env: argv.includes("--auth-meta") ? { ...process.env, GEMINI_API_KEY: "" } : { ...process.env, GEMINI_API_KEY: key },
});
child.stderr.on("data", (d) => trace({ dir: "stderr", text: String(d) }));
const stop = (code) => { child.stdin.end(); setTimeout(() => { child.kill(); process.exit(code); }, 1000); };

let nextId = 0;
const pending = new Map();
const send = (msg) => { trace({ dir: "out", msg }); child.stdin.write(JSON.stringify(msg) + "\n"); };
const request = (method, params, timeoutMs = 300000) => new Promise((res) => {
  const id = ++nextId;
  const timer = setTimeout(() => { pending.delete(id); res({ error: { message: `timeout: ${method}` } }); }, timeoutMs);
  pending.set(id, (m) => { clearTimeout(timer); res(m); });
  send({ jsonrpc: "2.0", id, method, params });
});
let text = "";
createInterface({ input: child.stdout }).on("line", (line) => {
  let m; try { m = JSON.parse(line); } catch { return; }
  trace({ dir: "in", msg: m });
  if (m.id !== undefined && m.method === undefined) { pending.get(m.id)?.(m); pending.delete(m.id); return; }
  if (m.method === "session/update") {
    const u = m.params?.update ?? {};
    if (u.sessionUpdate === "agent_message_chunk") text += u.content?.text ?? "";
    else if (u.sessionUpdate === "tool_call") console.log(`  [tool] ${u.kind ?? "-"}: ${u.title ?? ""}`);
    else if (u.sessionUpdate === "tool_call_update" && ["completed", "failed"].includes(u.status)) console.log(`  [tool ${u.status}] ${u.title ?? ""}`);
    else if (!["agent_message_chunk", "agent_thought_chunk", "usage_update", "tool_call_update", "available_commands_update"].includes(u.sessionUpdate)) console.log(`  [${u.sessionUpdate}] ${JSON.stringify(u).slice(0, 200)}`);
  } else if (m.method === "session/request_permission") {
    const want = argv.includes("--allow") ? "allow_once" : "reject_once";
    const pick = (m.params?.options ?? []).find((o) => o.kind === want);
    console.log(`  [承認リクエスト] ${m.params?.toolCall?.title ?? ""} -> ${want}`);
    send({ jsonrpc: "2.0", id: m.id, result: pick ? { outcome: { outcome: "selected", optionId: pick.optionId } } : { outcome: { outcome: "cancelled" } } });
  } else if (m.id !== undefined) {
    console.log(`  [未対応のリクエスト] ${JSON.stringify(m).slice(0, 600)}`);
    send({ jsonrpc: "2.0", id: m.id, error: { code: -32601, message: "Method not found" } });
  }
});

const init = await request("initialize", {
  protocolVersion: 1, clientInfo: { name: "ccpocket-acp-probe", version: "0.0.1" },
  clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false, ...JSON.parse(opt("--caps") ?? "{}") },
}, 30000);
if (init.error) { console.error(`中止: initialize 失敗 ${JSON.stringify(init.error)}`); stop(1); }
const auth = await request("authenticate", argv.includes("--auth-meta")
  ? { methodId: "gemini-api-key", _meta: { apiKey: key } } : { methodId: "gemini-api-key" }, 30000);
if (auth.error) { console.error(`中止: authenticate 失敗 ${JSON.stringify(auth.error)}`); stop(1); }
const existing = opt("--load") ?? opt("--resume");
const session = existing
  ? await request(opt("--load") ? "session/load" : "session/resume", { sessionId: existing, cwd, mcpServers: [] }, 60000)
  : await request("session/new", { cwd, mcpServers: [] }, 60000);
if (session.error) { console.error(`中止: session 開始失敗 ${JSON.stringify(session.error)}`); stop(1); }
const models = (session.result.models?.availableModels ?? []).map((m) => m.modelId);
const foreign = models.filter((m) => !m.startsWith("gemini-"));
if (models.length === 0 || foreign.length > 0) {
  console.error(`中止: APIキーモードを確認できません（Gemini 以外のモデル: ${foreign.join(", ") || "一覧が空"}）。プロンプトは送っていません。`);
  stop(1);
}
const sessionId = session.result.sessionId ?? existing;
console.log(`agy ${init.result.agentInfo?.version} / APIキーモード確認済み（モデル ${models.length} 件、すべて Gemini）`);
console.log(`session=${sessionId} model=${session.result.models.currentModelId}`);
// APIキーモードの既定は gemini-3.1-pro-low（入力 $2 / 出力 $12）なので、指定がなければ安い 3.8 Flash にする
const model = opt("--model") ?? "gemini-3.8-flash-high";
const setModel = await request("session/set_model", { sessionId, modelId: model });
if (setModel.error) { console.error(`中止: モデル ${model} に切り替えられません ${JSON.stringify(setModel.error)}`); stop(1); }
console.log(`model -> ${model}`);
if (opt("--mode")) console.log("set_mode:", JSON.stringify((await request("session/set_mode", { sessionId, modeId: opt("--mode") })).error ?? "ok"));
for (const p of prompts) {
  text = "";
  console.log(`\n> ${p}`);
  if (opt("--cancel-after")) setTimeout(() => { console.log("  [cancel 送信]"); send({ jsonrpc: "2.0", method: "session/cancel", params: { sessionId } }); }, Number(opt("--cancel-after")));
  if (opt("--steer")) setTimeout(() => {
    console.log(`  [steer 送信] ${opt("--steer")}`);
    request("session/prompt", { sessionId, prompt: [{ type: "text", text: opt("--steer") }] }).then((sr) => console.log(`  [steer の結果] ${JSON.stringify(sr.result ?? sr.error)}`));
  }, Number(opt("--steer-after") ?? 3000));
  const r = await request("session/prompt", { sessionId, prompt: [{ type: "text", text: p }] });
  console.log(text.trim());
  console.log(`  [結果] ${JSON.stringify(r.result ?? r.error)}`);
}
if (opt("--steer")) await new Promise((r) => setTimeout(r, 25000));
// タイマー（schedule）やバックグラウンドタスクでの自発的な再開を見るために残る
if (opt("--wait")) { await new Promise((r) => setTimeout(r, Number(opt("--wait")))); console.log(text.trim()); }
stop(0);
