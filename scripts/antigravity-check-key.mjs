#!/usr/bin/env node
// Antigravity 検証用 APIキーの確認。プロンプトは送らず、トークンも消費しない。
// キーの値は表示しない。使い方: node scripts/antigravity-check-key.mjs [envファイル]
import { readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const envFile = resolve(process.argv[2] ?? join(root, ".env.antigravity.local"));
const fail = (msg) => { console.error(`NG: ${msg}`); process.exit(1); };

let text;
try { text = readFileSync(envFile, "utf8"); } catch { fail(`${envFile} が読めません`); }
const line = text.split("\n").find((l) => /^\s*GEMINI_API_KEY\s*=/.test(l));
const key = line?.split("=").slice(1).join("=").trim().replace(/^["']|["']$/g, "");
if (!key) fail(`${envFile} の GEMINI_API_KEY が空です`);
if ((statSync(envFile).mode & 0o077) !== 0) console.warn("注意: ファイルが他ユーザーから読めます。chmod 600 を推奨");

const res = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000", {
  headers: { "x-goog-api-key": key },
});
if (!res.ok) {
  const body = await res.json().catch(() => ({}));
  fail(`Gemini API がキーを拒否しました (HTTP ${res.status}: ${body.error?.status ?? "unknown"})`);
}
const names = ((await res.json()).models ?? []).map((m) => m.name.replace(/^models\//, ""));
const want = ["gemini-3.8-flash", "gemini-4-hydrogen", "gemini-4-carbon"];
console.log(`OK: キーは有効です（長さ ${key.length}、利用可能モデル ${names.length} 件）`);
for (const w of want) console.log(`  ${names.some((n) => n.startsWith(w)) ? "o" : "x"} ${w}`);
