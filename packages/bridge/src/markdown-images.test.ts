import { mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { ImageStore, type ImageRef } from "./image-store.js";
import {
  MAX_ASSISTANT_IMAGES_PER_MESSAGE,
  assistantTextBlocks,
  createAssistantImageResolver,
  extractMarkdownImages,
  hasMarkdownImages,
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

  it("keeps alt text that contains brackets", () => {
    expect(
      extractMarkdownImages(
        [
          "![前 [案A] 後](/work/a.png)",
          "![escaped \\] bracket](/work/b.png)",
          "![opening \\[ bracket](/work/c.png)",
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "前 [案A] 後", path: "/work/a.png" },
      { alt: "escaped ] bracket", path: "/work/b.png" },
      { alt: "opening [ bracket", path: "/work/c.png" },
    ]);
  });

  it("keeps destinations with balanced parentheses", () => {
    expect(
      extractMarkdownImages(
        [
          "![shot](/work/Screenshot(1).png)",
          "![escaped](/work/Escaped\\(1\\).png)",
          "![angled](</work/Angled (1).png>)",
          "![encoded](/work/Encoded%20(1).png)",
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "shot", path: "/work/Screenshot(1).png" },
      { alt: "escaped", path: "/work/Escaped(1).png" },
      { alt: "angled", path: "/work/Angled (1).png" },
      { alt: "encoded", path: "/work/Encoded (1).png" },
    ]);
  });

  it("keeps Windows backslashes and titles that contain parentheses", () => {
    expect(
      extractMarkdownImages(
        '![w](C:\\work\\shot.png)\n![t](/work/t.png "title (1)")',
      ),
    ).toEqual([
      { alt: "w", path: "C:\\work\\shot.png" },
      { alt: "t", path: "/work/t.png" },
    ]);
  });

  it("keeps Windows separators that precede punctuation", () => {
    expect(
      extractMarkdownImages(
        [
          "![dot](C:\\Users\\me\\.claude\\tmp\\a.png)",
          "![underscore](C:\\work\\_shots\\a-b\\b.png)",
          "![angled](<C:\\Users\\me\\.claude\\My Shots\\c.png>)",
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "dot", path: "C:\\Users\\me\\.claude\\tmp\\a.png" },
      { alt: "underscore", path: "C:\\work\\_shots\\a-b\\b.png" },
      { alt: "angled", path: "C:\\Users\\me\\.claude\\My Shots\\c.png" },
    ]);
  });

  it("ignores bare destinations with whitespace inside parentheses", () => {
    expect(
      extractMarkdownImages(
        "![s](/work/foo(bar baz).png)\n![a\\\nb](/work/x.png)",
      ),
    ).toEqual([]);
  });

  it("ignores images that are not closed correctly", () => {
    expect(
      extractMarkdownImages(
        [
          "![open](/work/a.png",
          "![space](/work/Screenshot (1).png)",
          "![empty]()",
          "![nested](/work/(a.png)",
        ].join("\n"),
      ),
    ).toEqual([]);
  });
  it("accepts every supported image extension regardless of case", () => {
    expect(
      extractMarkdownImages(
        [
          "![a](/work/a.png)",
          "![b](/work/b.jpg)",
          "![c](/work/c.jpeg)",
          "![d](/work/d.gif)",
          "![e](/work/e.webp)",
          "![f](/work/f.PNG)",
          "![g](/work/g.svg)",
          "![h](/work/h)",
        ].join("\n"),
      ).map((image) => image.path),
    ).toEqual([
      "/work/a.png",
      "/work/b.jpg",
      "/work/c.jpeg",
      "/work/d.gif",
      "/work/e.webp",
      "/work/f.PNG",
    ]);
  });

  it("does not join the text on either side of removed code into an image", () => {
    expect(extractMarkdownImages("![a]`code`(/work/x.png)")).toEqual([]);
    expect(
      extractMarkdownImages("![a]\n```\ncode\n```\n(/work/x.png)"),
    ).toEqual([]);
    // Code inside the alt text still leaves a usable image.
    expect(extractMarkdownImages("![the `main` view](/work/x.png)")).toEqual([
      expect.objectContaining({ path: "/work/x.png" }),
    ]);
  });

  it("only treats fence markers at the start of a line as code fences", () => {
    // A marker in the middle of a line does not open a fence.
    expect(
      extractMarkdownImages("use ~~~ for fences\n![a](/work/a.png)"),
    ).toEqual([{ alt: "a", path: "/work/a.png" }]);
    // A marker in the middle of a line does not close a fence.
    expect(
      extractMarkdownImages(
        "~~~\ncode ~~~ still code\n![in](/work/in.png)\n~~~\n![out](/work/out.png)",
      ),
    ).toEqual([{ alt: "out", path: "/work/out.png" }]);
    // A closing fence may be longer than the opening one.
    expect(
      extractMarkdownImages(
        "```\n![in](/work/in.png)\n````\n![out](/work/out.png)",
      ),
    ).toEqual([{ alt: "out", path: "/work/out.png" }]);
  });

  it("keeps local paths that merely contain a colon or a stray percent sign", () => {
    expect(
      extractMarkdownImages(
        [
          "![time](/work/shot-at-10:30.png)",
          "![profile](/work/profile:1.png)",
          "![percent](/work/100%.png)",
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "time", path: "/work/shot-at-10:30.png" },
      { alt: "profile", path: "/work/profile:1.png" },
      { alt: "percent", path: "/work/100%.png" },
    ]);
  });

  it("trims whitespace around the alt text and the destination", () => {
    expect(
      extractMarkdownImages(
        [
          "![  padded  ](/work/a.png)",
          "![space]( /work/b.png)",
          "![tab](\t/work/c.png)",
          "![angled](< /work/d.png >)",
          "![close](/work/e.png\t)",
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "padded", path: "/work/a.png" },
      { alt: "space", path: "/work/b.png" },
      { alt: "tab", path: "/work/c.png" },
      { alt: "angled", path: "/work/d.png" },
      { alt: "close", path: "/work/e.png" },
    ]);
  });

  it("resolves escaped delimiters in destinations", () => {
    expect(
      extractMarkdownImages(
        [
          String.raw`![paren](/work/a\).png)`,
          String.raw`![angle](</work/a\>b.png>)`,
        ].join("\n"),
      ),
    ).toEqual([
      { alt: "paren", path: "/work/a).png" },
      { alt: "angle", path: "/work/a>b.png" },
    ]);
  });

  it("accepts every title form and whitespace around the title", () => {
    expect(
      extractMarkdownImages(
        [
          `![single](/work/a.png 'title')`,
          `![paren](/work/b.png (title))`,
          String.raw`![escaped](/work/c.png "say \"hi\" (1)")`,
          `![tabbed](/work/d.png\t"title")`,
          `![trailing-space](/work/e.png "title" )`,
          `![trailing-tab](/work/f.png "title"\t)`,
        ].join("\n"),
      ).map((image) => image.path),
    ).toEqual([
      "/work/a.png",
      "/work/b.png",
      "/work/c.png",
      "/work/d.png",
      "/work/e.png",
      "/work/f.png",
    ]);
  });

  it.each([
    ["text between the alt and the destination", "![a]x/work/a.png)"],
    ["a nested angle bracket", "![a](</work/a<b.png>)"],
    ["a line break in an angled destination", "![a](</work/a\nb.png>)"],
    ["an escaped space in a bare destination", String.raw`![a](/work/a\ b.png)`],
    ["an escaped tab in a bare destination", "![a](/work/a\\\tb.png)"],
    ["an escaped line break in a bare destination", "![a](/work/a\\\nb.png)"],
    ["a line break in a bare destination", "![a](/work/a\nb.png)"],
    ["a tab in a bare destination", "![a](/work/a\tb.png)"],
    ["an unbalanced parenthesis before whitespace", "![a](/work/a(b.png )"],
    ["a line break in the title", '![a](/work/a.png "title\nmore")'],
    ["an unterminated title", '![a](/work/a.png "title'],
    ["text after the title", '![a](/work/a.png "title" extra)'],
  ])("ignores %s", (_label, markdown) => {
    expect(extractMarkdownImages(markdown)).toEqual([]);
  });

  it("keeps scanning after a malformed image", () => {
    expect(
      extractMarkdownImages("![unclosed alt\n![ok](/work/ok.png)"),
    ).toEqual([{ alt: "ok", path: "/work/ok.png" }]);
  });
});

