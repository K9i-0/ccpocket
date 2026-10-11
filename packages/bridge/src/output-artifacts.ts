export interface OutputLinkCandidate {
  href: string;
  syntax: "markdown" | "inline" | "bare";
  /** Bounded visible link text for the artifact card. */
  label?: string;
}

const MAX_CANDIDATES = 32;
const MAX_PATH_LENGTH = 256;
const MAX_LABEL_LENGTH = 256;
const MAX_METADATA_BYTES = 8 * 1024;
const MAX_TEXT_LENGTH = 4 * 1024 * 1024;
const candidateCache = new WeakMap<object, { content: string; links: OutputLinkCandidate[] }>();

/** Shared history objects are projected independently for each connected client. */
export function outputLinkCandidatesForMessage(message: { content?: unknown }): OutputLinkCandidate[] {
  if (typeof message.content !== "string") return [];
  const cached = candidateCache.get(message);
  if (cached?.content === message.content) return cached.links;
  const links = extractOutputLinkCandidates(message.content);
  candidateCache.set(message, { content: message.content, links });
  return links;
}

function extractOutputLinkCandidates(text: string): OutputLinkCandidate[] {
  const candidates: OutputLinkCandidate[] = [];
  const seen = new Set<string>();
  let metadataBytes = 2;
  const add = (
    href: string,
    syntax: OutputLinkCandidate["syntax"],
    rawLabel?: string,
  ) => {
    if (candidates.length >= MAX_CANDIDATES || href.length > MAX_PATH_LENGTH) return;
    if (!href || href.startsWith("#") || href.endsWith("/")) return;
    if (/^[a-z][a-z0-9+.-]*:/i.test(href) && !/^file:/i.test(href) && !/^[a-z]:[\\/]/i.test(href)) return;
    if (href.startsWith("//")) return;
    const key = `${syntax}:${href}`;
    if (seen.has(key)) return;
    const normalizedLabel = rawLabel
      ?.replace(/[\u0000-\u001f\u007f]/g, " ")
      .trim();
    const label = normalizedLabel
      ? Array.from(normalizedLabel).slice(0, MAX_LABEL_LENGTH).join("")
      : undefined;
    const candidate = { href, syntax, ...(label ? { label } : {}) };
    const bytes = Buffer.byteLength(JSON.stringify(candidate)) + 1;
    if (metadataBytes + bytes > MAX_METADATA_BYTES) return;
    metadataBytes += bytes;
    seen.add(key);
    candidates.push(candidate);
  };

  let textOutsideCode = outsideMarkdownCode(text.slice(0, MAX_TEXT_LENGTH));

  textOutsideCode = textOutsideCode.replace(/`+[^`\n]*`+/g, (code) =>
    " ".repeat(code.length),
  );
  textOutsideCode = textOutsideCode.replace(
    /!?\[([^\]\n]*)\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+["'][^\n]*?["'])?\s*\)/g,
    (
      _,
      label: string,
      angleHref: string | undefined,
      href: string | undefined,
    ) => {
      add(angleHref ?? href ?? "", "markdown", label);
      return "";
    },
  );
  return candidates;
}

function outsideMarkdownCode(text: string): string {
  let fence: string | undefined;
  const listContentIndents: number[] = [];
  return text.split("\n").map((line) => {
    const leading = /^[ \t]*/.exec(line)![0];
    const indent = leading.replaceAll("\t", "    ").length;
    let content = line.slice(leading.length);
    if (content.trim() === "") return "";
    while (listContentIndents.length && listContentIndents.at(-1)! > indent) listContentIndents.pop();
    const listIndent = listContentIndents.at(-1);
    const insideList = listIndent != null && indent < listIndent + 4;
    const listMarker = /^([*+-]|\d+[.)])([ \t]+)/.exec(content);
    if (listMarker && (indent < 4 || insideList)) {
      listContentIndents.push(indent + listMarker[0].length);
      content = content.slice(listMarker[0].length);
    }
    const marker = /^(`{3,}|~{3,})/.exec(content)?.[1];
    if (fence) {
      if (marker?.[0] === fence[0] && marker.length >= fence.length) fence = undefined;
      return "";
    }
    if (indent >= 4 && !insideList) return "";
    if (marker) { fence = marker; return ""; }
    return line;
  }).join("\n");
}
