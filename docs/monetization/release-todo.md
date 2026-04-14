# Supporter Release TODO

最終更新: 2026-04-11

## 現在地

- Flutter 側の RevenueCat SDK 組み込みは完了
- 設定画面の Support セクションは実装済み
- `supporter` entitlement を読んで AppBar / Settings に反映済み
- RevenueCat Test Store での商品構成確認は完了

## リリースまでの TODO

### 1. RevenueCat に本番 App を追加

- [ ] iOS 用 App Store app を作成する
- [ ] Android 用 Google Play app を作成する
- [ ] bundle ID / package name が本番アプリと一致していることを確認する

### 2. Apple 側の認証情報を接続する

- [ ] App Store Connect API key を RevenueCat に登録する
- [ ] In-App Purchase Key を RevenueCat に登録する
- [ ] RevenueCat から App Store Connect を読める状態にする

メモ:
- Flutter での App Store 課金は In-App Purchase Key が必須
- 初回の IAP / subscription は app version と一緒に提出が必要

### 3. Google 側の認証情報を接続する

- [ ] RevenueCat の案内する自動化スクリプトで `revenuecat-key.json` を作る
- [ ] その JSON key を RevenueCat にアップロードする
- [ ] Google Play Console 側で service account に権限を付与する

メモ:
- Google Play の credential は有効化まで最大 36 時間かかることがある
- 直後は `Invalid Play Store credentials` 系エラーが出ても不思議ではない

### 4. ストア商品を本番で作成する

- [ ] iOS で `Supporter $10/mo` を subscription として作成する
- [ ] iOS で `$5 Coffee` を consumable として作成する
- [ ] iOS で `$10 Lunch` を consumable として作成する
- [ ] Android で `Supporter $10/mo` を subscription として作成する
- [ ] Android で `$5 Coffee` を in-app product として作成する
- [ ] Android で `$10 Lunch` を in-app product として作成する

推奨 product type:
- `Supporter $10/mo`: subscription
- `$5 Coffee`: one-time consumable
- `$10 Lunch`: one-time consumable

### 5. RevenueCat に本番商品を import / 接続する

- [ ] iOS 商品を RevenueCat に import する
- [ ] Android 商品を RevenueCat に import する
- [ ] `supporter` entitlement には月額商品だけを紐づける
- [ ] `default` offering に 3 商品を載せる
- [ ] package が意図通りになっていることを確認する

想定 package:
- `$rc_monthly` -> `Supporter $10/mo`
- `$rc_custom_coffee` -> `$5 Coffee`
- `$rc_custom_lunch` -> `$10 Lunch`

### 6. 本番ビルド設定を入れる

- [ ] release ビルドに `REVENUECAT_PUBLIC_KEY` を入れる
- [ ] CI / CD で iOS / Android の両方に同じ RevenueCat project を向くようにする
- [ ] debug の Test Store key と release の本番 key が混ざらないことを確認する

### 7. 実機で購入フロー確認

- [ ] iOS sandbox / TestFlight で購入成功を確認する
- [ ] iOS でキャンセル時の挙動を確認する
- [ ] iOS で restore を確認する
- [ ] Android internal testing で購入成功を確認する
- [ ] Android でキャンセル時の挙動を確認する
- [ ] Android で restore 相当の復元を確認する
- [ ] 購入後に `Supporter` バッジが反映されることを確認する

### 8. ストア審査準備

- [ ] 商品名と説明文を最終確定する
- [ ] App Review / Play 審査向けの補足説明を用意する
- [ ] 必要なら purchase 画面のスクリーンショットを更新する
- [ ] 初回 IAP 提出時は app version と同時提出する

## 商品メモ

### Monthly support

- 表示名: `Supporter $10/mo`
- 実態: 機能解放ではなく OSS 支援
- RevenueCat entitlement: `supporter`

### One-time support

- 表示名: `$5 Coffee`
- 表示名: `$10 Lunch`
- 実態: どちらも 1 回限りの支援導線
- RevenueCat entitlement には紐づけない

## 実装側メモ

- release では `REVENUECAT_PUBLIC_KEY` を必ず渡す
- debug では Test Store public key をフォールバックで使う
- Support セクションは RevenueCat current offering が空でも壊れない
- init 失敗後も `Retry` から再 `configure()` できるようにしてある
