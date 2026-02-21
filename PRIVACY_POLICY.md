# Privacy Policy

**Last updated: February 21, 2026**

## Overview

ccpocket ("the App") is a mobile remote client for Claude Code and Codex. This privacy policy explains what data the App collects, how it is used, and your rights regarding that data.

This app is not affiliated with, endorsed by, or associated with Anthropic or OpenAI.

## Data Collection

### Data We Do NOT Collect

- No analytics or telemetry
- No crash reporting to external services
- No personal information (name, email, phone number)
- No usage tracking or behavioral data
- No advertising identifiers
- No location data

### Data Stored Locally on Your Device

The following data is stored only on your device and is never transmitted to us or any third party:

- **App preferences**: Theme, language, and notification settings
- **Connection settings**: Bridge Server URLs, machine configurations
- **Prompt history**: Your previous prompts, stored in a local database
- **Chat drafts**: Unsent message text per session
- **Credentials**: API keys and SSH credentials, stored in encrypted secure storage

### Data Transmitted to Your Bridge Server

When you connect to your self-hosted Bridge Server, the App communicates via WebSocket to send and receive:

- Chat messages and prompts
- Tool approval/rejection responses
- Session management commands

This communication occurs directly between your device and your own server. No data passes through our servers.

### Firebase Cloud Messaging (Push Notifications)

If you enable push notifications, the App uses:

- **Firebase Anonymous Authentication**: To generate an anonymous identifier for push notification delivery. No personal information is associated with this identifier.
- **Firebase Cloud Messaging (FCM)**: To receive push notifications when your coding agent requires approval or completes a task.

You can disable push notifications at any time in the App settings. No notification content is stored by Firebase beyond delivery.

## Third-Party Services

| Service | Purpose | Data Shared |
|---------|---------|-------------|
| Firebase (Google) | Push notifications only | Anonymous device token |

No other third-party services are used.

## Data Security

- Sensitive credentials (API keys, SSH keys) are stored using platform-native encrypted storage (iOS Keychain / Android Keystore)
- All Bridge Server communication can be secured via Tailscale VPN or local network
- No data is stored on external servers controlled by the developer

## Children's Privacy

The App is not directed at children under 13 and does not knowingly collect data from children.

## Your Rights

Since ccpocket stores data only on your device:

- **Delete your data**: Uninstall the App to remove all locally stored data
- **View your data**: All stored data is accessible through the App's settings
- **Disable notifications**: Toggle push notifications off in settings to stop all Firebase communication

## Changes to This Policy

We may update this privacy policy from time to time. Changes will be posted to this page with an updated date.

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/K9i-0/ccpocket/issues

## Open Source

ccpocket is open source. You can review the complete source code at:
https://github.com/K9i-0/ccpocket