describe("hasMarkdownImages", () => {
  it("is true when any text embeds a local image", () => {
    expect(hasMarkdownImages([])).toBe(false);
    expect(hasMarkdownImages(["plain", "[link](/work/a.png)"])).toBe(false);
    expect(hasMarkdownImages(["plain", "![a](/work/a.png)"])).toBe(true);
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

  it("ignores empty strings and malformed blocks", () => {
    expect(assistantTextBlocks("")).toEqual([]);
    expect(
      assistantTextBlocks([
        null,
        "bare string",
        { type: "text" },
        { type: "text", text: 1 },
        { type: "other", text: "not a text block" },
        { type: "text", text: "kept" },
      ]),
    ).toEqual(["kept"]);
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

  it("registers an image once even when it is referenced in several ways", async () => {
    writeFileSync(resolve(project, "a.png"), PNG);
    const refs = await resolver()(
      [
        "![first](a.png) ![dot](./a.png)",
        `![absolute](${resolve(project, "a.png")}) ![again](a.png)`,
      ],
      project,
    );
    expect(refs).toHaveLength(1);
    expect(refs[0]).toMatchObject({ path: resolve(project, "a.png"), alt: "first" });
  });

  it("omits the label when the alt text is empty", async () => {
    writeFileSync(resolve(project, "a.png"), PNG);
    const refs = await resolver()(["![](a.png)"], project);
    expect(refs).toHaveLength(1);
    expect(refs[0]).not.toHaveProperty("alt");
  });

  it("skips a symlink outside the readable roots even when it points inside them", async () => {
    writeFileSync(resolve(project, "a.png"), PNG);
    symlinkSync(resolve(project, "a.png"), resolve(outside, "link.png"));
    const refs = await resolver()(
      [`![link](${resolve(outside, "link.png")})`],
      project,
    );
    expect(refs).toEqual([]);
  });

  describe("with a stubbed image store", () => {
    function resolverWithStore(
      registerImages: (paths: string[]) => Promise<ImageRef[]>,
    ) {
      return createAssistantImageResolver({
        imageStore: { registerImages } as unknown as ImageStore,
        isPathReadable: () => true,
        isCanonicalPathReadable: async () => true,
      });
    }
    const ref: ImageRef = {
      id: "id",
      url: "/images/id",
      thumbnailUrl: "/images/id?variant=thumbnail",
      mimeType: "image/png",
    };

    it("registers the canonical path of a readable file", async () => {
      writeFileSync(resolve(project, "a.png"), PNG);
      symlinkSync(resolve(project, "a.png"), resolve(project, "link.png"));
      const registered: string[][] = [];
      const refs = await resolverWithStore(async (paths) => {
        registered.push(paths);
        return [ref];
      })(["![link](link.png)"], project);
      expect(registered).toEqual([[resolve(project, "a.png")]]);
      expect(refs).toEqual([
        { ...ref, path: resolve(project, "link.png"), alt: "link" },
      ]);
    });

    it("never hands a directory to the image store", async () => {
      mkdirSync(resolve(project, "dir.png"));
      const registered: string[][] = [];
      const refs = await resolverWithStore(async (paths) => {
        registered.push(paths);
        return [ref];
      })(["![dir](dir.png)"], project);
      expect(registered).toEqual([]);
      expect(refs).toEqual([]);
    });

    it("skips an image the store declines to register", async () => {
      writeFileSync(resolve(project, "a.png"), PNG);
      const refs = await resolverWithStore(async () => [])(
        ["![a](a.png)"],
        project,
      );
      expect(refs).toEqual([]);
    });
  });
});
