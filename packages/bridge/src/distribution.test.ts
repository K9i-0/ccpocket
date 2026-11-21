import { describe, expect, it } from "vitest";
import {
  BRIDGE_STABLE_PACKAGE_SPEC,
  BRIDGE_STABLE_SETUP_COMMAND,
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

  it.each([
    "npx --yes @ccpocket/bridge@latest setup",
    "npx --yes @ccpocket/bridge@latest\n",
    "ExecStart='npx' '@ccpocket/bridge@latest'",
    'args = ["--yes", "@ccpocket/bridge@latest"]',
    "<string>@ccpocket/bridge@latest</string>",
  ])("detects latest at the end of a token: %j", (contents) => {
    expect(usesUnboundedBridgeLatest(contents)).toBe(true);
  });

  it.each([
    "npx --yes @ccpocket/bridge@latest-1",
    "npx --yes @ccpocket/bridge@latestish setup",
    "npx --yes @other/bridge@latest",
    "",
  ])("ignores other specs that merely start with latest: %j", (contents) => {
    expect(usesUnboundedBridgeLatest(contents)).toBe(false);
  });

  it("builds the setup command from the pinned spec", () => {
    expect(BRIDGE_STABLE_SETUP_COMMAND).toBe("npx --yes @ccpocket/bridge@1 setup");
  });
});
