# Changelog

All notable changes to `@ccpocket/bridge` will be documented in this file.

## [0.2.0] - 2026-02-22

### Added
- Prompt history backup & restore via Bridge Server
- `BRIDGE_HIDE_IP` option to mask IP addresses in QR code and logs
- Multiple image attachments per message support
- i18n push notifications with per-device locale (English/Japanese)
- ExitPlanMode special handling for push notifications
- Session-targeted push notification improvements with markdown code blocks

### Fixed
- Clear-context session switch and routing stability

### Changed
- Updated `@anthropic-ai/claude-agent-sdk` 0.2.29 → 0.2.50
- Updated `@openai/codex-sdk` 0.101.0 → 0.104.0

## [0.1.1] - 2025-06-17

### Changed
- Prepared metadata for public release and npm publish

## [0.1.0] - 2025-06-17

### Added
- Initial release
- WebSocket bridge between Claude Code CLI / Codex CLI and mobile devices
- Multi-session management
- Tool approval/rejection routing
- QR code connection with mDNS auto-discovery
- Push notifications via Firebase Cloud Messaging
- API key authentication support
