# CC Pocket Windows 托盘客户端

一个面向 Windows 用户的 CC Pocket Bridge 托盘客户端。它可以在后台启动 Bridge，不需要一直挂着终端窗口，更适合日常在 Windows 电脑上连接手机端、平板端或其他客户端使用。

这个 fork 基于 [K9i-0/ccpocket](https://github.com/K9i-0/ccpocket)。原项目提供移动端 App、桌面端实验版本和 Bridge Server。本 fork 重点做 Windows 电脑版体验：托盘程序、双语言设置界面、Windows 友好的开发脚本、第三方模型兼容，以及 Codex 最近会话同步优化。

[English](README.en.md) | [原项目](https://github.com/K9i-0/ccpocket) | [当前 PR](https://github.com/K9i-0/ccpocket/pull/175)

## 下载

预览版 Release：

[CC Pocket Windows Tray Preview](https://github.com/11233321323/ccpocket/releases/tag/windows-tray-preview-2026-07-20)

可下载两个包：

| 文件 | 适合场景 |
|------|----------|
| `CCPocketTray-win-x64-self-contained.zip` | 推荐普通用户下载，包含 .NET 运行时。 |
| `CCPocketTray-win-x64-framework-dependent.zip` | 体积更小，但需要安装 .NET Desktop Runtime 8。 |

两个包都仍然需要 Node.js，因为 Bridge 本身是 Node 程序。

## 原生 iOS 预览版

这个 fork 也提供 **CC Pocket Native iOS**，一个基于 SwiftUI 的原生 iPhone 客户端预览版。它复用现有 Bridge Server，不修改 `packages/bridge`，仍然兼容：

```bash
npx @ccpocket/bridge@latest
```

源码目录：[`iOS/CCPocketNative`](iOS/CCPocketNative)

Release 下载：

[CC Pocket Native iOS v0.1.0 Preview](https://github.com/11233321323/ccpocket/releases/tag/native-ios-v0.1.0)

| 文件 | 说明 |
|------|------|
| `CCPocketNative-unsigned-20260720-052037.ipa` | iOS 安装包，真机安装需要使用你自己的 Apple 账号或现有签名流程。 |
| `CCPocketNative-source-20260720.zip` | 原生 iOS 客户端源码包。 |

当前包括 Codex / Claude Code 分离、按项目文件夹整理对话、同项目多对话、流式聊天、权限审批、工具调用默认折叠、二维码 / deep link 连接解析和 Bonjour 自动发现。

## Windows 这次做了什么

- 新增 Windows 托盘启动器：`apps/windows-tray`。
- 可以从图形界面启动、停止、重启、查看 Bridge 状态。
- 启动时自动打开主界面，关闭窗口后继续留在系统托盘。
- 主界面支持中文、英文切换。
- 托盘菜单跟随当前语言。
- Bridge 在后台隐藏运行，不需要一直打开终端。
- 修复 Windows 下 `npm install` 和 `npm run bridge` 对 WSL、bash、Unix `env` 的依赖。
- 支持第三方模型、代理或 Claude-compatible runtime 自己处理认证，不再被本地 Claude API Key 检查挡住。
- 优化 Codex 最近会话列表：合并 app-server 返回结果和本地 `.codex/sessions` 扫描结果，减少手机端看不到最近记录、需要重启 Codex 的情况。

## 工作方式

```text
手机 / 平板 / 桌面客户端
        |
        v
Windows 电脑上的 CC Pocket Bridge
        |
        v
Codex / Claude / 兼容运行时
```

Windows 托盘程序不是替代 Bridge，而是给 Bridge 套了一层电脑版界面：负责后台启动、状态查看、复制连接地址、托盘驻留，让手机端或其他客户端照常连接。

## 从源码运行

要求：

- Windows 10 或更高版本
- Node.js 18 或更高版本
- .NET SDK 8 或更高版本

```powershell
git clone https://github.com/11233321323/ccpocket.git
cd ccpocket
git checkout windows-tray-bridge
npm install
npm run bridge:build
dotnet run --project apps\windows-tray\CCPocketTray.csproj
```

如果你从其他目录运行编译好的 EXE，可以指定仓库路径：

```powershell
$env:CCPOCKET_REPO_ROOT="C:\path\to\ccpocket"
```

## 打包

小包，需要 .NET Runtime：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

自包含包，包含 .NET Runtime：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

## 文档

- [Windows 托盘开发说明](apps/windows-tray/README.zh-CN.md)
- [Windows 托盘发布说明](docs/windows-tray-github-notes.zh-CN.md)
- [English Windows tray developer notes](apps/windows-tray/README.md)
- [English Windows tray release notes](docs/windows-tray-github-notes.md)

## 验证

当前预览分支已经跑过：

```powershell
npx tsc --noEmit -p packages\bridge\tsconfig.json
npm --workspace=packages/bridge run test:windows-smoke
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

## 和原项目的关系

这个仓库保留原 CC Pocket 源码树，是为了让 Windows 托盘客户端继续兼容原 Bridge 行为，也方便以 fork 或 PR 的形式审查。原项目采用 MIT License，本 fork 明确保留原项目来源说明。

## 许可证

[MIT](LICENSE)
