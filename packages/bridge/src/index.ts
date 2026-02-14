import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import { BridgeWebSocketServer } from "./websocket.js";
import { ImageStore } from "./image-store.js";
import { GalleryStore } from "./gallery-store.js";
import { printStartupInfo } from "./startup-info.js";
import { MdnsAdvertiser } from "./mdns.js";
import { ProjectHistory } from "./project-history.js";
import { getVersionInfo } from "./version.js";
import { DebugTraceStore } from "./debug-trace-store.js";

export function startServer() {
  const PORT = parseInt(process.env.BRIDGE_PORT ?? "8765", 10);
  const HOST = process.env.BRIDGE_HOST ?? "0.0.0.0";
  const API_KEY = process.env.BRIDGE_API_KEY;
  const PUSH_RELAY_URL = process.env.PUSH_RELAY_URL;
  const PUSH_RELAY_SECRET = process.env.PUSH_RELAY_SECRET;

  console.log("[bridge] Starting ccpocket bridge server...");

  if (API_KEY) {
    console.log("[bridge] API key authentication enabled");
  } else {
    console.log("[bridge] WARNING: No BRIDGE_API_KEY set - authentication disabled");
  }
  if (PUSH_RELAY_URL && PUSH_RELAY_SECRET) {
    console.log("[bridge] Push relay configured");
  } else {
    console.log("[bridge] Push relay disabled");
  }

  const imageStore = new ImageStore();
  const galleryStore = new GalleryStore();
  const projectHistory = new ProjectHistory();
  const debugTraceStore = new DebugTraceStore();
  const mdns = new MdnsAdvertiser();

  // Initialize stores (async)
  galleryStore.init().then(() => {
    console.log("[bridge] Gallery store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize gallery store:", err);
  });

  projectHistory.init().then(() => {
    console.log("[bridge] Project history initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize project history:", err);
  });

  debugTraceStore.init().then(() => {
    console.log("[bridge] Debug trace store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize debug trace store:", err);
  });

  const startedAt = Date.now();
  let wsServer: BridgeWebSocketServer | null = null;

  const httpServer = createServer((req, res) => {
    // CORS headers for Flutter Web clients
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

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

    // Version info endpoint
    if (req.url === "/version" && req.method === "GET") {
      const body = JSON.stringify(getVersionInfo(startedAt));
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(body);
      return;
    }

    // Serve images via ImageStore (in-memory, session-scoped)
    if (imageStore.handleRequest(req, res)) return;

    // Serve gallery images via GalleryStore (disk-persistent)
    if (galleryStore.handleRequest(req, res)) return;

    // Upload images via POST /api/gallery/upload
    if (galleryStore.handleUploadRequest(req, res, (meta) => {
      if (wsServer) {
        const info = galleryStore.metaToInfo(meta);
        wsServer.broadcastGalleryNewImage(info);
      }
    })) return;

    // Default 404 for unknown HTTP requests
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("Not Found");
  });

  wsServer = new BridgeWebSocketServer({
    server: httpServer,
    apiKey: API_KEY,
    imageStore,
    galleryStore,
    projectHistory,
    debugTraceStore,
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
}

// Auto-start when executed directly (node dist/index.js, tsx src/index.ts)
const isDirectExecution =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === process.argv[1];

if (isDirectExecution) {
  startServer();
}
