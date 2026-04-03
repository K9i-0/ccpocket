import React, { useState, useEffect } from "react";
import { Box, Text, useInput } from "ink";
import type { BridgeClient } from "../bridge-client.js";

interface Session {
  id: string;
  provider: string;
  projectPath: string;
  name?: string;
  status: string;
  lastActivityAt: string;
  lastMessage: string;
}

interface HomeScreenProps {
  client: BridgeClient;
  onAttach: (sessionId: string) => void;
  onNew: () => void;
  onQuit: () => void;
}

export function HomeScreen({ client, onAttach, onNew, onQuit }: HomeScreenProps) {
  const [sessions, setSessions] = useState<Session[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);

  useEffect(() => {
    const handler = (msg: Record<string, unknown>) => {
      if (msg.type === "session_list" && Array.isArray(msg.sessions)) {
        setSessions(msg.sessions as Session[]);
      }
    };
    client.on("message", handler);
    client.send({ type: "list_sessions" });
    return () => {
      client.off("message", handler);
    };
  }, [client]);

  useInput((input, key) => {
    if (input === "q") {
      onQuit();
      return;
    }
    if (input === "n") {
      onNew();
      return;
    }
    if (input === "a" || key.return) {
      if (sessions[selectedIndex]) {
        onAttach(sessions[selectedIndex].id);
      }
      return;
    }
    if (key.upArrow) {
      setSelectedIndex((i) => Math.max(0, i - 1));
    }
    if (key.downArrow) {
      setSelectedIndex((i) => Math.min(sessions.length - 1, i + 1));
    }
  });

  return (
    <Box flexDirection="column" padding={1}>
      <Text bold>CC Pocket — Sessions</Text>
      <Text dimColor>{""}</Text>
      {sessions.length === 0 ? (
        <Text dimColor>  No active sessions. Press [n] to start one.</Text>
      ) : (
        sessions.map((s, i) => {
          const selected = i === selectedIndex;
          const icon = s.status === "idle" ? "○" : "●";
          const name = s.name ?? s.projectPath.split("/").pop() ?? s.projectPath;
          const age = formatAge(s.lastActivityAt);
          const provider = s.provider === "codex" ? "Codex" : "Claude";
          return (
            <Text key={s.id}>
              {selected ? "❯ " : "  "}
              {icon} {name} ({provider}, {age})
              {s.lastMessage ? ` — ${s.lastMessage.slice(0, 50)}` : ""}
            </Text>
          );
        })
      )}
      <Text dimColor>{""}</Text>
      <Text dimColor>  [a]ttach  [n]ew  [q]uit</Text>
    </Box>
  );
}

function formatAge(isoDate: string): string {
  const diff = Date.now() - new Date(isoDate).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}
