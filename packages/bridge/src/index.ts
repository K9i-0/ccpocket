import { BridgeWebSocketServer } from "./websocket.js";

const PORT = parseInt(process.env.BRIDGE_PORT ?? "8765", 10);

console.log("[bridge] Starting ccpocket bridge server...");

const server = new BridgeWebSocketServer(PORT);

function shutdown() {
  console.log("\n[bridge] Shutting down gracefully...");
  server.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

console.log(`[bridge] Ready. Listening on ws://localhost:${PORT}`);
