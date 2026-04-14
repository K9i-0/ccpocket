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

- A dedicated `Support` screen that shows your support history summary
- Monthly Supporter perks: alternate app icons
- One-time and monthly ways to support the project financially
- No feature gating for the main app experience

## What The App Actually Shows

The purchase flow lives in `Settings > Support`.

The `Support` screen shows:

- Monthly support: `Supporter Monthly`
- One-time support: `Drink Support` and `Lunch Support`
- A support summary when there is any purchase history on the current store account

That summary can include:

- When monthly support started
- How long support has been active
- One-time support counts such as Drink / Lunch totals

This summary is shown for both monthly supporters and one-time supporters.

## Monthly Supporter Perks

Monthly Supporter does not unlock core app functionality.

Instead, it adds a small cosmetic perk:

- Alternate app icons in `Settings > App Icon`

The default icon remains available to everyone. The alternate icon options are only unlocked while monthly support is active.

## What Support Helps Cover

Support is used to keep the app moving.

- AI usage for development and testing, including tools like Claude and Codex
- Devices, OS updates, and real-world testing across platforms
- The motivation to keep polishing the app when people clearly find it useful

## FAQ

### Is CC Pocket paywalled?

No. The app remains fully usable without Supporter.

### Can I restore purchases after reinstalling?

Yes, as long as you use the same Apple ID or Google account that made the purchase.

### Can I buy on iPhone and restore on Android?

No. CC Pocket does not currently share support status across stores.

### What happens after a one-time support purchase?

It appears in the support summary on the `Support` screen. It does not unlock app features.

### What happens after a monthly support purchase?

It appears in the support summary on the `Support` screen and unlocks alternate app icons in `Settings > App Icon`.

### Why not add a CC Pocket account just for this?

Because CC Pocket is intentionally designed to avoid introducing more user identity and hosted account infrastructure than it needs.
