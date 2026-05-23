import { describe, expect, it } from "vitest";

import { resolveBonjourConstructor } from "./mdns.js";

class BonjourV14 {
  publish(): never {
    throw new Error("not implemented");
  }

  destroy(): void {
    // no-op
  }
}

class BonjourV13 {
  publish(): never {
    throw new Error("not implemented");
  }

  destroy(): void {
    // no-op
  }
}

describe("resolveBonjourConstructor", () => {
  it("returns the constructor from bonjour-service 1.4 export shape", () => {
    expect(resolveBonjourConstructor(BonjourV14)).toBe(BonjourV14);
  });

  it("returns the constructor from bonjour-service 1.3 export shape", () => {
    expect(
      resolveBonjourConstructor({
        Bonjour: BonjourV13,
        default: BonjourV13,
      }),
    ).toBe(BonjourV13);
  });

  it("returns the constructor from nested default interop shape", () => {
    expect(
      resolveBonjourConstructor({
        default: {
          Bonjour: BonjourV13,
        },
      }),
    ).toBe(BonjourV13);
  });

  it("throws for unsupported export shape", () => {
    expect(() => resolveBonjourConstructor({})).toThrow(
      "Unsupported bonjour-service export shape",
    );
  });
});
