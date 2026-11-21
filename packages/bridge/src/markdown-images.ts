import { realpath, stat } from "node:fs/promises";
import { extname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ImageRef, ImageStore } from "./image-store.js";

/**
 * An image the assistant explicitly embedded with markdown image syntax
 * (`![label](path)`). Plain links and paths in tool output are not included,
 * so verification screenshots stay out of the chat unless the agent asks for
 * them to be shown.
 */
export interface AssistantImageRef extends ImageRef {
  /** Absolute path of the source file on the Bridge host. */
  path: string;
  /** Alt text written by the assistant, used as the image label. */
  alt?: string;
}

export interface MarkdownImage {
  alt: string;
  path: string;
}

export const MAX_ASSISTANT_IMAGES_PER_MESSAGE = 12;

const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);

// ![alt](destination "optional title"); destination may be <angle bracketed>.
//
// A single regular expression cannot parse this syntax: markdown allows
// balanced brackets in the alt text (`![a [b] c](x.png)`) and balanced
// parentheses in a bare destination (`![shot](Screenshot(1).png)`), plus
// backslash escapes for both. The scanner below tracks those depths instead.
const FENCED_CODE_RE = /^(```|~~~)[^\n]*\n[\s\S]*?(?:^\1[^\n]*$|(?![\s\S]))/gm;
const INLINE_CODE_RE = /`[^`\n]*`/g;
const URL_SCHEME_RE = /^[A-Za-z][A-Za-z0-9+.-]*:/;
const WINDOWS_DRIVE_RE = /^[A-Za-z]:[\\/]/;

/** Extracts local image destinations from markdown, ignoring code and URLs. */
export function extractMarkdownImages(text: string): MarkdownImage[] {
  if (!text.includes("![")) return [];
  // Code is replaced by whitespace, not removed: removing it would join the
  // text on both sides, turning "![a]`code`(x.png)" into an image.
  const prose = text.replace(FENCED_CODE_RE, "\n").replace(INLINE_CODE_RE, " ");
  const images: MarkdownImage[] = [];
  const seen = new Set<string>();
  let index = 0;
  while ((index = prose.indexOf("![", index)) !== -1) {
    const altStart = index + 2;
    index = altStart;
    const alt = scanAltText(prose, altStart);
    if (!alt || prose[alt.end + 1] !== "(") continue;
    const destination = scanDestination(prose, alt.end + 2);
    if (!destination) continue;
    const close = scanTitleAndClose(prose, destination.end);
    if (close === null) continue;
    index = close;
    const path = localPathFromDestination(
      unescapeDestination(destination.value),
    );
    if (!path || seen.has(path)) continue;
    if (!IMAGE_EXTENSIONS.has(extname(path).toLowerCase())) continue;
    seen.add(path);
    images.push({ alt: unescapeMarkdown(alt.value).trim(), path });
  }
  return images;
}

/** Characters CommonMark lets a backslash escape. */
const ESCAPABLE_RE = /[!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]/;

/** Resolve backslash escapes the way a markdown renderer does. */
function unescapeMarkdown(value: string): string {
  let out = "";
  for (let index = 0; index < value.length; index++) {
    const char = value[index];
    if (
      char === "\\" &&
      index + 1 < value.length &&
      ESCAPABLE_RE.test(value[index + 1])
    ) {
      out += value[index + 1];
      index++;
      continue;
    }
    out += char;
  }
  return out;
}

/**
 * Destinations only drop the backslash from the delimiters the scanner itself
 * gives meaning to. Unescaping all punctuation would corrupt Windows paths,
 * where `\.` and `\_` are a separator followed by a file name
 * (`C:\Users\me\.claude\shot.png`).
 */
function unescapeDestination(value: string): string {
  return value.replace(/\\([()<>])/g, "$1");
}

interface Scanned {
  value: string;
  /** Index just past the scanned construct. */
  end: number;
}

/** Alt text: single line, balanced brackets, backslash escapes. */
function scanAltText(text: string, start: number): Scanned | null {
  let depth = 0;
  for (let index = start; index < text.length; index++) {
    const char = text[index];
    if (char === "\\" && text[index + 1] !== "\n") {
      index++;
      continue;
    }
    if (char === "\n") return null;
    if (char === "[") {
      depth++;
      continue;
    }
    if (char === "]") {
      if (depth === 0) return { value: text.slice(start, index), end: index };
      depth--;
    }
  }
  return null;
}

/**
 * Link destination: `<angle bracketed>` (may hold spaces and parentheses) or
 * bare, where balanced parentheses belong to the path. A bare destination
 * ends at the first unbalanced `)` or at whitespace, and cannot contain
 * whitespace even inside parentheses.
 */
function scanDestination(text: string, start: number): Scanned | null {
  let index = start;
  while (text[index] === " " || text[index] === "\t") index++;

  if (text[index] === "<") {
    const begin = index + 1;
    for (index = begin; index < text.length; index++) {
      const char = text[index];
      if (char === "\\") {
        index++;
        continue;
      }
      if (char === "\n" || char === "<") return null;
      if (char === ">") {
        return { value: text.slice(begin, index), end: index + 1 };
      }
    }
    return null;
  }

  const begin = index;
  let depth = 0;
  for (; index < text.length; index++) {
    const char = text[index];
    if (char === "\\") {
      // An escaped space is still a space, so it ends a bare destination.
      const next = text[index + 1];
      if (next === undefined || next === " " || next === "\t" || next === "\n") {
        break;
      }
      index++;
      continue;
    }
    if (char === "\n") break;
    if (char === "(") {
      depth++;
      continue;
    }
    if (char === ")") {
      if (depth === 0) break;
      depth--;
      continue;
    }
    if (char === " " || char === "\t") break;
  }
  if (index === begin || depth !== 0) return null;
  return { value: text.slice(begin, index), end: index };
}

/** Skips an optional title, then requires the closing `)`. */
function scanTitleAndClose(text: string, start: number): number | null {
  let index = start;
  while (text[index] === " " || text[index] === "\t") index++;

  const quote = text[index];
  if (quote === '"' || quote === "'" || quote === "(") {
    const closer = quote === "(" ? ")" : quote;
    for (index++; index < text.length; index++) {
      const char = text[index];
      if (char === "\\") {
        index++;
        continue;
      }
      if (char === "\n") return null;
      if (char === closer) break;
    }
    if (index >= text.length) return null;
    index++;
    while (text[index] === " " || text[index] === "\t") index++;
  }

  return text[index] === ")" ? index + 1 : null;
}

function localPathFromDestination(rawDestination: string): string | null {
  const destination = rawDestination.trim();
  if (!destination || destination.startsWith("//")) return null;

  if (/^file:/i.test(destination)) {
    try {
      return fileURLToPath(destination);
    } catch {
      return null;
    }
  }
  if (URL_SCHEME_RE.test(destination) && !WINDOWS_DRIVE_RE.test(destination)) {
    return null;
  }
  try {
    return decodeURIComponent(destination);
  } catch {
    return destination;
  }
}

export interface AssistantImageResolverOptions {
  imageStore: ImageStore;
  /** Lexical read-access check (allowed + read-only directories). */
  isPathReadable: (path: string) => boolean;
  /** Read-access check for a symlink-resolved path. */
  isCanonicalPathReadable: (path: string) => Promise<boolean>;
}

export type AssistantImageResolver = (
  texts: readonly string[],
  projectPath: string | undefined,
) => Promise<AssistantImageRef[]>;

export function hasMarkdownImages(texts: readonly string[]): boolean {
  return texts.some((text) => extractMarkdownImages(text).length > 0);
}

/** Collects the text blocks of an assistant message content array. */
export function assistantTextBlocks(content: unknown): string[] {
  if (typeof content === "string") return content ? [content] : [];
  if (!Array.isArray(content)) return [];
  const texts: string[] = [];
  for (const block of content) {
    const record = block as Record<string, unknown> | null;
    if (record?.type === "text" && typeof record.text === "string") {
      texts.push(record.text);
    }
  }
  return texts;
}

/**
 * Builds a resolver that registers markdown-embedded images in the image
 * store. Files outside the Bridge's readable directories are skipped.
 */
export function createAssistantImageResolver(
  options: AssistantImageResolverOptions,
): AssistantImageResolver {
  const { imageStore, isPathReadable, isCanonicalPathReadable } = options;
  return async (texts, projectPath) => {
    const refs: AssistantImageRef[] = [];
    const seen = new Set<string>();
    for (const text of texts) {
      for (const image of extractMarkdownImages(text)) {
        if (refs.length >= MAX_ASSISTANT_IMAGES_PER_MESSAGE) return refs;
        if (!isAbsolute(image.path) && !projectPath) continue;
        const absPath = isAbsolute(image.path)
          ? resolve(image.path)
          : resolve(projectPath!, image.path);
        if (seen.has(absPath)) continue;
        seen.add(absPath);
        try {
          if (!isPathReadable(absPath)) continue;
          const canonicalPath = await realpath(absPath);
          if (!(await isCanonicalPathReadable(canonicalPath))) continue;
          if (!(await stat(canonicalPath)).isFile()) continue;
          const [ref] = await imageStore.registerImages([canonicalPath]);
          if (!ref) continue;
          refs.push({
            ...ref,
            path: absPath,
            ...(image.alt ? { alt: image.alt } : {}),
          });
        } catch {
          // Missing or unreadable files are simply not attached.
        }
      }
    }
    return refs;
  };
}
