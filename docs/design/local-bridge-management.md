# Local Bridge management

The macOS app can start and manage a Bridge on the same Mac. The Bridge keeps
working standalone (`npx @ccpocket/bridge@1`, `setup`, environment variables).

Status (2026-11-26):

- Done: Bridge side (config file, `/admin/*`, `/tools`, safe mode); the macOS
  management screen (Settings > Connection > "Bridge on this Mac"): start and
  stop, status, restart, pairing QR, connect this app, tools checklist,
  settings, logs, macOS permissions; the macOS setup guide.
- Verified by tests and on a hand-signed sandboxed build: everything except
  the last step of "start" (registering the agent from the real app) and
  "stop", which register a login item and were left to a manual check.
- Not done: the tools checklist for remote hosts on mobile; asynchronous tool
  checks.

## Constraints

- The macOS app is sandboxed (`app-sandbox`) and shipped with Developer ID +
  Sparkle. A process the app spawns inherits the sandbox, so it cannot run
  `claude` / `codex` / `agy` against arbitrary project directories, and the
  app cannot write `~/Library/LaunchAgents` or read `~/.ccpocket`.
- Phones connect to this Bridge, so it must outlive the app window.
- Bridge releases stay independent of app releases.

Verified with signed test bundles on 2026-11-23:

| Question | Result |
|---|---|
| Does a process spawned by the sandboxed app leave the sandbox? | No: `Operation not permitted` on `~/.ccpocket` |
| Can the sandboxed app read `~/.ccpocket` with a `temporary-exception.files.home-relative-path.read-only` entitlement? | Yes, exactly that directory, read-only |
| Can the sandboxed app register a LaunchAgent with `SMAppService.agent`? | No: `SMAppServiceErrorDomain Code=1 "Operation not permitted"` |
| Can a non-sandboxed app do it? | Yes; its agent sees the login-shell `node` / `claude` / `agy` and can write to project folders |
| Can the sandboxed app open a bundled non-sandboxed helper app that registers the agent? | Yes |

## Architecture

```
CC Pocket.app (sandboxed)
 ├─ Flutter: LocalBridgeLauncher ── MethodChannel ── Runner/LocalBridgeHelper.swift
 │                                                     │ request.json in the app container
 │                                                     ▼ NSWorkspace.openApplication
 └─ Contents/Helpers/CC Pocket Bridge.app (not sandboxed, LSUIElement)
      ├─ Contents/MacOS/CC Pocket Bridge     helper: SMAppService register / unregister / status
      ├─ Contents/Library/LaunchAgents/com.k9i.ccpocket.bridge-agent.plist
      └─ Contents/MacOS/bridge-launcher      agent program (launchd: RunAtLoad, KeepAlive)
             └─ zsh -lic "exec npx --yes @ccpocket/bridge@1"   (user's Node)

app ⇄ Bridge: http://127.0.0.1:<port>/admin/*  (loopback + pairing secret)
```

Sources: `apps/mobile/macos/BridgeHelper/` (built by the "Build Bridge Helper"
phase of the Runner target, re-signed by `macos-release.yml`).

- **Process owner: launchd.** Start = register the agent, stop = unregister.
  Registering also makes it start at login. Quitting the app does not stop
  the Bridge. The item appears in System Settings > Login Items as
  "CC Pocket Bridge"; if the user turns it off there the app shows how to
  allow it again.
- **Helper request.** The helper has no URL scheme and takes no arguments, so
  nothing outside the main app can drive it: it reads
  `<app container>/Library/Application Support/local-bridge-helper/request.json`
  (`{id, action, createdAt}`, ignored when older than 30 seconds), acts, and
  writes `~/.ccpocket/launcher-helper.json`, which the main app polls for the
  matching `id`.
- **Launcher** (`Launcher.swift`), before replacing itself with the Bridge:
  - stops if another Bridge already answers on the configured port
    (`port_in_use`), so it never fights the `setup` service or a manual run;
  - checks `node -v` through the login shell (`node_missing`,
    `node_too_old`); the agent retries about every 30 seconds, so installing
    Node is enough to continue;
  - after 4 starts within 45 seconds sets `CCPOCKET_BRIDGE_SAFE_MODE=1`: the
    Bridge ignores the saved settings and reports `safeMode`, so settings that
    prevent startup (unbindable host or port) can be fixed from the app;
  - sets `CCPOCKET_BRIDGE_SUPERVISED=1` and writes Bridge output to
    `~/.ccpocket/logs/bridge.log`.
  It reports its state in `~/.ccpocket/launcher-status.json`.
- **Runtime: the user's Node** through a login shell, like `setup-launchd.ts`.
- **Existing Bridges are adopted.** If a Bridge already answers on the port
  (the `com.ccpocket.bridge` service from `setup`, or a manual `npx`), the app
  manages it through the same API and offers neither start nor stop.
- **macOS 12** has no `SMAppService`: the helper needs macOS 13, and the app
  hides the start button where the helper is unavailable.

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

## macOS permissions

The management screen lists the permissions of the Bridge the app runs, with
their state and a button to the System Settings page
(`LocalBridgePermissionsCard`). It moves to the top while something that
matters is missing, and a dialog with the same list appears once after the
Bridge is started from the app while Full Disk Access is missing.

| Permission | Importance | State from |
|---|---|---|
| Login item (background run) | required | `SMAppService` status (`requiresApproval` = turned off) |
| Full Disk Access | recommended | helper: opening a protected path |
| Screen Recording (`screenshot.ts`) | optional | helper: `CGPreflightScreenCaptureAccess` |
| Local Network | optional | none: macOS has no query; only the link |

