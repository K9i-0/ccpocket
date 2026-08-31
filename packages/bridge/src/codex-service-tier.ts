export function normalizeCodexServiceTierForRpc(
  value: string,
): string | null {
  const normalized = normalizeCodexServiceTierForClient(value);
  return normalized === "standard" ? null : normalized;
}

export function normalizeCodexServiceTierForClient(value: unknown): string {
  if (typeof value !== "string") return "standard";
  const normalized = value.trim();
  if (!normalized || normalized === "default" || normalized === "standard") {
    return "standard";
  }
  return normalized === "priority" ? "fast" : normalized;
}
