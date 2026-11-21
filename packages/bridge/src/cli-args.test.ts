import { describe, expect, it } from "vitest";
import { hasFlag, parseCliArgs, parseFlag } from "./cli-args.js";

describe("parseCliArgs", () => {
  it("detects long help flag", () => {
    const parsed = parseCliArgs(["--help"]);
    expect(parsed.helpRequested).toBe(true);
  });

  it("detects short help flag", () => {
    const parsed = parseCliArgs(["-h"]);
    expect(parsed.helpRequested).toBe(true);
  });

  it("detects help command", () => {
    const parsed = parseCliArgs(["help"]);
    expect(parsed.command).toBe("help");
    expect(parsed.helpRequested).toBe(true);
  });

  it("detects long version flag", () => {
    const parsed = parseCliArgs(["--version"]);
    expect(parsed.versionRequested).toBe(true);
  });

  it("detects short version flag", () => {
    const parsed = parseCliArgs(["-v"]);
    expect(parsed.versionRequested).toBe(true);
  });

  it("detects version command", () => {
    const parsed = parseCliArgs(["version"]);
    expect(parsed.command).toBe("version");
    expect(parsed.versionRequested).toBe(true);
  });

  it("does not treat flag values as commands", () => {
    const parsed = parseCliArgs([
      "--public-ws-url",
      "wss://example.ngrok-free.app",
      "--no-mdns",
    ]);

    expect(parsed.command).toBeUndefined();
    expect(parseFlag(parsed, "public-ws-url")).toBe(
      "wss://example.ngrok-free.app",
    );
    expect(hasFlag(parsed, "no-mdns")).toBe(true);
  });

  it("parses inline flag values", () => {
    const parsed = parseCliArgs(["--port=9000", "--host=127.0.0.1"]);

    expect(parseFlag(parsed, "port")).toBe("9000");
    expect(parseFlag(parsed, "host")).toBe("127.0.0.1");
  });

  it("preserves a value flag with a missing value", () => {
    const parsed = parseCliArgs(["--port"]);

    expect(parseFlag(parsed, "port")).toBe("");
  });

  it("does not consume a following flag as a missing option value", () => {
    const parsed = parseCliArgs(["--port", "--help"]);

    expect(parseFlag(parsed, "port")).toBe("");
    expect(parsed.helpRequested).toBe(true);
  });

  it("preserves dash-prefixed values that are not known CLI flags", () => {
    const parsed = parseCliArgs(["--api-key", "-secret"]);

    expect(parseFlag(parsed, "api-key")).toBe("-secret");
  });

  it("detects setup command after valued flags", () => {
    const parsed = parseCliArgs(["--port", "9000", "setup", "--uninstall"]);

    expect(parsed.command).toBe("setup");
    expect(parseFlag(parsed, "port")).toBe("9000");
    expect(hasFlag(parsed, "uninstall")).toBe(true);
  });

  it("reports no help or version request for an ordinary command", () => {
    const parsed = parseCliArgs(["setup", "--port", "9000"]);

    expect(parsed.helpRequested).toBe(false);
    expect(parsed.versionRequested).toBe(false);
  });

  it("stores boolean flags as true and exposes no string value for them", () => {
    const parsed = parseCliArgs(["-h", "-v", "--json", "--insecure-no-auth"]);

    expect(parsed.flags.get("help")).toBe(true);
    expect(parsed.flags.get("version")).toBe(true);
    expect(parsed.flags.get("json")).toBe(true);
    expect(parsed.flags.get("insecure-no-auth")).toBe(true);
    expect(parseFlag(parsed, "json")).toBeUndefined();
    expect(parsed.command).toBeUndefined();
  });

  it.each([
    "port",
    "host",
    "api-key",
    "public-ws-url",
    "codex-app-server-mode",
    "codex-shared-app-server-url",
    "codex-app-server-port",
    "codex-app-server-url",
  ])("reads --%s as a value flag", (name) => {
    const parsed = parseCliArgs([`--${name}`, "value", "setup"]);

    expect(parseFlag(parsed, name)).toBe("value");
    expect(parsed.command).toBe("setup");
  });

  it.each(["json", "uninstall", "no-mdns", "insecure-no-auth"])(
    "reads --%s as a boolean flag that takes no value",
    (name) => {
      const parsed = parseCliArgs([`--${name}`, "setup"]);

      expect(hasFlag(parsed, name)).toBe(true);
      expect(parsed.command).toBe("setup");
    },
  );

  it("treats unknown flags and single-dash words as positionals", () => {
    expect(parseCliArgs(["--unknown"]).command).toBe("--unknown");
    expect(parseCliArgs(["--unknown"]).flags.size).toBe(0);
    expect(parseCliArgs(["-x", "setup"]).command).toBe("-x");
    // A word that merely ends in a flag name is not that flag.
    expect(parseCliArgs(["xxhelp"]).helpRequested).toBe(false);
    expect(parseCliArgs(["xxport", "9000"]).command).toBe("xxport");
  });

  it.each([
    ["-h", "help"],
    ["-v", "version"],
    ["--version", "version"],
    ["--json", "json"],
    ["--host", "host"],
    ["--host=0.0.0.0", "host"],
  ])("leaves a value flag empty when %s follows it", (next, nextName) => {
    const parsed = parseCliArgs(["--port", next]);

    expect(parseFlag(parsed, "port")).toBe("");
    expect(hasFlag(parsed, nextName)).toBe(true);
  });

  it.each(["--unknown", "--unknown=1", "9000", "-x"])(
    "consumes %s as the value of a preceding value flag",
    (value) => {
      const parsed = parseCliArgs(["--api-key", value]);

      expect(parseFlag(parsed, "api-key")).toBe(value);
      expect(parsed.command).toBeUndefined();
    },
  );

  it("keeps everything after the first '=' as an inline value", () => {
    const parsed = parseCliArgs(["--public-ws-url=wss://host/path?a=b"]);

    expect(parseFlag(parsed, "public-ws-url")).toBe("wss://host/path?a=b");
  });
});
