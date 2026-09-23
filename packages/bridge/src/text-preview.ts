/** Preserve exact line counts without allocating a string for every omitted line. */
export function textPreview(raw: string, maxLines: number): {
  content: string;
  totalLines: number;
  truncated: boolean;
} {
  const limit = Math.trunc(maxLines);
  let totalLines = 1;
  let end = limit === 0 ? 0 : raw.length;
  let index = -1;
  while ((index = raw.indexOf("\n", index + 1)) !== -1) {
    if (totalLines === limit) end = index;
    totalLines++;
  }
  const truncated = totalLines > maxLines;
  return { content: truncated ? raw.slice(0, end) : raw, totalLines, truncated };
}
