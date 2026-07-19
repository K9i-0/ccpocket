# CC Pocket Windows 托盘启动器

这是 CC Pocket Bridge 的轻量 Windows 托盘启动器。它会在后台启动现有的 Node Bridge，隐藏终端窗口，提供一个可视化设置界面，并在系统托盘里提供启动、停止、重启、复制 WebSocket 地址等常用操作。

## 系统要求

- Windows 10 或更高版本
- Node.js 18 或更高版本
- 已在仓库根目录执行 `npm install`
- 如果使用 framework-dependent 包，需要安装 .NET Desktop Runtime 8 或更高版本
- 如果使用 self-contained 包，不需要单独安装 .NET Runtime

## 从源码运行

```powershell
dotnet run --project apps\windows-tray\CCPocketTray.csproj
```

托盘程序会自动寻找仓库根目录。如果你从其他目录运行可执行文件，可以手动指定：

```powershell
$env:CCPOCKET_REPO_ROOT="C:\path\to\ccpocket"
```

## 先构建 Bridge

```powershell
npm run bridge:build
```

当 `packages\bridge\dist\index.js` 存在时，托盘程序会优先运行编译后的 Bridge。如果不存在，会回退到 `npm run bridge`。

## 打包 EXE

framework-dependent 版本体积较小，但需要用户安装 .NET Desktop Runtime 8：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained false /p:PublishSingleFile=true
```

self-contained 版本体积较大，但包含 .NET 运行时：

```powershell
dotnet publish apps\windows-tray\CCPocketTray.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:PublishDir=bin\Release\net8.0-windows\win-x64\publish-self-contained\
```

## 行为说明

- 启动时自动打开主界面。
- 默认自动启动 Bridge。
- 关闭窗口后仍会留在系统托盘运行。
- 不会弹出 Bridge 终端窗口。
- 如果配置端口上已经有可用 Bridge，会自动连接已有 Bridge，而不是重复启动。
- 主界面和托盘菜单支持中文、英文切换。
- 设置保存到 `%APPDATA%\CCPocket\tray-settings.json`。
- 日志保存到 `%APPDATA%\CCPocket\tray.log`。

## 推荐发布方式

源码提交到 Git 分支，安装包通过 GitHub Releases 发布。不要把下面这些文件提交进仓库：

```text
apps/windows-tray/bin/
apps/windows-tray/obj/
packages/bridge/dist/
node_modules/
tmp/*.png
canvas/
```
