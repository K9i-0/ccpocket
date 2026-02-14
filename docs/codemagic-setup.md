# Codemagic CLI Tools + CI/CD セットアップガイド

ccpocket の iOS 署名自動化と Shorebird 連携の CI/CD 構築手順。

## 概要

| レイヤー | ツール | 用途 |
|---------|--------|------|
| iOS 署名 | Codemagic CLI Tools | 証明書・Provisioning Profile の自動取得・管理 |
| OTA 配信 | Shorebird | Dart コードの OTA パッチ配信 |
| CI/CD | Codemagic | ビルド・署名・リリース・パッチの自動化 |

## Part 1: ローカル環境セットアップ（手動作業）

### 1-1. App Store Connect API キーの作成

**手動作業（Web）**: https://appstoreconnect.apple.com/access/integrations/api

1. App Store Connect → ユーザーとアクセス → キー → 統合
2. 「+」でキーを作成
   - 名前: `Codemagic CI`
   - アクセス: **App Manager**
3. 以下を控える:
   - **Issuer ID** (ページ上部に表示)
   - **Key ID** (キー一覧に表示)
   - **API Key ファイル** (.p8) をダウンロード → 安全な場所に保存

> **注意**: API Key は一度しかダウンロードできない。紛失したら再作成が必要。

### 1-2. Codemagic CLI Tools のインストール

```bash
pip3 install codemagic-cli-tools
```

### 1-3. 環境変数の設定

`.zshrc` や `.env` に追加（リポジトリにはコミットしない）:

```bash
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_KEY_IDENTIFIER="your-key-id"
export APP_STORE_CONNECT_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXXXXX.p8)"
```

### 1-4. iOS 署名ファイルの取得

```bash
# Development (実機デバッグ・Shorebird preview 用)
app-store-connect fetch-signing-files com.k9i.ccpocket \
  --type IOS_APP_DEVELOPMENT \
  --create

# Ad Hoc (内部テスト配布用)
app-store-connect fetch-signing-files com.k9i.ccpocket \
  --type IOS_APP_ADHOC \
  --create

# App Store (本番配布用)
app-store-connect fetch-signing-files com.k9i.ccpocket \
  --type IOS_APP_STORE \
  --create
```

`--create` フラグにより、証明書・Profile が存在しなければ自動作成される。

### 1-5. キーチェーンへのインストール

```bash
keychain initialize
keychain add-certificates
xcode-project use-profiles
```

これで Xcode の自動署名が使えるようになる。

### 1-6. Shorebird iOS release（署名付き）

```bash
cd apps/mobile
~/.shorebird/bin/shorebird release ios
```

署名済みの IPA が生成されるので、`shorebird preview` も動作する。

---

## Part 2: Codemagic CI/CD セットアップ

### 2-1. Codemagic アカウント作成

https://codemagic.io/start/ でサインアップし、GitHub リポジトリを接続。

**料金**:
- 無料枠: macOS M2 で月 500 分
- 個人利用なら無料枠で十分

### 2-2. App Store Connect 連携の設定

Codemagic Dashboard → Settings → Integrations → App Store Connect:

1. **API key** を選択
2. Part 1-1 で作成した API キー情報を入力:
   - **Name**: `Codemagic` (codemagic.yaml の `integrations.app_store_connect` と一致させる)
   - **Issuer ID**: App Store Connect の Issuer ID
   - **Key ID**: API Key ID
   - **API Key (.p8)**: ダウンロードした .p8 ファイルをアップロード
3. 保存

### 2-3. Android Keystore の登録

Codemagic Dashboard → Settings → Code signing → Android:

1. **Keystore** セクションで keystore をアップロード
   - **Reference name**: `android_keystore` (codemagic.yaml で参照する名前)
   - **Keystore file**: `ccpocket-release.jks` をアップロード
   - **Keystore password**: keystore パスワード
   - **Key alias**: key alias
   - **Key password**: key パスワード

### 2-4. 環境変数の登録

Codemagic Dashboard → Settings → Environment variables:

| グループ名 | 変数名 | 値 | Secure |
|-----------|--------|-----|--------|
| `shorebird` | `SHOREBIRD_TOKEN` | `shorebird login:ci` の出力 | Yes |
| `ios_signing` | `CERTIFICATE_PRIVATE_KEY` | `~/ios-cert-private-key.pem` の中身 | Yes |
| `google_play` | `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | GCP サービスアカウント JSON の中身 | Yes |

```bash
# Shorebird CI トークンの取得
~/.shorebird/bin/shorebird login:ci

