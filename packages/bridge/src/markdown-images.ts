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
const MARKDOWN_IMAGE_RE =
  /!\[([^\]\n]*)\]\(\s*(<[^>\n]+>|[^)\s]+)(?:\s+(?:"[^"\n]*"|'[^'\n]*'))?\s*\)/g;
const FENCED_CODE_RE = /^(```|~~~)[^\n]*\n[\s\S]*?(?:^\1[^\n]*$|(?![\s\S]))/gm;
const INLINE_CODE_RE = /`[^`\n]*`/g;
const URL_SCHEME_RE = /^[A-Za-z][A-Za-z0-9+.-]*:/;
const WINDOWS_DRIVE_RE = /^[A-Za-z]:[\\/]/;

/** Extracts local image destinations from markdown, ignoring code and URLs. */
export function extractMarkdownImages(text: string): MarkdownImage[] {
  if (!text.includes("![")) return [];
  const prose = text.replace(FENCED_CODE_RE, "").replace(INLINE_CODE_RE, "");
  const images: MarkdownImage[] = [];
  const seen = new Set<string>();
  for (const match of prose.matchAll(MARKDOWN_IMAGE_RE)) {
    const path = localPathFromDestination(match[2]);
    if (!path || seen.has(path)) continue;
    if (!IMAGE_EXTENSIONS.has(extname(path).toLowerCase())) continue;
    seen.add(path);
    images.push({ alt: match[1].trim(), path });
  }
  return images;
}

function localPathFromDestination(rawDestination: string): string | null {
  let destination = rawDestination.trim();
  if (destination.startsWith("<") && destination.endsWith(">")) {
    destination = destination.slice(1, -1).trim();
  }
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
