---
name: release-app
description: ccpocketアプリのバージョン更新と、指定プラットフォーム向けリリースを行う。
allowed-tools: Bash(git:*), Bash(grep:*), Bash(gh:*), Bash(bash scripts/release/run-checks.sh), Bash(node scripts/release/monitor.mjs:*), Read, Edit, AskUserQuestion
---

# アプリ リリース

Flutter アプリのリリースを行う。
タグ push 後は GH Actions が自動でビルド・署名・配布・GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

指定済みのバージョン・対象を優先する。未指定の項目は以下の既定ルールで決定し、決定内容と理由を報告してリリースを進める。リリース依頼に含まれるコミット・push・タグ作成に追加の承認を求めない。

## 手順

### 1. 現在のバージョン確認 & 変更内容の収集

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の形式。`+N` は build number。

前回リリースからの差分を確認する:

```bash
# 前回のタグ（iOS/Android/macOS/Linux/Windows のいずれか新しい方）
git tag -l 'ios/v*' 'android/v*' 'macos/v*' 'linux/v*' 'windows/v*' --sort=-v:refname | head -1

# 差分コミット（bridge 以外）
git log $(git tag -l 'ios/v*' 'android/v*' 'macos/v*' 'linux/v*' 'windows/v*' --sort=-v:refname | head -1)..HEAD --oneline -- apps/mobile/ CHANGELOG.md
```

### 2. バージョンとプラットフォームを決定

差分コミットと実装内容から、次の優先順で決定する。指定済みのバージョンは再確認しない。

- 破壊的変更（`!`、`BREAKING CHANGE`、実際の互換性破壊）がある → `major`。未承認の場合だけ、具体的なバージョンと互換性への影響を示してユーザーに確認する。
- 破壊的変更がなく `feat` / 新機能がある → `minor` を自動採用する。
- その他の修正・改善・保守変更 → `patch` を自動採用する。

build number は現在の値 +1 とする。

プラットフォーム指定がなければ **iOS + Android + macOS + Linux + Windows 全部**を対象にする。「モバイルのみ」は iOS + Android、「デスクトップのみ」は macOS + Linux + Windows とし、個別指定があればその対象だけを使う。

### 3. CHANGELOG 更新

`CHANGELOG.md`（ルート）の先頭に新しいセクションを追加する。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

ステップ 1 で確認したコミットを元に、Added / Changed / Fixed に分類する。
空のセクション（該当なし）は省略する。

### 4. バージョン bump

`apps/mobile/pubspec.yaml` の `version` をステップ 2 で決定したバージョンに更新する。

### 5. ローカル検証

タグpush前に、CDと同じチェックをcompactラッパーで実行する。
成功時は解析・テスト・合計時間の3行だけを返す。失敗時は一時ログのパスと
最大120行の末尾だけを返す。**すべてpassしなければ次へ進まない。**

```bash
bash scripts/release/run-checks.sh
```

失敗した場合は原因を調査し、今回の変更に起因する問題を修正・再検証する。既存の無関係な問題や権限・認証など自力で解消できない障害が残る場合は、失敗内容と必要な対応を報告し、タグをpushしない。

### 6. コミット & push

```bash
git add apps/mobile/pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z+N"
git push origin main
```

### 6.1. Windows preflight（Windowsを選択した場合）

Windowsタグを含むリリースでは、**いずれのプラットフォームタグも作成する前に**、
リリースコミットと同じSHAで起動した `Test` workflowの成功を確認する。
通常CIの `mobile-windows` jobが、リリースworkflowと同じFlutter全テストを
`windows-2022` で実行する。

```bash
release_sha=$(git rev-parse HEAD)
node scripts/release/monitor.mjs preflight --sha "$release_sha"
```

監視スクリプトは起動検出を10秒間隔、実行中を30秒間隔で確認し、状態変化と
3分ごとのheartbeatだけを出す。起動しなければ2分、完了しなければ15分で失敗する。
個々の`gh`呼び出しも60秒で打ち切り、最大3回まで再試行する。
失敗時はjob・step・run URLと、完全な失敗ログを保存した一時パスを1行で返す。
タグは作成せず、必要なログ箇所だけを調査して修正コミットをpushし、新しいSHAで
preflightをやり直す。タグがなければ同じversion/build numberを使用できる。

### 6.2. タグ

ローカル検証と、Windows選択時のpreflightがすべて成功した後で、
ステップ2で選択されたプラットフォームのタグを作成・pushする。
Windowsを含む複数プラットフォームのリリースでは、preflight成功前に他のタグも作成しない。

ステップ 2 で選択されたプラットフォームのタグを打つ:

**各タグは必ず別々の `git push` で送信すること。** GitHubは4個以上のタグを
1回のpushで送るとtag pushイベントを生成しないため、複数タグを1つの
`git push origin <tag> <tag> ...` にまとめてはならない。

```bash
# iOS（選択された場合）
git tag ios/vX.Y.Z+N
git push origin ios/vX.Y.Z+N

# Android（選択された場合）
git tag android/vX.Y.Z+N
git push origin android/vX.Y.Z+N

# macOS（選択された場合）
git tag macos/vX.Y.Z+N
git push origin macos/vX.Y.Z+N

# Linux（選択された場合）
git tag linux/vX.Y.Z+N
git push origin linux/vX.Y.Z+N

# Windows（選択された場合）
git tag windows/vX.Y.Z+N
git push origin windows/vX.Y.Z+N
```

### 7. 完了確認

タグ push 後、GH Actions が自動実行される:

| タグ | ワークフロー | 内容 |
|-----|------------|------|
| `ios/v*` | `ios-release.yml` | Shorebird release iOS → TestFlight → GitHub Release |
| `android/v*` | `android-release.yml` | Shorebird release Android → Google Play (internal draft) → GitHub Release |
| `macos/v*` | `macos-release.yml` | Developer ID 署名 → 公証 → DMG → GitHub Release |
| `linux/v*` | `linux-release.yml` | Linux release build → Xvfb smoke → tar.gz → GitHub Release |
| `windows/v*` | `windows-release.yml` | Windows release build → smoke → zip → GitHub Release |

タグをpushしたプラットフォームだけをカンマ区切りで指定する:

```bash
node scripts/release/monitor.mjs release \
  --version "X.Y.Z+N" \
  --platforms "ios,android,macos,linux,windows"
```

監視スクリプトは全タグが同じcommitを指すことを検証し、exact tag/SHAのrunだけを
追跡する。起動検出は10秒間隔、開始後10分までは60秒間隔、その後は90秒間隔で確認し、
状態変化と3分heartbeatだけを出す。起動しなければ2分、完了しなければ40分で失敗する。
platformごとのworkflow名も照合し、同じtag/SHAで動く別workflowを成功扱いしない。
`gh run watch`や個別の`gh run list`を直接繰り返さない。

失敗時はcompactなjob/step要約と一時ログを調査する。全ログを会話へ貼らない。
全対象が`completed/success`になるまでリリースを完了扱いにしない。
