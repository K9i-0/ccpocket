import type { WebSocket } from "ws";
import type { ClientMessage } from "../../parser.js";
import type { BridgeWebSocketServer } from "../../websocket.js";

function pinsMessage(server: BridgeWebSocketServer): Record<string, unknown> {
  return { type: "pins", ...server.pinStore.snapshot() };
}

export async function handleGetPins(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_pins" }>,
  ws: WebSocket,
): Promise<void> {
  const adopted = msg.seed ? await server.pinStore.seed(msg.seed) : false;
  await server.pinStore.init();
  if (adopted) {
    console.log("[ws] Adopted a client's pins as the Bridge pins");
    server.broadcast(pinsMessage(server));
    return;
  }
  server.send(ws, pinsMessage(server));
}

/**
 * Every change is broadcast, also to the sender and also when nothing
 * changed, so that the sender's optimistic state is always confirmed.
 */
export async function handleSetSessionPin(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_session_pin" }>,
): Promise<void> {
  await server.pinStore.setSessionPin(
    {
      provider: msg.provider,
      sessionId: msg.sessionId,
      projectPath: msg.projectPath,
    },
    msg.pinned,
  );
  server.broadcast(pinsMessage(server));
}

export async function handleSetProjectPin(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_project_pin" }>,
): Promise<void> {
  await server.pinStore.setProjectPin(msg.projectPath, msg.pinned);
  server.broadcast(pinsMessage(server));
}
