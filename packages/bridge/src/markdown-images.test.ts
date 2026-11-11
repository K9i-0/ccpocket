import { mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { ImageStore } from "./image-store.js";
import {
  MAX_ASSISTANT_IMAGES_PER_MESSAGE,
  assistantTextBlocks,
  createAssistantImageResolver,
  extractMarkdownImages,
} from "./markdown-images.js";
import { isPathWithinAllowedDirectory } from "./path-utils.js";

// 1x1 transparent PNG
const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  "base64",
);

describe("extractMarkdownImages", () => {
  it("extracts local image destinations with their alt text", () => {
    expect(
      extractMarkdownImages(
        "候補です。\n\n![案A](/work/a.png)\n![案 B](out/b%20v2.jpg \"title\")\n![](<C:/work/c d.webp>)",
      ),
    ).toEqual([
      { alt: "案A", path: "/work/a.png" },
      { alt: "案 B", path: "out/b v2.jpg" },
      { alt: "", path: "C:/work/c d.webp" },
    ]);
  });

  it("ignores plain links, remote images, non-images, code, and duplicates", () => {
    expect(
      extractMarkdownImages(
        [
          "[shot.png](/tmp/shot.png)",
          "![remote](https://example.com/a.png)",
          "![proto](//example.com/a.png)",
          "![data](data:image/png;base64,AAAA)",
          "![doc](/work/readme.md)",
          "`![inline](/work/inline.png)`",
          "```md\n![fenced](/work/fenced.png)\n```",
          "![one](/work/one.png) ![again](/work/one.png)",
        ].join("\n"),
      ),
    ).toEqual([{ alt: "one", path: "/work/one.png" }]);
  });

  it("accepts file URLs", () => {
    expect(extractMarkdownImages("![f](file:///work/f.png)")).toEqual([
      { alt: "f", path: "/work/f.png" },
    ]);
  });
});

describe("assistantTextBlocks", () => {
  it("returns only text blocks", () => {
    expect(
      assistantTextBlocks([
        { type: "thinking", thinking: "![x](/a.png)" },
        { type: "text", text: "hello" },
        { type: "tool_use", id: "1", name: "Bash", input: {} },
      ]),
    ).toEqual(["hello"]);
    expect(assistantTextBlocks("plain")).toEqual(["plain"]);
    expect(assistantTextBlocks(undefined)).toEqual([]);
  });
});

describe.skipIf(process.platform === "win32")("createAssistantImageResolver", () => {
  let root: string;
  let project: string;
  let readOnly: string;
  let outside: string;

  beforeEach(() => {
    root = realpathSync(mkdtempSync(resolve(tmpdir(), "ccpocket-md-images-")));
    project = resolve(root, "project");
    readOnly = resolve(root, "readonly");
    outside = resolve(root, "outside");
    for (const dir of [project, readOnly, outside]) mkdirSync(dir);
  });

  afterEach(() => {
    rmSync(root, { recursive: true, force: true });
  });

  function resolver() {
    const within = (path: string) =>
      [project, readOnly].some((dir) => isPathWithinAllowedDirectory(path, dir));
    return createAssistantImageResolver({
      imageStore: new ImageStore(),
      isPathReadable: within,
      isCanonicalPathReadable: async (path) => within(path),
    });
  }

  it("registers readable images and keeps their path and label", async () => {
    writeFileSync(resolve(project, "a.png"), PNG);
    writeFileSync(resolve(readOnly, "b.png"), PNG);
    const refs = await resolver()(
      [`![案A](a.png)\n![案B](${resolve(readOnly, "b.png")})`],
      project,
    );
    expect(refs).toHaveLength(2);
    expect(refs[0]).toMatchObject({
      path: resolve(project, "a.png"),
      alt: "案A",
      mimeType: "image/png",
    });
    expect(refs[0].url).toMatch(/^\/images\/[a-f0-9]{64}$/);
    expect(refs[0].thumbnailUrl).toBe(`${refs[0].url}?variant=thumbnail`);
    expect(refs[1]).toMatchObject({ path: resolve(readOnly, "b.png"), alt: "案B" });
  });

  it("skips missing files, directories outside the readable roots, and escaping symlinks", async () => {
    writeFileSync(resolve(outside, "secret.png"), PNG);
    symlinkSync(resolve(outside, "secret.png"), resolve(project, "link.png"));
    const refs = await resolver()(
      [
        `![missing](missing.png) ![outside](${resolve(outside, "secret.png")}) ![link](link.png) ![up](../outside/secret.png)`,
      ],
      project,
    );
    expect(refs).toEqual([]);
  });

  it("skips relative paths without a project and caps the image count", async () => {
    const names = Array.from(
      { length: MAX_ASSISTANT_IMAGES_PER_MESSAGE + 3 },
      (_, index) => `n${index}.png`,
    );
    // Distinct bytes so content-addressed ids differ.
    names.forEach((name, index) =>
      writeFileSync(resolve(project, name), Buffer.concat([PNG, Buffer.from([index])])),
    );
    const text = names.map((name) => `![${name}](${name})`).join("\n");
    expect(await resolver()([text], undefined)).toEqual([]);
    expect(await resolver()([text], project)).toHaveLength(
      MAX_ASSISTANT_IMAGES_PER_MESSAGE,
    );
  });
});
