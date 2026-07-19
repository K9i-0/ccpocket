# Windows 托盘启动器发布说明

这份文档整理了 Windows 托盘启动器和 Bridge 相关改动，方便发布到 GitHub、写 PR 描述或准备 Release。

## 项目地址

- 原项目：`https://github.com/K9i-0/ccpocket`
- 你的 fork：`https://github.com/11233321323/ccpocket`
- 当前分支：`windows-tray-bridge`
- PR：`https://github.com/K9i-0/ccpocket/pull/175`

## 改动概览

- 新增轻量 WinForms 托盘程序：`apps/windows-tray`。
- 托盘程序可以在后台启动现有 CC Pocket Bridge，不需要一直挂着终端。
- 启动时自动打开主界面，关闭窗口后继续留在系统托盘。
- 主界面和托盘菜单支持中文、英文切换。
- 托盘程序会把设置保存到 `%APPDATA%\CCPocket\tray-settings.json`。
- 托盘日志保存到 `%APPDATA%\CCPocket\tray.log`。
- 修复 Windows 下 `npm install` 依赖 WSL/bash 的问题。
- 修复 Windows 下 `npm run bridge` 依赖 Unix `env -u` 的问题。
- 去除本地 Claude 官方认证硬检查，让第三方模型、代理或 Claude-compatible runtime 自己处理认证。
- 优化 Codex 最近会话同步：Bridge 会合并 Codex app-server 返回结果和本地 `.codex/sessions` 扫描结果，减少手机端看不到最新会话、需要重启 Codex 的情况。

## 新增源码

```text
apps/windows-tray/
```

主要文件：

```text
apps/windows-tray/CCPocketTray.csproj
apps/windows-tray/Program.cs
apps/windows-tray/TrayApplicationContext.cs
apps/windows-tray/MainForm.cs
apps/windows-tray/BridgeProcessManager.cs
apps/windows-tray/TraySettings.cs
apps/windows-tray/I18n.cs
apps/windows-tray/README.md
apps/windows-tray/README.zh-CN.md
```

## 构建命令

先构建 Bridge：

```powershell
npm run bridge:build
```

构建托盘程序：

```powershell
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

发布 framework-dependent EXE：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

发布 self-contained EXE：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

## 安装包/发布附件

建议通过 GitHub Releases 上传压缩包，不建议把 EXE、ZIP、`bin/`、`obj/` 直接提交到 Git。

推荐附件：

```text
CCPocketTray-win-x64-framework-dependent.zip
CCPocketTray-win-x64-self-contained.zip
```

framework-dependent 版本需要安装 .NET Desktop Runtime 8，包更小。

self-contained 版本包含 .NET 运行时，包更大，但用户开箱即用。两种版本都仍然需要 Node.js，因为 Bridge 本身是 Node 程序。

## 验证命令

已验证：

```powershell
npx tsc --noEmit -p packages\bridge\tsconfig.json
npm --workspace=packages/bridge run test:windows-smoke
dotnet build apps\windows-tray\CCPocketTray.csproj -c Release
```

Bridge 健康检查：

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health | ConvertTo-Json
```

预期返回类似：

```json
{
  "status": "ok",
  "uptime": 13,
  "sessions": 0,
  "clients": 0
}
```

## 发布注意事项

- 源码、README、设计说明提交到 Git 分支。
- EXE 和 ZIP 通过 GitHub Releases 发布。
- 不要提交本地 Cowart 画布草稿、截图、构建产物、依赖目录。
- 托盘程序优先运行 `packages/bridge/dist/index.js`。
- 如果 Bridge 未构建，会回退执行 `npm run bridge`。
- 如果配置端口已有 Bridge，托盘程序会连接现有 Bridge，不会重复启动。
