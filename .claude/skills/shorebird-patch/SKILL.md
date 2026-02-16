---
name: shorebird-patch
description: Shorebird OTA パッチの作成・配布
disable-model-invocation: true
allowed-tools: Bash(bash:*), Bash(shorebird:*), Bash(dart:*), Bash(xcrun:*), Bash(grep:*), Read
---

# Shorebird パッチ配布

Shorebird OTA パッチを作成し、stable に直接配布する。

## フロー概要

```
patch (stable) → ユーザーがアプリ再起動で受信
```

## パッチ手順

### 1. バージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の値を記録する（= `<version>`）。

### 2. パッチ作成 (stable)

引数でプラットフォームが指定された場合はそのまま使う。指定がなければユーザーに確認する。

```bash
# iOS
bash .claude/skills/shorebird-patch/patch.sh ios <version>

# Android
bash .claude/skills/shorebird-patch/patch.sh android <version>

# 両方の場合は順番に実行
```

スクリプトが以下を一括で行う:
- `dart analyze` で静的検証
- `shorebird patch` で stable にパッチ作成
- `--allow-asset-diffs` によりアセット変更の確認プロンプトを自動スキップ

完了後の出力から **パッチ番号** を記録する（= `<patch-number>`）。

### 3. アセット差分の検証（重要）

パッチ出力に以下の警告が含まれていないか確認する:

```
[WARN] Your app contains asset changes, which will not be included in the patch.
```

**この警告が出た場合、パッチは publish されるが実機に適用されない可能性が高い。**

#### 対処法

アセット差分が検出された場合、ユーザーに以下を報告する:

1. **警告内容**: どのファイルにアセット差分があるか（例: `MaterialIcons-Regular.otf`）
2. **影響**: パッチは作成されるが、デバイスでダウンロード後に適用されない
3. **推奨対応**: 新しいリリースを作成してから、クリーンな状態でパッチを再作成する（下記「リリース手順」参照）

### 4. 完了報告

以下を報告する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- トラック: **stable**
- アセット差分: あり/なし（ありの場合は警告を明記）

ユーザーにアプリの再起動を案内する（1回目でダウンロード、2回目で適用）。

## リリース手順

アセット差分でパッチが適用されない場合や、新バージョンをリリースする場合に使用する。

### 1. バージョン bump

`apps/mobile/pubspec.yaml` の `version:` を更新する。

### 2. リリース作成

```bash
# iOS（実機プレビュー用）
bash .claude/skills/shorebird-patch/release.sh ios --export-method development

# Android
bash .claude/skills/shorebird-patch/release.sh android
```

### 3. デバイスインストール（iOS）

```bash
# デバイスID確認
xcrun devicectl list devices

# IPAインストール
xcrun devicectl device install app --device <DEVICE_ID> apps/mobile/build/ios/ipa/ccpocket.ipa
```

### 4. その後のパッチ

クリーンなリリースベースが出来たので、以降のパッチはアセット差分なしで作成可能:
```bash
bash .claude/skills/shorebird-patch/patch.sh ios <new-version>
```

## トラブルシュート

- **アセット差分でパッチが適用されない**: `--allow-asset-diffs` でパッチ作成は成功するが、アセット変更（フォント、画像等）を含むパッチは実機で適用に失敗する。新リリースの作成が必要
- **署名エラー（exportArchive）**: IPA生成時のエラーはShorebirdパッチ自体には影響しない。パッチが `Published Patch N!` と表示されていれば成功
- **インタラクティブプロンプト**: `shorebird` コマンドを直接実行する場合は `--release-version` フラグ必須（省略するとインタラクティブプロンプトで非TTY環境がエラーになる）
- **パッチが反映されない場合の確認**: 設定画面のバージョン表示で `(patch N)` が出ているか確認。出ていなければShorebirdリリースビルドでない可能性がある
