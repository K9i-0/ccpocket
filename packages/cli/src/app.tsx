import React, { useState } from "react";
import { Box, Text, useApp } from "ink";
import type { BridgeClient } from "./bridge-client.js";
import { HomeScreen } from "./screens/home.js";
import { SessionScreen } from "./screens/session.js";
import { NewSessionScreen } from "./screens/new-session.js";

type Screen =
  | { name: "home" }
  | { name: "session"; sessionId: string }
  | { name: "new-session" };

interface AppProps {
  client: BridgeClient;
  initialScreen?: Screen;
}

export function App({ client, initialScreen }: AppProps) {
  const [screen, setScreen] = useState<Screen>(initialScreen ?? { name: "home" });
  const { exit } = useApp();

  switch (screen.name) {
    case "home":
      return (
        <HomeScreen
          client={client}
          onAttach={(sessionId) => setScreen({ name: "session", sessionId })}
          onNew={() => setScreen({ name: "new-session" })}
          onQuit={() => exit()}
        />
      );
    case "session":
      return (
        <SessionScreen
          client={client}
          sessionId={screen.sessionId}
          onDetach={() => setScreen({ name: "home" })}
        />
      );
    case "new-session":
      return (
        <NewSessionScreen
          client={client}
          onCreated={(sessionId) => setScreen({ name: "session", sessionId })}
          onCancel={() => setScreen({ name: "home" })}
        />
      );
  }
}
