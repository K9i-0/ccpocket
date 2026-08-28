import { createHash, randomBytes } from "node:crypto";
import { constants } from "node:fs";
import {
  link,
  lstat,
  open,
  readdir,
  realpath,
  rename,
  stat,
  unlink,
  type FileHandle,
} from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";
import { basename, extname, join } from "node:path";

export type UploadConflictPolicy = "rename" | "overwrite" | "skip";

export interface UploadRef {
  token: string;
  url: string;
}

export interface UploadResult {
  fileName: string;
  filePath: string;
  sizeBytes: number;
  sha256: string;
  skipped: boolean;
}

interface UploadEntry {
  directoryPath: string;
  relativeDirectoryPath: string;
  directoryDevice: number;
  directoryInode: number;
  fileName: string;
  sizeBytes: number;
  conflictPolicy: UploadConflictPolicy;
  stagingPath: string;
  stagingDevice: number;
  stagingInode: number;
  fileHandle: FileHandle | null;
  incomingSha256?: string;
  receivedBytes?: number;
  receiving: boolean;
  request?: IncomingMessage;
  expiresAt: number;
}

interface CompletedUpload {
  sha256: string;
  result: UploadResult;
  expiresAt: number;
}

interface UploadStoreOptions {
  ttlMs?: number;
  maxEntries?: number;
  maxReservedBytes?: number;
  maxConcurrentReceives?: number;
  maxCompletedEntries?: number;
  receiveTimeoutMs?: number;
  idleTimeoutMs?: number;
  cleanupIntervalMs?: number;
  now?: () => number;
}

const DEFAULT_TTL_MS = 60 * 60 * 1000;
const DEFAULT_MAX_ENTRIES = 100;
const DEFAULT_MAX_RESERVED_BYTES = 2 * 1024 * 1024 * 1024;
const DEFAULT_MAX_CONCURRENT_RECEIVES = 4;
const DEFAULT_RECEIVE_TIMEOUT_MS = 60 * 60 * 1000;
const DEFAULT_IDLE_TIMEOUT_MS = 60 * 1000;
const UPLOAD_PATH_PATTERN = /^\/api\/uploads\/([a-f0-9]{48})$/;
const INTERNAL_PREFIX = ".ccpocket-upload-";

export class UploadStoreError extends Error {
  constructor(
    readonly code:
      | "file_upload_not_found"
      | "file_upload_incomplete"
      | "file_upload_integrity_failed"
      | "file_upload_directory_changed"
      | "file_upload_conflict"
      | "file_upload_capacity_exceeded"
      | "file_upload_failed",
    message: string,
  ) {
    super(message);
  }
}

/** Stores short-lived upload capabilities and publishes verified files. */
export class UploadStore {
  private readonly entries = new Map<string, UploadEntry>();
  private readonly completed = new Map<string, CompletedUpload>();
  private readonly finalizations = new Map<
    string,
    { sha256: string; promise: Promise<UploadResult> }
  >();
  private readonly registrations = new Set<Promise<UploadRef>>();
  private readonly removals = new Map<string, Promise<void>>();
  private readonly ttlMs: number;
  private readonly maxEntries: number;
  private readonly maxReservedBytes: number;
  private readonly maxConcurrentReceives: number;
  private readonly maxCompletedEntries: number;
  private readonly receiveTimeoutMs: number;
  private readonly idleTimeoutMs: number;
  private readonly now: () => number;
  private readonly cleanupTimer: NodeJS.Timeout;
  private reservedBytes = 0;
  private pendingRegistrations = 0;
  private activeReceives = 0;
  private disposed = false;
  private disposePromise: Promise<void> | null = null;

