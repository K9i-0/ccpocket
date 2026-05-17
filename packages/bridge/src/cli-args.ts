const VALUE_FLAGS = new Set([
  "port",
  "host",
  "api-key",
  "public-ws-url",
  "codex-app-server-mode",
  "codex-shared-app-server-url",
  "codex-app-server-port",
  "codex-app-server-url",
]);

const BOOLEAN_FLAGS = new Set([
  "json",
  "uninstall",
  "no-mdns",
]);

export interface ParsedCliArgs {
  command?: string;
  flags: Map<string, string | true>;
  helpRequested: boolean;
  versionRequested: boolean;
}

export function parseCliArgs(args: string[]): ParsedCliArgs {
  const flags = new Map<string, string | true>();
  const positionals: string[] = [];

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];

    if (arg === "-h") {
      flags.set("help", true);
      continue;
    }
    if (arg === "-v") {
      flags.set("version", true);
      continue;
    }
    if (arg.startsWith("--")) {
      const raw = arg.slice(2);
      const equalIndex = raw.indexOf("=");
      const name = equalIndex === -1 ? raw : raw.slice(0, equalIndex);
      const inlineValue =
        equalIndex === -1 ? undefined : raw.slice(equalIndex + 1);

      if (VALUE_FLAGS.has(name)) {
        if (inlineValue !== undefined) {
          flags.set(name, inlineValue);
        } else if (i + 1 < args.length) {
          flags.set(name, args[i + 1]);
          i += 1;
        }
        continue;
      }

      if (
        BOOLEAN_FLAGS.has(name) ||
        name === "help" ||
        name === "version"
      ) {
        flags.set(name, true);
        continue;
      }
    }

    positionals.push(arg);
  }

  const command = positionals[0];

  return {
    command,
    flags,
    helpRequested: flags.has("help") || command === "help",
    versionRequested: flags.has("version") || command === "version",
  };
}

export function parseFlag(
  parsed: ParsedCliArgs,
  name: string,
): string | undefined {
  const value = parsed.flags.get(name);
  return typeof value === "string" ? value : undefined;
}

export function hasFlag(parsed: ParsedCliArgs, name: string): boolean {
  return parsed.flags.has(name);
}
