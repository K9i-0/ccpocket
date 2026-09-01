import { describe, expect, it } from "vitest";
import {
  normalizeCodexServiceTierForClient,
  normalizeCodexServiceTierForRpc,
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
});
