import { describe, expect, it, vi } from "vitest";
import { LogBuffer } from "./log-buffer.js";

describe("LogBuffer", () => {
  it("keeps the newest entries within capacity", () => {
    const buffer = new LogBuffer(3, 5);
    for (let i = 0; i < 5; i += 1) buffer.add("info", `m${i}`, i);
    buffer.add("warn", "long message", 9);
    expect(buffer.tail()).toEqual([
      { time: 3, level: "info", message: "m3" },
      { time: 4, level: "info", message: "m4" },
      { time: 9, level: "warn", message: "long …" },
    ]);
    expect(buffer.tail(1).map((e) => e.time)).toEqual([9]);
    expect(buffer.tail(0)).toEqual([]);
  });

  it("drops messages that contain a secret", () => {
    const buffer = new LogBuffer();
    buffer.addSecret("fixture/key+value");
    buffer.add("info", "link ccpocket://connect?token=fixture%2Fkey%2Bvalue\n▄▄▄", 1);
    buffer.add("info", "raw fixture/key+value", 2);
    buffer.add("info", "harmless", 3);
    expect(buffer.tail().map((e) => e.message)).toEqual([
      "[pairing details omitted]",
      "[pairing details omitted]",
      "harmless",
    ]);
  });

  it("mirrors console output and still calls the original", () => {
    const log = vi.fn();
    const error = vi.fn();
    const target = { log, info: vi.fn(), warn: vi.fn(), error } as unknown as Console;
    const buffer = new LogBuffer();
    buffer.install(target);
    target.log("a %s", "b");
    target.error("boom");
    expect(log).toHaveBeenCalledWith("a %s", "b");
    expect(error).toHaveBeenCalledWith("boom");
    expect(buffer.tail().map((e) => [e.level, e.message])).toEqual([
      ["info", "a b"],
      ["error", "boom"],
    ]);
  });
});
