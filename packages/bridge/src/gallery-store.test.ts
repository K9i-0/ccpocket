import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { TEST_HOME, indexWrites } = vi.hoisted(() => ({
  TEST_HOME: `/tmp/ccpocket-gallery-test-home-${process.pid}`,
  indexWrites: { inFlight: 0, maxInFlight: 0, targets: [] as string[] },
}));

vi.mock("node:fs/promises", async (importOriginal) => {
  const mod = await importOriginal<typeof import("node:fs/promises")>();
  const writeFile = (async (...args: Parameters<typeof mod.writeFile>) => {
    const target = String(args[0]);
    if (!target.includes(`${TEST_HOME}/.ccpocket/gallery/index.json`)) {
      return mod.writeFile(...args);
    }
    indexWrites.targets.push(target);
    indexWrites.inFlight += 1;
    indexWrites.maxInFlight = Math.max(
      indexWrites.maxInFlight,
      indexWrites.inFlight,
    );
    try {
      // Widen the race window so overlapping writes are observable.
      await new Promise((r) => setTimeout(r, 5));
      return await mod.writeFile(...args);
    } finally {
      indexWrites.inFlight -= 1;
    }
  }) as typeof mod.writeFile;
  return { ...mod, writeFile };
});

vi.mock("node:os", async (importOriginal) => {
  const mod = await importOriginal<typeof import("node:os")>();
  return {
    ...mod,
    homedir: () => TEST_HOME,
  };
});

import { GalleryStore } from "./gallery-store.js";

describe("GalleryStore.addImage", () => {
  beforeEach(async () => {
    await rm(TEST_HOME, { recursive: true, force: true });
    await mkdir(TEST_HOME, { recursive: true });
  });

  afterEach(async () => {
    await rm(TEST_HOME, { recursive: true, force: true });
  });

  it("resolves leading-slash project-relative paths", async () => {
    const root = await mkdtemp(join(tmpdir(), "ccpocket-gallery-project-"));
    try {
      const imageDir = join(root, "images");
      const imagePath = join(imageDir, "screenshots.png");
      await mkdir(imageDir, { recursive: true });
      await writeFile(imagePath, Buffer.from("89504e470d0a1a0a", "hex"));

      const store = new GalleryStore();
      await store.init();

      const meta = await store.addImage("/images/screenshots.png", root, "session-1");
      expect(meta).not.toBeNull();
      expect(meta?.sourcePath).toBe(imagePath);
      expect(meta?.mimeType).toBe("image/png");
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
});

describe("GalleryStore index persistence", () => {
  beforeEach(async () => {
    await rm(TEST_HOME, { recursive: true, force: true });
    await mkdir(TEST_HOME, { recursive: true });
    indexWrites.inFlight = 0;
    indexWrites.maxInFlight = 0;
    indexWrites.targets = [];
  });

  afterEach(async () => {
    await rm(TEST_HOME, { recursive: true, force: true });
  });

  it("serializes concurrent index saves and writes atomically", async () => {
    const root = await mkdtemp(join(tmpdir(), "ccpocket-gallery-project-"));
    try {
      const count = 8;
      for (let i = 0; i < count; i++) {
        await writeFile(
          join(root, `shot-${i}.png`),
          Buffer.from("89504e470d0a1a0a", "hex"),
        );
      }

      const store = new GalleryStore();
      await store.init();
      const metas = await Promise.all(
        Array.from({ length: count }, (_, i) =>
          store.addImage(join(root, `shot-${i}.png`), root),
        ),
      );
      expect(metas.every((m) => m !== null)).toBe(true);

      expect(indexWrites.maxInFlight).toBe(1);
      const indexFile = join(TEST_HOME, ".ccpocket", "gallery", "index.json");
      // Never truncate the live index in place; write a temp file and rename.
      expect(indexWrites.targets).not.toContain(indexFile);

      const parsed = JSON.parse(await readFile(indexFile, "utf-8")) as unknown[];
      expect(parsed).toHaveLength(count);

      const reloaded = new GalleryStore();
      await reloaded.init();
      expect(reloaded.list()).toHaveLength(count);
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });
});
