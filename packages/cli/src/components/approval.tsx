import React from "react";
import { Box, Text, useInput } from "ink";

interface ApprovalProps {
  toolName: string;
  input: Record<string, unknown>;
  onApprove: () => void;
  onReject: () => void;
  onApproveAlways: () => void;
}

export function ApprovalPrompt({ toolName, input, onApprove, onReject, onApproveAlways }: ApprovalProps) {
  useInput((char) => {
    switch (char.toLowerCase()) {
      case "y":
        onApprove();
        break;
      case "n":
        onReject();
        break;
      case "a":
        onApproveAlways();
        break;
    }
  });

  const path = input.file_path ?? input.command ?? "";

  return (
    <Box flexDirection="column">
      <Text>
        <Text color="yellow" bold>Allow?</Text>{" "}
        <Text bold>{toolName}</Text>{path ? ` ${String(path)}` : ""}
      </Text>
      <Text dimColor>  [y]es  [n]o  [a]lways</Text>
    </Box>
  );
}
