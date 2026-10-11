export interface McpResourceLink {
  uri: string;
  name: string;
  description?: string;
  mimeType?: string;
}

const MAX_RESOURCE_LINKS = 32;
const MAX_URI_LENGTH = 2048;
const MAX_NAME_LENGTH = 256;
const MAX_DESCRIPTION_LENGTH = 1024;
const MAX_MIME_TYPE_LENGTH = 256;

/** Returns only MCP resource links explicitly addressed to the user. */
export function mcpUserResourceLinks(
  contentBlocks: unknown,
): McpResourceLink[] {
  if (!Array.isArray(contentBlocks)) return [];

  const links = new Map<string, McpResourceLink>();
  for (const value of contentBlocks) {
    if (links.size >= MAX_RESOURCE_LINKS) break;
    const block = asRecord(value);
    if (!block || block.type !== "resource_link") continue;
    const annotations = asRecord(block.annotations);
    const audience = annotations?.audience;
    if (!Array.isArray(audience) || !audience.includes("user")) continue;

    const uri = boundedNonEmptyString(block.uri, MAX_URI_LENGTH);
    const name = boundedNonEmptyString(block.name, MAX_NAME_LENGTH);
    if (!uri || !name) continue;

    const description = boundedNonEmptyString(
      block.description,
      MAX_DESCRIPTION_LENGTH,
    );
    const mimeType = boundedNonEmptyString(
      block.mimeType,
      MAX_MIME_TYPE_LENGTH,
    );
    links.set(uri, {
      uri,
      name,
      ...(description ? { description } : {}),
      ...(mimeType ? { mimeType } : {}),
    });
  }

  return [...links.values()];
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function boundedNonEmptyString(
  value: unknown,
  maxLength: number,
): string | undefined {
  return typeof value === "string" &&
    value.trim().length > 0 &&
    value.length <= maxLength
    ? value.trim()
    : undefined;
}
