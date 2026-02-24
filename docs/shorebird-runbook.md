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

リリースは GH Actions のタグ駆動で実行する（`/release-mobile` スキル参照）。

```bash
# タグ打ちで自動実行
git tag ios/vX.Y.Z+N && git push origin ios/vX.Y.Z+N
git tag android/vX.Y.Z+N && git push origin android/vX.Y.Z+N
```

### Patch (staging)

```bash
# Android (staging track)
bash .claude/skills/shorebird-patch/patch.sh android <release-version>

# iOS (staging track)
bash .claude/skills/shorebird-patch/patch.sh ios <release-version>
```

### 検証 (staging)

```bash
# ローカルプレビュー
shorebird preview --track=staging --release-version=<release-version>

# 実機 (TestFlight等): デバッグ画面 → Update Track を Staging に → アプリ再起動
```

### Promote (staging → stable)

```bash
bash .claude/skills/shorebird-patch/promote.sh <release-version> <patch-number>
```

### npm scripts

```bash
npm run shorebird:patch:android -- <release-version>
npm run shorebird:patch:ios -- <release-version>
npm run shorebird:promote -- <release-version> <patch-number>
```

## 運用フロー

### 通常リリース (native 変更あり)

1. pubspec.yaml の version をインクリメント
2. `shorebird release android` / `shorebird release ios`
3. 生成された AAB / IPA をストアに提出
4. 審査通過後にユーザーへ配布

### Hotfix (Dart のみの変更)

1. 修正をコミット
2. `bash .claude/skills/shorebird-patch/patch.sh android <release-version>` → staging に配信
3. 検証: デバッグ画面で Update Track を Staging に → アプリ再起動で確認
4. `bash .claude/skills/shorebird-patch/promote.sh <release-version> <patch-number>` → stable に昇格
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

タグ駆動で `release`、手動 dispatch で `patch` を分離:

```yaml
# .github/workflows/ios-release.yml / android-release.yml
on:
  push:
    tags: ['ios/v*'] / ['android/v*']

# .github/workflows/ios-patch.yml / android-patch.yml
on:
  workflow_dispatch:
    inputs:
      release_version:
        type: string
        required: true
      track:
        type: choice
        default: staging
        options: [staging, stable]
```

CI パッチはデフォルトで staging に配信される。検証後に promote するか、緊急時は stable を直接選択する。

## 検証チェックリスト

### 初回 release 検証

- [x] `shorebird release android` 成功 (1.0.0+2)
- [x] 実機で起動確認 (shorebird preview)
- [x] `shorebird release ios` 成功 (1.0.0+3)
- [x] iOS 実機で起動確認 (shorebird preview)

### 初回 patch 検証

- [x] Dart のみの軽微変更を作成 (Connect ボタン色変更)
- [x] `staging` track で patch 配信 (Android + iOS)
- [x] `shorebird preview --track=staging` で確認
- [x] `stable` へ promote (Android + iOS)
- [x] OTA 差分適用を確認

### 失敗系検証

- [x] native 変更を含むケースで patch の挙動を確認 → **検証済み (2026-02-14)**

> **重要な知見**: Shorebird は native コード変更を**エラーにせず、サイレントに無視**する。
> Kotlin/Swift の変更のみの patch は成功するが、差分サイズが極小 (~300B) で実質何も反映されない。
> native + Dart の混在変更では Dart 部分のみ配信され、native 部分は無視される。
> → **native 変更がある場合は必ず新しい release を作成すること。**

## トラブルシューティング

### patch が適用されない

```bash
shorebird doctor
```

- Flutter version が release 時と一致しているか確認
- `--flutter-version` オプションで明示指定

### native 変更が含まれる場合

native コード (Kotlin/Swift, plugin のネイティブ部分) が変更された場合、
patch では反映されない。新しい release が必要。
Shorebird はエラーを出さずに patch を受け付けるため、**開発者が判断する必要がある**。

新しい release が必要な場合は `/release-mobile` スキルでタグを打つ。

## 参考リンク

- [Quickstart](https://docs.shorebird.dev/code-push/quickstart/)
- [Release](https://docs.shorebird.dev/code-push/release/)
- [Patch](https://docs.shorebird.dev/code-push/patch/)
- [Staging Patches](https://docs.shorebird.dev/code-push/staging-patches/)
- [GitHub CI](https://docs.shorebird.dev/code-push/ci/github-integration/)
- [Troubleshooting](https://docs.shorebird.dev/code-push/troubleshooting/)
- [iOS App Store](https://docs.shorebird.dev/code-push/ios/app-store/)
- [Android Play Store](https://docs.shorebird.dev/code-push/android/play-store/)
