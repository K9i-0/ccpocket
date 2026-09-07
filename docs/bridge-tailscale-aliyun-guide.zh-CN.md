# 让 Codex Desktop 自动部署 CC Pocket Bridge：手机连接个人电脑上的 Codex 或 Claude Code

> 将本文件完整发送给 Codex Desktop。Codex 负责检查、安装、配置、排错和端到端验证；用户只在必须购买、登录、授权或操作手机时介入。

## 1. 部署目标

```text
iPhone / iPad（Tailscale + CC Pocket）
        │
        │ ws://<BRIDGE_HOST_TAILSCALE_IP>:<BRIDGE_PORT>
        │ 优先直连；必要时经阿里云 Peer Relay
        ▼
用户的个人电脑（默认 Bridge 主机；Windows / macOS / Linux）
  ├─ Tailscale
  ├─ Node.js 20.18.1+
  ├─ Codex CLI 和/或 Claude Code
  └─ CC Pocket Bridge（只允许访问用户批准的目录）

远程 Linux / GPU 服务器（可选 Bridge 主机）
  └─ 仅当用户希望代理在远程项目上运行或需要常驻在线时使用

阿里云中国内地服务器（可选）
  └─ Tailscale Peer Relay，开放一个 UDP 端口
```

CC Pocket 是第三方开源项目，不是 OpenAI 或 Anthropic 官方产品。Bridge 默认运行在用户自己的个人电脑上，手机通过 WebSocket 控制这台电脑上的 Codex 或 Claude Code。远程 Linux/GPU 服务器和阿里云 Peer Relay 都是选配，不是基本连接的前提。

后文中的“Bridge 主机”默认指用户运行 Codex Desktop、Codex CLI 或 Claude Code 的个人电脑。只有用户明确选择远程方案时，它才指远程 Linux/GPU 服务器。

## 2. 给 Codex Desktop 的执行规则

1. 先只读检查，再决定安装方案。不要覆盖已有服务、端口、配置或 Tailnet 策略。
2. 如有会影响方案、执行或结果判断的实质性不确定项，集中向用户提问，优先提供互斥选项并标注推荐项；没有就直接执行。
3. 执行前查阅当前官方文档，核对 Codex、CC Pocket Bridge 和 Tailscale 的安装方式、最低版本与参数。
4. 不要求用户在聊天中粘贴 Tailscale auth key、OpenAI API key、Bridge key、SSH 私钥或密码。优先使用浏览器授权 URL。
5. 所有 `<PLACEHOLDER>` 必须先探测或确认，禁止原样执行。
6. 修改文件前备份。编辑 Tailscale Access Controls 时只合并最小规则，不覆盖已有 ACL、grants、SSH 规则、tests 或注释。
7. Bridge 面向 WebSocket；HTTP `404` 可以是健康状态。必须用监听、日志、手机会话列表和真实 Codex/Claude 对话验收。
8. 若用户正通过 Bridge 对话，说明服务在使用中。除非必要并已告知短暂中断，否则不要重启 Bridge，也不要批量终止 Codex、Claude 或 Node 进程。
9. 最终报告不得包含任何密钥、令牌、认证文件内容或个人隐私信息。

## 3. 只有这些环节需要用户操作

Codex 应按阶段一次性提出所需问题，不要让用户逐条运行普通命令。

### 用户关口 A：确认目标

让用户确认：

- Bridge 安装在当前个人电脑（推荐）还是可选的远程 Linux/GPU 服务器；
- 若选择远程服务器：SSH 别名或地址、用户名，以及 Codex Desktop 能否 SSH 登录；
- CC Pocket 可访问的项目目录；
- 准备使用 Codex、Claude Code，还是两者都用；
- 若选择远程服务器：远程主机是否有 `sudo`；
- 是否已有阿里云中国内地服务器；
- 手机平台；
- 是否启用 Bridge API key。推荐启用；若 Tailnet 仅含完全可信的个人设备，也可选择不启用。

