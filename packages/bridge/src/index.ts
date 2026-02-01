import { createServer } from "node:http";
import { BridgeWebSocketServer } from "./websocket.js";
import { ImageStore } from "./image-store.js";
import { printStartupInfo } from "./startup-info.js";
import { MdnsAdvertiser } from "./mdns.js";

const PORT = parseInt(process.env.BRIDGE_PORT ?? "8765", 10);
const HOST = process.env.BRIDGE_HOST ?? "0.0.0.0";
const API_KEY = process.env.BRIDGE_API_KEY;

console.log("[bridge] Starting ccpocket bridge server...");

if (API_KEY) {
  console.log("[bridge] API key authentication enabled");
} else {
  console.log("[bridge] WARNING: No BRIDGE_API_KEY set - authentication disabled");
}

const imageStore = new ImageStore();
const mdns = new MdnsAdvertiser();

const httpServer = createServer((req, res) => {
  // Serve images via ImageStore
  if (imageStore.handleRequest(req, res)) return;

  // Default 404 for unknown HTTP requests
  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("Not Found");
});

const wsServer = new BridgeWebSocketServer({
  server: httpServer,
  apiKey: API_KEY,
  imageStore,
});

httpServer.listen(PORT, HOST, () => {
  console.log(`[bridge] Ready. Listening on http://${HOST}:${PORT} (HTTP + WebSocket)`);
  mdns.start(PORT, API_KEY);
  printStartupInfo(PORT, HOST, API_KEY);
});

function shutdown() {
  console.log("\n[bridge] Shutting down gracefully...");
  mdns.stop();
  wsServer.close();
  httpServer.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
