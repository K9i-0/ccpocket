# Development Testing

Use a separate Bridge port while testing local changes so your normal always-on
Bridge on `8765` keeps working.

## Bridge-only changes

Use this when the mobile app already understands the protocol/UI you are testing,
and only the Bridge implementation changed.

```bash
BRIDGE_PORT=8766 BRIDGE_HOST=0.0.0.0 npm run bridge
```

Then connect from CC Pocket:

- Simulator on the same machine: `ws://localhost:8766`
- Physical phone: `ws://<host-lan-vpn-or-tailscale-ip>:8766`

This lets the installed mobile app talk to the Bridge code from your checkout.
It is the fastest end-to-end check for Bridge fixes such as recent sessions,
session resume, setup behavior, filesystem/git operations, and Codex/Claude
process handling.

## Bridge + app changes

Use this when the Flutter app also changed, or when a Bridge change requires new
mobile UI/protocol handling.

```bash
flutter devices
BRIDGE_PORT=8766 npm run dev -- <device-id>
```

Or run the two pieces manually:

```bash
BRIDGE_PORT=8766 BRIDGE_HOST=0.0.0.0 npm run bridge
cd apps/mobile && flutter run -d <device-id>
```

If no native/simulator device is available, use Flutter Web as the app target.
For a browser on the same machine, `web-server` gives a debug run:

```bash
BRIDGE_PORT=8766 BRIDGE_HOST=0.0.0.0 npm run bridge
cd apps/mobile && flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8888
```

For a phone or another machine, prefer a static web build. The debug
`web-server` target can try to connect to a localhost Dart debug service and
show a blank page in remote browsers:

```bash
BRIDGE_PORT=8766 BRIDGE_HOST=0.0.0.0 npm run bridge
cd apps/mobile && flutter build web --release
cd apps/mobile/build/web && python3 -m http.server 8888
```

Connect the debug app to:

- Simulator on the same machine: `ws://localhost:8766`
- Physical phone: `ws://<host-lan-vpn-or-tailscale-ip>:8766`
- Flutter Web on the same machine: open `http://127.0.0.1:8888`, then connect
  to `ws://127.0.0.1:8766`
- Flutter Web from another device: open `http://<host-lan-vpn-or-tailscale-ip>:8888`,
  then connect to `ws://<same-host-ip>:8766`

Debug builds also include the Mock Preview gallery for UI-only checks that do
not require a Bridge connection.

## Cleanup

If the Bridge or web app was started in the foreground, stop it with `Ctrl-C`.
If anything is still listening, kill the leftover port owners:

```bash
lsof -ti :8766 | xargs -r kill
lsof -ti :8888 | xargs -r kill
```

If you started detached transient user services for phone testing, stop and
clear them:

```bash
systemctl --user stop ccpocket-dev-bridge-8766 ccpocket-dev-web-8888
systemctl --user reset-failed ccpocket-dev-bridge-8766 ccpocket-dev-web-8888 2>/dev/null || true
```

Remove generated static web output after release-web previews:

```bash
rm -rf apps/mobile/build/web
```

Verify nothing is lingering. No output from these commands means the cleanup is
done:

```bash
lsof -nP -iTCP:8766 -sTCP:LISTEN
lsof -nP -iTCP:8888 -sTCP:LISTEN
ps -ef | grep -E "ccpocket-dev-(bridge|web)|BRIDGE_PORT=8766|http.server 8888|tsx src/index" | grep -v grep
find apps/mobile/build -maxdepth 1 -type d -name web
```

## Before opening a PR

Run the checks that match the files you touched:

```bash
npx tsc --noEmit -p packages/bridge/tsconfig.json
npm --workspace packages/bridge test -- src/<target>.test.ts
cd apps/mobile && dart analyze
cd apps/mobile && flutter test
```
