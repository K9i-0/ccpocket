import { createServer } from "node:http";
import { BridgeWebSocketServer } from "./websocket.js";
import { ImageStore } from "./image-store.js";
import { GalleryStore } from "./gallery-store.js";
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
const galleryStore = new GalleryStore();
const mdns = new MdnsAdvertiser();

// Initialize gallery store (async)
galleryStore.init().then(() => {
  console.log("[bridge] Gallery store initialized");
}).catch((err) => {
  console.error("[bridge] Failed to initialize gallery store:", err);
});

const startedAt = Date.now();
let wsServer: BridgeWebSocketServer | null = null;

const httpServer = createServer((req, res) => {
  // Health check endpoint
  if (req.url === "/health" && req.method === "GET") {
    const body = JSON.stringify({
      status: "ok",
      uptime: Math.floor((Date.now() - startedAt) / 1000),
      sessions: wsServer?.sessionCount ?? 0,
      clients: wsServer?.clientCount ?? 0,
    });
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(body);
    return;
  }

  // Serve images via ImageStore (in-memory, session-scoped)
  if (imageStore.handleRequest(req, res)) return;

  // Serve gallery images via GalleryStore (disk-persistent)
  if (galleryStore.handleRequest(req, res)) return;

  // Default 404 for unknown HTTP requests
  res.writeHead(404, { "Content-Type": "text/plain" });
  res.end("Not Found");
});

wsServer = new BridgeWebSocketServer({
  server: httpServer,
  apiKey: API_KEY,
  imageStore,
  galleryStore,
});

httpServer.listen(PORT, HOST, () => {
  console.log(`[bridge] Ready. Listening on http://${HOST}:${PORT} (HTTP + WebSocket)`);
  mdns.start(PORT, API_KEY);
  printStartupInfo(PORT, HOST, API_KEY);
});

function shutdown() {
  console.log("\n[bridge] Shutting down gracefully...");
  mdns.stop();
  wsServer?.close();
  httpServer.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
