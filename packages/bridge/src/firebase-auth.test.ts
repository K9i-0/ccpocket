import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { FirebaseAuthClient } from "./firebase-auth.js";

const tempDirs: string[] = [];

function tempCredentialsFile(): string {
  const dir = mkdtempSync(join(tmpdir(), "ccpocket-firebase-auth-"));
  tempDirs.push(dir);
  return join(dir, "firebase-credentials.json");
}

function signUpResponse(uid: string, idToken: string, refreshToken: string): Response {
  return new Response(JSON.stringify({
    localId: uid,
    idToken,
    refreshToken,
    expiresIn: "3600",
  }), { status: 200 });
}

function userNotFoundResponse(): Response {
  return new Response(JSON.stringify({
    error: {
      code: 400,
      message: "USER_NOT_FOUND",
      status: "INVALID_ARGUMENT",
    },
  }), { status: 400 });
}

afterEach(() => {
  vi.restoreAllMocks();
  for (const dir of tempDirs.splice(0)) {
    rmSync(dir, { recursive: true, force: true });
  }
});

describe("FirebaseAuthClient", () => {
  it("creates a new anonymous account when saved credentials no longer exist", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const credentialsFile = tempCredentialsFile();
    writeFileSync(credentialsFile, JSON.stringify({
      uid: "old-uid",
      refreshToken: "dummy-old-refresh",
    }), "utf-8");
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(userNotFoundResponse())
      .mockResolvedValueOnce(signUpResponse("new-uid", "new-id-token", "dummy-new-refresh"));
    const client = new FirebaseAuthClient({
      credentialsFile,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });

    await client.initialize();

    expect(client.uid).toBe("new-uid");
    await expect(client.getIdToken()).resolves.toBe("new-id-token");
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const saved = JSON.parse(readFileSync(credentialsFile, "utf-8")) as Record<string, string>;
    expect(saved).toEqual({
      uid: "new-uid",
      refreshToken: "dummy-new-refresh",
    });
  });

  it("recovers with a new anonymous account when refresh fails during runtime", async () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const credentialsFile = tempCredentialsFile();
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(signUpResponse("initial-uid", "initial-id-token", "dummy-initial-refresh"))
      .mockResolvedValueOnce(userNotFoundResponse())
      .mockResolvedValueOnce(signUpResponse("new-uid", "new-id-token", "dummy-new-refresh"));
    const client = new FirebaseAuthClient({
      credentialsFile,
      fetchImpl: fetchMock as unknown as typeof fetch,
    });
    await client.initialize();
    (client as unknown as { _expiresAt: number })._expiresAt = 0;

    await expect(client.getIdToken()).resolves.toBe("new-id-token");

    expect(client.uid).toBe("new-uid");
    expect(fetchMock).toHaveBeenCalledTimes(3);
    const saved = JSON.parse(readFileSync(credentialsFile, "utf-8")) as Record<string, string>;
    expect(saved).toEqual({
      uid: "new-uid",
      refreshToken: "dummy-new-refresh",
    });
  });
});
