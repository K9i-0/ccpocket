# @ccpocket/bridge

Bridge server that connects [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) and [Codex CLI](https://github.com/openai/codex) to mobile devices via WebSocket.

This is the server component of [ccpocket](https://github.com/K9i-0/ccpocket) — a mobile client for Claude Code and Codex.

## Quick Start

```bash
npx @ccpocket/bridge@latest
```

A QR code will appear in your terminal. Scan it with the ccpocket mobile app to connect.

> Warning
> Versions older than `1.25.0` are deprecated and should not be used for new installs due to potential Anthropic policy concerns around OAuth-based usage.
> Upgrade to `>=1.25.0` and use `ANTHROPIC_API_KEY` instead of OAuth.

## Installation

```bash
# Run directly (no install needed)
npx @ccpocket/bridge@latest

# Or install globally
npm install -g @ccpocket/bridge
ccpocket-bridge
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `BRIDGE_PORT` | `8765` | WebSocket port |
| `BRIDGE_HOST` | `0.0.0.0` | Bind address |
| `BRIDGE_API_KEY` | (none) | API key authentication (enabled when set) |
| `BRIDGE_PUBLIC_WS_URL` | (none) | Public `ws://` / `wss://` URL used for startup deep link and QR code |
| `BRIDGE_DEMO_MODE` | (none) | Demo mode: hide Tailscale IPs and API key from QR code / logs |
| `BRIDGE_RECORDING` | (none) | Enable session recording for debugging (enabled when set) |
| `BRIDGE_DISABLE_MDNS` | (none) | Disable mDNS auto-discovery advertisement (enabled when set) |
| `HTTPS_PROXY` | (none) | Proxy for outgoing fetch requests (`http://`, `socks5://`) |

```bash
# Example: custom port with API key
BRIDGE_PORT=9000 BRIDGE_API_KEY=my-secret npx @ccpocket/bridge@latest

# Example: expose Bridge through a reverse proxy / ngrok
BRIDGE_PUBLIC_WS_URL=wss://example.ngrok-free.app npx @ccpocket/bridge@latest

# Example: same setting via CLI flag
ccpocket-bridge --public-ws-url wss://example.ngrok-free.app

# Example: disable mDNS advertisement
BRIDGE_DISABLE_MDNS=1 npx @ccpocket/bridge@latest
# or via CLI flag
ccpocket-bridge --no-mdns
```

When `BRIDGE_PUBLIC_WS_URL` is set, the startup deep link and terminal QR code
use that public URL instead of the LAN address. This is useful when the Bridge
is reachable through a reverse proxy, tunnel, or public domain.

Without it, the printed QR code is LAN-oriented by default and typically encodes
something like `ws://192.168.x.x:8765`.

## Requirements

- Node.js v18+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) and/or [Codex CLI](https://github.com/openai/codex)

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

[MIT](../../LICENSE)