  constructor(options: UploadStoreOptions = {}) {
    this.ttlMs = options.ttlMs ?? DEFAULT_TTL_MS;
    this.maxEntries = options.maxEntries ?? DEFAULT_MAX_ENTRIES;
    this.maxReservedBytes =
      options.maxReservedBytes ?? DEFAULT_MAX_RESERVED_BYTES;
    this.maxConcurrentReceives =
      options.maxConcurrentReceives ?? DEFAULT_MAX_CONCURRENT_RECEIVES;
    this.maxCompletedEntries = options.maxCompletedEntries ?? this.maxEntries;
    this.receiveTimeoutMs =
      options.receiveTimeoutMs ?? DEFAULT_RECEIVE_TIMEOUT_MS;
    this.idleTimeoutMs = options.idleTimeoutMs ?? DEFAULT_IDLE_TIMEOUT_MS;
    this.now = options.now ?? Date.now;
    this.cleanupTimer = setInterval(
      () => void this.removeExpired(),
      options.cleanupIntervalMs ?? Math.min(this.ttlMs, 60_000),
    );
    this.cleanupTimer.unref();
  }

  register(options: {
    directoryPath: string;
    relativeDirectoryPath: string;
    fileName: string;
    sizeBytes: number;
    conflictPolicy: UploadConflictPolicy;
  }): Promise<UploadRef> {
    if (this.disposed) {
      return Promise.reject(
        new UploadStoreError(
          "file_upload_failed",
          "The Bridge is shutting down and cannot accept uploads.",
        ),
      );
    }
    const promise = this.registerActive(options);
    this.registrations.add(promise);
    void promise.then(
      () => this.registrations.delete(promise),
      () => this.registrations.delete(promise),
    );
    return promise;
  }

  private async registerActive(options: {
    directoryPath: string;
    relativeDirectoryPath: string;
    fileName: string;
    sizeBytes: number;
    conflictPolicy: UploadConflictPolicy;
  }): Promise<UploadRef> {
    await this.removeExpired();
    if (
      this.entries.size + this.pendingRegistrations >= this.maxEntries ||
      options.sizeBytes > this.maxReservedBytes - this.reservedBytes
    ) {
      throw new UploadStoreError(
        "file_upload_capacity_exceeded",
        "Bridge upload capacity is currently full. Try again after active uploads finish.",
      );
    }
    this.pendingRegistrations += 1;
    this.reservedBytes += options.sizeBytes;
    let committed = false;
    let fileHandle: FileHandle | null = null;
    let stagingPath: string | null = null;
    try {
      const directoryPath = await realpath(options.directoryPath);
      const directoryStat = await stat(directoryPath);
      if (!directoryStat.isDirectory()) {
        throw new Error("Upload destination is not a directory");
      }
      await this.scavengeDirectory(directoryPath);

      const token = randomBytes(24).toString("hex");
      stagingPath = join(
        directoryPath,
        `${INTERNAL_PREFIX}${randomBytes(24).toString("hex")}.part`,
      );
      const noFollow = process.platform === "win32" ? 0 : constants.O_NOFOLLOW;
      fileHandle = await open(
        stagingPath,
        constants.O_CREAT |
          constants.O_EXCL |
          constants.O_RDWR |
          noFollow,
        0o600,
      );
      const stagingStat = await fileHandle.stat();
      const now = this.now();
      this.entries.set(token, {
        directoryPath,
        relativeDirectoryPath: options.relativeDirectoryPath,
        directoryDevice: directoryStat.dev,
        directoryInode: directoryStat.ino,
        fileName: options.fileName,
        sizeBytes: options.sizeBytes,
        conflictPolicy: options.conflictPolicy,
        stagingPath,
        stagingDevice: stagingStat.dev,
        stagingInode: stagingStat.ino,
        fileHandle,
        receiving: false,
        expiresAt: now + this.ttlMs,
      });
      committed = true;
      return { token, url: `/api/uploads/${token}` };
    } catch (error) {
      await fileHandle?.close().catch(() => undefined);
      if (stagingPath) await unlink(stagingPath).catch(() => undefined);
      throw error;
    } finally {
      this.pendingRegistrations = Math.max(0, this.pendingRegistrations - 1);
      if (!committed) {
        this.reservedBytes = Math.max(
          0,
          this.reservedBytes - options.sizeBytes,
        );
      }
    }
  }

