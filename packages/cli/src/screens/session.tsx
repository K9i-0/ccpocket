import React, { useState, useEffect, useCallback } from "react";
import { Box, Text, useInput, useApp } from "ink";
import TextInput from "ink-text-input";
import type { BridgeClient } from "../bridge-client.js";
import { renderMessage } from "../renderer.js";
import { StatusBar } from "../components/status-bar.js";
import { ApprovalPrompt } from "../components/approval.js";

interface SessionScreenProps {
  client: BridgeClient;
  sessionId: string;
  onDetach: () => void;
}

interface PendingApproval {
  toolUseId: string;
  toolName: string;
  input: Record<string, unknown>;
}

interface ClientInfo {
  clientId: string;
  clientType: string;
}

export function SessionScreen({ client, sessionId, onDetach }: SessionScreenProps) {
  const [output, setOutput] = useState<string[]>([]);
  const [streamBuffer, setStreamBuffer] = useState("");
  const [inputValue, setInputValue] = useState("");
  const [status, setStatus] = useState<string>("connecting");
  const [pendingApproval, setPendingApproval] = useState<PendingApproval | null>(null);
  const [clients, setClients] = useState<ClientInfo[]>([]);
  const [provider, setProvider] = useState("claude");
  const [projectPath, setProjectPath] = useState("");
  const { exit } = useApp();

  const appendOutput = useCallback((text: string) => {
    if (!text) return;
    setOutput((prev) => [...prev, text]);
  }, []);

  useEffect(() => {
    client.send({ type: "attach_session", sessionId, clientType: "cli" });

    const handler = (msg: Record<string, unknown>) => {
      if (msg.sessionId && msg.sessionId !== sessionId) return;

      switch (msg.type) {
        case "system":
          if (msg.subtype === "session_created") {
            setProvider(String(msg.provider ?? "claude"));
            setProjectPath(String(msg.projectPath ?? ""));
          }
          break;

        case "session_clients":
          setClients(msg.clients as ClientInfo[]);
          break;

        case "client_joined":
        case "client_left":
          break;

        case "status":
          setStatus(String(msg.status));
          break;

        case "stream_delta":
          setStreamBuffer((prev) => prev + String(msg.text ?? ""));
          break;

        case "permission_request":
          setStreamBuffer((prev) => {
            if (prev) appendOutput(prev);
            return "";
          });
          setPendingApproval({
            toolUseId: String(msg.toolUseId),
            toolName: String(msg.toolName),
            input: (msg.input as Record<string, unknown>) ?? {},
          });
          break;

        case "permission_resolved":
          setPendingApproval(null);
          break;

        case "assistant":
          setStreamBuffer((prev) => {
            if (prev) appendOutput(prev);
            return "";
          });
          appendOutput(renderMessage(msg));
          break;

        case "history":
          if (Array.isArray(msg.messages)) {
            for (const histMsg of msg.messages as Record<string, unknown>[]) {
              const rendered = renderMessage(histMsg);
              if (rendered) appendOutput(rendered);
            }
          }
          setStatus("connected");
          break;

        default:
          appendOutput(renderMessage(msg));
          break;
      }
    };

    client.on("message", handler);
    return () => {
      client.off("message", handler);
    };
  }, [client, sessionId, appendOutput]);

  useInput((_input, key) => {
    if (key.ctrl && _input === "d") {
      client.send({ type: "detach_session", sessionId });
      onDetach();
    }
  }, { isActive: !pendingApproval });

  const handleSubmitInput = (text: string) => {
    if (!text.trim()) return;
    setInputValue("");
    appendOutput(`\n> ${text}\n`);
    client.send({ type: "input", text, sessionId });
  };

  const handleApprove = () => {
    if (!pendingApproval) return;
    client.send({ type: "approve", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  const handleReject = () => {
    if (!pendingApproval) return;
    client.send({ type: "reject", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  const handleApproveAlways = () => {
    if (!pendingApproval) return;
    client.send({ type: "approve_always", id: pendingApproval.toolUseId, sessionId });
    setPendingApproval(null);
  };

  return (
    <Box flexDirection="column">
      <StatusBar
        sessionId={sessionId}
        provider={provider}
        projectPath={projectPath}
        clients={clients}
      />
      <Text>{""}</Text>

      {output.map((line, i) => (
        <Text key={i}>{line}</Text>
      ))}

      {streamBuffer && <Text>{streamBuffer}</Text>}

      {pendingApproval ? (
        <ApprovalPrompt
          toolName={pendingApproval.toolName}
          input={pendingApproval.input}
          onApprove={handleApprove}
          onReject={handleReject}
          onApproveAlways={handleApproveAlways}
        />
      ) : status === "idle" || status === "connected" ? (
        <Box>
          <Text bold color="blue">&gt; </Text>
          <TextInput
            value={inputValue}
            onChange={setInputValue}
            onSubmit={handleSubmitInput}
            placeholder="Type a message..."
          />
        </Box>
      ) : null}

      <Text dimColor>  Ctrl+D: detach</Text>
    </Box>
  );
}
