# Shorebird Code Push Runbook

ccpocket の OTA (Over-The-Air) アップデート運用手順。

## 概要

[Shorebird](https://shorebird.dev/) を使い、ストア審査なしで Dart コード変更をユーザー端末へ配信する。

- **release**: ストアに提出するベースバイナリ。native 変更を含む場合はこちら。
- **patch**: release に対する差分配信。Dart のみの変更に限定。
- **track**: `staging` → `stable` の2段階で段階配信。

## 前提条件

### CLI インストール

```bash
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
shorebird --version
shorebird doctor
```

### 認証

```bash
# ローカル開発
shorebird login

# CI 用トークン
shorebird login:ci
# 出力されたトークンを CI secret SHOREBIRD_TOKEN に登録
```

### 初期セットアップ (初回のみ)

```bash
cd apps/mobile
shorebird init
```

`shorebird.yaml` が生成され、app_id が設定される。

## Android release 署名

`apps/mobile/android/keystore.properties` を作成:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-your-keystore.jks>
```

テンプレート: `apps/mobile/android/keystore.properties.example`

> **注意**: `keystore.properties` と `*.keystore` / `*.jks` は `.gitignore` 済み。

## バージョン運用

`apps/mobile/pubspec.yaml` の `version` フィールドを管理:

```
version: x.y.z+build
```

- `x.y.z` — セマンティックバージョニング (versionName / CFBundleShortVersionString)
- `build` — ビルド番号 (versionCode / CFBundleVersion)、release ごとにインクリメント

### ルール

- **release 時**: version をインクリメントしてコミット
- **patch 時**: version は変更しない (同じ release-version に対して配信)
- release-version は `shorebird release` 時の pubspec.yaml version から自動決定

## CLI 運用コマンド

### Release

```bash
# Android
scripts/shorebird/release-android.sh

# iOS
scripts/shorebird/release-ios.sh
```

### Patch

```bash
# Android (staging track)
scripts/shorebird/patch-android.sh <release-version>

# iOS (staging track)
scripts/shorebird/patch-ios.sh <release-version>
```

### Preview (staging patch の実機確認)

```bash
scripts/shorebird/preview.sh <release-version> <patch-number>
```

### Promote (staging → stable)

```bash
scripts/shorebird/promote.sh <release-version> <patch-number>
```

### npm scripts

```bash
npm run shorebird:release:android
npm run shorebird:release:ios
npm run shorebird:patch:android -- <release-version>
npm run shorebird:patch:ios -- <release-version>
```

## 運用フロー

### 通常リリース (native 変更あり)

1. pubspec.yaml の version をインクリメント
2. `shorebird release android` / `shorebird release ios`
3. 生成された AAB / IPA をストアに提出
4. 審査通過後にユーザーへ配布

### Hotfix (Dart のみの変更)

1. 修正をコミット
2. `scripts/shorebird/patch-android.sh <release-version>`
3. `scripts/shorebird/preview.sh <release-version> <patch-number>` で staging 確認
4. `scripts/shorebird/promote.sh <release-version> <patch-number>` で stable 昇格
5. iOS も同様に実施

### 緊急ロールバック

Shorebird Console (`https://console.shorebird.dev/`) から:
- patch を無効化 (unarchive/archive)
- または新しい patch で上書き

## CI 統合 (GitHub Actions)

### Secret 設定

| Secret | 説明 |
|--------|------|
| `SHOREBIRD_TOKEN` | `shorebird login:ci` で取得 |
| `KEYSTORE_BASE64` | release keystore の base64 |
| `KEYSTORE_PASSWORD` | keystore パスワード |
| `KEY_ALIAS` | key alias |
| `KEY_PASSWORD` | key パスワード |

### ワークフロー構成

手動 dispatch で `release` / `patch` を分離:

```yaml
# .github/workflows/shorebird-release.yml
on:
  workflow_dispatch:
    inputs:
      platform:
        type: choice
        options: [android, ios]

# .github/workflows/shorebird-patch.yml
on:
  workflow_dispatch:
    inputs:
      platform:
        type: choice
        options: [android, ios]
      release_version:
        type: string
        required: true
```

iOS は `--no-codesign` で CI ビルドし、署名は既存の配布工程へ接続。

## 検証チェックリスト

### 初回 release 検証

- [ ] `shorebird release android` 成功
- [ ] 実機で起動確認 (接続・チャット・承認フロー)
- [ ] `shorebird release ios --no-codesign` 成功
- [ ] iOS 実機で起動確認

### 初回 patch 検証

- [ ] Dart のみの軽微変更を作成
- [ ] `staging` track で patch 配信
- [ ] `shorebird preview` で確認
- [ ] `stable` へ promote
- [ ] 既存インストール端末で差分適用を確認

### 失敗系検証

- [ ] native 変更を含むケースで patch 不可になることを確認
- [ ] patch 不可時に `release` へ切り替える運用を確定

## トラブルシューティング

### patch が適用されない

```bash
shorebird doctor
```

- Flutter version が release 時と一致しているか確認
- `--flutter-version` オプションで明示指定

### native 変更が含まれるエラー

native コード (Kotlin/Swift, plugin のネイティブ部分) が変更された場合、
patch ではなく新しい release が必要。

```bash
# release として再ビルド
scripts/shorebird/release-android.sh
```

## 参考リンク

- [Quickstart](https://docs.shorebird.dev/code-push/quickstart/)
- [Release](https://docs.shorebird.dev/code-push/release/)
- [Patch](https://docs.shorebird.dev/code-push/patch/)
- [Staging Patches](https://docs.shorebird.dev/code-push/staging-patches/)
- [GitHub CI](https://docs.shorebird.dev/code-push/ci/github-integration/)
- [Troubleshooting](https://docs.shorebird.dev/code-push/troubleshooting/)
- [iOS App Store](https://docs.shorebird.dev/code-push/ios/app-store/)
- [Android Play Store](https://docs.shorebird.dev/code-push/android/play-store/)
