import type { IncomingMessage, ServerResponse } from "node:http";
import { createHash } from "node:crypto";
import {
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  rename,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { PassThrough } from "node:stream";
import { afterEach, describe, expect, it } from "vitest";
import { isSafeUploadFileName, UploadStore } from "./upload-store.js";

interface CapturedResponse {
  statusCode: number;
  headers: Record<string, string | number>;
  body: Buffer;
}

function put(
  store: UploadStore,
  url: string,
  bytes: Buffer,
  contentLength = bytes.length,
): Promise<CapturedResponse> {
  const pending = beginPut(store, url, contentLength);
  pending.request.end(bytes);
  return pending.response;
}

function beginPut(
  store: UploadStore,
  url: string,
  contentLength: number,
  onReceiveStarted?: () => void,
): { request: PassThrough; response: Promise<CapturedResponse> } {
  const request = new PassThrough();
  const response = new Promise<CapturedResponse>((resolve, reject) => {
    let statusCode = 0;
    let headers: Record<string, string | number> = {};
    const chunks: Buffer[] = [];
    Object.assign(request, {
      url,
      method: "PUT",
      headers: { "content-length": String(contentLength) },
    });
    const response = new PassThrough();
    response.on("data", (chunk: Buffer) => chunks.push(chunk));
    response.on("error", reject);
    response.on("finish", () =>
      resolve({ statusCode, headers, body: Buffer.concat(chunks) }),
    );
    Object.assign(response, {
      writeHead(
        nextStatusCode: number,
        nextHeaders: Record<string, string | number>,
      ) {
        statusCode = nextStatusCode;
        headers = nextHeaders;
        return response;
      },
    });
    expect(
      store.handleRequest(
        request as unknown as IncomingMessage,
        response as unknown as ServerResponse,
        onReceiveStarted,
      ),
    ).toBe(true);
  });
  return { request, response };
}

describe("isSafeUploadFileName", () => {
  it("accepts normal names and rejects traversal and cross-platform reserved names", () => {
    expect(isSafeUploadFileName("report final.pdf")).toBe(true);
    expect(isSafeUploadFileName("../private.txt")).toBe(false);
    expect(isSafeUploadFileName("nested/file.txt")).toBe(false);
    expect(isSafeUploadFileName("CON.txt")).toBe(false);
    expect(isSafeUploadFileName("trailing. ")).toBe(false);
    expect(isSafeUploadFileName(".ccpocket-upload-forged.part")).toBe(false);
    expect(isSafeUploadFileName("界".repeat(86))).toBe(false);
  });
});

describe("UploadStore", () => {
  const tempDirs: string[] = [];
  const stores: UploadStore[] = [];

  afterEach(async () => {
    await Promise.all(stores.splice(0).map((store) => store.dispose()));
    await Promise.all(
      tempDirs.splice(0).map((dir) => rm(dir, { recursive: true, force: true })),
    );
  });

  async function fixture(
    fileName = "report.pdf",
    conflictPolicy: "rename" | "overwrite" | "skip" = "rename",
  ) {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-"));
    tempDirs.push(project);
    const destination = join(project, "docs");
    await mkdir(destination);
    const bytes = Buffer.from("verified upload");
    const store = new UploadStore();
    stores.push(store);
    const ref = await store.register({
      directoryPath: destination,
      relativeDirectoryPath: "docs",
      fileName,
      sizeBytes: bytes.length,
      conflictPolicy,
    });
    return { project, destination, bytes, store, ref };
  }

  it("receives, hashes, and publishes a verified upload", async () => {
    const { destination, bytes, store, ref } = await fixture();
    const response = await put(store, ref.url, bytes);
    const sha256 = createHash("sha256").update(bytes).digest("hex");

    expect(response.statusCode).toBe(201);
    expect(response.headers["X-File-SHA256"]).toBe(sha256);
    const result = await store.finalize(ref.token, sha256);

    expect(result).toMatchObject({
      fileName: "report.pdf",
      filePath: "docs/report.pdf",
      skipped: false,
    });
    expect(await readFile(join(destination, "report.pdf"))).toEqual(bytes);
  });

  it("keeps both files by adding a numeric suffix", async () => {
    const { destination, bytes, store, ref } = await fixture();
    await writeFile(join(destination, "report.pdf"), "existing");
    await put(store, ref.url, bytes);
    const result = await store.finalize(
      ref.token,
      createHash("sha256").update(bytes).digest("hex"),
    );

    expect(result.fileName).toBe("report (1).pdf");
    expect(await readFile(join(destination, "report.pdf"), "utf8")).toBe("existing");
    expect(await readFile(join(destination, "report (1).pdf"))).toEqual(bytes);
  });

  it("supports skip and overwrite conflict policies", async () => {
    const skipped = await fixture("same.txt", "skip");
    await writeFile(join(skipped.destination, "same.txt"), "old");
    await put(skipped.store, skipped.ref.url, skipped.bytes);
    const skippedResult = await skipped.store.finalize(
      skipped.ref.token,
      createHash("sha256").update(skipped.bytes).digest("hex"),
    );
    expect(skippedResult.skipped).toBe(true);
    expect(await readFile(join(skipped.destination, "same.txt"), "utf8")).toBe("old");

    const overwritten = await fixture("same.txt", "overwrite");
    await writeFile(join(overwritten.destination, "same.txt"), "old");
    await put(overwritten.store, overwritten.ref.url, overwritten.bytes);
    const result = await overwritten.store.finalize(
      overwritten.ref.token,
      createHash("sha256").update(overwritten.bytes).digest("hex"),
    );
    expect(result.skipped).toBe(false);
    expect(await readFile(join(overwritten.destination, "same.txt"))).toEqual(
      overwritten.bytes,
    );
  });

  it("rejects mismatched lengths before writing and mismatched hashes before publishing", async () => {
    const lengthMismatch = await fixture();
    const response = await put(
      lengthMismatch.store,
      lengthMismatch.ref.url,
      lengthMismatch.bytes,
      lengthMismatch.bytes.length + 1,
    );
    expect(response.statusCode).toBe(413);

    const hashMismatch = await fixture();
    await put(hashMismatch.store, hashMismatch.ref.url, hashMismatch.bytes);
    await expect(
      hashMismatch.store.finalize(hashMismatch.ref.token, "0".repeat(64)),
    ).rejects.toMatchObject({ code: "file_upload_integrity_failed" });
  });

  it("expires capabilities and removes their partial files", async () => {
    let now = 1000;
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-expiry-"));
    tempDirs.push(project);
    const store = new UploadStore({ ttlMs: 100, now: () => now });
    stores.push(store);
    const ref = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "expired.txt",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });
    now = 1100;
    const response = await put(store, ref.url, Buffer.from("x"));
    expect(response.statusCode).toBe(404);
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(await readdir(project)).toEqual([]);
  });

  it("cancels a received upload and removes its staged file", async () => {
    const { destination, bytes, store, ref } = await fixture();
    await put(store, ref.url, bytes);

    await store.cancel(ref.token);

    await expect(
      store.finalize(
        ref.token,
        createHash("sha256").update(bytes).digest("hex"),
      ),
    ).rejects.toMatchObject({ code: "file_upload_not_found" });
    expect(await readdir(destination)).toEqual([]);
  });

  it("shares in-flight finalization and returns the cached result on retry", async () => {
    const { destination, bytes, store, ref } = await fixture();
    await put(store, ref.url, bytes);
    const sha256 = createHash("sha256").update(bytes).digest("hex");

    const [first, concurrent] = await Promise.all([
      store.finalize(ref.token, sha256),
      store.finalize(ref.token, sha256),
    ]);
    const cached = await store.finalize(ref.token, sha256);

    expect(concurrent).toEqual(first);
    expect(cached).toEqual(first);
    expect(await readdir(destination)).toEqual(["report.pdf"]);
  });

  it("detects staged file tampering before publish", async () => {
    const { destination, bytes, store, ref } = await fixture();
    await put(store, ref.url, bytes);
    const stagingName = (await readdir(destination)).find((name) =>
      name.endsWith(".part"),
    );
    expect(stagingName).toBeDefined();
    await writeFile(join(destination, stagingName!), "tampered upload");

    await expect(
      store.finalize(
        ref.token,
        createHash("sha256").update(bytes).digest("hex"),
      ),
    ).rejects.toMatchObject({ code: "file_upload_integrity_failed" });
    expect(await readdir(destination)).toEqual([]);
  });

  it("does not write through a destination symlink swapped after prepare", async () => {
    const { project, destination, bytes, store, ref } = await fixture();
    const movedDestination = join(project, "docs-moved");
    const outside = await mkdtemp(join(tmpdir(), "ccpocket-upload-outside-"));
    tempDirs.push(outside);
    await rename(destination, movedDestination);
    await symlink(outside, destination, "dir");

    const response = await put(store, ref.url, bytes);

    expect(response.statusCode).toBe(201);
    expect(await readdir(outside)).toEqual([]);
    await expect(
      store.finalize(
        ref.token,
        createHash("sha256").update(bytes).digest("hex"),
      ),
    ).rejects.toMatchObject({ code: "file_upload_directory_changed" });
  });

  it("rejects reservations beyond the aggregate capacity", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-capacity-"));
    tempDirs.push(project);
    const store = new UploadStore({ maxReservedBytes: 3 });
    stores.push(store);
    await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "one.bin",
      sizeBytes: 2,
      conflictPolicy: "rename",
    });

    await expect(
      store.register({
        directoryPath: project,
        relativeDirectoryPath: "",
        fileName: "two.bin",
        sizeBytes: 2,
        conflictPolicy: "rename",
      }),
    ).rejects.toMatchObject({ code: "file_upload_capacity_exceeded" });
  });

  it("reserves capacity before concurrent registration work begins", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-register-race-"));
    tempDirs.push(project);
    const store = new UploadStore({ maxEntries: 1, maxReservedBytes: 2 });
    stores.push(store);
    const options = (fileName: string) => ({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName,
      sizeBytes: 2,
      conflictPolicy: "rename" as const,
    });

    const results = await Promise.allSettled([
      store.register(options("one.bin")),
      store.register(options("two.bin")),
    ]);

    expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
    const rejected = results.find((result) => result.status === "rejected");
    expect(rejected).toMatchObject({
      status: "rejected",
      reason: { code: "file_upload_capacity_exceeded" },
    });
  });

  it("limits concurrent HTTP upload bodies without evicting active uploads", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-concurrency-"));
    tempDirs.push(project);
    const store = new UploadStore({ maxConcurrentReceives: 1 });
    stores.push(store);
    const first = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "one.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });
    const second = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "two.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });

    const active = beginPut(store, first.url, 1);
    await new Promise((resolve) => setTimeout(resolve, 0));
    const rejected = await put(store, second.url, Buffer.from("b"));
    expect(rejected.statusCode).toBe(429);

    active.request.end(Buffer.from("a"));
    expect((await active.response).statusCode).toBe(201);
  });

  it("extends the body deadline only for an active issued capability", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-deadline-"));
    tempDirs.push(project);
    const store = new UploadStore();
    stores.push(store);
    const mismatchedRef = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "mismatched.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });
    let started = 0;

    const invalid = beginPut(
      store,
      "/api/uploads/000000000000000000000000000000000000000000000000",
      1,
      () => {
        started += 1;
      },
    );
    invalid.request.end(Buffer.from("x"));
    expect((await invalid.response).statusCode).toBe(404);
    expect(started).toBe(0);

    const mismatched = beginPut(store, mismatchedRef.url, 2, () => {
      started += 1;
    });
    expect((await mismatched.response).statusCode).toBe(413);
    expect(started).toBe(0);
    mismatched.request.destroy();

    const validRef = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "valid.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });
    const valid = beginPut(store, validRef.url, 1, () => {
      started += 1;
    });
    valid.request.end(Buffer.from("x"));
    expect((await valid.response).statusCode).toBe(201);
    expect(started).toBe(1);
  });

  it("removes an upload that exceeds the idle receive deadline", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-idle-"));
    tempDirs.push(project);
    const store = new UploadStore({
      idleTimeoutMs: 10,
      receiveTimeoutMs: 1000,
      cleanupIntervalMs: 1000,
    });
    stores.push(store);
    const ref = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "idle.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });

    const pending = beginPut(store, ref.url, 1);

    expect((await pending.response).statusCode).toBe(408);
    expect(await readdir(project)).toEqual([]);
  });

  it("removes an upload that exceeds the total receive deadline", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-total-"));
    tempDirs.push(project);
    const store = new UploadStore({
      idleTimeoutMs: 1000,
      receiveTimeoutMs: 10,
      cleanupIntervalMs: 1000,
    });
    stores.push(store);
    const ref = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "total.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });

    const pending = beginPut(store, ref.url, 1);

    expect((await pending.response).statusCode).toBe(408);
    expect(await readdir(project)).toEqual([]);
  });

  it("expires an active body at the capability's absolute TTL", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-active-ttl-"));
    tempDirs.push(project);
    const store = new UploadStore({
      ttlMs: 10,
      idleTimeoutMs: 1000,
      receiveTimeoutMs: 1000,
      cleanupIntervalMs: 5,
    });
    stores.push(store);
    const ref = await store.register({
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "active.bin",
      sizeBytes: 1,
      conflictPolicy: "rename",
    });

    const pending = beginPut(store, ref.url, 1);

    expect((await pending.response).statusCode).toBe(400);
    expect(await readdir(project)).toEqual([]);
  });

  it("waits for pending registration and rejects new work during dispose", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-dispose-"));
    tempDirs.push(project);
    const store = new UploadStore();
    stores.push(store);
    const options = {
      directoryPath: project,
      relativeDirectoryPath: "",
      fileName: "pending.bin",
      sizeBytes: 1,
      conflictPolicy: "rename" as const,
    };

    const registration = store.register(options);
    const disposing = store.dispose();
    await registration;
    await disposing;

    expect(await readdir(project)).toEqual([]);
    await expect(store.register(options)).rejects.toMatchObject({
      code: "file_upload_failed",
    });
  });

  it("bounds completed result caching independently of active entries", async () => {
    const project = await mkdtemp(join(tmpdir(), "ccpocket-upload-completed-"));
    tempDirs.push(project);
    const store = new UploadStore({ maxCompletedEntries: 1 });
    stores.push(store);
    const finish = async (fileName: string) => {
      const ref = await store.register({
        directoryPath: project,
        relativeDirectoryPath: "",
        fileName,
        sizeBytes: 0,
        conflictPolicy: "rename",
      });
      await put(store, ref.url, Buffer.alloc(0));
      await store.finalize(
        ref.token,
        createHash("sha256").update(Buffer.alloc(0)).digest("hex"),
      );
      return ref;
    };

    const first = await finish("one.txt");
    await finish("two.txt");

    await expect(
      store.finalize(
        first.token,
        createHash("sha256").update(Buffer.alloc(0)).digest("hex"),
      ),
    ).rejects.toMatchObject({ code: "file_upload_not_found" });
  });

  it("keeps generated conflict names within 255 UTF-8 bytes", async () => {
    const longName = `${"界".repeat(83)}.txt`;
    const upload = await fixture(longName);
    await writeFile(join(upload.destination, longName), "existing");
    await put(upload.store, upload.ref.url, upload.bytes);

    const result = await upload.store.finalize(
      upload.ref.token,
      createHash("sha256").update(upload.bytes).digest("hex"),
    );

    expect(Buffer.byteLength(result.fileName, "utf8")).toBeLessThanOrEqual(255);
    expect(result.fileName).toMatch(/ \(1\)\.txt$/);
  });
});