  handleRequest(
    req: IncomingMessage,
    res: ServerResponse,
    onReceiveStarted?: () => void,
  ): boolean {
    const url = new URL(req.url ?? "", "http://localhost");
    const match = UPLOAD_PATH_PATTERN.exec(url.pathname);
    if (!match) return false;
    if (this.disposed) {
      this.sendText(res, 503, "Bridge is shutting down.");
      return true;
    }
    if (req.method !== "PUT") {
      res.writeHead(405, { Allow: "PUT", "Content-Type": "text/plain" });
      res.end("Method Not Allowed");
      return true;
    }
    const token = match[1];
    const entry = this.getActiveEntry(token);
    if (!entry || entry.receiving || entry.incomingSha256 !== undefined) {
      this.sendText(res, 404, "Not Found");
      return true;
    }
    if (this.activeReceives >= this.maxConcurrentReceives) {
      this.sendText(res, 429, "Too many uploads are currently in progress.", {
        "Retry-After": "5",
      });
      return true;
    }
    void this.receive(req, res, token, entry, onReceiveStarted);
    return true;
  }

  async finalize(token: string, expectedSha256: string): Promise<UploadResult> {
    if (this.disposed) {
      throw new UploadStoreError(
        "file_upload_failed",
        "The Bridge is shutting down and cannot finish uploads.",
      );
    }
    const normalizedSha256 = expectedSha256.toLowerCase();
    const previous = this.completed.get(token);
    if (previous && previous.expiresAt > this.now()) {
      if (previous.sha256 !== normalizedSha256) {
        throw new UploadStoreError(
          "file_upload_integrity_failed",
          "The uploaded file failed integrity verification.",
        );
      }
      return previous.result;
    }

    const ongoing = this.finalizations.get(token);
    if (ongoing) {
      if (ongoing.sha256 !== normalizedSha256) {
        throw new UploadStoreError(
          "file_upload_integrity_failed",
          "The uploaded file failed integrity verification.",
        );
      }
      return ongoing.promise;
    }

    const promise = this.finalizeActive(token, normalizedSha256);
    this.finalizations.set(token, { sha256: normalizedSha256, promise });
    try {
      return await promise;
    } finally {
      if (this.finalizations.get(token)?.promise === promise) {
        this.finalizations.delete(token);
      }
    }
  }

  private async finalizeActive(
    token: string,
    normalizedSha256: string,
  ): Promise<UploadResult> {
    const entry = this.getActiveEntry(token);
    if (!entry) {
      throw new UploadStoreError(
        "file_upload_not_found",
        "Upload expired or was not found.",
      );
    }
    if (
      entry.receiving ||
      !entry.incomingSha256 ||
      entry.receivedBytes !== entry.sizeBytes
    ) {
      throw new UploadStoreError(
        "file_upload_incomplete",
        "The upload has not completed.",
      );
    }

    try {
      await this.verifyDirectory(entry);
      const pinnedSha256 = await this.hashPinnedFile(entry);
      if (
        entry.incomingSha256 !== normalizedSha256 ||
        pinnedSha256 !== normalizedSha256
      ) {
        throw new UploadStoreError(
          "file_upload_integrity_failed",
          "The uploaded file failed integrity verification.",
        );
      }
      await this.verifyStagingPath(entry);
      await this.closeEntryHandle(entry);
      await this.verifyDirectory(entry);
      await this.verifyStagingPath(entry);
      const published = await this.publish(entry);
      const result: UploadResult = {
        fileName: published.fileName,
        filePath: entry.relativeDirectoryPath
          ? `${entry.relativeDirectoryPath}/${published.fileName}`
          : published.fileName,
        sizeBytes: entry.sizeBytes,
        sha256: pinnedSha256,
        skipped: published.skipped,
      };
      this.releaseEntry(token, entry);
      this.completed.set(token, {
        sha256: normalizedSha256,
        result,
        expiresAt: this.now() + this.ttlMs,
      });
      this.trimCompleted();
      return result;
    } catch (error) {
      await this.removeEntry(token);
      if (error instanceof UploadStoreError) throw error;
      throw new UploadStoreError(
        "file_upload_failed",
        "Unable to publish the uploaded file.",
      );
    }
  }

  async cancel(token: string): Promise<void> {
    this.completed.delete(token);
    await this.removeEntry(token);
  }

  dispose(): Promise<void> {
    this.disposed = true;
    this.disposePromise ??= this.disposeActive();
    return this.disposePromise;
  }

