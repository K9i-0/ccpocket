export const DEFAULT_CODEX_ASSIST_MODEL = "gpt-5.4-mini";
export const DEFAULT_CODEX_ASSIST_REASONING_EFFORT = "none";

function readNonEmptyEnv(name: string): string | undefined {
  const value = process.env[name]?.trim();
  return value || undefined;
}

export function getCodexAssistModel(): string {
  return (
    readNonEmptyEnv("BRIDGE_CODEX_ASSIST_MODEL") ??
    DEFAULT_CODEX_ASSIST_MODEL
  );
}

export function getCodexAssistReasoningEffort(): string {
  return (
    readNonEmptyEnv("BRIDGE_CODEX_ASSIST_REASONING_EFFORT") ??
    DEFAULT_CODEX_ASSIST_REASONING_EFFORT
  );
}

export function getCodexAssistReasoningConfig(): string {
  return `model_reasoning_effort=${JSON.stringify(getCodexAssistReasoningEffort())}`;
}
