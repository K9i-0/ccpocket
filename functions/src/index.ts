import { createHash } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

type PushPlatform = "ios" | "android" | "web";

type RegisterBody = {
  op: "register";
  bridgeId: string;
  token: string;
  platform: PushPlatform;
  locale?: string;
};

type UnregisterBody = {
  op: "unregister";
  bridgeId: string;
  token: string;
};

type NotifyBody = {
  op: "notify";
  bridgeId: string;
  eventType: string;
  title: string;
  body: string;
  /** When set, only tokens with this locale receive the notification. */
  locale?: string;
  data?: Record<string, string>;
};

type RelayBody = RegisterBody | UnregisterBody | NotifyBody;

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();
const appCheck = getAppCheck();

/**
 * Verify Firebase App Check token from the X-Firebase-AppCheck header.
 * Returns true if valid or if App Check enforcement is not yet enabled
 * (controlled by the ENFORCE_APP_CHECK env var).
 */
async function verifyAppCheck(req: { header: (name: string) => string | undefined }): Promise<boolean> {
  const appCheckToken = req.header("x-firebase-appcheck");
  if (!appCheckToken) {
    return false;
  }
  try {
    await appCheck.verifyToken(appCheckToken);
    return true;
  } catch {
    return false;
  }
}

/** Whether to enforce App Check. Set to "true" after all clients are updated. */
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === "true";

// ---------- Rate limiting ----------

/** Max notify calls per bridge per window. */
const RATE_LIMIT_NOTIFY_MAX = 30;
/** Rate limit window in milliseconds (1 minute). */
const RATE_LIMIT_WINDOW_MS = 60_000;

/** Max register/unregister calls per bridge per window. */
const RATE_LIMIT_TOKEN_MAX = 20;

/**
 * Firestore-backed sliding-window rate limiter.
 * Uses a single document per bridge+op to track request timestamps.
 * Returns true if the request is allowed, false if rate-limited.
 */
async function checkRateLimit(
  bridgeId: string,
  op: "notify" | "token",
  limit: number,
): Promise<boolean> {
  const ref = db.doc(`rate_limits/${bridgeId}_${op}`);
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  return db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const data = doc.data() as { timestamps?: number[] } | undefined;
    const timestamps = (data?.timestamps ?? []).filter((t) => t > windowStart);

    if (timestamps.length >= limit) {
      return false;
    }

    timestamps.push(now);
    // expireAt enables Firestore TTL policy to auto-delete stale rate limit docs
    const expireAt = new Date(now + RATE_LIMIT_WINDOW_MS * 2);
    tx.set(ref, { timestamps, updatedAt: FieldValue.serverTimestamp(), expireAt });
    return true;
  });
}

// ---------- Helpers ----------

function sha256(input: string): string {
  return createHash("sha256").update(input).digest("hex");
}

function tokenDocPath(bridgeId: string, token: string): string {
  return `bridges/${bridgeId}/tokens/${sha256(token)}`;
}

function readBearerToken(authHeader: string | undefined): string | null {
  if (!authHeader) return null;
  const [scheme, token] = authHeader.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;
  return token.trim();
}

/**
 * Verify Firebase ID token and return the UID.
 * Returns null if the token is invalid or expired.
 */
async function verifyFirebaseToken(authHeader: string | undefined): Promise<string | null> {
  const bearer = readBearerToken(authHeader);
  if (!bearer) return null;
  try {
    const decoded = await auth.verifyIdToken(bearer);
    return decoded.uid;
  } catch {
    return null;
  }
}

function asNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function parseRelayBody(payload: unknown): RelayBody | null {
  if (typeof payload !== "object" || payload == null) return null;
  const body = payload as Record<string, unknown>;
  const op = asNonEmptyString(body.op);
  if (!op) return null;

  // bridgeId from request body is ignored; the authenticated UID is used instead.
  // We still parse it for backward compatibility but it will be overridden.

  if (op === "register") {
    const token = asNonEmptyString(body.token);
    const platform = body.platform;
    if (!token) return null;
    if (platform !== "ios" && platform !== "android" && platform !== "web") {
      return null;
    }
    const locale = asNonEmptyString(body.locale) ?? undefined;
    return { op, bridgeId: "", token, platform, locale };
  }

  if (op === "unregister") {
    const token = asNonEmptyString(body.token);
    if (!token) return null;
    return { op, bridgeId: "", token };
  }

  if (op === "notify") {
    const eventType = asNonEmptyString(body.eventType);
    const title = asNonEmptyString(body.title);
    const bodyText = asNonEmptyString(body.body);
    if (!eventType || !title || !bodyText) return null;
    const locale = asNonEmptyString(body.locale) ?? undefined;
    const data =
      typeof body.data === "object" && body.data != null
        ? Object.fromEntries(
            Object.entries(body.data as Record<string, unknown>)
              .filter(([, v]) => v != null)
              .map(([k, v]) => [k, String(v)]),
          )
        : undefined;
    return { op, bridgeId: "", eventType, title, body: bodyText, locale, data };
  }

  return null;
}

/**
 * Validate FCM token format.
 * Real FCM tokens are 100-300+ characters, alphanumeric with colons and hyphens.
 */
