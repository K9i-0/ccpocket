# Apple Review Checklist For Supporter

最終更新: 2026-04-15

`CC Pocket` の `Supporter` 課金を iOS / App Store Connect / TestFlight / App Review で進めるためのメモ。

## 前提

- 課金は `RevenueCat + App Store`
- `CC Pocket` 独自アカウントはない
- 購入状態は reviewer の `Apple ID` にひもづく
- `Support` 導線はアプリ内の `Settings > Support`
- 月額サポーター特典の確認導線は `Settings > App Icon`
- アプリ本体の主要機能は self-hosted Bridge 前提

## TestFlight / Sandbox の確認事項

- TestFlight の In-App Purchase は sandbox 環境で動く
- TestFlight での購入は実課金されない
- TestFlight の auto-renewable subscription は 24 時間ごとに更新され、最大 6 回更新される
- 請求失敗や返金など特殊シナリオを試すときは `Sandbox Apple Account` を使う

## App Store Connect でやること

### 1. アプリ本体

- [ ] 最新の iOS build をアップロードする
- [ ] App Review Information の `Contact` を埋める
- [ ] App Review Information の `Notes` を埋める
- [ ] 初回 IAP なので、**新しい app version と一緒に提出**する

### 2. In-App Purchases / Subscription

- [ ] `Supporter Monthly` が `Ready to Submit`
- [ ] `Drink Support` が `Ready to Submit`
- [ ] `Lunch Support` が `Ready to Submit`
- [ ] 各商品の `Display Name` / `Description` を最新文言に更新する
- [ ] `Supporter` subscription group のローカライズを更新する
- [ ] 各商品に `App Review Screenshot` を設定する
- [ ] 各商品に `Review Notes` を設定する
- [ ] アプリ version の `In-App Purchases and Subscriptions` に 3 商品を追加する

## App Store Connect に入れる商品文言候補

実装上の導線と表示に合わせるなら、商品文言は次くらいが自然。

### Supporter Monthly

日本語:

```text
Display Name:
Supporter Monthly

Description:
CC Pocketの継続開発を支援する月額サポーター。
```

英語:

```text
Display Name:
Supporter Monthly

Description:
Monthly support for CC Pocket.
```

### Drink Support

日本語:

```text
Display Name:
Drink Support

Description:
CC Pocketを単発で応援するための購入です。
```

英語:

```text
Display Name:
Drink Support

Description:
One-time support for CC Pocket.
```

### Lunch Support

日本語:

```text
Display Name:
Lunch Support

Description:
CC Pocketを少し大きめに単発で応援する購入です。
```

英語:

```text
Display Name:
Lunch Support

Description:
A larger one-time support for CC Pocket.
```

### Subscription Group

日本語:

```text
Display Name:
Supporter
```

英語:

```text
Display Name:
Supporter
```

## App Review Information に入れる文面

`App Store Connect > App version > App Review Information > Notes`

```text
CC Pocket does not use a dedicated app account for purchases.
No login is required to access the Support section.
The purchase flow can be reviewed without connecting to a Bridge server.

To test in-app purchases:
1. Open the app.
2. Go to Settings.
3. Tap Support.
4. The available items on the Support screen are:
   - Supporter Monthly
   - Drink Support
   - Lunch Support
5. Purchases and restore are tied to the reviewer's Apple ID in Apple's sandbox environment.
6. After purchasing Supporter Monthly, go back to Settings > App Icon to verify that alternate app icons are unlocked.
7. Purchase history is summarized on the Support screen.

Important context:
- Supporter is optional OSS support. Core app functionality is not paywalled.
- The app remains usable without purchase.
- One-time purchases update the support summary only.
- The monthly purchase updates the support summary and unlocks alternate app icon perks.
- The current alternate app icon options for monthly supporters are Light and Metallic.

Bridge note:
CC Pocket's main coding workflow connects to a self-hosted Bridge Server.
If review of the full remote workflow is needed, please refer to the attached demo video / additional notes.
```

## IAP Review Notes の文面

### Supporter Monthly

`App Store Connect > In-App Purchase > Supporter Monthly > Review Notes`

```text
This is an optional monthly support subscription for CC Pocket.

Location in app:
Purchase flow: Settings > Support
Perk verification: Settings > App Icon

No CC Pocket account is required.
The subscription is associated with the reviewer's Apple ID in Apple's sandbox environment.

This purchase does not unlock core app functionality.
It is an optional supporter purchase that updates the support summary and unlocks alternate app icons.
The currently available monthly supporter icon options are Light and Metallic.
```

### Drink Support

`App Store Connect > In-App Purchase > Drink Support > Review Notes`

```text
This is a one-time optional support purchase for CC Pocket.

Location in app:
Settings > Support

No CC Pocket account is required.
The purchase is associated with the reviewer's Apple ID in Apple's sandbox environment.

This purchase does not unlock core app functionality.
It is an optional one-time support option that updates the support summary on the Support screen.
```

### Lunch Support

`App Store Connect > In-App Purchase > Lunch Support > Review Notes`

```text
This is a one-time optional support purchase for CC Pocket.

Location in app:
Settings > Support

No CC Pocket account is required.
The purchase is associated with the reviewer's Apple ID in Apple's sandbox environment.

This purchase does not unlock core app functionality.
It is an optional one-time support option that updates the support summary on the Support screen.
```

## Review Screenshot の考え方

- 公開用スクリーンショットではなく、審査用の画面でよい
- 基本は `Settings > Support` が見える画面を使う
- 各商品が確認できる状態で撮る

推奨:

- `Supporter Monthly` が見え、月額サポーター特典の説明も読めるスクショ
- 可能なら、月額購入後の `Settings > App Icon` で `Light` / `Metallic` が見える確認用スクショも別途控えておく
- `Drink Support` が見えるスクショ
- `Lunch Support` が見えるスクショ

## TestFlight での最終確認

- [ ] `Settings > Support` に 3 商品が表示される
- [ ] 購入シートが開く
- [ ] 単発購入後に `Support` 画面のサマリーが更新される
- [ ] 月額購入後に `Support` 画面のサマリーが更新される
- [ ] 月額購入後に `Settings > App Icon` の追加アイコンが解放される
- [ ] `Settings > App Icon` で `Light` / `Metallic` が選べる
- [ ] `Restore` が動く
- [ ] 月額の継続表示と単発支援サマリーが崩れない

## CC Pocket 固有の注意

### デモアカウントは必要か

不要。

Apple の `Username / Password` は、**アプリ利用にログインが必要な場合のみ**必要。`CC Pocket` の `Supporter` 購入では独自ログインを使わないので、ここは空でよい。

### Bridge が必要な点はどうするか

`CC Pocket` の本来の価値は Bridge 接続込みなので、レビューで誤解されやすい。

そのため:

- App Review Information の `Notes` に Bridge 前提であることを書く
- 必要なら短い demo video を添付する
- 「Supporter は paywall ではなく OSS support」であることを明記する

## 参考リンク

- Apple sandbox overview: https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox
- Apple TestFlight IAP testing: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/
- Apple submit IAP: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/
- Apple App Review information reference: https://developer.apple.com/help/app-store-connect/reference/app-review-information
- Apple App Review overview: https://developer.apple.com/app-store/review/
