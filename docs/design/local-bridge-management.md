# Local Bridge management

The macOS app can start and manage a Bridge on the same Mac. The Bridge keeps
working standalone (`npx @ccpocket/bridge@1`, `setup`, environment variables).

Status (2026-11-23):

- Done: Bridge side (config file, `/admin/*`, `/tools`); the macOS management
  screen (Settings > Connection > "Bridge on this Mac") for a Bridge that is
  already running: status, restart, pairing QR, tools checklist, settings,
  logs.
- Not done: starting/stopping the Bridge from the app (launcher +
  `SMAppService`), automatic registration of "this Mac" as a machine, the
  setup guide, the tools checklist for remote hosts on mobile.

## Constraints

- The macOS app is sandboxed (`app-sandbox`) and shipped with Developer ID +
  Sparkle. A process the app spawns inherits the sandbox, so it cannot run
  `claude` / `codex` / `agy` against arbitrary project directories, and the
  app cannot write `~/Library/LaunchAgents` or read `~/.ccpocket`.
  Verified with a signed test bundle (2026-11-23): a spawned `zsh` got
  `Operation not permitted` on `~/.ccpocket`; a
  `temporary-exception.files.home-relative-path.read-only` entitlement made
  exactly that directory readable (and nothing else, and not writable).
- Phones connect to this Bridge, so it must outlive the app window.
- Bridge releases stay independent of app releases.

## Architecture

```
CC Pocket.app (sandboxed)
 ├─ Flutter: LocalBridgeController ── MethodChannel ── Swift: SMAppService
 ├─ Contents/Library/LaunchAgents/<label>.plist      (bundled agent definition)
 └─ Contents/MacOS/bridge-launcher (not sandboxed)
        └─ zsh -li -c "exec npx --yes @ccpocket/bridge@1"   (user's Node)

app ⇄ Bridge: http://127.0.0.1:<port>/admin/*  (loopback + pairing secret)
```

- **Process owner: launchd.** The app registers a bundled LaunchAgent with
  `SMAppService.agent`. launchd starts the launcher, so nothing inherits the
  app sandbox. Start = register, stop = unregister, "launch at login" is the
  same registration. Quitting the app does not stop the Bridge.
  *Still to verify on a signed build: registration from the sandboxed app.*
  Fallback if it does not hold: drop the sandbox (needs app-data migration
  from the container).
- **Runtime: the user's Node** through a login shell, like `setup-launchd.ts`.
  The launcher sets `CCPOCKET_BRIDGE_SUPERVISED=1` and reports a missing or
  old Node in a status file under `~/.ccpocket/` (the Bridge cannot report
  that itself).
- **Existing Bridges are adopted.** If a Bridge already answers on the port
  (the `com.ccpocket.bridge` service from `setup`, or a manual `npx`), the app
  manages it through the same API and only disables start/stop.

## Settings

`~/.ccpocket/bridge-config.json` (`BRIDGE_CONFIG_FILE` overrides the path).

- Precedence: CLI flag > environment variable > config file > default.
- Implementation: at startup `applyBridgeConfig` fills the environment
  variables that are unset, so every existing reader of `process.env` is
  unchanged. The source of each value (`env` / `file` / `default`) is captured
  at that moment; the UI locks settings whose source is `env`.
- All settings apply on restart. `restartRequired` is true when the saved file
  differs from what the running Bridge loaded (ignoring env-overridden keys).
- `antigravityApiKey` lives in the same `0600` file and is never returned by
  the API (`configured` / `fileConfigured` booleans only). The Bridge API key
  stays in `~/.ccpocket/bridge-api-key`.

## Local management API

HTTP on the Bridge port, guarded exactly like `/pairing`: loopback peer,
loopback `Host`, no `Origin`, and the `x-ccpocket-pairing-secret` header.
The API key is deliberately **not** accepted: a paired phone must not be able
to widen `allowedDirs` or turn authentication off.

| Endpoint | Purpose |
|---|---|
| `GET /admin/status` | version, port, pid, `supervised`, `apiKeySource`, `restartRequired`, session/client counts, `adminApiVersion` |
| `GET /admin/config` | every setting: running value, source, saved file value |
| `PUT /admin/config` | `{settings: {key: value \| null}}`; validated as a whole, `null` removes |
| `POST /admin/restart` | exit so the supervisor restarts; `409 not_supervised` otherwise |
| `POST /admin/api-key/rotate` | replace the stored key (applies on restart); `409` when the key comes from env/flag or auth is off |
| `GET /admin/logs?limit=` | recent console output from an in-memory ring buffer |

`GET /tools` uses the normal API key (like `/doctor`), so a phone can show the
same install checklist for a remote host. Install commands come from the
Bridge per platform; user-facing texts are localized in the app by tool id.

## App side

`apps/mobile/lib/features/local_bridge/`: `LocalBridgeClient` (HTTP to
`127.0.0.1`), `LocalBridgeCubit`, `LocalBridgeScreen`.

- The app reads `~/.ccpocket/pairing-secret-<port>` through the
  `temporary-exception.files.home-relative-path.read-only` entitlement for
  `/.ccpocket/`. `HOME` is the sandbox container, so the real home is derived
  from it (`realHomeDirectory`). The app never writes there: settings go
  through `PUT /admin/config`.
- Edits are staged and saved together; the screen then offers "restart to
  apply". Restart waits until a different pid answers.
- The pairing QR code carries the API key and is hidden until requested.
- Port: 8765 by default; another port can be chosen from the menu.
- Verified on a sandboxed, Developer ID signed debug build against a test
  Bridge (save -> restart -> setting applied) and against Bridge 1.119.0,
  which shows the "update the Bridge" state.

## Known gaps before the launcher ships

- A saved `host` or `port` that cannot be bound makes a supervised Bridge
  exit on every start, and the app then has no API to repair the file. The
  launcher must detect repeated start failures and start once with the file
  ignored (or the Bridge must fall back to defaults) before the app owns the
  process.
- `/tools` runs CLIs synchronously and blocks the Bridge while it does. It is
  cached for 30 seconds (`?refresh=1` bypasses); making the checks
  asynchronous is still open.
- The tools checklist needs a running Bridge, so a Mac without Node gets no
  checklist yet. The launcher has to report a missing or old Node itself.
- `MACOSX_DEPLOYMENT_TARGET` is 12.0; `SMAppService` needs 13.

## Compatibility

- No WebSocket message and no protocol version change.
- An older Bridge answers `/admin/*` and `/tools` with `404`. The management
  screen and the tools checklist show "update the Bridge" themselves.
- `adminApiVersion` (currently `1`) lets the app detect later additions.
- `ccpocket-bridge setup` still bakes settings into the service definition as
  environment variables; those win over the file and show as locked.
