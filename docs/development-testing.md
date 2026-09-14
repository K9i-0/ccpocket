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

## Android deep-link task regression

Use an Android emulator or device to verify that external deep links reach the
existing CC Pocket task without creating a second `MainActivity` or Bridge
connection. Test both `ccpocket://session/<id>` and `ccpocket://connect`.

For cold and warm launches, run the supported flag combinations:

```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "ccpocket://session/test-session"
adb shell am start -W -a android.intent.action.VIEW -f 0x10000000 \
  -d "ccpocket://session/test-session"
adb shell am start -W -a android.intent.action.VIEW -f 0x30000000 \
  -d "ccpocket://session/test-session"
adb shell am start -W -a android.intent.action.VIEW -f 0x14000000 \
  -d "ccpocket://session/test-session"
```

`0x30000000` is `NEW_TASK | SINGLE_TOP`; `NEW_TASK | CLEAR_TOP` is
`0x14000000`. A sender Activity that calls `startActivity()` without task flags
is required to reproduce caller-task nesting exactly; `adb shell am start`
does not provide an existing Activity task as the caller.

After each launch, inspect the task stack:

```bash
adb shell dumpsys activity activities | grep -E \
  "Task\{|com\.k9i\.ccpocket/(\.DeepLinkActivity|\.MainActivity)"
```

Confirm that only the canonical `MainActivity` remains, the URI is handled once,
the existing Bridge connection stays active, and Back/Recents navigation is
unchanged. Repeat after selecting each alternate launcher icon.

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

Run the checks for every area you changed. The commands below start at the
repository root; parentheses keep the Flutter commands in their own directory.
Documentation-only changes may instead record link, command, and content checks
and explain why application tests do not apply.

### Setup

Use Node.js 22 and the Flutter version pinned in [`.mise.toml`](../.mise.toml),
matching the [Test workflow](../.github/workflows/test.yml). Install Node.js for
Bridge work; Flutter is only needed for mobile work. Install dependencies from
lockfiles with the commands in the relevant section below.

### Bridge

```bash
npm ci
npm run test:bridge
npx tsc --noEmit -p packages/bridge/tsconfig.json
npm run bridge:build
```

During development, run a targeted test for faster feedback:

```bash
npm --workspace packages/bridge test -- src/<target>.test.ts
```

Before submitting, run the full Bridge suite above, even if the targeted test
passes. Changes to shared session or history behavior can break tests in other
modules. Update affected fixtures and mocks when interfaces change, and preserve
meaningful regression assertions. Type checking and building do not replace
running tests.

### Flutter mobile app

```bash
(cd apps/mobile && flutter pub get && dart analyze . && flutter test)
```

Use targeted tests during development and the full suite before submitting.
CI also runs Docker-backed SSH smoke tests and selected host-dependent tests on
Windows; plain `flutter test` does not replace those checks. See the
[Test workflow](../.github/workflows/test.yml) for their setup and commands.
For UI or OS-dependent changes, include the visual or target-platform evidence
required by [CONTRIBUTING.md](../CONTRIBUTING.md).

### Functions

```bash
npm ci --prefix functions
npm --prefix functions test
npm --prefix functions run typecheck
npm --prefix functions run build
```

### Repository tooling

For PR readiness or release-tool changes, run the corresponding checks:

```bash
node --test scripts/pr-readiness.test.mjs
npm run test:release-tools
```

### Record results and check CI

Copy the exact commands and actual results into the PR template's **Test Evidence**
section. Include failures or checks you could not run and their reasons. A newly
added regression test or successful manual check does not establish that the
existing automated suite passes.

After pushing, inspect the **latest commit's** `Test` workflow. Fix failures caused
by the change and rerun affected checks. For a suspected existing failure, provide
comparison evidence from the base commit rather than assuming it is unrelated.
Wait for required CI and CodeRabbit checks before maintainer review; a green
`Test` workflow alone does not mean `PR Readiness` has passed.
