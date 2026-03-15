# Authentication Troubleshooting

CC Pocket uses Claude Code's OAuth tokens stored on the Bridge machine.
These tokens can expire or be revoked — here's how to fix common issues.

## Quick Fix

Run this on the **Bridge machine** (Mac / Linux):

```bash
claude auth login
```

Follow the prompts to re-authenticate with Anthropic.

## Detailed Steps (Headless / SSH)

If the Bridge machine is headless (e.g. Mac mini accessed via SSH or Tailscale):

1. **Connect via terminal** — Use a terminal app (Moshi, Termius, Blink, etc.) to SSH into the Bridge machine
2. **Launch Claude** — Run `claude` to start Claude Code interactively
3. **Login** — Type `/login` inside Claude Code
   - `claude auth login` from the shell also works, but `/login` inside Claude Code is more reliable
4. **Open the URL** — Copy the authentication URL and open it in Safari or any browser on your phone/PC
5. **Authenticate** — Complete the Anthropic OAuth flow in the browser
6. **Paste the token** — Copy the resulting token and paste it back into the terminal

After login, CC Pocket will automatically pick up the new token on the next request.

## Why Does This Happen?

- **Token expiry** — OAuth access tokens have a limited lifetime (typically a few hours). CC Pocket automatically refreshes them, but the refresh token itself can also expire
- **Claude Code updates** — Major Claude Code updates sometimes invalidate existing tokens
- **Server-side revocation** — Anthropic may revoke tokens for security reasons

## Environment Variable Alternative

Instead of OAuth, you can set an API key on the Bridge machine:

```bash
# In your shell profile or launchd plist
export ANTHROPIC_API_KEY="sk-ant-..."
```

API key authentication never expires (unless revoked) and doesn't require periodic login.
