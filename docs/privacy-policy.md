# Privacy Policy

**Last updated: 2025-06-19**

## Overview

ccpocket ("the App") is a mobile client that connects to a self-hosted Bridge Server to interact with coding agents (Claude Code, Codex). The App is designed with privacy in mind — your data stays on your devices and your server.

## Data Collection

### What we collect

- **Firebase Anonymous Authentication**: The App uses Firebase Anonymous Auth to enable push notifications. This generates an anonymous user ID — no personal information (email, name, phone number) is collected.
- **FCM Token**: A device token for push notifications is stored in Firebase Firestore, associated only with the anonymous user ID.

### What we do NOT collect

- No personal information (name, email, phone number, etc.)
- No conversation content or session data
- No usage analytics or tracking
- No location data
- No contacts, photos, or other device data

## Data Storage

- **On your device**: Connection settings, session history, and prompt history are stored locally on your device using SharedPreferences and SQLite.
- **On your Bridge Server**: Session data and conversation history are stored on your self-hosted Bridge Server. You control this server entirely.
- **Firebase**: Only the anonymous user ID and FCM token are stored in Firebase Firestore for push notification delivery.

## Push Notifications

Push notifications are sent through Firebase Cloud Messaging (FCM) when your Bridge Server has updates (e.g., tool approval requests, session results). Notification content is relayed through Firebase Cloud Functions. You can disable push notifications per server in the App settings.

## Third-Party Services

| Service | Purpose | Data shared |
|---------|---------|-------------|
| Firebase Authentication | Anonymous auth for push notifications | Anonymous user ID |
| Firebase Cloud Messaging | Push notification delivery | FCM device token |
| Firebase Firestore | FCM token storage | Anonymous user ID + FCM token |

No data is shared with advertisers or data brokers.

## Data Retention

- **Local data**: Retained until you uninstall the App or clear app data.
- **Firebase data**: Anonymous auth and FCM tokens are automatically cleaned up when the token expires or the app is uninstalled.

## Your Rights

- You can disable push notifications at any time in the App settings or your device settings.
- You can delete all local data by uninstalling the App.
- You control your Bridge Server and can delete all server-side data at any time.

## Children's Privacy

The App is not directed at children under 13 and does not knowingly collect data from children.

## Changes to This Policy

We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated date.

## Contact

If you have questions about this Privacy Policy, please open an issue on [GitHub](https://github.com/K9i-0/ccpocket/issues).
