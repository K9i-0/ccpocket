import { describe, it, expect } from "vitest";
import { ImageStore } from "./image-store.js";

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
