/**
 * Detection for third-party Claude API backends on the Bridge host.
 *
 * Claude Code and the Claude Agent SDK can run against Amazon Bedrock instead
 * of the first-party Anthropic API. In that mode there is no Anthropic API key
 * and no Claude.ai login: requests are signed with AWS credentials that the
 * Claude Code process resolves through the AWS default credential provider
 * chain on the Bridge machine.
 *
 * The Bridge only needs to know whether that mode is active so it does not ask
 * for Anthropic credentials the setup never uses. It never reads, stores, logs,
 * or forwards AWS credentials.
 *
 * https://code.claude.com/docs/en/amazon-bedrock
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const BEDROCK_ENV_VAR = "CLAUDE_CODE_USE_BEDROCK";

/** Values Claude Code accepts for its own boolean environment variables. */
const TRUTHY_VALUES = new Set(["1", "true", "yes", "on"]);

function isTruthy(value: unknown): boolean {
  if (typeof value !== "string") return false;
  return TRUTHY_VALUES.has(value.trim().toLowerCase());
}

/**
 * Read only `env.CLAUDE_CODE_USE_BEDROCK` from the Claude Code user settings.
 *
 * `claude`'s Amazon Bedrock login wizard writes its result to the `env` block
 * of the user settings file instead of exporting shell variables, and the
 * Bridge starts SDK queries with the `user` setting source enabled. No other
 * value from that file is inspected, returned, or logged.
 */
function bedrockFlagFromUserSettings(env: NodeJS.ProcessEnv): unknown {
  const configDir = env.CLAUDE_CONFIG_DIR?.trim();
  const settingsPath = join(configDir || join(homedir(), ".claude"), "settings.json");
  try {
    const settings: unknown = JSON.parse(readFileSync(settingsPath, "utf-8"));
    if (!settings || typeof settings !== "object") return undefined;
    const settingsEnv = (settings as { env?: unknown }).env;
    if (!settingsEnv || typeof settingsEnv !== "object") return undefined;
    return (settingsEnv as Record<string, unknown>)[BEDROCK_ENV_VAR];
  } catch {
    // Missing, unreadable, or invalid settings mean "not configured".
    return undefined;
  }
}

/**
 * Whether Claude Code on this host is configured to use Amazon Bedrock.
 *
 * Either source enables it, matching how Claude Code resolves the flag from the
 * process environment and from its settings files.
 */
export function isClaudeBedrockModeEnabled(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return isTruthy(env[BEDROCK_ENV_VAR]) || isTruthy(bedrockFlagFromUserSettings(env));
}
