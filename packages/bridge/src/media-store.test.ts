import type { IncomingMessage, ServerResponse } from "node:http";
import {
  mkdtemp,
  open,
  realpath,
  rm,
  symlink,
  unlink,
  writeFile,
} from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { PassThrough } from "node:stream";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  contentDispositionAttachment,
  MediaStore,
  parseByteRange,
} from "./media-store.js";

interface CapturedResponse {
  statusCode: number;
  headers: Record<string, string | number>;
  body: Buffer;
}

function requestMedia(
  store: MediaStore,
  url: string,
  options: { method?: string; range?: string } = {},
): Promise<CapturedResponse> {
  return new Promise((resolve, reject) => {
    let statusCode = 0;
    let headers: Record<string, string | number> = {};
    const chunks: Buffer[] = [];
    const response = new PassThrough();
    response.on("data", (chunk: Buffer) => chunks.push(chunk));
    response.on("error", reject);
    response.on("finish", () => {
      resolve({ statusCode, headers, body: Buffer.concat(chunks) });
    });
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
    const handled = store.handleRequest(
      {
        url,
        method: options.method ?? "GET",
        headers: options.range ? { range: options.range } : {},
      } as IncomingMessage,
      response as unknown as ServerResponse,
    );
    expect(handled).toBe(true);
  });
}

describe("parseByteRange", () => {
  it("returns undefined when no range is requested", () => {
    expect(parseByteRange(undefined, 10)).toBeUndefined();
  });

  it("parses bounded, open-ended, and suffix ranges", () => {
    expect(parseByteRange("bytes=2-5", 10)).toEqual({ start: 2, end: 5 });
    expect(parseByteRange("bytes=7-", 10)).toEqual({ start: 7, end: 9 });
    expect(parseByteRange("bytes=-3", 10)).toEqual({ start: 7, end: 9 });
  });

  it("clamps the end and rejects invalid ranges", () => {
    expect(parseByteRange("bytes=8-99", 10)).toEqual({ start: 8, end: 9 });
    expect(parseByteRange("bytes=10-", 10)).toBeNull();
    expect(parseByteRange("bytes=6-3", 10)).toBeNull();
    expect(parseByteRange("bytes=0-1,4-5", 10)).toBeNull();
  });
});

describe("contentDispositionAttachment", () => {
  it("provides safe ASCII and UTF-8 download names", () => {
    expect(contentDispositionAttachment('report "final".pdf')).toBe(
      "attachment; filename=\"report _final_.pdf\"; filename*=UTF-8''report%20%22final%22.pdf",
    );
    expect(contentDispositionAttachment("成果物.pdf")).toContain(
      "filename*=UTF-8''%E6%88%90%E6%9E%9C%E7%89%A9.pdf",
    );
  });
});

