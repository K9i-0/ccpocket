# RevenueCat Setup

## Current Monetization Shape

- Model: OSS support without feature gating
- Brand: `Pro` is not used; use `Supporter`
- One-time products:
  - `$5 Coffee`
  - `$10 Lunch`
- Monthly product:
  - `Supporter $10/mo`

This matches the product reality better than a paid-feature plan and keeps user expectations aligned.

## RevenueCat MCP

RevenueCat provides a remote MCP server:

- URL: `https://mcp.revenuecat.ai/mcp`

Recommended for Codex:

- Add RevenueCat as a remote MCP server in Codex
- Authenticate with OAuth when prompted
- Use an API v2 secret key only if OAuth is not available in the client flow

Codex config example:

```toml
[mcp_servers.revenuecat]
url = "https://mcp.revenuecat.ai/mcp"
```

Notes:

- Codex app, CLI, and IDE extension share MCP settings
- If key-based auth is needed later, use a dedicated RevenueCat API v2 key for MCP
- Use a write-enabled key only when creating or mutating catalog objects

## First RevenueCat Objects To Create

Suggested initial catalog:

- Entitlement: `supporter`
- Offering: `default`
- Packages:
  - one-time `$5 Coffee`
  - one-time `$10 Lunch`
  - monthly `Supporter $10/mo`

Suggested store-facing naming:

- `Coffee`
- `Lunch`
- `Supporter`

Suggested internal identifiers:

- `supporter`
- `support_coffee_5`
- `support_lunch_10`
- `supporter_monthly_10`

## Useful MCP Prompts

After MCP is connected, these are the first useful prompts:

```text
Show me my RevenueCat projects and apps.
```

```text
Create an entitlement called "supporter" with display name "Supporter".
```

```text
Create a default offering for my app and show me its packages.
```

```text
Show me the complete configuration for my app including entitlements, offerings, packages, and products.
```

## Next Implementation Steps

1. Create store products in App Store Connect and Google Play Console.
2. Mirror those products into RevenueCat.
3. Add the Flutter RevenueCat SDK to `apps/mobile`.
4. Expose supporter status in app state.
5. Add minimal supporter UI:
   - settings badge
   - optional app bar label
   - supporter icon treatment
6. Keep the app fully functional for non-supporters.
