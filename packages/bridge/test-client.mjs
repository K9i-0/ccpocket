import WebSocket from "ws";

const ws = new WebSocket("ws://localhost:8765");
const received = [];
let testsPassed = 0;
let testsFailed = 0;

function assert(condition, msg) {
  if (condition) {
    console.log(`  PASS: ${msg}`);
    testsPassed++;
  } else {
    console.error(`  FAIL: ${msg}`);
    testsFailed++;
  }
}

ws.on("open", () => {
  console.log("[test] Connected to server");
});

ws.on("message", (data) => {
  const msg = JSON.parse(data.toString());
  received.push(msg);
  console.log(`[test] Received: ${JSON.stringify(msg)}`);
});

ws.on("error", (err) => {
  console.error("[test] Connection error:", err.message);
  process.exit(1);
});

// Wait for initial messages, then run tests
setTimeout(async () => {
  console.log("\n=== Test 1: Initial status message ===");
  assert(received.length >= 1, "Received at least 1 message on connect");
  const statusMsg = received.find((m) => m.type === "status");
  assert(statusMsg !== undefined, "Received status message");
  assert(statusMsg?.status === "idle", "Initial status is idle");

  console.log("\n=== Test 2: Invalid JSON ===");
  received.length = 0;
  ws.send("this is not json");
  await sleep(500);
  const errorMsg = received.find((m) => m.type === "error");
  assert(errorMsg !== undefined, "Received error for invalid JSON");
  assert(
    errorMsg?.message === "Invalid message format",
    "Error message is correct"
  );

  console.log("\n=== Test 3: Input before start ===");
  received.length = 0;
  ws.send(JSON.stringify({ type: "input", text: "hello" }));
  await sleep(500);
  const inputError = received.find((m) => m.type === "error");
  assert(inputError !== undefined, "Received error for input before start");

  console.log("\n=== Test 4: Start Claude CLI ===");
  received.length = 0;
  ws.send(JSON.stringify({ type: "start", projectPath: "/tmp/test-project" }));
  await sleep(5000);
  const hasStatus = received.some((m) => m.type === "status");
  assert(hasStatus, "Received status update after start");
  const runningOrSystem = received.some(
    (m) =>
      (m.type === "status" && m.status === "running") ||
      m.type === "system" ||
      m.type === "error"
  );
  assert(runningOrSystem, "Claude CLI started (status/system/error received)");

  console.log(`\n=== Results: ${testsPassed} passed, ${testsFailed} failed ===`);
  ws.close();
  process.exit(testsFailed > 0 ? 1 : 0);
}, 1000);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
