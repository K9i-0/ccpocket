export interface CodexServiceTierMetadata {
  id: string;
  name: string;
  description?: string;
}

/** The model catalog is a candidate list, not proof of account entitlement. */
export function isCodexServiceTierSupported(
  value: string,
  supportedTiers: readonly string[],
): boolean {
  const tier = normalizeCodexServiceTierForClient(value);
  return (
    tier === "standard" ||
    supportedTiers.some(
      (supported) => normalizeCodexServiceTierForClient(supported) === tier,
    )
  );
}

export function extractCodexServiceTierMetadata(
  raw: Record<string, unknown>,
): CodexServiceTierMetadata[] {
  const values = Array.isArray(raw.serviceTiers)
    ? raw.serviceTiers
    : Array.isArray(raw.additionalSpeedTiers)
      ? raw.additionalSpeedTiers
      : [];
  const tiers = new Map<string, CodexServiceTierMetadata>();
  for (const value of values) {
    const entry =
      value && typeof value === "object"
        ? (value as Record<string, unknown>)
        : undefined;
    const rawId = typeof value === "string" ? value : entry?.id;
    if (typeof rawId !== "string" || !rawId.trim()) continue;
    const id = normalizeCodexServiceTierForClient(rawId);
    if (tiers.has(id)) continue;
    const name =
      typeof entry?.name === "string" && entry.name.trim()
        ? entry.name.trim()
        : id === "fast" ? "Fast" : id;
    const description =
      typeof entry?.description === "string" ? entry.description : undefined;
    tiers.set(id, { id, name, ...(description ? { description } : {}) });
  }
  return [...tiers.values()];
}

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
