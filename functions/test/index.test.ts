import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  verifyIdToken: vi.fn(),
  verifyAppCheckToken: vi.fn(),
  runTransaction: vi.fn(),
  doc: vi.fn(),
  collection: vi.fn(),
  tokenGet: vi.fn(),
  tokenUpdate: vi.fn(),
  tokenSet: vi.fn(),
  tokenDelete: vi.fn(),
  countGet: vi.fn(),
  collectionGet: vi.fn(),
  sendEachForMulticast: vi.fn(),
  transactionGet: vi.fn(),
  transactionSet: vi.fn(),
  serverTimestamp: vi.fn(),
  loggerInfo: vi.fn(),
  loggerWarn: vi.fn(),
  loggerError: vi.fn(),
}));

vi.mock("firebase-admin/app", () => ({ initializeApp: vi.fn() }));
vi.mock("firebase-admin/auth", () => ({
  getAuth: () => ({ verifyIdToken: mocks.verifyIdToken }),
}));
vi.mock("firebase-admin/app-check", () => ({
  getAppCheck: () => ({ verifyToken: mocks.verifyAppCheckToken }),
}));
vi.mock("firebase-admin/firestore", () => ({
  FieldValue: { serverTimestamp: mocks.serverTimestamp },
  getFirestore: () => ({
    runTransaction: mocks.runTransaction,
    doc: mocks.doc,
    collection: mocks.collection,
  }),
}));
vi.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({ sendEachForMulticast: mocks.sendEachForMulticast }),
}));
vi.mock("firebase-functions/logger", () => ({
  info: mocks.loggerInfo,
  warn: mocks.loggerWarn,
  error: mocks.loggerError,
}));
vi.mock("firebase-functions/v2/https", () => ({
  onRequest: (_options: unknown, handler: unknown) => handler,
}));

import { relay } from "../src/index.js";

type RelayRequest = {
  method: string;
  body: unknown;
  header: (name: string) => string | undefined;
};

type RelayResponse = {
  status: ReturnType<typeof vi.fn>;
  json: ReturnType<typeof vi.fn>;
};

type RelayHandler = (req: RelayRequest, res: RelayResponse) => Promise<void>;

const relayHandler = relay as unknown as RelayHandler;
const VALID_TOKEN = "a".repeat(32);
const INVALID_FCM_VALUE = ["invalid", "value"].join(" ");

function request(body: unknown, method = "POST"): RelayRequest {
  return {
    method,
    body,
    header: (name) => {
      if (name === "authorization") return "Bearer valid-id-token";
      if (name === "x-firebase-appcheck") return "valid-app-check-token";
      return undefined;
    },
  };
}

function response(): RelayResponse {
  const res = {
    status: vi.fn(),
    json: vi.fn(),
  } as RelayResponse;
  res.status.mockReturnValue(res);
  res.json.mockReturnValue(res);
  return res;
}

async function invoke(body: unknown, method = "POST"): Promise<RelayResponse> {
  const res = response();
  await relayHandler(request(body, method), res);
  return res;
}

beforeEach(() => {
  for (const mock of Object.values(mocks)) mock.mockReset();

  mocks.verifyIdToken.mockResolvedValue({ uid: "bridge-uid" });
  mocks.verifyAppCheckToken.mockResolvedValue({});
  mocks.serverTimestamp.mockReturnValue("server-timestamp");
  mocks.transactionGet.mockResolvedValue({ data: () => ({ timestamps: [] }) });
  mocks.runTransaction.mockImplementation(async (callback) => callback({
    get: mocks.transactionGet,
    set: mocks.transactionSet,
  }));
  mocks.tokenGet.mockResolvedValue({ exists: false });
  mocks.tokenUpdate.mockResolvedValue(undefined);
  mocks.tokenSet.mockResolvedValue(undefined);
  mocks.tokenDelete.mockResolvedValue(undefined);
  mocks.countGet.mockResolvedValue({ data: () => ({ count: 0 }) });
  mocks.collectionGet.mockResolvedValue({ docs: [] });
  mocks.doc.mockImplementation((path: string) => {
    if (path.startsWith("rate_limits/")) return { path };
    return {
      get: mocks.tokenGet,
      update: mocks.tokenUpdate,
      set: mocks.tokenSet,
      delete: mocks.tokenDelete,
    };
  });
  mocks.collection.mockReturnValue({
    count: () => ({ get: mocks.countGet }),
    get: mocks.collectionGet,
  });
  mocks.sendEachForMulticast.mockResolvedValue({
    successCount: 1,
    failureCount: 0,
    responses: [{ success: true }],
  });
});

