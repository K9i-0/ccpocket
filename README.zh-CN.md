# CC Pocket

**把编程代理，装进口袋。**

用手机聊天的方式操作 Codex 和 Claude：发出指令、批准下一步、查看结果。
换到平板或 Mac，也能继续同一项工作。

[了解 CC Pocket](https://k9i-0.github.io/ccpocket/install/?lang=zh) · 免费使用 · 开源

[English README](README.md) | [日本語 README](README.ja.md) | [한국어 README](README.ko.md)

<p align="center">
  <img src="docs/images/screenshots-zh-CN.png" alt="CC Pocket 截图" width="800">
</p>

## 安装

1. 在运行会话的主机上安装至少一个代理 CLI：
   [Codex](https://github.com/openai/codex) 或 [Claude](https://docs.anthropic.com/en/docs/claude-code)。
2. 在同一台主机上安装 [Node.js](https://nodejs.org/) 20.18.1 或更高版本。
3. 启动 CC Pocket Bridge Server：

```bash
npx @ccpocket/bridge@latest
```

4. 安装 CC Pocket，并扫描 Bridge Server 打印出的二维码。
5. 选择项目，再选择 Codex 或 Claude，然后从 App 启动会话。

| 平台 | 安装 |
|------|------|
| **iOS / iPadOS** | <a href="https://apps.apple.com/us/app/cc-pocket-code-anywhere/id6759188790"><img height="40" alt="Download on the App Store" src="docs/images/app-store-badge.svg" /></a> |
| **Android** | <a href="https://play.google.com/store/apps/details?id=com.k9i.ccpocket"><img height="40" alt="Get it on Google Play" src="docs/images/google-play-badge-en.svg" /></a> |
| **macOS** | 从 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=macos) 下载最新 `.dmg`。请查找带有 `macos/v*` 标签的发行版。也可以使用 Homebrew Cask 通过 `brew install --cask cc-pocket` 安装。 |
| **Linux（实验性）** | 从 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=linux) 下载最新 `.tar.gz`。请查找带有 `linux/v*` 标签的发行版。也可以使用 `yay -S cc-pocket-bin` 安装由社区维护的 [AUR 软件包](https://aur.archlinux.org/packages/cc-pocket-bin)。 |
| **Windows（实验性）** | 从 [GitHub Releases](https://github.com/K9i-0/ccpocket/releases?q=windows) 下载最新 `.zip`。请查找带有 `windows/v*` 标签的发行版。 |

## 免费使用

CC Pocket 可以免费使用。如果它对你的开发流程有帮助，欢迎在应用内成为 Supporter。Supporter 购买会用于覆盖 AI 工具费用，并帮助持续开发。

## 可以做什么

- **像聊天一样操作。** 每个会话就是一个房间，集中显示指令、回复、审批和问题。支持 Markdown、语音输入和图片附件。
- **换个设备，继续工作。** 在手机、平板或 Mac 上恢复 CLI 或应用中的会话。大屏幕可并排显示聊天、文件和 Git 差异。
- **断网也不丢输入。** 离线消息会暂存，重连后自动发送，并恢复遗漏的回复。执行新请求仍需要网络连接。
- **生成、查看、播放。** 用 Codex Imagegen 生成图片，在聊天中查看结果。视频和音频文件也能直接在应用内播放。
- **从审查到提交。** 浏览文件，查看代码和图片差异，执行 stage、commit、push 或 revert。通过 git worktree 分离并行任务。
- **使用自己的主机。** 代理通过 Mac、Linux 或 Windows 上的 Bridge Server 运行。用二维码、已保存主机或 Tailscale 连接，也可通过 SSH 管理 Bridge。

## 工作方式

CC Pocket 由两部分组成：

```text
CC Pocket app  <->  你自己机器上的 Bridge Server  <->  Codex / Claude
```

App 是操作界面。Bridge Server 在能够访问你的项目、shell、git 仓库和代理 CLI
的主机上运行。你的代码留在自己的机器上，不需要迁移到托管 IDE。

## 远程访问

在同一网络内，你可以使用二维码、mDNS 自动发现，或手动输入
`ws://` / `wss://` URL 连接。

如果要从家或办公室之外访问，推荐使用 Tailscale：

1. 在主机和手机上安装 [Tailscale](https://tailscale.com/)
2. 加入同一个 tailnet
3. 从 CC Pocket 连接 `ws://<host-tailscale-ip>:8765`

对于长期在线的主机，也可以把 Bridge Server 注册为后台服务：

```bash
npx @ccpocket/bridge@1 setup
```

服务化设置支持 macOS launchd 和 Linux systemd。
关于 `BRIDGE_ALLOWED_DIRS` 等 Bridge 设置，以及 service setup 会保存哪些设置，请见
[Bridge package README](packages/bridge/README.md#configuration)。

## 说明

- Claude 会话默认使用 `ANTHROPIC_API_KEY`。由于官方文档对此架构的适用范围尚不明确，
  订阅认证需要在 Bridge 上通过 `BRIDGE_ALLOW_CLAUDE_OAUTH=1` 明确启用。
  详情请见 [Claude 认证排查](docs/auth-troubleshooting.zh-CN.md)。
- CC Pocket 围绕自托管和最少数据收集设计。Supporter 购买可以在同一个
  Apple ID / Google 账号内恢复，但不会在不同商店之间同步。
  详情请见 [Supporter / Purchases](docs/supporter_zh.md)。
- macOS 截图功能需要为运行 Bridge Server 的终端应用授予屏幕录制权限。
- CC Pocket 与 Anthropic 或 OpenAI 没有任何关联，也未获得其认可、赞助或官方合作。

## 开发

```bash
git clone https://github.com/K9i-0/ccpocket.git
cd ccpocket
npm install
cd apps/mobile && flutter pub get && cd ../..
```

常用命令：

| 命令 | 说明 |
|------|------|
| `npm run bridge` | 以开发模式启动 Bridge Server |
| `npm run bridge:build` | 构建 Bridge Server |
| `npm run dev` | 重启 Bridge 并启动 Flutter App |
| `npm run test:bridge` | 运行 Bridge Server 测试 |
| `cd apps/mobile && flutter test` | 运行 Flutter 测试 |
| `cd apps/mobile && dart analyze` | 运行 Dart 静态分析 |

贡献指南请见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)
