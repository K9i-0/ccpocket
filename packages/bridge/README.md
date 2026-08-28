# @ccpocket/bridge

Bridge server that connects Claude sessions powered by the [Claude Agent SDK](https://code.claude.com/docs/en/agent-sdk) and [Codex CLI](https://github.com/openai/codex) to mobile devices via WebSocket.

This is the server component of [ccpocket](https://github.com/K9i-0/ccpocket) — a mobile client for Claude and Codex.

## Quick Start

```bash
npx @ccpocket/bridge@latest
```

A QR code will appear in your terminal. Scan it with the ccpocket mobile app to connect.

Claude sessions use `ANTHROPIC_API_KEY` by default. Subscription authentication
through the Bridge machine's Claude Code login is available only after explicit
opt-in with `BRIDGE_ALLOW_CLAUDE_OAUTH=1`; see
[Claude Subscription Authentication](#claude-subscription-authentication-explicit-opt-in).
Hosts that run Claude Code on Amazon Bedrock need neither of those; see
[Claude on Amazon Bedrock](#claude-on-amazon-bedrock).

## Installation

```bash
# Recommended: run the latest Bridge directly
npx @ccpocket/bridge@latest

# Optional: install globally
npm install -g @ccpocket/bridge
ccpocket-bridge

# Show CLI help or version
ccpocket-bridge --help
ccpocket-bridge --version
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `BRIDGE_PORT` | `8765` | WebSocket port |
| `BRIDGE_HOST` | `0.0.0.0` | Bind address |
| `BRIDGE_API_KEY` | (none) | API key authentication (enabled when set) |
| `BRIDGE_ALLOWED_DIRS` | `$HOME` | Comma-separated list of project directories the Bridge may access; set exactly to `*` to allow any directory |
| `BRIDGE_PUBLIC_WS_URL` | (none) | Public `ws://` / `wss://` URL used for startup deep link and QR code |
| `BRIDGE_CODEX_APP_SERVER_MODE` | `private` | Experimental Codex app-server mode: `private`, `managed`, or `external` |
| `BRIDGE_CODEX_SHARED_APP_SERVER_URL` | `ws://127.0.0.1:8767` in `managed` mode | Experimental shared Codex app-server URL for Codex CLI co-presence |
| `BRIDGE_CODEX_ASSIST_MODEL` | `gpt-5.6-luna` | Codex model used for auto-rename and commit-message assist calls |
| `BRIDGE_CODEX_ASSIST_REASONING_EFFORT` | `none` | Reasoning effort used for Codex assist calls |
| `BRIDGE_DEMO_MODE` | (none) | Demo mode: hide Tailscale IPs and API key from QR code / logs |
| `BRIDGE_RECORDING` | (none) | Enable session recording for debugging (enabled when set) |
| `BRIDGE_DISABLE_MDNS` | (none) | Disable mDNS auto-discovery advertisement (macOS disables it automatically) |
| `BRIDGE_ALLOW_CLAUDE_OAUTH` | (none) | Set exactly to `1` to explicitly enable experimental Claude subscription authentication |
| `BRIDGE_PROMPT_HISTORY_FILE` | `$HOME/.ccpocket/prompt-history-v2.json` | Custom prompt history store path |
| `BRIDGE_RECENT_SESSIONS_PROFILE` | (none) | Log recent-session index timing when set to `1` or `true` |
| `BRIDGE_FILE_LIST_MAX_ENTRIES` | `5000` | Maximum file and directory entries returned to a client; non-positive or invalid values use the default |
| `BRIDGE_FILE_LIST_MAX_BYTES` | `524288` | Maximum serialized path bytes returned in a client file list; non-positive or invalid values use the default |
| `BRIDGE_DELTA_BATCH_MS` | `100` | Milliseconds to batch streaming deltas per connected client; set to `0` to disable batching |
| `BRIDGE_DELTA_BATCH_MAX_CHARS` | `4096` | Maximum Unicode characters per batched streaming payload; non-positive or invalid values use the default |
| `DIFF_IMAGE_AUTO_DISPLAY_KB` | `1024` (1 MB) | Auto-display diff images up to this size, in KB |
| `DIFF_IMAGE_MAX_SIZE_MB` | `5` (5 MB) | Maximum diff image size available for on-demand loading, in MB |
| `ANTHROPIC_API_KEY` | (none) | Claude Agent SDK API key; recommended for predictable third-party product usage |
| `ANTHROPIC_AUTH_TOKEN` | (none) | Advanced Claude SDK auth token; prefer `ANTHROPIC_API_KEY` |
| `CLAUDE_CODE_USE_BEDROCK` | (none) | Claude Code setting; when enabled, Claude sessions run on Amazon Bedrock and no Anthropic credential is required |
| `AWS_REGION` / `AWS_PROFILE` | (none) | Bedrock region (required) and optional AWS credential profile read by Claude Code |
| `OPENAI_API_KEY` | (none) | Codex API key; Codex can also use `~/.codex/auth.json` |
| `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` | (none) | Proxy for outgoing fetch requests (`http://`, `https://`, `socks4://`, `socks5://`) |

Lowercase proxy variables (`https_proxy`, `http_proxy`, `all_proxy`) are also
supported. When `BRIDGE_PROMPT_HISTORY_FILE` is not set and `BRIDGE_PORT` is not
`8765`, prompt history is stored in
`$HOME/.ccpocket/prompt-history-v2-<port>.json`.

Push relay uses Firebase Anonymous Auth automatically; no FCM environment
variables are required.

## Claude Subscription Authentication (Explicit Opt-In)

Anthropic's [Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)
page says its Commercial Terms do not prevent a platform from hosting the
unmodified Claude Code binary when each end user signs in with their own
subscription or other credentials, subject to the conditions listed there.
CC Pocket similarly runs Anthropic's official Agent SDK on the user's Bridge
machine and delegates credential loading to the host's Claude Code environment.
CC Pocket does not copy, store, or refresh Claude OAuth credentials itself.

Running Claude Code on a user's computer and controlling it remotely is also a
common pattern among tools such as [OpenClaw](https://github.com/openclaw/openclaw/blob/main/docs/concepts/oauth.md),
[Happy](https://github.com/slopus/happy), and
[Termopus](https://github.com/Termopus/termopus), although their exact
implementations differ from CC Pocket.

However, Anthropic's [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk)
also says that, unless previously approved, third-party products should use API
keys rather than offer Claude.ai login or subscription rate limits. The scope of
these two statements is not clear for CC Pocket's architecture, so subscription
authentication may be restricted or stop working in the future.

To avoid that uncertainty, use `ANTHROPIC_API_KEY`. If you understand the risk
and want to use the Bridge machine's Claude Code subscription login, enable it
explicitly and restart Bridge:

```bash
BRIDGE_ALLOW_CLAUDE_OAUTH=1 npx @ccpocket/bridge@latest
```

Only the exact value `1` enables this behavior. Service setup preserves the
setting when it is present in the setup environment.

```bash
# Example: custom port with API key
BRIDGE_PORT=9000 BRIDGE_API_KEY=my-secret npx @ccpocket/bridge@latest

# Example: allow projects outside $HOME
BRIDGE_ALLOWED_DIRS="$HOME,/scratch/$USER" npx @ccpocket/bridge@latest

# Example: expose Bridge through a reverse proxy / ngrok
BRIDGE_PUBLIC_WS_URL=wss://example.ngrok-free.app npx @ccpocket/bridge@latest

# Example: same setting via CLI flag
ccpocket-bridge --public-ws-url wss://example.ngrok-free.app

# Example: disable mDNS advertisement
BRIDGE_DISABLE_MDNS=1 npx @ccpocket/bridge@latest
# or via CLI flag
ccpocket-bridge --no-mdns

# Example: use an assist model provided by a custom Codex gateway
BRIDGE_CODEX_ASSIST_MODEL=gpt-oss:20b-cloud \
BRIDGE_CODEX_ASSIST_REASONING_EFFORT=none \
npx @ccpocket/bridge@latest
```

When `BRIDGE_PUBLIC_WS_URL` is set, the startup deep link and terminal QR code
use that public URL instead of the LAN address. This is useful when the Bridge
is reachable through a reverse proxy, tunnel, or public domain.

Without it, the printed QR code is LAN-oriented by default and typically encodes
something like `ws://192.168.x.x:8765`.

## Claude on Amazon Bedrock

Claude Code and the Claude Agent SDK can run against
[Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock) instead of the
first-party Anthropic API. Bedrock requests are signed with AWS credentials, so
the Bridge requires neither `ANTHROPIC_API_KEY` nor the subscription opt-in:

```bash
CLAUDE_CODE_USE_BEDROCK=1 \
AWS_REGION=us-west-2 \
npx @ccpocket/bridge@latest

# AWS_PROFILE optionally selects a specific credential profile. AWS_REGION is
# still required because Claude Code does not read it from the AWS profile:
CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-west-2 AWS_PROFILE=my-profile \
  npx @ccpocket/bridge@latest
```

AWS credentials remain on the Bridge host and are resolved through the normal
AWS credential provider chain — environment credentials, `AWS_PROFILE`,
`~/.aws/credentials`, `~/.aws/config`, IAM roles, SSO, and EC2/ECS credentials.
CC Pocket has no AWS credential store of its own. The Bridge parses the Claude
settings file to detect the Bedrock flag and region, but does not access or
persist credential fields, log credential values, or send AWS configuration to
the mobile app. Claude Code resolves credentials on the Bridge host.

The Bridge also recognizes Bedrock when Claude Code's `/setup-bedrock` wizard
wrote `CLAUDE_CODE_USE_BEDROCK` into the `env` block of the Claude Code user
settings file (`~/.claude/settings.json`, or `$CLAUDE_CONFIG_DIR/settings.json`).
Only the Bedrock flag and `AWS_REGION` are accessed from the parsed settings.

Bedrock normally authenticates without Claude OAuth. If Claude Code reports an
OAuth authentication source despite the Bedrock flag, the Bridge still requires
`BRIDGE_ALLOW_CLAUDE_OAUTH=1` and rejects the session without that explicit
opt-in.

Model IDs, region resolution, and IAM permissions follow the Claude Code
documentation. CC Pocket adds no Bedrock-specific configuration of its own.

Verify the result with the doctor command:

```bash
npx @ccpocket/bridge@latest doctor
```

The Claude Code CLI line then reads
`Amazon Bedrock configured; AWS credentials not verified`. Doctor reports the
configuration only — it does not call AWS, so it never claims that credentials
work. If `AWS_REGION` is missing, doctor warns instead of reporting Bedrock as
configured.

### Amazon Bedrock with the background service

`ccpocket-bridge setup` persists only the `BRIDGE_*` settings listed below, so
make the Bedrock configuration reachable from the service environment:

- macOS launchd: the generated plist starts the Bridge through a login shell
  (`zsh -li`), so `export CLAUDE_CODE_USE_BEDROCK=1` and any `AWS_*` variables in
  `~/.zprofile` / `~/.zshrc` are inherited.
- Linux systemd: the generated unit starts the Bridge through a login shell
  (`bash -lc`), so exports in `~/.profile` / `~/.bash_profile` are inherited.
  `Environment=` lines added to
  `~/.config/systemd/user/ccpocket-bridge.service` also work, but re-running
  setup rewrites that file.
- Either platform: keeping the configuration in the Claude Code user settings
  `env` block works too, and survives re-running setup.

## Persistent service setup

Register the Bridge as a user-level background service:

```bash
npx @ccpocket/bridge@latest setup
```

Setup supports macOS launchd and Linux systemd. It persists the Bridge settings
that affect startup:

- `BRIDGE_PORT` / `--port`
- `BRIDGE_HOST` / `--host`
- `BRIDGE_API_KEY` / `--api-key`
- `BRIDGE_ALLOWED_DIRS`
- `BRIDGE_PUBLIC_WS_URL` / `--public-ws-url`
- `BRIDGE_DISABLE_MDNS` / `--no-mdns`
- `BRIDGE_ALLOW_CLAUDE_OAUTH`
- `BRIDGE_CODEX_APP_SERVER_MODE` / `--codex-app-server-mode`
- `BRIDGE_CODEX_SHARED_APP_SERVER_URL` / `--codex-shared-app-server-url`
- `BRIDGE_CODEX_ASSIST_MODEL`
- `BRIDGE_CODEX_ASSIST_REASONING_EFFORT`

Example:

```bash
BRIDGE_ALLOWED_DIRS="$HOME,/scratch/$USER" \
BRIDGE_API_KEY=my-secret \
npx @ccpocket/bridge@latest setup
```

To persist the explicit subscription-authentication opt-in:

```bash
BRIDGE_ALLOW_CLAUDE_OAUTH=1 npx @ccpocket/bridge@latest setup
```

Custom gateway users can persist assist overrides in the same way:

```bash
BRIDGE_CODEX_ASSIST_MODEL=gpt-oss:20b-cloud \
BRIDGE_CODEX_ASSIST_REASONING_EFFORT=none \
npx @ccpocket/bridge@latest setup
```

On Linux, setup gives standalone Codex installs priority by including
`$HOME/.local/bin` before npm-managed Node paths in the service `PATH`.

## Experimental: Join a CC Pocket Codex Session from Codex CLI

By default, each Codex session uses a private app-server. To let Codex CLI join
the same live thread that CC Pocket started, run the Bridge with shared
app-server mode:

```bash
BRIDGE_CODEX_APP_SERVER_MODE=managed \
BRIDGE_CODEX_SHARED_APP_SERVER_URL=ws://127.0.0.1:8767 \
npx @ccpocket/bridge@latest
```

Then start or resume a Codex session from CC Pocket. When the session is ready,
the session screen can copy a session-specific command like:

```bash
codex resume <thread-id> --remote ws://127.0.0.1:8767
```

Run that command in a terminal on the same machine as the Bridge. The
`127.0.0.1` address is for the Mac/Linux machine running the Bridge and Codex
CLI, not for the phone.

Modes:

- `private`: default behavior. No Codex CLI co-presence.
- `managed`: Bridge starts one local WebSocket Codex app-server and shares it
  with Codex CLI.
- `external`: Bridge connects to an already-running app-server. In this mode,
  `BRIDGE_CODEX_SHARED_APP_SERVER_URL` is required.

This is experimental and currently targets Codex CLI co-presence only. Codex App
compatibility is not guaranteed and may use a different integration model in the
future.

## Requirements

- Node.js v20.18.1+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) and/or [Codex CLI](https://github.com/openai/codex)

Current Codex CLI docs recommend the standalone installer for macOS/Linux:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

## Health Check

Run the built-in doctor command to verify your environment:

```bash
npx @ccpocket/bridge@latest doctor
```

It checks Node.js, Git, CLI providers, macOS permissions (Screen Recording, Keychain), network connectivity, and more.

## Architecture

```
Mobile App ←WebSocket→ Bridge Server ←stdio→ Claude Code CLI
```

The bridge server spawns and manages Claude Code CLI processes, translating WebSocket messages to/from the CLI's stdio interface. It supports multiple concurrent sessions.

## License

This package is MIT licensed as part of CC Pocket. See [LICENSE](./LICENSE) and
the repository root [LICENSE](../../LICENSE).
