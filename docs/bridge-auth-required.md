# Bridge authentication required by default

## Problem

The Bridge listens on `0.0.0.0:8765` by default and only authenticates
WebSocket clients when `BRIDGE_API_KEY` is set. On a shared network (café
Wi-Fi, conference LAN) anyone who can reach the port can start sessions, read
files and approve tool calls, which amounts to remote command execution on the
host. Without a key, a web page open in the user's browser can also try
`ws://127.0.0.1:8765`, because WebSocket connections are not subject to the
same-origin policy.

Additional gaps found during review:

- `/usage`, `/doctor`, `POST /api/gallery/upload` and `DELETE /api/gallery/:id`
  do not check the key even when one is configured.
- The token comparison is not constant time.
- Headless (launchd/systemd) users have no way to print the pairing QR again,
  because the startup output goes to a log file.
- The app treats close code `4001 Unauthorized` like any other drop and
  reconnects forever, so a rejected client only ever shows "Reconnecting…".

## Goal

Make the API key required by default without silently stranding users. When
the Bridge starts requiring a key, the app must say so and offer to rescan the
QR code.

## Rollout

All breaking behavior ships together in a single Bridge release, and only
after an app release that understands it has been available for a while.

### Step 1: App release N (ships first)

Backward compatible with every existing Bridge.

- Close code `4001` puts `BridgeService` into a new
  `BridgeConnectionState.unauthorized`. The service stops reconnecting, and
  `ensureConnected()` on foreground resume does not restart the loop. Only a
  new `connect()` (QR rescan, machine tap, manual entry) leaves the state.
- The home screen shows an "authentication required" banner with a Scan QR
  button and the hint `npx @ccpocket/bridge@1 qr`. Rescanning updates the
  existing machine's stored key, because `recordConnection` matches the
  machine by host and port.
- HTTP calls that will become authenticated (gallery upload and delete) add
  `?token=<key>` when a key is known. A query parameter is used instead of an
  `Authorization` header so Flutter Web does not trigger a CORS preflight that
  older Bridges, which only allow `Content-Type, Content-Length, Range`, would
  reject. Older Bridges ignore the parameter.
- When `/health` reports `auth: "required"` and the machine has no stored
  key, the machine entry shows that a QR rescan is needed.

### Step 2: Bridge release (additive, can ship any time)

Nothing is rejected that was previously accepted.

- `/health` includes `auth: "required" | "none"`, with the same meaning as the
  mDNS TXT `auth` field.
- The token comparison uses `crypto.timingSafeEqual`.
- `GET /pairing` returns pairing information (connection URLs, deep link and
  token) and is served only to loopback clients. The request must come from a
  loopback address, carry a loopback `Host` header (to block DNS rebinding)
  and have no `Origin` header (so web pages cannot use it). The response has
  no CORS headers. The future desktop app can reuse this endpoint to show
  "this Mac's" QR.
- `ccpocket-bridge qr [--port <port>]` fetches `/pairing` from the running
  Bridge and prints the QR code. This lets launchd/systemd users re-pair.
- Starting without a key prints a warning that a key will become required.

### Step 3: Bridge release (enforcement, after app N has been out)

- When `BRIDGE_API_KEY` is not set, the Bridge generates a random key,
  persists it to `~/.ccpocket/` with mode `0600`, and reuses it on later
  starts. This covers plain `npx` users as well as `setup` users.
- `--insecure-no-auth` (or `BRIDGE_INSECURE_NO_AUTH=1`) opts out explicitly.
- `/usage`, `/doctor`, `POST /api/gallery/upload` and `DELETE /api/gallery/:id`
  require the token. `/health` and `/version` stay public; app probing and
  update checks depend on them. Image, media and upload-store URLs remain
  capability URLs (unguessable IDs or short-lived tokens).
- Open question: ship this in `1.x` or `2.x`. `setup` pins
  `@ccpocket/bridge@1`, so a `1.x` release reaches launchd users on their next
  restart, while `2.x` never reaches pinned installs.

## Clients on older app versions

App versions before N keep reconnecting silently after the enforcement
release. The Bridge cannot fix that on its own. Mitigations: release notes,
the startup log, and the delay between app N and Step 3.

## Out of scope

- WebSocket `Origin` allowlisting. Once a key is required, it adds little, and
  a default allowlist risks breaking self-hosted Flutter Web clients.
- Transport encryption on LAN. Until pairing-based encryption exists, the docs
  recommend Tailscale or `wss://`.
