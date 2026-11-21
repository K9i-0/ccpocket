import { WebSocket } from "ws";
import type { ClientMessage } from "../../parser.js";
import { normalizePushLocale } from "../../push-i18n.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  beginPushTokenOperation,
  enqueuePushTokenOperation,
  isCurrentPushTokenOperation,
} from "../push-notifications.js";

export async function handlePushRegister(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "push_register" }>,
  ws: WebSocket,
): Promise<void> {
  const locale = normalizePushLocale(msg.locale);
  const privacyMode = msg.privacyMode === true;
  const supportsRegistrationResult =
    server.clientSupportedServerMessages
      .get(ws)
      ?.has("push_registration_result") ?? false;
  console.log(
    `[ws] push_register received (platform: ${msg.platform}, locale: ${locale}, privacy: ${privacyMode}, configured: ${server.pushRelay.isConfigured})`,
  );
  const generation = beginPushTokenOperation(server, msg.token);
  if (!server.pushRelay.isConfigured) {
    const error = "Push relay is not configured on bridge";
    server.send(
      ws,
      supportsRegistrationResult
        ? {
            type: "push_registration_result",
            token: msg.token,
            requestId: msg.requestId ?? "",
            success: false,
            error,
          }
        : { type: "error", message: error },
    );
    return;
  }
  const operation = enqueuePushTokenOperation(server, msg.token, () =>
    server.pushRelay.registerToken(msg.token, msg.platform, locale),
  );
  operation
    .then(() => {
      if (!isCurrentPushTokenOperation(server, msg.token, generation)) return;
      console.log("[ws] push_register: token registered successfully");
      if (supportsRegistrationResult) {
        server.send(ws, {
          type: "push_registration_result",
          token: msg.token,
          requestId: msg.requestId ?? "",
          success: true,
        });
      }
      // Enable delivery only after the acknowledgement has been queued
      // on the WebSocket, keeping the app on local fallback until then.
      server.tokenLocales.set(msg.token, locale);
      server.tokenPrivacyMode.set(msg.token, privacyMode);
    })
    .catch((err) => {
      if (!isCurrentPushTokenOperation(server, msg.token, generation)) return;
      const detail = err instanceof Error ? err.message : String(err);
      console.error(`[ws] push_register failed: ${detail}`);
      const error = `Failed to register push token: ${detail}`;
      server.send(
        ws,
        supportsRegistrationResult
          ? {
              type: "push_registration_result",
              token: msg.token,
              requestId: msg.requestId ?? "",
              success: false,
              error,
            }
          : { type: "error", message: error },
      );
    });
}

export async function handlePushUnregister(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "push_unregister" }>,
  ws: WebSocket,
): Promise<void> {
  console.log("[ws] push_unregister received");
  const generation = beginPushTokenOperation(server, msg.token);
  if (!server.pushRelay.isConfigured) {
    server.send(ws, {
      type: "error",
      message: "Push relay is not configured on bridge",
    });
    return;
  }
  enqueuePushTokenOperation(server, msg.token, () =>
    server.pushRelay.unregisterToken(msg.token),
  )
    .then(() => {
      if (!isCurrentPushTokenOperation(server, msg.token, generation)) return;
      console.log(
        "[ws] push_unregister: token unregistered successfully",
      );
    })
    .catch((err) => {
      if (!isCurrentPushTokenOperation(server, msg.token, generation)) return;
      const detail = err instanceof Error ? err.message : String(err);
      console.error(`[ws] push_unregister failed: ${detail}`);
      server.send(ws, {
        type: "error",
        message: `Failed to unregister push token: ${detail}`,
      });
    });
}
