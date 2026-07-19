# CC Pocket Windows Tray

A Windows desktop tray client for running the CC Pocket Bridge without keeping a terminal window open.

This fork is based on [K9i-0/ccpocket](https://github.com/K9i-0/ccpocket). The upstream project provides the mobile app, desktop app experiments, and Bridge Server. This fork focuses on a cleaner Windows desktop experience: a tray app, a bilingual settings window, Windows-friendly development scripts, third-party runtime compatibility, and improved Codex recent-session syncing.

[简体中文](README.md) | [Upstream Project](https://github.com/K9i-0/ccpocket) | [Draft PR](https://github.com/K9i-0/ccpocket/pull/175)

## Download

Preview release:

[CC Pocket Windows Tray Preview](https://github.com/11233321323/ccpocket/releases/tag/windows-tray-preview-2026-07-20)

Available packages:

| Package | Use When |
|---------|----------|
| `CCPocketTray-win-x64-self-contained.zip` | Recommended for most users. Includes the .NET runtime. |
| `CCPocketTray-win-x64-framework-dependent.zip` | Smaller package. Requires .NET Desktop Runtime 8. |

Both packages still require Node.js because the Bridge itself is a Node application.

## Native iOS Preview

This fork also provides **CC Pocket Native iOS**, a SwiftUI-based native iPhone client preview. It reuses the existing Bridge Server, does not modify `packages/bridge`, and remains compatible with:

```bash
npx @ccpocket/bridge@latest
```

Source directory: [`iOS/CCPocketNative`](iOS/CCPocketNative)

Release download:

[CC Pocket Native iOS v0.1.0 Preview](https://github.com/11233321323/ccpocket/releases/tag/native-ios-v0.1.0)

| File | Notes |
|------|-------|
| `CCPocketNative-unsigned-20260720-052037.ipa` | iOS package. Physical-device installation requires your own Apple account or existing signing workflow. |
| `CCPocketNative-source-20260720.zip` | Native iOS client source package. |

Current coverage includes separate Codex / Claude Code workspaces, project-folder based conversations, multiple conversations per project, streaming chat, permission approval, folded tool calls, QR / deep-link parsing, and Bonjour discovery.

## What Windows Adds

- Windows tray launcher under `apps/windows-tray`.
- Start, stop, restart, and monitor Bridge from a GUI.
- Main window opens on launch and keeps running from the system tray after closing.
- Chinese and English UI, switchable from the main window.
- Tray menu follows the selected language.
- Hidden Bridge process, so no terminal window needs to stay open.
- Windows-compatible `npm install` and `npm run bridge` scripts.
- Third-party model, proxy, or Claude-compatible runtime support without a hard local Claude API-key precheck.
- Improved Codex recent-session listing by merging app-server results with local `.codex/sessions` scanning.

## How It Works

```text
Phone / tablet / desktop client
        |
        v
CC Pocket Bridge on your Windows machine
        |
        v
Codex / Claude / compatible runtime
```

The Windows tray app does not replace the Bridge. It wraps the Bridge with a desktop UI, keeps it running in the background, exposes connection URLs, and lets the existing mobile or desktop clients connect as before.

## Run From Source

Requirements:

- Windows 10 or later
- Node.js 18 or later
- .NET SDK 8 or later

```powershell
git clone https://github.com/11233321323/ccpocket.git
cd ccpocket
git checkout windows-tray-bridge
npm install
npm run bridge:build
dotnet run --project apps\windows-tray\CCPocketTray.csproj
```

If you run the built executable from a different folder, point it at the repository:

```powershell
$env:CCPOCKET_REPO_ROOT="C:\path\to\ccpocket"
```

## Build Packages

Framework-dependent:

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

Self-contained:

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

## Documentation

- [Windows tray developer notes](apps/windows-tray/README.md)
- [Windows tray release notes](docs/windows-tray-github-notes.md)
- [Chinese Windows tray developer notes](apps/windows-tray/README.zh-CN.md)
- [Chinese Windows tray release notes](docs/windows-tray-github-notes.zh-CN.md)

## Verification

These checks were run for the current preview branch:

```powershell
npx tsc --noEmit -p packages\bridge\tsconfig.json
npm --workspace=packages/bridge run test:windows-smoke
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

## Relationship To Upstream

This repository keeps the original CC Pocket source tree so the Windows tray work can remain compatible with upstream Bridge behavior and can be reviewed as a normal fork or pull request. The original project is MIT licensed and remains credited as the foundation of this fork.

## License

[MIT](LICENSE)
