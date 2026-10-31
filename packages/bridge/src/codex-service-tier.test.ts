import { describe, expect, it } from "vitest";
import {
  normalizeCodexServiceTierForClient,
  normalizeCodexServiceTierForRpc,
  extractCodexServiceTierMetadata,
  isCodexServiceTierSupported,
} from "./codex-service-tier.js";

describe("Codex service tier normalization", () => {
  it("normalizes the internal priority tier to Fast for clients", () => {
    expect(normalizeCodexServiceTierForClient("priority")).toBe("fast");
  });

  it("normalizes standard tiers to the RPC default", () => {
    expect(normalizeCodexServiceTierForRpc("standard")).toBeNull();
    expect(normalizeCodexServiceTierForRpc("default")).toBeNull();
  });

  it("accepts both Fast spellings for RPCs", () => {
    expect(normalizeCodexServiceTierForRpc("fast")).toBe("fast");
    expect(normalizeCodexServiceTierForRpc("priority")).toBe("fast");
  });

  it("preserves future non-UI service tiers", () => {
    expect(normalizeCodexServiceTierForClient("flex")).toBe("flex");
  });

  it("preserves Ultrafast metadata and normalizes only the priority id", () => {
    expect(extractCodexServiceTierMetadata({ serviceTiers: [
      { id: "priority", name: "Fast", description: "2x speed, increased usage" },
      { id: "ultrafast", name: "Ultrafast", description: "Fastest responses" },
      { id: "custom", name: "Fast" },
    ] })).toEqual([
      { id: "fast", name: "Fast", description: "2x speed, increased usage" },
      { id: "ultrafast", name: "Ultrafast", description: "Fastest responses" },
      { id: "custom", name: "Fast" },
    ]);
  });

  it("respects an explicitly empty current catalog and handles legacy catalogs", () => {
    expect(extractCodexServiceTierMetadata({ serviceTiers: [], additionalSpeedTiers: ["fast"] })).toEqual([]);
    expect(extractCodexServiceTierMetadata({ additionalSpeedTiers: ["fast", "priority", "ultrafast"] })).toEqual([
      { id: "fast", name: "Fast" }, { id: "ultrafast", name: "ultrafast" },
    ]);
  });

  it("rejects unadvertised tiers without changing the requested tier", () => {
    expect(isCodexServiceTierSupported("ultrafast", ["fast"])).toBe(false);
    expect(isCodexServiceTierSupported("ultrafast", ["priority", "ultrafast"])).toBe(true);
    expect(isCodexServiceTierSupported("priority", ["fast"])).toBe(true);
    expect(isCodexServiceTierSupported("standard", [])).toBe(true);
    expect(normalizeCodexServiceTierForRpc("ultrafast")).toBe("ultrafast");
  });
});
