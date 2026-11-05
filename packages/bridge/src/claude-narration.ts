/**
 * Claude Code "narration": the short prose the model writes between tool calls
 * ("I'll check X first..."). The API delivers it as a `thinking` block whose
 * signature carries block_kind "narration", and Claude Code's terminal renders
 * it as ordinary assistant text. The SDK frame also lists these blocks in the
 * internal `narration_block_indexes` sibling field, but transcripts (JSONL)
 * keep only the signature, so both are honoured here.
 *
 * Clients treat thinking as optional detail (performance/lite modes drop it),
 * so narration is projected to a `text` block for display. This is a delivery
 * projection only; the agent's canonical transcript is untouched.
 */

const NARRATION_KIND = Buffer.from("narration", "utf8");
// Protobuf field 8 (block_kind), wire type 2 (length-delimited) => tag 0x42.
const NARRATION_FIELD = Buffer.concat([
  Buffer.from([0x42, NARRATION_KIND.length]),
  NARRATION_KIND,
]);
// block_kind sits in the signature header; no need to decode the whole blob.
const SIGNATURE_HEADER_CHARS = 96;

export function isNarrationSignature(signature: unknown): boolean {
  if (typeof signature !== "string" || signature.length === 0) return false;
  const head = signature.slice(0, SIGNATURE_HEADER_CHARS);
  const decoded = Buffer.from(head.slice(0, head.length - (head.length % 4)), "base64");
  return decoded.includes(NARRATION_FIELD);
}

type Block = Record<string, unknown>;

/**
 * Returns `content` with narration thinking blocks replaced by text blocks.
 * Returns the same array instance when nothing changed.
 */
export function projectNarrationBlocks<T>(
  content: T[],
  narrationIndexes?: unknown,
): T[] {
  const indexes = new Set(
    Array.isArray(narrationIndexes)
      ? narrationIndexes.filter((i): i is number => Number.isInteger(i))
      : [],
  );
  let changed = false;
  const projected = content.map((block, index) => {
    if (!block || typeof block !== "object") return block;
    const candidate = block as unknown as Block;
    if (candidate.type !== "thinking" || typeof candidate.thinking !== "string") {
      return block;
    }
    if (!indexes.has(index) && !isNarrationSignature(candidate.signature)) {
      return block;
    }
    const text = candidate.thinking.trim();
    if (!text) return block;
    changed = true;
    return { type: "text", text } as unknown as T;
  });
  return changed ? projected : content;
}
