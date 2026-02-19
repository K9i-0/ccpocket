import { createHash } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
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
  data?: Record<string, string>;
};

type RelayBody = RegisterBody | UnregisterBody | NotifyBody;

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

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
    return { op, bridgeId: "", token, platform };
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
    const data =
      typeof body.data === "object" && body.data != null
        ? Object.fromEntries(
            Object.entries(body.data as Record<string, unknown>)
              .filter(([, v]) => v != null)
              .map(([k, v]) => [k, String(v)]),
          )
        : undefined;
    return { op, bridgeId: "", eventType, title, body: bodyText, data };
  }

  return null;
}

async function handleRegister(body: RegisterBody): Promise<void> {
  const ref = db.doc(tokenDocPath(body.bridgeId, body.token));
  const snapshot = await ref.get();
  if (snapshot.exists) {
    await ref.update({
      token: body.token,
      platform: body.platform,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return;
  }
  await ref.set({
    token: body.token,
    platform: body.platform,
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

export const relay = onRequest({ cors: true }, async (req, res) => {
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

  const parsed = parseRelayBody(req.body);
  if (!parsed) {
    res.status(400).json({ error: "Invalid request body" });
    return;
  }

  // Override bridgeId with authenticated UID for security.
  // This prevents a client from accessing another bridge's tokens.
  parsed.bridgeId = uid;

  try {
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
