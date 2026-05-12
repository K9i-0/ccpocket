# Linux Desktop Client PRD

## 背景

CC Pocket 目前已有 iOS、Android、macOS client 和 Bridge Server。Linux 现在主要作为
Bridge Server 的 host 使用，但还没有提供 Flutter client 的 Linux desktop 版本。

`apps/mobile` 已经具备一部分 desktop 适配能力，包括 adaptive workspace 和
`TargetPlatform.linux` 判断。缺口主要在两类地方：

- `apps/mobile/linux/` Flutter 平台工程尚未生成。
- 少数移动端或 macOS 相关插件没有 Linux 实现，需要在 Linux 上降级或禁用。

## 目标

第一阶段目标是做出最小可用 Linux client：

- Linux 上能 build 和 launch。
- 能连接现有 Bridge Server。
- 能启动 / 继续 Codex 或 Claude session。
- 能处理消息、流式输出、审批、AskUserQuestion、Diff、Explorer 等核心工作流。

## 非目标

- 第一版不追求与 iOS / Android / macOS 完全等价。
- 第一版不正式支持 FCM push、RevenueCat purchase、QR camera scan、Shorebird OTA。
- 本 PRD 不覆盖 Linux Bridge Server / systemd host 的改造。
- 第一版不要求 AppImage、deb、rpm 等正式安装包。

## 当前判断

- 当前机器的 Flutter Linux toolchain 可用。
- Flutter 能识别 `Linux (desktop)` 设备。
- `apps/mobile/linux/` 当前不存在。
- 核心通信是 Dart WebSocket / HTTP，天然跨平台。
- 主要 UI 已经有 tablet / macOS / Linux desktop layout 判断。
- 最大风险来自插件支持，而不是业务逻辑或 UI 重写。

## 插件风险表

| 功能 | 当前 package | Linux 状态 | 最小 client 处理 |
|---|---|---|---|
| WebSocket / HTTP | Dart packages | 可用 | 直接使用 |
| Settings | `shared_preferences` | 可用 | 直接使用 |
| SSH credentials | `flutter_secure_storage` | 可用 | 直接使用 |
| mDNS discovery | `bonsoir_linux` | 可用 | 直接使用 |
| Deep links | `app_links_linux` | 可用 | 直接使用 |
| File/image picker | `image_picker_linux` | 可用 | 直接使用 |
| Clipboard / drag-drop | `super_native_extensions` | 可用 | 直接使用 |
| Local DB | `sqflite` | 无 Linux backend | Phase 1 no-op，Phase 2 接 `sqflite_common_ffi` |
| FCM push | `firebase_messaging` | 无 Linux 实现 | Linux 禁用 |
| QR camera scan | `mobile_scanner` | 无 Linux 实现 | Linux 隐藏入口或提示手动输入 |
| Voice input | `speech_to_text` | desktop 不作为核心能力 | 沿用现有 desktop 禁用 |
| RevenueCat | `purchases_flutter` | Linux 不支持购买 | Linux 显示 unavailable |
| Shorebird OTA | `shorebird_code_push` | mobile only | Linux 禁用 |
| Local notifications | `flutter_local_notifications_linux` | 可用 | Phase 1 最小处理，Phase 2 polish |

## Phase 1: 最小 Linux Client

目标：Linux 上可以启动 client，并完成 Bridge 连接和主要 session 操作。

### 功能要求

- Linux desktop app 可以启动。
- 可以通过手动 URL 连接 Bridge Server。
- 可以通过 saved machines 连接。
- mDNS discovery 可用时可以展示发现到的 Bridge。
- 可以 start / resume Codex 和 Claude session。
- 可以发送用户输入。
- 可以显示 assistant message、stream delta、tool result。
- 可以处理 approve / reject / AskUserQuestion answer。
- Git diff、Explorer、Gallery 等 Bridge 侧功能保持可用。
- SSH remote start / stop / update 保持现有 Dart SSH 能力，不额外扩展。

### 降级功能

- Linux 不显示 QR camera scan 入口，或者明确引导手动输入 URL。
- Linux 不注册 FCM token，不初始化 Firebase Messaging handler。
- Linux 不执行 Shorebird update。
- Linux 不提供 RevenueCat purchase flow。
- Prompt history local DB 在 Phase 1 可以 no-op，但不能导致 app crash。

