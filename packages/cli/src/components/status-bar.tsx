import React from "react";
import { Box, Text } from "ink";

interface StatusBarProps {
  sessionId: string;
  provider: string;
  projectPath: string;
  clients: Array<{ clientId: string; clientType: string }>;
}

export function StatusBar({ provider, projectPath, clients }: StatusBarProps) {
  const otherClients = clients.filter((c) => c.clientType !== "cli");
  const alsoOn = otherClients.length > 0
    ? ` also on: ${otherClients.map((c) => c.clientType).join(", ")}`
    : "";
  const project = projectPath.split("/").pop() ?? projectPath;
  const providerLabel = provider === "codex" ? "Codex" : "Claude";

  return (
    <Box>
      <Text dimColor>
        ── Attached to {project} ({providerLabel}) ──{alsoOn ? ` ${alsoOn}` : ""} ──
      </Text>
    </Box>
  );
}
