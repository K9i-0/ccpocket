# CC Pocket Windows Tray

Lightweight Windows tray launcher for the CC Pocket Bridge. It starts the existing Node bridge in the background, keeps the console hidden, exposes a small settings window, and provides tray actions for start, stop, and copying the WebSocket URL.

Chinese documentation: [README.zh-CN.md](README.zh-CN.md).

## Requirements

- Windows 10 or later
- Node.js 18 or later
- Repository dependencies installed with `npm install`

## Run From Source

```powershell
dotnet run --project apps\windows-tray\CCPocketTray.csproj
```

The tray app looks for the repository root automatically. If you run the executable from another folder, set:

```powershell
$env:CCPOCKET_REPO_ROOT="C:\path\to\ccpocket"
```

## Build Bridge First

```powershell
npm run bridge:build
```

When `packages\bridge\dist\index.js` exists, the tray app runs the compiled bridge. If it is missing, it falls back to `npm run bridge`.

## Publish EXE

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

The executable is written to:

```text
apps\windows-tray\bin\Release\net8.0-windows\win-x64\publish-self-contained\CCPocketTray.exe
```

## Behavior

- Opens the main window on launch and keeps running from the system tray after the window is closed.
- Starts Bridge automatically by default.
- Does not open a terminal window.
- If Bridge is already reachable on the configured port, it attaches instead of starting a duplicate process.
- Settings are saved under `%APPDATA%\CCPocket\tray-settings.json`.
