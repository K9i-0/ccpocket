import { afterEach, describe, expect, it } from "vitest";
import { DEFAULT_BRIDGE_PORT, parseBridgePort } from "./bridge-port.js";

const originalBridgePort = process.env.BRIDGE_PORT;

describe("parseBridgePort", () => {
  afterEach(() => {
    if (originalBridgePort === undefined) {
      delete process.env.BRIDGE_PORT;
    } else {
      process.env.BRIDGE_PORT = originalBridgePort;
    }
  });

  it("uses the default bridge port when no value is configured", () => {
    delete process.env.BRIDGE_PORT;

    expect(parseBridgePort()).toBe(DEFAULT_BRIDGE_PORT);
  });

  it("reads BRIDGE_PORT from the environment", () => {
    process.env.BRIDGE_PORT = "9876";

    expect(parseBridgePort()).toBe(9876);
  });

  it.each([
    ["1", 1],
    ["8765", 8765],
    ["65535", 65535],
    [" 8765 ", 8765],
  ])("accepts %s", (rawPort, expected) => {
    expect(parseBridgePort(rawPort)).toBe(expected);
  });

  it.each(["", "0", "-1", "65536", "123abc", "8.5", "NaN"])(
    "rejects %s",
    (rawPort) => {
      expect(() => parseBridgePort(rawPort)).toThrow(
        `Invalid BRIDGE_PORT "${rawPort}"`,
      );
    },
  );
});