# 証明書秘密鍵の内容を確認
cat ~/ios-cert-private-key.pem
```

### 2-5. Google Play サービスアカウントの作成

Google Play Console への自動アップロードに必要。

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成（または既存を使用）
2. **IAM と管理** → **サービスアカウント** → サービスアカウントを作成
   - 名前: `codemagic-ci`
3. **キー** タブ → **鍵を追加** → **新しい鍵を作成** → **JSON**
4. ダウンロードした JSON の中身を `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` に登録
5. [Google Play Console](https://play.google.com/console/) → **設定** → **API アクセス** で、作成したサービスアカウントをリンク
   - 権限: **リリースマネージャー** 以上

### 2-6. codemagic.yaml

リポジトリルートに `codemagic.yaml` を配置済み。

---

## Part 3: codemagic.yaml ワークフロー解説

`codemagic.yaml` はリポジトリルートに配置済み。

### ワークフロー一覧

| ワークフロー | トリガー | 内容 |
|------------|---------|------|
| `test` | PR / main push | `dart analyze` + `flutter test` |
| `android-release` | 手動 | Shorebird release → Google Play 内部テスト |
| `ios-release` | 手動 | Shorebird release → TestFlight |
| `android-patch` | 手動 (release_version 入力) | Shorebird patch → staging |
| `ios-patch` | 手動 (release_version 入力) | Shorebird patch → staging |

### Android signing の仕組み

Codemagic の `android_signing` が keystore をデコードし、`CM_KEYSTORE_PATH` 等の環境変数をセットする。
CI スクリプトでこれらから `keystore.properties` を生成し、既存の `build.gradle.kts` を無修正で動作させる:

```bash
cat > apps/mobile/android/keystore.properties << EOF
storeFile=$CM_KEYSTORE_PATH
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF
```

### iOS signing の仕組み

Codemagic CLI Tools (CI にプリインストール済み) で自動署名:

1. `app-store-connect fetch-signing-files` — App Store Connect API 経由で証明書・Profile を取得
2. `keychain initialize` + `keychain add-certificates` — CI キーチェーンにインストール
3. `xcode-project use-profiles` — Xcode プロジェクトに署名設定を適用
4. `shorebird release/patch ios --export-options-plist=...` — 生成された export options を使用

### Patch ワークフローの inputs

Codemagic UI から手動トリガー時に `release_version` を入力する。
`${{ inputs.release_version }}` で参照され、Shorebird の `--release-version` に渡される。

### Publishing

- **Android**: Google Play 内部テストトラックにアップロード (`GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` 必要)
- **iOS**: TestFlight に自動提出 (App Store Connect 連携で認証)

---

## Part 4: 手動作業まとめ

### 初回のみ（1回きり）

| 作業 | 場所 | 状態 |
|------|------|------|
| App Store Connect API キー作成 | Web (App Store Connect) | **済** |
| Codemagic CLI Tools インストール | ローカル PC | **済** |
| Codemagic アカウント作成・リポジトリ接続 | Web (Codemagic) | 要実施 |
| App Store Connect 連携設定 | Web (Codemagic) | 要実施 |
| Android Keystore 登録 | Web (Codemagic) | 要実施 |
| 環境変数登録 (SHOREBIRD_TOKEN, CERTIFICATE_PRIVATE_KEY) | Web (Codemagic) | 要実施 |
| Google Play サービスアカウント作成 | Web (GCP + Play Console) | 要実施 |
| codemagic.yaml コミット | ローカル PC | **済** |

### リリースごと

| 作業 | 自動化状況 |
|------|-----------|
| pubspec.yaml のバージョン更新 | 手動（コミットに含める） |
| Shorebird release | **CI で自動** |
| iOS 署名 | **CI で自動** (Codemagic CLI Tools) |
| TestFlight / Play Console 提出 | **CI で自動** |
| ストア審査提出・公開 | **手動** (App Store Connect / Play Console) |

### パッチごと

| 作業 | 自動化状況 |
|------|-----------|
| Dart コード変更・コミット | 手動 |
| Shorebird patch (staging) | **CI で自動** |
| staging 確認 | 手動（実機で確認） |
| stable 昇格 | 手動（`scripts/shorebird/promote.sh` or Console） |

### 年次更新

| 作業 | 自動化状況 |
|------|-----------|
| iOS 証明書の更新 | **自動** (CLI Tools が API 経由で自動取得) |
| App Store Connect API キーの更新 | 不要（キーに有効期限なし） |
| Android keystore の更新 | 不要（keystore に有効期限なし） |

---

## Part 5: 導入ステップ

```
Phase 1: ローカル iOS 署名 ✅ 完了
  ├── App Store Connect API キー作成
  ├── Codemagic CLI Tools インストール
  ├── fetch-signing-files で証明書取得
  └── shorebird release ios → preview 確認

Phase 2: CI/CD 構築 ✅ codemagic.yaml 作成済み
  ├── codemagic.yaml コミット
  └── 以下は Codemagic Web で設定:
      ├── アカウント作成・リポジトリ接続
      ├── App Store Connect 連携
      ├── Android Keystore 登録
      ├── 環境変数登録
      └── Google Play サービスアカウント

Phase 3: 運用開始
  ├── test ワークフローで CI 動作確認
  ├── 初回 release (Android + iOS) を CI で実行
  ├── 初回 patch を CI で実行
  └── runbook を更新
```

---

## 参考リンク

- [Codemagic CLI Tools ドキュメント](https://docs.codemagic.io/knowledge-codemagic/codemagic-cli-tools/)
- [Codemagic CLI Tools GitHub](https://github.com/codemagic-ci-cd/cli-tools)
- [fetch-signing-files コマンドリファレンス](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/app-store-connect/fetch-signing-files.md)
- [Shorebird + Codemagic YAML ガイド](https://blog.codemagic.io/how-to-set-up-flutter-code-push-with-shorebird-and-codemagic/)
- [Shorebird Codemagic 公式連携ドキュメント](https://docs.shorebird.dev/code-push/ci/codemagic/)
- [Codemagic Shorebird デモリポジトリ](https://github.com/shorebirdtech/codemagic_demo)
- [iOS Code Signing with CLI Tools](https://blog.codemagic.io/ios-code-signing-with-cli-tools/)
