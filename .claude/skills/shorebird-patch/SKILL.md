---
name: shorebird-patch
description: Shorebird OTA パッチの作成・配布
disable-model-invocation: true
allowed-tools: Bash(bash:*), Bash(grep:*), Read
---

# Shorebird パッチ配布

Shorebird OTA パッチを作成し、stable に直接配布する。

## フロー概要

```
patch (stable) → ユーザーがアプリ再起動で受信
```

## 手順

### 1. バージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の値を記録する（= `<version>`）。

### 2. パッチ作成 (stable)

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
- `shorebird patch` で stable にパッチ作成
- `--allow-asset-diffs` によりアセット変更の確認プロンプトを自動スキップ

完了後の出力から **パッチ番号** を記録する（= `<patch-number>`）。

### 3. 完了報告

以下を報告する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- トラック: **stable**

ユーザーにアプリの再起動を案内する（1回目でダウンロード、2回目で適用）。

## トラブルシュート

- **アセット変更警告**: スクリプトが `--allow-asset-diffs` を付与するため自動スキップされる。フォントファイル等の変更は OTA パッチに含まれない点をユーザーに伝える
- **署名エラー（exportArchive）**: IPA生成時のエラーはShorebirdパッチ自体には影響しない。パッチが `Published Patch N!` と表示されていれば成功
- **インタラクティブプロンプト**: `shorebird` コマンドを直接実行する場合は `--release-version` フラグ必須（省略するとインタラクティブプロンプトで非TTY環境がエラーになる）
