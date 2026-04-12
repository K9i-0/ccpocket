# Supporter

CC Pocket is fully usable for free.

`Supporter` exists as an optional way to support ongoing development of the app. It does not unlock core features or change how the app works.

## Why It Works This Way

CC Pocket is built around a self-hosted Bridge and a minimal-account design.

- The app does not require a dedicated CC Pocket account to connect to your machine.
- It avoids collecting a stable cross-platform identity for monetization.
- Only the minimum operational data needed for features like notifications is used.

This is a deliberate product choice. The goal is to keep CC Pocket usable without adding a hosted account system just to make purchases work.

## How Restore Works

Purchase restore is store-scoped.

- On Apple platforms, restore works with the same Apple ID.
- On Android, restore works with the same Google account.

If you reinstall the app or move to another device on the same store account, restore should work there.

## Why iOS And Android Are Not Shared

CC Pocket does not maintain its own cross-platform customer account.

That means the app has no stable way to identify that an iPhone user and an Android user are the same person across stores. Cross-platform sharing would require CC Pocket to introduce an app-specific account or another long-lived user identifier.

That tradeoff is not a fit for the current product direction.

As a result:

- An Apple purchase is restored through Apple.
- A Google Play purchase is restored through Google Play.
- Support status is not shared between iOS and Android.

## What Supporter Includes

Supporter is intentionally small.

- A Supporter badge in the app
- A simple way to support the project financially
- No feature gating for the main app experience

## FAQ

### Is CC Pocket paywalled?

No. The app remains fully usable without Supporter.

### Can I restore purchases after reinstalling?

Yes, as long as you use the same Apple ID or Google account that made the purchase.

### Can I buy on iPhone and restore on Android?

No. CC Pocket does not currently share support status across stores.

### Why not add a CC Pocket account just for this?

Because CC Pocket is intentionally designed to avoid introducing more user identity and hosted account infrastructure than it needs.
