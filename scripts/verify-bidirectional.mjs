#!/usr/bin/env node
/**
 * 双方向通信検証スクリプト
 *
 * Client A (Bridge役) と Client B (TUI役) が共有app-serverに接続。
 * Client B が turn/start した際に Client A がイベントを受信するか検証。
 */

import { WebSocket } from "ws";
import { spawn } from "node:child_process";

const PORT = 19877;
const WS_URL = `ws://127.0.0.1:${PORT}`;
const CWD = process.env.HOME;

let nextId = 1;

function createClient(name) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(WS_URL);
    const pending = new Map();
    const notifications = [];

    ws.on("open", () => resolve({ ws, pending, notifications, name }));
    ws.on("error", reject);
    ws.on("message", (raw) => {
      const msg = JSON.parse(raw.toString());
      // Log all messages
      console.log(`  [${name}:recv] ${JSON.stringify(msg).slice(0, 300)}`);
      if (msg.id != null && pending.has(msg.id)) {
        const { resolve: res, reject: rej } = pending.get(msg.id);
        pending.delete(msg.id);
        if (msg.error) rej(msg.error);
        else res(msg.result);
      } else if (msg.method) {
        notifications.push(msg);
      }
    });
  });
}

function request(client, method, params = {}) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    client.pending.set(id, { resolve, reject });
    const msg = JSON.stringify({ id, method, params });
    console.log(`  [${client.name}:send] ${msg.slice(0, 300)}`);
    client.ws.send(msg);
    setTimeout(() => {
      if (client.pending.has(id)) {
        client.pending.delete(id);
        reject(new Error(`timeout: ${method}`));
      }
    }, 30_000);
  });
}

function notify(client, method, params = {}) {
  const msg = JSON.stringify({ method, params });
  console.log(`  [${client.name}:send] ${msg.slice(0, 200)}`);
  client.ws.send(msg);
}

async function initialize(client) {
  const result = await request(client, "initialize", {
    clientInfo: {
      name: `verify_bidir_${client.name}`,
      title: `Verify ${client.name}`,
      version: "0.0.1",
    },
  });
  notify(client, "initialized");
  return result;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function log(label, msg) {
  console.log(`[${label}] ${msg}`);
}

async function main() {
  log("server", `Starting codex app-server on ${WS_URL} ...`);
  const server = spawn("codex", ["app-server", "--listen", `ws://127.0.0.1:${PORT}`], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env },
  });

  server.stderr.on("data", (chunk) => {
    if (process.env.VERBOSE) process.stderr.write(`  [server:err] ${chunk}`);
  });
  server.stdout.on("data", (chunk) => {
    if (process.env.VERBOSE) process.stdout.write(`  [server:out] ${chunk}`);
  });

  log("server", "Waiting for readyz ...");
  for (let i = 0; i < 30; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/readyz`);
      if (res.ok) break;
    } catch { /* not ready */ }
    await sleep(500);
  }
  log("server", "Ready!");

  try {
    // === Client A (Bridge役) connects ===
    log("A", "Connecting ...");
    const clientA = await createClient("A");
    await initialize(clientA);
    log("A", "Initialized");

    // Client A starts a thread
    log("A", "thread/start ...");
    const startResult = await request(clientA, "thread/start", {
      cwd: CWD,
      experimentalRawEvents: false,
      persistExtendedHistory: false,
    });
    const threadId = startResult.thread.id;
    log("A", `Thread created: ${threadId}`);

    // === Client B (TUI役) connects ===
    log("B", "Connecting ...");
    const clientB = await createClient("B");
    await initialize(clientB);
    log("B", "Initialized");

    // Client B resumes the thread
    log("B", `thread/resume ${threadId} ...`);
    const resumeResult = await request(clientB, "thread/resume", {
      threadId,
      persistExtendedHistory: false,
    });
    log("B", `Resumed: ${resumeResult.thread.id}`);

    // Clear notifications before test
    clientA.notifications.length = 0;
    clientB.notifications.length = 0;

    // === TEST 1: Client A sends turn, check Client B receives ===
    log("TEST1", "Client A (Bridge) sends turn/start ...");
    const turn1 = await request(clientA, "turn/start", {
      threadId,
      input: [{ type: "text", text: "Say exactly: HELLO_FROM_A", text_elements: [] }],
    });
    log("TEST1", `Turn started: ${turn1.id}`);

    log("TEST1", "Waiting 10s for events ...");
    await sleep(10000);

    log("TEST1", `Client A received ${clientA.notifications.length} notifications`);
    log("TEST1", `Client B received ${clientB.notifications.length} notifications`);
    const bMethods1 = [...new Set(clientB.notifications.map(n => n.method))];
    log("TEST1", `Client B event types: ${bMethods1.join(", ")}`);
    const aHasItems1 = clientA.notifications.some(n => n.method?.startsWith("item/"));
    const bHasItems1 = clientB.notifications.some(n => n.method?.startsWith("item/"));
    log("TEST1", `A gets item events: ${aHasItems1 ? "✅" : "❌"}`);
    log("TEST1", `B gets item events: ${bHasItems1 ? "✅" : "❌"}`);

    // Clear for next test
    clientA.notifications.length = 0;
    clientB.notifications.length = 0;

    // === TEST 2: Client B sends turn, check Client A receives ===
    log("TEST2", "Client B (TUI) sends turn/start ...");
    const turn2 = await request(clientB, "turn/start", {
      threadId,
      input: [{ type: "text", text: "Say exactly: HELLO_FROM_B", text_elements: [] }],
    });
    log("TEST2", `Turn started: ${turn2.id}`);

    log("TEST2", "Waiting 10s for events ...");
    await sleep(10000);

    log("TEST2", `Client A received ${clientA.notifications.length} notifications`);
    log("TEST2", `Client B received ${clientB.notifications.length} notifications`);
    const aMethods2 = [...new Set(clientA.notifications.map(n => n.method))];
    log("TEST2", `Client A event types: ${aMethods2.join(", ")}`);
    const aHasItems2 = clientA.notifications.some(n => n.method?.startsWith("item/"));
    const bHasItems2 = clientB.notifications.some(n => n.method?.startsWith("item/"));
    log("TEST2", `A gets item events: ${aHasItems2 ? "✅" : "❌"}`);
    log("TEST2", `B gets item events: ${bHasItems2 ? "✅" : "❌"}`);

    // Summary
    console.log("\n=== Summary ===");
    console.log(`TEST1 (A→B): A items=${aHasItems1?"✅":"❌"}, B items=${bHasItems1?"✅":"❌"}`);
    console.log(`TEST2 (B→A): A items=${aHasItems2?"✅":"❌"}, B items=${bHasItems2?"✅":"❌"}`);

    clientA.ws.close();
    clientB.ws.close();
  } finally {
    server.kill();
    log("server", "Stopped");
  }
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