describe("MediaStore", () => {
  const tempDirs: string[] = [];

  afterEach(async () => {
    await Promise.all(
      tempDirs.splice(0).map((dir) => rm(dir, { recursive: true, force: true })),
    );
  });

  async function fixture(): Promise<{
    store: MediaStore;
    url: string;
    bytes: Buffer;
    filePath: string;
  }> {
    const dir = await mkdtemp(join(tmpdir(), "ccpocket-media-store-"));
    tempDirs.push(dir);
    const filePath = join(dir, "sample.mp4");
    const bytes = Buffer.from("0123456789");
    await writeFile(filePath, bytes);
    const store = new MediaStore();
    const ref = await store.register(
      await realpath(filePath),
      "video/mp4",
      bytes.length,
    );
    return {
      store,
      url: ref.url,
      bytes,
      filePath,
    };
  }

  it("streams the complete file without embedding it in the capability URL", async () => {
    const { store, url, bytes } = await fixture();
    const response = await requestMedia(store, url);

    expect(response.statusCode).toBe(200);
    expect(response.headers["Content-Type"]).toBe("video/mp4");
    expect(response.headers["Accept-Ranges"]).toBe("bytes");
    expect(response.body).toEqual(bytes);
    expect(url).not.toContain("sample.mp4");
  });

  it("serves byte ranges and rejects unsatisfiable ranges", async () => {
    const { store, url } = await fixture();
    const partial = await requestMedia(store, url, { range: "bytes=2-5" });
    const invalid = await requestMedia(store, url, { range: "bytes=99-" });

    expect(partial.statusCode).toBe(206);
    expect(partial.headers["Content-Range"]).toBe("bytes 2-5/10");
    expect(partial.body.toString()).toBe("2345");
    expect(invalid.statusCode).toBe(416);
    expect(invalid.headers["Content-Range"]).toBe("bytes */10");
  });

  it("supports HEAD without returning a body", async () => {
    const { store, url } = await fixture();
    const response = await requestMedia(store, url, { method: "HEAD" });

    expect(response.statusCode).toBe(200);
    expect(response.headers["Content-Length"]).toBe(10);
    expect(response.body).toHaveLength(0);
  });

  it("adds a download filename when one is registered", async () => {
    const dir = await mkdtemp(join(tmpdir(), "ccpocket-media-download-"));
    tempDirs.push(dir);
    const filePath = join(dir, "report.pdf");
    await writeFile(filePath, "pdf");
    const store = new MediaStore();
    const ref = await store.register(
      await realpath(filePath),
      "application/pdf",
      3,
      "report.pdf",
    );

    const response = await requestMedia(store, ref.url, { method: "HEAD" });

    expect(response.headers["Content-Disposition"]).toBe(
      "attachment; filename=\"report.pdf\"; filename*=UTF-8''report.pdf",
    );
  });

  it("destroys the file stream when the client closes the response", async () => {
    const { store, url, filePath } = await fixture();
    const probeHandle = await open(filePath, "r");
    const fileHandlePrototype = Object.getPrototypeOf(probeHandle);
    await probeHandle.close();
    const streamSpy = vi.spyOn(fileHandlePrototype, "createReadStream");
    const response = new PassThrough();
    let statusCode = 0;
    Object.assign(response, {
      writeHead(nextStatusCode: number) {
        statusCode = nextStatusCode;
        return response;
      },
    });
    const nativeOnce = response.once.bind(response);
    response.once = ((event: string, listener: (...args: unknown[]) => void) => {
      if (event === "close") {
        listener();
        return response;
      }
      return nativeOnce(event, listener);
    }) as typeof response.once;

    try {
      expect(
        store.handleRequest(
          { url, method: "GET", headers: {} } as IncomingMessage,
          response as unknown as ServerResponse,
        ),
      ).toBe(true);
      await vi.waitFor(() => expect(streamSpy).toHaveBeenCalledOnce());
      const stream = streamSpy.mock.results[0]?.value;
      expect(statusCode).toBe(200);
      expect(stream?.destroyed).toBe(true);
    } finally {
      streamSpy.mockRestore();
      response.destroy();
    }
  });

  it("rejects a validated path after a symlink swap", async () => {
    const allowedDir = await mkdtemp(join(tmpdir(), "ccpocket-media-allowed-"));
    const outsideDir = await mkdtemp(join(tmpdir(), "ccpocket-media-outside-"));
    tempDirs.push(allowedDir, outsideDir);
    const allowedPath = join(allowedDir, "sample.mp4");
    const outsidePath = join(outsideDir, "private.mp4");
    await writeFile(allowedPath, "allowed");
    await writeFile(outsidePath, "private");
    const validatedPath = await realpath(allowedPath);
    await unlink(allowedPath);
    await symlink(outsidePath, allowedPath);
    const store = new MediaStore();
    await expect(
      store.register(validatedPath, "video/mp4", 7),
    ).rejects.toThrow();
  });

  it("rejects a file whose size changes after registration", async () => {
    const { store, url, filePath } = await fixture();
    await writeFile(filePath, "0123456789-expanded");

    const response = await requestMedia(store, url);

    expect(response.statusCode).toBe(404);
    expect(response.body.toString()).toBe("Not Found");
  });

  it("expires capability URLs", async () => {
    let now = 1000;
    const dir = await mkdtemp(join(tmpdir(), "ccpocket-media-expiry-"));
    tempDirs.push(dir);
    const filePath = join(dir, "sample.wav");
    await writeFile(filePath, "wav");
    const store = new MediaStore({ ttlMs: 100, now: () => now });
    const ref = await store.register(await realpath(filePath), "audio/wav", 3);
    now = 1100;

    const response = await new Promise<{ statusCode: number }>((resolve) => {
      const res = {
        writeHead(statusCode: number) {
          resolve({ statusCode });
          return this;
        },
        end() {},
      };
      expect(
        store.handleRequest(
          { url: ref.url, method: "GET", headers: {} } as IncomingMessage,
          res as unknown as ServerResponse,
        ),
      ).toBe(true);
    });
    expect(response.statusCode).toBe(404);
  });
});