describe("relay", () => {
  it("returns 405 for non-POST requests", async () => {
    const res = await invoke(undefined, "GET");

    expect(res.status).toHaveBeenCalledWith(405);
    expect(res.json).toHaveBeenCalledWith({ error: "Method Not Allowed" });
  });

  it("returns 401 when the Firebase ID token is invalid", async () => {
    mocks.verifyIdToken.mockRejectedValue(new Error("expired token"));

    const res = await invoke({ op: "unregister", token: VALID_TOKEN });

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ error: "Unauthorized" });
  });

  it("returns 400 for a malformed request body", async () => {
    const res = await invoke({ op: "register", token: VALID_TOKEN, platform: "desktop" });

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: "Invalid request body" });
  });

  it("returns 429 when the token operation rate limit is exceeded", async () => {
    mocks.transactionGet.mockResolvedValue({
      data: () => ({ timestamps: Array.from({ length: 20 }, () => Date.now()) }),
    });

    const res = await invoke({ op: "unregister", token: VALID_TOKEN });

    expect(res.status).toHaveBeenCalledWith(429);
    expect(res.json).toHaveBeenCalledWith({ error: "Rate limit exceeded. Try again later." });
  });

  it("returns a stable 400 error for an invalid FCM token", async () => {
    const res = await invoke({ op: "register", token: INVALID_FCM_VALUE, platform: "ios" });

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: "invalid_fcm_token" });
    expect(mocks.loggerWarn).toHaveBeenCalledWith("Relay operation rejected", {
      op: "register",
      status: 400,
      code: "invalid_fcm_token",
    });
  });

  it("returns a stable 409 error for a new token above the bridge limit", async () => {
    mocks.countGet.mockResolvedValue({ data: () => ({ count: 20 }) });

    const res = await invoke({ op: "register", token: VALID_TOKEN, platform: "ios" });

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({ error: "token_limit_exceeded" });
    expect(mocks.tokenSet).not.toHaveBeenCalled();
  });

  it("updates an existing token even when the bridge has reached the token limit", async () => {
    mocks.tokenGet.mockResolvedValue({ exists: true });
    mocks.countGet.mockResolvedValue({ data: () => ({ count: 20 }) });

    const res = await invoke({
      op: "register",
      token: VALID_TOKEN,
      platform: "android",
      locale: "ja",
    });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ ok: true, op: "register" });
    expect(mocks.tokenUpdate).toHaveBeenCalledWith({
      token: VALID_TOKEN,
      platform: "android",
      locale: "ja",
      updatedAt: "server-timestamp",
    });
    expect(mocks.countGet).not.toHaveBeenCalled();
  });

  it("registers a new valid token", async () => {
    const res = await invoke({ op: "register", token: VALID_TOKEN, platform: "web" });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mocks.tokenSet).toHaveBeenCalledWith(expect.objectContaining({
      token: VALID_TOKEN,
      platform: "web",
    }));
  });

  it("unregisters a token", async () => {
    const res = await invoke({ op: "unregister", token: VALID_TOKEN });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mocks.tokenDelete).toHaveBeenCalledOnce();
  });

  it("returns notify success counts when no tokens are registered", async () => {
    const res = await invoke({
      op: "notify",
      eventType: "session_completed",
      title: "Done",
      body: "Finished",
    });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      ok: true,
      op: "notify",
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      deletedInvalidTokens: 0,
    });
  });

  it("sanitizes unexpected Firestore errors and logs their details", async () => {
    const firestoreError = new Error("sensitive Firestore details");
    mocks.tokenGet.mockRejectedValue(firestoreError);

    const res = await invoke({ op: "register", token: VALID_TOKEN, platform: "ios" });

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: "internal_error" });
    expect(res.json).not.toHaveBeenCalledWith(expect.objectContaining({
      error: expect.stringContaining("Firestore"),
    }));
    expect(mocks.loggerError).toHaveBeenCalledWith("Relay operation failed", {
      op: "register",
      message: firestoreError.message,
      stack: firestoreError.stack,
    });
  });

  it("sanitizes unexpected FCM errors", async () => {
    mocks.collectionGet.mockResolvedValue({
      docs: [{ get: () => VALID_TOKEN }],
    });
    mocks.sendEachForMulticast.mockRejectedValue(new Error("sensitive FCM details"));

    const res = await invoke({
      op: "notify",
      eventType: "session_completed",
      title: "Done",
      body: "Finished",
    });

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: "internal_error" });
  });

  it("sanitizes non-Error exceptions", async () => {
    mocks.runTransaction.mockRejectedValue("opaque failure");

    const res = await invoke({ op: "unregister", token: VALID_TOKEN });

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: "internal_error" });
    expect(mocks.loggerError).toHaveBeenCalledWith("Relay operation failed", {
      op: "unregister",
      message: "opaque failure",
      stack: undefined,
    });
  });
});