  private async disposeActive(): Promise<void> {
    clearInterval(this.cleanupTimer);
    await Promise.allSettled([...this.registrations]);
    await Promise.all(
      [...this.entries.keys()].map((token) => this.removeEntry(token)),
    );
    await Promise.allSettled(
      [...this.finalizations.values()].map((value) => value.promise),
    );
    this.completed.clear();
  }

  private trimCompleted(): void {
    while (this.completed.size > this.maxCompletedEntries) {
      const oldestToken = this.completed.keys().next().value as
        | string
        | undefined;
      if (!oldestToken) return;
      this.completed.delete(oldestToken);
    }
  }

  private async receive(
    req: IncomingMessage,
    res: ServerResponse,
    token: string,
    entry: UploadEntry,
    onReceiveStarted?: () => void,
  ): Promise<void> {
    const contentLength = Number(req.headers["content-length"]);
    if (
      !Number.isSafeInteger(contentLength) ||
      contentLength !== entry.sizeBytes
    ) {
      await this.removeEntry(token);
      this.sendText(
        res,
        contentLength > entry.sizeBytes ? 413 : 400,
        "Content-Length does not match the prepared upload.",
      );
      return;
    }
    const fileHandle = entry.fileHandle;
    if (!fileHandle) {
      await this.removeEntry(token);
      this.sendText(res, 404, "Not Found");
      return;
    }

    entry.receiving = true;
    entry.request = req;
    this.activeReceives += 1;
    const hash = createHash("sha256");
    let receivedBytes = 0;
    let timedOut = false;

    let idleTimer: NodeJS.Timeout;
    const abortForTimeout = () => {
      timedOut = true;
      req.destroy(new Error("Upload timed out"));
    };
    const totalTimer = setTimeout(abortForTimeout, this.receiveTimeoutMs);
    const resetIdleTimer = () => {
      clearTimeout(idleTimer);
      idleTimer = setTimeout(abortForTimeout, this.idleTimeoutMs);
    };
    idleTimer = setTimeout(abortForTimeout, this.idleTimeoutMs);
    onReceiveStarted?.();

    const finishReceive = () => {
      clearTimeout(totalTimer);
      clearTimeout(idleTimer);
      entry.receiving = false;
      entry.request = undefined;
      this.activeReceives = Math.max(0, this.activeReceives - 1);
    };

    try {
      await fileHandle.truncate(0);
      for await (const value of req) {
        resetIdleTimer();
        const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value);
        if (receivedBytes + chunk.length > entry.sizeBytes) {
          throw new Error("Upload exceeds the prepared size");
        }
        let written = 0;
        while (written < chunk.length) {
          const result = await fileHandle.write(
            chunk,
            written,
            chunk.length - written,
            receivedBytes + written,
          );
          if (result.bytesWritten <= 0) {
            throw new Error("Upload write did not make progress");
          }
          written += result.bytesWritten;
        }
        receivedBytes += chunk.length;
        hash.update(chunk);
      }
      if (receivedBytes !== entry.sizeBytes) {
        throw new Error("Upload did not match the prepared size");
      }
      finishReceive();
      entry.receivedBytes = receivedBytes;
      entry.incomingSha256 = hash.digest("hex");
      res.writeHead(201, {
        "Content-Type": "application/json",
        "Cache-Control": "private, no-store",
        "X-File-SHA256": entry.incomingSha256,
        "X-Received-Bytes": String(receivedBytes),
      });
      res.end(
        JSON.stringify({
          sha256: entry.incomingSha256,
          receivedBytes,
        }),
      );
    } catch {
      finishReceive();
      await this.removeEntry(token);
      if (!res.headersSent) {
        this.sendText(
          res,
          timedOut ? 408 : 400,
          timedOut ? "Upload timed out." : "Upload did not complete.",
        );
      } else {
        res.destroy();
      }
    }
  }

  private async hashPinnedFile(entry: UploadEntry): Promise<string> {
    const fileHandle = entry.fileHandle;
    if (!fileHandle) {
      throw new UploadStoreError(
        "file_upload_integrity_failed",
        "The staged upload is unavailable.",
      );
    }
    const fileStat = await fileHandle.stat();
    if (
      !fileStat.isFile() ||
      fileStat.size !== entry.sizeBytes ||
      fileStat.dev !== entry.stagingDevice ||
      fileStat.ino !== entry.stagingInode
    ) {
      throw new UploadStoreError(
        "file_upload_integrity_failed",
        "The staged upload changed before it could be published.",
      );
    }
    const hash = createHash("sha256");
    if (fileStat.size === 0) return hash.digest("hex");
    const stream = fileHandle.createReadStream({
      autoClose: false,
      start: 0,
      end: fileStat.size - 1,
    });
    for await (const chunk of stream) hash.update(chunk as Buffer);
    return hash.digest("hex");
  }

  private async publish(
    entry: UploadEntry,
  ): Promise<{ fileName: string; skipped: boolean }> {
    const destination = join(entry.directoryPath, entry.fileName);
    if (entry.conflictPolicy === "overwrite") {
      try {
        const existing = await lstat(destination);
        if (!existing.isFile() || existing.isSymbolicLink()) {
          throw new UploadStoreError(
            "file_upload_conflict",
            "The destination is not a regular file.",
          );
        }
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      }
      await this.replaceFile(entry, destination);
      return { fileName: entry.fileName, skipped: false };
    }

    const candidates =
      entry.conflictPolicy === "skip"
        ? [entry.fileName]
        : this.renameCandidates(entry.fileName);
    for (const candidate of candidates) {
      const candidatePath = join(entry.directoryPath, candidate);
      try {
        await link(entry.stagingPath, candidatePath);
        await unlink(entry.stagingPath);
        return { fileName: candidate, skipped: false };
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        if (entry.conflictPolicy === "skip") {
          await unlink(entry.stagingPath).catch(() => undefined);
          return { fileName: entry.fileName, skipped: true };
        }
      }
    }
    throw new UploadStoreError(
      "file_upload_conflict",
      "Unable to find an available file name.",
    );
  }

  private async replaceFile(
    entry: UploadEntry,
    destination: string,
  ): Promise<void> {
    // Node's rename uses the platform's replace-existing primitive. If the OS
    // cannot perform that atomic operation (for example because an antivirus
    // holds the destination on Windows), fail without moving the original to a
    // hidden backup or attempting a non-atomic fallback.
    await rename(entry.stagingPath, destination);
  }

  private *renameCandidates(fileName: string): Generator<string> {
    yield fileName;
    const extension = extname(fileName);
    const stem = extension ? fileName.slice(0, -extension.length) : fileName;
    for (let index = 1; index <= 10_000; index += 1) {
      const suffix = ` (${index})`;
      const fixed = `${suffix}${extension}`;
      const availableStemBytes = 255 - Buffer.byteLength(fixed, "utf8");
      if (availableStemBytes > 0) {
        yield `${truncateUtf8(stem, availableStemBytes)}${fixed}`;
      } else {
        yield `${truncateUtf8(stem || "file", 255 - Buffer.byteLength(suffix, "utf8"))}${suffix}`;
      }
    }
  }

  private async verifyDirectory(entry: UploadEntry): Promise<void> {
    const currentRealPath = await realpath(entry.directoryPath).catch(() => "");
    const currentStat = currentRealPath
      ? await stat(currentRealPath).catch(() => null)
      : null;
    if (
      currentRealPath !== entry.directoryPath ||
      !currentStat?.isDirectory() ||
      currentStat.dev !== entry.directoryDevice ||
      currentStat.ino !== entry.directoryInode
    ) {
      throw new UploadStoreError(
        "file_upload_directory_changed",
        "The upload destination changed during transfer.",
      );
    }
  }

  private async verifyStagingPath(entry: UploadEntry): Promise<void> {
    const stagingStat = await lstat(entry.stagingPath).catch(() => null);
    if (
      !stagingStat?.isFile() ||
      stagingStat.isSymbolicLink() ||
      stagingStat.dev !== entry.stagingDevice ||
      stagingStat.ino !== entry.stagingInode
    ) {
      throw new UploadStoreError(
        "file_upload_integrity_failed",
        "The staged upload changed before it could be published.",
      );
    }
  }

  private getActiveEntry(token: string): UploadEntry | null {
    const entry = this.entries.get(token);
    if (!entry) return null;
    if (entry.expiresAt <= this.now()) {
      void this.removeEntry(token);
      return null;
    }
    return entry;
  }

  private async removeExpired(): Promise<void> {
    const now = this.now();
    await Promise.all(
      [...this.entries.entries()]
        .filter(([, entry]) => entry.expiresAt <= now)
        .map(([token]) => this.removeEntry(token)),
    );
    for (const [token, value] of this.completed) {
      if (value.expiresAt <= now) this.completed.delete(token);
    }
  }

  private async removeEntry(token: string): Promise<void> {
    const ongoing = this.removals.get(token);
    if (ongoing) return ongoing;
    const entry = this.entries.get(token);
    if (!entry) return;
    const promise = this.removeEntryActive(token, entry);
    this.removals.set(token, promise);
    try {
      await promise;
    } finally {
      if (this.removals.get(token) === promise) this.removals.delete(token);
    }
  }

  private async removeEntryActive(
    token: string,
    entry: UploadEntry,
  ): Promise<void> {
    this.releaseEntry(token, entry);
    entry.request?.destroy();
    await this.closeEntryHandle(entry);
    if (await this.stagingPathMatches(entry)) {
      await unlink(entry.stagingPath).catch(() => undefined);
    }
  }

  private releaseEntry(token: string, entry: UploadEntry): void {
    if (!this.entries.delete(token)) return;
    this.reservedBytes = Math.max(0, this.reservedBytes - entry.sizeBytes);
  }

  private async closeEntryHandle(entry: UploadEntry): Promise<void> {
    const fileHandle = entry.fileHandle;
    entry.fileHandle = null;
    if (fileHandle) await fileHandle.close().catch(() => undefined);
  }

  private async stagingPathMatches(entry: UploadEntry): Promise<boolean> {
    const fileStat = await lstat(entry.stagingPath).catch(() => null);
    return (
      fileStat?.isFile() === true &&
      !fileStat.isSymbolicLink() &&
      fileStat.dev === entry.stagingDevice &&
      fileStat.ino === entry.stagingInode
    );
  }

  private async scavengeDirectory(directoryPath: string): Promise<void> {
    const cutoff = this.now() - this.ttlMs;
    const names = await readdir(directoryPath).catch(() => [] as string[]);
    await Promise.all(
      names
        .filter(
          (name) =>
            name.startsWith(INTERNAL_PREFIX) &&
            name.endsWith(".part"),
        )
        .map(async (name) => {
          const path = join(directoryPath, name);
          const fileStat = await lstat(path).catch(() => null);
          if (
            fileStat?.isFile() &&
            !fileStat.isSymbolicLink() &&
            fileStat.mtimeMs <= cutoff
          ) {
            await unlink(path).catch(() => undefined);
          }
        }),
    );
  }

  private sendText(
    res: ServerResponse,
    statusCode: number,
    body: string,
    extraHeaders: Record<string, string> = {},
  ): void {
    res.writeHead(statusCode, {
      "Content-Type": "text/plain",
      "Cache-Control": "private, no-store",
      ...extraHeaders,
    });
    res.end(body);
  }
}

export function isSafeUploadFileName(fileName: string): boolean {
  if (
    !fileName ||
    fileName === "." ||
    fileName === ".." ||
    basename(fileName) !== fileName ||
    Buffer.byteLength(fileName, "utf8") > 255 ||
    fileName.toLowerCase().startsWith(INTERNAL_PREFIX)
  ) {
    return false;
  }
  if (/[\\/\0\x00-\x1f<>:"|?*]/.test(fileName) || /[. ]$/.test(fileName)) {
    return false;
  }
  const stem = fileName.split(".")[0].toUpperCase();
  return !/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/.test(stem);
}

function truncateUtf8(value: string, maxBytes: number): string {
  let result = "";
  let usedBytes = 0;
  for (const character of value) {
    const characterBytes = Buffer.byteLength(character, "utf8");
    if (usedBytes + characterBytes > maxBytes) break;
    result += character;
    usedBytes += characterBytes;
  }
  return result;
}
