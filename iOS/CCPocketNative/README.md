# CC Pocket Native iOS

English | [简体中文](#简体中文)

## English

`CC Pocket Native` is an experimental native SwiftUI iOS client for the existing
CC Pocket Bridge protocol. It is designed as a more Apple-native agent console
while keeping the desktop Bridge Server unchanged.

It does not modify `packages/bridge` and remains compatible with:

```sh
npx @ccpocket/bridge@latest
```

Current preview coverage:

- Scan or enter a Bridge URL, including `ccpocket://connect?url=ws://IP:PORT&token=...`.
- Connect to Bridge over `ws://` and `wss://`.
- Send `client_capabilities`.
- Separate Codex and Claude Code workspaces.
- Organize conversations by project folder.
- Run multiple conversations under the same project.
- Start Codex or Claude sessions.
- Resume previous sessions.
- Send prompts and display `stream_delta`, assistant messages, tool calls, tool results, and errors.
- Fold tool-call details by default.
- Approve, always allow, or reject `permission_request` messages.
- Discover `_ccpocket._tcp` Bridge services on the local network.
- Switch agent, model, and permission mode from the chat UI.

### Build

Open `CCPocketNative.xcodeproj` with Xcode 26 or newer, or build from the command line:

```sh
xcodebuild -project CCPocketNative.xcodeproj -scheme CCPocketNative -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Deployment target is iOS 26. The UI uses system SwiftUI structure first and keeps
Liquid Glass effects limited to navigation and floating controls.

### Release Asset

The prepared unsigned IPA is:

```text
dist/CCPocketNative-unsigned-20260720-052037.ipa
```

The IPA does not contain the developer's Apple account signature,
`_CodeSignature`, or `embedded.mobileprovision`. Re-sign it with your own Apple
account before installing it on an iPhone, or build from source with Xcode.

## 简体中文

面向现有 CC Pocket Bridge 的原生 SwiftUI iOS 客户端。这个版本暂名
`CC Pocket Native`，用于验证更 Apple 原生的移动端 agent 控制体验。

这个 app 不修改 `packages/bridge`，并复用 Flutter 客户端同一套 WebSocket JSON 协议。当前已覆盖第一阶段控制闭环：

- 扫描或输入 Bridge 地址，包括 `ccpocket://connect?url=ws://IP:PORT&token=...`
- 使用系统 WebSocket 和本地 TCP WebSocket 连接 Bridge
- 发送 `client_capabilities`
- 分离 Codex / Claude Code 工作区
- 按项目文件夹整理运行中会话、最近会话和项目历史
- 启动 Codex 或 Claude 会话
- 同一个项目下运行多个对话
- 恢复历史会话
- 发送提示词，并显示 `stream_delta`、assistant 消息、工具调用、工具结果和错误
- 默认折叠工具调用详情，避免工具输出占满聊天
- 对 `permission_request` 执行批准、始终允许或拒绝
- 在局域网中发现 `_ccpocket._tcp` Bridge 服务
- 在聊天顶部切换 agent、模型和权限模式

## 构建

用 Xcode 26 或更新版本打开 `CCPocketNative.xcodeproj`，也可以从命令行构建：

```sh
xcodebuild -project CCPocketNative.xcodeproj -scheme CCPocketNative -destination 'platform=iOS Simulator,name=iPhone 17' build
```

部署目标是 iOS 26。UI 优先使用系统 SwiftUI 结构，并且只在导航与浮动控制层使用 Liquid Glass。

## GitHub Release

当前准备的发布材料：

- `docs/releases/native-ios-github-release-body.md`
- `docs/releases/ccpocket-native-ios-v0.1.0.md`
- `docs/releases/native-ios-installation.md`
- `docs/releases/native-ios-release-checklist.md`

当前 unsigned IPA：

```text
dist/CCPocketNative-unsigned-20260720-052037.ipa
```

这个 IPA 不包含开发者账号签名，不能直接安装到 iPhone。发布给 GitHub 后，用户需要用自己的证书重签，或从源码用 Xcode 构建安装。
