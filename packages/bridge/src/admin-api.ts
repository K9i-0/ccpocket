import { randomBytes } from "node:crypto";
import { chmod, mkdir, writeFile } from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";
import { dirname } from "node:path";
import {
  apiKeyPath,
  isLocalPairingRequest,
  type ApiKeySource,
} from "./bridge-auth.js";
import {
  bridgeConfigPath,
  describeBridgeConfig,
  mergeBridgeSettings,
  readBridgeConfigFile,
  writeBridgeConfigFile,
  type AppliedBridgeConfig,
} from "./bridge-config.js";
import type { LogBuffer } from "./log-buffer.js";

/**
 * Local management API (`/admin/*`) used by the desktop app on the same
 * machine. It can change what the Bridge may access, so it is deliberately not
 * reachable with the API key that paired phones hold: every request must pass
 * the same checks as `/pairing` (loopback peer, loopback Host, no Origin, and
 * the per-start pairing secret that only the Bridge's OS user can read).
 * See docs/design/local-bridge-management.md.
 */
export const ADMIN_API_VERSION = 1;

const MAX_BODY_BYTES = 64 * 1024;

/** Set by launchers that restart the Bridge when it exits. */
export const SUPERVISED_ENV = "CCPOCKET_BRIDGE_SUPERVISED";
/** Set by launchers to start without the saved settings (see index.ts). */
export const SAFE_MODE_ENV = "CCPOCKET_BRIDGE_SAFE_MODE";
/** Label of the service written by `ccpocket-bridge setup` (KeepAlive). */
const SETUP_LAUNCHD_LABEL = "com.ccpocket.bridge";

/** Whether something will start the Bridge again after it exits. */
export function isSupervised(env: NodeJS.ProcessEnv = process.env): boolean {
  return (
    env[SUPERVISED_ENV] === "1" ||
    env.XPC_SERVICE_NAME === SETUP_LAUNCHD_LABEL
  );
}

export interface AdminContext {
  pairingSecret: string | null;
  port: number;
  version: string;
  startedAt: number;
  appliedConfig: AppliedBridgeConfig;
  apiKeySource: ApiKeySource;
  /** The saved settings were ignored for this run. */
  safeMode?: boolean;
  logs: LogBuffer;
  counts: () => { sessions: number; clients: number };
  /** Exit so the supervisor starts a fresh Bridge. */
  restart: () => void;
  env?: NodeJS.ProcessEnv;
  configPath?: string;
  apiKeyFile?: string;
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  });
  res.end(JSON.stringify(body));
}

async function readJsonBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += (chunk as Buffer).length;
    if (size > MAX_BODY_BYTES) throw new Error("body too large");
    chunks.push(chunk as Buffer);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

/**
 * Handle an `/admin/*` request. Returns false for other paths. Must run before
 * CORS headers are attached so a browser can never read a response.
 */
export function handleAdminRequest(
  req: IncomingMessage,
  res: ServerResponse,
  ctx: AdminContext,
): boolean {
  const url = new URL(req.url ?? "/", "http://localhost");
  if (!url.pathname.startsWith("/admin/")) return false;

  if (!isLocalPairingRequest(req, ctx.pairingSecret)) {
    res.writeHead(403, { "Content-Type": "text/plain" });
    res.end("Forbidden");
    return true;
  }

  route(req, res, ctx, url).catch((err) => {
    if (!res.headersSent) sendJson(res, 500, { error: String(err) });
  });
  return true;
}

async function route(
  req: IncomingMessage,
  res: ServerResponse,
  ctx: AdminContext,
  url: URL,
): Promise<void> {
  const env = ctx.env ?? process.env;
  const configPath = ctx.configPath ?? bridgeConfigPath(env);
  const key = `${req.method} ${url.pathname}`;

  const configView = async () =>
    describeBridgeConfig(
      ctx.appliedConfig,
      (await readBridgeConfigFile(configPath)).settings,
      configPath,
    );

  switch (key) {
    case "GET /admin/status": {
      sendJson(res, 200, {
        adminApiVersion: ADMIN_API_VERSION,
        version: ctx.version,
        port: ctx.port,
        pid: process.pid,
        startedAt: ctx.startedAt,
        supervised: isSupervised(env),
        apiKeySource: ctx.apiKeySource,
        safeMode: ctx.safeMode ?? false,
        restartRequired: (await configView()).restartRequired,
        ...ctx.counts(),
      });
      return;
    }

    case "GET /admin/config":
      sendJson(res, 200, await configView());
      return;

    case "PUT /admin/config": {
      let body: unknown;
      try {
        body = await readJsonBody(req);
      } catch {
        sendJson(res, 400, { error: "invalid_body" });
        return;
      }
      const patch =
        body !== null && typeof body === "object"
          ? (body as { settings?: unknown }).settings
          : undefined;
      const current = (await readBridgeConfigFile(configPath)).settings;
      const merged = mergeBridgeSettings(current, patch);
      if (!merged.ok) {
        sendJson(res, 400, { error: "invalid_settings", errors: merged.errors });
        return;
      }
      await writeBridgeConfigFile(merged.settings, configPath);
      console.log("[bridge] Settings saved from the local management API");
      sendJson(res, 200, await configView());
      return;
    }

    case "POST /admin/api-key/rotate": {
      // A key given by env/flag is not ours to replace; no key means auth is off.
      if (ctx.apiKeySource === "configured" || ctx.apiKeySource === "disabled") {
        sendJson(res, 409, { error: `api_key_${ctx.apiKeySource}` });
        return;
      }
      const path = ctx.apiKeyFile ?? apiKeyPath();
      const apiKey = randomBytes(24).toString("base64url");
      await mkdir(dirname(path), { recursive: true, mode: 0o700 });
      await writeFile(path, `${apiKey}\n`, { mode: 0o600 });
      await chmod(path, 0o600);
      console.log(
        "[bridge] API key replaced from the local management API; it applies after a restart",
      );
      sendJson(res, 200, { restartRequired: true });
      return;
    }

    case "POST /admin/restart": {
      if (!isSupervised(env)) {
        sendJson(res, 409, { error: "not_supervised" });
        return;
      }
      sendJson(res, 202, { restarting: true });
      console.log("[bridge] Restart requested from the local management API");
      // Let the response flush before the process exits.
      res.once("finish", () => setTimeout(ctx.restart, 100));
      return;
    }

    case "GET /admin/logs": {
      const limit = Number(url.searchParams.get("limit") ?? "500");
      sendJson(res, 200, {
        entries: ctx.logs.tail(
          Number.isSafeInteger(limit) && limit > 0 ? limit : 500,
        ),
      });
      return;
    }

    default:
      sendJson(res, 404, { error: "not_found" });
  }
}
