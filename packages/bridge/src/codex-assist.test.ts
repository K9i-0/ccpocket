import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  DEFAULT_CODEX_ASSIST_MODEL,
  DEFAULT_CODEX_ASSIST_REASONING_EFFORT,
  getCodexAssistModel,
  getCodexAssistReasoningConfig,
  getCodexAssistReasoningEffort,
} from "./codex-assist.js";

const originalModel = process.env.BRIDGE_CODEX_ASSIST_MODEL;
const originalReasoningEffort =
  process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT;

describe("codex assist config", () => {
  beforeEach(() => {
    delete process.env.BRIDGE_CODEX_ASSIST_MODEL;
    delete process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT;
  });

  afterEach(() => {
    restoreEnvVar("BRIDGE_CODEX_ASSIST_MODEL", originalModel);
    restoreEnvVar(
      "BRIDGE_CODEX_ASSIST_REASONING_EFFORT",
      originalReasoningEffort,
    );
  });

  it("uses existing defaults when overrides are absent or blank", () => {
    process.env.BRIDGE_CODEX_ASSIST_MODEL = "  ";
    process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT = "";

    expect(getCodexAssistModel()).toBe(DEFAULT_CODEX_ASSIST_MODEL);
    expect(getCodexAssistReasoningEffort()).toBe(
      DEFAULT_CODEX_ASSIST_REASONING_EFFORT,
    );
  });

  it("reads trimmed environment overrides", () => {
    process.env.BRIDGE_CODEX_ASSIST_MODEL = " gpt-oss:20b-cloud ";
    process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT = " low ";

    expect(getCodexAssistModel()).toBe("gpt-oss:20b-cloud");
    expect(getCodexAssistReasoningEffort()).toBe("low");
  });

  it("escapes reasoning effort as a TOML string", () => {
    process.env.BRIDGE_CODEX_ASSIST_REASONING_EFFORT = 'low"custom';

    expect(getCodexAssistReasoningConfig()).toBe(
      'model_reasoning_effort="low\\"custom"',
    );
  });
});

function restoreEnvVar(key: string, value: string | undefined): void {
  if (value === undefined) {
    delete process.env[key];
    return;
  }
  process.env[key] = value;
}
