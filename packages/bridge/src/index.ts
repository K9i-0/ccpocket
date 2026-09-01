import { createServer } from "node:http";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";
import { setupProxy } from "./proxy.js";
import { BridgeWebSocketServer } from "./websocket.js";
import { ImageStore } from "./image-store.js";
import { MediaStore } from "./media-store.js";
import { UploadStore } from "./upload-store.js";
import { GalleryStore } from "./gallery-store.js";
import { printStartupInfo } from "./startup-info.js";
import { MdnsAdvertiser, shouldAdvertiseMdns } from "./mdns.js";
import { ProjectHistory } from "./project-history.js";
import { WorkspaceStore } from "./workspace-store.js";
import { getVersionInfo } from "./version.js";
import { fetchAllUsage } from "./usage.js";
import { runDoctor } from "./doctor.js";
import { DebugTraceStore } from "./debug-trace-store.js";
import { RecordingStore } from "./recording-store.js";
import { FirebaseAuthClient } from "./firebase-auth.js";
import { PromptHistoryBackupStore } from "./prompt-history-backup.js";
import {
  promptHistoryStoreFileForPort,
  PromptHistoryStore,
} from "./prompt-history-store.js";
import { parseAllowedDirectories } from "./path-utils.js";
import { parseBridgePort } from "./bridge-port.js";
import { listenForStartup } from "./server-listen.js";

function startupErrorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

function positiveEnvInt(name: string, fallback: number): number {
  const value = Number(process.env[name]);
  return Number.isSafeInteger(value) && value > 0 ? value : fallback;
}

