import React, { useState } from "react";
import { Box, Text, useInput } from "ink";
import TextInput from "ink-text-input";
import type { BridgeClient } from "../bridge-client.js";
import { loadConfig } from "../config.js";

interface NewSessionScreenProps {
  client: BridgeClient;
  onCreated: (sessionId: string) => void;
  onCancel: () => void;
}

type Step = "path" | "provider" | "starting";

export function NewSessionScreen({ client, onCreated, onCancel }: NewSessionScreenProps) {
  const config = loadConfig();
  const [step, setStep] = useState<Step>("path");
  const [projectPath, setProjectPath] = useState("");
  const [provider, setProvider] = useState<"claude" | "codex">(config.defaultProvider);

  useInput((input, key) => {
    if (key.escape) {
      onCancel();
      return;
    }
  });

  React.useEffect(() => {
    const handler = (msg: Record<string, unknown>) => {
      if (msg.type === "system" && msg.subtype === "session_created" && msg.sessionId) {
        onCreated(msg.sessionId as string);
      }
      if (msg.type === "error") {
        setStep("path");
      }
    };
    client.on("message", handler);
    return () => {
      client.off("message", handler);
    };
  }, [client, onCreated]);

  const handleSubmitPath = (value: string) => {
    const resolved = value.startsWith("~")
      ? value.replace("~", process.env.HOME ?? "")
      : value;
    setProjectPath(resolved);
    setStep("provider");
  };

  const handleSubmitProvider = () => {
    setStep("starting");
    client.send({
      type: "start",
      projectPath,
      provider,
    });
  };

  return (
    <Box flexDirection="column" padding={1}>
      <Text bold>New Session</Text>
      <Text dimColor>Press Escape to cancel</Text>
      <Text>{""}</Text>

      {step === "path" && (
        <Box>
          <Text>Project path: </Text>
          <TextInput
            value={projectPath}
            onChange={setProjectPath}
            onSubmit={handleSubmitPath}
            placeholder="~/GitHub/my-project"
          />
        </Box>
      )}

      {step === "provider" && (
        <Box flexDirection="column">
          <Text dimColor>Project: {projectPath}</Text>
          <Box>
            <Text>Provider [{provider === "claude" ? "Claude" : "Codex"}]: </Text>
            <ProviderToggle value={provider} onChange={setProvider} onSubmit={handleSubmitProvider} />
          </Box>
        </Box>
      )}

      {step === "starting" && (
        <Text dimColor>Starting {provider} session for {projectPath}...</Text>
      )}
    </Box>
  );
}

function ProviderToggle({
  value,
  onChange,
  onSubmit,
}: {
  value: "claude" | "codex";
  onChange: (v: "claude" | "codex") => void;
  onSubmit: () => void;
}) {
  useInput((input, key) => {
    if (key.return) {
      onSubmit();
      return;
    }
    if (key.leftArrow || key.rightArrow || input === "c") {
      onChange(value === "claude" ? "codex" : "claude");
    }
  });

  return (
    <Text>
      {value === "claude" ? "▸ Claude  Codex" : "  Claude  ▸ Codex"}
    </Text>
  );
}
