import { describe, expect, it } from "vitest";
import {
  clientProtocolRange,
  negotiateProtocolVersion,
} from "./protocol-version.js";

describe("protocol version negotiation", () => {
  it("treats clients without metadata as protocol 1", () => {
    expect(clientProtocolRange({})).toEqual({ min: 1, max: 1 });
  });

  it("treats a singular client version as an exact range", () => {
    expect(clientProtocolRange({ protocolVersion: 2 })).toEqual({
      min: 2,
      max: 2,
    });
  });

  it("selects the highest overlapping protocol version", () => {
    expect(
      negotiateProtocolVersion({ min: 1, max: 3 }, { min: 2, max: 4 }),
    ).toBe(3);
  });

  it("returns null when protocol ranges do not overlap", () => {
    expect(
      negotiateProtocolVersion({ min: 1, max: 1 }, { min: 2, max: 2 }),
    ).toBeNull();
  });
});
