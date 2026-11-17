import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { describe, it, expect, vi } from "vitest";
import sharp from "sharp";
import { ImageStore } from "./image-store.js";

interface ImageResponse {
  statusCode: number;
  headers: Record<string, string | number>;
  body: Buffer;
}

function requestImage(store: ImageStore, url: string): Promise<ImageResponse> {
  return new Promise((resolve) => {
    let statusCode = 0;
    let headers: Record<string, string | number> = {};
    const response = {
      writeHead(
        nextStatusCode: number,
        nextHeaders: Record<string, string | number>,
      ) {
        statusCode = nextStatusCode;
        headers = nextHeaders;
      },
      end(body: Buffer | string = "") {
        resolve({
          statusCode,
          headers,
          body: Buffer.isBuffer(body) ? body : Buffer.from(body),
        });
      },
    };
    const handled = store.handleRequest(
      { url } as any,
      response as any,
    );
    expect(handled).toBe(true);
  });
}

describe("ImageStore.extractImagePaths", () => {
  let store: ImageStore;

  // Create fresh instance per test
  function extract(input: unknown): string[] {
    store = new ImageStore();
    return store.extractImagePaths(input);
  }

  // ---- Absolute path extraction ----

  it("extracts single absolute path", () => {
    expect(extract("File at /tmp/screenshot.png")).toEqual(["/tmp/screenshot.png"]);
  });

  it("extracts multiple absolute paths", () => {
    const text = "See /home/user/a.jpg and /tmp/b.png for details";
    expect(extract(text)).toEqual(["/home/user/a.jpg", "/tmp/b.png"]);
  });

  it("handles paths with underscores, dots, and hyphens", () => {
    expect(extract("Image: /path/to/my_file-2.test.jpeg")).toEqual([
      "/path/to/my_file-2.test.jpeg",
    ]);
  });

  it("handles deeply nested paths", () => {
    expect(extract("Result: /a/b/c/d/e/f.gif")).toEqual(["/a/b/c/d/e/f.gif"]);
  });

  it("does not report the tail of a relative path", () => {
    expect(extract("The icon lives at src/assets/logo.png")).toEqual([]);
  });

  it("does not treat punctuation inside relative paths as a token boundary", () => {
    expect(extract("The icon lives at src/c++/logo.png")).toEqual([]);
  });

  it("keeps the Windows drive prefix with the path", () => {
    expect(extract("Saved to C:/Users/alice/shot.png")).toEqual([
      "C:/Users/alice/shot.png",
    ]);
  });

  it("keeps non-ASCII directory names inside the path", () => {
    expect(extract("Saved to /Users/alice/写真/cat.png")).toEqual([
      "/Users/alice/写真/cat.png",
    ]);
  });

  it("finds a path glued to punctuation or non-ASCII prose", () => {
    expect(extract("<path>/tmp/a.png</path>")).toEqual(["/tmp/a.png"]);
    expect(extract("保存先：/tmp/b.png")).toEqual(["/tmp/b.png"]);
    expect(extract("画像は/tmp/c.png に保存しました")).toEqual(["/tmp/c.png"]);
    expect(extract("files: [/tmp/d.png]|/tmp/e.png;/tmp/f.png")).toEqual([
      "/tmp/d.png",
      "/tmp/e.png",
      "/tmp/f.png",
    ]);
  });

  it("finds a path that follows a newline inside structured content", () => {
    expect(
      extract([{ type: "text", text: "Saved:\n/tmp/shot.png\t/tmp/other.png" }]),
    ).toEqual(["/tmp/shot.png", "/tmp/other.png"]);
  });

  it("does not report the path part of a URL", () => {
    expect(extract("See https://example.com/img/remote.jpg")).toEqual([]);
  });

  // ---- Extension filtering ----

  it("extracts png files", () => {
    expect(extract("/tmp/test.png")).toEqual(["/tmp/test.png"]);
  });

  it("extracts jpg files", () => {
    expect(extract("/tmp/test.jpg")).toEqual(["/tmp/test.jpg"]);
  });

  it("extracts jpeg files", () => {
    expect(extract("/tmp/test.jpeg")).toEqual(["/tmp/test.jpeg"]);
  });

  it("extracts gif files", () => {
    expect(extract("/tmp/test.gif")).toEqual(["/tmp/test.gif"]);
  });

  it("extracts webp files", () => {
    expect(extract("/tmp/test.webp")).toEqual(["/tmp/test.webp"]);
  });

  it("does not extract non-image extensions", () => {
    expect(extract("/tmp/test.txt /tmp/data.json /tmp/app.ts")).toEqual([]);
  });

  // ---- URL exclusion ----

  it("excludes URL-like paths starting with //", () => {
    // The regex matches absolute paths; paths starting with // are filtered out
    expect(extract("//cdn.example.com/img/photo.png")).toEqual([]);
  });

  it("extracts local path but not URL from mixed content", () => {
    const text = "Local: /tmp/local.png, Remote: https://example.com/remote.jpg";
    const result = extract(text);
    expect(result).toContain("/tmp/local.png");
    // URL paths that look like absolute paths (e.g., /remote.jpg from URL) may be extracted
    // but //example.com paths would be filtered
  });

  // ---- Deduplication ----

  it("deduplicates identical paths", () => {
    const text = "/tmp/same.png appears at /tmp/same.png again";
    expect(extract(text)).toEqual(["/tmp/same.png"]);
  });

  it("keeps different paths even with same filename", () => {
    const text = "/a/photo.png and /b/photo.png";
    expect(extract(text)).toEqual(["/a/photo.png", "/b/photo.png"]);
  });

  // ---- Null / empty / edge cases ----

  it("returns empty array for empty string", () => {
    expect(extract("")).toEqual([]);
  });

  it("returns empty array for string with no paths", () => {
    expect(extract("No images here")).toEqual([]);
  });

  it("handles null input via JSON.stringify fallback", () => {
    expect(extract(null)).toEqual([]);
  });

  it("handles undefined input via JSON.stringify fallback", () => {
    expect(extract(undefined)).toEqual([]);
  });

  it("handles numeric input via JSON.stringify fallback", () => {
    expect(extract(42)).toEqual([]);
  });

  it("handles object input by JSON.stringifying it", () => {
    const obj = { file: "/tmp/photo.png" };
    expect(extract(obj)).toEqual(["/tmp/photo.png"]);
  });

  it("handles array input by JSON.stringifying it", () => {
    const arr = ["/tmp/a.jpg", "/tmp/b.png"];
    expect(extract(arr)).toEqual(["/tmp/a.jpg", "/tmp/b.png"]);
  });
});