function isValidFcmToken(token: string): boolean {
  if (token.length < 32 || token.length > 4096) return false;
  // FCM tokens consist of base64-like chars, colons, hyphens, and underscores
  return /^[A-Za-z0-9_:+/=-]+$/.test(token);
}

async function handleRegister(body: RegisterBody): Promise<void> {
  if (!isValidFcmToken(body.token)) {
    throw new Error("Invalid FCM token format");
  }

  // Limit number of tokens per bridge to prevent abuse
  const existingTokens = await db.collection(`bridges/${body.bridgeId}/tokens`).count().get();
  if (existingTokens.data().count >= 20) {
    throw new Error("Too many registered tokens for this bridge");
  }

  const ref = db.doc(tokenDocPath(body.bridgeId, body.token));
  const snapshot = await ref.get();
  if (snapshot.exists) {
    const updateData: Record<string, unknown> = {
      token: body.token,
      platform: body.platform,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (body.locale) updateData.locale = body.locale;
    await ref.update(updateData);
    return;
  }
  await ref.set({
    token: body.token,
    platform: body.platform,
    ...(body.locale ? { locale: body.locale } : {}),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function handleUnregister(body: UnregisterBody): Promise<void> {
  const ref = db.doc(tokenDocPath(body.bridgeId, body.token));
  await ref.delete();
}

function isDeleteTargetError(code: string | undefined): boolean {
  return code === "messaging/registration-token-not-registered"
    || code === "messaging/invalid-registration-token";
}

async function handleNotify(body: NotifyBody): Promise<{
  tokenCount: number;
  successCount: number;
  failureCount: number;
  deletedInvalidTokens: number;
}> {
  const snapshot = await db.collection(`bridges/${body.bridgeId}/tokens`).get();
  const tokens = snapshot.docs
    .filter((d) => {
      // When locale is specified, only send to tokens with matching locale.
      // Tokens without a locale field are included when no locale filter is set (backward compat).
      if (!body.locale) return true;
      const tokenLocale = asNonEmptyString(d.get("locale"));
      return tokenLocale === body.locale || tokenLocale == null;
    })
    .map((d) => asNonEmptyString(d.get("token")))
    .filter((token): token is string => token != null);
  if (tokens.length === 0) {
    return {
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      deletedInvalidTokens: 0,
    };
  }

  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = new Set<string>();

  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title: body.title, body: body.body },
      data: body.data,
      android: {
        priority: "high",
        notification: {
          channelId: "ccpocket_channel",
          priority: "high",
          sound: "default",
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    });

    successCount += response.successCount;
    failureCount += response.failureCount;
    for (let j = 0; j < response.responses.length; j++) {
      const result = response.responses[j];
      if (!result.success && isDeleteTargetError(result.error?.code)) {
        invalidTokens.add(chunk[j]);
      }
    }
  }

  if (invalidTokens.size > 0) {
    await Promise.all(
      Array.from(invalidTokens).map((token) =>
        db.doc(tokenDocPath(body.bridgeId, token)).delete(),
      ),
    );
  }

  return {
    tokenCount: tokens.length,
    successCount,
    failureCount,
    deletedInvalidTokens: invalidTokens.size,
  };
}

export const relay = onRequest({ cors: true, maxInstances: 10 }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method Not Allowed" });
    return;
  }

  // Verify Firebase ID token
  const uid = await verifyFirebaseToken(req.header("authorization"));
  if (!uid) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  // Verify App Check token (soft-enforce until ENFORCE_APP_CHECK=true)
  const appCheckValid = await verifyAppCheck(req);
  if (!appCheckValid) {
    if (ENFORCE_APP_CHECK) {
      res.status(401).json({ error: "App Check verification failed" });
      return;
    }
    logger.warn("App Check token missing or invalid (not enforced yet)", { bridgeId: uid });
  }

  const parsed = parseRelayBody(req.body);
  if (!parsed) {
    res.status(400).json({ error: "Invalid request body" });
    return;
  }

  // Override bridgeId with authenticated UID for security.
  // This prevents a client from accessing another bridge's tokens.
  parsed.bridgeId = uid;

  try {
    // Rate limit check
    const rateLimitOp = parsed.op === "notify" ? "notify" as const : "token" as const;
    const rateLimitMax = parsed.op === "notify" ? RATE_LIMIT_NOTIFY_MAX : RATE_LIMIT_TOKEN_MAX;
    const allowed = await checkRateLimit(uid, rateLimitOp, rateLimitMax);
    if (!allowed) {
      logger.warn("Rate limit exceeded", { bridgeId: uid, op: parsed.op });
      res.status(429).json({ error: "Rate limit exceeded. Try again later." });
      return;
    }

    switch (parsed.op) {
      case "register":
        await handleRegister(parsed);
        res.status(200).json({ ok: true, op: parsed.op });
        return;
      case "unregister":
        await handleUnregister(parsed);
        res.status(200).json({ ok: true, op: parsed.op });
        return;
      case "notify": {
        const result = await handleNotify(parsed);
        logger.info("Push notification relay sent", {
          bridgeId: uid,
          eventType: parsed.eventType,
          ...result,
        });
        res.status(200).json({ ok: true, op: parsed.op, ...result });
        return;
      }
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    logger.error("Relay operation failed", { op: parsed.op, message });
    res.status(500).json({ error: message });
  }
});