Measured on macOS 27.2 (2026-11-26) with a signed test bundle and the TCC log
(`/usr/bin/log stream --info --debug --predicate 'subsystem == "com.apple.TCC"'`):

- TCC attributes the agent's processes to the **outermost app bundle** that
  contains the agent program (`BUNDLE_ATTRIBUTION: ... resolves to attributed
  bundle`). For the helper nested in `CC Pocket.app/Contents/Helpers/` the
  subject is `com.k9i.ccpocket`: Privacy & Security lists the Bridge as
  "CC Pocket", not as "CC Pocket Bridge", `bridge-launcher` or `node`.
- This is the same whether the launcher `execv`s into the Bridge or spawns it,
  and whether the agent program is the bundle's main executable or not. The
  responsible process stays the launcher after `execv`.
- The helper app is attributed the same way, so it answers for the Bridge:
  its `status` result carries `permissions: {fullDiskAccess?, screenCapture}`.
  Seen in the log for both services: the helper's requests have
  `Sub:{com.k9i.ccpocket}`, and its answer for Full Disk Access matched the
  TCC record. The sandboxed main app cannot check this itself. The failed
  read also makes "CC Pocket" appear in the Full Disk Access list.
- `~/Library/Application Support/com.apple.TCC/TCC.db` does not exist on
  macOS 27; the helper tries the system `TCC.db`, `~/Library/Safari` and
  `~/Library/Mail` and reports nothing when none of them tells.
- Opening the pages from the sandboxed app works: Login Items through
  `SMAppService.openSystemSettingsLoginItems()`, the others through
  `NSWorkspace.open` of
  `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`
  and `?Privacy_ScreenCapture`.
- The helper reads one request file, so the app sends it one request at a
  time (`HelperLocalBridgeLauncher.run` queues).

Not measured:

- Granting Full Disk Access to "CC Pocket" and the Bridge then reading
  protected folders after a restart (the screen says a restart is needed).
- `requestScreenCapture` (`CGRequestScreenCaptureAccess` from the helper).
- Local Network: under which name macOS lists the Bridge, and the link:
  `?Privacy_LocalNetwork` is not among the pane's anchors on macOS 27.2 and
  was only seen to open Privacy & Security.
- The re-check when the app becomes active again (`AppLifecycleListener`);
  the refresh button does the same.

A Bridge started another way (`setup`, manual `npx`) runs under its own
identity (Terminal, `node`), so the list is hidden unless the app's agent is
registered.

## Known gaps

- `/tools` runs CLIs synchronously and blocks the Bridge while it does. It is
  cached for 30 seconds (`?refresh=1` bypasses).
- The tools checklist needs a running Bridge. Without Node the launcher
  reports it and the app shows the install command for Node only.
- The app and the `ccpocket-bridge setup` service are separate LaunchAgents.
  The launcher yields when the port is taken, but the app does not migrate a
  `setup` service into its own agent.

## Entry points (macOS)

- Disconnected screen: "Bridge on this Mac" button above "try without
  connecting".
- "Bridge requires authentication" card for a loopback address: a button to
  the management screen replaces the terminal command.
- Settings home: a tile right below "Connection & Bridge"; also inside that
  category (so settings search can reveal it).
- Setup guide, page 2.
- "Connect from this app" hands `ws://127.0.0.1:<port>` and the token to the
  session list like a scanned QR code and closes the screen.

## Compatibility

- No WebSocket message and no protocol version change.
- An older Bridge answers `/admin/*` and `/tools` with `404`. The management
  screen and the tools checklist show "update the Bridge" themselves.
- `adminApiVersion` (currently `1`) lets the app detect later additions.

## Updating the Bridge

The launcher runs `npx --yes @ccpocket/bridge@1`, which installs the newest
1.x on every start, so restarting from the management screen is the update.
Nothing restarts a running Bridge when a release appears.

The phone's "update" action is a different path: over SSH it restarts the
`com.ccpocket.bridge` service written by `setup`. It must not be used for a
Bridge the desktop app runs: installing `setup` next to the app's agent puts
two KeepAlive services on one port. Restarting stays local on purpose (see
`/admin/*` above), so a phone only explains where to update:

- `/version` (public, like `/health`) reports `managedBy`: `desktop-app` when
  the launcher started the Bridge (`CCPOCKET_BRIDGE_SUPERVISED=1`, already set
  by shipped launchers), otherwise `other`. It only says which update path
  applies. Older Bridges omit it, and clients treat that as unknown.
- `desktop-app`: the app offers no SSH update and no `setup` instructions. It
  shows the steps for the Mac instead, or opens this screen directly when it
  is the desktop app connected over loopback.
- Unknown, in the desktop app connected over loopback without SSH: treated
  like `desktop-app`, because on the Mac that hosts the Bridge this app is
  where it is managed. The row opens this screen.
- Unknown on macOS (or unknown platform) otherwise: the `setup` instructions carry a
  note that they do not apply to a Bridge the desktop app runs. This is the
  case that matters in practice, because a Bridge that needs an update is an
  old one.
- The SSH start, stop and update commands report the same when the `setup`
  service is missing and the Mac shows signs of the app's launcher: its agent
  (`com.k9i.ccpocket.bridge-agent`) is registered, or
  `~/.ccpocket/launcher-status.json` exists (the agent is unregistered once
  the Bridge is stopped from the app). They only read that state and never
  start, stop or restart the agent.
- `desktop-app` also hides the SSH stop action. Start stays available because
  an offline Bridge reports nothing; the command above answers instead.
- `ccpocket-bridge setup` still bakes settings into the service definition as
  environment variables; those win over the file and show as locked.
