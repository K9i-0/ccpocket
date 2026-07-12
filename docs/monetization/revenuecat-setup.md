# RevenueCat Setup

## Current Monetization Shape

- Model: OSS support without feature gating
- Brand: `Pro` is not used; use `Supporter`
- One-time products:
  - `$3 Snack Support`
  - `$5 Coffee`
  - `$10 Lunch`
- Monthly product:
  - `Supporter $3/mo`
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
  - one-time `$3 Snack Support`
  - one-time `$5 Coffee`
  - one-time `$10 Lunch`
  - monthly `Supporter $3/mo`
  - monthly `Supporter $10/mo`

Store-facing naming:

- `Snack Support` / `おやつで応援`
- `Drink Support`
- `Lunch Support`
- `Supporter Monthly`
- `Supporter Monthly Plus`

Suggested internal identifiers:

- `supporter`
- `support_snack_3`
- `support_coffee_5`
- `support_lunch_10`
- `supporter_monthly_3_ios` (App Store)
- `supporter_monthly_10:monthly-3` (Google Play base plan)
- `supporter_monthly_10`

RevenueCat package identifiers:

- `$rc_custom_snack`
- `$rc_custom_monthly_3`
- `$rc_custom_coffee`
- `$rc_custom_lunch`
- `$rc_monthly`

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

## Store Rollout Checklist

- [x] Create the $2.99 one-time and monthly products in App Store Connect.
- [x] Create and activate the $2.99 one-time product and monthly base plan in Google Play Console.
- [ ] Import the two products into RevenueCat and add `$rc_custom_snack` and `$rc_custom_monthly_3` to the `default` offering.
- [x] Map package type, price ordering, and the active monthly base plan in the Flutter app.
- [x] Keep the app fully functional for non-supporters.
