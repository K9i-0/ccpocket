import { describe, expect, it } from "vitest";
import {
  BRIDGE_STABLE_PACKAGE_SPEC,
  usesUnboundedBridgeLatest,
} from "./distribution.js";

describe("Bridge distribution channel", () => {
  it("pins persistent services to the current major", () => {
    expect(BRIDGE_STABLE_PACKAGE_SPEC).toBe("@ccpocket/bridge@1");
  });

  it("detects an unbounded latest service", () => {
    expect(
      usesUnboundedBridgeLatest(
        "exec npx --yes @ccpocket/bridge@latest",
      ),
    ).toBe(true);
    expect(
      usesUnboundedBridgeLatest("exec npx --yes @ccpocket/bridge@1"),
    ).toBe(false);
  });
});