### 实施步骤

1. 在 `apps/mobile` 下生成 Linux 平台工程：`flutter create --platforms=linux .`
2. 确认 `.metadata` 包含 Linux platform migration。
3. 运行 Linux build，收集编译错误。
4. 对 Linux 不支持的插件调用加 platform guard。
5. 在 Linux 隐藏 QR scan button / route 入口。
6. 在 Linux 跳过 FCM background / foreground handler registration。
7. 如 local notification 在 Linux 初始化时报错，Phase 1 先 no-op 化。
8. 运行 `flutter run -d linux`，通过手动 URL 连接 Bridge。
9. 做最小 smoke：session start、message send、approval、diff / Explorer。

### 验收标准

- `flutter build linux --debug` 通过。
- `flutter run -d linux` 可以启动。
- 手动 URL 可以连接 Bridge。
- 可以启动一个 Codex session 并收到 assistant response。
- approval request 可以展示，并能 approve 或 reject。
- Linux 不支持功能不会造成 runtime crash。

## Phase 2: Desktop Parity

目标：让 Linux desktop client 达到日常可用质量。

### 功能要求

- 用 `sqflite_common_ffi` 支持 Linux prompt history cache。
- 完成 Linux local notification 初始化和展示验证。
- 验证 `app_links_linux` deep link 行为。
- 验证 image picker、clipboard image paste、drag-and-drop。
- 清理 macOS 专属 banner / settings 在 Linux 上的展示。
- 检查 desktop keyboard shortcut 和窗口尺寸下的布局。

### 实施步骤

1. 加入 `sqflite_common_ffi`，只在 Linux 初始化 database factory。
2. 为 `NotificationService` 补 Linux initialization / details。
3. 用测试固定 macOS native app banner 不在 Linux 显示。
4. 改善 QR scan 的替代入口，例如 paste connection URL。
5. 运行 `dart analyze apps/mobile` 和 Linux 启动验证。
6. 手动验证 chat、Git、Explorer、settings 主要页面。

### 验收标准

- Linux prompt history 可以持久化。
- Linux local notification 不 crash，至少能显示基础通知。
- macOS 专属 UI 不在 Linux 误展示。
- desktop 主要页面没有明显布局崩坏。

## Phase 3: Distribution

目标：产出可分发的 Linux client。

### 功能要求

- 可以生成 release build。
- app icon、desktop entry、app name 正确。
- 至少提供 tarball，后续可加 AppImage。
- GitHub Releases 可以附加 Linux artifact。

### 实施步骤

1. 跑通 `flutter build linux --release`。
2. 调整 Linux icon / metadata / desktop file。
3. 添加 tarball packaging script。
4. 如需要，添加 AppImage packaging。
5. 添加 GitHub Actions Linux build job。
6. 更新 README 和 install page。

### 验收标准

- clean checkout 可以生成 Linux release artifact。
- artifact 解压后可以启动 app。
- GitHub Releases 可以发布 Linux build。

## 验证计划

Phase 1:

- `flutter build linux --debug`
- `flutter run -d linux`
- 手动 Bridge 连接
- Codex session smoke test
- approval flow smoke test
- Explorer / Git diff smoke test

Phase 2:

- `dart analyze apps/mobile`
- `cd apps/mobile && flutter test`
- Linux desktop 手动 UI 检查
- prompt history persistence 检查
- local notification 检查

Phase 3:

- `flutter build linux --release`
- release artifact 启动检查
- clean machine dependency 检查

## 未决问题

- Linux desktop client 是正式 release，还是先标记 experimental。
- 第一种发布格式选 tarball 还是 AppImage。
- Linux 上 Supporter / purchase 是完全隐藏，还是显示 unavailable 说明。
- QR scan 的替代是否只做 manual URL，还是增加从图片文件 decode QR。

## 推荐第一版 PR Scope

第一版只做 Phase 1：

- 生成 `apps/mobile/linux/`。
- 给不支持 Linux 的 service / route 加 guard。
- Linux 隐藏 QR camera scan。
- 保证 build 和 launch。
- 验证手动 Bridge 连接和一个 Codex session smoke path。

这样可以最快确认 Linux client 的可行性，并把 polish 和 packaging 分离到后续 PR。
