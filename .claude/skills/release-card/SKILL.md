---
name: release-card
description: ccpocketのX向けリリース告知カード画像を生成・更新するときに使う。
---

# Release Card

ccpocket のリリース告知用画像を、最新タグとストア用リリースノートから生成する。

## ワークフロー

### 1. 最新リリース情報を確認

最新タグと現在のアプリバージョンを確認する。

```bash
git tag -l 'ios/v*' 'android/v*' 'macos/v*' --sort=-v:refname | head -10
grep '^version:' apps/mobile/pubspec.yaml
```

原則として最新タグの `vX.Y.Z` をカードのバージョンに使う。タグが `ios/v1.86.1+148` のように build number を含む場合、画像表示とファイル名には `1.86.1` を使う。

指定されたバージョン・プラットフォームを優先し、未指定なら最新リリースタグを使う。pubspecや各プラットフォームのタグにずれがあっても、タグの内容とrelease workflowを調べて対象を決定し、採用理由を報告する。調査しても対象リリースを特定できない場合だけユーザーへ確認する。

### 2. リリースノートを確認

英語・日本語のリリースノートを読む。

```bash
sed -n '1,160p' apps/mobile/fastlane/metadata/en-US/release_notes.txt
sed -n '1,160p' apps/mobile/fastlane/metadata/ja/release_notes.txt
```

必要に応じて最新タグとの差分も確認する。

```bash
git log <latest-tag>..HEAD --oneline -- apps/mobile/ CHANGELOG.md
```

ノートが空・古い・英日で不一致の場合は、対象リリースのCHANGELOGと実装差分からカード用の英日文言を補完する。ユーザーに見える変更を優先して読みやすく要約し、文言や要約方針の承認は求めない。

### 3. 画像を生成

既存の生成スクリプトを使う。

```bash
npm run release-card
```

タグ由来のバージョンを明示したい場合は、直接スクリプトを実行する。

```bash
node scripts/release-card/generate.mjs --version <X.Y.Z>
```

出力先は `docs/images/`。ファイル名は蓄積運用のため、必ずバージョンを含む形式にする。

```text
docs/images/release-card-v<X.Y.Z>-en.png
docs/images/release-card-v<X.Y.Z>-ja.png
```

### 4. 生成画像を確認

生成後、英語版・日本語版の両方を `view_image` で確認する。

確認観点:

- タイトルとバージョンが正しい
- `Claude Code` ではなく `Claude` 表記になっている
- `Codex / Claude / Self-hosted` のようなラベルが残っていない
- すべての変更点が画像内に収まっている
- テキストがカードからはみ出していない
- 文字が小さすぎず、Xのタイムライン上でも読める
- 余計なインストール手順・URL導線が入っていない
- 英日でレイアウト密度が破綻していない

### 5. 不備があればスクリプトを更新

画像に不備がある場合は、出力画像を直接加工せず `scripts/release-card/generate.mjs` を修正して再生成する。

よくある調整:

- release notes が長い場合はフォントサイズ・行間・カード高さを調整する
- 項目数が奇数の場合は最後のカードを横幅いっぱいにする
- 日本語が詰まりすぎる場合は compact 判定やフォントサイズを調整する
- 出力名にバージョンが入っていない場合は命名ロジックを修正する

修正後は必ず再生成し、もう一度 `view_image` で確認する。

### 6. 完了報告

完了時は以下を簡潔に報告する。

- 使用したバージョン
- 生成したPNGパス
- スクリプトを更新した場合は変更点
- 実行した検証
