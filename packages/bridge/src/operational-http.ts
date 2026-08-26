import type { IncomingMessage, ServerResponse } from "node:http";
import { createHash, timingSafeEqual } from "node:crypto";
import { readCodexAppServerMode } from "./codex-app-server-config.js";
import {
  BRIDGE_PROTOCOL_MODE,
  BRIDGE_READINESS_SCHEMA,
  getBridgeGeneration,
  getPackageVersion,
  getVersionInfo,
  loadRuntimeManifest,
} from "./version.js";

export interface CoreBridgeHttpOptions {
  startedAt: number;
  apiKey?: string;
  env?: NodeJS.ProcessEnv;
  getSessionCount: () => number;
  getClientCount: () => number;
  getReadinessCounts: () => {
    activeTurns: number;
    pendingApprovals: number;
    pendingQuestions: number;
    busyWorkers: number;
    clients: number;
  };
}

export function handleCoreBridgeHttpRequest(
  req: IncomingMessage,
  res: ServerResponse,
  options: CoreBridgeHttpOptions,
): boolean {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return true;
  }

  let pathname: string;
  try {
    pathname = new URL(req.url ?? "/", "http://bridge.invalid").pathname;
  } catch {
    return false;
  }

  if (req.url === "/health" && req.method === "GET") {
    writeJson(res, 200, {
      status: "ok",
      uptime: Math.floor((Date.now() - options.startedAt) / 1000),
      sessions: options.getSessionCount(),
      clients: options.getClientCount(),
    });
    return true;
  }

  if (req.url === "/version" && req.method === "GET") {
    writeJson(res, 200, getVersionInfo(options.startedAt));
    return true;
  }

  if (
    req.method !== "GET" ||
    (pathname !== "/server-info" && pathname !== "/readiness")
  ) {
    return false;
  }

  res.setHeader("Cache-Control", "no-store");
  if (!options.apiKey) {
    writeJson(res, 503, { code: "auth_unavailable" });
    return true;
  }

  const suppliedToken = readBearerToken(req.headers.authorization);
  if (!suppliedToken || !safeTokenEquals(suppliedToken, options.apiKey)) {
    writeJson(res, 401, { code: "unauthorized" });
    return true;
  }

  if (pathname === "/readiness") {
    writeJson(res, 200, {
      schema: BRIDGE_READINESS_SCHEMA,
      sampledAt: new Date().toISOString(),
      ...options.getReadinessCounts(),
    });
    return true;
  }

  const env = options.env ?? process.env;
  try {
    const runtimeManifest = loadRuntimeManifest(env);
    writeJson(res, 200, {
      schema: "ccpocket-bridge-server-info/v1",
      packageVersion: getPackageVersion(),
      protocolMode: BRIDGE_PROTOCOL_MODE,
      codexAppServerMode: readCodexAppServerMode(env),
      generation: getBridgeGeneration(),
      runtimeManifest,
    });
  } catch {
    writeJson(res, 503, { code: "identity_unavailable" });
  }
  return true;
}

function readBearerToken(authorization: string | undefined): string | null {
  if (!authorization) return null;
  const match = /^Bearer ([^\s]+)$/.exec(authorization);
  return match?.[1] ?? null;
}

function safeTokenEquals(supplied: string, expected: string): boolean {
  const suppliedHash = createHash("sha256").update(supplied).digest();
  const expectedHash = createHash("sha256").update(expected).digest();
  return timingSafeEqual(suppliedHash, expectedHash);
}

function writeJson(
  res: ServerResponse,
  status: number,
  body: unknown,
): void {
  res.writeHead(status, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
}
