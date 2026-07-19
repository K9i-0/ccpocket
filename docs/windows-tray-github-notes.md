# Windows Tray Launcher Notes

This document summarizes the Windows tray launcher work and the Bridge changes that make Windows use smoother.

Simplified Chinese version: [windows-tray-github-notes.zh-CN.md](windows-tray-github-notes.zh-CN.md).

## Summary

- Added a lightweight WinForms tray app at `apps/windows-tray`.
- The tray app starts the existing CC Pocket Bridge in the background without opening a terminal window.
- The main window opens on launch and continues running from the system tray after it is closed.
- The UI supports Chinese and English, switchable from the main screen.
- The system tray context menu follows the selected language.
- The tray app persists settings under `%APPDATA%\CCPocket\tray-settings.json`.
- Tray logs are written to `%APPDATA%\CCPocket\tray.log`.
- Bridge recent Codex sessions now merge Codex app-server results with local `.codex/sessions` JSONL scanning, reducing stale recent-session lists that previously required restarting Codex.
- Bridge Windows development scripts no longer require WSL/bash for `npm install` or `npm run bridge`.
- Claude-compatible third-party model/proxy runtimes are allowed to handle authentication themselves instead of being blocked by a hard API-key precheck.

## New App

Source:

```text
apps/windows-tray/
```

Important files:

```text
apps/windows-tray/CCPocketTray.csproj
apps/windows-tray/Program.cs
apps/windows-tray/TrayApplicationContext.cs
apps/windows-tray/MainForm.cs
apps/windows-tray/BridgeProcessManager.cs
apps/windows-tray/TraySettings.cs
apps/windows-tray/I18n.cs
apps/windows-tray/README.md
```

## Build

Build Bridge first:

```powershell
npm run bridge:build
```

Build the tray app:

```powershell
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

Publish EXE:

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

## Release Artifacts

Release executable:

```text
apps/windows-tray/bin/Release/net8.0-windows/win-x64/publish-self-contained/CCPocketTray.exe
```

Only publish packaged artifacts through GitHub Releases. Do not commit `bin/`, `obj/`, local screenshots, or Cowart canvas drafts.

## Verification

Commands already used during development:

```powershell
npm install
npm run bridge:build
npx tsc --noEmit -p packages\bridge\tsconfig.json
npm --workspace=packages/bridge run test:windows-smoke
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

Runtime checks:

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health | ConvertTo-Json
```

Expected shape:

```json
{
  "status": "ok",
  "uptime": 13,
  "sessions": 0,
  "clients": 0
}
```

## Notes For Reviewers

- The Windows tray app shells out to Node and runs `packages/bridge/dist/index.js` when Bridge has been built.
- If Bridge has not been built, it falls back to `npm run bridge`.
- If a Bridge is already reachable on the configured port, the tray app attaches instead of starting a duplicate Bridge.
- The tray app does not bundle Node.js; users still need Node.js installed.
- The release build includes the .NET runtime, but Node.js is still required for Bridge.

## Suggested Commit Scope

Include:

```text
.gitignore
package.json
package-lock.json
scripts/setup-hooks.mjs
packages/bridge/package.json
packages/bridge/scripts/dev.mjs
packages/bridge/src/sdk-process.ts
packages/bridge/src/websocket.ts
apps/windows-tray/
docs/windows-tray-github-notes.md
```

Exclude:

```text
canvas/
tmp/*.png
apps/windows-tray/bin/
apps/windows-tray/obj/
packages/bridge/dist/
```
