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

- Close code `4001` records a `BridgeAuthRejection` (host and port) on
  `BridgeService`, exposed through `BridgeAuthRejectionCubit`. The connection
  state stays `disconnected` rather than gaining a new enum value, because many
  widgets treat "anything but disconnected" as connected. The service stops
  reconnecting, and `ensureConnected()` on foreground resume does not restart
  the loop. A new `connect()` (QR rescan, machine tap, manual entry) or
  `disconnect()` clears the rejection.
- The connect screen shows an "authentication required" card with the
  command `npx --yes @ccpocket/bridge@1 qr`, a Scan QR button (mobile only),
  and an Enter API key button that opens the matching machine's edit sheet. Rescanning updates the
  existing machine's stored key, because `recordConnection` matches the
  machine by host and port.
- HTTP calls that will become authenticated (gallery upload and delete) send
  `Authorization: Bearer <key>` when a key is known. A `?token=` query cannot
  be used: older Bridges match these routes on the raw `req.url`
  (`/api/gallery/upload` by equality, `/api/gallery/:id` with an anchored
  regex), so an added query string turns them into 404s. Native clients work
  against every Bridge because unknown headers are ignored. Known gap: Flutter
  Web against a Bridge older than Step 2 fails the CORS preflight for these two
  calls, because `Authorization` is only allowed from Step 2 on.
- When `/health` reports `auth: "required"` and the machine has no stored
  key, the machine entry shows that a QR rescan is needed.

### Step 2: Bridge release (additive, ship before or together with app N)

The card in app N tells users to run `ccpocket-bridge qr`, so this release
should be on npm by the time app N reaches users.

Nothing is rejected that was previously accepted.

- `/health` includes `auth: "required" | "none"`, with the same meaning as the
  mDNS TXT `auth` field.
- The token comparison uses `crypto.timingSafeEqual`.
- `Access-Control-Allow-Headers` includes `Authorization`.
- `GET /pairing` returns pairing information (connection URLs, deep link and
  token). It requires the per-start secret the Bridge writes to
  `~/.ccpocket/pairing-secret-<port>` (mode `0600`), sent in the
  `X-CCPocket-Pairing-Secret` header, so other local users on shared hosts
  cannot read the key. It is also served only to loopback clients. The request must come from a
  loopback address, carry a loopback `Host` header (to block DNS rebinding)
  and have no `Origin` header (so web pages cannot use it). The response has
  no CORS headers. The future desktop app can reuse this endpoint to show
  "this Mac's" QR.
- `ccpocket-bridge qr [--port <port>]` fetches `/pairing` from the running
  Bridge and prints the QR code. This lets launchd/systemd users re-pair.
- Starting without a key prints a warning that a key will become required.

### Step 3: Bridge release (enforcement, after app N has been out)

Gate: start only after app N has passed App Store and Google Play review and
is publicly available on both stores. App 1.160.0+301 (app N) became public
on both stores on 2026-11-09, and Step 3 was implemented then.

- Key resolution: `BRIDGE_API_KEY` / `--api-key` wins. Otherwise the key in
  `~/.ccpocket/bridge-api-key` (mode `0600`) is reused, or a random key is
  generated and stored there (written with `O_EXCL`, so concurrent first
  starts converge on one key). This covers plain `npx` users as well as
  `setup` users; `setup` does not need to embed a key in the service file.
- `--insecure-no-auth` / `BRIDGE_INSECURE_NO_AUTH=1` opts out explicitly, and
  `setup` persists it.
- `/usage`, `/doctor`, `POST /api/gallery/upload` and `DELETE /api/gallery/:id`
  require `Authorization: Bearer <key>` and answer `401` otherwise.
  `/health` and `/version` stay public; app probing and update checks depend
  on them. Image, media and upload-store URLs remain capability URLs.
- The token-bearing QR code is printed at startup only when stdout is a TTY.
  Background services log to files other local users may read, so they print
  a pointer to `ccpocket-bridge qr` instead. `setup` prints the same pointer.
- The startup banner and `ccpocket-bridge qr` print one QR code per route
  (Public, LAN, Tailscale; the first address of each), so a phone can pair
  over Tailscale as well as the local network. Link-local `169.254.x.x`
  addresses are no longer listed. `/pairing` returns a deep link per
  connection.
- `ccpocket-bridge qr` also prints the API key on its own line, because the
  desktop apps cannot scan QR codes and take the key in the machine editor.
- Ships in `1.x`. `setup` pins `@ccpocket/bridge@1`, so background services
  pick it up on their next restart; app N's re-pairing card guides users.

## Clients on older app versions

App versions before N keep reconnecting silently after the enforcement
release. The Bridge cannot fix that on its own. Mitigations: release notes,
the startup log, and the delay between app N and Step 3.

## Out of scope

- WebSocket `Origin` allowlisting. Once a key is required, it adds little, and
  a default allowlist risks breaking self-hosted Flutter Web clients.
- Transport encryption on LAN. Until pairing-based encryption exists, the docs
  recommend Tailscale or `wss://`.
