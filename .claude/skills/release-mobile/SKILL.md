---
name: release-mobile
description: モバイルアプリのリリース（バージョンbump + CHANGELOG + タグ → GH Actions で Shorebird release + ストア配布）
disable-model-invocation: true
allowed-tools: Bash(git:*), Bash(grep:*), Bash(dart analyze:*), Bash(cd apps/mobile && flutter test), Read, Edit, AskUserQuestion
---

# モバイルアプリ リリース

Flutter モバイルアプリのリリースを行う。
タグ push 後は GH Actions が自動で Shorebird release + ストア配布 + GitHub Release を作成する。

## 前提

- main ブランチで作業中であること
- 未コミットの変更がないこと

## 手順

### 1. 現在のバージョン確認 & 変更内容の収集

```bash
grep '^version:' apps/mobile/pubspec.yaml
```

`version: X.Y.Z+N` の形式。`+N` は build number。

前回リリースからの差分を確認する:

```bash
# 前回のタグ（iOS/Android どちらか新しい方）
git tag -l 'ios/v*' 'android/v*' --sort=-v:refname | head -1

# 差分コミット（bridge 以外）
git log $(git tag -l 'ios/v*' 'android/v*' --sort=-v:refname | head -1)..HEAD --oneline -- apps/mobile/ CHANGELOG.md
```

### 2. バージョンとプラットフォームをユーザーに確認

差分コミットの内容を分析し、AskUserQuestion で **2つの質問を同時に** 確認する。

#### 質問 1: バージョン

**選択肢の決定ルール:**
- `feat` コミットがある → **minor** を推奨（1番目の選択肢にし「(Recommended)」を付ける）
- `feat` がなく `fix` のみ → **patch** を推奨
- 破壊的変更がある → **major** を推奨

選択肢は具体的なバージョン番号で提示する（例: 「1.20.0+43 (minor)」「1.19.1+43 (patch)」）。
build number は現在の値 +1 で統一する。

#### 質問 2: プラットフォーム

以下の3択:
- **iOS + Android 両方** (Recommended)
- **iOS のみ**
- **Android のみ**

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

タグ push 前に、CD と同じチェックをローカルで実行する。
**すべて pass しなければ次のステップに進まない。**

```bash
# 静的解析
dart analyze apps/mobile

# テスト
cd apps/mobile && flutter test
```

失敗した場合はユーザーに報告し、修正を待つ。

### 6. コミット & タグ

```bash
git add apps/mobile/pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z+N"
git push origin main
```

ステップ 2 で選択されたプラットフォームのタグを打つ:

```bash
# iOS（選択された場合）
git tag ios/vX.Y.Z+N
git push origin ios/vX.Y.Z+N

# Android（選択された場合）
git tag android/vX.Y.Z+N
git push origin android/vX.Y.Z+N
```

### 7. 完了確認

タグ push 後、GH Actions が自動実行される:

| タグ | ワークフロー | 内容 |
|-----|------------|------|
| `ios/v*` | `ios-release.yml` | Shorebird release iOS → TestFlight → GitHub Release |
| `android/v*` | `android-release.yml` | Shorebird release Android → Google Play (internal draft) → GitHub Release |

```bash
# iOS タグを打った場合
gh run list --workflow=ios-release.yml --limit 1

# Android タグを打った場合
gh run list --workflow=android-release.yml --limit 1
```

成功を確認したら完了。