describe("ImageStore.registerImages", () => {
  it("resolves leading-slash project-relative paths with projectPath", async () => {
    const root = await mkdtemp(join(tmpdir(), "ccpocket-image-store-"));
    try {
      const imageDir = join(root, "images");
      const imagePath = join(imageDir, "screenshots.png");
      await mkdir(imageDir, { recursive: true });
      await writeFile(imagePath, Buffer.from("89504e470d0a1a0a", "hex"));

      const store = new ImageStore();
      const refs = await store.registerImages(["/images/screenshots.png"], root);

      expect(refs).toHaveLength(1);
      expect(refs[0]).toMatchObject({ mimeType: "image/png" });
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });

  it("reuses the same content-addressed ref for identical files", async () => {
    const root = await mkdtemp(join(tmpdir(), "ccpocket-image-store-"));
    try {
      const firstPath = join(root, "first.png");
      const secondPath = join(root, "second.png");
      const contents = Buffer.from("89504e470d0a1a0a", "hex");
      await writeFile(firstPath, contents);
      await writeFile(secondPath, contents);

      const store = new ImageStore();
      const refs = await store.registerImages([firstPath, secondPath]);

      expect(refs).toHaveLength(2);
      expect(refs[0]).toEqual(refs[1]);
      expect(refs[0].id).toMatch(/^[a-f0-9]{64}$/);
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
});

describe("ImageStore.registerFromBase64", () => {
  it("reuses the same ref for repeated base64 history images", () => {
    const store = new ImageStore();
    const data = Buffer.from("same generated image").toString("base64");

    const first = store.registerFromBase64(data, "image/png");
    const second = store.registerFromBase64(data, "image/png");

    expect(first).not.toBeNull();
    expect(second).toEqual(first);
    expect(first?.id).toMatch(/^[a-f0-9]{64}$/);
  });

  it("keeps mime types distinct for identical bytes", () => {
    const store = new ImageStore();
    const data = Buffer.from("same bytes").toString("base64");

    const png = store.registerFromBase64(data, "image/png");
    const webp = store.registerFromBase64(data, "image/webp");

    expect(png?.id).not.toBe(webp?.id);
  });

  it("bounds the base64 dedupe index to the image store capacity", () => {
    const store = new ImageStore();

    for (let index = 0; index < 125; index++) {
      store.registerFromBase64(
        Buffer.from(`generated image ${index}`).toString("base64"),
        "image/png",
      );
    }

    expect((store as any).base64Ids.size).toBe(100);
  });
});

describe("ImageStore.handleRequest", () => {
  it("serves a cached WebP thumbnail without changing the original URL", async () => {
    const source = await sharp({
      create: {
        width: 1600,
        height: 900,
        channels: 4,
        background: { r: 30, g: 120, b: 220, alpha: 1 },
      },
    })
      .png()
      .toBuffer();
    const store = new ImageStore();
    const ref = store.registerFromBase64(
      source.toString("base64"),
      "image/png",
    );
    expect(ref).not.toBeNull();

    const original = await requestImage(store, ref!.url);
    expect(ref!.thumbnailUrl).toBe(`${ref!.url}?variant=thumbnail`);
    const [thumbnail, concurrentThumbnail] = await Promise.all([
      requestImage(store, ref!.thumbnailUrl!),
      requestImage(store, ref!.thumbnailUrl!),
    ]);
    const cachedThumbnail = await requestImage(store, ref!.thumbnailUrl!);
    const metadata = await sharp(thumbnail.body).metadata();

    expect(original.statusCode).toBe(200);
    expect(original.headers["Content-Type"]).toBe("image/png");
    expect(original.body).toEqual(source);
    expect(thumbnail.statusCode).toBe(200);
    expect(thumbnail.headers["Content-Type"]).toBe("image/webp");
    expect(thumbnail.body.length).toBeLessThan(original.body.length);
    expect(metadata.width).toBe(768);
    expect(metadata.height).toBe(432);
    expect(concurrentThumbnail.body).toBe(thumbnail.body);
    expect(cachedThumbnail.body).toEqual(thumbnail.body);
  });

  it("falls back to the original when thumbnail conversion fails", async () => {
    const source = Buffer.from("not actually a png");
    const store = new ImageStore();
    const ref = store.registerFromBase64(
      source.toString("base64"),
      "image/png",
    );
    const warning = vi.spyOn(console, "warn").mockImplementation(() => {});

    try {
      const response = await requestImage(store, ref!.thumbnailUrl!);

      expect(response.statusCode).toBe(200);
      expect(response.headers["Content-Type"]).toBe("image/png");
      expect(response.body).toEqual(source);
      expect(warning).toHaveBeenCalledOnce();
    } finally {
      warning.mockRestore();
    }
  });
});