不要索要 SSH 私钥正文。首次主机指纹确认应由用户在可信界面完成。

### 用户关口 B：网页登录授权

Codex 把命令产生的登录 URL 发给用户，等待其完成：

- Bridge 主机加入 Tailscale；
- 阿里云服务器加入同一个 Tailnet；
- Bridge 主机上的 Codex CLI 登录 OpenAI 账号（仅现有登录不可用时）；
- Claude Code 所需的 Anthropic API key 由用户通过安全方式配置（仅选择 Claude 时）。

不要让用户回传网页登录后的 token。

### 用户关口 C：云控制台

仅用户完成：购买/创建阿里云实例、修改安全组或轻量服务器防火墙、在 Tailscale 管理后台保存 grant，以及必要时使用 Workbench/VNC/救援控制台恢复访问。

### 用户关口 D：手机

手机 App 的安装和账号登录无法由远程 Codex 代办，必须由用户亲自在手机上完成：

- 从官方应用商店安装并登录 Tailscale；
- 从 [CC Pocket 项目官网](https://k9i-0.github.io/ccpocket/install/) 提供的商店链接安装正版 CC Pocket；
- iPhone/iPad 的中国大陆区 App Store 可能搜索不到 CC Pocket。若项目官网链接提示当前地区不可用，用户需要切换到能够下载该应用的非中国大陆区 Apple ID（例如美区或日区），安装后再切回日常账号；
- 填写 Bridge 地址和 key；
- 最终关闭 Wi-Fi、切换移动网络测试。

不要仅凭应用名称下载同名软件。应核对链接来自 CC Pocket 官方项目页面，并核对商店中的开发者信息。

## 4. 选择 Bridge 主机并做只读检查

### 默认方案：当前个人电脑

如果用户的目标是让手机连接个人电脑上的 Codex 或 Claude Code，Bridge 就安装在当前电脑，不需要 8GPU 或其他远程服务器。Codex Desktop 应直接检查当前系统，不要要求 SSH。

Windows PowerShell：

```powershell
Get-Command node,npm,npx,codex,claude,tailscale -ErrorAction SilentlyContinue
node --version
npm --version
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object LocalPort -In 8765,8766
```

macOS/Linux：

```bash
command -v node npm npx codex claude tailscale || true
node --version 2>/dev/null || true
npm --version 2>/dev/null || true
ss -lntp 2>/dev/null | grep -E ':(8765|8766)\b' || true
```

确认 Codex 和/或 Claude Code 能在当前项目目录正常启动。若电脑已经运行健康的 Bridge，应复用它，不能为了按本文重装而中断手机连接。

### 选配方案：远程 Linux/GPU 服务器

仅当用户明确选择远程 Bridge 主机时执行本节。将 `<REMOTE_SSH>` 替换为已确认的 SSH 别名或 `user@host`：

```powershell
ssh -o BatchMode=yes -o ConnectTimeout=10 <REMOTE_SSH> "bash -lc 'whoami; hostname; uname -a; command -v node || true; node --version 2>/dev/null || true; command -v codex || true; codex --version 2>/dev/null || true; command -v ccpocket-bridge || true; ccpocket-bridge --version 2>/dev/null || true; command -v tailscale || true; tailscale version 2>/dev/null || true'"
```

在远程主机继续检查：

```bash
id
sudo -n true >/dev/null 2>&1 && echo SUDO_NONINTERACTIVE=yes || echo SUDO_NONINTERACTIVE=no
ss -lntup 2>/dev/null || true
systemctl --user --no-pager --full status ccpocket-bridge.service 2>/dev/null || true
systemctl --user --no-pager --full status tailscaled-userspace.service 2>/dev/null || true
loginctl show-user "$USER" -p Linger 2>/dev/null || true
```

记录操作系统、CPU 架构、各程序真实路径/版本、空闲端口和允许目录。远程 Linux 还需记录 systemd 能力与 `Linger` 状态。默认 Bridge 端口为 `8765`；若已占用就选其他空闲端口，不得杀死无关进程。健康的现有服务应复用，不要重装。

## 5. 在 Bridge 主机安装 Tailscale

### 默认方案：个人电脑

Codex 应打开或提供 [Tailscale 官方安装页](https://tailscale.com/docs/install)，让用户完成操作系统要求的安装确认和登录。Windows/macOS 上优先使用官方桌面客户端；Linux 有 sudo 时使用官方包。个人电脑和手机必须加入同一个 Tailnet。

安装后 Codex 获取 Bridge 主机的 Tailnet IPv4，并确认节点在线。Windows 可使用：

```powershell
tailscale status
tailscale ip -4
```

如果个人电脑与手机在同一局域网，Tailscale 通常会建立直连；离开局域网后仍使用同一个 Tailnet 地址。

### 选配方案：远程 Linux/GPU 服务器

#### 有 sudo

按当前官方 Linux 文档安装：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=<REMOTE_NODE_NAME> --accept-routes=false
```

进入用户关口 B。授权后验证：

```bash
sudo tailscale status
sudo tailscale ip -4
```

#### 无 sudo

Codex 从 Tailscale 官方 stable packages 确认当前版本和架构包，将 `tailscale`、`tailscaled` 安装到 `$HOME/.local/bin`，不要固定使用本文撰写时的版本。

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.local/state/tailscale" "$HOME/.config/systemd/user"
```

创建 `~/.config/systemd/user/tailscaled-userspace.service`：

```ini
[Unit]
Description=Tailscale userspace daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=<HOME>/.local/bin/tailscaled --tun=userspace-networking --state=<HOME>/.local/state/tailscale/tailscaled.state --socket=<HOME>/.local/state/tailscale/tailscaled.sock --port=0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

把 `<HOME>` 替换为真实绝对路径，然后：

```bash
systemctl --user daemon-reload
systemctl --user enable --now tailscaled-userspace.service
TS_SOCKET="$HOME/.local/state/tailscale/tailscaled.sock"
"$HOME/.local/bin/tailscale" --socket="$TS_SOCKET" up \
  --hostname=<REMOTE_NODE_NAME> --accept-routes=false
```

进入用户关口 B。授权后验证：

```bash
"$HOME/.local/bin/tailscale" --socket="$TS_SOCKET" status
"$HOME/.local/bin/tailscale" --socket="$TS_SOCKET" ip -4
```

userspace 模式没有常规 `tailscale0` 网卡。必须通过真实 TCP/WebSocket 测试确认 Tailnet 入站能到达 Bridge，不能只以节点在线作为成功依据。

## 6. 安装 Node.js、代理 CLI 和 Bridge

### Node.js

Bridge 当前需要 Node.js `20.18.1+`。优先安装当前受支持的 Node LTS。个人电脑使用 Node.js 官方安装包或用户现有版本管理器；远程 Linux 无 sudo 时，将官方二进制包解压到 `<HOME>/.local/node-<VERSION>`，服务使用绝对路径。

```bash
bash -lc 'command -v node; node --version; command -v npm; npm --version'
```

若 npm 错误调用旧系统 Node，使用：

```bash
<NODE_ROOT>/bin/node <NODE_ROOT>/lib/node_modules/npm/bin/npm-cli.js --version
```

### 代理 CLI：Codex 或 Claude Code

Bridge 主机至少安装一种受支持的代理 CLI。用户可只配置 Codex、只配置 Claude Code，或两者都配置；Tailscale、Bridge 服务和手机配对流程相同，差异主要在代理安装与认证。

#### Codex

先检查：

```bash
bash -lc 'command -v codex; codex --version'
```

若缺失，按当前 OpenAI Codex 官方文档安装。CC Pocket 项目当前在 macOS/Linux 推荐 standalone installer：

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

安装后确认 Bridge 服务所用环境可直接执行 `codex`，并在必要时进入用户关口 B 完成登录。不要读取或打印 `~/.codex/auth.json`。若 Bridge 安装在远程 Linux，Codex Desktop 本机可用不代表远程 CLI 已安装或已登录。

#### Claude Code

先检查：

```bash
command -v claude
claude --version
```

缺失时按当前 Claude Code 官方文档安装，并确认 Bridge 服务环境可直接执行 `claude`。

当前 CC Pocket Bridge 对 Claude 会话默认使用 `ANTHROPIC_API_KEY`。Codex 应让用户通过安全方式在 Bridge 的私有环境文件中配置该变量，不得在聊天、命令输出、Git 或报告中暴露其值。

Claude 订阅登录不是默认路径。当前 Bridge 只有在显式设置 `BRIDGE_ALLOW_CLAUDE_OAUTH=1` 时才允许订阅认证，而且 CC Pocket 项目明确提示 Anthropic 对这种架构的官方政策范围并不清晰。因此公开教程默认推荐 API key；只有用户理解该风险并明确选择时，才启用 OAuth 选项。

除上述认证差异外，Claude Code 与 Codex 共用同一个 Bridge、Tailnet 地址、手机配对、Peer Relay 和网络验证流程。手机新建任务时选择相应 Provider 即可。

### CC Pocket Bridge

```bash
npm install -g @ccpocket/bridge@latest
ccpocket-bridge --version
```

若全局 npm 不可靠，使用绝对 Node 与 `npm-cli.js`。快速启动及长期服务命令应先检查当前帮助：

```bash
npx @ccpocket/bridge@latest --help
npx @ccpocket/bridge@latest setup --help
```

官方快速启动为 `npx @ccpocket/bridge@latest`。长期运行优先使用当前可用的 `npx @ccpocket/bridge@latest setup`；若主机存在特殊 Node 路径、userspace Tailscale 或端口布局，则创建下述用户服务。

## 7. 启动并服务化 Bridge

在个人电脑上，先通过真实命令验证 Bridge：

```bash
npx @ccpocket/bridge@latest
```

确认它能发现已安装的 Codex 和/或 Claude Code，再使用当前版本提供的服务安装器：

```bash
npx @ccpocket/bridge@latest setup
```

当前项目的服务化支持 macOS launchd 和 Linux systemd。Windows 上若 `setup` 未提供合适的常驻方式，Codex 应创建用户可见、可审计的启动脚本或计划任务，并通过实际重启/登录路径验证；不能只验证脚本语法。

### 远程 Linux 的手动用户服务模板

备份旧文件，再创建 `~/.config/systemd/user/ccpocket-bridge.service`：

```ini
[Unit]
Description=CC Pocket Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOME=<HOME>
Environment=PATH=<NODE_ROOT>/bin:<HOME>/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=BRIDGE_PORT=<BRIDGE_PORT>
Environment=BRIDGE_HOST=127.0.0.1
Environment=BRIDGE_DISABLE_MDNS=1
Environment=BRIDGE_ALLOWED_DIRS=<PROJECT_DIR_1>,<PROJECT_DIR_2>
ExecStart=<ABSOLUTE_PATH_TO_CCPOCKET_BRIDGE>
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

若实测发现系统级 Tailscale 无法访问仅监听 `127.0.0.1` 的 Bridge，应依据当前官方建议调整监听接口。任何监听 `0.0.0.0` 的方案都必须启用 Bridge API key 和主机防火墙，而且绝不能把 Bridge 端口开放到公网。

推荐将随机 Bridge key 放在权限为 `0600` 的环境文件中，并用 `EnvironmentFile=<ABSOLUTE_SECRET_FILE>` 引用。若使用 Claude Code，同一个私有环境文件还应包含 `ANTHROPIC_API_KEY`，但手机端只填写 Bridge API key，绝不能填写 Anthropic key。不要将任何 key 写进本文、Git、日志或报告。若用户选择不启用 Bridge key，则 Bridge 和手机两端都留空。

```bash
systemctl --user daemon-reload
systemctl --user enable --now ccpocket-bridge.service
systemctl --user --no-pager --full status ccpocket-bridge.service
journalctl --user -u ccpocket-bridge.service -n 100 --no-pager
ss -lntp | grep ":<BRIDGE_PORT>"
```

若 `Linger=no`，用户级服务可能在退出登录后停止或无法在重启后启动。让用户联系管理员执行 `sudo loginctl enable-linger <REMOTE_USER>`；若做不到，明确记录持久性未保证。

## 8. 先完成手机与个人电脑的连接测试

先验证基础链路，避免混淆 Bridge 与 Relay 故障。Codex 获取 Bridge 主机的 Tailnet IPv4；远程 userspace 安装要加 `--socket=<TAILSCALE_SOCKET>`。

进入用户关口 D，让用户：

1. 自行从官方应用商店安装 Tailscale，登录与 Bridge 主机相同的 Tailnet，并允许 iOS/Android 创建 VPN 配置；
2. 自行通过 [CC Pocket 官方安装页](https://k9i-0.github.io/ccpocket/install/) 跳转到应用商店安装正版 CC Pocket；
3. iPhone/iPad 若使用中国大陆区 Apple ID 且提示不可用或搜索不到，应改用可下载该应用的非中国大陆区 Apple ID（例如美区或日区）完成安装；
4. 添加 Bridge：Host 为 `<BRIDGE_HOST_TAILSCALE_IP>`，Port 为 `<BRIDGE_PORT>`，URL 如需填写则为 `ws://<BRIDGE_HOST_TAILSCALE_IP>:<BRIDGE_PORT>`；
5. API key 与 Bridge 一致，未配置则留空；
6. 新建任务时选择已配置的 `Codex` 或 `Claude` Provider；
7. 保持 Tailscale 打开，加载任务列表并完成一次真实 Codex 或 Claude Code 对话。

手机不需要填写阿里云地址，也不用手动选择 Relay。Tailscale 会自动在 direct、Peer Relay 和 DERP 之间选择。Codex 同时观察：

```bash
journalctl --user -u ccpocket-bridge.service -f
```

## 9. 创建阿里云 Peer Relay（可选）

仅在手机连接个人电脑（或选配的远程 Bridge 主机）时跨网直连较慢、经常落到境外 DERP，或用户明确需要国内中继时执行。8GPU 等远程服务器不是配置阿里云 Relay 的前置条件。

### 用户创建实例

进入用户关口 C，建议用户选择：

- 轻量应用服务器或 ECS；
- 中国内地、靠近主要用户的地域，例如华南 3（广州），最终按运营商实测选择；
- 当前 Ubuntu LTS 或其他 Tailscale 支持的干净 Linux；
- 纯 Relay 通常 2 vCPU、2 GiB 内存、40 GiB 磁盘即可；
- 稳定公网 IPv4；
- 建议至少 100 Mbps，并同时核对峰值带宽与流量额度；
- 创建后先确认 SSH 与 Workbench/VNC/救援入口至少一个可用。

用户只需向 Codex提供 SSH 入口、公网 IPv4 和地域，不发送密码或私钥正文。

### 用户配置云防火墙

- 入站允许 `UDP <RELAY_PORT>`，可使用 `40000`；
- SSH `TCP 22` 尽量限制到可信来源；
- 不开放 Bridge TCP 端口到公网；
- 保留 Workbench/云助手所需规则。

### Codex 安装并配置 Relay

Peer Relay 要求 Tailscale `1.86+`，应使用当前稳定版：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

阿里云 Workbench 内部通信可能使用 `100.x` 地址，与 Tailscale 的 CGNAT 网段 `100.64.0.0/10` 重叠。默认 netfilter 规则可能令 Workbench/InnerInstanceLogin 超时。确认另有恢复入口后运行：

```bash
sudo tailscale up \
  --reset \
  --hostname=<ALIYUN_RELAY_NODE_NAME> \
  --accept-routes=false \
  --netfilter-mode=off
```

`Warning: netfilter=off; configure iptables yourself.` 是预期警告。这不等于关闭所有防火墙，而是 Tailscale 不再代管规则；Codex 必须检查并保留阿里云安全组及现有 ufw/firewalld/iptables/nftables 策略。

进入用户关口 B 完成 Tailnet 授权，然后：

```bash
sudo tailscale status
sudo tailscale debug prefs
```

确认节点在线、`RouteAll=false`、netfilter 关闭、无 exit node、无无关 subnet route。进入用户关口 C，让用户立即复测 Workbench。若仍断开，通过独立控制台执行 `sudo tailscale down` 后排查，不能反复运行默认 `tailscale up`。

启用 Relay：

```bash
sudo tailscale set \
  --relay-server-port=<RELAY_PORT> \
  --relay-server-static-endpoints="<ALIYUN_PUBLIC_IP>:<RELAY_PORT>"

sudo tailscale status
sudo tailscale debug prefs
sudo ss -lunp | grep ":<RELAY_PORT>"
```

若系统启用主机防火墙，还要添加匹配的 UDP 入站规则。不要把 Relay 配成 exit node；它不是手机的通用互联网代理。

## 10. 授权设备使用 Peer Relay

Codex 读取当前节点信息，生成最小权限 grant。优先使用经过核实的稳定 tag/group/user 选择器；简单个人 Tailnet 也可使用当前 Tailnet IP。

```json
{
  "src": [
    "<BRIDGE_HOST_TAILSCALE_IP>",
    "<OPTIONAL_PC_TAILSCALE_IP>"
  ],
  "dst": ["<ALIYUN_RELAY_TAILSCALE_IP>"],
  "app": {
    "tailscale.com/cap/relay": []
  }
}
```

进入用户关口 C，让用户把对象合并进 Access Controls 的现有 `grants` 数组。绝不能用示例覆盖整个策略。通常只需授权运行 Bridge 的个人电脑；如果 Bridge 位于远程 Linux/GPU 服务器，则授权该服务器。其他电脑需要使用 Relay 时再逐一加入 `src`，不要无依据扩大到整个 Tailnet。

## 11. 移动网络端到端验收

Bridge 主机检查（以下命令适用于 Linux；Windows/macOS 使用对应服务和端口检查）：

```bash
systemctl --user is-active ccpocket-bridge.service
ss -lntp | grep ":<BRIDGE_PORT>"
journalctl --user -u ccpocket-bridge.service -n 80 --no-pager
```

同一 Tailnet 的 Windows 电脑检查：

```powershell
Test-NetConnection <BRIDGE_HOST_TAILSCALE_IP> -Port <BRIDGE_PORT>
```

进入用户关口 D：用户关闭 Wi-Fi、保持 Tailscale 打开，用 CC Pocket 加载任务并完成真实对话。Codex 在 Bridge 主机执行数次：

```bash
tailscale ping <PHONE_NODE_NAME_OR_IP>
tailscale status
tailscale debug peer-relay-servers
```

userspace 安装需加 `--socket=<TAILSCALE_SOCKET>`。

- `direct`：已直连，通常最好；
- `peer-relay(<ALIYUN_PUBLIC_IP>:<RELAY_PORT>...)`：阿里云 Relay 已选中；
- `via DERP(...)`：检查 UDP 端口、云/系统防火墙、grant、版本、endpoint 和 Relay 在线状态；
- 首次 ping 可能先经 DERP 再发现更优路径，应观察多次结果。

低延迟不等于高带宽。需要测速时，在用户同意后用 `iperf3` 或等价工具分别测试远程主机到阿里云、手机到阿里云及端到端 Bridge，不能根据 ping 推断吞吐。

## 12. 常见故障

| 现象 | 优先检查与处理 |
|---|---|
| 手机找不到 Bridge | Tailscale 在线状态、Tailnet IP/端口、listener、API key |
| 卡在“加载会话列表” | Bridge 主机上的 Codex/Claude CLI PATH、认证、版本兼容及子进程日志；不要先归咎 Relay |
| HTTP 404 | Bridge 是 WebSocket 服务，用 TCP/WebSocket/手机实测 |
| `Cannot find module 'node:path'` | npm 调用了旧 Node，使用绝对 Node + `npm-cli.js` |
| `invalid token` | 手机与 Bridge key 不一致，保持 key 持久化后重新配对 |
| Workbench 在 `tailscale up` 后超时 | 从独立控制台恢复，使用 `--netfilter-mode=off` 并自行管理防火墙 |
| Relay 一直未选中 | 检查 UDP、安全组/主机防火墙、grant、版本、endpoint |
| 退出 SSH 后服务停止 | `Linger=no`；请管理员启用或明确记录限制 |
| 二维码含局域网 IP | 手动填 Tailnet IP，或核对当前 `BRIDGE_PUBLIC_WS_URL` 配置 |
| Codex skills 文件缺失 | 与网络分开诊断；若会话可加载，不要为此重配 Tailscale |

## 13. 回滚

- Bridge 升级失败：用相同 npm prefix 安装已记录的旧版本，恢复 service 文件，只重启 Bridge。
- userspace Tailscale 失败：停止其用户服务；不要随意删除 state 文件，否则节点身份改变并需重新授权。
- 阿里云 Workbench/网络失败：通过独立控制台运行 `sudo tailscale down`。
- 停用 Relay：先删除对应 grant，再运行 `sudo tailscale set --relay-server-port=""`，最后关闭云防火墙 UDP 端口。
- 未经用户明确确认，不删除阿里云实例。

## 14. 完成标准与报告

只有以下项目已验证或明确标记未完成，Codex 才能结束：Bridge 主机的 Node、Codex和/或Claude Code、Bridge、Tailscale 路径与版本；Bridge 监听与允许目录；认证策略正确；手机加载任务并完成所选 Provider 的真实对话；如启用阿里云，则 Workbench 可用且 Relay UDP/endpoint/grant 有效；移动网路径已识别；服务持久性已证明或限制已报告；无秘密泄露。

```markdown
## 部署结果

- 状态：成功 / 部分成功 / 阻塞
- Bridge 主机类型：个人电脑 / 远程服务器（选配）
- Bridge 主机与 Tailnet 节点：
- Node / Codex / Claude Code / Bridge / Tailscale 版本与路径：
- 已验证 Provider：Codex / Claude / 两者
- Bridge 监听地址、端口与允许目录：
- Bridge 认证：已启用 / 未启用（不展示密钥）
- 阿里云地域与 Relay 公网端点：
- Workbench 复测：
- Peer Relay grant 范围：
- 手机 CC Pocket 实测：
- 移动网络路径及延迟/带宽观察：
- 服务持久性：
- 备份：
- 剩余风险或用户动作：
```

## 15. 参考资料

- [CC Pocket 中文 README](https://github.com/K9i-0/ccpocket/blob/main/README.zh-CN.md)
- [CC Pocket 安装页](https://k9i-0.github.io/ccpocket/install/)
- [CC Pocket Claude 认证排错](https://github.com/K9i-0/ccpocket/blob/main/docs/auth-troubleshooting.md)
- [Tailscale Linux 安装](https://tailscale.com/docs/install/linux)
- [Tailscale iOS 安装](https://tailscale.com/docs/install/ios)
- [Tailscale Peer Relay](https://tailscale.com/docs/features/peer-relay)
- [Tailscale CLI](https://tailscale.com/kb/1080/cli)
- [OpenAI Developers](https://developers.openai.com/)

版本、参数和界面会变化。每次复用时，Codex 都必须重新核对官方资料，并以现场端到端验证为准。
