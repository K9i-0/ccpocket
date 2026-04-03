import React, { useState } from "react";
import { Box, Text, useApp } from "ink";
import type { BridgeClient } from "./bridge-client.js";
import { HomeScreen } from "./screens/home.js";
import { NewSessionScreen } from "./screens/new-session.js";

type Screen =
  | { name: "home" }
  | { name: "new-session" };

interface AppProps {
  client: BridgeClient;
  initialScreen?: { name: "home" } | { name: "new-session" };
  onEnterRawSession: (sessionId: string) => void;
  onQuit?: () => void;
}

export function App({ client, initialScreen, onEnterRawSession, onQuit }: AppProps) {
  const [screen, setScreen] = useState<Screen>(initialScreen ?? { name: "home" });
  const { exit } = useApp();

  switch (screen.name) {
    case "home":
      return (
        <HomeScreen
          client={client}
          onAttach={(sessionId) => onEnterRawSession(sessionId)}
          onNew={() => setScreen({ name: "new-session" })}
          onQuit={() => { exit(); onQuit?.(); }}
        />
      );
    case "new-session":
      return (
        <NewSessionScreen
          client={client}
          onCreated={(sessionId) => onEnterRawSession(sessionId)}
          onCancel={() => setScreen({ name: "home" })}
        />
      );
  }
}
