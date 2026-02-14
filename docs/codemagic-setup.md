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

### 2-2. Codemagic に Secret を登録

Codemagic Dashboard → Settings → Environment variables で以下を登録:

| グループ名 | 変数名 | 値 | Secure |
|-----------|--------|-----|--------|
| `shorebird` | `SHOREBIRD_TOKEN` | `shorebird login:ci` の出力 | Yes |
| `ios_signing` | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | Yes |
| `ios_signing` | `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID | Yes |
| `ios_signing` | `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 ファイルの中身 | Yes |
| `android_signing` | `CM_KEYSTORE` | keystore の base64 | Yes |
| `android_signing` | `CM_KEYSTORE_PASSWORD` | keystore パスワード | Yes |
| `android_signing` | `CM_KEY_ALIAS` | key alias | Yes |
| `android_signing` | `CM_KEY_PASSWORD` | key パスワード | Yes |

```bash
# Shorebird CI トークンの取得
~/.shorebird/bin/shorebird login:ci

# Android keystore の base64 エンコード
base64 -i ~/ccpocket-release.jks
```

### 2-3. codemagic.yaml の作成

リポジトリルートに `codemagic.yaml` を配置（後述の実装フェーズで作成）。

---

## Part 3: codemagic.yaml ワークフロー設計

### ワークフロー一覧

| ワークフロー | トリガー | 内容 |
|------------|---------|------|
| `android-release` | 手動 | Shorebird release → Play Console 内部テスト |
| `ios-release` | 手動 | Shorebird release → TestFlight |
| `android-patch` | 手動 (release_version 指定) | Shorebird patch → staging |
| `ios-patch` | 手動 (release_version 指定) | Shorebird patch → staging |
| `test` | PR / push | analyze + test のみ |

### 共通スクリプト (definitions)

```yaml
definitions:
  env_versions: &env_versions
    flutter: 3.41.1
    xcode: latest
  scripts:
    - &install_shorebird
      name: Install Shorebird
      script: |
        curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
        echo "export PATH=$HOME/.shorebird/bin:$PATH" >> $CM_ENV
    - &shorebird_doctor
      name: Shorebird Doctor
      script: shorebird doctor
    - &flutter_analyze
      name: Flutter Analyze
      script: |
        cd apps/mobile
        flutter analyze
    - &flutter_test
      name: Flutter Test
      script: |
        cd apps/mobile
        flutter test
```

### Android Release ワークフロー

```yaml
workflows:
  android-release:
    name: Android Release (Shorebird)
    max_build_duration: 30
    environment:
      groups:
        - shorebird
        - android_signing
      <<: *env_versions
      android_signing:
        - keystore_reference: CM_KEYSTORE
    triggering:
      events:
        - push
      cancel_previous_builds: true
    when:
      changeset:
        includes:
          - 'never-auto-trigger'  # 手動のみ
    scripts:
      - *install_shorebird
      - *flutter_analyze
      - *flutter_test
      - name: Shorebird Release Android
        script: |
          cd apps/mobile
          shorebird release android \
            --flutter-version=$FLUTTER_VERSION \
            --no-confirm
    artifacts:
      - apps/mobile/build/app/outputs/bundle/release/*.aab
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
```

### iOS Release ワークフロー

```yaml
  ios-release:
    name: iOS Release (Shorebird)
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      groups:
        - shorebird
        - ios_signing
      <<: *env_versions
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.k9i.ccpocket
    scripts:
      - *install_shorebird
      - *flutter_analyze
      - *flutter_test
      - name: Set up iOS signing
        script: |
          app-store-connect fetch-signing-files com.k9i.ccpocket \
            --type IOS_APP_STORE --create
          keychain initialize
          keychain add-certificates
          xcode-project use-profiles
      - name: Shorebird Release iOS
        script: |
          cd apps/mobile
          shorebird release ios \
            --flutter-version=$FLUTTER_VERSION \
            --no-confirm
    artifacts:
      - apps/mobile/build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

### Patch ワークフロー（Android / iOS 共通パターン）

```yaml
  android-patch:
    name: Android Patch (Shorebird)
    max_build_duration: 30
    environment:
      groups:
        - shorebird
        - android_signing
      <<: *env_versions
      android_signing:
        - keystore_reference: CM_KEYSTORE
      vars:
        RELEASE_VERSION: "latest"  # Codemagic UIで上書き可能
    scripts:
      - *install_shorebird
      - name: Shorebird Patch Android
        script: |
          cd apps/mobile
          shorebird patch android \
            --release-version=$RELEASE_VERSION \
            --flutter-version=$FLUTTER_VERSION \
            --track=staging \
            --no-confirm

  ios-patch:
    name: iOS Patch (Shorebird)
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      groups:
        - shorebird
        - ios_signing
      <<: *env_versions
      vars:
        RELEASE_VERSION: "latest"
    scripts:
      - *install_shorebird
      - name: Set up iOS signing
        script: |
          app-store-connect fetch-signing-files com.k9i.ccpocket \
            --type IOS_APP_STORE --create
          keychain initialize
          keychain add-certificates
          xcode-project use-profiles
      - name: Shorebird Patch iOS
        script: |
          cd apps/mobile
          shorebird patch ios \
            --release-version=$RELEASE_VERSION \
            --flutter-version=$FLUTTER_VERSION \
            --track=staging \
            --no-confirm
```

---

## Part 4: 手動作業まとめ

### 初回のみ（1回きり）

| 作業 | 場所 | 所要時間 |
|------|------|---------|
| App Store Connect API キー作成 | Web (App Store Connect) | 5分 |
| Codemagic CLI Tools インストール | ローカル PC | 2分 |
| Codemagic アカウント作成・リポジトリ接続 | Web (Codemagic) | 10分 |
| Secret 登録 (SHOREBIRD_TOKEN, 署名情報) | Web (Codemagic) | 10分 |
| codemagic.yaml 作成・コミット | ローカル PC | ー（Claude Codeで実装） |

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
| stable 昇格 | 手動（`shorebird patches promote` or Console） |

### 年次更新

| 作業 | 自動化状況 |
|------|-----------|
| iOS 証明書の更新 | **自動** (CLI Tools が API 経由で自動取得) |
| App Store Connect API キーの更新 | 不要（キーに有効期限なし） |
| Android keystore の更新 | 不要（keystore に有効期限なし） |

---

## Part 5: 導入ステップ（推奨順序）

```
Phase 1: ローカル iOS 署名 (今すぐ)
  ├── App Store Connect API キー作成
  ├── Codemagic CLI Tools インストール
  ├── fetch-signing-files で証明書取得
  └── shorebird release ios (署名付き) → preview 確認

Phase 2: CI/CD 構築 (Phase 1 完了後)
  ├── Codemagic アカウント作成
  ├── Secret 登録
  ├── codemagic.yaml 作成・コミット
  └── テストビルド実行

Phase 3: 運用開始
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
