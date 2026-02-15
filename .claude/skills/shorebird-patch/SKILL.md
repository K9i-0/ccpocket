---
name: shorebird-patch
description: Shorebird OTA パッチの作成・検証・プロモート
disable-model-invocation: true
allowed-tools: Bash(bash:*), Bash(grep:*), Read
---

# Shorebird パッチ配布

Shorebird OTA パッチを作成し、staging で検証後 stable にプロモートする。

## フロー概要

```
patch (staging) → ユーザー検証 → promote (stable)
```

**重要**: パッチは必ず staging → stable の2段階で配布する。直接 stable に配布しない。

## 手順

### 1. バージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の値を記録する（= `<version>`）。

### 2. パッチ作成 (staging)

引数でプラットフォームが指定された場合はそのまま使う。指定がなければユーザーに確認する。

```bash
# iOS
bash scripts/shorebird/patch-ios.sh <version>

# Android
bash scripts/shorebird/patch-android.sh <version>

# 両方の場合は順番に実行
```

スクリプトが以下を一括で行う:
- `dart analyze` で静的検証
- `shorebird patch` で staging にパッチ作成
- `--allow-asset-diffs` によりアセット変更の確認プロンプトを自動スキップ

完了後の出力から **パッチ番号** を記録する（= `<patch-number>`）。

### 3. ユーザーへの案内

以下を報告し、ユーザーにデバイスでの検証を案内する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- 現在のトラック: **staging**

ユーザーがアプリを再起動すると staging パッチが自動適用される。

### 4. プロモート (staging → stable)

ユーザーが検証完了を報告したら実行する:

```bash
bash scripts/shorebird/promote.sh <version> <patch-number> --force
```

- `--force` で確認プロンプトをスキップ（非TTY環境で安定動作）
- 完了後、全ユーザーに stable パッチが配信される

### 5. 完了報告

以下を報告する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- 現在のトラック: **stable**

## トラブルシュート

- **アセット変更警告**: スクリプトが `--allow-asset-diffs` を付与するため自動スキップされる。フォントファイル等の変更は OTA パッチに含まれない点をユーザーに伝える
- **署名エラー（exportArchive）**: IPA生成時のエラーはShorebirdパッチ自体には影響しない。パッチが `Published Patch N!` と表示されていれば成功
- **インタラクティブプロンプト**: `shorebird` コマンドを直接実行する場合は `--release-version` フラグ必須（省略するとインタラクティブプロンプトで非TTY環境がエラーになる）