export async function startServer() {
  const PORT = parseBridgePort();
  const HOST = process.env.BRIDGE_HOST ?? "0.0.0.0";
  const API_KEY = process.env.BRIDGE_API_KEY;
  const MDNS_ENABLED = shouldAdvertiseMdns(
    process.platform,
    !!process.env.BRIDGE_DISABLE_MDNS,
  );

  // Unrestricted access requires the exact value "*".
  const ALLOWED_DIRS = parseAllowedDirectories(
    process.env.BRIDGE_ALLOWED_DIRS,
    process.platform,
    [homedir()],
  );

  console.log("[bridge] Starting ccpocket bridge server...");

  if (API_KEY) {
    console.log("[bridge] API key authentication enabled");
  }

  if (!MDNS_ENABLED) {
    console.log(
      process.platform === "darwin"
        ? "[bridge] mDNS advertisement disabled on macOS"
        : "[bridge] mDNS advertisement disabled",
    );
  }

  console.log(
    `[bridge] Allowed dirs: ${
      ALLOWED_DIRS.length > 0 ? ALLOWED_DIRS.join(", ") : "(unrestricted)"
    }`,
  );

  // Initialize Firebase Anonymous Auth for push notifications
  let firebaseAuth: FirebaseAuthClient | undefined;
  try {
    firebaseAuth = new FirebaseAuthClient();
    await firebaseAuth.initialize();
    console.log("[bridge] Push relay enabled (Firebase Anonymous Auth)");
  } catch (err) {
    console.warn("[bridge] Push relay disabled: Firebase auth failed:", err);
    firebaseAuth = undefined;
  }

  const imageStore = new ImageStore();
  const mediaStore = new MediaStore();
  const uploadStore = new UploadStore({
    maxReservedBytes:
      positiveEnvInt("BRIDGE_FILE_UPLOAD_MAX_RESERVED_MB", 2048) *
      1024 *
      1024,
    maxConcurrentReceives: positiveEnvInt(
      "BRIDGE_FILE_UPLOAD_MAX_CONCURRENT",
      4,
    ),
  });
  const galleryStore = new GalleryStore();
  const projectHistory = new ProjectHistory();
  const workspaceStore = new WorkspaceStore({
    ...(process.env.BRIDGE_WORKSPACE_FILE
      ? { filePath: process.env.BRIDGE_WORKSPACE_FILE }
      : {}),
  });
  const debugTraceStore = new DebugTraceStore();
  const RECORDING_ENABLED = !!process.env.BRIDGE_RECORDING;
  const recordingStore = RECORDING_ENABLED ? new RecordingStore() : undefined;
  const promptHistoryBackup = new PromptHistoryBackupStore();
  const promptHistoryStore = new PromptHistoryStore(
    promptHistoryStoreFileForPort(
      PORT,
      process.env.BRIDGE_PROMPT_HISTORY_FILE,
    ),
  );
  const mdns = MDNS_ENABLED ? new MdnsAdvertiser() : undefined;

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

  await workspaceStore.init().then(() => {
    console.log("[bridge] Workspace store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize workspace store:", err);
  });

  debugTraceStore.init().then(() => {
    console.log("[bridge] Debug trace store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize debug trace store:", err);
  });

  if (recordingStore) {
    recordingStore.init().then(() => {
      console.log("[bridge] Recording enabled");
    }).catch((err) => {
      console.error("[bridge] Failed to initialize recording store:", err);
    });
  }

  promptHistoryBackup.init().then(() => {
    console.log("[bridge] Prompt history backup store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize prompt history backup store:", err);
  });

  await promptHistoryStore.init().then(() => {
    console.log("[bridge] Prompt history store initialized");
  }).catch((err) => {
    console.error("[bridge] Failed to initialize prompt history store:", err);
  });

  const startedAt = Date.now();
  let wsServer: BridgeWebSocketServer | null = null;

  const httpServer = createServer((req, res) => {
    const defaultBodyDeadline = setTimeout(
      () => req.destroy(),
      5 * 60 * 1000,
    );
    defaultBodyDeadline.unref();
    const clearDefaultBodyDeadline = () => {
      clearTimeout(defaultBodyDeadline);
    };
    req.once("end", clearDefaultBodyDeadline);
    req.once("close", clearDefaultBodyDeadline);

    // CORS headers for Flutter Web clients
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader(
      "Access-Control-Allow-Methods",
      "GET, HEAD, POST, PUT, DELETE, OPTIONS",
    );
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Content-Length, Range");
    res.setHeader(
      "Access-Control-Expose-Headers",
      "Accept-Ranges, Content-Length, Content-Range, X-File-SHA256, X-Received-Bytes",
    );

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

    // Usage endpoint
    if (req.url === "/usage" && req.method === "GET") {
      fetchAllUsage()
        .then((providers) => {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ providers }));
        })
        .catch((err) => {
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: String(err) }));
        });
      return;
    }

    // Doctor endpoint
    if (req.url === "/doctor" && req.method === "GET") {
      runDoctor()
        .then((report) => {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify(report));
        })
        .catch((err) => {
          res.writeHead(500, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: String(err) }));
        });
      return;
    }

    // Serve images via ImageStore (in-memory, session-scoped)
    if (imageStore.handleRequest(req, res)) return;

    // Stream local media registered by an authenticated read_file request.
    if (mediaStore.handleRequest(req, res)) return;

    // Receive files through short-lived capabilities prepared over WebSocket.
    if (uploadStore.handleRequest(req, res, clearDefaultBodyDeadline)) return;

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
  // UploadStore applies its own one-hour total and one-minute idle deadlines.
  // Other HTTP requests retain a five-minute total deadline above.
  httpServer.requestTimeout = 60 * 60 * 1000;

  wsServer = new BridgeWebSocketServer({
    server: httpServer,
    apiKey: API_KEY,
    allowedDirs: ALLOWED_DIRS,
    imageStore,
    mediaStore,
    uploadStore,
    galleryStore,
    projectHistory,
    workspaceStore,
    debugTraceStore,
    recordingStore,
    firebaseAuth,
    promptHistoryBackup,
    promptHistoryStore,
  });

  let shuttingDown = false;
  async function shutdown() {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log("\n[bridge] Shutting down gracefully...");
    mdns?.stop();
    wsServer?.close();
    await uploadStore.dispose();
    httpServer.close();
    process.exit(0);
  }

  try {
    await listenForStartup(httpServer, PORT, HOST);
  } catch (err) {
    wsServer.close();
    httpServer.close();
    throw err;
  }

  console.log(
    `[bridge] Ready. Listening on http://${HOST}:${PORT} (HTTP + WebSocket)`,
  );
  mdns?.start(PORT, API_KEY);
  printStartupInfo(PORT, HOST, API_KEY);

  process.on("SIGINT", () => void shutdown());
  process.on("SIGTERM", () => void shutdown());
}

// Auto-start when executed directly (node dist/index.js, tsx src/index.ts)
const isDirectExecution =
  process.argv[1] &&
  fileURLToPath(import.meta.url) === process.argv[1];

if (isDirectExecution) {
  setupProxy();
  startServer().catch((err) => {
    console.error(`[bridge] Failed to start: ${startupErrorMessage(err)}`);
    process.exit(1);
  });
}
