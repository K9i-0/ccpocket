# Security Policy

## Supported versions

| Component | Version | Supported |
|-----------|---------|-----------|
| Bridge Server (`@ccpocket/bridge`) | latest | Yes |
| Mobile App | latest | Yes |

## Reporting a vulnerability

If you discover a security vulnerability, **please do not open a public issue**.

Instead, report it privately via [GitHub Security Advisories](https://github.com/K9i-0/ccpocket/security/advisories/new).

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Security considerations

CC Pocket's Bridge Server exposes filesystem operations over WebSocket. Key security measures include:

- **`BRIDGE_ALLOWED_DIRS`**: Restricts which directories can be accessed
- **`BRIDGE_API_KEY`**: Optional API key authentication for connections
- **Path validation**: All paths are resolved and checked against allowed directories before any operation
- **Network security**: Tailscale or local network recommended for remote access; no data is sent to external servers
- **Credential storage**: API keys and SSH keys are stored using platform-native encrypted storage (iOS Keychain / Android Keystore)
