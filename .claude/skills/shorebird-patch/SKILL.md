---
name: shorebird-patch
description: Shorebird OTA パッチの作成・検証・プロモート
disable-model-invocation: true
allowed-tools: Bash(shorebird:*), Bash(dart:*), Bash(grep:*), Bash(cat:*), Read
---

# Shorebird パッチ配布

Shorebird OTA パッチを作成し、staging で検証後 stable にプロモートする。

## フロー概要

```
patch (staging) → preview → promote (stable)
```

**重要**: パッチは必ず staging トラックに作成し、検証後に stable へプロモートする。

## 手順

### 1. バージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

- `version: X.Y.Z+N` の値を記録する（= `<release-version>` とする）

### 2. 静的検証

```bash
dart analyze apps/mobile
```

- エラーがある場合は中断し、修正を促す

### 3. プラットフォーム選択

ユーザーに対象プラットフォームを確認する:
- **iOS**: `scripts/shorebird/patch-ios.sh`
- **Android**: `scripts/shorebird/patch-android.sh`
- **両方**: 順番に実行

### 4. パッチ作成 (staging)

```bash
# iOS
bash scripts/shorebird/patch-ios.sh <release-version>

# Android
bash scripts/shorebird/patch-android.sh <release-version>
```

- スクリプトは `--track=staging` でパッチを作成する
- 完了後、出力からパッチ番号を記録する（= `<patch-number>` とする）

### 5. 検証 (staging)

```bash
bash scripts/shorebird/preview.sh <release-version> <patch-number>
```

- staging トラックのパッチをプレビューデバイスで確認する
- ユーザーに検証結果を確認する

### 6. プロモート (staging → stable)

```bash
bash scripts/shorebird/promote.sh <release-version> <patch-number>
```

- 確認プロンプトが表示される（y で続行）
- **注意**: promote.sh はインタラクティブな確認があるため、`yes |` でパイプするか、ユーザーに手動実行を案内する

### 7. 完了報告

以下を報告する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- 現在のトラック (staging / stable)

## 注意事項

- `shorebird` コマンドを直接実行する場合は必ず `--release-version` フラグを付ける（省略するとインタラクティブプロンプトでエラーになる）
- CI/非インタラクティブ環境では `--force` フラグも検討する
- パッチ作成前に `dart analyze` を必ず実行する（スクリプト内でも実行されるが、早期発見のため）
