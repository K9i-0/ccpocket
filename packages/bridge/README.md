# @ccpocket/bridge

Bridge server that connects [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) to mobile devices via WebSocket.

This is the server component of [ccpocket](https://github.com/K9i-0/ccpocket) — a mobile client for Claude Code.

## Quick Start

```bash
npx @ccpocket/bridge
```

A QR code will appear in your terminal. Scan it with the ccpocket mobile app to connect.

## Installation

```bash
# Run directly (no install needed)
npx @ccpocket/bridge

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

```bash
# Example: custom port with API key
BRIDGE_PORT=9000 BRIDGE_API_KEY=my-secret npx @ccpocket/bridge
```

## Requirements

- Node.js v18+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and configured (`claude` command available)

## Architecture

```
Mobile App ←WebSocket→ Bridge Server ←stdio→ Claude Code CLI
```

The bridge server spawns and manages Claude Code CLI processes, translating WebSocket messages to/from the CLI's stdio interface. It supports multiple concurrent sessions.

## License

[MIT](../../LICENSE)
