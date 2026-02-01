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
  console.log(`[test] Received: ${JSON.stringify(msg).slice(0, 200)}`);
});

ws.on("error", (err) => {
  console.error("[test] Connection error:", err.message);
  process.exit(1);
});

// Wait for initial messages, then run tests
setTimeout(async () => {
  console.log("\n=== Test 1: Session list on connect ===");
  const sessionList = received.find((m) => m.type === "session_list");
  assert(sessionList !== undefined, "Received session_list on connect");
  assert(Array.isArray(sessionList?.sessions), "session_list contains sessions array");

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

  console.log("\n=== Test 3: List sessions ===");
  received.length = 0;
  ws.send(JSON.stringify({ type: "list_sessions" }));
  await sleep(500);
  const listResp = received.find((m) => m.type === "session_list");
  assert(listResp !== undefined, "Received session_list response");

  console.log("\n=== Test 4: Start session ===");
  received.length = 0;
  ws.send(
    JSON.stringify({
      type: "start",
      projectPath: "/tmp/test-project",
      permissionMode: "default",
    })
  );
  await sleep(5000);
  const sessionCreated = received.find(
    (m) => m.type === "system" && m.subtype === "session_created"
  );
  assert(sessionCreated !== undefined, "Received session_created event");

  const sessionId = sessionCreated?.sessionId;
  console.log(`  Session ID: ${sessionId}`);

  if (sessionId) {
    console.log("\n=== Test 5: Session appears in list ===");
    received.length = 0;
    ws.send(JSON.stringify({ type: "list_sessions" }));
    await sleep(500);
    const listAfter = received.find((m) => m.type === "session_list");
    const found = listAfter?.sessions?.some((s) => s.id === sessionId);
    assert(found, "New session appears in session list");

    console.log("\n=== Test 6: Stop session ===");
    received.length = 0;
    ws.send(JSON.stringify({ type: "stop_session", sessionId }));
    await sleep(1000);
    ws.send(JSON.stringify({ type: "list_sessions" }));
    await sleep(500);
    const listAfterStop = received.find((m) => m.type === "session_list");
    const notFound = !listAfterStop?.sessions?.some((s) => s.id === sessionId);
    assert(notFound, "Stopped session removed from list");
  }

  console.log(
    `\n=== Results: ${testsPassed} passed, ${testsFailed} failed ===`
  );
  ws.close();
  process.exit(testsFailed > 0 ? 1 : 0);
}, 1000);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
