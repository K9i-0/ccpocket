/**
 * Detection for third-party Claude API backends on the Bridge host.
 *
 * Claude Code and the Claude Agent SDK can run against Amazon Bedrock instead
 * of the first-party Anthropic API. In that mode there is no Anthropic API key
 * and no Claude.ai login: requests are signed with AWS credentials that the
 * Claude Code process resolves through the AWS default credential provider
 * chain on the Bridge machine.
 *
 * The Bridge only needs the provider flag for its startup gate and the region
 * for doctor diagnostics. It does not access credential fields from Claude
 * settings or send AWS configuration to the mobile app.
 *
 * https://code.claude.com/docs/en/amazon-bedrock
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const BEDROCK_ENV_VAR = "CLAUDE_CODE_USE_BEDROCK";
const AWS_REGION_ENV_VAR = "AWS_REGION";

/** Values Claude Code accepts for its own boolean environment variables. */
const TRUTHY_VALUES = new Set(["1", "true", "yes", "on"]);

function isTruthy(value: unknown): boolean {
  if (typeof value !== "string") return false;
  return TRUTHY_VALUES.has(value.trim().toLowerCase());
}

/**
 * Read a non-secret environment setting from the Claude Code user settings.
 *
 * `claude`'s Amazon Bedrock login wizard writes its result to the `env` block
 * of the user settings file instead of exporting shell variables, and the
 * Bridge starts SDK queries with the `user` setting source enabled. The JSON
 * file is parsed as a whole, but only the requested field is accessed and
 * returned; other values are not retained or logged.
 */
function valueFromUserSettings(
  env: NodeJS.ProcessEnv,
  name: string,
): unknown {
  const configDir = env.CLAUDE_CONFIG_DIR?.trim();
  const settingsPath = join(configDir || join(homedir(), ".claude"), "settings.json");
  try {
    const settings: unknown = JSON.parse(readFileSync(settingsPath, "utf-8"));
    if (!settings || typeof settings !== "object") return undefined;
    const settingsEnv = (settings as { env?: unknown }).env;
    if (!settingsEnv || typeof settingsEnv !== "object") return undefined;
    return (settingsEnv as Record<string, unknown>)[name];
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
  return (
    isTruthy(env[BEDROCK_ENV_VAR])
    || isTruthy(valueFromUserSettings(env, BEDROCK_ENV_VAR))
  );
}

/** Whether the required Bedrock region is available to Claude Code. */
export function isClaudeBedrockRegionConfigured(
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  const hasRegion = (value: unknown): boolean =>
    typeof value === "string" && value.trim().length > 0;
  return (
    hasRegion(env[AWS_REGION_ENV_VAR])
    || hasRegion(valueFromUserSettings(env, AWS_REGION_ENV_VAR))
  );
}
