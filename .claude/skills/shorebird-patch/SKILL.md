---
name: shorebird-patch
description: Shorebird OTA パッチの作成・staging 配布（stable 昇格はユーザー実施）
disable-model-invocation: true
allowed-tools: Bash(bash:*), Bash(shorebird:*), Bash(dart:*), Bash(xcrun:*), Bash(grep:*), Read
---

# Shorebird パッチ配布

Shorebird OTA パッチを staging に作成する。stable への昇格はユーザーが検証後に手動で実施する。

> **新バージョンのリリース**は `/release-mobile` スキルを使用する。
> アセット差分でパッチが適用されない場合も、`/release-mobile` でリリース後に再パッチする。

## フロー概要

```
patch (staging) → デバッグ画面で検証 → ユーザーが promote (stable) → 全ユーザーに配信
```

## パッチ手順

### 1. バージョン確認

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の値を記録する（= `<version>`）。

### 2. パッチ作成 (staging)

引数でプラットフォームが指定された場合はそのまま使う。指定がなければ、その時点のエージェントで利用可能な質問手段でユーザーに確認する。特定の質問ツール名には依存しない。

```bash
# iOS
bash .claude/skills/shorebird-patch/patch.sh ios <version>

# Android
bash .claude/skills/shorebird-patch/patch.sh android <version>

# 両方の場合は順番に実行
```

スクリプトが以下を一括で行う:
- `shorebird patch` で **staging** にパッチ作成
- `--allow-asset-diffs` によりアセット変更の確認プロンプトを自動スキップ
- iOSでは一時的にWatchターゲットを除外し、一般向けReleaseと同じXcode構成で作成
- iOSのnative差分は許可せず、検出時はフルリリースを要求

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
3. **推奨対応**: `/release-mobile` で新リリースを作成してから、クリーンな状態でパッチを再作成する

### 4. 検証（staging）

パッチが staging に配信されたら、以下の方法で検証する:

- **ローカル**: `shorebird preview --track=staging --release-version=<version>`
- **実機（TestFlight等）**: アプリのデバッグ画面（ロゴ5連打）→ Update Track を Staging に変更 → アプリ再起動

### 5. Promote (staging → stable)

このスキルでは stable への昇格は実行しない。検証が問題なければ、ユーザーが以下を手動実行する:

```bash
bash .claude/skills/shorebird-patch/promote.sh <version> <patch-number>
```

エージェントは promote を自動実行せず、上記コマンドをそのまま案内する。

### 6. 完了報告

以下を報告する:
- パッチ番号
- 対象プラットフォーム
- リリースバージョン
- トラック: **staging** に配信済み
- stable 昇格は未実施で、ユーザー実行待ちであること
- アセット差分: あり/なし（ありの場合は警告を明記）
- ユーザーがそのまま実行できる promote コマンド

## npm scripts

```bash
npm run shorebird:patch:android -- <release-version>
npm run shorebird:patch:ios -- <release-version>
npm run shorebird:promote -- <release-version> <patch-number>
```

## トラブルシュート

- **アセット差分でパッチが適用されない**: `--allow-asset-diffs` でパッチ作成は成功するが、アセット変更（フォント、画像等）を含むパッチは実機で適用に失敗する。`/release-mobile` で新リリースが必要
- **iOS native差分**: パッチでは配布できないため、Watch機能をmainへ初めてマージした後は、先に一般向けiOSフルリリースを作成する。以前のpre-Watch releaseへiOS patchを作らない
- **署名エラー（exportArchive）**: IPA生成時のエラーはShorebirdパッチ自体には影響しない。パッチが `Published Patch N!` と表示されていれば成功
- **インタラクティブプロンプト**: `shorebird` コマンドを直接実行する場合は `--release-version` フラグ必須（省略するとインタラクティブプロンプトで非TTY環境がエラーになる）
- **パッチが反映されない場合の確認**: 設定画面のバージョン表示で `(patch N)` が出ているか確認。出ていなければShorebirdリリースビルドでない可能性がある
- **staging パッチの確認方法**: デバッグ画面（ロゴ5連打）→ Update Track を Staging に変更 → アプリ再起動
- **エージェント差異への対応**: ユーザーへの確認が必要な場面では `AskUserQuestion` などの固有ツール名を前提にせず、その環境で使える質問手段を使う
